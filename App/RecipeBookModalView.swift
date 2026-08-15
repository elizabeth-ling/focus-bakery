import SwiftUI

/// The recipe-book timer modal (spec 10): grandma's book over the dimmed room,
/// arrows turning pages between unlocked recipes, a duration stepper, and one
/// start action.
///
/// A pure view: the caller passes the unlocked recipes and where to open, and
/// receives the start or the dismissal. Every string in it is the chrome TTF —
/// the modal is SwiftUI chrome, so that is its single text tier (spec 01).
struct RecipeBookModalView: View {
    let unlockedRecipes: [Recipe]
    let onStart: (RecipeID, Int) -> Void
    let onDismiss: () -> Void

    @State private var recipeID: RecipeID
    @State private var minutes: Int

    init(
        unlockedRecipes: [Recipe],
        initialRecipeID: RecipeID,
        initialMinutes: Int,
        onStart: @escaping (RecipeID, Int) -> Void,
        onDismiss: @escaping () -> Void
    ) {
        self.unlockedRecipes = unlockedRecipes
        self.onStart = onStart
        self.onDismiss = onDismiss
        _recipeID = State(initialValue: initialRecipeID)
        // Clamped here as well as at the source: this is the input layer the
        // timer trusts (specs 03, 10), so it vouches for its own value.
        _minutes = State(initialValue: BakeDuration.clamped(initialMinutes))
    }

    /// Steps through the unlocked recipes only, wrapping at either end — with
    /// two recipes both arrows still work, they just meet.
    static func cycled(from current: RecipeID, by delta: Int, in unlocked: [Recipe]) -> RecipeID {
        guard !unlocked.isEmpty else { return current }
        let index = unlocked.firstIndex { $0.id == current } ?? 0
        let count = unlocked.count
        return unlocked[((index + delta) % count + count) % count].id
    }

    private var recipe: Recipe {
        unlockedRecipes.first { $0.id == recipeID } ?? RecipeCatalog.recipe(for: recipeID)
    }

    var body: some View {
        ZStack {
            Color.black.opacity(0.55)
                .ignoresSafeArea()
                .onTapGesture(perform: onDismiss)
                .accessibilityHidden(true)
            page
        }
        .accessibilityAddTraits(.isModal)
    }

    private var page: some View {
        ZStack {
            PixelImage(name: "book_page", atlas: .ui)
            VStack(spacing: 0) {
                HStack {
                    closeButton
                    Spacer()
                }
                title
                    .padding(.top, 8)
                recipeRow
                    .padding(.top, 14)
                caption
                    .padding(.top, 10)
                Spacer(minLength: 8)
                durationRow
                payout
                    .padding(.top, 8)
                startButton
                    .padding(.top, 16)
            }
            // Insets place the content on the drawn page, clear of the cover,
            // the ribbon and the page-stack edges.
            .padding(EdgeInsets(top: 26, leading: 36, bottom: 52, trailing: 44))
        }
        .frame(width: 320, height: 480)
    }

    private var title: some View {
        Text(recipe.name)
            .font(ChromeFont.pixel())
            .foregroundStyle(BookInk.heading)
            .multilineTextAlignment(.center)
            // Two lines are reserved whether or not the name needs them, so
            // paging between short and long names never reflows the page.
            .frame(height: 40)
    }

    private var recipeRow: some View {
        HStack(spacing: 0) {
            pageArrow("arrow_left", by: -1, label: "Previous recipe")
            Spacer(minLength: 0)
            PixelImage(name: recipe.spriteName, atlas: .treats, scale: 8)
                .accessibilityLabel(recipe.name)
            Spacer(minLength: 0)
            pageArrow("arrow_right", by: 1, label: "Next recipe")
        }
    }

    /// With one unlocked recipe there are no pages to turn, so the arrows are
    /// not drawn at all — absent reads as intentional where disabled reads as
    /// broken (spec 11). The caption below carries the intent.
    @ViewBuilder
    private func pageArrow(_ name: String, by delta: Int, label: String) -> some View {
        if unlockedRecipes.count > 1 {
            Button {
                recipeID = Self.cycled(from: recipeID, by: delta, in: unlockedRecipes)
            } label: {
                PixelImage(name: name, atlas: .ui)
                    .frame(width: 44, height: 44)
                    .contentShape(Rectangle())
            }
            .buttonStyle(PressedPixelButtonStyle())
            .accessibilityLabel(label)
        } else {
            Color.clear.frame(width: 44, height: 44)
        }
    }

    private var caption: some View {
        Group {
            if unlockedRecipes.count > 1,
               let index = unlockedRecipes.firstIndex(where: { $0.id == recipeID }) {
                Text("Page \(index + 1) of \(unlockedRecipes.count)")
            } else {
                Text("Earn coins to\nfill the book")
            }
        }
        .font(ChromeFont.pixel())
        .foregroundStyle(BookInk.faded)
        .multilineTextAlignment(.center)
        // Two lines reserved either way, so the one-page book and the full
        // one lay the page out identically.
        .frame(height: 40)
    }

    private var durationRow: some View {
        HStack(spacing: 14) {
            stepperButton("stepper_minus", by: -BakeDuration.stepMinutes, label: "Shorter bake")
            Text("\(minutes) min")
                .font(ChromeFont.pixel(3))
                .foregroundStyle(BookInk.heading)
                .frame(width: 168)
            stepperButton("stepper_plus", by: BakeDuration.stepMinutes, label: "Longer bake")
        }
        .accessibilityElement(children: .contain)
        .accessibilityValue("\(minutes) minutes")
    }

    private func stepperButton(_ name: String, by delta: Int, label: String) -> some View {
        let target = BakeDuration.clamped(minutes + delta)
        return Button {
            minutes = target
        } label: {
            PixelImage(name: name, atlas: .ui)
                .frame(width: 44, height: 44)
                .contentShape(Rectangle())
        }
        .buttonStyle(PressedPixelButtonStyle())
        // At a bound the step has nowhere to go; showing that beats a silent
        // no-op. This is the whole of the min/max constraint (spec 10) — the
        // value can only ever move to a clamped target.
        .disabled(target == minutes)
        .opacity(target == minutes ? 0.35 : 1)
        .accessibilityLabel(label)
    }

    /// Duration drives coins (spec 07's banded curve), and the band arithmetic
    /// is not something to make the user infer — the payout for the current
    /// choice is simply written on the page.
    private var payout: some View {
        Text("earns \(Economy.coins(forCompletedMinutes: minutes)) coins")
            .font(ChromeFont.pixel())
            .foregroundStyle(BookInk.body)
    }

    private var startButton: some View {
        Button {
            onStart(recipeID, minutes)
        } label: {
            ZStack {
                PixelImage(name: "button_start", atlas: .ui)
                Text("Start baking")
                    .font(ChromeFont.pixel())
                    .foregroundStyle(BookInk.cream)
            }
        }
        .buttonStyle(PressedPixelButtonStyle())
    }

    private var closeButton: some View {
        Button(action: onDismiss) {
            PixelImage(name: "button_close", atlas: .ui)
                .frame(width: 44, height: 44, alignment: .topLeading)
                .contentShape(Rectangle())
        }
        .buttonStyle(PressedPixelButtonStyle())
        .accessibilityLabel("Close")
    }
}

/// Ink colours matching the authored page art (tools/ui/build_ui.py), so the
/// TTF text sits on the paper as if written there.
private enum BookInk {
    static let heading = Color(red: 0x38 / 255, green: 0x1A / 255, blue: 0x08 / 255)
    static let body = Color(red: 0x66 / 255, green: 0x45 / 255, blue: 0x1E / 255)
    static let faded = Color(red: 0xB9 / 255, green: 0x9E / 255, blue: 0x86 / 255)
    static let cream = Color(red: 0xF0 / 255, green: 0xEF / 255, blue: 0xDE / 255)
}

/// Presses darken the art in place. No motion: a scaling pixel sprite would
/// break the whole-pixel rule mid-animation for nothing.
private struct PressedPixelButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .opacity(configuration.isPressed ? 0.6 : 1)
    }
}
