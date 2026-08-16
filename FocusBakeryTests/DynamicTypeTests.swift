import CoreGraphics
import SwiftUI
import Testing
@testable import FocusBakery

/// Spec 13's Dynamic Type criterion, which is really two claims: chrome text
/// grows with the reader's text size, and growing it never costs the bakery any
/// room.
///
/// The second is structural rather than measured — `ChromeLayout` takes a size
/// and two safe-area insets and nothing else, so the scene's rect cannot depend
/// on text size. What is left to check is that the tray never *needs* to grow:
/// its row is authored deep enough and wide enough to hold the largest step, on
/// the narrowest phone, with the busiest numbers the app can put in it.
@Suite("Dynamic Type")
struct DynamicTypeTests {
    @Test("Chrome text steps by whole pixels, once, and stops")
    func magnificationStepsRatherThanScales() {
        let base = PixelGrid.chromeScale
        // Everything up to the default size is the room's own magnification, so
        // a chrome pixel and a room pixel are the same physical size (01).
        for size in [DynamicTypeSize.xSmall, .small, .medium, .large] {
            #expect(ChromeFont.magnification(base, at: size) == base, "\(size)")
        }
        // Above it, exactly one step — and never a second one, because ×4 no
        // longer fits the tray (asserted below) and the grid offers nothing in
        // between.
        for size in [DynamicTypeSize.xLarge, .xxxLarge, .accessibility1, .accessibility5] {
            #expect(ChromeFont.magnification(base, at: size) == base + 1, "\(size)")
        }
    }

    /// The measurement the bound above rests on. `BitmapFont.scene` is
    /// rasterized from the very TTF the chrome draws with, and `ChromeFontTests`
    /// proves the two measure a string identically — so this is the real width
    /// of the real glyphs, not an estimate.
    @Test("The tray's readouts fit their row at the largest text size")
    func theTrayHoldsTheLargestText() {
        let font = BitmapFont.scene
        let scale = ChromeFont.magnification(at: .accessibility5)
        let icon = CGFloat(PixelGrid.chromeScale)

        // The busiest the tray gets: a four-figure balance beside a
        // three-figure streak.
        func text(_ string: String) -> CGFloat {
            CGFloat(font.width(of: string) * scale)
        }
        // Icons keep the room's magnification whatever the text does.
        let coinIcon = 10 * icon
        let flameIcon = 10 * icon
        let gear = ChromeLayout.minimumTarget
        // BakeryChromeView: HStack(spacing: 20) over four children, each readout
        // an HStack(spacing: 8) of icon and number, and a Spacer(minLength: 12).
        let demand = (coinIcon + 8 + text("9999"))
            + 20 + (flameIcon + 8 + text("999"))
            + 20 + 12
            + 20 + gear

        for (name, size, top) in [
            ("iPhone SE (2nd/3rd gen)", CGSize(width: 375, height: 667), CGFloat(20)),
            ("iPhone 13 mini", CGSize(width: 375, height: 812), 50),
            ("iPhone 16", CGSize(width: 393, height: 852), 62),
            ("iPhone 16 Pro Max", CGSize(width: 440, height: 956), 62),
        ] {
            let chrome = ChromeLayout(size: size, safeAreaTop: top, safeAreaBottom: 34)
            #expect(chrome.content.width >= demand,
                    "\(name): the tray needs \(demand)pt and has \(chrome.content.width)pt")
            #expect(chrome.content.height >= CGFloat(font.cellHeight * scale),
                    "\(name): the tray's row is shorter than a glyph at ×\(scale)")
        }
    }

    /// The other half of the bound, kept honest: a second step would not fit, so
    /// `magnification` stopping where it does is a measurement rather than a
    /// preference. If the tray ever gets roomier this fails, which is the
    /// prompt to let the ladder go further.
    @Test("A second step would not fit the narrowest tray")
    func theBoundIsMeasuredRatherThanChosen() {
        let font = BitmapFont.scene
        let overstep = ChromeFont.magnification(at: .accessibility5) + 1
        let demand = (10 * CGFloat(PixelGrid.chromeScale) + 8 + CGFloat(font.width(of: "9999") * overstep))
            + 20 + (10 * CGFloat(PixelGrid.chromeScale) + 8 + CGFloat(font.width(of: "999") * overstep))
            + 20 + 12
            + 20 + ChromeLayout.minimumTarget

        let narrowest = ChromeLayout(
            size: CGSize(width: 375, height: 667),
            safeAreaTop: 20,
            safeAreaBottom: 0
        )
        #expect(demand > narrowest.content.width,
                "×\(overstep) now fits the SE's tray — the ladder can go further")
    }

    /// The scene's geometry has no text-size input at all, which is what makes
    /// "chrome does not crowd the bakery" structural rather than a placement to
    /// keep re-checking. Asserted the only way a type-safe language lets you:
    /// the same inputs give the same room, and the tray's depth is fixed.
    @Test("The room is the same size whatever the reader's text size is")
    func theRoomDoesNotMoveWithTextSize() {
        let chrome = ChromeLayout(size: CGSize(width: 393, height: 852), safeAreaTop: 62, safeAreaBottom: 34)
        let again = ChromeLayout(size: CGSize(width: 393, height: 852), safeAreaTop: 62, safeAreaBottom: 34)
        #expect(chrome == again)
        // And the tray is authored in art pixels, not in text metrics: its depth
        // is the readout row plus the lip, both constants.
        #expect(chrome.tray.height == chrome.scene.minY)
        #expect(RoomLayout(fitting: chrome.scene.size).scale == PixelGrid.chromeScale)
    }
}
