import SwiftUI

/// The recipe-book timer modal (spec 10): grandma's book over the dimmed room,
/// arrows turning pages through the whole catalogue, and one action per page —
/// a duration to start on a recipe you own, a price to buy on one you do not.
///
/// A pure view: the caller passes the book and where to open, and receives one
/// start, one purchase, or the dismissal. Every string in it is the chrome TTF —
/// the modal is SwiftUI chrome, so that is its single text tier (spec 01).
struct RecipeBookModalView: View {
    let entries: [RecipeBookEntry]
    let coinBalance: Int
    let onStart: (RecipeID, Int) -> Void
    let onPurchase: (RecipeID) -> Void
    let onDismiss: () -> Void

    @State private var recipeID: RecipeID
    @State private var minutes: Int
    @State private var isConfirmingPurchase = false

    init(
        entries: [RecipeBookEntry],
        coinBalance: Int,
        initialRecipeID: RecipeID,
        initialMinutes: Int,
        onStart: @escaping (RecipeID, Int) -> Void,
        onPurchase: @escaping (RecipeID) -> Void,
        onDismiss: @escaping () -> Void
    ) {
        self.entries = entries
        self.coinBalance = coinBalance
        self.onStart = onStart
        self.onPurchase = onPurchase
        self.onDismiss = onDismiss
        _recipeID = State(initialValue: initialRecipeID)
        // Clamped here as well as at the source: this is the input layer the
        // timer trusts (specs 03, 10), so it vouches for its own value.
        _minutes = State(initialValue: BakeDuration.clamped(initialMinutes))
    }

    /// Steps through every page, locked ones included, wrapping at either end.
    /// A locked recipe is a page of the book like any other — a goal you cannot
    /// browse to is not a goal (specs 07, 10).
    static func cycled(from current: RecipeID, by delta: Int, in book: [RecipeBookEntry]) -> RecipeID {
        guard !book.isEmpty else { return current }
        let index = book.firstIndex { $0.id == current } ?? 0
        let count = book.count
        return book[((index + delta) % count + count) % count].id
    }

    /// The page being shown. The fallback keeps this a total function for a
    /// caller that hands over a book the current recipe is not in; the store's
    /// `recipeBook` is always the whole catalogue, so it does not arise there.
    private var entry: RecipeBookEntry {
        entries.first { $0.id == recipeID } ?? {
            let recipe = RecipeCatalog.recipe(for: recipeID)
            return RecipeBookEntry(
                recipe: recipe,
                isUnlocked: false,
                coinsShort: max(0, recipe.price - coinBalance)
            )
        }()
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
        .confirmationDialog(
            entry.isAffordable ? "Buy this recipe?" : "Not enough coins",
            isPresented: $isConfirmingPurchase,
            titleVisibility: .visible
        ) {
            // Spec 07 asks that spending earned currency feel deliberate, so the
            // buy is confirmed rather than done on the first tap, and a short
            // balance opens this same sheet to be *explained* rather than
            // leaving a dead control on the page.
            if entry.isAffordable {
                Button("Bake it forever") { onPurchase(recipeID) }
                Button("Not yet", role: .cancel) {}
            } else {
                Button("OK", role: .cancel) {}
            }
        } message: {
            Text(purchaseExplanation)
        }
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
                // Two spacers rather than one, so the slack falls either side
                // of the treat and it sits between the name and the controls
                // instead of riding up under the title.
                Spacer(minLength: 14)
                recipeRow
                Spacer(minLength: 8)
                controls
            }
            // Insets place the content on the drawn page, clear of the cover,
            // the ribbon and the page-stack edges.
            .padding(EdgeInsets(top: 26, leading: 36, bottom: 52, trailing: 44))
        }
        .frame(width: 320, height: 480)
    }

    private var title: some View {
        Text(entry.recipe.name)
            .font(ChromeFont.pixel())
            .foregroundStyle(PixelInk.heading)
            .multilineTextAlignment(.center)
            // Two lines are reserved whether or not the name needs them, so
            // paging between short and long names never reflows the page.
            .frame(height: 40)
    }

    private var recipeRow: some View {
        HStack(spacing: 0) {
            pageArrow("arrow_left", by: -1, label: "Previous recipe")
            Spacer(minLength: 0)
            treat
            Spacer(minLength: 0)
            pageArrow("arrow_right", by: 1, label: "Next recipe")
        }
    }

    /// A locked treat is dimmed and drained of its colour under a gold padlock:
    /// recognisably the thing you are working towards, unmistakably not yours
    /// yet. The filters are per-pixel, so the art stays on its grid.
    private var treat: some View {
        ZStack {
            PixelImage(name: entry.recipe.spriteName, atlas: .treats, scale: 8)
                .saturation(entry.isUnlocked ? 1 : 0.45)
                .colorMultiply(entry.isUnlocked ? .white : Color(white: 0.72))
            if !entry.isUnlocked {
                PixelImage(name: "lock_gold", atlas: .ui, scale: 4)
            }
        }
        .accessibilityElement()
        .accessibilityLabel(entry.isUnlocked ? entry.recipe.name : "\(entry.recipe.name), locked")
    }

    private func pageArrow(_ name: String, by delta: Int, label: String) -> some View {
        Button {
            recipeID = Self.cycled(from: recipeID, by: delta, in: entries)
        } label: {
            PixelImage(name: name, atlas: .ui)
                .frame(width: 44, height: 44)
                .contentShape(Rectangle())
        }
        .buttonStyle(PressedPixelButtonStyle())
        .accessibilityLabel(label)
    }

    /// The bottom of the page: the stepper and the start on a recipe you own,
    /// the price and the buy on one you do not. Both variants sit in a block of
    /// the same height, so turning to a locked page swaps the controls without
    /// shifting the treat above them.
    private var controls: some View {
        VStack(spacing: 0) {
            if entry.isUnlocked {
                durationRow
                startButton
                    .padding(.top, 16)
            } else {
                purchaseButton
                balance
                    .padding(.top, 8)
            }
        }
        .frame(height: 108, alignment: .top)
    }

    private var durationRow: some View {
        HStack(spacing: 14) {
            stepperButton("stepper_minus", by: -BakeDuration.stepMinutes, label: "Shorter bake")
            Text("\(minutes) min")
                .font(ChromeFont.pixel(3))
                .foregroundStyle(PixelInk.heading)
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

    private var startButton: some View {
        Button {
            onStart(recipeID, minutes)
        } label: {
            ZStack {
                PixelImage(name: "button_start", atlas: .ui)
                Text("Start baking")
                    .font(ChromeFont.pixel())
                    .foregroundStyle(PixelInk.cream)
            }
        }
        .buttonStyle(PressedPixelButtonStyle())
    }

    /// Brass, like the lock over the treat and the coin on its face: gold is
    /// what a locked page is worth, and leather is what starts a bake.
    private var purchaseButton: some View {
        Button {
            isConfirmingPurchase = true
        } label: {
            ZStack {
                PixelImage(name: "button_buy", atlas: .ui)
                HStack(spacing: 8) {
                    Text("Buy for")
                    PixelImage(name: "coin", atlas: .ui)
                    Text("\(entry.recipe.price)")
                }
                .font(ChromeFont.pixel())
                .foregroundStyle(PixelInk.heading)
            }
        }
        .buttonStyle(PressedPixelButtonStyle())
        .accessibilityLabel("Buy for \(entry.recipe.price) coins")
    }

    private var balance: some View {
        Text(entry.isAffordable
             ? "You have \(coinBalance) coins"
             : "\(entry.coinsShort) more to go")
            .font(ChromeFont.pixel())
            .foregroundStyle(PixelInk.body)
    }

    /// Numbers are formatted rather than interpolated raw: the page's own
    /// `Text` groups them by locale, and a sheet that said "1000" beside a page
    /// saying "1,000" would look like two different amounts.
    private var purchaseExplanation: String {
        let opening = """
            \(entry.recipe.name) costs \(entry.recipe.price.formatted()) coins. \
            You have \(coinBalance.formatted())
            """
        return entry.isAffordable
            ? "\(opening)."
            : "\(opening) — \(entry.coinsShort.formatted()) more to go."
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

/// Presses darken the art in place. No motion: a scaling pixel sprite would
/// break the whole-pixel rule mid-animation for nothing.
private struct PressedPixelButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .opacity(configuration.isPressed ? 0.6 : 1)
    }
}
