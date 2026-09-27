import SwiftUI

// MARK: - FieldRowView

/// A single labeled field row with hover-activated actions (FR-023, FR-025).
///
/// The label sits above its value. Clicking the row copies the value, except URL rows,
/// which open in the browser. The trailing menu provides explicit copy and other actions.
///
/// Usage:
/// ```swift
/// FieldRowView(label: "Username", value: item.username, itemId: item.id)
/// FieldRowView(label: "Password", value: item.password, itemId: item.id, isMasked: true)
/// FieldRowView(label: "Website", value: uri.uri, itemId: item.id, url: URL(string: uri.uri))
/// ```
struct FieldRowView: View {

    let label:    String
    let value:    String?
    let itemId:   String
    var isMasked: Bool  = false
    var isMultiLine: Bool = false
    var url:      URL?  = nil
    /// Optional external reference. No reference action is shown unless the caller supplies one.
    var reference: String? = nil
    var onCopy:   ((String) -> Void)? = nil

    @State private var isHovered = false
    @State private var showCopied = false
    @State private var isRevealed = false
    @State private var showLargeType = false
    @State private var copyFeedbackTask: Task<Void, Never>?
    @Environment(\.colorSchemeContrast) private var contrast
    @Environment(\.isHoverSuppressed) private var isHoverSuppressed
    @Environment(\.openURL) private var openURL
    @Environment(SecretVisibilityState.self) private var secretVisibility

    private var hasValue: Bool {
        value?.isEmpty == false
    }

    private var canCopy: Bool {
        hasValue && onCopy != nil
    }

    var body: some View {
        HStack(alignment: .center, spacing: Spacing.fieldActionGap) {
            VStack(alignment: .leading, spacing: Spacing.fieldContentGap) {
                if !label.isEmpty {
                    Text(label)
                        .font(Typography.fieldLabel)
                        .foregroundStyle(.secondary)
                }

                fieldValue
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            if isHovered, canCopy || hasValue {
                HStack(spacing: Spacing.headerGap) {
                    if canCopy || url != nil {
                        Text(url == nil ? "Copy" : "Open")
                            .font(Typography.utility.weight(.semibold))
                            .textCase(.uppercase)
                            .foregroundStyle(Color.accentColor)
                            .transition(.opacity)
                    }

                    if hasValue {
                        actionsMenu
                    }
                }
            }

        }
        .padding(.vertical, Spacing.rowVertical)
        .padding(.horizontal, Spacing.rowHorizontal)
        .background {
            Rectangle()
                .fill(isHovered && hasValue
                    ? Color.accentColor.opacity(Opacity.fieldHover(contrast))
                    : Color.clear)
        }
        .contentShape(Rectangle())
        .onTapGesture { performPrimaryAction() }
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
        .sheet(isPresented: $showLargeType) {
            LargeTypeFieldView(label: label, value: value ?? "")
        }
        .onChange(of: itemId) {
            isRevealed = false
            showLargeType = false
        }
        .onDisappear {
            copyFeedbackTask?.cancel()
        }
        .accessibilityElement(children: .contain)
        .accessibilityLabel(label.isEmpty ? "Field" : label)
        .accessibilityValue(isMasked && !isEffectivelyRevealed ? "Hidden" : value ?? "Empty")
        .accessibilityHint(url != nil ? "Click to open in browser" : (canCopy ? "Click to copy" : ""))
        .accessibilityAction(named: "Open") {
            if let url {
                openURL(url)
            }
        }
        .accessibilityAction(named: "Copy") { copyValue() }
        .accessibilityIdentifier(AccessibilityID.Field.row(label))
    }

    @ViewBuilder
    private var fieldValue: some View {
        if isMasked {
            MaskedFieldView(
                label: label,
                value: value,
                itemId: itemId,
                isRevealed: $isRevealed
            )
        } else {
            Text(value ?? "Not set")
                .font(Typography.fieldValue.monospaced())
                .lineLimit(isMultiLine ? nil : 1)
                .fixedSize(horizontal: false, vertical: isMultiLine)
                .textSelection(.enabled)
        }
    }

    private var isEffectivelyRevealed: Bool {
        isRevealed || secretVisibility.revealsAll
    }

    private var actionsMenu: some View {
        Menu {
            if canCopy {
                Button("Copy", systemImage: "doc.on.doc") {
                    copyValue()
                }
                .accessibilityIdentifier(AccessibilityID.Field.copyButton(label))
            }

            if isMasked {
                Button(
                    isEffectivelyRevealed ? "Hide" : "Reveal",
                    systemImage: isEffectivelyRevealed ? "eye.slash" : "eye"
                ) {
                    toggleReveal()
                }
                .accessibilityIdentifier(AccessibilityID.Field.revealButton(label))
            }

            Button("Show in Large Type", systemImage: "textformat.size.larger") {
                showLargeType = true
            }

            if let reference, !reference.isEmpty {
                Divider()
                Button("Copy Reference", systemImage: "link") {
                    onCopy?(reference)
                    showCopyFeedback(announcement: "\(accessibleLabel) reference copied")
                }
            }
        } label: {
            Image(systemName: "chevron.down")
                .imageScale(.small)
                .foregroundStyle(Color.accentColor)
        }
        .menuStyle(.borderlessButton)
        .menuIndicator(.hidden)
        .fixedSize()
        .help("More actions for \(accessibleLabel)")
        .accessibilityLabel("More actions for \(accessibleLabel)")
    }

    private var accessibleLabel: String {
        label.isEmpty ? "field" : label
    }

    private func toggleReveal() {
        if secretVisibility.revealsAll {
            secretVisibility.concealAll()
        } else {
            isRevealed.toggle()
        }
    }

    private func copyValue() {
        guard let copyValue = value, !copyValue.isEmpty, let onCopy else { return }
        onCopy(copyValue)
        showCopyFeedback(announcement: "\(accessibleLabel) copied")
    }

    private func performPrimaryAction() {
        if let url {
            openURL(url)
        } else {
            copyValue()
        }
    }

    private func showCopyFeedback(announcement: String) {
        copyFeedbackTask?.cancel()
        optionalAnimation(.easeInOut(duration: 0.1)) { showCopied = true }
        AccessibilityNotification.Announcement(announcement).post()
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

}

/// Shared by `FieldRowView` and `TOTPCodeView` so every copyable value offers the same large-type preview.
struct LargeTypeFieldView: View {
    let label: String
    let value: String

    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.cardTop) {
            HStack {
                Text(label.isEmpty ? "Large Type" : label)
                    .font(Typography.sectionHeader)
                    .accessibilityAddTraits(.isHeader)
                Spacer()
                Button("Done") {
                    dismiss()
                }
                .keyboardShortcut(.cancelAction)
            }

            Divider()

            ScrollView(.horizontal) {
                HStack(alignment: .top, spacing: Spacing.largeCharacterGap) {
                    ForEach(Array(value.enumerated()), id: \.offset) { offset, character in
                        VStack(spacing: Spacing.fieldContentGap) {
                            Text(displayCharacter(character))
                                .font(Typography.largeCharacter)
                            Text("\(offset + 1)")
                                .font(Typography.largeCharacterIndex)
                                .foregroundStyle(.secondary)
                        }
                        .accessibilityElement(children: .ignore)
                        .accessibilityLabel("Character \(offset + 1), \(spokenCharacter(character))")
                    }
                }
                .padding(.vertical, Spacing.cardTop)
            }
        }
        .padding(Spacing.pageMargin)
        .frame(minWidth: 520, minHeight: 220)
    }

    private func displayCharacter(_ character: Character) -> String {
        switch character {
        case " ": "␠"
        case "\n": "↵"
        case "\t": "⇥"
        default: String(character)
        }
    }

    private func spokenCharacter(_ character: Character) -> String {
        switch character {
        case " ": "space"
        case "\n": "new line"
        case "\t": "tab"
        default: String(character)
        }
    }
}
