import Foundation

/// Semantic names for the original game's main city-interface artwork.
///
/// `China_Interface` stores every four-state button as consecutive records:
/// normal, hover, selected, and disabled. Keeping those IDs in one catalog
/// prevents player-facing SwiftUI views from scattering unexplained archive
/// offsets or silently substituting unrelated symbols.
public enum OriginalInterfaceIcon: String, CaseIterable, Sendable, Hashable {
    case mainMenu
    case compass
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
        .compass: 1_227,
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

/// Original artwork used by the fixed 1024×768 city chrome.
///
/// These records are not buttons, so they deliberately live outside the
/// four-state semantic icon table above.
public enum OriginalInterfaceChromeSpriteCatalog {
    public static let archiveBaseName = OriginalInterfaceSpriteCatalog.archiveBaseName
    public static let cityHUDBackgroundImageID = 1_221
    public static let cityPanelBackgroundImageID = 1_223
    public static let treasuryImageID = 652
    // The authored labor icon is visible in the original HUD, but its source
    // record is not yet verified. Do not use #311: it includes a terrain tile.
    public static let laborImageID: Int? = nil

    /// `China_Interface_New_parts` stores the twelve zodiac heads in an
    /// archive-specific order rather than calendar order.
    private static let zodiacImageIDs: [String: Int] = [
        "鼠": 1_364,
        "牛": 1_372,
        "虎": 1_370,
        "兔": 1_363,
        "龙": 1_365,
        "蛇": 1_373,
        "马": 1_374,
        "羊": 1_368,
        "猴": 1_367,
        "鸡": 1_369,
        "狗": 1_371,
        "猪": 1_366,
    ]

    public static func zodiacImageID(for animal: String) -> Int? {
        zodiacImageIDs[animal]
    }

    public static var requiredImageIDs: Set<Int> {
        Set([
            cityHUDBackgroundImageID,
            cityPanelBackgroundImageID,
            treasuryImageID,
        ]).union(zodiacImageIDs.values)
    }
}

/// Standalone city-interface / tool artwork that is not stored as a four-state
/// category-button family.
///
/// - #1275/#1279/#1283/#1287: the road, inspection, shovel and red removal
///   actions visible in the original city utility strip above the minimap
/// - #1291: help star used as the strip's trailing entry (messages stay on the
///   bottom navigation bar; the message family is not yet verified)
/// - Player-built world roads still use the authored China_Terrain connection
///   family (`roadTerrainLocalID`), not the Great Wall category button (#1319)
public enum OriginalInterfaceUtilityIcon: String, CaseIterable, Sendable, Hashable {
    case inspect
    case clearLand
    case demolish
    case road
    case help
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
        // Road tile, city inspection, shovel, red removal, then help star.
        .road: 1_275,
        .inspect: 1_279,
        .clearLand: 1_283,
        .demolish: 1_287,
        .help: 1_291,
    ]

    public static func imageID(for icon: OriginalInterfaceUtilityIcon) -> Int? {
        interfaceImageIDs[icon]
    }

    public static var requiredImageIDs: Set<Int> {
        Set(interfaceImageIDs.values)
    }
}

/// The original construction menu stores 54×53 button artwork as consecutive
/// normal, hover, and selected records in `China_Interface_New_Bbuttons`.
/// These are UI sprites, not the isometric world sprites used on the map.
///
/// Evidence for `buildingID → baseImageID` is **not** fully exe-recovered.
/// GameData has no button field; read-only `Emperor[EN].exe` notes (addresses,
/// exhausted negative searches, evidence classes) live in
/// `docs/exe-research/construction-bbuttons.md`. Do not upgrade inferred rows
/// to confirmed without linking UI-record writers in that binary.
public enum OriginalConstructionButtonState: Int, CaseIterable, Sendable, Hashable {
    case normal
    case hover
    case selected
}

/// Evidence level for a building-to-button association.
///
/// The executable research recovered the three-state sheet geometry, but not
/// the construction-panel writer that associates an authored building model
/// with an early Bbutton frame. Keeping this distinction in the catalog makes
/// it impossible for callers and tests to describe the current sheet-order
/// mapping as exe-confirmed by accident.
public enum OriginalConstructionButtonEvidence: String, Sendable, Hashable {
    case inferredFromSheet
    case unknown
}

public enum OriginalConstructionButtonSpriteCatalog {
    public static let archiveBaseName = OriginalInterfaceSpriteCatalog.archiveBaseName

    /// First records of three-state button families.
    /// Sheet geometry (54×53, ×3 states) is confirmed from SG3 export.
    /// Individual building→base rows are inferred from sheet order and frame
    /// content unless/until exe UI-record writers are recovered; see
    /// `docs/exe-research/construction-bbuttons.md`.
    private static let baseImageIDByBuildingID: [Int: Int] = [
        2: 1_491,   // common housing
        11: 1_494,  // elite housing
        31: 1_512,  // fishing wharf
        33: 1_506,  // hunting camp
        35: 1_515,  // clay pit
        36: 1_518,  // quarry / stoneworks
        43: 1_521,  // kiln
        39: 1_524,  // bronze smelter
        40: 1_524,  // iron smelter shares the furnace button
        38: 1_527,  // lumber mill
        // Commerce / light-industry: inferred from New_Bbuttons order after
        // lumber + exported 54×53 frames (not exe-confirmed).
        54: 1_528,  // warehouse
        66: 1_531,  // food shop
        53: 1_534,  // mill
        47: 1_537,  // weaver
        65: 1_540,  // ceramics shop
        67: 1_543,  // hemp shop
        59: 1_546,  // common market
        60: 1_546,  // grand market shares the market pavilion family
        72: 1_551,  // well
        207: 1_554, // herbalist
        208: 1_557, // acupuncture clinic
        124: 1_560, // inspector tower
        127: 1_563, // watchtower
        209: 1_566, // administrative city
        110: 1_569, // palace
        125: 1_572, // tax office
        203: 1_575, // irrigation pump
        211: 1_584, // music school
        212: 1_587, // acrobat school
        213: 1_590, // drama school
        214: 1_596, // ancestral shrine
        215: 1_599, // Daoist shrine
        216: 1_599, // large Daoist temple shares the Daoist button family
        218: 1_602, // Buddhist pagoda
        219: 1_605, // Confucian academy
        220: 1_608, // crossbow fort
        221: 1_611, // infantry fort
        224: 1_614, // cavalry fort
        225: 1_617, // chariot fort
        223: 1_620, // catapult fort
        116: 1_623, // decorative sculpture
        115: 1_626, // garden
        117: 1_629, // ornate sculpture
        120: 1_632, // pond
        121: 1_635, // tai chi park
        119: 1_638, // wayside pavilion
        118: 1_641, // flowering tree
        122: 1_644, // private garden
        233: 1_647, // laborers camp
        52: 1_650,  // carpenters guild
        235: 1_650, // masons guild shares the guild button family
        236: 1_650, // ceramists guild shares the guild button family
        93: 1_653,  // grand pagoda
    ]

    public static func imageID(
        forBuildingID buildingID: Int,
        state: OriginalConstructionButtonState = .normal
    ) -> Int? {
        baseImageIDByBuildingID[buildingID].map { $0 + state.rawValue }
    }

    /// Returns the evidence class for the association used by `imageID`.
    /// A missing association is deliberately `unknown`; callers must not
    /// synthesize a Bbutton from a model/building id or from `4A5960`.
    public static func evidence(
        forBuildingID buildingID: Int
    ) -> OriginalConstructionButtonEvidence {
        baseImageIDByBuildingID[buildingID] == nil
            ? .unknown
            : .inferredFromSheet
    }

    /// Building IDs currently covered by the sheet-order fallback. This is
    /// useful for diagnostics and tests without exposing the implementation
    /// dictionary to player-facing code.
    public static var mappedBuildingIDs: Set<Int> {
        Set(baseImageIDByBuildingID.keys)
    }

    /// Crop buttons are semantic because several crop models intentionally
    /// share the same original field or orchard artwork.
    public static func cropImageID(
        isRice: Bool,
        isOrchard: Bool,
        state: OriginalConstructionButtonState = .normal
    ) -> Int {
        let base = isRice ? 1_500 : (isOrchard ? 1_509 : 1_497)
        return base + state.rawValue
    }

    public static var requiredImageIDs: Set<Int> {
        let buildingIDs = baseImageIDByBuildingID.values.flatMap { base in
            OriginalConstructionButtonState.allCases.map { base + $0.rawValue }
        }
        let cropIDs = [1_497, 1_500, 1_509].flatMap { base in
            OriginalConstructionButtonState.allCases.map { base + $0.rawValue }
        }
        return Set(buildingIDs + cropIDs)
    }
}
