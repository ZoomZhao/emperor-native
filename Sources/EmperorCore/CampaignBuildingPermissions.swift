import Foundation

/// A reason the original Campaign Creator would keep a construction item out
/// of the player's build menu.
public enum CampaignConstructionRestriction: Sendable, Hashable {
    /// The named item is disabled in the mission's 56-entry Buildings Allowed list.
    case buildingNotAllowed(menuID: Int, name: String)
    /// Raw-material and agricultural producers are controlled by local city resources.
    case localResourceNotAllowed(commodityID: Int)
    /// A manufacturer is enabled, but none of its complete input combinations can be acquired.
    case requiredInputsUnavailable(options: [[Int]])
}

/// Exact order of text group 67 in the shipping `EmperorText.eng` file, plus
/// its mapping back to original building-model IDs.
///
/// Campaign archives store the selected list index (1...56), not a building
/// ID. Several visual variants deliberately share one permission entry.
public enum OriginalCampaignBuildingPermissionCatalog {
    public static let menuNames: [String] = [
        "",
        "Roadblock", "Elite Housing", "Irrigation Pump", "Mint", "Money Printer",
        "Lacquerware Maker", "Weaver", "Bronzeware Maker", "Kiln", "Paper Maker",
        "Jade Carver's Studio", "Mill", "Common Market", "Grand Market", "Warehouse",
        "Trade Buildings", "Music School", "Acrobat School", "Drama School",
        "Ancestral Shrine", "Daoist Shrine", "Buddhist Shrine", "Daoist Temple",
        "Buddhist Pagoda", "Confucian Academy", "Well", "Herbalist's Stall",
        "Acupuncturist's Clinic", "Inspector's Tower", "Watchtower", "Imperial Way",
        "Grand Way", "Gardens", "Decorative Sculptures", "Ornate Sculptures",
        "Flowering tree", "Wayside Pavilion", "Pond", "Tai Chi Park", "Private Garden",
        "Residential Wall", "Administrative City", "Palace", "Tax Office", "Bridge",
        "Ferry", "Tower", "City Wall", "City Gate", "Weaponsmith", "Crossbowmen Fort",
        "Infantry Fort", "Cavalry Fort", "Chariot Fort", "Catapult Fort",
        "Theatre Pavilion"
    ]

    private static let menuIDByBuildingID: [Int: Int] = {
        var result: [Int: Int] = [
            126: 1, 11: 2, 203: 3, 48: 4, 49: 5,
            44: 6, 47: 7, 42: 8, 43: 9, 45: 10, 46: 11,
            53: 12, 59: 13, 60: 14, 54: 15, 56: 16, 58: 16,
            211: 17, 212: 18, 213: 19, 214: 20, 215: 21,
            217: 22, 216: 23, 218: 24, 219: 25,
            72: 26, 207: 27, 208: 28, 124: 29, 127: 30,
            113: 31, 111: 32, 115: 33,
            116: 34, 117: 35, 118: 36, 119: 37, 120: 38,
            121: 39, 122: 40,
            209: 42, 110: 43, 125: 44, 123: 45, 210: 46,
            131: 47, 129: 48, 130: 49, 226: 50,
            220: 51, 221: 52, 224: 53, 225: 54, 223: 55, 75: 56
        ]
        for buildingID in [243, 244, 245] { result[buildingID] = 34 }
        for buildingID in [246, 247, 248] { result[buildingID] = 35 }
        for buildingID in [249, 250] { result[buildingID] = 36 }
        result[251] = 37
        result[252] = 38
        for buildingID in [89, 90, 91, 104, 105, 106, 231, 232] {
            result[buildingID] = 41
        }
        return result
    }()

    /// Producers omitted from the Buildings Allowed dialog. The guide states
    /// that their local output resource alone determines whether they appear.
    private static let localResourceCommodityIDByBuildingID: [Int: Int] = [
        31: 2,   // Fishing Quay -> Fish
        33: 4,   // Hunter's Tent -> Meat
        35: 18,  // Clay Pit -> Clay
        36: 20,  // Stoneworks -> Stone
        37: 8,   // Salt Mine -> Salt
        38: 10,  // Logging Shed -> Wood
        39: 11,  // Bronze Smelter -> Bronze
        40: 15,  // Iron Smelter -> Iron
        41: 16,  // Steel Furnace -> Steel
        192: 19, // Hemp Farm -> Hemp
        237: 13, // Tea Curing Shed -> Tea
        238: 14, // Lacquer Refinery -> Lacquer
        239: 12  // Silkworm Shed -> Raw Silk
    ]

    /// Complete raw-material combinations for manufacturers. Every commodity
    /// in one option must be available locally or from an open trade partner.
    private static let inputOptionsByBuildingID: [Int: [[Int]]] = [
        42: [[11, 18]], // Bronzeware Maker
        43: [[18]],     // Kiln
        44: [[14, 10]], // Lacquerware Maker
        45: [[19]],     // Paper Maker
        46: [[17]],     // Jade Carver's Studio
        47: [[12]],     // Weaver
        49: [[27]],     // Money Printer
        226: [[11], [15], [16]] // Weaponsmith
    ]

    public static func menuName(forMenuID menuID: Int) -> String? {
        menuNames.indices.contains(menuID) && menuID > 0 ? menuNames[menuID] : nil
    }

    public static func menuID(forBuildingID buildingID: Int) -> Int? {
        menuIDByBuildingID[buildingID]
    }

    public static func localResourceCommodityID(forBuildingID buildingID: Int) -> Int? {
        localResourceCommodityIDByBuildingID[buildingID]
    }

    public static func requiredInputOptions(forBuildingID buildingID: Int) -> [[Int]] {
        inputOptionsByBuildingID[buildingID] ?? []
    }
}

public extension CampaignMissionStartSettings {
    /// Applies the original build-menu rules without requiring a city state.
    /// Sandbox cities have no mission settings and therefore never call this.
    func constructionRestriction(
        forBuildingID buildingID: Int,
        openTradePartners: [TradePartner] = []
    ) -> CampaignConstructionRestriction? {
        if let menuID = OriginalCampaignBuildingPermissionCatalog.menuID(
            forBuildingID: buildingID
        ), !allowedBuildingMenuIDs.contains(menuID) {
            return .buildingNotAllowed(
                menuID: menuID,
                name: OriginalCampaignBuildingPermissionCatalog.menuName(forMenuID: menuID)
                    ?? "Building #\(menuID)"
            )
        }

        if let commodityID = OriginalCampaignBuildingPermissionCatalog.localResourceCommodityID(
            forBuildingID: buildingID
        ), !allowedResourceCommodityIDs.contains(commodityID) {
            return .localResourceNotAllowed(commodityID: commodityID)
        }

        let inputOptions = OriginalCampaignBuildingPermissionCatalog.requiredInputOptions(
            forBuildingID: buildingID
        )
        guard !inputOptions.isEmpty else { return nil }
        let importedCommodityIDs = openTradePartners.reduce(into: Set<Int>()) { available, partner in
            guard partner.isOpen else { return }
            available.formUnion(partner.supplyByCommodityID.compactMap { commodityID, level in
                level == .none ? nil : commodityID
            })
        }
        let obtainableCommodityIDs = Set(allowedResourceCommodityIDs).union(importedCommodityIDs)
        guard inputOptions.contains(where: { option in
            Set(option).isSubset(of: obtainableCommodityIDs)
        }) else {
            return .requiredInputsUnavailable(options: inputOptions)
        }
        return nil
    }
}
