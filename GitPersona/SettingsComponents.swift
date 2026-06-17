import SwiftUI

enum SettingsPane: String, CaseIterable, Identifiable, Hashable {
    case general
    case personas
    case about

    var id: String { rawValue }

    var title: String {
        switch self {
        case .general: "General"
        case .personas: "Personas"
        case .about: "About"
        }
    }

    var icon: String {
        switch self {
        case .general: "gearshape"
        case .personas: "person.2"
        case .about: "info.circle"
        }
    }

    static let standardPanes: [SettingsPane] = [.general, .personas, .about]
}

// MARK: - Detail scaffold

struct SettingsDetailScaffold<Content: View>: View {
    let title: String
    @ViewBuilder let content: () -> Content

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                Text(title)
                    .font(.system(size: 28, weight: .bold))
                    .foregroundStyle(.primary)
                    .padding(.bottom, 20)

                content()
            }
            .padding(.horizontal, 28)
            .padding(.top, 20)
            .padding(.bottom, 32)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .scrollContentBackground(.hidden)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

// MARK: - Grouped form

struct SettingsForm<Content: View>: View {
    var footer: String? = nil
    @ViewBuilder let content: () -> Content

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Form {
                Section {
                    content()
                }
            }
            .formStyle(.grouped)
            .scrollContentBackground(.hidden)
            .scrollDisabled(true)
            .frame(maxWidth: .infinity)

            if let footer {
                Text(footer)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, 4)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }
}

// MARK: - Rows

struct SettingsActionButton: View {
    let title: String
    let icon: String
    var isLoading: Bool = false
    var role: SettingsActionRole = .primary
    var disabled: Bool = false
    let action: () -> Void

    enum SettingsActionRole {
        case primary
        case destructive
        case secondary
    }

    var body: some View {
        Button(action: action) {
            HStack(spacing: 6) {
                if isLoading {
                    ProgressView()
                        .controlSize(.small)
                } else {
                    Image(systemName: icon)
                        .font(.system(size: 12, weight: .semibold))
                }
                Text(title)
                    .font(.body.weight(.medium))
            }
            .frame(maxWidth: .infinity)
        }
        .buttonStyle(.borderedProminent)
        .tint(tintColor)
        .controlSize(.large)
        .disabled(disabled || isLoading)
    }

    private var tintColor: Color {
        switch role {
        case .primary: .accentColor
        case .destructive: .red
        case .secondary: .secondary
        }
    }
}

struct SettingsSidebarLabel: View {
    let pane: SettingsPane

    var body: some View {
        Label(pane.title, systemImage: pane.icon)
    }
}

// MARK: - Brand logo

/// Renders the default `BrandLogo` asset with no added background.
func brandLogoImage(size: CGFloat) -> some View {
    Image("BrandLogo")
        .resizable()
        .interpolation(.high)
        .antialiased(true)
        .aspectRatio(contentMode: .fit)
        .frame(width: size, height: size)
}
