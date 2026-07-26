import Foundation

/// One serialized map object from the Campaign Creator's `cEmpire` vector.
public struct CampaignEmpireObject: Identifiable, Sendable, Hashable {
    public let id: Int
    public let schemaVersion: UInt16
    /// City slot carried by city-marker objects in the original empire map.
    public let linkedCityID: Int?
    public let rawPayload: Data
}

/// The per-city relationship state retained by the original simulation.
///
/// The game allocates one entry for every possible destination city. Most of
/// this state changes while a mission is running, so the untouched payload is
/// retained until those diplomacy and military systems are implemented.
public struct CampaignCityRelationship: Identifiable, Sendable, Hashable {
    public let id: Int
    public let schemaVersion: UInt16
    public let rawPayload: Data
}

/// A fixed city slot from the Campaign Creator's empire map.
public struct CampaignEmpireCity: Identifiable, Sendable, Hashable {
    public static let maximumTradeCommodityCount = 36

    public let id: Int
    public let schemaVersion: UInt16
    public let isActive: Bool
    public let cityTypeRawValue: UInt8
    public let nameID: Int
    /// Initial opinion of the player, stored as a 0...100 value in the
    /// original fixed city prefix.
    public let initialFavor: Int
    /// Index of this city's marker in the serialized `EmpireObject` vector.
    public let empireObjectID: Int
    /// Original visit interval. `Trade.txt` defines land as 34 and sea as 4.
    public let tradeVisitInterval: Int
    /// Goods this city buys from the player's city.
    public let demandCommodityIDs: [Int]
    /// Goods this city sells to the player's city.
    public let supplyCommodityIDs: [Int]
    /// Original February-to-January quota, in displayed 100-unit loads.
    public let annualLoadsByCommodityID: [Int: Int]
    /// Prices converted from the original half-unit storage representation.
    public let priceByCommodityID: [Int: Int]
    public let relationships: [CampaignCityRelationship]
    public let rawPrefix: Data
    public let rawPostlude: Data

    public func routeKind(using tradeRules: TradeRules) -> TradeRouteKind? {
        if tradeVisitInterval == tradeRules.landFrequency { return .land }
        if tradeVisitInterval == tradeRules.seaFrequency { return .sea }
        return nil
    }

    /// Converts the original campaign city record into the native trade model.
    public func tradePartner(name: String, tradeRules: TradeRules) -> TradePartner? {
        guard isActive, let routeKind = routeKind(using: tradeRules) else { return nil }
        let demand = demandCommodityIDs.reduce(into: [Int: TradeVolumeLevel]()) { result, commodityID in
            guard tradeRules[commodityID: commodityID] != nil,
                  let volume = tradeVolume(for: commodityID), volume != .none else { return }
            result[commodityID] = volume
        }
        let supply = supplyCommodityIDs.reduce(into: [Int: TradeVolumeLevel]()) { result, commodityID in
            guard tradeRules[commodityID: commodityID] != nil,
                  let volume = tradeVolume(for: commodityID), volume != .none else { return }
            result[commodityID] = volume
        }
        guard !demand.isEmpty || !supply.isEmpty,
              demand.count <= 4,
              supply.count <= 4,
              demand.count + supply.count <= 8,
              Set(demand.keys).isDisjoint(with: supply.keys) else { return nil }
        return TradePartner(
            id: id,
            name: name,
            routeKind: routeKind,
            demandByCommodityID: demand,
            supplyByCommodityID: supply,
            priceByCommodityID: priceByCommodityID
        )
    }

    private func tradeVolume(for commodityID: Int) -> TradeVolumeLevel? {
        guard let annualLoads = annualLoadsByCommodityID[commodityID],
              annualLoads.isMultiple(of: 12) else { return nil }
        return TradeVolumeLevel(rawValue: annualLoads / 12)
    }
}

/// The original empire/world map embedded after the campaign goal tables.
///
/// `EmperorEdit.exe` serializes a variable `EmpireObject` vector followed by
/// 22 fixed-size city records. This parser is read-only and validates every
/// nested MFC schema marker before accepting a candidate signature.
public struct CampaignEmpireMap: Sendable, Hashable {
    public static let empireObjectCountOffset = 0xA018
    public static let empireObjectByteCount = 40
    public static let maximumEmpireObjectCount = 200
    public static let cityCount = 22
    public static let cityByteCount = 15_366
    public static let cityPrefixByteCount = 1_194
    public static let relationshipCount = 22
    public static let relationshipByteCount = 629

    public let sourceURL: URL
    /// Offset inside the concatenated, decoded Sierra chunks.
    public let decodedOffset: Int
    public let objects: [CampaignEmpireObject]
    public let cities: [CampaignEmpireCity]

    public var activeCities: [CampaignEmpireCity] { cities.filter(\.isActive) }
    public var tradingCities: [CampaignEmpireCity] {
        activeCities.filter { !$0.demandCommodityIDs.isEmpty || !$0.supplyCommodityIDs.isEmpty }
    }

    public init(contentsOf url: URL) throws {
        let decoded = try SierraChunkedFile(contentsOf: url).decodedData
        guard let parsed = try Self.parseIfPresent(decoded: decoded, sourceURL: url) else {
            throw GameDataError.malformedFile("campaign empire map")
        }
        self = parsed
    }

    /// Returns `nil` for older/custom campaigns that contain no empire map.
    public static func loadIfPresent(campaignURL: URL) throws -> CampaignEmpireMap? {
        let decoded = try SierraChunkedFile(contentsOf: campaignURL).decodedData
        return try parseIfPresent(decoded: decoded, sourceURL: campaignURL)
    }

    private static let signature = Data([0x02, 0x00, 0x06, 0x00])

    private static func parseIfPresent(decoded: Data, sourceURL: URL) throws -> CampaignEmpireMap? {
        var offsets: [Int] = []
        var searchStart = decoded.startIndex
        while searchStart < decoded.endIndex,
              let match = decoded.range(of: signature, in: searchStart..<decoded.endIndex) {
            if validatesCandidate(in: decoded, at: match.lowerBound) {
                offsets.append(match.lowerBound)
            }
            searchStart = match.lowerBound + 1
        }
        guard !offsets.isEmpty else { return nil }
        guard offsets.count == 1, let offset = offsets.first else {
            throw GameDataError.malformedFile("ambiguous campaign empire map")
        }
        return try parse(in: decoded, at: offset, sourceURL: sourceURL)
    }

    private static func validatesCandidate(in data: Data, at offset: Int) -> Bool {
        guard let objectCount = uint32LE(in: data, at: offset + empireObjectCountOffset).map(Int.init),
              (0...maximumEmpireObjectCount).contains(objectCount) else { return false }
        let objectBase = offset + empireObjectCountOffset + 4
        let cityBase = objectBase + objectCount * empireObjectByteCount
        guard cityBase >= objectBase,
              cityBase + cityCount * cityByteCount <= data.count else { return false }
        for index in 0..<objectCount where
            uint16LE(in: data, at: objectBase + index * empireObjectByteCount) != 2 {
            return false
        }
        for cityIndex in 0..<cityCount {
            let cityOffset = cityBase + cityIndex * cityByteCount
            guard uint16LE(in: data, at: cityOffset) == 15 else { return false }
            for relationshipIndex in 0..<relationshipCount where
                uint16LE(
                    in: data,
                    at: cityOffset + cityPrefixByteCount + relationshipIndex * relationshipByteCount
                ) != 5 {
                return false
            }
        }
        return true
    }

    private static func parse(in data: Data, at offset: Int, sourceURL: URL) throws -> CampaignEmpireMap {
        let objectCount = Int(try requiredUInt32LE(
            in: data,
            at: offset + empireObjectCountOffset,
            field: "empire object count"
        ))
        let objectBase = offset + empireObjectCountOffset + 4
        var objects: [CampaignEmpireObject] = []
        objects.reserveCapacity(objectCount)
        for index in 0..<objectCount {
            let recordOffset = objectBase + index * empireObjectByteCount
            let schema = try requiredUInt16LE(in: data, at: recordOffset, field: "empire object schema")
            objects.append(CampaignEmpireObject(
                id: index,
                schemaVersion: schema,
                linkedCityID: {
                    let candidate = Int(data[recordOffset + 2 + 24])
                    return candidate < cityCount ? candidate : nil
                }(),
                rawPayload: data.subdata(in: (recordOffset + 2)..<(recordOffset + empireObjectByteCount))
            ))
        }

        let cityBase = objectBase + objectCount * empireObjectByteCount
        var cities: [CampaignEmpireCity] = []
        cities.reserveCapacity(cityCount)
        for cityIndex in 0..<cityCount {
            let cityOffset = cityBase + cityIndex * cityByteCount
            let schema = try requiredUInt16LE(in: data, at: cityOffset, field: "city schema")
            let prefix = data.subdata(in: (cityOffset + 2)..<(cityOffset + cityPrefixByteCount))
            let relationshipBase = cityOffset + cityPrefixByteCount
            var relationships: [CampaignCityRelationship] = []
            relationships.reserveCapacity(relationshipCount)
            for relationshipIndex in 0..<relationshipCount {
                let relationshipOffset = relationshipBase + relationshipIndex * relationshipByteCount
                let relationshipSchema = try requiredUInt16LE(
                    in: data,
                    at: relationshipOffset,
                    field: "city relationship schema"
                )
                relationships.append(CampaignCityRelationship(
                    id: relationshipIndex,
                    schemaVersion: relationshipSchema,
                    rawPayload: data.subdata(
                        in: (relationshipOffset + 2)..<(relationshipOffset + relationshipByteCount)
                    )
                ))
            }

            let postludeOffset = relationshipBase + relationshipCount * relationshipByteCount
            let postlude = data.subdata(in: postludeOffset..<(cityOffset + cityByteCount))
            let demandIDs = commodityIDs(in: prefix, at: 1_110)
            let supplyIDs = commodityIDs(in: prefix, at: 1_114)
            let tradedIDs = Set(demandIDs + supplyIDs)
            var annualLoads: [Int: Int] = [:]
            var prices: [Int: Int] = [:]
            for commodityID in tradedIDs where commodityID < CampaignEmpireCity.maximumTradeCommodityCount {
                let loads = Int(prefix[1_008 + commodityID])
                if loads > 0 { annualLoads[commodityID] = loads }
                if let storedPrice = uint16LE(in: prefix, at: 1_118 + commodityID * 2), storedPrice > 0 {
                    prices[commodityID] = Int(storedPrice) / 2
                }
            }
            cities.append(CampaignEmpireCity(
                id: cityIndex,
                schemaVersion: schema,
                isActive: prefix[0] != 0,
                cityTypeRawValue: prefix[2],
                nameID: Int(prefix[3]),
                initialFavor: min(100, Int(prefix[52])),
                empireObjectID: Int(prefix[37]),
                tradeVisitInterval: Int(int16LE(in: prefix, at: 66) ?? 0),
                demandCommodityIDs: demandIDs,
                supplyCommodityIDs: supplyIDs,
                annualLoadsByCommodityID: annualLoads,
                priceByCommodityID: prices,
                relationships: relationships,
                rawPrefix: prefix,
                rawPostlude: postlude
            ))
        }
        return CampaignEmpireMap(
            sourceURL: sourceURL,
            decodedOffset: offset,
            objects: objects,
            cities: cities
        )
    }

    private init(
        sourceURL: URL,
        decodedOffset: Int,
        objects: [CampaignEmpireObject],
        cities: [CampaignEmpireCity]
    ) {
        self.sourceURL = sourceURL
        self.decodedOffset = decodedOffset
        self.objects = objects
        self.cities = cities
    }

    private static func commodityIDs(in prefix: Data, at offset: Int) -> [Int] {
        prefix[offset..<(offset + 4)].compactMap { byte in
            let id = Int(byte)
            return (1..<CampaignEmpireCity.maximumTradeCommodityCount).contains(id) ? id : nil
        }
    }

    private static func uint16LE(in data: Data, at offset: Int) -> UInt16? {
        guard offset >= 0, offset + 2 <= data.count else { return nil }
        return UInt16(data[offset]) | UInt16(data[offset + 1]) << 8
    }

    private static func int16LE(in data: Data, at offset: Int) -> Int16? {
        uint16LE(in: data, at: offset).map(Int16.init(bitPattern:))
    }

    fileprivate static func uint32LE(in data: Data, at offset: Int) -> UInt32? {
        guard offset >= 0, offset + 4 <= data.count else { return nil }
        return UInt32(data[offset])
            | UInt32(data[offset + 1]) << 8
            | UInt32(data[offset + 2]) << 16
            | UInt32(data[offset + 3]) << 24
    }

    private static func requiredUInt16LE(in data: Data, at offset: Int, field: String) throws -> UInt16 {
        guard let value = uint16LE(in: data, at: offset) else {
            throw GameDataError.malformedFile(field)
        }
        return value
    }

    private static func requiredUInt32LE(in data: Data, at offset: Int, field: String) throws -> UInt32 {
        guard let value = uint32LE(in: data, at: offset) else {
            throw GameDataError.malformedFile(field)
        }
        return value
    }
}

/// Original city names from text group 21 in `EmperorText.eng`.
public struct OriginalCityNameCatalog: Sendable, Hashable {
    public static let cityNameGroupID = 21
    private static let groupTableOffset = 0x20
    private static let groupRecordByteCount = 8
    private static let groupRecordCapacity = 1_000
    private static let textDataOffset = 28 + groupRecordCapacity * groupRecordByteCount

    public let names: [String]

    public init(contentsOf url: URL) throws {
        let data = try Data(contentsOf: url, options: [.mappedIfSafe])
        guard data.count >= Self.textDataOffset,
              String(data: Data(data.prefix(16)), encoding: .ascii) == "Emperor textfile" else {
            throw GameDataError.malformedFile("Emperor text header")
        }
        let groupOffset = Self.groupTableOffset + Self.cityNameGroupID * Self.groupRecordByteCount
        let previousOffset = groupOffset - Self.groupRecordByteCount
        guard let count = CampaignEmpireMap.uint32LE(in: data, at: groupOffset).map(Int.init),
              let start = CampaignEmpireMap.uint32LE(in: data, at: previousOffset + 4).map(Int.init),
              let end = CampaignEmpireMap.uint32LE(in: data, at: groupOffset + 4).map(Int.init),
              count > 0, start <= end, Self.textDataOffset + end <= data.count else {
            throw GameDataError.malformedFile("city name text group")
        }
        let bytes = data.subdata(in: (Self.textDataOffset + start)..<(Self.textDataOffset + end))
        var parsed: [String] = []
        var cursor = bytes.startIndex
        while parsed.count < count, cursor < bytes.endIndex,
              let terminator = bytes[cursor...].firstIndex(of: 0) {
            guard let name = String(data: bytes[cursor..<terminator], encoding: .windowsCP1252) else {
                throw GameDataError.malformedFile("city name encoding")
            }
            parsed.append(name)
            cursor = terminator + 1
        }
        guard parsed.count == count else {
            throw GameDataError.malformedFile("city name count")
        }
        names = parsed
    }

    public subscript(nameID id: Int) -> String? {
        names.indices.contains(id) ? names[id] : nil
    }
}
