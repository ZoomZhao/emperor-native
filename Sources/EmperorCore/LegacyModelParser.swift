import Foundation

public enum LegacyModelText {
    public static func read(_ url: URL) throws -> String {
        let data = try Data(contentsOf: url, options: [.mappedIfSafe])
        return String(data: data, encoding: .windowsCP1252) ?? String(decoding: data, as: UTF8.self)
    }
}

public struct LegacyINI: Sendable, Equatable {
    public let sections: [String: [String: String]]

    public init(text: String) {
        var result: [String: [String: String]] = [:]
        var section: String?
        for rawLine in text.components(separatedBy: .newlines) {
            let line = rawLine.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !line.isEmpty, !line.hasPrefix(";"), !line.hasPrefix("#"), !line.hasPrefix("//") else { continue }
            if line.hasPrefix("["), let closing = line.firstIndex(of: "]") {
                let name = String(line[line.index(after: line.startIndex)..<closing]).trimmingCharacters(in: .whitespaces)
                section = name
                if result[name] == nil { result[name] = [:] }
                continue
            }
            guard let section, let separator = line.firstIndex(of: "=") else { continue }
            let key = String(line[..<separator]).trimmingCharacters(in: .whitespaces)
            let value = String(line[line.index(after: separator)...]).trimmingCharacters(in: .whitespaces)
            guard !key.isEmpty else { continue }
            result[section, default: [:]][key] = value
        }
        sections = result
    }

    public init(contentsOf url: URL) throws {
        self.init(text: try LegacyModelText.read(url))
    }

    public func string(section: String, key: String) -> String? {
        guard let sectionEntry = sections.first(where: { $0.key.caseInsensitiveCompare(section) == .orderedSame })?.value else {
            return nil
        }
        return sectionEntry.first(where: { $0.key.caseInsensitiveCompare(key) == .orderedSame })?.value
    }

    public func integer(section: String, key: String) -> Int? {
        string(section: section, key: key).flatMap(Int.init)
    }

    public func decimal(section: String, key: String) -> Double? {
        string(section: section, key: key).flatMap(Double.init)
    }
}

public struct LegacyBraceRow: Identifiable, Sendable, Equatable {
    public let section: String
    public let id: Int
    public let name: String
    public let values: [Int]
}

public struct LegacyBraceTable: Sendable, Equatable {
    public let rows: [LegacyBraceRow]

    public init(text: String, sectionNames: Set<String>) {
        var parsed: [LegacyBraceRow] = []
        var section = ""
        for rawLine in text.components(separatedBy: .newlines) {
            let line = rawLine.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !line.isEmpty else { continue }
            let normalizedLine = line.split(whereSeparator: { $0.isWhitespace }).joined(separator: " ")
            if let matchedSection = sectionNames.first(where: { $0.caseInsensitiveCompare(normalizedLine) == .orderedSame }) {
                section = matchedSection
                continue
            }
            guard !section.isEmpty,
                  let opening = line.firstIndex(of: "{") else { continue }
            let closing = line[opening...].firstIndex(of: "}") ?? line.endIndex
            let prefix = line[..<opening]
            let firstComma = prefix.firstIndex(of: ",")
            let explicitID = firstComma.flatMap { Int(prefix[..<$0].trimmingCharacters(in: .whitespaces)) }
            let id = explicitID ?? parsed.count(where: { $0.section == section })
            var name: String
            if let firstComma, explicitID != nil {
                name = prefix[prefix.index(after: firstComma)...].trimmingCharacters(in: .whitespaces)
            } else {
                name = prefix.trimmingCharacters(in: .whitespaces)
            }
            while name.last == "," { name.removeLast() }
            name = name.trimmingCharacters(in: .whitespaces)
            let values = line[line.index(after: opening)..<closing]
                .split(separator: ",", omittingEmptySubsequences: true)
                .compactMap { Int($0.trimmingCharacters(in: .whitespaces)) }
            parsed.append(LegacyBraceRow(section: section, id: id, name: name, values: values))
        }
        rows = parsed
    }

    public init(contentsOf url: URL, sectionNames: Set<String>) throws {
        self.init(text: try LegacyModelText.read(url), sectionNames: sectionNames)
    }
}

public enum GameDifficulty: Int, CaseIterable, Sendable, Codable {
    case veryEasy
    case easy
    case normal
    case hard
    case veryHard
}

public struct TaxSentimentBand: Identifiable, Sendable, Equatable {
    public let id: Int
    public let name: String
    public let taxRatePercent: Int
    public let sentimentByDifficulty: [Int]

    public func sentiment(at difficulty: GameDifficulty) -> Int {
        sentimentByDifficulty[difficulty.rawValue]
    }
}

public struct TaxSentimentModel: Sendable, Equatable {
    public let bands: [TaxSentimentBand]

    public init(text: String) throws {
        var parsed: [TaxSentimentBand] = []
        for rawLine in text.components(separatedBy: .newlines) {
            let line = rawLine.trimmingCharacters(in: .whitespacesAndNewlines)
            guard let opening = line.firstIndex(of: "{"),
                  let closing = line[opening...].firstIndex(of: "}"),
                  let firstComma = line[..<opening].firstIndex(of: ",") else { continue }
            let name = line[..<firstComma].trimmingCharacters(in: .whitespaces)
            let values = line[line.index(after: opening)..<closing]
                .split(separator: ",", omittingEmptySubsequences: true)
                .compactMap { Int($0.trimmingCharacters(in: .whitespaces)) }
            guard values.count == 6 else { continue }
            parsed.append(TaxSentimentBand(
                id: parsed.count,
                name: name,
                taxRatePercent: values[0],
                sentimentByDifficulty: Array(values.dropFirst())
            ))
        }
        guard parsed.count == 7 else {
            throw GameDataError.malformedFile("tax sentiment table")
        }
        bands = parsed
    }

    public init(contentsOf url: URL) throws {
        try self.init(text: LegacyModelText.read(url))
    }
}

public struct BuildingModel: Identifiable, Sendable, Equatable {
    public let id: Int
    public let name: String
    public let cost: Int
    public let initialDesirability: Int
    public let desirabilityStep: Int
    public let desirabilityStepSize: Int
    public let maximumDesirabilityRange: Int
    public let employees: Int
    public let fireRiskIncrement: Int
    public let damageRiskIncrement: Int
    public let resourceUsed: Int
    public let riskReducer: Int
    public let evolveDesirability: Int
    public let structuralIntegrity: Int
    public let fengShuiValue: Int

    init?(row: LegacyBraceRow) {
        guard row.values.count == 13 else { return nil }
        id = row.id
        name = row.name
        cost = row.values[0]
        initialDesirability = row.values[1]
        desirabilityStep = row.values[2]
        desirabilityStepSize = row.values[3]
        maximumDesirabilityRange = row.values[4]
        employees = row.values[5]
        fireRiskIncrement = row.values[6]
        damageRiskIncrement = row.values[7]
        resourceUsed = row.values[8]
        riskReducer = row.values[9]
        evolveDesirability = row.values[10]
        structuralIntegrity = row.values[11]
        fengShuiValue = row.values[12]
    }
}

public struct HouseModel: Identifiable, Sendable, Equatable {
    public let id: Int
    public let name: String
    public let devolveDesirability: Int
    public let evolveDesirability: Int
    public let herbalistRequired: Int
    public let waterRequired: Int
    public let acupunctureRequired: Int
    public let musicRequired: Int
    public let acrobatRequired: Int
    public let dramaRequired: Int
    public let foodQualityRequired: Int
    public let hempRequired: Int
    public let ceramicsRequired: Int
    public let teaRequired: Int
    public let silkRequired: Int
    public let luxuryWareRequired: Int
    public let crimeRiskIncrement: Int
    public let crimeRiskBase: Int
    public let populationCapacity: Int
    public let taxRateMultiplier: Int
    public let diseaseRiskIncrement: Int
    public let ancestorAccessRequired: Int
    public let confucianAccessRequired: Int
    public let daoistOrBuddhistAccessRequired: Int

    init?(row: LegacyBraceRow) {
        guard row.values.count == 24 else { return nil }
        id = row.id
        name = row.name
        devolveDesirability = row.values[0]
        evolveDesirability = row.values[1]
        herbalistRequired = row.values[2]
        waterRequired = row.values[3]
        acupunctureRequired = row.values[4]
        musicRequired = row.values[5]
        acrobatRequired = row.values[6]
        dramaRequired = row.values[7]
        foodQualityRequired = row.values[8]
        hempRequired = row.values[9]
        ceramicsRequired = row.values[10]
        teaRequired = row.values[11]
        silkRequired = row.values[12]
        luxuryWareRequired = row.values[13]
        crimeRiskIncrement = row.values[14]
        crimeRiskBase = row.values[15]
        populationCapacity = row.values[17]
        taxRateMultiplier = row.values[18]
        diseaseRiskIncrement = row.values[20]
        ancestorAccessRequired = row.values[21]
        confucianAccessRequired = row.values[22]
        daoistOrBuddhistAccessRequired = row.values[23]
    }
}

public struct BuildingModelTable: Sendable, Equatable {
    public let difficultyModifiers: [LegacyBraceRow]
    public let buildings: [BuildingModel]
    public let houseDifficultyModifiers: [LegacyBraceRow]
    public let houses: [HouseModel]

    public init(contentsOf url: URL) throws {
        let table = try LegacyBraceTable(
            contentsOf: url,
            sectionNames: ["BUILDING MODS", "ALL BUILDINGS", "HOUSE MODS", "ALL HOUSES"]
        )
        difficultyModifiers = table.rows.filter { $0.section == "BUILDING MODS" }
        buildings = table.rows.filter { $0.section == "ALL BUILDINGS" }.compactMap(BuildingModel.init)
        houseDifficultyModifiers = table.rows.filter { $0.section == "HOUSE MODS" }
        houses = table.rows.filter { $0.section == "ALL HOUSES" }.compactMap(HouseModel.init)
    }

    public subscript(buildingID id: Int) -> BuildingModel? {
        buildings.first { $0.id == id }
    }


    public subscript(houseLevelID id: Int) -> HouseModel? {
        houses.first { $0.id == id }
    }

    /// Returns the source `DAT_00A63BFC[row * 0x18 + 0x11]` capacity after
    /// the authored house-difficulty adjustment and the loader's inclusive
    /// `[-99, 100]` clamp (`ERR_No_Building_Model_file` / `FUN_005D16D0`).
    /// The row is the executable's zero-based `ALL HOUSES` index, not a
    /// building ID.  Keeping this lookup beside the parser prevents callers
    /// from silently substituting Native's current unadjusted model field.
    public func originalHouseCapacity(
        sourceRow: Int,
        difficulty: GameDifficulty = .normal
    ) -> Int? {
        guard let house = houses.first(where: { $0.id == sourceRow }) else {
            return nil
        }
        let modifier = houseDifficultyModifiers.indices.contains(difficulty.rawValue)
            && houseDifficultyModifiers[difficulty.rawValue].values.indices.contains(17)
            ? houseDifficultyModifiers[difficulty.rawValue].values[17]
            : 0
        return min(100, max(-99, house.populationCapacity + modifier))
    }
}

public struct FigureModel: Identifiable, Sendable, Equatable {
    public let id: Int
    public let name: String
    public let combatType: Int
    public let hitPoints: Int
    public let attack: Int
    public let armor: Int
    public let missileArmor: Int
    public let missileAttack: Int
    public let missileRange: Int
    public let missileRateOfFire: Int
    public let speed: Int
    public let periodPercentages: [Int]
    public let defensiveMoraleThreshold: Int
    /// For roaming service figures this field contains their maximum route range.
    public let behaviorRange: Int

    init?(row: LegacyBraceRow) {
        guard row.values.count == 18 else { return nil }
        id = row.id
        name = row.name
        combatType = row.values[0]
        hitPoints = row.values[1]
        attack = row.values[2]
        armor = row.values[3]
        missileArmor = row.values[4]
        missileAttack = row.values[5]
        missileRange = row.values[6]
        missileRateOfFire = row.values[7]
        speed = row.values[8]
        periodPercentages = Array(row.values[9...13])
        defensiveMoraleThreshold = row.values[14]
        behaviorRange = row.values[15]
    }
}

public struct FigureModelTable: Sendable, Equatable {
    public let figures: [FigureModel]
    /// Nation-specific enemy records from the original model file. Their IDs
    /// form a separate table and intentionally overlap the ordinary figures.
    public let enemies: [FigureModel]

    public init(contentsOf url: URL) throws {
        let table = try LegacyBraceTable(
            contentsOf: url,
            sectionNames: ["ALL FIGURES", "ALL ENEMIES"]
        )
        figures = table.rows
            .filter { $0.section == "ALL FIGURES" }
            .compactMap(FigureModel.init)
        enemies = table.rows
            .filter { $0.section == "ALL ENEMIES" }
            .compactMap(FigureModel.init)
    }

    public subscript(figureID id: Int) -> FigureModel? {
        figures.first { $0.id == id }
    }

    public subscript(enemyTypeID id: Int) -> FigureModel? {
        enemies.first { $0.id == id }
    }
}

public struct TradeCommodity: Identifiable, Sendable, Equatable {
    public let id: Int
    public let name: String
    public let price: Int
}

public struct TradeRules: Sendable, Equatable {
    public let commodities: [TradeCommodity]
    public let prices: [String: Int]
    public let landFrequency: Int
    public let seaFrequency: Int
    public let landCapacity: Int
    public let seaCapacity: Int

    public init(contentsOf url: URL) throws {
        let text = try LegacyModelText.read(url)
        let ini = LegacyINI(text: text)
        var parsedCommodities: [TradeCommodity] = []
        var isReadingPrices = false
        for rawLine in text.components(separatedBy: .newlines) {
            let line = rawLine.trimmingCharacters(in: .whitespacesAndNewlines)
            if line.hasPrefix("["), let closing = line.firstIndex(of: "]") {
                let section = String(line[line.index(after: line.startIndex)..<closing])
                isReadingPrices = section.caseInsensitiveCompare("DefaultPrices") == .orderedSame
                continue
            }
            guard isReadingPrices, let separator = line.firstIndex(of: "=") else { continue }
            let name = String(line[..<separator]).trimmingCharacters(in: .whitespaces)
            let value = String(line[line.index(after: separator)...]).trimmingCharacters(in: .whitespaces)
            guard !name.isEmpty, let price = Int(value) else { continue }
            parsedCommodities.append(TradeCommodity(id: parsedCommodities.count, name: name, price: price))
        }
        guard !parsedCommodities.isEmpty else {
            throw GameDataError.malformedFile("trade commodity prices")
        }
        commodities = parsedCommodities
        prices = Dictionary(uniqueKeysWithValues: parsedCommodities.map { ($0.name, $0.price) })
        guard let landFrequency = ini.integer(section: "Frequency", key: "Land"),
              let seaFrequency = ini.integer(section: "Frequency", key: "Sea"),
              let landCapacity = ini.integer(section: "Capacity", key: "Land"),
              let seaCapacity = ini.integer(section: "Capacity", key: "Sea") else {
            throw GameDataError.malformedFile("trade rules")
        }
        self.landFrequency = landFrequency
        self.seaFrequency = seaFrequency
        self.landCapacity = landCapacity
        self.seaCapacity = seaCapacity
    }

    public subscript(commodityID id: Int) -> TradeCommodity? {
        commodities.first { $0.id == id }
    }
}

public struct OriginalEconomyModels: Sendable, Equatable {
    public let trade: TradeRules
    public let taxSentiment: TaxSentimentModel
    public let buildings: BuildingModelTable
    public let figures: FigureModelTable
    public let farm: LegacyINI
    public let generalBuilding: LegacyINI

    public init(source: GameDataSource) throws {
        trade = try TradeRules(contentsOf: source.modelDirectory.appendingPathComponent("Trade.txt"))
        taxSentiment = try TaxSentimentModel(contentsOf: source.modelDirectory.appendingPathComponent("EmperorTaxSentimentModel.txt"))
        buildings = try BuildingModelTable(contentsOf: source.modelDirectory.appendingPathComponent("EmperorBuildingModels.txt"))
        figures = try FigureModelTable(contentsOf: source.modelDirectory.appendingPathComponent("EmperorFigureModels.txt"))
        farm = try LegacyINI(contentsOf: source.modelDirectory.appendingPathComponent("FarmConfig.txt"))
        generalBuilding = try LegacyINI(contentsOf: source.modelDirectory.appendingPathComponent("GeneralBuildingConfig.txt"))
    }
}
