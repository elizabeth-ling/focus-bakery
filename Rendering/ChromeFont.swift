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
    /// Always a fixed size, because a fractional one puts glyph edges between
    /// pixels. Responding to the reader's text size is `magnification`'s job —
    /// it picks *which* whole number, and this still draws a whole one.
    static func pixel(_ scale: Int = PixelGrid.chromeScale) -> Font {
        .custom(name, fixedSize: CGFloat(artPixelsPerEm * scale))
    }

    /// Spec 13's Dynamic Type answer, and spec 01's open question closed: the
    /// chrome tier responds to text size by **stepping** its magnification, not
    /// by scaling it.
    ///
    /// There is exactly one step, and the bound is measured rather than chosen.
    /// At ×3 the tray's readouts still fit their row on the narrowest supported
    /// phone; at ×4 they do not, and the pixel grid offers nothing in between.
    /// So chrome text grows by half again and stops, which is real support and
    /// is also less than a low-vision reader asking for AX5 wants — the honest
    /// trade a pixel tier makes, recorded in 13 rather than hidden here.
    ///
    /// Only text steps. Icons stay at `PixelGrid.chromeScale`, so a chrome art
    /// pixel and a room art pixel remain the same physical size (01); it is the
    /// text the reader asked to be bigger.
    static func magnification(
        _ base: Int = PixelGrid.chromeScale,
        at size: DynamicTypeSize
    ) -> Int {
        size >= .xLarge ? base + 1 : base
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

/// Chrome text at whatever whole magnification the reader's text size asks for.
///
/// A modifier rather than a call to `ChromeFont.pixel()` because the size lives
/// in the environment, and the surfaces that use it — the tray, the settings
/// sheet, the display-case sheet — would otherwise each have to thread it down
/// by hand. The recipe book deliberately does not use this (10, 13): its page is
/// authored art at a fixed size and its text is printed on that page, so there
/// is nothing for larger text to reflow into.
private struct PixelFont: ViewModifier {
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    let base: Int

    func body(content: Content) -> some View {
        content.font(ChromeFont.pixel(ChromeFont.magnification(base, at: dynamicTypeSize)))
    }
}

extension View {
    func pixelFont(_ base: Int = PixelGrid.chromeScale) -> some View {
        modifier(PixelFont(base: base))
    }
}
