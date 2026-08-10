import OSLog
import SpriteKit

/// Metrics for the bitmap font, decoded from the `Font.json` that
/// `tools/font/build_font.py` writes beside the glyph atlas.
///
/// The metrics are data rather than constants in Swift because the glyphs are:
/// editing a glyph's width in `glyphs.py` must not require editing anything
/// here.
struct BitmapFont: Decodable, Sendable {
    struct Glyph: Decodable, Sendable {
        let character: String
        /// Absent for glyphs with no ink — a space is an advance and nothing else.
        let sprite: String?
        /// Ink width in art pixels.
        let width: Int
        /// Width plus tracking: how far the pen moves for this glyph.
        let advance: Int
    }

    let ascent: Int
    let descent: Int
    let tracking: Int
    let leading: Int
    let glyphs: [Character: Glyph]

    /// Rows in a glyph image. Every glyph is the full cell, so a line of text
    /// aligns from one common top edge.
    var cellHeight: Int { ascent + descent }
    var lineHeight: Int { cellHeight + leading }

    func glyph(for character: Character) -> Glyph? { glyphs[character] }

    /// Width of a rendered string in art pixels. The trailing tracking is not
    /// part of the string — counting it would offset every centred label by
    /// half a pixel.
    func width(of text: String) -> Int {
        let advances = text.reduce(0) { $0 + (glyph(for: $1)?.advance ?? 0) }
        return max(0, advances - (text.isEmpty ? 0 : tracking))
    }

    static let focusPixel: BitmapFont = load()

    private static func load() -> BitmapFont {
        let logger = Logger(subsystem: "com.focusbakery.FocusBakery", category: "rendering")
        guard let url = Bundle.main.url(forResource: "Font", withExtension: "json") else {
            logger.error("Font.json is not in the bundle; in-scene text will not draw")
            return BitmapFont()
        }
        do {
            return try JSONDecoder().decode(BitmapFont.self, from: Data(contentsOf: url))
        } catch {
            // Soft, like the stores in spec 02: a broken font should cost the
            // text, not the app. The tests are what stop it shipping broken.
            logger.error("Unreadable Font.json: \(error.localizedDescription, privacy: .public)")
            return BitmapFont()
        }
    }

    private init() {
        ascent = 7
        descent = 2
        tracking = 1
        leading = 2
        glyphs = [:]
    }

    private enum CodingKeys: String, CodingKey {
        case ascent, descent, tracking, leading, glyphs
    }

    init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        ascent = try container.decode(Int.self, forKey: .ascent)
        descent = try container.decode(Int.self, forKey: .descent)
        tracking = try container.decode(Int.self, forKey: .tracking)
        leading = try container.decode(Int.self, forKey: .leading)

        let listed = try container.decode([Glyph].self, forKey: .glyphs)
        glyphs = Dictionary(
            listed.compactMap { glyph in glyph.character.first.map { ($0, glyph) } },
            uniquingKeysWith: { first, _ in first }
        )
    }
}

/// A line of in-scene text, drawn as one sprite per glyph.
///
/// Spec 01 bans `SKLabelNode` for timer digits, coin counts and ★ quantities,
/// and this is the reason it can be banned: the text here is literally the same
/// pixels as the art, magnified by the same whole number, positioned on the
/// same grid. A system label would antialias and sub-pixel-position its glyphs
/// next to sprites that do neither.
@MainActor
final class BitmapTextNode: SKNode {
    private let font: BitmapFont
    private let pixelScale: Int
    private let tint: SKColor

    /// Rendered size in points. The node's own origin is its top-left corner.
    private(set) var size: CGSize = .zero

    var text: String {
        didSet {
            guard text != oldValue else { return }
            rebuild()
        }
    }

    init(
        _ text: String,
        scale: Int,
        color: SKColor = .white,
        font: BitmapFont = .focusPixel
    ) {
        self.text = text
        self.font = font
        pixelScale = scale
        tint = color
        super.init()
        rebuild()
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { fatalError("not used") }

    /// Centres the text on a point, snapped to the grid.
    ///
    /// Centring is where half pixels get in — an odd width halved is half a
    /// pixel — so it goes through here rather than through `position` directly.
    func place(centeredOn point: CGPoint) {
        position = CGPoint(
            x: PixelGrid.snap(point.x - size.width / 2, at: pixelScale),
            y: PixelGrid.snap(point.y + size.height / 2, at: pixelScale)
        )
    }

    private func rebuild() {
        removeAllChildren()

        let step = CGFloat(pixelScale)
        var pen = 0
        for character in text {
            guard let glyph = font.glyph(for: character) else { continue }
            if let sprite = glyph.sprite {
                let node = SKSpriteNode(texture: PixelTexture.named(sprite, in: .font))
                node.anchorPoint = CGPoint(x: 0, y: 1)
                node.size = CGSize(
                    width: CGFloat(glyph.width) * step,
                    height: CGFloat(font.cellHeight) * step
                )
                node.position = CGPoint(x: CGFloat(pen) * step, y: 0)
                node.color = tint
                node.colorBlendFactor = 1
                addChild(node)
            }
            pen += glyph.advance
        }

        size = CGSize(width: CGFloat(font.width(of: text)) * step, height: CGFloat(font.cellHeight) * step)
    }
}
