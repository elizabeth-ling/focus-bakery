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
    /// asks for recipes chosen from what the pack renders well at 16x16 rather
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

/// One row of the recipe book.
///
/// The book is the whole catalogue rather than the unlocked slice: spec 07
/// wants locked recipes visible with their price, because a goal you cannot see
/// is not a goal. `coinsShort` is carried rather than left to the caller so the
/// shortfall can be *said* — spec 07 asks that an unaffordable recipe be
/// explained, not just rendered as a dead control.
struct RecipeBookEntry: Identifiable, Hashable, Sendable {
    let recipe: Recipe
    let isUnlocked: Bool
    /// Coins still needed to afford this recipe. Zero when it is already owned
    /// or the balance covers it.
    let coinsShort: Int

    var id: RecipeID { recipe.id }
    var isAffordable: Bool { coinsShort == 0 }
}

/// Why a purchase did or did not happen.
///
/// Three cases rather than a `Bool` for the same reason: "no" and "no, and here
/// is how much you are short" are different things to a user, and only one of
/// them can be explained.
enum PurchaseResult: Equatable, Sendable {
    case bought
    case alreadyOwned
    /// The wallet and the book are both untouched.
    case insufficientFunds(coinsShort: Int)
}
