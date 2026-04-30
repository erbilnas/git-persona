import SwiftUI

/// Floating action chrome (popover bar). Uses materials so the project builds on Xcode 16 / macOS 15 SDK
/// (CI); `glassEffect` requires a newer SDK and is not used here.
enum GlassChrome {
    @MainActor
    @ViewBuilder
    static func floatingBar<Content: View>(@ViewBuilder content: () -> Content) -> some View {
        content()
            .padding(.horizontal, 10)
            .padding(.vertical, 8)
            .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
    }
}
