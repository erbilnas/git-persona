import AppKit
import SwiftUI

@main
struct GitPersonaApp: App {
    @State private var store = PersonaStore()

    var body: some Scene {
        MenuBarExtra("GitPersona", systemImage: "person.crop.circle.dashed") {
            MenuBarPopoverView()
                .environment(store)
        }
        .menuBarExtraStyle(.window)
        .commands {
            CommandGroup(replacing: .appTermination) {
                Button("Quit GitPersona") {
                    NSApp.terminate(nil)
                }
                .keyboardShortcut("q", modifiers: .command)
            }
        }

        Settings {
            SettingsView()
                .environment(store)
        }
    }
}
