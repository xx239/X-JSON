import AppKit
import SwiftUI

enum AppTypography {
    static func nsMonoFont(family: AppFontFamily, size: CGFloat, weight: NSFont.Weight = .regular) -> NSFont {
        let effectiveWeight = strongerWeight(weight, than: preferredSystemWeight(for: family))

        if let customName = family.nsFontName, let custom = NSFont(name: customName, size: size) {
            return customWithWeightIfNeeded(custom, minimumWeight: effectiveWeight)
        }
        return NSFont.monospacedSystemFont(ofSize: size, weight: effectiveWeight)
    }

    static func monoFont(family: AppFontFamily, size: CGFloat, weight: NSFont.Weight = .regular) -> Font {
        Font(nsMonoFont(family: family, size: size, weight: weight))
    }

    private static func preferredSystemWeight(for family: AppFontFamily) -> NSFont.Weight {
        switch family {
        case .systemMonospaced:
            return .regular
        case .systemMonospacedSemibold:
            return .semibold
        case .systemMonospacedBold:
            return .bold
        case .menlo, .menloBold, .monaco, .courierNew, .courierNewBold:
            return .regular
        }
    }

    private static func strongerWeight(_ first: NSFont.Weight, than second: NSFont.Weight) -> NSFont.Weight {
        first.rawValue >= second.rawValue ? first : second
    }

    private static func customWithWeightIfNeeded(_ font: NSFont, minimumWeight: NSFont.Weight) -> NSFont {
        guard minimumWeight.rawValue >= NSFont.Weight.semibold.rawValue else {
            return font
        }
        let converted = NSFontManager.shared.convert(font, toHaveTrait: .boldFontMask)
        return converted
    }
}
