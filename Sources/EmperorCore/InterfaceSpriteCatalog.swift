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
/// The original city utility strip above the minimap has exactly five buttons;
/// `GameData/EmperorText.txt` group lists them in order as
/// `修路 / 路障 / 清除 / 撤销 / 查看最后事件` (rows 3694–3698, matching the
/// manual's Build Roads / Place Roadblocks / Clear Item / Undo Last Action /
/// View Last Event). The shipped `China_Interface_New_parts` sheet stores the
/// five four-state families as:
///
/// - #1275 (`group 133`): dirt-road tile — 修路 / Build Roads
/// - #1279 (`group 134`): roadblock sign on a roadside — 路障 / Place Roadblocks
/// - #1283 (`group 135`): clearing shovel in grass — 清除 / Clear Item
/// - #1287 (`group 136`): red removal mark — 撤销 / Undo Last Action
///   (the same family as `OriginalInterfaceSpriteCatalog .undo`)
/// - #1291 (`group 115`): scroll/event mark — 查看最后事件 / View Last Event
///
/// Native keeps `.demolish` as the item-removal tool under its own label and
/// reuses the #1287 family; the messages entry stays in the bottom navigation
/// bar, so `.help` is retained for the strip's trailing message button.
public enum OriginalInterfaceUtilityIcon: String, CaseIterable, Sendable, Hashable {
    case road
    case roadblock
    case clearLand
    case demolish
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
        // 修路, 路障, 清除, 撤销, 查看最后事件 — original utility-strip order.
        .road: 1_275,
        .roadblock: 1_279,
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
/// The hash-identified executable's `0x53A760` writer reads a compact
/// `(selectorID, sheetFamilyIndex)` table at `0x855888`. Direct rows bind a
/// building to one family. Submenu rows bind a group to one family and can be
/// collapsed to a sole available member by the original program; native flat
/// catalogs reuse that confirmed shared family for every group member.
public enum OriginalConstructionButtonEvidence: String, Sendable, Hashable {
    case confirmedDirectFromExecutable
    case confirmedSubmenuFamilyFromExecutable
    case inferredFromSheet
    case unknown
}

/// Original city construction categories in the executable's fixed rail order.
public enum OriginalConstructionPanelCategory: Int, CaseIterable, Sendable, Hashable {
    case residential
    case agriculture
    case industry
    case commerce
    case safety
    case government
    case entertainment
    case religion
    case military
    case aesthetics
    case monuments
}

/// One executable-authored top-level construction slot.
public struct OriginalConstructionPanelSlot: Sendable, Hashable, Identifiable {
    public enum Kind: Sendable, Hashable {
        case directBuilding
        case buildingSubmenu
        case resourceSubmenu
        case dynamicMonument
    }

    public let category: OriginalConstructionPanelCategory
    public let position: Int
    public let selectorID: Int
    public let familyIndex: Int
    public let kind: Kind
    public let memberBuildingIDs: [Int]

    public var id: String { "\(category.rawValue)-\(position)-\(selectorID)" }

    public var baseImageID: Int {
        OriginalConstructionButtonSpriteCatalog.baseImageID(
            forFamilyIndex: familyIndex
        )
    }
}

/// Executable-confirmed construction-panel topology.
///
/// Sources: category table `0x855888`, selector switch `0x403C80`, and group
/// members `0x821164` in the hash-identified English executable.
public enum OriginalConstructionPanelCatalog {
    /// Only these four selector groups pass through `0x53A640` before the
    /// top-level records are painted. `0x53A690` replaces the selector with
    /// its sole available member only for these groups; every other group
    /// still opens state 6 even when one row remains.
    public static let singletonCollapsingSelectorIDs: Set<Int> = [63, 204, 205, 222]

    private struct Recipe {
        let selectorID: Int
        let familyIndex: Int
        let kind: OriginalConstructionPanelSlot.Kind
        let members: [Int]
    }

    private static func direct(_ selectorID: Int, _ familyIndex: Int) -> Recipe {
        Recipe(
            selectorID: selectorID,
            familyIndex: familyIndex,
            kind: .directBuilding,
            members: []
        )
    }

    private static func submenu(
        _ selectorID: Int,
        _ familyIndex: Int,
        _ members: [Int]
    ) -> Recipe {
        Recipe(
            selectorID: selectorID,
            familyIndex: familyIndex,
            kind: .buildingSubmenu,
            members: members
        )
    }

    private static func resource(_ selectorID: Int, _ familyIndex: Int) -> Recipe {
        Recipe(
            selectorID: selectorID,
            familyIndex: familyIndex,
            kind: .resourceSubmenu,
            members: []
        )
    }

    private static let recipes: [[Recipe]] = [
        [direct(2, 1), direct(11, 2)],
        [
            submenu(24, 3, [193, 192]),
            submenu(200, 4, [199, 198, 196, 197, 195, 194]),
            submenu(201, 5, [202, 203]),
            submenu(29, 6, [238, 239, 237]),
            submenu(25, 7, [27, 28, 26]),
            submenu(30, 8, [31, 33]),
        ],
        [
            direct(35, 9), submenu(34, 10, [38, 36]),
            submenu(204, 11, [39, 40, 41]), submenu(50, 12, [43, 42, 44]),
            submenu(140, 13, [47, 45, 46]), direct(37, 14),
        ],
        [
            direct(53, 15), submenu(63, 16, [59, 60]),
            submenu(206, 17, [66, 67, 65, 70, 69, 64, 68]), direct(54, 18),
            resource(88, 19), resource(87, 20),
        ],
        [direct(72, 21), direct(207, 22), direct(208, 23), direct(124, 24), direct(127, 25)],
        [
            direct(209, 26), direct(125, 27), direct(110, 28), direct(123, 29),
            direct(210, 30), submenu(205, 31, [48, 49]),
        ],
        [direct(211, 32), direct(212, 33), direct(213, 34), direct(75, 35)],
        [
            direct(214, 36), submenu(240, 37, [215, 216]),
            submenu(241, 38, [217, 218]), direct(219, 39),
        ],
        [
            direct(220, 40), direct(221, 41), submenu(222, 42, [224, 225]),
            direct(223, 43), submenu(134, 44, [131, 129, 130]), direct(226, 45),
        ],
        [
            direct(115, 46),
            submenu(229, 47, [116, 243, 244, 245, 117, 246, 247, 248]),
            submenu(136, 48, [119, 251, 120, 252, 121, 122]),
            submenu(230, 49, [111, 113]), submenu(107, 50, [231, 91, 90, 89]),
            submenu(242, 51, [118, 249, 250]),
        ],
        [direct(233, 52), submenu(234, 53, [52, 235, 236])],
    ]

    /// Exact `(buildingID, familyIndex)` table at `0x855D88`. Every family
    /// index is 55; retaining the authored ID order is what determines the
    /// four runtime positions.
    public static let dynamicMonumentBuildingIDs =
        Array(76...84) + [92, 93] + Array(253...268)

    /// `0x53A4E0` makes the two project IDs and all sixteen layout IDs
    /// equivalent only while matching an active monument task. The later
    /// existing-building scan remains an exact-ID comparison.
    public static let greatWallTaskFamilyBuildingIDs: Set<Int> =
        Set([85, 86] + Array(253...268))

    /// Monument task IDs recognized by the support-button gate at the tail of
    /// `0x53A760`. Clock Tower (92) and Grand Pagoda (93) need the guild slot
    /// but deliberately omit the laborers-camp slot.
    public static let monumentTaskBuildingIDs: Set<Int> =
        Set(Array(76...86) + [92, 93])
    public static let laborersCampMonumentTaskBuildingIDs: Set<Int> =
        Set(Array(76...86))

    public static func collapsesSingleAvailableMember(selectorID: Int) -> Bool {
        singletonCollapsingSelectorIDs.contains(selectorID)
    }

    /// Reproduces the `0x53A5D0` task match and the first-four scan in
    /// `0x53A760`. Existing candidates turn into holes in their original
    /// positions; later matches do not compact forward into those holes.
    public static func runtimeDynamicMonumentBuildingIDs(
        monumentTaskBuildingIDs taskBuildingIDs: Set<Int>,
        existingBuildingIDs: Set<Int>
    ) -> [Int?] {
        let matching = dynamicMonumentBuildingIDs.lazy.filter { candidate in
            if taskBuildingIDs.contains(candidate) { return true }
            return greatWallTaskFamilyBuildingIDs.contains(candidate)
                && !taskBuildingIDs.isDisjoint(with: greatWallTaskFamilyBuildingIDs)
        }
        var result = Array(matching.prefix(4)).map(Optional.some)
        while result.count < 4 { result.append(nil) }
        return result.map { candidate in
            guard let candidate, !existingBuildingIDs.contains(candidate) else {
                return nil
            }
            return candidate
        }
    }

    public static func slots(
        for category: OriginalConstructionPanelCategory,
        dynamicMonumentBuildingIDs: [Int?] = []
    ) -> [OriginalConstructionPanelSlot?] {
        var result = recipes[category.rawValue].enumerated().map { position, recipe in
            OriginalConstructionPanelSlot(
                category: category,
                position: position,
                selectorID: recipe.selectorID,
                familyIndex: recipe.familyIndex,
                kind: recipe.kind,
                memberBuildingIDs: recipe.members
            )
        }.map(Optional.some)

        if category == .monuments {
            for position in 2..<6 {
                let dynamicIndex = position - 2
                let buildingID = dynamicMonumentBuildingIDs.indices.contains(dynamicIndex)
                    ? dynamicMonumentBuildingIDs[dynamicIndex]
                    : nil
                result.append(
                    OriginalConstructionPanelSlot(
                        category: category,
                        position: position,
                        selectorID: buildingID ?? 0,
                        familyIndex: 55,
                        kind: .dynamicMonument,
                        memberBuildingIDs: buildingID.map { [$0] } ?? []
                    )
                )
            }
        }
        while result.count < 6 { result.append(nil) }
        return Array(result.prefix(6))
    }

    /// Applies the monument-task support gate at the end of `0x53A760` in
    /// addition to the fixed category table. Non-monument categories are
    /// identical to `slots(for:)`.
    public static func runtimeSlots(
        for category: OriginalConstructionPanelCategory,
        monumentTaskBuildingIDs taskBuildingIDs: Set<Int>,
        existingMonumentBuildingIDs: Set<Int>
    ) -> [OriginalConstructionPanelSlot?] {
        guard category == .monuments else { return slots(for: category) }
        guard !taskBuildingIDs.isEmpty else { return Array(repeating: nil, count: 6) }
        var result = slots(
            for: category,
            dynamicMonumentBuildingIDs: runtimeDynamicMonumentBuildingIDs(
                monumentTaskBuildingIDs: taskBuildingIDs,
                existingBuildingIDs: existingMonumentBuildingIDs
            )
        )
        for position in 2..<6 where result[position]?.memberBuildingIDs.isEmpty == true {
            result[position] = nil
        }
        guard !taskBuildingIDs.isDisjoint(with: monumentTaskBuildingIDs) else {
            result[0] = nil
            result[1] = nil
            return result
        }
        if taskBuildingIDs.isDisjoint(with: laborersCampMonumentTaskBuildingIDs) {
            result[0] = nil
        }
        return result
    }
}

public enum OriginalConstructionButtonSpriteCatalog {
    public static let archiveBaseName = OriginalInterfaceSpriteCatalog.archiveBaseName

    private struct Mapping: Sendable {
        let baseImageID: Int
        let evidence: OriginalConstructionButtonEvidence
    }

    /// First records of the original three-state button families.
    ///
    /// `0x449C10` resolves image group `#695` and adds the offset written by
    /// `0x53A760`; the latter is `sheetFamilyIndex * 3`. In the exported
    /// `China_Interface` index this is `1488 + sheetFamilyIndex * 3`.
    private static let mappingByBuildingID: [Int: Mapping] = {
        var result: [Int: Mapping] = [:]

        func add(
            _ buildingIDs: [Int],
            baseImageID: Int,
            evidence: OriginalConstructionButtonEvidence
        ) {
            for buildingID in buildingIDs {
                result[buildingID] = Mapping(
                    baseImageID: baseImageID,
                    evidence: evidence
                )
            }
        }

        let direct = OriginalConstructionButtonEvidence.confirmedDirectFromExecutable
        let submenu = OriginalConstructionButtonEvidence.confirmedSubmenuFamilyFromExecutable

        // Direct category-slot rows from the 11×6 table at 0x855888.
        add([2], baseImageID: 1_491, evidence: direct)
        add([11], baseImageID: 1_494, evidence: direct)
        add([35], baseImageID: 1_515, evidence: direct)
        add([37], baseImageID: 1_530, evidence: direct)
        add([53], baseImageID: 1_533, evidence: direct)
        add([54], baseImageID: 1_542, evidence: direct)
        add([72], baseImageID: 1_551, evidence: direct)
        add([207], baseImageID: 1_554, evidence: direct)
        add([208], baseImageID: 1_557, evidence: direct)
        add([124], baseImageID: 1_560, evidence: direct)
        add([127], baseImageID: 1_563, evidence: direct)
        add([209], baseImageID: 1_566, evidence: direct)
        add([125], baseImageID: 1_569, evidence: direct)
        add([110], baseImageID: 1_572, evidence: direct)
        add([123], baseImageID: 1_575, evidence: direct)
        add([210], baseImageID: 1_578, evidence: direct)
        add([211], baseImageID: 1_584, evidence: direct)
        add([212], baseImageID: 1_587, evidence: direct)
        add([213], baseImageID: 1_590, evidence: direct)
        add([75], baseImageID: 1_593, evidence: direct)
        add([214], baseImageID: 1_596, evidence: direct)
        add([219], baseImageID: 1_605, evidence: direct)
        add([220], baseImageID: 1_608, evidence: direct)
        add([221], baseImageID: 1_611, evidence: direct)
        add([223], baseImageID: 1_617, evidence: direct)
        add([226], baseImageID: 1_623, evidence: direct)
        add([115], baseImageID: 1_626, evidence: direct)
        add([233], baseImageID: 1_644, evidence: direct)

        // Original submenu members from the 45×32 table at 0x821164. The
        // program keeps the selector's family when only one member is
        // available, so every member legitimately shares that family.
        add([193, 192], baseImageID: 1_497, evidence: submenu)
        add([199, 198, 196, 197, 195, 194], baseImageID: 1_500, evidence: submenu)
        add([202, 203], baseImageID: 1_503, evidence: submenu)
        add([238, 239, 237], baseImageID: 1_506, evidence: submenu)
        add([27, 28, 26], baseImageID: 1_509, evidence: submenu)
        add([31, 33], baseImageID: 1_512, evidence: submenu)
        add([38, 36], baseImageID: 1_518, evidence: submenu)
        add([39, 40, 41], baseImageID: 1_521, evidence: submenu)
        add([43, 42, 44], baseImageID: 1_524, evidence: submenu)
        add([47, 45, 46], baseImageID: 1_527, evidence: submenu)
        add([59, 60], baseImageID: 1_536, evidence: submenu)
        add([66, 67, 65, 70, 69, 64, 68], baseImageID: 1_539, evidence: submenu)
        add([48, 49], baseImageID: 1_581, evidence: submenu)
        add([215, 216], baseImageID: 1_599, evidence: submenu)
        add([217, 218], baseImageID: 1_602, evidence: submenu)
        add([224, 225], baseImageID: 1_614, evidence: submenu)
        add([131, 129, 130], baseImageID: 1_620, evidence: submenu)
        add([116, 243, 244, 245, 117, 246, 247, 248], baseImageID: 1_629, evidence: submenu)
        add([119, 251, 120, 252, 121, 122], baseImageID: 1_632, evidence: submenu)
        add([111, 113], baseImageID: 1_635, evidence: submenu)
        add([231, 91, 90, 89], baseImageID: 1_638, evidence: submenu)
        add([118, 249, 250], baseImageID: 1_641, evidence: submenu)
        add([52, 235, 236], baseImageID: 1_647, evidence: submenu)

        // The monument category fills up to four live entries from 0x855D88;
        // every emitted building ID receives family index 55 (#1653).
        add(
            Array(76...84) + [92, 93] + Array(253...268),
            baseImageID: 1_653,
            evidence: direct
        )

        return result
    }()

    public static func baseImageID(forFamilyIndex familyIndex: Int) -> Int {
        1_488 + familyIndex * 3
    }

    public static func imageID(
        forFamilyIndex familyIndex: Int,
        state: OriginalConstructionButtonState = .normal
    ) -> Int {
        baseImageID(forFamilyIndex: familyIndex) + state.rawValue
    }

    public static func imageID(
        forBuildingID buildingID: Int,
        state: OriginalConstructionButtonState = .normal
    ) -> Int? {
        mappingByBuildingID[buildingID].map { $0.baseImageID + state.rawValue }
    }

    /// Returns the evidence class for the association used by `imageID`.
    /// A missing association is deliberately `unknown`; callers must not
    /// synthesize a Bbutton from a model/building id or from `4A5960`.
    public static func evidence(
        forBuildingID buildingID: Int
    ) -> OriginalConstructionButtonEvidence {
        mappingByBuildingID[buildingID]?.evidence ?? .unknown
    }

    /// Building IDs currently covered by the executable-derived map. This is
    /// useful for diagnostics and tests without exposing the implementation
    /// dictionary to player-facing code.
    public static var mappedBuildingIDs: Set<Int> {
        Set(mappingByBuildingID.keys)
    }

    /// Crop buttons are semantic because several crop models intentionally
    /// share the same original field or orchard artwork.
    ///
    /// The original executable maps every member of `BUILD_CROPS` (including
    /// rice and hemp) to the shared #1500 family, while tea, mulberry, and
    /// lacquer use the shared orchard #1509 family. The #1503 family belongs
    /// to the irrigation submenu, not to hemp.
    public static func cropImageID(
        for crop: AgriculturalCrop,
        state: OriginalConstructionButtonState = .normal
    ) -> Int {
        let base: Int
        switch crop {
        case .tea, .mulberry, .lacquer:
            base = 1_509
        case .soybeans, .cabbage, .millet, .wheat, .rice, .hemp:
            base = 1_500
        }
        return base + state.rawValue
    }

    /// Compatibility overload for callers that only know the crop family.
    /// Prefer `cropImageID(for:state:)` when the semantic crop is available.
    public static func cropImageID(
        isRice: Bool,
        isOrchard: Bool,
        state: OriginalConstructionButtonState = .normal
    ) -> Int {
        let base = isOrchard ? 1_509 : 1_500
        return base + state.rawValue
    }

    public static var requiredImageIDs: Set<Int> {
        let buildingIDs = mappingByBuildingID.values.flatMap { mapping in
            OriginalConstructionButtonState.allCases.map {
                mapping.baseImageID + $0.rawValue
            }
        }
        let cropIDs = [1_500, 1_509].flatMap { base in
            OriginalConstructionButtonState.allCases.map { base + $0.rawValue }
        }
        return Set(buildingIDs + cropIDs)
    }
}
