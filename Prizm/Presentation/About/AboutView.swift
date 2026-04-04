import SwiftUI

// MARK: - AboutView

/// Custom About window for Prizm (replaces the default `NSApp.orderFrontStandardAboutPanel`).
///
/// Surfaces app version, tagline, GitHub link, "Built with" summary, and
/// acknowledgements — letting users verify the full dependency chain without
/// digging into source code. Required by CONSTITUTION §VII (Radical Transparency).
struct AboutView: View {

    // Initialized lazily from Bundle.main — safe here because View.body is @MainActor.
    @State private var viewModel = AboutViewModel.forCurrentApp()

    var body: some View {
        VStack(spacing: 0) {
            // App icon + name + version
            headerSection

            Divider()
                .padding(.vertical, 16)

            // Tagline
            Text(viewModel.tagline)
                .font(.body)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 24)

            Spacer().frame(height: 20)

            // GitHub link
            Link(destination: viewModel.gitHubURL) {
                Label("View on GitHub", systemImage: "arrow.up.right.square")
                    .font(.callout)
            }
            .buttonStyle(.link)

            Spacer().frame(height: 24)

            // Built with
            builtWithSection

            Spacer().frame(height: 16)

            // Acknowledgements
            acknowledgementsSection

            Spacer().frame(height: 24)
        }
        .frame(width: 380)
        .padding(.top, 32)
        .padding(.bottom, 24)
    }

    // MARK: - Sections

    private var headerSection: some View {
        VStack(spacing: 8) {
            Image(nsImage: NSApp.applicationIconImage)
                .resizable()
                .frame(width: 80, height: 80)

            Text(viewModel.appName)
                .font(.title.bold())

            Text("Version \(viewModel.version)")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
    }

    private var builtWithSection: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Built with")
                .font(.caption.bold())
                .foregroundStyle(.secondary)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 24)

            VStack(alignment: .leading, spacing: 3) {
                Text("Swift 6.2 + SwiftUI")
                Text("Open source — all crypto is publicly auditable")
                    .foregroundStyle(.secondary)
            }
            .font(.caption)
            .padding(.horizontal, 24)
        }
    }

    private var acknowledgementsSection: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Acknowledgements")
                .font(.caption.bold())
                .foregroundStyle(.secondary)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 24)

            VStack(alignment: .leading, spacing: 3) {
                ForEach(viewModel.acknowledgements, id: \.self) { entry in
                    Text(entry)
                }
            }
            .font(.caption)
            .foregroundStyle(.secondary)
            .padding(.horizontal, 24)
        }
    }
}
