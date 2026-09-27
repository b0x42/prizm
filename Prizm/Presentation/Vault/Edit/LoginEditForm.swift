import SwiftUI

// MARK: - LoginEditForm

/// Edit form for Login vault items.
///
/// Mirrors the layout of `LoginDetailView`: Credentials card, Websites card,
/// Notes card, Custom Fields card. URIs can be added, removed, and reordered.
/// Password is masked by default.
struct LoginEditForm: View {

    @Binding var draft: DraftLoginContent

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {

            DetailSectionCard("Credentials") {
                OptionalEditFieldRow(label: "Username", value: $draft.username)
                Divider()
                MaskedEditFieldRow(label: "Password", value: $draft.password, generatorBinding: $draft.password)
            }

            additionalFieldsSection

            DetailSectionCard("Websites") {
                ForEach(draft.uris) { uri in
                    if let index = draft.uris.firstIndex(where: { $0.id == uri.id }) {
                        if index > 0 { Divider() }
                        URIEditRow(
                            uri: $draft.uris[index],
                            canMoveUp: index > 0,
                            canMoveDown: index < draft.uris.count - 1,
                            showReorderButtons: draft.uris.count > 1,
                            onMoveUp: {
                                guard let i = draft.uris.firstIndex(where: { $0.id == uri.id }), i > 0 else { return }
                                draft.uris.swapAt(i, i - 1)
                            },
                            onMoveDown: {
                                guard let i = draft.uris.firstIndex(where: { $0.id == uri.id }), i < draft.uris.count - 1 else { return }
                                draft.uris.swapAt(i, i + 1)
                            },
                            onRemove: {
                                guard let i = draft.uris.firstIndex(where: { $0.id == uri.id }) else { return }
                                draft.uris.remove(at: i)
                            }
                        )
                    }
                }
                if !draft.uris.isEmpty { Divider() }
                Button {
                    draft.uris.append(DraftLoginURI())
                } label: {
                    Label("Add Website", systemImage: "plus")
                        .font(Typography.fieldValue)
                        .foregroundStyle(.tint)
                }
                .buttonStyle(.borderless)
                .padding(.vertical, Spacing.rowVertical)
                .padding(.horizontal, Spacing.rowHorizontal)
                .accessibilityLabel("Add website")
            }

            DetailSectionCard("Notes") {
                OptionalEditFieldRow(label: "Notes", value: $draft.notes)
            }
        }
    }

    private var additionalFieldsSection: some View {
        DetailSectionCard(
            "Additional Fields",
            showsBackground: draft.totp != nil
        ) {
            if draft.totp != nil {
                TOTPSecretEditView(
                    configuration: Binding(
                        get: { draft.totp ?? "" },
                        set: { draft.totp = $0 }
                    )
                )
                Divider()
                Button("Remove Authenticator", role: .destructive) {
                    draft.totp = nil
                }
                .buttonStyle(.borderless)
                .foregroundStyle(.red)
                .padding(.vertical, Spacing.rowVertical)
                .padding(.horizontal, Spacing.rowHorizontal)
                .accessibilityLabel("Remove authenticator")
            }

            if draft.totp == nil {
                Button {
                    draft.totp = ""
                } label: {
                    Label("Add Authenticator (TOTP)", systemImage: "plus")
                        .font(Typography.fieldValue)
                        .foregroundStyle(Color.accentColor)
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Add authenticator")
            }
        }
    }
}

private struct TOTPSecretEditView: View {
    @Binding var configuration: String

    @FocusState private var isFieldFocused: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.fieldContentGap) {
            Text("Authenticator Key")
                .font(Typography.fieldLabel)
                .foregroundStyle(.secondary)

            HStack(spacing: Spacing.fieldActionGap) {
                Button {
                    isFieldFocused.toggle()
                } label: {
                    Image(systemName: isFieldFocused ? "eye.slash" : "eye")
                        .imageScale(.medium)
                        .foregroundStyle(Color.accentColor)
                }
                .buttonStyle(.plain)
                .help(isFieldFocused ? "Hide" : "Edit")
                .accessibilityLabel(isFieldFocused ? "Hide authenticator key" : "Edit authenticator key")

                TextField("Base32 key or otpauth URI", text: $configuration)
                    .font(Typography.fieldValue.monospaced())
                    .textFieldStyle(.plain)
                    .focused($isFieldFocused)
                    .foregroundStyle(isFieldFocused ? Color.primary : Color.clear)
                    .overlay(alignment: .leading) {
                        if !isFieldFocused, !configuration.isEmpty {
                            Text(MaskedFieldState.maskedPlaceholder)
                                .font(Typography.fieldValue.monospaced())
                                .foregroundStyle(.primary)
                                .allowsHitTesting(false)
                        }
                    }
                    .accessibilityLabel("Authenticator key")
                    .accessibilityValue(isFieldFocused ? configuration : "Hidden")
            }
        }
        .padding(.vertical, Spacing.rowVertical)
        .padding(.horizontal, Spacing.rowHorizontal)
    }
}

struct TOTPCodeView: View {
    let configuration: String
    let generator: any TOTPCodeGenerating
    var showsErrors = false
    var onCopy: ((String) -> Void)? = nil

    @State private var isHovered = false
    @State private var showCopied = false
    @State private var copyFeedbackTask: Task<Void, Never>?
    /// Snapshot of the code when "Show in Large Type" was chosen. Captured rather than
    /// re-read live so the sheet does not silently change digits mid-read when the period rolls over.
    @State private var largeTypeCode: String?
    @Environment(\.colorSchemeContrast) private var contrast
    @Environment(\.isHoverSuppressed) private var isHoverSuppressed

    var body: some View {
        TimelineView(.periodic(from: .now, by: 1)) { context in
            switch displayState(at: context.date) {
            case .code(let code):
                HStack(spacing: Spacing.fieldActionGap) {
                    VStack(alignment: .leading, spacing: Spacing.fieldContentGap) {
                        Text("One-Time Password")
                            .font(Typography.fieldLabel)
                            .foregroundStyle(.secondary)

                        HStack(spacing: Spacing.fieldActionGap) {
                            // Separate Text views rather than "XXX • XXX" in one string: in a
                            // monospaced font every space is a full glyph cell, which pushed the
                            // separator too far from the digits.
                            HStack(spacing: Spacing.totpGroupGap) {
                                Text(codeHalves(code.value).first)
                                Text("•")
                                    .foregroundStyle(.tertiary)
                                Text(codeHalves(code.value).second)
                            }
                            .font(Typography.fieldValue.monospaced())
                            .textSelection(.enabled)

                            HStack(spacing: Spacing.totpRingGap) {
                                TOTPCountdownRing(
                                    progress: Double(code.secondsRemaining) / Double(max(code.period, 1)),
                                    tint: code.secondsRemaining <= 10 ? Color.red : Color.green
                                )

                                Text(paddedSeconds(code.secondsRemaining))
                                    .font(Typography.totpCountdown)
                            }
                            .padding(.horizontal, Spacing.badgeHorizontal)
                            .padding(.vertical, Spacing.totpBadgeVertical)
                            .background(
                                Color.primary.opacity(Opacity.fieldHover(contrast)),
                                in: Capsule()
                            )
                            .accessibilityElement(children: .ignore)
                            .accessibilityLabel("Time remaining")
                            .accessibilityValue("\(code.secondsRemaining) seconds")
                        }
                    }

                    Spacer()

                    if isHovered {
                        HStack(spacing: Spacing.headerGap) {
                            if onCopy != nil {
                                Text("Copy")
                                    .font(Typography.utility.weight(.semibold))
                                    .textCase(.uppercase)
                                    .foregroundStyle(Color.accentColor)
                                    .transition(.opacity)
                            }

                            actionsMenu(for: code.value)
                        }
                    }
                }
                .padding(.vertical, Spacing.rowVertical)
                .padding(.horizontal, Spacing.rowHorizontal)
                .background {
                    Rectangle()
                        .fill(isHovered
                            ? Color.accentColor.opacity(Opacity.fieldHover(contrast))
                            : Color.clear)
                }
                .contentShape(Rectangle())
                .onTapGesture { copy(code.value) }
                .onHover { hovering in
                    optionalAnimation(.easeInOut(duration: 0.15)) {
                        isHovered = hovering && !isHoverSuppressed
                    }
                }
                .onChange(of: isHoverSuppressed) { _, suppressed in
                    if suppressed { isHovered = false }
                }
                .overlay(alignment: .topTrailing) {
                    if showCopied {
                        Label("Copied", systemImage: "checkmark")
                            .font(Typography.utility.weight(.semibold))
                            .foregroundStyle(DesignColor.selectedContentForeground)
                            .padding(.horizontal, Spacing.toastHorizontal)
                            .padding(.vertical, Spacing.toastVertical)
                            .background(Color.accentColor, in: Capsule())
                            .padding(.trailing, Spacing.rowHorizontal)
                            .transition(.opacity.combined(with: .scale))
                            .accessibilityHidden(true)
                    }
                }
                .sheet(isPresented: isShowingLargeType) {
                    LargeTypeFieldView(label: "One-Time Password", value: largeTypeCode ?? "")
                }
                .onDisappear {
                    copyFeedbackTask?.cancel()
                }
                .accessibilityElement(children: .contain)
                .accessibilityLabel("One-time password \(code.value)")
                .accessibilityHint(onCopy == nil ? "" : "Click to copy")
                .accessibilityAction(named: "Copy") {
                    copy(code.value)
                }
                .accessibilityAction(named: "Show in Large Type") {
                    largeTypeCode = code.value
                }
            case .error(let message):
                if showsErrors {
                    Text(message)
                        .font(Typography.utility)
                        .foregroundStyle(.red)
                        .accessibilityLabel(message)
                }
            }
        }
    }

    private var isShowingLargeType: Binding<Bool> {
        Binding(
            get: { largeTypeCode != nil },
            set: { if !$0 { largeTypeCode = nil } }
        )
    }

    private func actionsMenu(for code: String) -> some View {
        Menu {
            if onCopy != nil {
                Button("Copy", systemImage: "doc.on.doc") {
                    copy(code)
                }
                .accessibilityIdentifier(AccessibilityID.Field.copyButton("One-Time Password"))
            }

            Button("Show in Large Type", systemImage: "textformat.size.larger") {
                largeTypeCode = code
            }
        } label: {
            Image(systemName: "chevron.down")
                .imageScale(.small)
                .foregroundStyle(Color.accentColor)
        }
        .menuStyle(.borderlessButton)
        .menuIndicator(.hidden)
        .fixedSize()
        .help("More actions for one-time password")
        .accessibilityLabel("More actions for one-time password")
    }

    private func copy(_ code: String) {
        guard let onCopy else { return }
        onCopy(code)

        copyFeedbackTask?.cancel()
        optionalAnimation(.easeInOut(duration: 0.1)) { showCopied = true }
        AccessibilityNotification.Announcement("One-time password copied").post()
        copyFeedbackTask = Task {
            do {
                try await Task.sleep(for: .seconds(1.2))
                guard !Task.isCancelled else { return }
                optionalAnimation(.easeInOut(duration: 0.1)) { showCopied = false }
            } catch {
                // A newer copy action owns the feedback lifetime.
            }
        }
    }

    private func displayState(at date: Date) -> DisplayState {
        do {
            return .code(try generator.generateCode(from: configuration, at: date))
        } catch {
            return .error(error.localizedDescription)
        }
    }

    private func codeHalves(_ code: String) -> (first: String, second: String) {
        let midpoint = code.index(code.startIndex, offsetBy: code.count / 2)
        return (String(code[..<midpoint]), String(code[midpoint...]))
    }

    private func paddedSeconds(_ seconds: Int) -> String {
        seconds < 10 ? "0\(seconds)" : "\(seconds)"
    }

    private enum DisplayState {
        case code(TOTPCode)
        case error(String)
    }
}

/// Compact countdown ring for the TOTP badge.
///
/// A hand-drawn `Circle().trim` rather than `Gauge(.accessoryCircularCapacity)`: the system
/// gauge ignores an explicit `.frame` below its intrinsic size and renders its label inside
/// the ring, which overflowed the badge at the 12 pt size this row needs.
private struct TOTPCountdownRing: View {
    /// Fraction of the period still remaining, 0...1. Drawn clockwise from 12 o'clock.
    let progress: Double
    let tint: Color

    var body: some View {
        ZStack {
            Circle()
                .stroke(tint.opacity(0.25), lineWidth: LayoutMetrics.totpProgressLineWidth)
            Circle()
                .trim(from: 0, to: min(max(progress, 0), 1))
                .stroke(tint, style: StrokeStyle(lineWidth: LayoutMetrics.totpProgressLineWidth, lineCap: .round))
                .rotationEffect(.degrees(-90))
        }
        .frame(width: LayoutMetrics.totpProgressDiameter, height: LayoutMetrics.totpProgressDiameter)
        .accessibilityHidden(true)
    }
}

// MARK: - URIEditRow

/// An editable row for a single LoginURI, with match-type picker, reorder, and remove controls.
private struct URIEditRow: View {

    @Binding var uri: DraftLoginURI
    let canMoveUp: Bool
    let canMoveDown: Bool
    let showReorderButtons: Bool
    let onMoveUp: () -> Void
    let onMoveDown: () -> Void
    let onRemove: () -> Void

    @State private var showMatchType = false

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            HStack {
                if showReorderButtons {
                    VStack(spacing: 2) {
                        Button(action: onMoveUp) {
                            Image(systemName: "chevron.up")
                                .font(Typography.utility)
                        }
                        .buttonStyle(.borderless)
                        .accessibilityLabel("Move up")
                        .disabled(!canMoveUp)

                        Button(action: onMoveDown) {
                            Image(systemName: "chevron.down")
                                .font(Typography.utility)
                        }
                        .buttonStyle(.borderless)
                        .accessibilityLabel("Move down")
                        .disabled(!canMoveDown)
                    }
                    .padding(.leading, Spacing.rowHorizontal)
                }

                EditFieldRow(label: "Website", text: $uri.uri)

                Button {
                    optionalAnimation(.easeInOut(duration: 0.2)) {
                        showMatchType.toggle()
                    }
                } label: {
                    Image(systemName: "gearshape")
                        .foregroundStyle(showMatchType ? Color.accentColor : Color.secondary)
                }
                .buttonStyle(.borderless)
                .accessibilityLabel("Match type settings")

                Button(action: onRemove) {
                    Image(systemName: "minus.circle.fill")
                        .foregroundStyle(.red)
                }
                .buttonStyle(.borderless)
                .accessibilityLabel("Remove website")
                .padding(.trailing, Spacing.rowHorizontal)
            }
            if showMatchType {
                Divider()
                HStack {
                    Text("Match Type")
                        .font(Typography.fieldLabel)
                        .foregroundStyle(.secondary)
                        .padding(.leading, Spacing.rowHorizontal)
                    Spacer()
                    Picker("Match Type", selection: $uri.matchType) {
                        Text("Default").tag(URIMatchType?.none)
                        ForEach(URIMatchType.allCases, id: \.self) { type in
                            Text(type.displayName).tag(URIMatchType?.some(type))
                        }
                    }
                    .labelsHidden()
                    .padding(.trailing, Spacing.rowHorizontal)
                }
                .padding(.vertical, Spacing.rowVertical)
                .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
    }
}

// MARK: - URIMatchType + Helpers

private extension URIMatchType {
    static var allCases: [URIMatchType] {
        [.domain, .host, .startsWith, .exact, .regularExpression, .never]
    }

    var displayName: String {
        switch self {
        case .domain:            return "Domain"
        case .host:              return "Host"
        case .startsWith:        return "Starts With"
        case .exact:             return "Exact"
        case .regularExpression: return "Regular Expression"
        case .never:             return "Never"
        }
    }
}
