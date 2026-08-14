import SwiftUI

enum VaultGlassStyle {
    case regular
    case thin
    case thick

    @available(iOS 26, *)
    var glass: Glass {
        switch self {
        case .thin:
            return .clear
        case .regular, .thick:
            return .regular
        }
    }

    var material: Material {
        switch self {
        case .thin:
            return .ultraThinMaterial
        case .regular:
            return .regularMaterial
        case .thick:
            return .thickMaterial
        }
    }
}

extension View {
    @ViewBuilder
    func vaultGlass(cornerRadius: CGFloat = 16, style: VaultGlassStyle = .regular) -> some View {
        if #available(iOS 26, *) {
            self.glassEffect(style.glass, in: .rect(cornerRadius: cornerRadius))
        } else {
            self.background(style.material, in: RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
        }
    }

    @ViewBuilder
    func vaultProminentButton() -> some View {
        if #available(iOS 26, *) {
            self.buttonStyle(.glassProminent)
        } else {
            self.buttonStyle(.borderedProminent)
        }
    }

    @ViewBuilder
    func vaultGlassButton() -> some View {
        if #available(iOS 26, *) {
            self.buttonStyle(.glass)
        } else {
            self.buttonStyle(.bordered)
        }
    }
}

struct VaultCard<Content: View>: View {
    var cornerRadius: CGFloat = 16
    var style: VaultGlassStyle = .regular
    @ViewBuilder var content: () -> Content

    var body: some View {
        content()
            .padding(20)
            .frame(maxWidth: .infinity, alignment: .leading)
            .vaultGlass(cornerRadius: cornerRadius, style: style)
    }
}
