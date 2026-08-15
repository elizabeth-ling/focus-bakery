import SpriteKit
import SwiftUI

/// The atlases the app ships. Closed on purpose: a texture that is not in one
/// of these has not been through the pipeline.
enum PixelAtlas: String, CaseIterable {
    case baker = "Baker"
    case bakery = "Bakery"
    case treats = "Treats"
    case font = "Font"
    /// Authored chrome (tools/ui), not pack art — the one atlas that is
    /// committed alongside the font.
    case ui = "UI"
}

/// The single texture load path.
///
/// Spec 01 rule 2 is nearest-neighbour everywhere, and the way to hold that is
/// to leave exactly one place where an `SKTexture` comes into existence.
/// `SKTexture(imageNamed:)` anywhere else in the app is a bug: its default is
/// linear filtering, which blurs every edge in the room.
@MainActor
enum PixelTexture {
    static func named(_ name: String, in atlas: PixelAtlas) -> SKTexture {
        let texture = loaded(atlas).textureNamed(name)
        texture.filteringMode = .nearest
        return texture
    }

    /// Frame names in an atlas, sorted. Animation strips are numbered by the
    /// slicer (14), so sorted order is frame order.
    static func names(in atlas: PixelAtlas, prefix: String = "") -> [String] {
        loaded(atlas).textureNames.filter { $0.hasPrefix(prefix) }.sorted()
    }

    private static var atlases: [PixelAtlas: SKTextureAtlas] = [:]

    private static func loaded(_ atlas: PixelAtlas) -> SKTextureAtlas {
        if let cached = atlases[atlas] { return cached }
        let opened = SKTextureAtlas(named: atlas.rawValue)
        atlases[atlas] = opened
        return opened
    }
}

/// Pixel art in SwiftUI chrome.
///
/// The SwiftUI half of rule 2 — `.interpolation(.none)` — plus rule 1: the
/// image is sized to a whole multiple of its own pixels, so chrome art is
/// magnified by the same kind of whole number the room uses.
struct PixelImage: View {
    let name: String
    let atlas: PixelAtlas
    var scale: Int = PixelGrid.chromeScale

    var body: some View {
        let texture = PixelTexture.named(name, in: atlas)
        let size = texture.size()

        Image(decorative: texture.cgImage(), scale: 1)
            .interpolation(.none)
            .antialiased(false)
            .resizable()
            .frame(width: size.width * CGFloat(scale), height: size.height * CGFloat(scale))
    }
}
