import UIKit
import Testing
@testable import FocusBakery

@MainActor
@Suite("Chrome font")
struct ChromeFontTests {
    @Test("The bundled TTF registers and resolves by name")
    func fontRegisters() {
        #expect(ChromeFont.register())

        let font = UIFont(name: ChromeFont.name, size: 18)
        #expect(font != nil)
        #expect(font?.familyName == "PxPlus IBM CGA")
    }

    @Test("Registering twice is harmless")
    func registeringIsIdempotent() {
        #expect(ChromeFont.register())
        #expect(ChromeFont.register())
    }

    @Test("At 8 × N points, one art pixel is N points")
    func emIsTheGlyphCell() throws {
        ChromeFont.register()
        let scale = 2
        let font = try #require(
            UIFont(name: ChromeFont.name, size: CGFloat(ChromeFont.artPixelsPerEm * scale))
        )
        let bitmap = BitmapFont.scene

        // The atlas is rasterized from this very TTF, so a string has to measure
        // the same in both tiers. NSString's width includes the last glyph's
        // trailing tracking, which the bitmap width deliberately drops.
        for text in ["00:00", "Settings", "baking…"] {
            let drawn = (text as NSString).size(withAttributes: [.font: font]).width
            let expected = CGFloat(bitmap.width(of: text) + bitmap.tracking) * CGFloat(scale)
            #expect(abs(drawn - expected) < 0.01, "\(text): \(drawn) vs \(expected)")
        }
    }
}
