import SwiftUI
import Testing
@testable import FocusBakery

/// Spec 13's contrast criterion: the 16-bit palette still has to clear contrast
/// requirements for text and controls.
///
/// Checkable arithmetic rather than a judgement, so a future palette tweak that
/// costs legibility fails here instead of shipping. WCAG 2.1 relative luminance,
/// and every pair `PixelInk` actually puts on screen — the palette is small
/// enough that "every pair" means the whole list.
@MainActor
@Suite("Palette contrast")
struct PaletteContrastTests {
    /// AA for body text is 4.5:1. The bar here is AAA, because the app is
    /// deliberately low-contrast in mood — warm ink on warm paper — and that is
    /// exactly the aesthetic that drifts into unreadable one shade at a time.
    private static let required = 7.0

    private static let pairs: [(String, Color, Color)] = [
        ("heading on paper", PixelInk.heading, PixelInk.paper),
        ("body on paper", PixelInk.body, PixelInk.paper),
        // The tray: cream readouts on the leather field (06).
        ("cream on leather", PixelInk.cream, PixelInk.leather),
        // The recipe book's page and its buy plate are the same paper and
        // leather, so the modal is covered by the two pairs above (10).
    ]

    @Test("Every ink the app puts on a surface clears AAA")
    func everyPairIsReadable() {
        for (name, ink, surface) in Self.pairs {
            let ratio = contrast(ink, surface)
            #expect(ratio >= Self.required,
                    "\(name) is \(String(format: "%.2f", ratio)):1, under \(Self.required):1")
        }
    }

    /// The guard on the measurement itself: a ratio function that returned a big
    /// number for everything would pass the test above and mean nothing.
    @Test("The measurement can tell a bad pair from a good one")
    func theMeasurementDiscriminates() {
        #expect(contrast(.black, .white) > 20)
        #expect(contrast(.white, .white) == 1)
        // Two neighbouring inks from the same palette: legitimately close, and
        // exactly what must never end up as text on background.
        #expect(contrast(PixelInk.heading, PixelInk.leather) < Self.required)
    }

    private func contrast(_ first: Color, _ second: Color) -> Double {
        let a = luminance(of: first)
        let b = luminance(of: second)
        return (max(a, b) + 0.05) / (min(a, b) + 0.05)
    }

    private func luminance(of color: Color) -> Double {
        var red: CGFloat = 0, green: CGFloat = 0, blue: CGFloat = 0, alpha: CGFloat = 0
        UIColor(color).getRed(&red, green: &green, blue: &blue, alpha: &alpha)
        func linear(_ channel: CGFloat) -> Double {
            let value = Double(channel)
            return value <= 0.03928 ? value / 12.92 : pow((value + 0.055) / 1.055, 2.4)
        }
        return 0.2126 * linear(red) + 0.7152 * linear(green) + 0.0722 * linear(blue)
    }
}
