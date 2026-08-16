import SwiftUI

/// Spec 06's persistent chrome: the few things the room cannot say about itself.
///
/// A pure view — it reads no state and decides nothing. The shell hands down
/// numbers and takes back taps, which is the same boundary the scene has (05),
/// applied to the half of the screen that is SwiftUI.
///
/// Every element here covers part of the bakery, so the list is short and each
/// entry has to earn its place. The coin balance is chrome rather than in-scene
/// bitmap text: it belongs inside the safe area, where the room's top row is
/// not, and sprite digits do not exist to VoiceOver at all (13). The recipe book
/// is deliberately absent — the "+" *is* the way into it (10), and two controls
/// opening one modal would be two things covering the room instead of one.
struct BakeryChromeView: View {
    let coins: Int
    let streak: Int
    let onSettings: () -> Void

    var body: some View {
        HStack(spacing: 20) {
            readout("coin", value: "\(coins)")
                .accessibilityLabel("Coins")
                .accessibilityValue("\(coins)")
            streakReadout
            Spacer(minLength: 12)
            settingsButton
        }
    }

    private func readout(_ icon: String, value: String, dimmed: Bool = false) -> some View {
        HStack(spacing: 8) {
            PixelImage(name: icon, atlas: .ui)
                // Drained rather than greyed out: enough colour left to still
                // be a flame, per-pixel so it stays on the grid (01, 10).
                .saturation(dimmed ? 0.3 : 1)
                .opacity(dimmed ? 0.45 : 1)
            if !value.isEmpty {
                // Cream and unshadowed. A one-pixel drop shadow is the usual
                // way to hold text over busy art, but this font's counters are
                // a pixel or two wide at chrome scale, so the shadow shows
                // through them and a "0" fills in to a blob — checked on the
                // simulator, which is the only place it shows.
                Text(value)
                    .font(ChromeFont.pixel())
                    .foregroundStyle(PixelInk.cream)
            }
        }
        .accessibilityElement(children: .ignore)
    }

    /// A streak of nothing is an unlit flame and no number. Spec 11 asks day one
    /// to read as an invitation, and a chrome "0" beside a coin count reads as a
    /// scold — the same sprite drained of colour says "not yet" instead.
    private var streakReadout: some View {
        readout("icon_flame", value: streak > 0 ? "\(streak)" : "", dimmed: streak == 0)
            .accessibilityLabel("Streak")
            .accessibilityValue(streakDescription)
    }

    private var streakDescription: String {
        switch streak {
        case 0: "No streak yet"
        case 1: "1 day"
        default: "\(streak) days"
        }
    }

    private var settingsButton: some View {
        Button(action: onSettings) {
            PixelImage(name: "icon_gear", atlas: .ui)
                .frame(width: ChromeLayout.minimumTarget, height: ChromeLayout.minimumTarget)
                .contentShape(Rectangle())
        }
        .buttonStyle(PressedPixelButtonStyle())
        .accessibilityLabel("Settings")
    }
}

/// The one control floating over the room (spec 06), showing whichever of its
/// two states the app is in. It is never disabled-but-present: mid-bake the "+"
/// is *gone*, replaced by the way out, so the "one session at a time" rule (02)
/// is visible rather than discovered by tapping.
struct BakeryActionButton: View {
    let action: MainScreenAction
    let onStart: () -> Void
    let onStop: () -> Void

    var body: some View {
        switch action {
        case .start:
            button("button_bake", label: "Start a bake", perform: onStart)
        case .stop:
            button("button_stop", label: "Stop baking", perform: onStop)
        case .none:
            EmptyView()
        }
    }

    private func button(_ art: String, label: String, perform: @escaping () -> Void) -> some View {
        Button(action: perform) {
            PixelImage(name: art, atlas: .ui)
                .contentShape(Rectangle())
        }
        .buttonStyle(PressedPixelButtonStyle())
        .accessibilityLabel(label)
    }
}
