import SwiftUI

/// The chrome palette, in the colours `tools/ui/build_ui.py` draws the authored
/// UI art in — so text sits on that art as though printed there.
///
/// Shared rather than redeclared per screen. Spec 13 asks chrome to look like it
/// belongs to the room it covers, and the recipe book, the display-case sheet,
/// settings and the room's own overlay disagreeing by a shade is how that quietly
/// stops being true. Deliberately few colours: this is one palette, not a design
/// system (`AGENTS.md`).
enum PixelInk {
    /// Sheet backgrounds — the paper a chrome surface is printed on.
    static let paper = Color(red: 0xF4 / 255, green: 0xE9 / 255, blue: 0xD8 / 255)
    /// Ink for headings and anything that must be read first.
    static let heading = Color(red: 0x38 / 255, green: 0x1A / 255, blue: 0x08 / 255)
    /// Ink for supporting text.
    static let body = Color(red: 0x66 / 255, green: 0x45 / 255, blue: 0x1E / 255)
    /// Text on leather, and text over the room itself, where paper-dark ink
    /// would disappear into the floor.
    static let cream = Color(red: 0xF0 / 255, green: 0xEF / 255, blue: 0xDE / 255)
}
