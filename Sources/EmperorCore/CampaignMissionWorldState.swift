import Foundation

/// The original world-map state required to start one campaign mission.
///
/// This joins the Campaign Creator's per-mission settings and map assignment,
/// its player-city slot, and the empire city's authored trade routes. Keeping
/// the join in EmperorCore prevents the native UI from having to infer a city
/// or starting economy from filenames.
public struct CampaignMissionWorldState: Sendable, Hashable {
    public let missionID: Int
    public let startSettings: CampaignMissionStartSettings
    public let mapAssignment: CampaignMissionMapAssignment
    public let playerCity: CampaignEmpireCity?
    public let playerCityName: String
    public let tradePartners: [TradePartner]

    public var agriculturalClimate: AgriculturalClimate {
        OriginalAgriculturalClimateCatalog.climate(
            forMapFileName: mapAssignment.embeddedMap.mapURL.lastPathComponent
        )
    }

    public init(
        missionID: Int,
        missionSettings: CampaignMissionSettingsArchive,
        missionMaps: CampaignMissionMapArchive,
        empireMap: CampaignEmpireMap?,
        cityNames: OriginalCityNameCatalog,
        tradeRules: TradeRules
    ) throws {
        guard let startSettings = missionSettings.missions.first(where: { $0.id == missionID }) else {
            throw GameDataError.malformedFile("campaign mission start settings")
        }
        guard let assignment = missionMaps.missions.first(where: { $0.id == missionID }) else {
            throw GameDataError.malformedFile("campaign mission world assignment")
        }
        let playerCity: CampaignEmpireCity?
        let playerCityName: String
        let partners: [TradePartner]
        if let empireMap {
            guard empireMap.cities.indices.contains(assignment.playerCityID) else {
                throw GameDataError.malformedFile("campaign player city slot")
            }
            let authoredPlayerCity = empireMap.cities[assignment.playerCityID]
            guard authoredPlayerCity.isActive,
                  empireMap.objects.indices.contains(authoredPlayerCity.empireObjectID),
                  empireMap.objects[authoredPlayerCity.empireObjectID].linkedCityID
                    == authoredPlayerCity.id,
                  let authoredName = cityNames[nameID: authoredPlayerCity.nameID] else {
                throw GameDataError.malformedFile("campaign player city marker")
            }
            playerCity = authoredPlayerCity
            playerCityName = authoredName
            partners = empireMap.tradingCities
                .filter { $0.id != authoredPlayerCity.id }
                .compactMap { city -> TradePartner? in
                    guard let name = cityNames[nameID: city.nameID] else { return nil }
                    return city.tradePartner(name: name, tradeRules: tradeRules)
                }
                .sorted { $0.id < $1.id }
        } else {
            // Older/custom campaigns can contain complete maps, settings,
            // goals and events without an empire section. They remain valid
            // single-city missions with no initial world-map trade routes.
            playerCity = nil
            playerCityName = "独立城市"
            partners = []
        }

        self.missionID = missionID
        self.startSettings = startSettings
        mapAssignment = assignment
        self.playerCity = playerCity
        self.playerCityName = playerCityName
        tradePartners = partners
    }

    /// Installs every route authored on the original empire map into a fresh
    /// deterministic city state. Trading buildings remain a player decision.
    @discardableResult
    public func installTradePartners(
        in city: inout DeterministicCityState,
        rules: EconomyRulesEngine
    ) -> Int {
        tradePartners.count { city.addTradePartner($0, rules: rules) }
    }
}
