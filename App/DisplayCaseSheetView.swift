import SwiftUI

/// Today's bakes, listed (spec 08).
///
/// The room shows the case; this shows the truth about it. The shelf has a
/// fixed number of slots and reports quantities as ♦ counts in bitmap text,
/// which stops being readable when the case is busy and does not exist at all
/// to VoiceOver — so the tally lives here too, in chrome, in the pixel TTF
/// tier (01, 13).
///
/// It takes the whole day rather than a list and a number, so the count it
/// shows cannot drift from the record it came from however full the case is.
struct DisplayCaseSheetView: View {
    let day: DisplayCaseDay
    let onDismiss: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            header
            if day.isEmpty {
                emptyState
            } else {
                filled
            }
        }
        .background(PixelInk.paper)
        .presentationDetents([.medium, .large])
        .presentationDragIndicator(.visible)
    }

    /// The total sits here rather than under the list because it is the sheet's
    /// whole promise: it is the true tally whatever the case in the room had
    /// room to show, so it must not be something you have to scroll to find.
    private var header: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(alignment: .firstTextBaseline) {
                // Wraps rather than truncates: at the largest text size the
                // title and "Done" no longer share a line on the narrowest
                // phone, and a clipped heading is the failure spec 13 names.
                Text("Today's Bakes")
                    .pixelFont()
                    .foregroundStyle(PixelInk.heading)
                    .fixedSize(horizontal: false, vertical: true)
                Spacer(minLength: 12)
                Button("Done", action: onDismiss)
                    .pixelFont()
                    .foregroundStyle(PixelInk.heading)
            }
            .accessibilityAddTraits(.isHeader)

            if !day.isEmpty {
                Text(day.totalCount == 1 ? "1 treat today" : "\(day.totalCount) treats today")
                    .pixelFont()
                    .foregroundStyle(PixelInk.body)
            }
        }
        .padding(.horizontal, 20)
        .padding(.top, 20)
        .padding(.bottom, 12)
    }

    private var filled: some View {
        ScrollView {
            VStack(spacing: 0) {
                ForEach(day.tallies) { tally in
                    row(tally)
                }
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 24)
        }
    }

    private func row(_ tally: TreatTally) -> some View {
        let recipe = RecipeCatalog.recipe(for: tally.recipeID)
        return HStack(spacing: 16) {
            // A fixed column, because the treats are not all one tile wide —
            // the cake is two. Letting the art set the column would indent one
            // row's name past the others and squeeze its wrapping.
            PixelImage(name: recipe.spriteName, atlas: .treats)
                .frame(width: 64)
            Text(recipe.name)
                .pixelFont()
                .foregroundStyle(PixelInk.heading)
                .multilineTextAlignment(.leading)
            Spacer(minLength: 8)
            Text("x\(tally.count)")
                .pixelFont()
                .foregroundStyle(PixelInk.body)
        }
        .padding(.vertical, 14)
        // One element per treat rather than four fragments to swipe through,
        // and the quantity as a value so it is read as "how many" rather than
        // as more of the name (13).
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(recipe.name)
        .accessibilityValue("\(tally.count)")
    }

    /// A fresh morning, not an absence. The reset is the point of the display
    /// case and is never framed to the user as something lost (08, 11).
    private var emptyState: some View {
        VStack(spacing: 12) {
            Spacer(minLength: 20)
            Text("The case is clean and the oven is warm.")
                .pixelFont()
                .foregroundStyle(PixelInk.heading)
            Text("Today's bakes will fill it up.")
                .pixelFont()
                .foregroundStyle(PixelInk.body)
            Spacer(minLength: 20)
        }
        .multilineTextAlignment(.center)
        .padding(.horizontal, 28)
        .frame(maxWidth: .infinity)
        .accessibilityElement(children: .combine)
    }
}
