/// Shared multipart-monument road-access table used by
/// `FUN_004BA6F0`. Each original row contains 24 signed 228-wide linear
/// offsets and is zero-terminated; these are the nonzero entries converted
/// to local grid points for the footprint sizes used by the Great Wall and
/// Grand Canal.
public enum OriginalMultipartMonumentRoutingCatalog {
    public static let offsetTableSlotCount = 24
    public static let componentRankLimit = 10

    public static func roadAccessOffsets(footprintSide: Int) -> [GridPoint] {
        switch footprintSide {
        case 1:
            return [
                GridPoint(x: 0, y: -1), GridPoint(x: 1, y: 0),
                GridPoint(x: 0, y: 1), GridPoint(x: -1, y: 0),
            ]
        case 2:
            return [
                GridPoint(x: 0, y: -1), GridPoint(x: 1, y: -1),
                GridPoint(x: 2, y: 0), GridPoint(x: 2, y: 1),
                GridPoint(x: 1, y: 2), GridPoint(x: 0, y: 2),
                GridPoint(x: -1, y: 1), GridPoint(x: -1, y: 0),
            ]
        case 4:
            return [
                GridPoint(x: 0, y: -1), GridPoint(x: 1, y: -1),
                GridPoint(x: 2, y: -1), GridPoint(x: 3, y: -1),
                GridPoint(x: 4, y: 0), GridPoint(x: 4, y: 1),
                GridPoint(x: 4, y: 2), GridPoint(x: 4, y: 3),
                GridPoint(x: 3, y: 4), GridPoint(x: 2, y: 4),
                GridPoint(x: 1, y: 4), GridPoint(x: 0, y: 4),
                GridPoint(x: -1, y: 3), GridPoint(x: -1, y: 2),
                GridPoint(x: -1, y: 1), GridPoint(x: -1, y: 0),
            ]
        default:
            return []
        }
    }

    /// Chooses the first perimeter cell belonging to the best of the ten
    /// ranked road components. The original comparison is strict, so table
    /// order wins ties within one component rank.
    public static func roadAccessPoint(
        subBuildingOrigin: GridPoint,
        footprintSide: Int,
        roadComponentRankByPoint: [GridPoint: Int]
    ) -> GridPoint? {
        var selected: GridPoint?
        var selectedRank = componentRankLimit + 2
        for offset in roadAccessOffsets(footprintSide: footprintSide) {
            let point = GridPoint(
                x: subBuildingOrigin.x + offset.x,
                y: subBuildingOrigin.y + offset.y
            )
            guard let rank = roadComponentRankByPoint[point],
                  rank >= 0,
                  rank < componentRankLimit,
                  rank < selectedRank else { continue }
            selected = point
            selectedRank = rank
        }
        return selected
    }
}
