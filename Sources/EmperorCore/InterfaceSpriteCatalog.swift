import Foundation

/// Semantic names for the original game's main city-interface artwork.
///
/// `China_Interface` stores every four-state button as consecutive records:
/// normal, hover, selected, and disabled. Keeping those IDs in one catalog
/// prevents player-facing SwiftUI views from scattering unexplained archive
/// offsets or silently substituting unrelated symbols.
public enum OriginalInterfaceIcon: String, CaseIterable, Sendable, Hashable {
    case mainMenu
    case worldMap
    case cityView
    case objectives
    case messages
    case undo
    case help
    case zoom
    case panUp
    case panDown
    case panLeft
    case panRight
    case infrastructure
    case residential
    case agriculture
    case industry
    case commerce
    case entertainment
    case government
    case culture
    case religion
    case military
    case aesthetics
}

public enum OriginalInterfaceIconState: Int, CaseIterable, Sendable, Hashable {
    case normal
    case hover
    case selected
    case disabled
}

public enum OriginalInterfaceSpriteCatalog {
    public static let archiveBaseName = "China_Interface"

    /// First image in each verified four-state family. These records were
    /// visually matched against the shipped city panel and its button sheet.
    ///
    /// Note: `.infrastructure` (1_319) is the Great Wall / monument category
    /// button in the original strip — not the road tool.
    private static let baseImageIDs: [OriginalInterfaceIcon: Int] = [
        .mainMenu: 1_259,
        .worldMap: 1_263,
        .cityView: 1_267,
        .objectives: 1_271,
        // The original message family is not yet verified. IDs 1275...1278
        // are cabbage/cargo artwork, so callers intentionally use a native
        // fallback rather than loading a semantically incorrect sprite.
        .undo: 1_287,
        .help: 1_291,
        .zoom: 1_295,
        .panUp: 1_299,
        .panDown: 1_303,
        .panLeft: 1_311,
        .panRight: 1_315,
        .infrastructure: 1_319,
        .residential: 1_323,
        .agriculture: 1_327,
        .industry: 1_331,
        .commerce: 1_335,
        .entertainment: 1_339,
        .government: 1_343,
        .culture: 1_347,
        .religion: 1_351,
        .military: 1_355,
        .aesthetics: 1_359,
    ]

    public static func imageID(
        for icon: OriginalInterfaceIcon,
        state: OriginalInterfaceIconState = .normal
    ) -> Int? {
        baseImageIDs[icon].map { $0 + state.rawValue }
    }

    public static var requiredImageIDs: Set<Int> {
        Set(OriginalInterfaceIcon.allCases.flatMap { icon in
            OriginalInterfaceIconState.allCases.compactMap {
                imageID(for: icon, state: $0)
            }
        })
    }
}

/// Standalone city-interface / tool artwork that is not stored as a four-state
/// category-button family.
///
/// - #1283: the original green shovel shown in the city utility strip
/// - Demolish intentionally falls back to the native trash symbol until a
///   distinct original demolition family is verified; #1287 is Undo.
/// - Road tools reuse an authored China_Terrain dirt-road tile
///   (`roadTerrainLocalID`) rather than the Great Wall category button (#1319)
public enum OriginalInterfaceUtilityIcon: String, CaseIterable, Sendable, Hashable {
    case clearLand
    case demolish
    case road
}

public enum OriginalInterfaceUtilitySpriteCatalog {
    public static let archiveBaseName = OriginalInterfaceSpriteCatalog.archiveBaseName

    /// Authored dirt-road tile used for the road tool and infrastructure rail.
    public static let roadTerrainLocalID = 782
    public static let roadTerrainArchiveBaseName = "China_Terrain"
    /// China_Terrain locals covering the early-era dirt-road connection family
    /// (straight, corner, tee, end). Tutorial maps like Banpo ship with no
    /// authored road tiles; player-built roads fall back to this set.
    public static let roadTerrainLocalIDs: Set<Int> = Set(
        defaultRoadLocalIDByConnectionMask.values
    )

    /// N/E/S/W connection mask → China_Terrain local ID, derived from authored
    /// roads across the original city maps (780-series / China_Land3 family).
    public static let defaultRoadLocalIDByConnectionMask: [Int: Int] = [
        0b0000: 782,
        0b0001: 788,
        0b0010: 789,
        0b0011: 784,
        0b0100: 790,
        0b0101: 782,
        0b0110: 785,
        0b0111: 795,
        0b1000: 791,
        0b1001: 787,
        0b1010: 783,
        0b1011: 796,
        0b1100: 786,
        0b1101: 795,
        0b1110: 794,
        0b1111: 797,
    ]

    public static func defaultRoadLocalID(forConnectionMask mask: Int) -> Int {
        defaultRoadLocalIDByConnectionMask[mask & 0b1111]
            ?? roadTerrainLocalID
    }

    private static let interfaceImageIDs: [OriginalInterfaceUtilityIcon: Int] = [
        .clearLand: 1_283,
    ]

    public static func imageID(for icon: OriginalInterfaceUtilityIcon) -> Int? {
        interfaceImageIDs[icon]
    }

    public static var requiredImageIDs: Set<Int> {
        Set(interfaceImageIDs.values)
    }
}
