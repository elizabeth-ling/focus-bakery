import CoreGraphics
import Testing
@testable import FocusBakery

/// The same span as `RoomLayoutTests`: the smallest and largest iPhones an
/// iOS 17 deployment target supports, plus the middles.
private let supportedPhones: [(name: String, size: CGSize)] = [
    ("iPhone SE (2nd/3rd gen)", CGSize(width: 375, height: 667)),
    ("iPhone 13 mini", CGSize(width: 375, height: 812)),
    ("iPhone 16e", CGSize(width: 375, height: 812)),
    ("iPhone 16", CGSize(width: 393, height: 852)),
    ("iPhone 16 Pro", CGSize(width: 402, height: 874)),
    ("iPhone 16 Plus", CGSize(width: 430, height: 932)),
    ("iPhone 16 Pro Max", CGSize(width: 440, height: 956)),
]

@Suite("Room plan")
struct RoomPlanTests {
    private var plans: [(name: String, plan: RoomPlan, layout: RoomLayout)] {
        supportedPhones.map { phone in
            let layout = RoomLayout(fitting: phone.size)
            return (phone.name, RoomPlan(fitting: layout), layout)
        }
    }

    /// Every tile a plan claims for furniture, walls included.
    private func isFurniture(_ tile: RoomTile, in plan: RoomPlan) -> Bool {
        if tile.row == plan.wallRow { return true }
        if tile.row <= plan.ovenRow && plan.ovenColumns.contains(tile.column) { return true }
        if tile.row == plan.prepRow && plan.prepColumns.contains(tile.column) { return true }
        if tile.row == plan.counterRow && tile.column != plan.corridorColumn { return true }
        if plan.seatTiles.contains(tile) { return true }
        return false
    }

    private func tiles(from a: RoomTile, to b: RoomTile) -> [RoomTile] {
        if a.column == b.column {
            let rows = min(a.row, b.row)...max(a.row, b.row)
            return rows.map { RoomTile(column: a.column, row: $0) }
        }
        let columns = min(a.column, b.column)...max(a.column, b.column)
        return columns.map { RoomTile(column: $0, row: a.row) }
    }

    @Test("Anchors stand on open floor inside the room on every supported iPhone")
    func anchorsStandOnOpenFloor() {
        for (name, plan, _) in plans {
            for tile in [plan.stationTile, plan.deliverTile, plan.restTile, plan.doorTile] {
                #expect((0..<plan.columns).contains(tile.column), "\(name)")
                #expect((0..<plan.rows).contains(tile.row), "\(name)")
            }
            for tile in [plan.stationTile, plan.deliverTile, plan.restTile] {
                #expect(!isFurniture(tile, in: plan), "\(name): anchor \(tile) is inside furniture")
            }
        }
    }

    @Test("The room reads back to front: oven, station, counter, seating, door")
    func zonesAreOrdered() {
        for (name, plan, _) in plans {
            #expect(plan.ovenRow < plan.stationTile.row, "\(name)")
            #expect(plan.stationTile.row < plan.counterRow, "\(name)")
            #expect(plan.counterRow < plan.deliverTile.row, "\(name)")
            #expect(plan.counterRow < plan.restTile.row, "\(name)")
            #expect(plan.doorTile.row == plan.rows - 1, "\(name)")
            for seat in plan.seatTiles {
                #expect(seat.row > plan.counterRow, "\(name)")
                #expect(seat.row < plan.rows - 1, "\(name)")
            }
        }
    }

    @Test("The counter line spans the room with exactly the corridor left open")
    func counterHasOneGap() {
        for (name, plan, _) in plans {
            #expect(plan.shelfColumns.lowerBound == plan.caseColumn + 1, "\(name)")
            #expect(plan.shelfColumns.upperBound == plan.corridorColumn - 1, "\(name)")
            #expect((0..<plan.columns).contains(plan.corridorColumn), "\(name)")
            #expect(plan.caseColumn != plan.corridorColumn, "\(name)")
        }
    }

    @Test("Routes between the anchors are axis-aligned and avoid all furniture")
    func routesAreLegal() {
        for (name, plan, _) in plans {
            let anchors = [plan.stationTile, plan.deliverTile, plan.restTile]
            for from in anchors {
                for to in anchors {
                    let route = plan.route(from: from, to: to)
                    #expect(route.first == from, "\(name)")
                    #expect(route.last == to, "\(name)")
                    for (a, b) in zip(route, route.dropFirst()) {
                        #expect(a.column == b.column || a.row == b.row,
                                "\(name): diagonal leg \(a) → \(b)")
                        for tile in tiles(from: a, to: b) {
                            #expect(!isFurniture(tile, in: plan),
                                    "\(name): \(from) → \(to) walks through furniture at \(tile)")
                        }
                    }
                }
            }
        }
    }

    @Test("Crossing between the zones goes through the corridor, never the counter")
    func zoneCrossingsUseTheCorridor() {
        for (name, plan, _) in plans {
            let route = plan.route(from: plan.restTile, to: plan.stationTile)
            #expect(route.contains(RoomTile(column: plan.corridorColumn, row: plan.restTile.row)), "\(name)")
            #expect(route.contains(RoomTile(column: plan.corridorColumn, row: plan.stationTile.row)), "\(name)")
            for (a, b) in zip(route, route.dropFirst()) {
                for tile in tiles(from: a, to: b) where tile.row == plan.counterRow {
                    #expect(tile.column == plan.corridorColumn,
                            "\(name): crossed the counter at \(tile)")
                }
            }
        }
    }

    /// A state change can cut a walk anywhere, including on the one walkable
    /// counter tile. The next route must step off the line, not slide along it.
    @Test("A walk interrupted in the corridor still routes cleanly")
    func corridorInterruptionRoutes() {
        for (name, plan, _) in plans {
            let stranded = RoomTile(column: plan.corridorColumn, row: plan.counterRow)
            for target in [plan.stationTile, plan.deliverTile, plan.restTile] {
                let route = plan.route(from: stranded, to: target)
                #expect(route.last == target, "\(name)")
                for (a, b) in zip(route, route.dropFirst()) {
                    #expect(a.column == b.column || a.row == b.row, "\(name)")
                    for tile in tiles(from: a, to: b) {
                        #expect(!isFurniture(tile, in: plan),
                                "\(name): corridor → \(target) hits furniture at \(tile)")
                    }
                }
            }
        }
    }

    @Test("Going nowhere is a single tile")
    func standingStillIsOneTile() {
        let plan = RoomPlan(columns: 5, rows: 10)
        #expect(plan.route(from: plan.restTile, to: plan.restTile) == [plan.restTile])
    }

    @Test("A degenerate scene still produces a coherent plan")
    func degenerateRoomsStillPlan() {
        let plan = RoomPlan(columns: 1, rows: 1)
        #expect(plan.columns == PixelGrid.smallestUsefulRoom.columns)
        #expect(plan.rows == PixelGrid.smallestUsefulRoom.rows)
        #expect(plan.stationTile.row < plan.counterRow)
        #expect(plan.counterRow < plan.deliverTile.row)
    }

    @Test("Tile positions round-trip through nearestTile and clamp off-room points")
    func tilePointsRoundTrip() {
        let layout = RoomLayout(fitting: CGSize(width: 393, height: 852))
        for column in 0..<layout.columns {
            for row in 0..<layout.rows {
                let tile = RoomTile(column: column, row: row)
                #expect(layout.nearestTile(to: layout.point(of: tile)) == tile)
            }
        }
        // Mid-leg positions resolve to an adjacent whole tile, never out of range.
        let between = CGPoint(
            x: layout.point(of: RoomTile(column: 1, row: 3)).x + layout.tileSize / 2,
            y: layout.point(of: RoomTile(column: 1, row: 3)).y
        )
        #expect((1...2).contains(layout.nearestTile(to: between).column))
        #expect(layout.nearestTile(to: CGPoint(x: -500, y: -500)) == RoomTile(column: 0, row: layout.rows - 1))
    }
}
