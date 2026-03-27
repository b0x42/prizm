import SwiftUI

// MARK: - FieldRowView

/// A single labeled field row with hover-activated action buttons (FR-023, FR-025).
///
/// Shows a label + value and reveals copy/reveal/open-in-browser controls on hover.
/// Background highlights on hover to indicate interactivity (FR-023).
///
/// For secret fields (password, card number, etc.) pass `isMasked: true` to show
/// a `MaskedFieldView` instead of plain text; the reveal button will be included automatically.
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
    var onCopy:   ((String) -> Void)? = nil

    @State private var isHovered = false

    var body: some View {
        HStack(alignment: .center, spacing: 8) {
            // Field content
            if isMasked {
                Text(label)
                    .font(Typography.fieldValue)
                Spacer()
                hoverActions
                MaskedFieldView(label: label, value: value, itemId: itemId)
            } else if isMultiLine {
                VStack(alignment: .leading, spacing: 2) {
                    if !label.isEmpty {
                        Text(label)
                            .font(Typography.fieldValue)
                    }
                    Text(value ?? "—")
                        .font(Typography.fieldValue.monospaced())
                        .textSelection(.enabled)
                }
                Spacer()
                hoverActions
            } else {
                Text(label)
                    .font(Typography.fieldValue)
                Spacer()
                hoverActions
                Text(value ?? "—")
                    .font(Typography.fieldValue.monospaced())
                    .lineLimit(1)
                    .textSelection(.enabled)
            }
        }
        .padding(.vertical, 16)
        .padding(.horizontal, Spacing.rowHorizontal)
        .contentShape(Rectangle())
        .onHover { hovering in
            withAnimation(.easeInOut(duration: 0.15)) {
                isHovered = hovering
            }
        }
        .accessibilityIdentifier(AccessibilityID.Field.row(label))
    }

    @ViewBuilder
    private var hoverActions: some View {
        if isHovered {
            HStack(spacing: 4) {
                if let copyValue = value, !copyValue.isEmpty {
                    Button {
                        onCopy?(copyValue)
                    } label: {
                        Text("copy")
                            .font(Typography.utility)
                            .bold()
                            .textCase(.uppercase)
                    }
                    .buttonStyle(.plain)
                    .help("Copy \(label)")
                    .accessibilityIdentifier(AccessibilityID.Field.copyButton(label))
                }

                if let link = url {
                    Link(destination: link) {
                        Image(systemName: "arrow.up.right.square")
                            .imageScale(.small)
                    }
                    .buttonStyle(.plain)
                    .help("Open in browser")
                    .accessibilityIdentifier(AccessibilityID.Field.openButton(label))
                }
            }
            .transition(.opacity)
        }
    }
}
