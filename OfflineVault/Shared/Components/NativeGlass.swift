import SwiftUI
import UIKit

extension View {
    @ViewBuilder
    func nativeProminentButton() -> some View {
        if #available(iOS 26, *) {
            self.buttonStyle(.glassProminent)
        } else {
            self.buttonStyle(.borderedProminent)
        }
    }

    @ViewBuilder
    func nativeGlassButton() -> some View {
        if #available(iOS 26, *) {
            self.buttonStyle(.glass)
        } else {
            self.buttonStyle(.bordered)
        }
    }
}

struct CopyBanner: View {
    let text: String

    var body: some View {
        Text(text)
            .font(.subheadline)
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
            .modifier(BannerChrome())
    }
}

private struct BannerChrome: ViewModifier {
    func body(content: Content) -> some View {
        if #available(iOS 26, *) {
            content.glassEffect(.regular, in: .capsule)
        } else {
            content.background(.regularMaterial, in: Capsule())
        }
    }
}

enum Haptics {
    static func success() {
        UINotificationFeedbackGenerator().notificationOccurred(.success)
    }
}
