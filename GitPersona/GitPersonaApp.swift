import AppKit
import SwiftUI

@main
struct GitPersonaApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
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

        WindowGroup(id: "main") {
            MainView()
                .environment(store)
                .frame(
                    minWidth: 680, idealWidth: 780, maxWidth: .infinity,
                    minHeight: 520, idealHeight: 580, maxHeight: .infinity
                )
        }
        .windowStyle(.automatic)
        .windowToolbarStyle(.unified)
        .defaultSize(width: 780, height: 580)
        .windowResizability(.contentSize)
        .defaultPosition(.center)
    }
}
