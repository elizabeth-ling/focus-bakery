import CoreGraphics

/// A whole-tile position in the room. Column 0 is the left wall, row 0 the back
/// wall, rows growing toward the viewer — the same orientation as
/// `RoomLayout.tileRect`.
struct RoomTile: Hashable, Sendable {
    var column: Int
    var row: Int
}

/// Where the furniture stands and where the baker may walk.
///
/// Spec 05 requires every fixture to hang off an anchor — back wall, case row,
/// door — because the room's tile dimensions flex per device (01). Everything
/// here is derived from `columns` and `rows`; there is no coordinate a
/// different screen size could strand.
///
/// The room reads back to front: wall, then the oven and prep counter, open
/// floor where the baker works, the counter line with the display case that
/// splits back of house from front of house, then seating and the door. The two
/// zones stay one continuous space — the split is a line of furniture with a
/// corridor gap, not a boundary.
struct RoomPlan: Equatable {
    let columns: Int
    let rows: Int

    /// The back wall band. Visual only; nothing stands on it.
    let wallRow: Int
    /// The oven's floor footprint: two tiles hung on the back wall, its body
    /// drawn three tiles tall so it covers the wall band above.
    let ovenColumns: ClosedRange<Int>
    let ovenRow: Int
    /// Prep counter filling the rest of the back wall line.
    let prepColumns: ClosedRange<Int>
    let prepRow: Int
    /// The counter line dividing the zones, continuous except the corridor.
    let counterRow: Int
    /// The one walkable tile on the counter row.
    let corridorColumn: Int
    /// The glass display case at the left end of the counter line.
    let caseColumn: Int
    /// Counter tiles where delivered treats land, left to right.
    let shelfColumns: ClosedRange<Int>
    let doorTile: RoomTile
    let seatTiles: [RoomTile]

    /// Where the baker works, directly in front of the oven.
    let stationTile: RoomTile
    /// Where the baker stands to place a treat, front-of-house side of the case.
    let deliverTile: RoomTile
    /// Where the idle baker rests, front of house near the seating.
    let restTile: RoomTile

    init(columns: Int, rows: Int) {
        // A scene below the smallest useful room (01) still gets a coherent
        // plan — the layout simply cannot show all of it. Never a crash.
        let columns = max(columns, PixelGrid.smallestUsefulRoom.columns)
        let rows = max(rows, PixelGrid.smallestUsefulRoom.rows)
        self.columns = columns
        self.rows = rows

        wallRow = 0
        ovenColumns = 0...1
        ovenRow = 2
        prepColumns = (ovenColumns.upperBound + 1)...(columns - 1)
        prepRow = 1
        // An even split, so a taller phone grows both zones rather than one.
        counterRow = rows / 2
        corridorColumn = columns - 1
        caseColumn = 0
        shelfColumns = 1...(corridorColumn - 1)

        stationTile = RoomTile(column: ovenColumns.upperBound, row: ovenRow + 1)
        deliverTile = RoomTile(column: caseColumn + 1, row: counterRow + 1)
        restTile = RoomTile(column: columns - 2, row: rows - 2)
        doorTile = RoomTile(column: columns / 2, row: rows - 1)
        // Against the left wall, below the case: the one strip of front of
        // house no authored route ever crosses, so the seating can never end
        // up inside a walk lane on any room size.
        seatTiles = [
            RoomTile(column: 0, row: counterRow + 2),
            RoomTile(column: 0, row: counterRow + 3),
        ]
    }

    init(fitting layout: RoomLayout) {
        self.init(columns: layout.columns, rows: layout.rows)
    }

    /// The authored routes — spec 05 has no pathfinding. Legs are axis-aligned;
    /// crossing between the zones goes through the corridor gap in the counter.
    ///
    /// Works from *any* start tile, not only the named anchors, because a state
    /// change can interrupt a walk anywhere and the next walk begins wherever
    /// the baker was cut off.
    func route(from start: RoomTile, to end: RoomTile) -> [RoomTile] {
        var waypoints = [start]
        if (start.row < counterRow) != (end.row < counterRow) {
            waypoints.append(RoomTile(column: corridorColumn, row: start.row))
            waypoints.append(RoomTile(column: corridorColumn, row: end.row))
        } else if start.row == counterRow {
            // Interrupted in the corridor itself: step off the counter line
            // before turning, or the leg would walk along it through furniture.
            waypoints.append(RoomTile(column: start.column, row: end.row))
        } else {
            waypoints.append(RoomTile(column: end.column, row: start.row))
        }
        waypoints.append(end)
        return waypoints.reduce(into: []) { route, tile in
            if route.last != tile { route.append(tile) }
        }
    }
}

extension RoomPlan {
    /// The display case's extent in scene coordinates: the counter line it
    /// stands at the end of, three tiles tall.
    ///
    /// One place rather than two because it is both the tap target and the
    /// frame VoiceOver reads (08, 13) — and because a single tile is 32pt at
    /// ×2, under the 44pt minimum, so the region has to be the fixture's full
    /// extent rather than the tile the sprite sits on.
    func caseRegion(in layout: RoomLayout) -> CGRect {
        let base = layout.tileRect(column: caseColumn, row: counterRow)
        let end = layout.tileRect(column: shelfColumns.upperBound, row: counterRow)
        return CGRect(
            x: base.minX,
            y: base.minY,
            width: end.maxX - base.minX,
            height: layout.tileSize * 3
        )
    }
}

extension RoomLayout {
    /// The scene position of a tile — its bottom-left corner, where a
    /// zero-anchored sprite standing on that tile goes.
    func point(of tile: RoomTile) -> CGPoint {
        tileRect(column: tile.column, row: tile.row).origin
    }

    /// The whole tile a scene position is standing on, clamped into the room —
    /// how a walk interrupted mid-leg rejoins the authored routes.
    func nearestTile(to point: CGPoint) -> RoomTile {
        let column = Int(((point.x - roomFrame.minX) / tileSize).rounded())
        let row = Int(((roomFrame.maxY - point.y) / tileSize).rounded()) - 1
        return RoomTile(
            column: min(max(column, 0), columns - 1),
            row: min(max(row, 0), rows - 1)
        )
    }
}
