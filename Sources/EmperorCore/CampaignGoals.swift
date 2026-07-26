import Foundation

public enum CampaignGoalKind: String, CaseIterable, Sendable, Hashable {
    case alliedCities = "cAlliedCitiesGoal"
    case conquer = "cConquerGoal"
    case homage = "cHomageGoal"
    case housing = "cHousingGoal"
    case menagerie = "cMenagerieGoal"
    case monument = "cMonumentGoal"
    case population = "cPopulationGoal"
    case tradingPartners = "cTradingPartnersGoal"
    case treasury = "cTreasuryGoal"
    case yearlyProduction = "cYearlyProductionGoal"
    case yearlyProfit = "cYearlyProfitGoal"

    fileprivate var valueWordCount: Int {
        switch self {
        case .population, .tradingPartners, .treasury:
            1
        case .alliedCities, .conquer, .homage, .menagerie, .monument, .yearlyProfit:
            2
        case .housing, .yearlyProduction:
            3
        }
    }
}

public struct CampaignMissionGoal: Identifiable, Sendable, Hashable {
    public let id: Int
    public let kind: CampaignGoalKind
    public let classSchema: UInt16
    public let objectVersion: UInt16
    public let typeID: UInt32
    public let variant: UInt16
    public let values: [UInt32]

    public init(
        id: Int,
        kind: CampaignGoalKind,
        classSchema: UInt16 = 0,
        objectVersion: UInt16 = 0,
        typeID: UInt32 = 0,
        variant: UInt16 = 0,
        values: [UInt32]
    ) {
        self.id = id
        self.kind = kind
        self.classSchema = classSchema
        self.objectVersion = objectVersion
        self.typeID = typeID
        self.variant = variant
        self.values = values
    }
}

public struct CampaignMissionGoalSet: Identifiable, Sendable, Hashable {
    public let id: Int
    public let listVersion: UInt16
    public let goals: [CampaignMissionGoal]

    public init(id: Int, listVersion: UInt16 = 1, goals: [CampaignMissionGoal]) {
        self.id = id
        self.listVersion = listVersion
        self.goals = goals
    }
}

public struct CampaignGoalArchive: Sendable, Hashable {
    public let sectionOffset: Int?
    public let endOffset: Int?
    public let missions: [CampaignMissionGoalSet]

    public init(campaignURL: URL, missionCount: Int) throws {
        let decoded = try SierraChunkedFile(contentsOf: campaignURL).decodedData
        guard let sectionOffset = Self.detectSectionOffset(in: decoded) else {
            self.sectionOffset = nil
            endOffset = nil
            missions = (0..<missionCount).map {
                CampaignMissionGoalSet(id: $0, listVersion: 1, goals: [])
            }
            return
        }
        var reader = BinaryReader(data: decoded, offset: sectionOffset)
        var runtimeClasses: [UInt16: (kind: CampaignGoalKind, schema: UInt16)] = [:]
        var nextPersistentID: UInt16 = 1
        var parsedMissions: [CampaignMissionGoalSet] = []
        parsedMissions.reserveCapacity(missionCount)
        var nextGoalID = 0

        for missionIndex in 0..<missionCount {
            let listVersion = try reader.readUInt16LE()
            let goalCount = Int(try reader.readUInt32LE())
            guard listVersion == 1, (0...8).contains(goalCount) else {
                throw GameDataError.malformedFile("campaign goal list #\(missionIndex)")
            }
            var goals: [CampaignMissionGoal] = []
            goals.reserveCapacity(goalCount)
            for _ in 0..<goalCount {
                let classTag = try reader.readUInt16LE()
                let descriptor: (kind: CampaignGoalKind, schema: UInt16)
                if classTag == 0xffff {
                    let schema = try reader.readUInt16LE()
                    let nameLength = Int(try reader.readUInt16LE())
                    guard (1...64).contains(nameLength),
                          let name = String(data: try reader.readData(count: nameLength), encoding: .ascii),
                          let kind = CampaignGoalKind(rawValue: name) else {
                        throw GameDataError.malformedFile("campaign goal runtime class")
                    }
                    descriptor = (kind, schema)
                    runtimeClasses[nextPersistentID] = descriptor
                    nextPersistentID &+= 1
                } else if classTag & 0x8000 != 0 {
                    let classID = classTag & 0x7fff
                    guard let knownClass = runtimeClasses[classID] else {
                        throw GameDataError.malformedFile("campaign goal class reference \(classID)")
                    }
                    descriptor = knownClass
                } else {
                    throw GameDataError.malformedFile(
                        "campaign goal object tag 0x\(String(classTag, radix: 16)) at 0x\(String(reader.offset - 2, radix: 16)) in mission \(missionIndex)"
                    )
                }

                // MFC assigns a persistent ID to the object immediately after its
                // runtime-class descriptor/reference. Goal objects are never shared,
                // but retaining the sequence is required to resolve later class tags.
                nextPersistentID &+= 1
                let objectVersion = try reader.readUInt16LE()
                let typeID = try reader.readUInt32LE()
                let variant = try reader.readUInt16LE()
                var values: [UInt32] = []
                values.reserveCapacity(descriptor.kind.valueWordCount)
                for _ in 0..<descriptor.kind.valueWordCount {
                    values.append(try reader.readUInt32LE())
                }
                goals.append(CampaignMissionGoal(
                    id: nextGoalID,
                    kind: descriptor.kind,
                    classSchema: descriptor.schema,
                    objectVersion: objectVersion,
                    typeID: typeID,
                    variant: variant,
                    values: values
                ))
                nextGoalID += 1
            }
            parsedMissions.append(CampaignMissionGoalSet(
                id: missionIndex,
                listVersion: listVersion,
                goals: goals
            ))
        }

        self.sectionOffset = sectionOffset
        endOffset = reader.offset
        missions = parsedMissions
    }

    private static func detectSectionOffset(in data: Data) -> Int? {
        var candidates: [Int] = []
        for kind in CampaignGoalKind.allCases {
            let pattern = Data(kind.rawValue.utf8)
            var searchStart = data.startIndex
            while searchStart < data.endIndex,
                  let match = data.range(of: pattern, in: searchStart..<data.endIndex) {
                let nameOffset = match.lowerBound
                let sectionOffset = nameOffset - 12
                if sectionOffset >= 0,
                   data[sectionOffset] == 1,
                   data[sectionOffset + 1] == 0,
                   data[sectionOffset + 6] == 0xff,
                   data[sectionOffset + 7] == 0xff {
                    candidates.append(sectionOffset)
                }
                searchStart = match.lowerBound + 1
            }
        }
        return candidates.min()
    }
}
