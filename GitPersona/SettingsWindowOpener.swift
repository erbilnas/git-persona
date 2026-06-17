import AppKit
import SwiftUI

extension Notification.Name {
    static let openSettingsPane = Notification.Name("OpenSettingsPane")
}

enum SettingsWindowOpener {
    private static let paneUserInfoKey = "pane"

    static func open(pane: SettingsPane? = nil, openWindow: OpenWindowAction? = nil) {
        if let pane {
            NotificationCenter.default.post(
                name: .openSettingsPane,
                object: nil,
                userInfo: [paneUserInfoKey: pane.rawValue]
            )
        }

        autoreleasepool {
            if let existingWindow = findMainWindow() {
                NSApp.setActivationPolicy(.regular)
                NSApp.activate(ignoringOtherApps: true)
                existingWindow.makeKeyAndOrderFront(nil)
            } else if let openWindow {
                openWindow(id: "main")
                activateApp()
            }
        }
    }

    static func pane(from notification: Notification) -> SettingsPane? {
        guard let rawValue = notification.userInfo?[paneUserInfoKey] as? String else {
            return nil
        }
        return SettingsPane(rawValue: rawValue)
    }

    private static func findMainWindow() -> NSWindow? {
        NSApplication.shared.windows.first { window in
            window.frame.width >= 400
                && window.frame.height >= 400
                && window.isVisible
        }
    }

    private static func activateApp() {
        NSApp.setActivationPolicy(.regular)
        NSApp.activate(ignoringOtherApps: true)

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
            autoreleasepool {
                findMainWindow()?.makeKeyAndOrderFront(nil)
            }
        }
    }
}
