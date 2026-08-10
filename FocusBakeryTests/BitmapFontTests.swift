import SpriteKit
import Testing
@testable import FocusBakery

/// These use `Font.atlas` throughout, never the pack atlases: the pack is
/// licensed and its slices are build artifacts (14), so a checkout without it
/// must still run green.
@MainActor
@Suite("Bitmap font")
struct BitmapFontTests {
    let font = BitmapFont.focusPixel

    @Test("The metrics load from the bundle")
    func metricsLoad() {
        #expect(font.ascent == 7)
        #expect(font.descent == 2)
        #expect(font.cellHeight == 9)
        #expect(font.glyphs.count > 70)
        #expect(font.glyph(for: "0") != nil)
        #expect(font.glyph(for: "★") != nil)
        #expect(font.glyph(for: "…") != nil)
    }

    @Test("Digits are all one width, so a counting timer does not jitter")
    func digitsAreMonospaced() {
        let widths = Set("0123456789".compactMap { font.glyph(for: $0)?.advance })
        #expect(widths.count == 1)
    }

    @Test("A string measures the sum of its advances without a trailing gap")
    func widthExcludesTrailingTracking() {
        let digit = font.glyph(for: "0")?.advance ?? 0
        let colon = font.glyph(for: ":")?.advance ?? 0

        #expect(font.width(of: "") == 0)
        #expect(font.width(of: "0") == digit - font.tracking)
        #expect(font.width(of: "00:00") == digit * 4 + colon - font.tracking)
    }

    @Test("Every glyph in the metrics has its texture in the atlas, at cell height")
    func metricsAndAtlasAgree() {
        for (character, glyph) in font.glyphs {
            guard let sprite = glyph.sprite else { continue }
            let size = PixelTexture.named(sprite, in: .font).size()

            #expect(
                size == CGSize(width: CGFloat(glyph.width), height: CGFloat(font.cellHeight)),
                "\(character) is \(size), expected \(glyph.width)×\(font.cellHeight)"
            )
        }
    }

    @Test("Textures load nearest-neighbour, never linear")
    func texturesFilterNearest() {
        for name in PixelTexture.names(in: .font).prefix(10) {
            let texture = PixelTexture.named(name, in: .font)
            #expect(texture.filteringMode == .nearest)
        }
    }

    @Test("A rendered string is one sprite per inked glyph on whole art pixels")
    func textNodeLaysOutOnTheGrid() {
        let node = BitmapTextNode("00:00", scale: 2)

        #expect(node.children.count == 5)
        #expect(node.size == CGSize(width: CGFloat(font.width(of: "00:00")) * 2, height: 18))

        for child in node.children {
            #expect(child.position.x.truncatingRemainder(dividingBy: 2) == 0)
            #expect(child.position.y == 0)
        }
    }

    @Test("Spaces advance the pen without drawing anything")
    func spacesDrawNothing() {
        let node = BitmapTextNode("a a", scale: 2)

        #expect(node.children.count == 2)
        #expect(node.size.width == CGFloat(font.width(of: "a a")) * 2)
    }

    @Test("Changing the text rebuilds the line")
    func settingTextRebuilds() {
        let node = BitmapTextNode("25:00", scale: 2)
        let before = node.size

        node.text = "24:59"
        #expect(node.children.count == 5)
        #expect(node.size == before)

        node.text = "1"
        #expect(node.children.count == 1)
        #expect(node.size.width < before.width)
    }

    @Test("Centring snaps to whole art pixels")
    func centringSnapsToTheGrid() {
        let node = BitmapTextNode("00:00", scale: 3)

        node.place(centeredOn: CGPoint(x: 196.5, y: 400.5))

        #expect(node.position.x.truncatingRemainder(dividingBy: 3) == 0)
        #expect(node.position.y.truncatingRemainder(dividingBy: 3) == 0)
        // Still within half a pixel of where it was asked to go.
        #expect(abs(node.position.x + node.size.width / 2 - 196.5) <= 1.5)
        #expect(abs(node.position.y - node.size.height / 2 - 400.5) <= 1.5)
    }

    @Test("An unknown character is skipped rather than drawn as a blank box")
    func unknownCharactersAreSkipped() {
        let node = BitmapTextNode("0\u{1F370}0", scale: 2)

        #expect(node.children.count == 2)
    }
}
