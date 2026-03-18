import SwiftUI

// MARK: - VerticalLabeledContentStyle

/// A `LabeledContentStyle` that stacks the label above the content.
/// Shared by `LoginView` and `UnlockView`.
struct VerticalLabeledContentStyle: LabeledContentStyle {
    func makeBody(configuration: Configuration) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            configuration.label
                .font(.callout.weight(.medium))
                .foregroundStyle(.secondary)
            configuration.content
        }
    }
}

extension LabeledContentStyle where Self == VerticalLabeledContentStyle {
    static var vertical: VerticalLabeledContentStyle { .init() }
}
