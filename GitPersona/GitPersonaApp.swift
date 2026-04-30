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

        Settings {
            SettingsView()
                .environment(store)
        }
    }
}
