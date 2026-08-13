import CoreText
import OSLog
import SwiftUI

/// The chrome text tier: the bundled pixel TTF, for settings and menus.
///
/// Spec 01 allows this tier to be convenient rather than grid-perfect, because
/// the system lays it out. What it does not allow is the two tiers sitting next
/// to each other — crisp bitmap digits beside a system-positioned label is the
/// mismatch the spec calls jarring. In-scene text is `BitmapTextNode`; this is
/// for everything off-scene.
///
/// Both tiers are the same file: `tools/font/build_font.py` rasterizes the
/// bitmap atlas from this very TTF and then copies it into `Resources/`.
enum ChromeFont {
    /// PostScript name of the bundled pack font.
    static let name = "PxPlus_IBM_CGA"

    /// The em is the font's full 8-row cell, so a size of 8 × N points renders
    /// one art pixel as exactly N points.
    static let artPixelsPerEm = 8

    /// The chrome font at a whole-number magnification of its own pixels.
    ///
    /// Fixed rather than Dynamic-Type-scaled: a fractional size puts glyph
    /// edges between pixels. Spec 13 owns whether accessibility text sizes
    /// override that, and it is a real trade-off, not an oversight.
    static func pixel(_ scale: Int = PixelGrid.chromeScale) -> Font {
        .custom(name, fixedSize: CGFloat(artPixelsPerEm * scale))
    }

    /// Registered at runtime rather than through `UIAppFonts`, so the font
    /// working depends on the file being in the bundle and nothing else.
    @discardableResult
    static func register() -> Bool { registered }

    private static let registered: Bool = {
        let logger = Logger(subsystem: "com.focusbakery.FocusBakery", category: "rendering")
        guard let url = Bundle.main.url(forResource: name, withExtension: "ttf") else {
            logger.error("\(name, privacy: .public).ttf is not in the bundle; chrome falls back to a system font")
            return false
        }

        var error: Unmanaged<CFError>?
        guard CTFontManagerRegisterFontsForURL(url as CFURL, .process, &error) else {
            let reason = error?.takeRetainedValue().localizedDescription ?? "unknown"
            logger.error("Could not register \(name, privacy: .public): \(reason, privacy: .public)")
            return false
        }
        return true
    }()
}
