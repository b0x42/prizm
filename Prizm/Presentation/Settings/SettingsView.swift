import LocalAuthentication
import SwiftUI

enum OrganizationExplorerLayout: String, CaseIterable, Identifiable {
    case tree
    case dropdown

    var id: Self { self }

    var displayName: String {
        switch self {
        case .tree:     "Tree"
        case .dropdown: "Dropdown"
        }
    }
}

enum PreferenceKeys {
    static let organizationExplorerLayout = "organizationExplorerLayout"
}

/// macOS Settings window (⌘,).
struct SettingsView: View {

    let authRepository: any AuthRepository

    @Environment(\.dismiss) private var dismiss
    @State private var selection: SettingsPane? = .general
    @AppStorage(PreferenceKeys.organizationExplorerLayout)
    private var organizationExplorerLayout: OrganizationExplorerLayout = .tree

    private var deviceHasBiometrics: Bool {
        LAContext().canEvaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, error: nil)
    }

    var body: some View {
        HSplitView {
            List(selection: $selection) {
                Label("General", systemImage: "gearshape")
                    .tag(SettingsPane.general)
                Label("About", systemImage: "info.circle")
                    .tag(SettingsPane.about)
            }
            .listStyle(.sidebar)
            .frame(
                minWidth: SettingsMetrics.sidebarMinimumWidth,
                idealWidth: SettingsMetrics.sidebarIdealWidth,
                maxWidth: SettingsMetrics.sidebarMaximumWidth
            )

            Group {
                switch selection {
                case .general, .none:
                    Form {
                        Section("Organization Explorer") {
                            Picker(
                                "Organization Explorer Layout",
                                selection: $organizationExplorerLayout
                            ) {
                                ForEach(OrganizationExplorerLayout.allCases) { layout in
                                    Text(layout.displayName).tag(layout)
                                }
                            }
                            .pickerStyle(.segmented)
                            .accessibilityLabel("Organization Explorer Layout")
                            .accessibilityValue(organizationExplorerLayout.displayName)
                        }

                        if deviceHasBiometrics {
                            Section("Security") {
                                BiometricUnlockToggle(authRepository: authRepository)
                            }
                        }
                    }
                    .formStyle(.grouped)
                    .padding(Spacing.pageMargin)

                case .about:
                    AboutView()
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .frame(
            minWidth: SettingsMetrics.windowMinimumWidth,
            minHeight: SettingsMetrics.windowMinimumHeight
        )
        .onExitCommand {
            dismiss()
        }
    }
}

private enum SettingsPane: Hashable {
    case general
    case about
}

private enum SettingsMetrics {
    static let sidebarMinimumWidth: CGFloat = 150
    static let sidebarIdealWidth: CGFloat = 180
    static let sidebarMaximumWidth: CGFloat = 220
    static let windowMinimumWidth: CGFloat = 620
    static let windowMinimumHeight: CGFloat = 380
}
