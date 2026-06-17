import AppKit

@MainActor
class AppDelegate: NSObject, NSApplicationDelegate {
    private var hasLaunched = false
    private var windowObserver: Any?

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)
        hasLaunched = true

        windowObserver = NotificationCenter.default.addObserver(
            forName: NSWindow.didBecomeKeyNotification,
            object: nil,
            queue: .main
        ) { [weak self] notification in
            guard let window = notification.object as? NSWindow else { return }
            if self?.isMainAppWindow(window) == true {
                NSApp.setActivationPolicy(.regular)
            }
        }

        NotificationCenter.default.addObserver(
            forName: NSWindow.willCloseNotification,
            object: nil,
            queue: .main
        ) { [weak self] notification in
            guard let window = notification.object as? NSWindow else { return }
            if self?.isMainAppWindow(window) == true {
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                    let hasVisibleMainWindow = NSApp.windows.contains { w in
                        self?.isMainAppWindow(w) == true && w.isVisible && w != window
                    }
                    if !hasVisibleMainWindow {
                        NSApp.setActivationPolicy(.accessory)
                    }
                }
            }
        }
    }

    private func isMainAppWindow(_ window: NSWindow) -> Bool {
        let isLargeEnough = window.frame.width >= 400 && window.frame.height >= 400
        let isNotPanel = !(window is NSPanel)
        let isNotMenuBarWindow = window.level == .normal
        return isLargeEnough && isNotPanel && isNotMenuBarWindow
    }

    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        if !flag && hasLaunched {
            showMainWindow()
        }
        return true
    }

    func applicationWillTerminate(_ notification: Notification) {
        if let observer = windowObserver {
            NotificationCenter.default.removeObserver(observer)
        }
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        false
    }

    func showMainWindow() {
        NSApp.setActivationPolicy(.regular)
        NSApp.activate(ignoringOtherApps: true)

        for window in NSApp.windows {
            if isMainAppWindow(window) {
                window.makeKeyAndOrderFront(nil)
                return
            }
        }
    }
}
