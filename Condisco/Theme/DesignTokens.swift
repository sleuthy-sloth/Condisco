import SwiftUI
import UIKit

/// Warm Studio design tokens for the Condisco learning experience.
/// Cream stock, one terracotta accent, hard offset shadows — never blur.
enum DesignTokens {
    // MARK: - Colors
    static let primary = Color(hex: 0xA8_511F)
    static let primaryStrong = Color(hex: 0x8F_4318)
    static let primarySoft = Color(hex: 0xF6_E3CD)
    static let canvas = Color(hex: 0xFB_F4E6)
    static let stock = Color(hex: 0xFF_FDF7)
    static let stock2 = Color(hex: 0xFD_F7EA)
    static let stock3 = Color(hex: 0xF2_EAD7)
    static let ink = Color(hex: 0x2F_2A24)
    static let inkDeep = Color(hex: 0x23_1E18)
    static let muted = Color(hex: 0x6B_5F4B)
    static let edge = Color(hex: 0x2F_2A24)
    static let edgeSoft = Color(hex: 0xE0_D3BA)
    static let correctFill = Color(hex: 0xE9_F0E2)
    static let correctLine = Color(hex: 0x2F_6B3F)
    static let attentionFill = Color(hex: 0xF7_ECE7)
    static let attentionLine = Color(hex: 0x8F_4B3A)
    static let attentionInk = Color(hex: 0x8F_4B3A)

    // MARK: - Type
    /// Display serif. Bundled Fraunces replaces this when the font files land.
    static func display(_ size: CGFloat, weight: Font.Weight = .semibold) -> Font {
        dynamicFont(size: size, weight: weight, design: .serif)
    }

    static func text(_ size: CGFloat, weight: Font.Weight = .regular) -> Font {
        dynamicFont(size: size, weight: weight, design: .default)
    }

    /// The design size, boosted by the in-app Larger text toggle, then scaled
    /// by the system Dynamic Type setting via UIFontMetrics — the app's type
    /// follows Settings → Display → Text Size like a good citizen.
    private static func dynamicFont(
        size: CGFloat, weight: Font.Weight, design: Font.Design
    ) -> Font {
        let base = A11ySettings.shared.largeText
            ? size * A11ySettings.largeTextScale : size
        return Font(UIFontMetrics.default.scaledFont(
            for: uiFont(size: base, weight: weight, design: design)))
    }

    private static func uiFont(
        size: CGFloat, weight: Font.Weight, design: Font.Design
    ) -> UIFont {
        let uiWeight: CGFloat = {
            switch weight {
            case .ultraLight: return UIFont.Weight.ultraLight.rawValue
            case .thin: return UIFont.Weight.thin.rawValue
            case .light: return UIFont.Weight.light.rawValue
            case .medium: return UIFont.Weight.medium.rawValue
            case .semibold: return UIFont.Weight.semibold.rawValue
            case .bold: return UIFont.Weight.bold.rawValue
            case .heavy: return UIFont.Weight.heavy.rawValue
            case .black: return UIFont.Weight.black.rawValue
            default: return UIFont.Weight.regular.rawValue
            }
        }()
        var descriptor = UIFontDescriptor.preferredFontDescriptor(
            withTextStyle: .body)
        if design == .serif, let serif = descriptor.withDesign(.serif) {
            descriptor = serif
        }
        descriptor = descriptor.addingAttributes([
            .traits: [UIFontDescriptor.TraitKey.weight: uiWeight]
        ])
        return UIFont(descriptor: descriptor, size: size)
    }
}

extension Color {
    init(hex: UInt32) {
        let r = Double((hex >> 16) & 0xFF) / 255
        let g = Double((hex >> 8) & 0xFF) / 255
        let b = Double(hex & 0xFF) / 255
        self.init(red: r, green: g, blue: b)
    }
}

/// A paper card: flat stock, ink edge, hard offset shadow. No blur, ever.
struct PaperCard<Content: View>: View {
    let content: Content

    init(@ViewBuilder content: () -> Content) {
        self.content = content()
    }

    var body: some View {
        content
            .padding(16)
            .background(DesignTokens.stock)
            .cornerRadius(10)
            .overlay(
                RoundedRectangle(cornerRadius: 10)
                    .stroke(DesignTokens.edge, lineWidth: 1.5)
            )
            .shadow(color: DesignTokens.ink, radius: 0, x: 4, y: 4)
    }
}

/// A quiet surface for information-heavy screens. The older paper treatment
/// remains available for lessons, while Home and You use less visual chrome.
struct QuietSurface<Content: View>: View {
    let content: Content

    init(@ViewBuilder content: () -> Content) {
        self.content = content()
    }

    var body: some View {
        content
            .padding(20)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(DesignTokens.stock)
            .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .stroke(DesignTokens.edgeSoft.opacity(0.65), lineWidth: 1)
            }
    }
}
