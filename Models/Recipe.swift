import Foundation

/// Raw values are written to the save file, so they are part of the on-disk
/// format and must not be renamed once shipped.
enum RecipeID: String, Codable, CaseIterable, Sendable {
    case chocolateChipCookie
    case croissant
    case bread
    case chocolateDonut
    case fruitTart
    case cake
}

/// Static app content. Unlock state is deliberately not a field here — it is
/// user data and lives in `ProgressState`, which is what keeps the permanent
/// recipe book separable from everything that resets.
struct Recipe: Identifiable, Hashable, Sendable {
    let id: RecipeID
    let name: String
    /// Texture in `Resources/Treats.atlas` (spec 14).
    let spriteName: String

    var price: Int { Economy.price(for: id) }
}

enum RecipeCatalog {
    /// The only recipe unlocked on a fresh install (spec 07).
    static let starter: RecipeID = .chocolateChipCookie

    /// Sprite names track the treats the atlas pipeline already slices. Spec 07
    /// asks for recipes chosen from what the pack renders well at 32x32 rather
    /// than names picked first, and marks the final set as still open.
    static func recipe(for id: RecipeID) -> Recipe {
        switch id {
        case .chocolateChipCookie:
            Recipe(id: id, name: "Chocolate Chip Cookie", spriteName: "cookie")
        case .croissant:
            Recipe(id: id, name: "Croissant", spriteName: "croissant")
        case .bread:
            Recipe(id: id, name: "Sourdough Loaf", spriteName: "bread")
        case .chocolateDonut:
            Recipe(id: id, name: "Chocolate Donut", spriteName: "donut_chocolate")
        case .fruitTart:
            Recipe(id: id, name: "Fruit Tart", spriteName: "tart")
        case .cake:
            Recipe(id: id, name: "Celebration Cake", spriteName: "cake")
        }
    }

    static let all: [Recipe] = RecipeID.allCases.map(recipe(for:))
}
