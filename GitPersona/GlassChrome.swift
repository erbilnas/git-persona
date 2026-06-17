import SwiftUI

extension View {
    /// Full-window material backdrop for the settings window.
    func liquidGlassWindowBackdrop() -> some View {
        modifier(LiquidGlassWindowBackdropModifier())
    }
}

private struct LiquidGlassWindowBackdropModifier: ViewModifier {
    func body(content: Content) -> some View {
        content
            .background {
                Rectangle()
                    .fill(.ultraThinMaterial)
                    .ignoresSafeArea()
            }
    }
}

/// Liquid Glass on floating chrome only (action bar), per Apple HIG guidance.
enum GlassChrome {
    @MainActor
    @ViewBuilder
    static func floatingBar<Content: View>(@ViewBuilder content: () -> Content) -> some View {
        if #available(macOS 26.0, *) {
            content()
                .padding(.horizontal, 10)
                .padding(.vertical, 8)
                .glassEffect(.regular.interactive(), in: .rect(cornerRadius: 14))
        } else {
            content()
                .padding(.horizontal, 10)
                .padding(.vertical, 8)
                .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
        }
    }
}
