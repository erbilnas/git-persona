import AppKit
import SwiftUI

struct MainView: View {
    @State private var selectedPane: SettingsPane = .general

    var body: some View {
        NavigationSplitView {
            sidebar
        } detail: {
            detailPane
        }
        .navigationSplitViewStyle(.balanced)
        .frame(
            minWidth: 680, idealWidth: 780, maxWidth: .infinity,
            minHeight: 520, idealHeight: 580, maxHeight: .infinity
        )
        .liquidGlassWindowBackdrop()
        .toolbarBackgroundVisibility(.hidden, for: .windowToolbar)
        .onAppear {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                activateWindow()
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: .openSettingsPane)) { notification in
            if let pane = SettingsWindowOpener.pane(from: notification) {
                selectedPane = pane
            }
            activateWindow()
        }
    }

    // MARK: - Sidebar

    private var sidebar: some View {
        List(selection: $selectedPane) {
            Section {
                ForEach(SettingsPane.standardPanes) { pane in
                    SettingsSidebarLabel(pane: pane)
                        .tag(pane)
                }
            } header: {
                HStack(spacing: 10) {
                    brandLogoImage(size: 22)

                    Text("GitPersona")
                        .font(.headline)
                }
                .textCase(nil)
                .padding(.vertical, 4)
            }
        }
        .listStyle(.sidebar)
        .navigationSplitViewColumnWidth(min: 200, ideal: 220, max: 260)
        .scrollContentBackground(.hidden)
    }

    // MARK: - Detail

    @ViewBuilder
    private var detailPane: some View {
        switch selectedPane {
        case .general:
            GeneralSettingsPane()
        case .personas:
            PersonasSettingsPane()
        case .about:
            AboutSettingsPane()
        }
    }

    // MARK: - Window

    private func activateWindow() {
        NSApp.setActivationPolicy(.regular)
        NSApp.activate(ignoringOtherApps: true)

        autoreleasepool {
            for window in NSApplication.shared.windows {
                guard window.frame.width >= 400, window.isVisible else { continue }

                window.title = "GitPersona"
                window.minSize = NSSize(width: 680, height: 520)
                window.titleVisibility = .hidden
                window.titlebarAppearsTransparent = true
                window.isOpaque = false
                window.backgroundColor = .clear
                window.styleMask.insert(.fullSizeContentView)
                window.isMovableByWindowBackground = true
                window.makeKeyAndOrderFront(nil)
                break
            }
        }
    }
}
