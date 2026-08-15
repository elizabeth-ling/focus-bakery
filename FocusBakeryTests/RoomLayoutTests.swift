import CoreGraphics
import Testing
@testable import FocusBakery

/// Portrait point sizes spanning the iPhones an iOS 17 deployment target
/// supports — the SE at the small end, the Pro Max at the large end.
private let supportedPhones: [(name: String, size: CGSize)] = [
    ("iPhone SE (2nd/3rd gen)", CGSize(width: 375, height: 667)),
    ("iPhone 13 mini", CGSize(width: 375, height: 812)),
    ("iPhone 16e", CGSize(width: 375, height: 812)),
    ("iPhone 16", CGSize(width: 393, height: 852)),
    ("iPhone 16 Pro", CGSize(width: 402, height: 874)),
    ("iPhone 16 Plus", CGSize(width: 430, height: 932)),
    ("iPhone 16 Pro Max", CGSize(width: 440, height: 956)),
]

@Suite("Room layout")
struct RoomLayoutTests {
    @Test("Scale is a whole number ×2 on every supported iPhone")
    func scaleIsTwoEverywhere() {
        for phone in supportedPhones {
            let layout = RoomLayout(fitting: phone.size)
            #expect(layout.scale == 2, "\(phone.name) resolved to ×\(layout.scale)")
        }
    }

    @Test("One tile is 16 art pixels, 32pt, on every supported iPhone")
    func tileSizeIsConstant() {
        for phone in supportedPhones {
            let layout = RoomLayout(fitting: phone.size)
            #expect(layout.tileSize == 32)
            #expect(layout.tileSize == CGFloat(PixelGrid.artPixelsPerTile * layout.scale))
        }
    }

    @Test("A larger phone sees more tiles, never bigger ones")
    func largerPhonesSeeMoreRoom() {
        let small = RoomLayout(fitting: CGSize(width: 375, height: 667))
        let large = RoomLayout(fitting: CGSize(width: 440, height: 956))

        #expect(small.tileSize == large.tileSize)
        #expect(large.columns > small.columns)
        #expect(large.rows > small.rows)
        #expect((small.columns, small.rows) == (11, 20))
        #expect((large.columns, large.rows) == (13, 29))
    }

    @Test("The room is whole tiles and the remainder becomes margin")
    func remainderBecomesMargin() {
        for phone in supportedPhones {
            let layout = RoomLayout(fitting: phone.size)

            #expect(layout.roomFrame.width == CGFloat(layout.columns) * layout.tileSize)
            #expect(layout.roomFrame.height == CGFloat(layout.rows) * layout.tileSize)
            #expect(layout.roomFrame.maxX <= phone.size.width)
            #expect(layout.roomFrame.maxY <= phone.size.height)
            // Anything a whole tile or more would have been another tile of room.
            #expect(phone.size.width - layout.roomFrame.width < layout.tileSize)
            #expect(phone.size.height - layout.roomFrame.height < layout.tileSize)
        }
    }

    @Test("The room origin lands on a whole art pixel")
    func marginIsWholeArtPixels() {
        for phone in supportedPhones {
            let layout = RoomLayout(fitting: phone.size)
            let scale = CGFloat(layout.scale)

            #expect(layout.roomFrame.minX.truncatingRemainder(dividingBy: scale) == 0)
            #expect(layout.roomFrame.minY.truncatingRemainder(dividingBy: scale) == 0)
        }
    }

    @Test("Snapping rounds to whole art pixels")
    func snappingRoundsToArtPixels() {
        let layout = RoomLayout(fitting: CGSize(width: 393, height: 852))

        #expect(layout.snap(0) == 0)
        #expect(layout.snap(1.4) == 2)
        #expect(layout.snap(2.9) == 2)
        #expect(layout.snap(-3.2) == -4)
        #expect(layout.snap(CGPoint(x: 100.5, y: 7.1)) == CGPoint(x: 100, y: 8))

        for step in stride(from: -50.0, through: 50.0, by: 0.37) {
            let snapped = layout.snap(CGFloat(step))
            #expect(snapped.truncatingRemainder(dividingBy: CGFloat(layout.scale)) == 0)
        }
    }

    @Test("Row 0 is the back wall and tiles abut without gaps")
    func tilesTileTheRoom() {
        let layout = RoomLayout(fitting: CGSize(width: 393, height: 852))

        let backWall = layout.tileRect(column: 0, row: 0)
        let nextRow = layout.tileRect(column: 0, row: 1)
        let nextColumn = layout.tileRect(column: 1, row: 0)

        #expect(backWall.maxY == layout.roomFrame.maxY)
        #expect(backWall.minX == layout.roomFrame.minX)
        #expect(nextRow.maxY == backWall.minY)
        #expect(nextColumn.minX == backWall.maxX)

        let lastTile = layout.tileRect(column: layout.columns - 1, row: layout.rows - 1)
        #expect(lastTile.maxX == layout.roomFrame.maxX)
        #expect(lastTile.minY == layout.roomFrame.minY)
    }

    @Test("A scene too small for a useful room still resolves to a whole scale")
    func tinySceneStillResolves() {
        let layout = RoomLayout(fitting: CGSize(width: 120, height: 200))

        #expect(layout.scale == 2)
        #expect(layout.columns >= 1)
        #expect(layout.rows >= 1)
        #expect(layout.roomFrame.minX >= 0)
    }

    @Test("A scene large enough for a bigger room steps the scale up, not the room out")
    func hugeSceneStepsScaleUp() {
        // No iPhone is this big; the rule is what keeps the resolver honest if
        // one ever is, rather than growing the room to thirty tiles across.
        let layout = RoomLayout(fitting: CGSize(width: 1024, height: 1366))

        #expect(layout.scale == 4)
        #expect(layout.columns >= PixelGrid.smallestUsefulRoom.columns)
        #expect(layout.rows >= PixelGrid.smallestUsefulRoom.rows)
    }
}
