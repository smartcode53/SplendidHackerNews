import SwiftUI
import UIKit

struct ReaderTypography {
    let fontScale: Double
    let lineSpacing: Double

    private var clampedScale: Double {
        min(max(fontScale, 0.9), 1.3)
    }

    var clampedLineSpacing: CGFloat {
        CGFloat(min(max(lineSpacing, 0), 6))
    }

    var bodyFont: Font {
        .system(size: 17 * clampedScale)
    }

    var bodyUIFont: UIFont {
        UIFont.systemFont(ofSize: 17 * clampedScale)
    }

    var quoteFont: Font {
        bodyFont
    }

    var quoteUIFont: UIFont {
        bodyUIFont
    }

    var codeFont: Font {
        .system(size: 15 * clampedScale, design: .monospaced)
    }

    var codeUIFont: UIFont {
        UIFont.monospacedSystemFont(ofSize: 15 * clampedScale, weight: .regular)
    }

    func headingFont(level: Int) -> Font {
        .system(size: headingSize(for: level) * clampedScale, weight: .semibold)
    }

    func headingUIFont(level: Int) -> UIFont {
        UIFont.systemFont(ofSize: headingSize(for: level) * clampedScale, weight: .semibold)
    }

    private func headingSize(for level: Int) -> CGFloat {
        switch level {
        case 1:
            return 26
        case 2:
            return 22
        case 3:
            return 20
        case 4:
            return 18
        default:
            return 17
        }
    }
}
