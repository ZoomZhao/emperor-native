import Foundation

public struct OriginalMilitaryFortConfiguration: Sendable, Hashable, Codable {
    public let buildingID: Int
    public let figureID: Int
    public let soldierCount: Int

    public static func configuration(buildingID: Int) -> Self? {
        let figureID: Int
        switch buildingID {
        case 220: figureID = 65 // Crossbow Fort
        case 221: figureID = 64 // Infantry Fort
        case 223: figureID = 68 // Catapult Fort
        case 224: figureID = 66 // Cavalry Fort
        case 225: figureID = 67 // Chariot Fort
        default: return nil
        }
        return Self(buildingID: buildingID, figureID: figureID, soldierCount: 16)
    }
}

/// One object-vector row supplied to the executable's City Gate/Tower labor
/// allocator (`FUN_004AD850 @ 0x4AD850`).  The vector index is kept explicit:
/// the source scans objects in registry order and does not sort by building ID
/// or placement coordinates.  `noLaborFlag` is the raw object `+0x6E` byte
/// consumed by `FUN_00408B40`; `callbackEligible` is the already-resolved
/// vtable `+0x58` predicate.  These are deliberately raw gates, not Native
/// guesses about a defense's staffing semantics.
public struct OriginalMilitaryDefenseStaffingCandidate: Sendable, Hashable, Codable {
    public let vectorIndex: Int
    public let buildingID: Int
    public let noLaborFlag: Bool
    public let callbackEligible: Bool

    public init(
        vectorIndex: Int,
        buildingID: Int,
        noLaborFlag: Bool = false,
        callbackEligible: Bool = true
    ) {
        self.vectorIndex = vectorIndex
        self.buildingID = buildingID
        self.noLaborFlag = noLaborFlag
        self.callbackEligible = callbackEligible
    }
}

/// A single source labor assignment emitted for a City Gate/Tower row.
public struct OriginalMilitaryDefenseStaffingAssignment: Sendable, Hashable, Codable {
    public let vectorIndex: Int
    public let buildingID: Int
    public let assignedWorkers: Int

    public init(vectorIndex: Int, buildingID: Int, assignedWorkers: Int) {
        self.vectorIndex = vectorIndex
        self.buildingID = buildingID
        self.assignedWorkers = assignedWorkers
    }
}

/// Source-backed City Gate/Tower staffing boundary.
///
/// `FUN_004AD850` admits only models `0x82` (City Gate, ID 130) and `0x83`
/// (Tower, ID 131), and `FUN_00408B40` caps each row by model-table field 5.
/// The shipping `EmperorBuildingModels.txt` rows give those caps as 9 and 6.
/// The source consumes a shared remaining-worker word in vector order; this
/// helper mirrors that allocation only after callers provide the two already
/// resolved source gates and per-object callback flags.  It does not project
/// Native workforce totals or claim that a Native defense object is the same
/// source registry row.
public enum OriginalMilitaryDefenseStaffingCatalog {
    public static let workerCapByBuildingID: [Int: Int] = [
        130: 9, // City Gate, EmperorBuildingModels field 5
        131: 6  // Tower, EmperorBuildingModels field 5
    ]

    public static func workerCap(forBuildingID buildingID: Int) -> Int? {
        workerCapByBuildingID[buildingID]
    }

    public static func plan(
        globalGateOpen: Bool,
        laborAllocatorGateOpen: Bool,
        sourceLaborAvailable: Int,
        candidates: [OriginalMilitaryDefenseStaffingCandidate]
    ) -> [OriginalMilitaryDefenseStaffingAssignment] {
        guard globalGateOpen, laborAllocatorGateOpen else { return [] }
        var remaining = max(0, sourceLaborAvailable)
        var assignments: [OriginalMilitaryDefenseStaffingAssignment] = []
        for candidate in candidates where remaining > 0 {
            guard candidate.vectorIndex > 0,
                  !candidate.noLaborFlag,
                  candidate.callbackEligible,
                  let cap = workerCap(forBuildingID: candidate.buildingID)
            else { continue }
            let assigned = min(remaining, cap)
            guard assigned > 0 else { continue }
            assignments.append(.init(
                vectorIndex: candidate.vectorIndex,
                buildingID: candidate.buildingID,
                assignedWorkers: assigned
            ))
            remaining -= assigned
        }
        return assignments
    }
}

/// Raw table inputs used by `FUN_004AD850 @ 0x4AD850` when it computes the
/// shared labor word before assigning City Gate/Tower rows.  The second table
/// is intentionally named by its source index rather than a guessed gameplay
/// meaning: its index comes from `FUN_00592BD0`, whose receiver/domain is not
/// recovered.  This catalog is an explicit-input research boundary and is
/// not a Native workforce projection.
public enum OriginalMilitaryDefenseLaborPoolCatalog {
    /// `DAT_00847410`, indexed by `DAT_010DE2E0`.
    public static let basePercentageByDifficultyIndex = [50, 45, 40, 37, 35]
    /// `DAT_00847424`, indexed by the result of `FUN_00592BD0`.
    public static let rawAdjustmentBySourceIndex = [-10, -6, -3, 0, 3, 5, -2]
    /// `DAT_0084743C`, indexed by the five-way `DAT_0130F97C` band.
    public static let popularityBandAdjustment = [-2, -1, 0, 1, 2]

    /// Returns the exact percentage passed to `FUN_00408B80(n3, percentage)`.
    /// All three indices remain explicit because only their table lookups,
    /// not the Native semantic sources, are recovered.
    public static func percentage(
        difficultyIndex: Int,
        sourceAdjustmentIndex: Int,
        popularityBandIndex: Int
    ) -> Int? {
        guard basePercentageByDifficultyIndex.indices.contains(difficultyIndex),
              rawAdjustmentBySourceIndex.indices.contains(sourceAdjustmentIndex),
              popularityBandAdjustment.indices.contains(popularityBandIndex)
        else { return nil }
        return basePercentageByDifficultyIndex[difficultyIndex]
            + rawAdjustmentBySourceIndex[sourceAdjustmentIndex]
            + popularityBandAdjustment[popularityBandIndex]
    }

    /// Mirrors the source's integer percentage helper for a supplied positive
    /// object-worker sum.  The source's `n3` is still a PE object-vector value;
    /// callers must not substitute Native population/workforce totals without
    /// a separately recovered projection.
    public static func availableLabor(
        positiveObjectWorkerTotal: Int,
        difficultyIndex: Int,
        sourceAdjustmentIndex: Int,
        popularityBandIndex: Int
    ) -> Int? {
        guard positiveObjectWorkerTotal >= 0,
              let percentage = percentage(
                  difficultyIndex: difficultyIndex,
                  sourceAdjustmentIndex: sourceAdjustmentIndex,
                  popularityBandIndex: popularityBandIndex
              )
        else { return nil }
        return (positiveObjectWorkerTotal * percentage) / 100
    }
}

public enum MilitaryDefenseKind: String, Sendable, Hashable, Codable {
    case cityWall
    case cityGate
    case tower
}

/// Figure models accepted by the executable's `DAT_01312564` war-count gate.
///
/// This is deliberately a model-family catalog, not a live counter. The
/// original increments once per individual figure at creation and decrements
/// that same figure at death; Native currently stores one aggregate enemy
/// force per invasion and therefore cannot use this catalog to derive a
/// truthful `warCount` without a recovered per-figure ledger.
public enum OriginalWarFigureCatalog {
    public static let contributingModelIDs: Set<Int> = Set(58...62).union([78])

    public static func contributesToWarCount(modelID: Int) -> Bool {
        contributingModelIDs.contains(modelID)
    }
}

/// Explicit-input ledger for the executable's `DAT_01312564` lifecycle.
///
/// `FUN_004EBB40 @ 0x4EBB40` adjusts the counter once per individual figure,
/// after the `FUN_004E2560` model gate. Creation passes `flag=1`, death passes
/// `flag=0`, and the stored value is clamped at zero. This ledger mirrors that
/// arithmetic without claiming that Native's aggregate invasion model can
/// supply the required figure-level event stream.
public struct OriginalWarFigureLedger: Sendable, Hashable, Codable {
    public private(set) var count: Int

    public init(count: Int = 0) {
        self.count = max(0, count)
    }

    /// Mirrors `FUN_004EBBD0 @ 0x4EBBD0`, which resets the war counter to zero.
    public mutating func reset() {
        count = 0
    }

    /// Applies one creation/death event. Unsupported model IDs are ignored by
    /// the source gate. Death events preserve the executable's lower bound of
    /// zero even when the caller presents an unmatched or repeated event.
    @discardableResult
    public mutating func apply(modelID: Int, created: Bool) -> Int {
        guard OriginalWarFigureCatalog.contributesToWarCount(modelID: modelID) else {
            return count
        }
        count = max(0, count + (created ? 1 : -1))
        return count
    }
}

/// Raw gate for the optional Enemy's Heroes branch in `FUN_00522D30`.
///
/// The executable reads the selected city record's signed short at `+0x38`
/// and enters the model-78 branch only when `0 <= value < 12`. This helper
/// deliberately reports branch eligibility only: the subsequent
/// `FUN_00510C70` route/placement request can still reject the hero, and the
/// field's authored semantic name and Native city-record projection remain
/// unknown.
public enum OriginalInvasionHeroEligibility {
    public static func rawCityFieldIsEligible(_ value: Int) -> Bool {
        (0..<12).contains(value)
    }
}

/// Per-model weights used by the invasion event's local threat aggregate.
/// These are separate from `OriginalWarFigureCatalog`: the executable's
/// `FUN_0054D850` switch omits model 58 and applies floating-point weights to
/// active record quantities before truncating the result. The runtime quantity
/// writer is recovered in `FUN_00522D30`; the source registry/archive
/// projection is still not mapped to Native, so this catalog remains a pure,
/// explicit-input helper.
public enum OriginalInvasionThreatWeightCatalog {
    public static let weightsByModelID: [Int: Double] = [
        59: 1.25,
        60: 2.5,
        61: 4.0,
        62: 5.0,
        78: 10.0
    ]

    public static func weight(modelID: Int) -> Double? {
        weightsByModelID[modelID]
    }

    /// Returns the executable's positive-quantity contribution after its
    /// `__ftol` conversion. Zero quantities and unrecognized model keys are
    /// skipped by the source loop and therefore return `nil`.
    public static func contribution(modelID: Int, quantity: UInt8) -> Int? {
        guard quantity > 0, let weight = weight(modelID: modelID) else {
            return nil
        }
        return Int(Double(quantity) * weight)
    }
}

/// The fields consumed by `FUN_0054D850` after its cursor is biased to
/// `record + 0x28`. This is an explicit-input projection of the executable's
/// raw record predicates; it does not claim that Native can reconstruct the
/// source registry from a campaign archive.
public struct OriginalInvasionThreatRecord: Sendable, Hashable, Codable {
    public let active: Bool
    public let modelID: Int
    public let quantity: UInt8
    public let citySelector: Int

    public init(
        active: Bool,
        modelID: Int,
        quantity: UInt8,
        citySelector: Int
    ) {
        self.active = active
        self.modelID = modelID
        self.quantity = quantity
        self.citySelector = citySelector
    }
}

/// Unified enemy-record layout and the recovered runtime quantity writer.
/// `FUN_0054D580` resets the 100 records rooted at `DAT_011A2B08` with
/// `FUN_005512D0`; `FUN_0054C4F0` allocates the enemy slice beginning at slot
/// `0x23`, which aliases `DAT_011A43A4`. Its quantity byte is therefore
/// `DAT_011A2B30 + slot*0xB4`, aliasing `DAT_011A43CC` for the first enemy
/// slot. `FUN_00522D30` clears that byte after allocation and increments it
/// only after each successful figure creation, while storing the figure ID in
/// the corresponding 16-entry link array and writing figure `+0x6A = slot`.
/// The archive/load population and a Native object-registry projection remain
/// outside this closed runtime writer boundary.
public enum OriginalInvasionThreatRecordLifecycle {
    public static let unifiedTableBaseAddress = 0x011A2B08
    public static let unifiedTableRecordCount = 100
    public static let recordStride = 0xB4
    public static let enemyFirstSlot = 0x23
    public static let enemySlotCount = 64
    public static let enemyTableBaseAddress = 0x011A43A4
    public static let quantityOffset = 0x28
    public static let enemyQuantityAddress = 0x011A43CC
    public static let figureLinkBaseOffset = 0x08
    public static let figureLinkCapacity = 16

    /// The two bytes tested before `FUN_0054C4F0` initializes a slot.  The
    /// executable scans from slot `0x23` upward and accepts a row only when
    /// both the active byte (`record + 0x00`) and the lifecycle byte
    /// (`record + 0x69`) are zero.  This is a raw allocator predicate; it
    /// does not assign a Native invasion or claim that an aggregate force has
    /// one source record per group.
    public struct SlotState: Sendable, Hashable, Codable {
        public let active: Bool
        public let lifecycleByte: UInt8

        public init(active: Bool, lifecycleByte: UInt8 = 0) {
            self.active = active
            self.lifecycleByte = lifecycleByte
        }
    }

    /// Returns the first source slot admitted by the allocator's linear scan.
    /// Missing state is rejected rather than padded with an invented empty
    /// row, preserving the source table's finite 64-slot boundary.
    public static func firstAllocatableSlot(_ states: [SlotState]) -> Int? {
        guard states.count == enemySlotCount else { return nil }
        for (offset, state) in states.enumerated()
            where !state.active && state.lifecycleByte == 0 {
            return enemyFirstSlot + offset
        }
        return nil
    }

    public static func quantityAddress(forSlot slot: Int) -> Int? {
        guard (enemyFirstSlot..<(enemyFirstSlot + enemySlotCount)).contains(slot) else {
            return nil
        }
        return unifiedTableBaseAddress + slot * recordStride + quantityOffset
    }

    /// Mirrors the successful-spawn increments in `FUN_00522D30`. For this
    /// spawn-count projection the source has a finite 16-entry link array;
    /// values above that capacity are rejected rather than wrapped. This does
    /// not classify archive-provided bytes, which remain outside the recovered
    /// writer boundary.
    public static func quantityAfterSuccessfulFigureSpawns(_ count: Int) -> UInt8? {
        guard (0...figureLinkCapacity).contains(count) else { return nil }
        return UInt8(count)
    }
}

/// Save/load boundary recovered for the source threat-record table.
///
/// `FUN_0052FDA0` is the map/save serializer and iterates the same 100-row
/// table for both load (`FUN_00780642`) and save (`FUN_00780533`) modes. Each
/// row is delegated to `FUN_005501B0`; this metadata records the byte layout
/// observed in that per-record routine without pretending that the Native
/// aggregate can yet be rehydrated into the source registry.
public enum OriginalInvasionThreatRecordSerialization {
    public struct Field: Sendable, Hashable, Codable {
        public let offset: Int
        public let width: Int

        public init(offset: Int, width: Int) {
            self.offset = offset
            self.width = width
        }
    }

    public static let serializerAddress = 0x005501B0
    public static let mapSaveSerializerAddress = 0x0052FDA0
    public static let directSaveEntryAddress = 0x004FD2A0
    public static let unifiedTableBaseAddress = 0x011A2B08
    public static let recordCount = 100
    public static let recordStride = 0xB4

    /// Canonical (version >= 6) field reads/writes in `FUN_005501B0`.
    /// Duplicate offset `0xA4` is retained because the source invokes the
    /// serializer twice for that dword.
    public static let canonicalFields: [Field] = [
        Field(offset: 0x00, width: 1), Field(offset: 0x01, width: 1),
        Field(offset: 0x02, width: 1), Field(offset: 0x03, width: 1),
        Field(offset: 0x04, width: 2), Field(offset: 0x06, width: 2),
        Field(offset: 0x08, width: 0x20), Field(offset: 0x28, width: 1),
        Field(offset: 0x29, width: 1), Field(offset: 0x2A, width: 2),
        Field(offset: 0x2C, width: 2), Field(offset: 0x2E, width: 2),
        Field(offset: 0x30, width: 2), Field(offset: 0x32, width: 2),
        Field(offset: 0x34, width: 2), Field(offset: 0x36, width: 2),
        Field(offset: 0x38, width: 2), Field(offset: 0x3A, width: 2),
        Field(offset: 0x3C, width: 2), Field(offset: 0x3E, width: 2),
        Field(offset: 0x40, width: 2), Field(offset: 0x42, width: 1),
        Field(offset: 0x43, width: 1), Field(offset: 0x44, width: 2),
        Field(offset: 0x46, width: 2), Field(offset: 0x48, width: 2),
        Field(offset: 0x4A, width: 2), Field(offset: 0x4C, width: 2),
        Field(offset: 0x4E, width: 2), Field(offset: 0x50, width: 2),
        Field(offset: 0x52, width: 2), Field(offset: 0x54, width: 2),
        Field(offset: 0x56, width: 2), Field(offset: 0x58, width: 2),
        Field(offset: 0x5A, width: 2), Field(offset: 0x5C, width: 2),
        Field(offset: 0x5E, width: 2), Field(offset: 0x60, width: 2),
        Field(offset: 0x62, width: 2), Field(offset: 0x64, width: 2),
        Field(offset: 0x66, width: 1), Field(offset: 0x67, width: 1),
        Field(offset: 0x68, width: 1), Field(offset: 0x69, width: 1),
        Field(offset: 0x6A, width: 1), Field(offset: 0x6B, width: 1),
        Field(offset: 0x6C, width: 2), Field(offset: 0x6E, width: 2),
        Field(offset: 0x70, width: 1), Field(offset: 0x71, width: 1),
        Field(offset: 0x72, width: 1), Field(offset: 0x73, width: 1),
        Field(offset: 0x74, width: 1), Field(offset: 0x75, width: 1),
        Field(offset: 0x76, width: 1), Field(offset: 0x77, width: 1),
        Field(offset: 0x78, width: 2), Field(offset: 0x7A, width: 2),
        Field(offset: 0x7C, width: 2), Field(offset: 0x7E, width: 2),
        Field(offset: 0x80, width: 2), Field(offset: 0x82, width: 2),
        Field(offset: 0x84, width: 4), Field(offset: 0x88, width: 2),
        Field(offset: 0x8C, width: 4), Field(offset: 0x90, width: 1),
        Field(offset: 0x91, width: 1), Field(offset: 0x92, width: 1),
        Field(offset: 0x93, width: 1), Field(offset: 0x94, width: 1),
        Field(offset: 0x95, width: 1), Field(offset: 0x98, width: 4),
        Field(offset: 0x9C, width: 1), Field(offset: 0xA4, width: 4),
        Field(offset: 0xA4, width: 4), Field(offset: 0xAC, width: 4),
        Field(offset: 0xB0, width: 4), Field(offset: 0x9E, width: 2),
        Field(offset: 0xA0, width: 2)
    ]
}

public enum OriginalInvasionThreatAggregate {
    /// Mirrors `FUN_0054D850(citySelector)`: active records for the selected
    /// city contribute their positive quantity through the recovered model
    /// weight table; records with unknown models are ignored by the source
    /// switch.
    public static func value(
        citySelector: Int,
        records: some Sequence<OriginalInvasionThreatRecord>
    ) -> Int {
        records.reduce(into: 0) { total, record in
            guard record.active, record.citySelector == citySelector,
                  let contribution = OriginalInvasionThreatWeightCatalog
                    .contribution(modelID: record.modelID, quantity: record.quantity)
            else { return }
            total += contribution
        }
    }
}

/// One source invasion formation record produced for a single enemy model.
///
/// `FUN_00522D30` creates one threat/formation record for every group emitted
/// by the count splitter, rather than one record for the whole invasion.  The
/// figure ledger and Native object projection are still separate unknowns;
/// this value only preserves the recovered source-side grouping contract.
public struct OriginalInvasionFormationGroup: Sendable, Hashable, Codable {
    public let modelID: Int
    public let groupIndex: Int
    public let quantity: Int

    public init(modelID: Int, groupIndex: Int, quantity: Int) {
        self.modelID = modelID
        self.groupIndex = groupIndex
        self.quantity = quantity
    }
}

/// The five formation counts produced by the executable's invasion builder.
///
/// `FUN_00522B30` clamps the requested amount to 0x100 and the underlying
/// `FUN_00522C50` selects five consecutive records from the authored
/// `ALL ENEMIES` table, using one of the five period-percentage columns. The
/// returned model IDs are the normal-branch figure models selected by
/// `FUN_00522D30`; the enemy-set index remains an explicit input because this
/// helper does not claim to be the still-unrecovered live city-record bridge.
public struct OriginalInvasionFormationPlan: Sendable, Hashable, Codable {
    public let periodIndex: Int
    public let modelIDs: [Int]
    public let counts: [Int]

    /// The records the source builder would allocate, in model/category order.
    /// Zero-count categories emit no record.
    public var groups: [OriginalInvasionFormationGroup] {
        zip(modelIDs, counts).flatMap { modelID, count in
            OriginalInvasionFormationCatalog.groups(
                forCount: count
            ).enumerated().map { groupIndex, quantity in
                OriginalInvasionFormationGroup(
                    modelID: modelID,
                    groupIndex: groupIndex,
                    quantity: quantity
                )
            }
        }
    }

    /// Number of normal-branch figures created by the source builder. This
    /// sums the five authored category counts; it intentionally excludes the
    /// separate model-78 hero branch.
    public var sourceFigureCount: Int {
        counts.reduce(0, +)
    }
}

public enum OriginalInvasionFormationCatalog {
    public static let normalFormationModelIDs = [58, 59, 60, 61, 62]

    /// Splits one source count into the formation quantities used by
    /// `FUN_00522D30 @ 0x522D30`.
    ///
    /// The executable caps each category at `0x200`, emits complete groups of
    /// 16, and when a remainder exists after at least one full group it
    /// replaces the final 16-group with two near-half groups whose sum is the
    /// original remainder plus 16.  This slightly unusual split is observable
    /// in the recovered stack-array writes and is intentionally kept separate
    /// from Native's one-force aggregate.
    public static func groups(forCount count: Int) -> [Int] {
        guard count > 0 else { return [] }
        let capped = min(0x200, count)
        let fullGroupCount = capped / 16
        let remainder = capped - fullGroupCount * 16
        guard remainder != 0 else {
            return Array(repeating: 16, count: fullGroupCount)
        }
        guard fullGroupCount > 0 else { return [remainder] }

        var groups = Array(repeating: 16, count: fullGroupCount - 1)
        let splitTotal = remainder + 16
        groups.append((splitTotal + 1) / 2)
        groups.append(splitTotal / 2)
        return groups
    }

    /// `FUN_0054B6D0` compares the signed current year against the constructor
    /// literals recovered at `FUN_0054B650`: -1200, -500, -350, -200.
    public static func periodIndex(forYear year: Int) -> Int {
        if year >= -200 { return 4 }
        if year >= -350 { return 3 }
        if year >= -500 { return 2 }
        if year >= -1_200 { return 1 }
        return 0
    }

    /// Reproduces the source-side five-value extraction with explicit inputs.
    /// `enemySetIndex` selects one six-row `ALL ENEMIES` block; the sixth row
    /// is the authored blank separator and is not emitted as a formation.
    public static func plan(
        enemySetIndex: Int,
        periodIndex: Int,
        amount: Int,
        enemies: [FigureModel]
    ) -> OriginalInvasionFormationPlan? {
        guard (0...6).contains(enemySetIndex),
              (0...4).contains(periodIndex),
              amount >= 0,
              enemies.count >= (enemySetIndex + 1) * 6 else {
            return nil
        }
        let clampedAmount = min(0x100, amount)
        let rowStart = enemySetIndex * 6
        let counts = (0..<5).map { offset in
            clampedAmount * enemies[rowStart + offset].periodPercentages[periodIndex] / 100
        }
        return OriginalInvasionFormationPlan(
            periodIndex: periodIndex,
            modelIDs: normalFormationModelIDs,
            counts: counts
        )
    }

    public static func plan(
        enemySetIndex: Int,
        year: Int,
        amount: Int,
        enemies: [FigureModel]
    ) -> OriginalInvasionFormationPlan? {
        plan(
            enemySetIndex: enemySetIndex,
            periodIndex: periodIndex(forYear: year),
            amount: amount,
            enemies: enemies
        )
    }
}

/// Defensive structures use the original building identifiers and durability
/// values. Gates and towers replace an existing wall tile, matching the
/// original construction flow instead of behaving like ordinary buildings.
public struct OriginalMilitaryDefenseConfiguration: Sendable, Hashable, Codable {
    public let buildingID: Int
    public let kind: MilitaryDefenseKind
    public let maximumIntegrity: Int
    public let sentryFigureIDs: [Int]

    public static func configuration(buildingID: Int) -> Self? {
        switch buildingID {
        case 129:
            Self(buildingID: 129, kind: .cityWall, maximumIntegrity: 500, sentryFigureIDs: [])
        case 130:
            Self(buildingID: 130, kind: .cityGate, maximumIntegrity: 1_500, sentryFigureIDs: [])
        case 131:
            // A staffed tower creates both of the original sentry figures: a
            // wall patrol and a standing bow guard.
            Self(buildingID: 131, kind: .tower, maximumIntegrity: 1_200, sentryFigureIDs: [56, 57])
        default:
            nil
        }
    }
}

public struct MilitaryDefenseStructure: Identifiable, Sendable, Hashable, Codable {
    public let id: Int
    public let buildingID: Int
    public let kind: MilitaryDefenseKind
    public let point: GridPoint
    public let maximumIntegrity: Int
    public private(set) var integrity: Int

    public var isOperational: Bool { integrity > 0 }

    mutating func applyDamage(_ amount: Int) {
        integrity = max(0, integrity - max(0, amount))
    }

    mutating func restore() {
        integrity = maximumIntegrity
    }
}

public struct MilitarySentry: Identifiable, Sendable, Hashable, Codable {
    public let id: Int
    public let defenseID: Int
    public let figureID: Int
    public let point: GridPoint
}

public struct MilitaryFort: Identifiable, Sendable, Hashable, Codable {
    public let id: Int
    public let buildingID: Int
    public let figureID: Int
    public let roadAccessPoint: GridPoint
    public let unitID: Int
}

public enum MilitaryUnitStatus: String, Sendable, Hashable, Codable {
    case garrisoned
    case marching
    case victorious
    case destroyed
}

public struct MilitaryUnit: Identifiable, Sendable, Hashable, Codable {
    public let id: Int
    public let fortID: Int
    public let figureID: Int
    public let originalSoldierCount: Int
    public private(set) var hitPoints: Int
    public private(set) var morale: Int
    public private(set) var currentPoint: GridPoint
    public private(set) var route: [GridPoint]
    public private(set) var routeIndex: Int
    public private(set) var assignedInvasionID: String?
    public private(set) var status: MilitaryUnitStatus
    public private(set) var rallyPoint: GridPoint?

    public func survivingSoldiers(model: FigureModel?) -> Int {
        guard hitPoints > 0 else { return 0 }
        return min(originalSoldierCount, (hitPoints + max(1, model?.hitPoints ?? 1) - 1)
            / max(1, model?.hitPoints ?? 1))
    }

    mutating func assign(invasionID: String, route: [GridPoint]) {
        guard hitPoints > 0, !route.isEmpty else { return }
        assignedInvasionID = invasionID
        self.route = route
        routeIndex = 0
        currentPoint = route[0]
        rallyPoint = route.last
        status = .marching
    }

    mutating func assignPlayerOrder(route: [GridPoint]) {
        guard hitPoints > 0, !route.isEmpty else { return }
        assignedInvasionID = nil
        self.route = route
        routeIndex = 0
        currentPoint = route[0]
        rallyPoint = route.last
        status = .marching
    }

    mutating func advance(steps: Int) -> Bool {
        guard status == .marching, !route.isEmpty else { return false }
        routeIndex = min(route.count - 1, routeIndex + max(0, steps))
        currentPoint = route[routeIndex]
        return routeIndex == route.count - 1
    }

    mutating func applyCombat(hitPoints remainingHitPoints: Int, morale: Int, won: Bool) {
        hitPoints = max(0, remainingHitPoints)
        self.morale = min(100, max(0, morale))
        route = []
        routeIndex = 0
        assignedInvasionID = nil
        rallyPoint = nil
        status = hitPoints == 0 ? .destroyed : (won ? .victorious : .garrisoned)
    }

    mutating func completePlayerOrder() {
        route = []
        routeIndex = 0
        rallyPoint = nil
        status = hitPoints == 0 ? .destroyed : .garrisoned
    }
}

public struct MilitaryCombatReport: Identifiable, Sendable, Hashable, Codable {
    public let id: String
    public let invasionID: String
    public let unitID: Int
    public let friendlyFigureID: Int
    public let friendlySoldiersBefore: Int
    public let friendlySoldiersLost: Int
    public let enemyTypeID: Int
    public let enemySoldiersBefore: Int
    public let enemySoldiersLost: Int
    public let rounds: Int
    public let outcome: CampaignInvasionStatus
    /// Added in native format 0.31. `nil` preserves decoding of 0.30 saves.
    public let participatingUnitIDs: [Int]?
    /// Added in native format 0.75. Optional compatibility field; the source
    /// catapult/structure-attack projection is not recovered, so live reports
    /// must not derive this from invasion amount.
    public let enemySiegeEngineCount: Int?
}

public struct MilitaryMovementSettlement: Sendable, Hashable, Codable {
    public let movedSteps: Int
    public let reports: [MilitaryCombatReport]
    /// Added in native format 0.75. Optional for decoding earlier saves.
    public let enemyMovedSteps: Int?

    public static let empty = Self(movedSteps: 0, reports: [], enemyMovedSteps: nil)
}

public enum EnemyForceStatus: String, Sendable, Hashable, Codable {
    case maneuvering
    case engaged
    case repelled
    case breached
}

/// A visible, saveable enemy force created from an authored campaign
/// invasion. It advances from the original map entry point toward the nearest
/// operational defense (or the city centre when no defense remains).
public struct EnemyMilitaryForce: Identifiable, Sendable, Hashable, Codable {
    public let id: String
    public let invasionID: String
    public let enemyTypeID: Int
    public let soldierCount: Int
    public let siegeEngineCount: Int
    public private(set) var currentPoint: GridPoint
    public private(set) var targetPoint: GridPoint
    public private(set) var route: [GridPoint]
    public private(set) var routeIndex: Int
    public private(set) var status: EnemyForceStatus

    mutating func retarget(_ target: GridPoint, route: [GridPoint]) {
        guard status == .maneuvering || status == .engaged else { return }
        targetPoint = target
        self.route = route
        routeIndex = 0
        if let first = route.first { currentPoint = first }
        status = .maneuvering
    }

    mutating func advance(steps: Int) -> Bool {
        guard status == .maneuvering, !route.isEmpty else {
            return currentPoint == targetPoint
        }
        routeIndex = min(route.count - 1, routeIndex + max(0, steps))
        currentPoint = route[routeIndex]
        let arrived = routeIndex == route.count - 1
        if arrived { status = .engaged }
        return arrived
    }

    mutating func resolve(_ outcome: CampaignInvasionStatus) {
        route = []
        routeIndex = 0
        status = outcome == .repelled ? .repelled : .breached
    }
}

public struct DeterministicMilitaryState: Sendable, Hashable, Codable {
    public private(set) var forts: [MilitaryFort]
    public private(set) var units: [MilitaryUnit]
    public private(set) var combatReports: [MilitaryCombatReport]
    public private(set) var lastMovement: MilitaryMovementSettlement?
    // Optional backing fields keep military data written by 0.30 decodable.
    private var defensiveStructuresState: [MilitaryDefenseStructure]?
    private var sentriesState: [MilitarySentry]?
    /// Optional backing keeps pre-0.75 native saves decodable.
    private var enemyForcesState: [EnemyMilitaryForce]?

    public var defensiveStructures: [MilitaryDefenseStructure] {
        defensiveStructuresState ?? []
    }

    public var sentries: [MilitarySentry] { sentriesState ?? [] }
    public var enemyForces: [EnemyMilitaryForce] { enemyForcesState ?? [] }

    public init() {
        forts = []
        units = []
        combatReports = []
        lastMovement = nil
        defensiveStructuresState = []
        sentriesState = []
        enemyForcesState = []
    }

    @discardableResult
    mutating func addFort(
        configuration: OriginalMilitaryFortConfiguration,
        roadAccessPoint: GridPoint,
        models: FigureModelTable
    ) -> Int? {
        guard let figure = models[figureID: configuration.figureID], figure.hitPoints > 0 else {
            return nil
        }
        let fortID = (forts.map(\.id).max() ?? 0) + 1
        let unitID = (units.map(\.id).max() ?? 0) + 1
        forts.append(MilitaryFort(
            id: fortID,
            buildingID: configuration.buildingID,
            figureID: configuration.figureID,
            roadAccessPoint: roadAccessPoint,
            unitID: unitID
        ))
        units.append(MilitaryUnit(
            id: unitID,
            fortID: fortID,
            figureID: configuration.figureID,
            originalSoldierCount: configuration.soldierCount,
            hitPoints: configuration.soldierCount * figure.hitPoints,
            morale: 100,
            currentPoint: roadAccessPoint,
            route: [],
            routeIndex: 0,
            assignedInvasionID: nil,
            status: .garrisoned,
            rallyPoint: nil
        ))
        return fortID
    }

    @discardableResult
    mutating func removeFort(id: Int) -> Bool {
        guard let index = forts.firstIndex(where: { $0.id == id }) else { return false }
        let fort = forts.remove(at: index)
        units.removeAll { $0.id == fort.unitID }
        return true
    }

    @discardableResult
    mutating func addDefense(
        configuration: OriginalMilitaryDefenseConfiguration,
        point: GridPoint,
        models: FigureModelTable
    ) -> Int? {
        guard configuration.sentryFigureIDs.allSatisfy({ models[figureID: $0] != nil }) else {
            return nil
        }
        var defenses = defensiveStructuresState ?? []
        // Keep placement references disjoint from fort IDs while both share
        // the existing `.military` placement category.
        let defenseID = max(1_000_000, (defenses.map(\.id).max() ?? 999_999) + 1)
        defenses.append(MilitaryDefenseStructure(
            id: defenseID,
            buildingID: configuration.buildingID,
            kind: configuration.kind,
            point: point,
            maximumIntegrity: configuration.maximumIntegrity,
            integrity: configuration.maximumIntegrity
        ))
        defensiveStructuresState = defenses
        appendSentries(
            defenseID: defenseID,
            point: point,
            figureIDs: configuration.sentryFigureIDs
        )
        return defenseID
    }

    @discardableResult
    mutating func replaceDefense(
        id: Int,
        configuration: OriginalMilitaryDefenseConfiguration,
        models: FigureModelTable
    ) -> Bool {
        guard configuration.sentryFigureIDs.allSatisfy({ models[figureID: $0] != nil }) else {
            return false
        }
        var defenses = defensiveStructuresState ?? []
        guard let index = defenses.firstIndex(where: { $0.id == id }) else { return false }
        let point = defenses[index].point
        defenses[index] = MilitaryDefenseStructure(
            id: id,
            buildingID: configuration.buildingID,
            kind: configuration.kind,
            point: point,
            maximumIntegrity: configuration.maximumIntegrity,
            integrity: configuration.maximumIntegrity
        )
        defensiveStructuresState = defenses
        var sentries = sentriesState ?? []
        sentries.removeAll { $0.defenseID == id }
        sentriesState = sentries
        appendSentries(
            defenseID: id,
            point: point,
            figureIDs: configuration.sentryFigureIDs
        )
        return true
    }

    @discardableResult
    mutating func removeDefense(id: Int) -> Bool {
        var defenses = defensiveStructuresState ?? []
        guard let index = defenses.firstIndex(where: { $0.id == id }) else { return false }
        defenses.remove(at: index)
        defensiveStructuresState = defenses
        var sentries = sentriesState ?? []
        sentries.removeAll { $0.defenseID == id }
        sentriesState = sentries
        return true
    }

    @discardableResult
    mutating func issueOrder(unitIDs: Set<Int>, routesByUnitID: [Int: [GridPoint]]) -> Int {
        var ordered = 0
        for index in units.indices where unitIDs.contains(units[index].id) {
            guard let route = routesByUnitID[units[index].id], !route.isEmpty,
                  units[index].hitPoints > 0 else { continue }
            units[index].assignPlayerOrder(route: route)
            ordered += 1
        }
        return ordered
    }

    private mutating func appendSentries(
        defenseID: Int,
        point: GridPoint,
        figureIDs: [Int]
    ) {
        var sentries = sentriesState ?? []
        var nextID = (sentries.map(\.id).max() ?? 0) + 1
        for figureID in figureIDs {
            sentries.append(MilitarySentry(
                id: nextID,
                defenseID: defenseID,
                figureID: figureID,
                point: point
            ))
            nextID += 1
        }
        sentriesState = sentries
    }

    public mutating func advance(
        maximumStepsPerUnit: Int? = nil,
        terrain: DeterministicTerrainState?,
        blockedPoints: Set<GridPoint>,
        campaignEvents: inout CampaignCityEventState,
        models: FigureModelTable
    ) -> MilitaryMovementSettlement {
        var movedSteps = 0
        var enemyMovedSteps = 0
        var newReports: [MilitaryCombatReport] = []

        // Player rally orders are advanced before campaign alerts claim idle
        // formations. Units already marching under an explicit order remain
        // unavailable until they reach their destination.
        for index in units.indices where
            units[index].assignedInvasionID == nil && !units[index].route.isEmpty {
            let speed = models[figureID: units[index].figureID]?.speed ?? 1
            let beforeIndex = units[index].routeIndex
            let arrived = units[index].advance(steps: maximumStepsPerUnit ?? max(1, speed))
            movedSteps += max(0, units[index].routeIndex - beforeIndex)
            if arrived { units[index].completePlayerOrder() }
        }

        let pending = campaignEvents.invasions
            .filter { $0.status == .awaitingDefense }
            .sorted { $0.id < $1.id }

        synchronizeEnemyForces(
            with: pending,
            terrain: terrain,
            blockedPoints: blockedPoints,
            models: models
        )

        for alert in pending {
            guard let forceIndex = enemyForcesState?.firstIndex(where: {
                $0.invasionID == alert.id
            }) else { continue }
            let target = enemyTarget(for: alert, terrain: terrain)
            retargetEnemyForce(
                at: forceIndex,
                target: target,
                terrain: terrain,
                blockedPoints: blockedPoints
            )
            let enemySpeed = min(4, max(1, models[enemyTypeID: Self.enemyTypeID(for: alert)]?.speed ?? 1))
            let enemyBeforeIndex = enemyForcesState?[forceIndex].routeIndex ?? 0
            let enemyArrived = enemyForcesState?[forceIndex].advance(
                steps: maximumStepsPerUnit ?? enemySpeed
            ) ?? false
            enemyMovedSteps += max(
                0,
                (enemyForcesState?[forceIndex].routeIndex ?? enemyBeforeIndex) - enemyBeforeIndex
            )
            guard let enemyPoint = enemyForcesState?[forceIndex].currentPoint else { continue }

            var participating = units.indices.filter {
                units[$0].hitPoints > 0 && units[$0].assignedInvasionID == alert.id
            }
            if participating.isEmpty {
                let available = units.indices
                    .filter {
                        units[$0].hitPoints > 0
                            && units[$0].assignedInvasionID == nil
                            && units[$0].route.isEmpty
                    }
                    .sorted { lhs, rhs in
                        let target = alert.entryPoint ?? units[lhs].currentPoint
                        let left = Self.distance(units[lhs].currentPoint, target)
                        let right = Self.distance(units[rhs].currentPoint, target)
                        return left == right ? units[lhs].id < units[rhs].id : left < right
                    }
                for unitIndex in available {
                    let destination = enemyPoint
                    var routeBlocked = blockedPoints
                    routeBlocked.remove(destination)
                    let route = terrain?.shortestLandVisitorPath(
                        from: units[unitIndex].currentPoint,
                        to: destination,
                        blocked: routeBlocked
                    ) ?? GridPathfinder.shortestPath(
                        width: terrain?.width
                            ?? max(destination.x + 1, units[unitIndex].currentPoint.x + 1),
                        height: terrain?.height
                            ?? max(destination.y + 1, units[unitIndex].currentPoint.y + 1),
                        from: units[unitIndex].currentPoint,
                        to: destination,
                        isPassable: { !routeBlocked.contains($0) }
                    )
                    if let route {
                        units[unitIndex].assign(invasionID: alert.id, route: route)
                        participating.append(unitIndex)
                    }
                }
            }

            // Enemy and friendly formations move simultaneously. Recompute a
            // short intercept route each tick so formations pursue a moving
            // force instead of walking to a stale invasion entry point.
            for unitIndex in participating where units[unitIndex].currentPoint != enemyPoint {
                var routeBlocked = blockedPoints
                routeBlocked.remove(enemyPoint)
                routeBlocked.remove(units[unitIndex].currentPoint)
                if let route = terrain?.shortestLandVisitorPath(
                    from: units[unitIndex].currentPoint,
                    to: enemyPoint,
                    blocked: routeBlocked
                ) ?? GridPathfinder.shortestPath(
                    width: terrain?.width ?? max(enemyPoint.x + 1, 1),
                    height: terrain?.height ?? max(enemyPoint.y + 1, 1),
                    from: units[unitIndex].currentPoint,
                    to: enemyPoint,
                    isPassable: { !routeBlocked.contains($0) }
                ) {
                    units[unitIndex].assign(invasionID: alert.id, route: route)
                }
            }

            var allArrived = !participating.isEmpty
            for unitIndex in participating {
                let speed = models[figureID: units[unitIndex].figureID]?.speed ?? 1
                let beforeIndex = units[unitIndex].routeIndex
                let arrived = units[unitIndex].advance(
                    steps: maximumStepsPerUnit ?? max(1, speed)
                )
                movedSteps += max(0, units[unitIndex].routeIndex - beforeIndex)
                allArrived = allArrived && arrived
            }

            let defenseIndex = enemyArrived
                ? nearestOperationalDefenseIndex(to: enemyPoint)
                : nil
            guard allArrived || enemyArrived else { continue }

            let enemyTypeID = Self.enemyTypeID(for: alert)
            guard let enemy = models[enemyTypeID: enemyTypeID]
                ?? models[enemyTypeID: 0]
                ?? participating.first.flatMap({ models[figureID: units[$0].figureID] })
            else { continue }
            let report = resolveCombat(
                alert: alert,
                unitIndices: participating,
                defenseIndex: defenseIndex,
                enemyTypeID: enemyTypeID,
                enemy: enemy,
                siegeEngineCount: enemyForcesState?[forceIndex].siegeEngineCount ?? 0,
                models: models
            )
            _ = campaignEvents.resolveInvasion(id: alert.id, as: report.outcome)
            // `resolveCombat` does not mutate the enemy-force array, so the
            // index remains stable across the settlement.
            if enemyForcesState?.indices.contains(forceIndex) == true {
                enemyForcesState?[forceIndex].resolve(report.outcome)
            }
            combatReports.append(report)
            newReports.append(report)
        }
        let settlement = MilitaryMovementSettlement(
            movedSteps: movedSteps,
            reports: newReports,
            enemyMovedSteps: enemyMovedSteps
        )
        lastMovement = settlement
        return settlement
    }

    private mutating func resolveCombat(
        alert: CampaignInvasionAlert,
        unitIndices: [Int],
        defenseIndex: Int?,
        enemyTypeID: Int,
        enemy: FigureModel,
        siegeEngineCount: Int,
        models: FigureModelTable
    ) -> MilitaryCombatReport {
        let participatingIDs = unitIndices.map { units[$0].id }
        let modelsByUnitIndex = Dictionary(uniqueKeysWithValues: unitIndices.compactMap { index in
            models[figureID: units[index].figureID].map { (index, $0) }
        })
        let hitPointsBefore = Dictionary(uniqueKeysWithValues: unitIndices.map {
            ($0, units[$0].hitPoints)
        })
        var friendlyHitPoints = hitPointsBefore
        let friendlyBefore = unitIndices.reduce(0) { partial, index in
            partial + units[index].survivingSoldiers(model: modelsByUnitIndex[index])
        }
        // Real campaign invasions carry the source-side five-family formation
        // plan.  The aggregate combat model uses its recovered normal-branch
        // figure subtotal when present; hand-authored/custom alerts retain
        // their legacy strength value until the source projection is known.
        let enemyBefore = max(1, alert.sourceFigureCount ?? alert.strength)
        var enemyHP = enemyBefore * max(1, enemy.hitPoints)
        var defenses = defensiveStructuresState ?? []
        let defenseID = defenseIndex.map { defenses[$0].id }
        var defenseHP = defenseIndex.map { defenses[$0].integrity } ?? 0
        let activeSentries = sentries.filter { sentry in
            guard sentry.defenseID == defenseID else { return false }
            let range = models[figureID: sentry.figureID]?.missileRange ?? 0
            return range > 0 && alert.entryPoint.map {
                Self.distance(sentry.point, $0) <= range
            } ?? true
        }
        let maximumRange = max(
            unitIndices.compactMap { modelsByUnitIndex[$0]?.missileRange }.max() ?? 0,
            activeSentries.compactMap { models[figureID: $0.figureID]?.missileRange }.max() ?? 0
        )
        let rangedOpeningRounds = min(2, maximumRange / 6)
        var rounds = 0
        while (friendlyHitPoints.values.contains { $0 > 0 } || defenseHP > 0),
              enemyHP > 0, rounds < 256 {
            let enemyCount = (enemyHP + max(1, enemy.hitPoints) - 1)
                / max(1, enemy.hitPoints)
            let unitDamage = unitIndices.reduce(0) { partial, index in
                guard let model = modelsByUnitIndex[index],
                      let hitPoints = friendlyHitPoints[index], hitPoints > 0 else { return partial }
                let count = (hitPoints + max(1, model.hitPoints) - 1) / max(1, model.hitPoints)
                return partial + count * Self.damage(attacker: model, defender: enemy)
            }
            let sentryDamage = defenseHP > 0 ? activeSentries.reduce(0) { partial, sentry in
                guard let model = models[figureID: sentry.figureID] else { return partial }
                return partial + Self.damage(attacker: model, defender: enemy)
            } : 0
            let friendlyDamage = unitDamage + sentryDamage
            enemyHP = max(0, enemyHP - friendlyDamage)

            if enemyHP > 0, rounds >= rangedOpeningRounds {
                if defenseHP > 0 {
                    let structureDamage = enemyCount * max(1, enemy.attack + enemy.missileAttack)
                        + siegeEngineCount * 120
                    defenseHP = max(0, defenseHP - structureDamage)
                } else if let targetIndex = unitIndices.first(where: {
                    (friendlyHitPoints[$0] ?? 0) > 0 && modelsByUnitIndex[$0] != nil
                }), let defender = modelsByUnitIndex[targetIndex] {
                    let enemyDamage = enemyCount * Self.damage(
                        attacker: enemy,
                        defender: defender
                    )
                    friendlyHitPoints[targetIndex] = max(
                        0,
                        (friendlyHitPoints[targetIndex] ?? 0) - enemyDamage
                    )
                }
            }
            rounds += 1
        }
        let outcome: CampaignInvasionStatus = enemyHP == 0 ? .repelled : .cityBreached
        var friendlyAfter = 0
        for index in unitIndices {
            guard let model = modelsByUnitIndex[index] else { continue }
            let remaining = friendlyHitPoints[index] ?? 0
            let before = units[index].survivingSoldiers(model: model)
            let after = remaining == 0 ? 0
                : (remaining + max(1, model.hitPoints) - 1) / max(1, model.hitPoints)
            friendlyAfter += after
            let moraleLoss = max(0, before - after) * 100 / max(1, before)
            units[index].applyCombat(
                hitPoints: remaining,
                morale: 100 - moraleLoss,
                won: outcome == .repelled
            )
        }
        if let defenseIndex {
            defenses[defenseIndex].applyDamage(defenses[defenseIndex].integrity - defenseHP)
            defensiveStructuresState = defenses
        }
        let enemyAfter = enemyHP == 0 ? 0
            : (enemyHP + max(1, enemy.hitPoints) - 1) / max(1, enemy.hitPoints)
        let leadUnitID = unitIndices.first.map { units[$0].id } ?? 0
        let leadFigureID = unitIndices.first.map { units[$0].figureID }
            ?? activeSentries.first?.figureID
            ?? 57
        return MilitaryCombatReport(
            id: "\(alert.id):\(leadUnitID)",
            invasionID: alert.id,
            unitID: leadUnitID,
            friendlyFigureID: leadFigureID,
            friendlySoldiersBefore: friendlyBefore,
            friendlySoldiersLost: friendlyBefore - friendlyAfter,
            enemyTypeID: enemyTypeID,
            enemySoldiersBefore: enemyBefore,
            enemySoldiersLost: enemyBefore - enemyAfter,
            rounds: rounds,
            outcome: outcome,
            participatingUnitIDs: participatingIDs,
            enemySiegeEngineCount: siegeEngineCount
        )
    }

    private mutating func synchronizeEnemyForces(
        with alerts: [CampaignInvasionAlert],
        terrain: DeterministicTerrainState?,
        blockedPoints: Set<GridPoint>,
        models: FigureModelTable
    ) {
        var forces = enemyForcesState ?? []
        for alert in alerts where !forces.contains(where: { $0.invasionID == alert.id }) {
            // FUN_00522D30 can legitimately produce no normal-branch figures
            // for a very small amount.  Do not invent a Native soldier in
            // that source-backed zero case; hero/alternate branches remain
            // unresolved and therefore stay fail-closed.
            if let sourceFigureCount = alert.sourceFigureCount,
               sourceFigureCount <= 0 {
                continue
            }
            let enemyTypeID = Self.enemyTypeID(for: alert)
            let start = alert.entryPoint ?? GridPoint(x: 0, y: (terrain?.height ?? 1) / 2)
            let target = enemyTarget(for: alert, terrain: terrain)
            var routeBlocked = blockedPoints
            routeBlocked.remove(start)
            routeBlocked.remove(target)
            let route = terrain?.shortestLandVisitorPath(
                from: start,
                to: target,
                blocked: routeBlocked
            ) ?? [start]
            forces.append(EnemyMilitaryForce(
                id: alert.id,
                invasionID: alert.id,
                enemyTypeID: enemyTypeID,
                soldierCount: max(1, alert.sourceFigureCount ?? alert.strength),
                // The source's model-62 catapult records and structure-attack
                // path are separate unresolved projections.  Do not turn the
                // authored event amount into a guessed siege count.
                siegeEngineCount: 0,
                currentPoint: start,
                targetPoint: target,
                route: route,
                routeIndex: 0,
                status: .maneuvering
            ))
            _ = models[enemyTypeID: enemyTypeID]
        }
        enemyForcesState = forces
    }

    private func enemyTarget(
        for alert: CampaignInvasionAlert,
        terrain: DeterministicTerrainState?
    ) -> GridPoint {
        let invasionOrigin = alert.entryPoint
            ?? GridPoint(x: (terrain?.width ?? 1) / 2, y: (terrain?.height ?? 1) / 2)
        if let defense = defensiveStructures.filter(\.isOperational).min(by: {
            let left = Self.distance($0.point, invasionOrigin)
            let right = Self.distance($1.point, invasionOrigin)
            return left == right ? $0.id < $1.id : left < right
        }) {
            return defense.point
        }
        if let unit = units.filter({ $0.hitPoints > 0 }).min(by: {
            let left = Self.distance($0.currentPoint, invasionOrigin)
            let right = Self.distance($1.currentPoint, invasionOrigin)
            return left == right ? $0.id < $1.id : left < right
        }) {
            return unit.currentPoint
        }
        return GridPoint(x: (terrain?.width ?? 1) / 2, y: (terrain?.height ?? 1) / 2)
    }

    private mutating func retargetEnemyForce(
        at index: Int,
        target: GridPoint,
        terrain: DeterministicTerrainState?,
        blockedPoints: Set<GridPoint>
    ) {
        guard enemyForcesState?.indices.contains(index) == true,
              let force = enemyForcesState?[index],
              force.status == .maneuvering || force.status == .engaged,
              force.targetPoint != target || force.route.isEmpty else { return }
        var routeBlocked = blockedPoints
        routeBlocked.remove(force.currentPoint)
        routeBlocked.remove(target)
        let route = terrain?.shortestLandVisitorPath(
            from: force.currentPoint,
            to: target,
            blocked: routeBlocked
        ) ?? GridPathfinder.shortestPath(
            width: terrain?.width ?? max(force.currentPoint.x, target.x) + 1,
            height: terrain?.height ?? max(force.currentPoint.y, target.y) + 1,
            from: force.currentPoint,
            to: target,
            isPassable: { !routeBlocked.contains($0) }
        ) ?? [force.currentPoint]
        enemyForcesState?[index].retarget(target, route: route)
    }

    private func nearestOperationalDefenseIndex(to point: GridPoint?) -> Int? {
        let defenses = defensiveStructuresState ?? []
        guard let point else { return defenses.firstIndex(where: \.isOperational) }
        return defenses.indices
            .filter { defenses[$0].isOperational && Self.distance(defenses[$0].point, point) <= 3 }
            .min { lhs, rhs in
                let left = Self.distance(defenses[lhs].point, point)
                let right = Self.distance(defenses[rhs].point, point)
                return left == right ? defenses[lhs].id < defenses[rhs].id : left < right
            }
    }

    private static func damage(attacker: FigureModel, defender: FigureModel) -> Int {
        let melee = attacker.attack > 0 ? max(1, attacker.attack - defender.armor) : 0
        let missile = attacker.missileAttack > 0
            ? max(1, attacker.missileAttack - defender.missileArmor) : 0
        return max(1, melee + missile)
    }

    private static func enemyTypeID(for alert: CampaignInvasionAlert) -> Int {
        // The type-2 invasion handler calls FUN_00522d00 → FUN_00522d30.
        // That builder's normal force path selects authored enemy models
        // 0x3a…0x3e (58…62) by formation category. Native stores one force
        // per alert, so use the infantry member of that family as the stable
        // representative; the alert's secondary selector remains preserved
        // for campaign identity but does not select the regional Xiongnu
        // model (6).
        _ = alert
        return 58
    }

    private static func distance(_ lhs: GridPoint, _ rhs: GridPoint) -> Int {
        abs(lhs.x - rhs.x) + abs(lhs.y - rhs.y)
    }
}
