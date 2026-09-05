import Foundation

public enum MigrationBlockReason: Sendable, Hashable, Codable {
    case noEligibleHousing
    case negativeTreasury
    case highUnemployment(percent: Int)
}

/// Automatic migration remains disabled until the recovered original
/// popularity/factor producer, figure-#11 arrival write chain, and unmapped
/// factor inputs are represented in Native state.
public enum AutomaticMigrationAvailability: String, Sendable, Hashable, Codable {
    /// Enabled after the recovered producer is implemented and verified.
    case supportedOriginalProducer
    /// Fail-closed default: the popularity/factor producer is not run.
    case unsupportedOriginalProducer
}

/// Address/field metadata for the recovered migration request handoff.
///
/// `FUN_005917E0 @ 0x5917E0` is the only indexed producer of non-zero values for
/// the two request words in the canonical EN/CH corpus; the daily consumer
/// `FUN_004AD4A0 @ 0x4AD4A0` only clears them after carrying sub-six requests
/// through the pending words. This catalog deliberately records raw roles and
/// addresses only; it does not project Native objects into the source registry
/// or enable migration.
public enum OriginalMigrationRequestProducerCatalog {
    public enum Stream: String, Sendable, Hashable, Codable {
        case arrival
        case departure
    }

    public static let pressureProducerAddress: UInt32 = 0x005917E0
    public static let requestScaleHelperAddress: UInt32 = 0x0059A1B0
    public static let dailyConsumerAddress: UInt32 = 0x004AD4A0
    public static let arrivalAssignmentAddress: UInt32 = 0x004ADA10
    public static let departureAssignmentAddress: UInt32 = 0x004ADC90

    /// Complete direct relative-call sites recovered in both canonical PE
    /// images.  These are callsite addresses, not an assertion that an
    /// indirect/table-driven edge does not exist.
    public static let pressureProducerDirectCallSites: [UInt32] = [
        0x004AD4C0,
    ]
    public static let dailyConsumerDirectCallSites: [UInt32] = [
        0x004AC3E2,
    ]
    public static let arrivalAssignmentDirectCallSites: [UInt32] = [
        0x004AD4EB, 0x004AD508,
    ]
    public static let departureAssignmentDirectCallSites: [UInt32] = [
        0x004AD52C, 0x004AD544,
    ]

    /// Exact figure/house write edges reached after a request crosses the
    /// source's six-person pending threshold.  These are metadata only: the
    /// popularity producer, object-registry projection, and route/arrival
    /// lifecycle remain unresolved, so Qin does not invoke these addresses.
    public static let arrivalFigureWriterAddress: UInt32 = 0x004ADE10
    public static let departureFigureWriterAddress: UInt32 = 0x004ADED0
    /// The canonical PE-wide direct-call census finds 97 calls to the generic
    /// figure allocator, but only `FUN_004ADE10` passes the immediate
    /// type-`0xB` immigrant model.  Keep the exact callsite separate from the
    /// writer census so indirect/table dispatch is not mistaken for absent.
    public static let arrivalFigureAllocatorAddress: UInt32 = 0x004EA050
    public static let arrivalFigureAllocatorDirectCallSites: [UInt32] = [
        0x004ADE2B,
    ]
    public static let arrivalFigureAllocatorDirectCallerAddresses: [UInt32] = [
        0x004ADE10,
    ]
    public static let arrivalFigureAllocatorFlags = 1
    /// Complete direct relative-call sites to the figure/house assignment
    /// helpers in both canonical PE `.text` sections.  These are metadata
    /// only; constructor inputs and arrival settlement remain unresolved.
    public static let arrivalFigureWriterDirectCallSites: [UInt32] = [
        0x004ADB04, 0x004ADB18, 0x004ADB92,
        0x004ADBA6, 0x004ADC1C, 0x004ADC2F,
    ]
    public static let departureFigureWriterDirectCallSites: [UInt32] = [
        0x004ADD04, 0x004ADD12,
    ]
    public static let arrivalFigureTypeID = 0x0B
    public static let departureFigureTypeID = 0x0C
    public static let assignmentFigureStateOffset = 0x40
    public static let assignmentFigureStateValue = 6
    public static let arrivalFigureHouseIDOffset = 0x64
    /// `FUN_004ADA10` loads the candidate house object's registry dword at
    /// `+0xB4` and passes it as the first argument to `FUN_004ADE10`.
    /// `FUN_004ADC90` does the same for `FUN_004ADED0`.  This is the source
    /// object-vector identity, not a map-cell index or provider-specific
    /// semantic; Qin archive rows still need an unresolved projection into
    /// this live object registry before either writer can be invoked.
    public static let arrivalHouseArgumentRegistryFieldOffset = 0xB4
    public static let departureHouseArgumentRegistryFieldOffset = 0xB4
    public static let arrivalHouseArgumentSourceAddress: UInt32 = 0x004ADA10
    public static let departureHouseArgumentSourceAddress: UInt32 = 0x004ADC90
    public static let houseArgumentRegistryLookupAddress: UInt32 = 0x0047F1B0
    public static let arrivalFigurePeopleCountOffset = 0x6E
    public static let departureFigurePeopleCountOffset = 0x6E
    public static let arrivalHouseInFlightFigureOffset = 0x32
    public static let houseResidentCountOffset = 0x20
    public static let populationLedgerCallbackAddress: UInt32 = 0x00591900

    public static let arrivalRequestWordAddress: UInt32 = 0x01311F7C
    public static let departureRequestWordAddress: UInt32 = 0x01311F80
    public static let departurePendingWordAddress: UInt32 = 0x01311F84
    public static let arrivalPendingWordAddress: UInt32 = 0x01311F88

    public static func requestWordAddress(for stream: Stream) -> UInt32 {
        switch stream {
        case .arrival:
            return arrivalRequestWordAddress
        case .departure:
            return departureRequestWordAddress
        }
    }

    public static func pendingWordAddress(for stream: Stream) -> UInt32 {
        switch stream {
        case .arrival:
            return arrivalPendingWordAddress
        case .departure:
            return departurePendingWordAddress
        }
    }
}

/// Direct-call metadata for the source monument matching walk.
///
/// The canonical EN/CH `.text` scans contain exactly these four relative-call
/// sites to `FUN_0055AE30 @ 0x55AE30`.  This is a direct-call census only:
/// vtable/table dispatch and the unresolved live object-vector projection are
/// deliberately not treated as absent.
public enum OriginalMonumentMatchingCatalog {
    public static let address: UInt32 = 0x0055AE30

    public static let directCallSites: [UInt32] = [
        0x0055B6AB,
        0x0055E498,
        0x00591281,
        0x005B8C4B,
    ]

    /// Function starts enclosing the direct callsites, in the same order as
    /// `directCallSites`.
    public static let directCallerAddresses: [UInt32] = [
        0x0055B6A0,
        0x0055E490,
        0x00591200,
        0x005B8740,
    ]
}

public struct MigrationAssessment: Sendable, Hashable, Codable {
    public let eligibleHouseIDs: [Int]
    public let availableCapacity: Int
    public let unemploymentPercent: Int
    public let plannedImmigrants: Int
    public let blockReason: MigrationBlockReason?

    public static let noHousing = Self(
        eligibleHouseIDs: [],
        availableCapacity: 0,
        unemploymentPercent: 0,
        plannedImmigrants: 0,
        blockReason: .noEligibleHousing
    )
}

/// Raw object inputs for the source population aggregate
/// (`FUN_00517DE0 @ 0x517DE0`). `residentWord` is the signed 16-bit value at
/// object offset `+0x20`; the two predicates stand in for the object's vtable
/// callbacks at `+0xB8` and `+0x204`. Native `ResidentialUnit` values are not
/// converted into this record because their object state and callback
/// projection are not recovered.
public struct OriginalPopulationAggregateObject: Sendable, Hashable, Codable {
    public let state: Int
    public let residentWord: Int
    public let qualifiesForPopulation: Bool
    public let qualifiesForSecondaryPopulation: Bool

    public init(
        state: Int,
        residentWord: Int,
        qualifiesForPopulation: Bool,
        qualifiesForSecondaryPopulation: Bool
    ) {
        self.state = state
        self.residentWord = residentWord
        self.qualifiesForPopulation = qualifiesForPopulation
        self.qualifiesForSecondaryPopulation = qualifiesForSecondaryPopulation
    }
}

/// Raw `HouseBldg` fields that feed the two callbacks consumed by
/// `FUN_00517DE0 @ 0x517DE0`.  The source's `+0xB8` implementation
/// (`FUN_0042DD40`) returns true exactly when object byte `+0x09` is non-zero;
/// the `+0x204` implementation (`FUN_00518D90`) returns true exactly when
/// signed model word `+0x14` is at least `11`.  The object-state exclusions
/// are applied by the enclosing population walk, not by either callback.
///
/// This is a source-backed projection only.  It does not claim that every
/// Native `ResidentialUnit` has an equivalent serialized object state or that
/// map-loaded Qin records have already been specialized into `HouseBldg`.
public struct OriginalHousePopulationCallbackInput: Sendable, Hashable, Codable {
    public let objectStateByte: UInt8
    public let houseEligibilityByte: UInt8
    public let residentWord: Int
    public let houseTypeWord: Int16

    public init(
        objectStateByte: UInt8,
        houseEligibilityByte: UInt8,
        residentWord: Int,
        houseTypeWord: Int16
    ) {
        self.objectStateByte = objectStateByte
        self.houseEligibilityByte = houseEligibilityByte
        self.residentWord = residentWord
        self.houseTypeWord = houseTypeWord
    }

    /// Converts the recovered HouseBldg fields into the explicit callback
    /// results expected by `OriginalPopulationAggregate.evaluate`.
    public var aggregateObject: OriginalPopulationAggregateObject {
        .init(
            state: Int(objectStateByte),
            residentWord: residentWord,
            qualifiesForPopulation: houseEligibilityByte != 0,
            qualifiesForSecondaryPopulation: houseTypeWord >= 11
        )
    }

    /// Whether the source population walk admits this record after applying
    /// its object-state byte and HouseBldg `+0xB8` callback.
    public var isPopulationEligible: Bool {
        objectStateByte != 0
            && objectStateByte != 2
            && objectStateByte != 5
            && objectStateByte != 6
            && houseEligibilityByte != 0
    }

    /// Whether an admitted record contributes to the source `+0x2C` upper
    /// class total selected by HouseBldg `+0x204`.
    public var isSecondaryPopulationEligible: Bool {
        isPopulationEligible && houseTypeWord >= 11
    }
}

/// The two output words written by `FUN_00517DE0`: `+0x28` is the aggregate
/// signed resident count and `+0x2C` is the subset accepted by the second
/// vtable predicate. The source excludes object states `0`, `2`, `5`, and `6`
/// before invoking either predicate; state `6` therefore never reaches the
/// `+0xB8` callback.
public struct OriginalPopulationAggregate: Sendable, Hashable, Codable {
    public let population: Int
    public let secondaryPopulation: Int

    public init(population: Int, secondaryPopulation: Int) {
        self.population = population
        self.secondaryPopulation = secondaryPopulation
    }

    public static func evaluate(
        objects: [OriginalPopulationAggregateObject]
    ) -> Self {
        var population = 0
        var secondaryPopulation = 0
        for object in objects {
            let state = UInt8(truncatingIfNeeded: object.state)
            guard state != 0, state != 2, state != 5, state != 6,
                  object.qualifiesForPopulation else {
                continue
            }

            let residents = Int(Int16(truncatingIfNeeded: object.residentWord))
            population += residents
            if object.qualifiesForSecondaryPopulation {
                secondaryPopulation += residents
            }
        }
        return .init(
            population: population,
            secondaryPopulation: secondaryPopulation
        )
    }
}

/// Raw population-ledger state touched by `FUN_00591920/30/50/70/9A0`.
/// `populationWord` mirrors `DAT_0130F988`, `unclassifiedDeltaWord` mirrors
/// `DAT_01311F8C`, and `highWaterMark` mirrors `DAT_0131257C`. The source does
/// not expose stable semantic names for the second word; the raw label is
/// intentional. This value type records arithmetic only and is not wired to
/// Native's house or figure collections.
public struct OriginalPopulationLedger: Sendable, Hashable, Codable {
    public private(set) var populationWord: Int
    public private(set) var unclassifiedDeltaWord: Int
    public private(set) var highWaterMark: Int

    public init(
        populationWord: Int = 0,
        unclassifiedDeltaWord: Int = 0,
        highWaterMark: Int = 0
    ) {
        self.populationWord = populationWord
        self.unclassifiedDeltaWord = unclassifiedDeltaWord
        self.highWaterMark = highWaterMark
        refreshHighWaterMark()
    }

    /// Mirrors `FUN_00591970`: subtract the supplied signed amount, clamp the
    /// population word at zero, then apply `FUN_00590A50`'s high-water update.
    public mutating func decrementPopulation(by amount: Int) {
        populationWord -= amount
        if populationWord < 0 {
            populationWord = 0
        }
        refreshHighWaterMark()
    }

    /// Mirrors `FUN_005919A0`: add the supplied signed amount, clamp at zero,
    /// then apply the same high-water update.
    public mutating func incrementPopulation(by amount: Int) {
        populationWord += amount
        if populationWord < 0 {
            populationWord = 0
        }
        refreshHighWaterMark()
    }

    /// Mirrors `FUN_00591950`: increase the unclassified word and then run
    /// the population-decrement path for the same count.
    public mutating func applyTypeDCountIncrease(_ count: Int) {
        unclassifiedDeltaWord += count
        decrementPopulation(by: count)
    }

    /// Mirrors `FUN_00591930`: decrease the unclassified word and then run
    /// the population-increment path for the same count.
    public mutating func applyTypeDCountDecrease(_ count: Int) {
        unclassifiedDeltaWord -= count
        incrementPopulation(by: count)
    }

    private mutating func refreshHighWaterMark() {
        if highWaterMark < populationWord {
            highWaterMark = populationWord
        }
    }
}

/// One house selected by the original emigration assignment walk
/// (`FUN_004ADC90 @ 0x4ADC90`). `houseVectorIndex` is the position in the
/// executable's live house vector; the source does not sort by object ID.
/// `houseLevelIndex` is the raw `house+0x16` bucket (0…13).
public struct OriginalDepartureHouse: Sendable, Hashable, Codable {
    public let houseVectorIndex: Int
    public let houseLevelIndex: Int
    public let residentCount: Int

    public init(
        houseVectorIndex: Int,
        houseLevelIndex: Int,
        residentCount: Int
    ) {
        self.houseVectorIndex = houseVectorIndex
        self.houseLevelIndex = houseLevelIndex
        self.residentCount = residentCount
    }
}

/// One exact batch selected by the original departure walk. The corresponding
/// `FUN_004ADED0` call mutates the house and attempts to spawn an emigrant
/// figure; this value records only the already-closed selection inputs.
public struct OriginalDepartureAssignment: Sendable, Hashable, Codable {
    public let houseVectorIndex: Int
    public let houseLevelIndex: Int
    public let peopleCount: Int

    public init(
        houseVectorIndex: Int,
        houseLevelIndex: Int,
        peopleCount: Int
    ) {
        self.houseVectorIndex = houseVectorIndex
        self.houseLevelIndex = houseLevelIndex
        self.peopleCount = peopleCount
    }
}

/// Result of the source-complete departure assignment pass. `unassigned`
/// mirrors the request remainder after all fourteen level buckets have been
/// scanned; it is not a claim that the downstream figure spawn succeeded.
public struct OriginalDepartureAssignmentPlan: Sendable, Hashable, Codable {
    public let assignments: [OriginalDepartureAssignment]
    public let unassigned: Int

    public init(
        assignments: [OriginalDepartureAssignment],
        unassigned: Int
    ) {
        self.assignments = assignments
        self.unassigned = unassigned
    }
}

/// One raw house record consumed by the immigrant assignment walk
/// (`FUN_004ADA10 @ 0x4ADA10`).  These fields retain the source short words:
/// `accessValue` is `house+0x24`, `residents` is `house+0x20`, and
/// `remainingCapacity` is `house+0x22`.  The link fields are the already
/// resolved object behind `house+0x32`: the source keeps a link only when the
/// linked object has model `0xB` at `+0x12` and a non-zero state at `+0x16`.
/// No Native house or registry projection is implied by this record.
public struct OriginalImmigrantAssignmentHouse: Sendable, Hashable, Codable {
    public let houseVectorIndex: Int
    public let accessValue: Int
    public let residents: Int
    public let remainingCapacity: Int
    public let houseLinkPresent: Bool
    public let linkedObjectModelID: Int
    public let linkedObjectState16: Int

    public init(
        houseVectorIndex: Int,
        accessValue: Int,
        residents: Int,
        remainingCapacity: Int,
        houseLinkPresent: Bool = false,
        linkedObjectModelID: Int = 0,
        linkedObjectState16: Int = 0
    ) {
        self.houseVectorIndex = houseVectorIndex
        self.accessValue = accessValue
        self.residents = residents
        self.remainingCapacity = remainingCapacity
        self.houseLinkPresent = houseLinkPresent
        self.linkedObjectModelID = linkedObjectModelID
        self.linkedObjectState16 = linkedObjectState16
    }
}

/// One batch emitted by the source's three assignment passes.  `pass` is
/// `1` for an empty house with spare capacity, `2` for a house with more than
/// eleven spare places, and `3` for any remaining positive spare capacity.
public struct OriginalImmigrantAssignment: Sendable, Hashable, Codable {
    public let houseVectorIndex: Int
    public let peopleCount: Int
    public let pass: Int

    public init(houseVectorIndex: Int, peopleCount: Int, pass: Int) {
        self.houseVectorIndex = houseVectorIndex
        self.peopleCount = peopleCount
        self.pass = pass
    }
}

/// Result of `FUN_004ADA10`'s assignment-only portion.  The source mutates
/// the live house link before the three passes; `clearedHouseVectorIndices`
/// records those exact cleanup writes.  Figure creation, routes, and arrival
/// settlement remain outside this pure boundary.
public struct OriginalImmigrantAssignmentPlan: Sendable, Hashable, Codable {
    public let assignments: [OriginalImmigrantAssignment]
    public let unassigned: Int
    public let clearedHouseVectorIndices: [Int]

    public init(
        assignments: [OriginalImmigrantAssignment],
        unassigned: Int,
        clearedHouseVectorIndices: [Int] = []
    ) {
        self.assignments = assignments
        self.unassigned = unassigned
        self.clearedHouseVectorIndices = clearedHouseVectorIndices
    }
}

/// Pure reproduction of the recovered three-pass immigrant assignment walk.
/// The vector is rescanned in its existing order for each pass; no ID sort is
/// performed.  A batch is capped at six, and the local remainder is consumed
/// even though the downstream `FUN_004ADE10` figure constructor is not modeled
/// here.  The caller must supply the original house words and linked-object
/// fields; Native state is not treated as an equivalent registry projection.
public enum OriginalImmigrantAssignmentPlanner {
    public static let maximumBatchSize = 6

    public static func plan(
        request: Int,
        houses: [OriginalImmigrantAssignmentHouse]
    ) -> OriginalImmigrantAssignmentPlan {
        guard request > 0 else {
            return .init(assignments: [], unassigned: 0)
        }

        var normalized = houses
        var cleared: [Int] = []
        for index in normalized.indices where normalized[index].houseLinkPresent {
            let linkedObjectIsActive = normalized[index].linkedObjectModelID == 0xB
                && normalized[index].linkedObjectState16 != 0
            guard !linkedObjectIsActive else { continue }
            let house = normalized[index]
            normalized[index] = OriginalImmigrantAssignmentHouse(
                houseVectorIndex: house.houseVectorIndex,
                accessValue: house.accessValue,
                residents: house.residents,
                remainingCapacity: house.remainingCapacity,
                houseLinkPresent: false,
                linkedObjectModelID: house.linkedObjectModelID,
                linkedObjectState16: house.linkedObjectState16
            )
            cleared.append(house.houseVectorIndex)
        }

        var remaining = request
        var assignments: [OriginalImmigrantAssignment] = []

        func appendBatch(
            for house: OriginalImmigrantAssignmentHouse,
            pass: Int,
            requested: Int
        ) {
            let batch = min(maximumBatchSize, min(requested, remaining))
            guard batch > 0 else { return }
            assignments.append(.init(
                houseVectorIndex: house.houseVectorIndex,
                peopleCount: batch,
                pass: pass
            ))
            remaining -= batch
        }

        // Pass 1: accessible, empty houses with a positive spare-capacity
        // word.  An active immigrant link is skipped; invalid links were
        // cleared by the source cleanup above.
        for house in normalized where remaining > 0 {
            guard house.accessValue > 0,
                  house.residents == 0,
                  house.remainingCapacity != 0,
                  !house.houseLinkPresent else { continue }
            appendBatch(for: house, pass: 1, requested: maximumBatchSize)
        }

        // Pass 2: accessible houses with more than eleven spare places.
        for house in normalized where remaining > 0 {
            guard house.accessValue > 0,
                  house.remainingCapacity > 0xB,
                  !house.houseLinkPresent else { continue }
            appendBatch(for: house, pass: 2, requested: maximumBatchSize)
        }

        // Pass 3: all other accessible houses with positive spare capacity.
        for house in normalized where remaining > 0 {
            guard house.accessValue > 0,
                  house.remainingCapacity > 0,
                  !house.houseLinkPresent else { continue }
            appendBatch(for: house, pass: 3, requested: house.remainingCapacity)
        }

        return .init(
            assignments: assignments,
            unassigned: remaining,
            clearedHouseVectorIndices: cleared
        )
    }
}

/// Inputs to the type-`0xB` figure constructor `FUN_004ADE10 @ 0x4ADE10`.
/// `figureTableWord` is the already-resolved `DAT_00F6A9E0[figure+0x28]`
/// value; the constructor only consumes its bit 6.  The allocator result and
/// figure ID remain explicit because Native has no source-equivalent figure
/// registry.
public struct OriginalImmigrantFigureSpawnInput: Sendable, Hashable, Codable {
    public let allocationSucceeded: Bool
    public let figureID: Int?
    public let houseObjectID: Int
    public let peopleCount: Int
    public let houseFlag51: Int
    public let initialWaitWord: Int
    public let figureTableWord: UInt32

    public init(
        allocationSucceeded: Bool,
        figureID: Int? = nil,
        houseObjectID: Int,
        peopleCount: Int,
        houseFlag51: Int,
        initialWaitWord: Int,
        figureTableWord: UInt32 = 0
    ) {
        self.allocationSucceeded = allocationSucceeded
        self.figureID = figureID
        self.houseObjectID = houseObjectID
        self.peopleCount = peopleCount
        self.houseFlag51 = houseFlag51
        self.initialWaitWord = initialWaitWord
        self.figureTableWord = figureTableWord
    }
}

/// Exact field writes and wait-pointer update performed after a successful
/// `FUN_004EA050(1, 0xB, ...)` allocation.  A failed allocation returns no
/// figure writes and leaves the caller's wait word unchanged, while the
/// assignment caller still accounts the requested batch separately.
public struct OriginalImmigrantFigureSpawnResult: Sendable, Hashable, Codable {
    public let succeeded: Bool
    public let figureID: Int?
    public let figureState40: Int?
    public let figureHouseID64: Int?
    public let figureWaitWord3E: UInt16?
    public let figurePeopleByte6E: UInt8?
    public let figureFlag13: UInt8?
    public let figureFlag49: UInt8?
    public let linkedHouseObjectID: Int?
    public let updatedWaitWord: Int

    public init(
        succeeded: Bool,
        figureID: Int?,
        figureState40: Int?,
        figureHouseID64: Int?,
        figureWaitWord3E: UInt16?,
        figurePeopleByte6E: UInt8?,
        figureFlag13: UInt8?,
        figureFlag49: UInt8?,
        linkedHouseObjectID: Int?,
        updatedWaitWord: Int
    ) {
        self.succeeded = succeeded
        self.figureID = figureID
        self.figureState40 = figureState40
        self.figureHouseID64 = figureHouseID64
        self.figureWaitWord3E = figureWaitWord3E
        self.figurePeopleByte6E = figurePeopleByte6E
        self.figureFlag13 = figureFlag13
        self.figureFlag49 = figureFlag49
        self.linkedHouseObjectID = linkedHouseObjectID
        self.updatedWaitWord = updatedWaitWord
    }
}

public enum OriginalImmigrantFigureSpawn {
    public static let figureTypeID = 0xB
    public static let initializedState = 6
    public static let successfulSpawnWaitIncrement = 0x32

    public static func apply(
        _ input: OriginalImmigrantFigureSpawnInput
    ) -> OriginalImmigrantFigureSpawnResult {
        guard input.allocationSucceeded, let figureID = input.figureID else {
            return .init(
                succeeded: false,
                figureID: nil,
                figureState40: nil,
                figureHouseID64: nil,
                figureWaitWord3E: nil,
                figurePeopleByte6E: nil,
                figureFlag13: nil,
                figureFlag49: nil,
                linkedHouseObjectID: nil,
                updatedWaitWord: input.initialWaitWord
            )
        }

        let houseFlag = UInt8(truncatingIfNeeded: input.houseFlag51)
        let waitWord = UInt16(
            truncatingIfNeeded: (Int(houseFlag) & 0xFF7F) + input.initialWaitWord
        )
        let peopleByte = UInt8(truncatingIfNeeded: input.peopleCount)
        let lowFlag = houseFlag & 1
        let regionFlag = UInt8((input.figureTableWord >> 6) & 1)
        return .init(
            succeeded: true,
            figureID: figureID,
            figureState40: initializedState,
            figureHouseID64: input.houseObjectID,
            figureWaitWord3E: waitWord,
            figurePeopleByte6E: peopleByte,
            figureFlag13: lowFlag,
            figureFlag49: regionFlag,
            linkedHouseObjectID: input.houseObjectID,
            updatedWaitWord: input.initialWaitWord + successfulSpawnWaitIncrement
        )
    }
}

/// One already-resolved result of `FUN_004E23A0`, the allocator-state
/// candidate consumed by `FUN_004E1420`/`FUN_004EA050`.  The candidate ID is
/// passed to `FUN_004E2400`; `objectPresent` represents the mapped vector slot
/// and `objectState16` is the object's raw byte at `+0x16`.
public struct OriginalFigureAllocationCandidate: Sendable, Hashable, Codable {
    public let candidateID: Int
    public let objectPresent: Bool
    public let objectState16: Int

    public init(
        candidateID: Int,
        objectPresent: Bool,
        objectState16: Int = 0
    ) {
        self.candidateID = candidateID
        self.objectPresent = objectPresent
        self.objectState16 = objectState16
    }

    /// The exact gate before the generic allocator dispatches the requested
    /// model constructor: positive candidate ID, non-null mapped object, and
    /// an inactive (`+0x16 == 0`) object state.
    public var isAvailable: Bool {
        candidateID > 0 && objectPresent && objectState16 == 0
    }
}

/// Result of the bounded candidate scan in `FUN_004E1420`.  A non-nil ID is
/// the first eligible allocator result; `attemptCount` is the number of
/// resolved candidates examined, capped at the source's five calls.
public struct OriginalFigureAllocationResult: Sendable, Hashable, Codable {
    public let candidateID: Int?
    public let attemptCount: Int

    public init(candidateID: Int?, attemptCount: Int) {
        self.candidateID = candidateID
        self.attemptCount = attemptCount
    }
}

/// The mutable cursor/count words consumed by `FUN_004E23A0 @ 0x4E23A0`.
/// `slotValue` is supplied by the caller after resolving the current ring
/// slot; the source's slot population and registry ownership are not inferred
/// here.  The wrap comparison is against index `0x7CE`, giving a 1999-slot
/// ring (`0…0x7CE`), and the count is decremented for every non-zero count,
/// including a negative raw value.
public struct OriginalFigureAllocatorState: Sendable, Hashable, Codable {
    public static let lastRingIndex = 0x7CE
    public static let ringSlotCount = lastRingIndex + 1
    /// Raw source object used as ECX by the allocator ring helpers. These
    /// offsets describe executable state only, not a Native figure-registry
    /// projection.
    public static let sourceStateAddress: UInt32 = 0x01032678
    public static let cursorOffset: UInt32 = 0x00
    public static let writeCursorOffset: UInt32 = 0x04
    public static let availableCountOffset: UInt32 = 0x08
    public static let ringValuesOffset: UInt32 = 0x0C
    public static let ringResetAddress: UInt32 = 0x004EBBF0
    public static let ringSeedAddress: UInt32 = 0x004EBC00
    public static let ringSeedFirstID = 1
    public static let ringSeedExclusiveUpperBound = 2000
    public static let liveRegistryRebuildAddress: UInt32 = 0x004E9FE0
    public static let liveRegistryRebuildDirectCallSites: [UInt32] = [
        0x00534D08,
    ]
    /// `FUN_004E1420` resolves the candidate ID through `FUN_004E2400`, then
    /// obtains the corresponding global object-vector slot through
    /// `FUN_00408200` and stores the newly constructed figure pointer there.
    /// This is the recovered figure-registry projection; it is distinct from
    /// a Building's provider `+0xB4` field and is not a Qin map-load bridge.
    public static let candidateObjectLookupAddress: UInt32 = 0x004E2400
    public static let objectVectorSlotAddressHelper: UInt32 = 0x00408200
    public static let objectVectorBaseAddress: UInt32 = 0x004F8210
    public static let objectVectorSlotStrideBytes = 4
    public static let objectVectorSlotStoreAddress: UInt32 = 0x004E18CA
    public static let objectVectorSlotStoreUsesCandidateID = true
    public static let objectVectorSlotStoresConstructedFigure = true

    public private(set) var cursor: Int
    public private(set) var writeCursor: Int
    public private(set) var availableCount: Int

    public init(
        cursor: Int = 0,
        writeCursor: Int = 0,
        availableCount: Int = 0
    ) {
        self.cursor = cursor
        self.writeCursor = writeCursor
        self.availableCount = availableCount
    }

    /// Mirrors one `FUN_004E23A0` call after its current slot has been read.
    /// A zero count returns `nil` without changing either state word; every
    /// other count returns the supplied slot value, advances/wraps the cursor,
    /// and decrements the count.
    public mutating func consume(slotValue: Int) -> Int? {
        guard availableCount != 0 else { return nil }
        let result = slotValue
        cursor += 1
        if cursor > Self.lastRingIndex {
            cursor = 0
        }
        availableCount -= 1
        return result
    }

    /// The companion `FUN_004E23D0` enqueue transition. The returned index is
    /// where the caller stores `slotValue`; the source keeps a distinct write
    /// cursor at `+0x04`, advances/wraps it with the same `0x7CE` boundary,
    /// and increments the shared count without a capacity clamp.
    @discardableResult
    public mutating func enqueue(slotValue: Int) -> (slotIndex: Int, slotValue: Int) {
        let slotIndex = writeCursor
        writeCursor += 1
        if writeCursor > Self.lastRingIndex {
            writeCursor = 0
        }
        availableCount += 1
        return (slotIndex: slotIndex, slotValue: slotValue)
    }

    /// Mirrors `FUN_004EBBF0`, which clears read cursor, write cursor, and
    /// count before the ascending `FUN_004E23D0` refill.
    public mutating func reset() {
        cursor = 0
        writeCursor = 0
        availableCount = 0
    }
}

/// Resolved object-vector fields consumed by the map/runtime queue rebuild
/// `FUN_004E9FE0 @ 0x4E9FE0`. Object IDs are the fixed 1…1999 registry slots;
/// `state16` is the raw object byte at `+0x16`, and `state12` is the raw byte
/// at `+0x12` re-read after the non-free counter update.
public struct OriginalFigureAllocatorObjectRecord: Sendable, Hashable, Codable {
    public let objectID: Int
    public let state16: Int
    public let state12: Int

    public init(objectID: Int, state16: Int, state12: Int = 0) {
        self.objectID = objectID
        self.state16 = state16
        self.state12 = state12
    }
}

/// Output of the source's descending free-object rebuild. The two non-free
/// lists expose only the additional counter-side-effect inputs; the details
/// of `FUN_004EBB40` and `FUN_00417350` remain separate boundaries.
public struct OriginalFigureAllocatorQueueRebuildResult: Sendable, Hashable, Codable {
    public let freeObjectIDs: [Int]
    public let counterUpdateObjectIDs: [Int]
    public let specialState12ObjectIDs: [Int]

    public init(
        freeObjectIDs: [Int],
        counterUpdateObjectIDs: [Int],
        specialState12ObjectIDs: [Int]
    ) {
        self.freeObjectIDs = freeObjectIDs
        self.counterUpdateObjectIDs = counterUpdateObjectIDs
        self.specialState12ObjectIDs = specialState12ObjectIDs
    }
}

/// Pure queue-population boundaries for the two recovered refill callers.
/// Incomplete or duplicate object-vector input returns `nil` rather than
/// silently treating missing registry slots as free.
public enum OriginalFigureAllocatorQueue {
    public static let firstObjectID = 1
    public static let lastObjectID = 1999

    /// Mirrors `FUN_004EBC00`: reset the queue, then enqueue every object ID
    /// in ascending order. The caller still owns the queue's mutable cursors.
    public static func bootstrapObjectIDs() -> [Int] {
        Array(firstObjectID...lastObjectID)
    }

    /// Mirrors `FUN_004E9FE0` after its object-vector lookups are resolved.
    /// Free (`+0x16 == 0`) objects are enqueued in descending ID order.
    /// Non-free states other than `2` enter the separate counter update; the
    /// post-update `+0x12 == 1` subset is reported without modeling its global
    /// counters. A complete one-record-per-slot input is required.
    public static func rebuild(
        objects: [OriginalFigureAllocatorObjectRecord]
    ) -> OriginalFigureAllocatorQueueRebuildResult? {
        guard objects.count == OriginalFigureAllocatorState.ringSlotCount else {
            return nil
        }
        var byID: [Int: OriginalFigureAllocatorObjectRecord] = [:]
        for object in objects {
            guard byID[object.objectID] == nil else { return nil }
            byID[object.objectID] = object
        }
        guard byID.count == OriginalFigureAllocatorState.ringSlotCount,
              byID.keys.allSatisfy({ (firstObjectID...lastObjectID).contains($0) }) else {
            return nil
        }

        var free: [Int] = []
        var counterUpdates: [Int] = []
        var special: [Int] = []
        for objectID in stride(from: lastObjectID, through: firstObjectID, by: -1) {
            guard let object = byID[objectID] else { return nil }
            if object.state16 == 0 {
                free.append(objectID)
            } else if object.state16 != 2 {
                counterUpdates.append(objectID)
                if object.state12 == 1 {
                    special.append(objectID)
                }
            }
        }
        return .init(
            freeObjectIDs: free,
            counterUpdateObjectIDs: counterUpdates,
            specialState12ObjectIDs: special
        )
    }
}

/// The two model predicates consumed by `FUN_004EBB40 @ 0x4EBB40` after an
/// object-vector lookup has supplied the object's `+0x12` model byte.
public struct OriginalFigureCounterClassification: Sendable, Hashable, Codable {
    public let modelID: Int
    public let updatesFirstCounter: Bool
    public let updatesSecondCounter: Bool

    public init(modelID: Int, updatesFirstCounter: Bool, updatesSecondCounter: Bool) {
        self.modelID = modelID
        self.updatesFirstCounter = updatesFirstCounter
        self.updatesSecondCounter = updatesSecondCounter
    }

    public static func resolve(modelID: Int) -> Self {
        .init(
            modelID: modelID,
            updatesFirstCounter: (0x3A...0x3E).contains(modelID) || modelID == 0x4E,
            updatesSecondCounter: modelID == 0x38
                || modelID == 0x39
                || (0x40...0x44).contains(modelID)
                || modelID == 0x4F
        )
    }
}

/// Explicit global-counter arithmetic from `FUN_004EBB40`. The source clamps
/// each decremented counter at zero; model lookup and object-vector existence
/// are caller inputs, so no registry mapping is inferred here.
public struct OriginalFigureGlobalCounters: Sendable, Hashable, Codable {
    public private(set) var first: Int
    public private(set) var second: Int

    public init(first: Int = 0, second: Int = 0) {
        self.first = first
        self.second = second
    }

    /// Applies the source update for one positive object ID. `adding` mirrors
    /// the raw `param_2` byte: non-zero increments, zero decrements.
    public mutating func apply(
        objectID: Int,
        modelID: Int,
        adding: Bool
    ) {
        guard objectID > 0 else { return }
        let classification = OriginalFigureCounterClassification.resolve(modelID: modelID)
        let delta = adding ? 1 : -1
        if classification.updatesFirstCounter {
            first = max(0, first + delta)
        }
        if classification.updatesSecondCounter {
            second = max(0, second + delta)
        }
    }
}

/// Pure reproduction of the allocator gate shared by immigrant figure
/// creation and other object factories.  `FUN_004E1420` calls
/// `FUN_004E23A0` once, then retries only after a failed object/state gate; the
/// fifth failed candidate returns zero.  Constructor dispatch, pool
/// registration, and model-specific vtable initialization remain outside this
/// boundary.
public enum OriginalFigureAllocator {
    public static let maximumCandidateAttempts = 5

    public static func firstAvailable(
        candidates: [OriginalFigureAllocationCandidate]
    ) -> OriginalFigureAllocationResult {
        let scanned = candidates.prefix(maximumCandidateAttempts)
        for (offset, candidate) in scanned.enumerated() {
            if candidate.isAvailable {
                return .init(candidateID: candidate.candidateID, attemptCount: offset + 1)
            }
        }
        return .init(candidateID: nil, attemptCount: scanned.count)
    }
}

/// Pure reproduction of `FUN_004ADC90 @ 0x4ADC90`'s fourteen-bucket walk.
///
/// For each level index `0…13`, the executable rescans the house vector in
/// its existing order. A positive resident count is selected when
/// `house+0x16 == level`, with a batch of `min(6, residents, remaining)`;
/// `FUN_004ADED0` is then called and the local remainder is reduced regardless
/// of whether that figure creation succeeds. This planner intentionally does
/// not subtract residents, create type-`0xC` figures, or invent a route/home
/// unlink contract.
public enum OriginalDepartureAssignmentPlanner {
    public static let maximumHouseLevelIndex = 13
    public static let maximumBatchSize = 6

    public static func plan(
        request: Int,
        houses: [OriginalDepartureHouse]
    ) -> OriginalDepartureAssignmentPlan {
        guard request > 0 else {
            return .init(assignments: [], unassigned: 0)
        }

        var remaining = request
        var assignments: [OriginalDepartureAssignment] = []
        for level in 0...maximumHouseLevelIndex {
            guard remaining > 0 else { break }
            for house in houses {
                guard remaining > 0,
                      house.houseLevelIndex == level,
                      house.residentCount > 0 else {
                    continue
                }
                let batch = min(
                    maximumBatchSize,
                    min(house.residentCount, remaining)
                )
                guard batch > 0 else { continue }
                assignments.append(.init(
                    houseVectorIndex: house.houseVectorIndex,
                    houseLevelIndex: level,
                    peopleCount: batch
                ))
                remaining -= batch
            }
        }
        return .init(assignments: assignments, unassigned: remaining)
    }
}

/// Explicit inputs for the downstream `FUN_004ADED0 @ 0x4ADED0` departure
/// writer. The source receives a previously selected positive batch and the
/// already-resolved return values of the house class predicates and figure
/// allocator; those runtime object lookups are intentionally not inferred
/// from Native `ResidentialUnit` state.
public struct OriginalDepartureWriteInput: Sendable, Hashable, Codable {
    public let houseResidents: Int
    public let peopleCount: Int
    public let isCommonHouseType: Bool
    public let isEliteHouseType: Bool
    public let houseCleanupCallbackPassed: Bool
    public let figureAllocationSucceeded: Bool

    public init(
        houseResidents: Int,
        peopleCount: Int,
        isCommonHouseType: Bool,
        isEliteHouseType: Bool,
        houseCleanupCallbackPassed: Bool = false,
        figureAllocationSucceeded: Bool = false
    ) {
        self.houseResidents = houseResidents
        self.peopleCount = peopleCount
        self.isCommonHouseType = isCommonHouseType
        self.isEliteHouseType = isEliteHouseType
        self.houseCleanupCallbackPassed = houseCleanupCallbackPassed
        self.figureAllocationSucceeded = figureAllocationSucceeded
    }
}

/// Field-level result of `FUN_004ADED0`. The population-ledger delta is kept
/// separate from the clamped house result because the source calls
/// `FUN_00591900(-peopleCount)` before it tests whether the house is exhausted.
/// A successful allocation initializes a type-`0xC` emigrant figure to state 6,
/// wait word 0, and the request byte (the source stores a signed byte).
public struct OriginalDepartureWriteResult: Sendable, Hashable, Codable {
    public let populationLedgerDelta: Int
    public let resultingResidents: Int
    public let exhaustedHouse: Bool
    public let invokedHouseCleanup: Bool
    public let resultingHouseTypeID: Int?
    public let resultingHouseLevelIndex: Int?
    public let figureSpawnAttempted: Bool
    public let figureSpawnSucceeded: Bool
    public let figureState: Int?
    public let figureWaitWord: Int?
    public let figurePeopleByte: Int?

    public init(
        populationLedgerDelta: Int,
        resultingResidents: Int,
        exhaustedHouse: Bool,
        invokedHouseCleanup: Bool,
        resultingHouseTypeID: Int?,
        resultingHouseLevelIndex: Int?,
        figureSpawnAttempted: Bool,
        figureSpawnSucceeded: Bool,
        figureState: Int?,
        figureWaitWord: Int?,
        figurePeopleByte: Int?
    ) {
        self.populationLedgerDelta = populationLedgerDelta
        self.resultingResidents = resultingResidents
        self.exhaustedHouse = exhaustedHouse
        self.invokedHouseCleanup = invokedHouseCleanup
        self.resultingHouseTypeID = resultingHouseTypeID
        self.resultingHouseLevelIndex = resultingHouseLevelIndex
        self.figureSpawnAttempted = figureSpawnAttempted
        self.figureSpawnSucceeded = figureSpawnSucceeded
        self.figureState = figureState
        self.figureWaitWord = figureWaitWord
        self.figurePeopleByte = figurePeopleByte
    }
}

/// Pure reproduction of the already-selected departure batch's writer.
/// This does not mutate Native houses, invoke the global population ledger,
/// rebuild map cells, or create a live emigrant walker. It records those
/// effects as explicit outputs so the unresolved type-`0xC` route/home
/// lifecycle cannot be replaced by a compatibility shortcut.
public enum OriginalDepartureWrite {
    public static func apply(
        _ input: OriginalDepartureWriteInput
    ) -> OriginalDepartureWriteResult {
        let residents = max(0, input.houseResidents)
        let people = max(0, input.peopleCount)
        guard people > 0 else {
            return .init(
                populationLedgerDelta: 0,
                resultingResidents: residents,
                exhaustedHouse: false,
                invokedHouseCleanup: false,
                resultingHouseTypeID: nil,
                resultingHouseLevelIndex: nil,
                figureSpawnAttempted: false,
                figureSpawnSucceeded: false,
                figureState: nil,
                figureWaitWord: nil,
                figurePeopleByte: nil
            )
        }

        let exhausted = people >= residents
        let resultingResidents = exhausted ? 0 : residents - people
        let cleanup = exhausted && input.houseCleanupCallbackPassed
        let resultingHouseTypeID: Int?
        let resultingHouseLevelIndex: Int?
        if cleanup, input.isCommonHouseType {
            resultingHouseTypeID = 3
            resultingHouseLevelIndex = 0
        } else if cleanup, input.isEliteHouseType {
            resultingHouseTypeID = 12
            resultingHouseLevelIndex = 9
        } else {
            resultingHouseTypeID = nil
            resultingHouseLevelIndex = nil
        }

        let storedFigurePeopleByte = Int(Int8(truncatingIfNeeded: people))
        return .init(
            populationLedgerDelta: -people,
            resultingResidents: resultingResidents,
            exhaustedHouse: exhausted,
            invokedHouseCleanup: cleanup,
            resultingHouseTypeID: resultingHouseTypeID,
            resultingHouseLevelIndex: resultingHouseLevelIndex,
            figureSpawnAttempted: true,
            figureSpawnSucceeded: input.figureAllocationSucceeded,
            figureState: input.figureAllocationSucceeded ? 6 : nil,
            figureWaitWord: input.figureAllocationSucceeded ? 0 : nil,
            figurePeopleByte: input.figureAllocationSucceeded ? storedFigurePeopleByte : nil
        )
    }
}

/// A physical immigrant figure (model 11) walking from the authored land
/// entry to a house. Implements the recovered `FUN_004C9FD0` state machine
/// (`6` wait → `7` walk → `8` arrive) mapped onto the Native 30-day clock
/// bridge: each Native day runs `floor(day×816/30) − floor((day−1)×816/30)`
/// original figure updates, and movement follows the recovered 1/1/2
/// substep cadence with a 20-substep route step (initial progress 20 so the
/// first substep advances immediately, §5.2–§5.3).
public struct ImmigrantWalker: Identifiable, Sendable, Hashable, Codable {
    public static let figureID = 11
    public static let originalStepsPerMonth = 816
    public static let nativeDaysPerMonth = 30

    public enum State: Int, Sendable, Hashable, Codable {
        case waiting = 6
        case walking = 7
        case arriving = 8
    }

    public let id: Int
    public let houseID: Int
    public let peopleCount: Int
    public let entryPoint: GridPoint
    public private(set) var route: [GridPoint]
    public private(set) var routeIndex: Int
    public private(set) var state: State
    /// Original `figure+0x3e` wait word, in original simulation steps.
    public private(set) var waitStepsRemaining: Int
    /// 1/1/2 substep pattern index (0…2) and progress (initial 20).
    public private(set) var substepPatternIndex: Int
    public private(set) var substepProgress: Int
    /// Source `figure+5` animation counter. The original immigrant think
    /// increments this byte on every successful update and wraps at 12;
    /// `FUN_004D6D30` consumes it directly as the SG3 frame index. Optional
    /// keeps older saves decodable until their first update.
    public private(set) var sourceAnimationFrame: Int?
    /// Whether the last source update advanced to another route cell. This
    /// is presentation state only; it prevents interpolation while an
    /// immigrant is waiting or during a non-moving substep.
    public private(set) var movedOnLastSimulationStep: Bool?

    public var currentPoint: GridPoint {
        route.indices.contains(routeIndex) ? route[routeIndex] : entryPoint
    }

    public init(
        id: Int,
        houseID: Int,
        peopleCount: Int,
        entryPoint: GridPoint,
        route: [GridPoint],
        waitSteps: Int
    ) {
        self.id = id
        self.houseID = houseID
        self.peopleCount = max(1, peopleCount)
        self.entryPoint = entryPoint
        self.route = route
        routeIndex = 0
        state = waitSteps > 0 ? .waiting : .walking
        waitStepsRemaining = max(0, waitSteps)
        substepPatternIndex = 0
        substepProgress = 20
        sourceAnimationFrame = 0
        movedOnLastSimulationStep = false
    }

    /// Consumes one original figure update. Returns `true` when the arrival
    /// write becomes due (the update after the walker reaches the house).
    public mutating func advanceOneUpdate() -> Bool {
        // A spawned Native walker already passed the source's house/route
        // guards, so retain the source's 0…11 frame counter at this update
        // boundary for all three live states.
        sourceAnimationFrame = ((sourceAnimationFrame ?? 0) + 1) % 12
        movedOnLastSimulationStep = false
        switch state {
        case .waiting:
            waitStepsRemaining -= 1
            if waitStepsRemaining <= 0 {
                state = .walking
            }
            return false
        case .walking:
            let previousRouteIndex = routeIndex
            substepProgress += [1, 1, 2][substepPatternIndex]
            substepPatternIndex = (substepPatternIndex + 1) % 3
            while substepProgress >= 20, routeIndex < route.count - 1 {
                substepProgress -= 20
                routeIndex += 1
            }
            movedOnLastSimulationStep = routeIndex != previousRouteIndex
            if routeIndex == route.count - 1 {
                state = .arriving
            }
            return false
        case .arriving:
            return true
        }
    }
}

/// Result of an immigrant reaching its house (the `0x4CA265` occupancy write
/// is applied by the city, not by the walker).
public struct ImmigrantArrival: Sendable, Hashable, Codable {
    public let houseID: Int
    public let peopleCount: Int

    public init(houseID: Int, peopleCount: Int) {
        self.houseID = houseID
        self.peopleCount = peopleCount
    }
}

/// The field-level inputs consumed by the original type-`0xB` arrival write
/// (`FUN_004C9FD0`, `0x4CA265`).  `capacitySnapshot` is deliberately supplied
/// by the caller: it is the value returned by `FUN_0044CC80(row, 0x11)` before
/// the vacant-house `+0x230` type switch, and its table projection is not yet
/// proven in Native.  `houseInfoSettlingByte` is the raw `cHouseInfo+0x3C`
/// gate; a non-zero value suppresses the resident/population write but does
/// not suppress the preceding vacant-house conversion.
public struct OriginalImmigrantArrivalWriteInput: Sendable, Hashable, Codable {
    public let houseTypeID: Int
    public let houseResidents: Int
    public let figurePeopleCount: Int
    public let capacitySnapshot: Int
    public let houseInfoSettlingByte: Int
    /// `DAT_00D62408`; direct EN/CH scans found no writer, so shipped builds
    /// keep this false.  It remains explicit to preserve the recovered branch.
    public let typeSwitchGateNonzero: Bool

    public init(
        houseTypeID: Int,
        houseResidents: Int,
        figurePeopleCount: Int,
        capacitySnapshot: Int,
        houseInfoSettlingByte: Int = 0,
        typeSwitchGateNonzero: Bool = false
    ) {
        self.houseTypeID = houseTypeID
        self.houseResidents = max(0, houseResidents)
        self.figurePeopleCount = min(255, max(0, figurePeopleCount))
        self.capacitySnapshot = capacitySnapshot
        self.houseInfoSettlingByte = houseInfoSettlingByte
        self.typeSwitchGateNonzero = typeSwitchGateNonzero
    }
}

public struct OriginalImmigrantArrivalWriteResult: Sendable, Hashable, Codable {
    /// The `+0x230` argument selected by the source type switch.  `nil`
    /// means the switch was skipped by the (unwritten in shipped builds)
    /// `DAT_00D62408` gate or the house was already occupied.
    public let vacantConversionArgument: Int?
    /// Source building type after the optional conversion (`+0x14`).
    public let resultingHouseTypeID: Int
    /// The byte written from `figure+0x6e` after the empty-house capacity
    /// clamp.  Occupied houses intentionally keep the raw byte; the source
    /// does not repeat the capacity clamp on that path.
    public let residentWriteCount: Int
    public let residentDelta: Int
    public let resultingResidents: Int
    public let remainingCapacity: Int
    /// True when the `house+0x20` add and `FUN_00591900` call are reached.
    public let invokedPopulationWriter: Bool
    /// The arrival path clears `house+0x32` after the occupancy block even
    /// when the `cHouseInfo+0x3C` gate suppresses the add.
    public let clearedHouseLink: Bool

    public init(
        vacantConversionArgument: Int?,
        resultingHouseTypeID: Int,
        residentWriteCount: Int,
        residentDelta: Int,
        resultingResidents: Int,
        remainingCapacity: Int,
        invokedPopulationWriter: Bool,
        clearedHouseLink: Bool
    ) {
        self.vacantConversionArgument = vacantConversionArgument
        self.resultingHouseTypeID = resultingHouseTypeID
        self.residentWriteCount = residentWriteCount
        self.residentDelta = residentDelta
        self.resultingResidents = resultingResidents
        self.remainingCapacity = remainingCapacity
        self.invokedPopulationWriter = invokedPopulationWriter
        self.clearedHouseLink = clearedHouseLink
    }
}

/// Raw write set of the post-removal HouseBldg path at
/// `FUN_004681A0 @ 0x4681A0`.
///
/// The caller supplies the value already converted by the source's
/// `__ftol` instruction.  The executable passes that full integer to the
/// population-ledger decrement, but subtracts only its signed 16-bit form
/// from house `+0x20`.  It then stores the caller byte in `cHouseInfo+0x3C`,
/// arms house `+0x98` to `0x20`, clears `+0xA4`, and refreshes the map object
/// through the house registry ID at `+0xB4`.  This is a pure field contract;
/// it does not invent the unresolved incident producer or wire disease
/// walkers into Native gameplay.
public struct OriginalHouseInfoRemovalLockWrite: Sendable, Hashable, Codable {
    public let residentWordAfter: Int16
    public let populationLedgerDelta: Int
    public let cHouseInfoByte3C: UInt8
    public let countdown98: Int
    public let clearedFieldA4: Bool
    public let refreshedRegistryID: Int

    public init(
        residentWordAfter: Int16,
        populationLedgerDelta: Int,
        cHouseInfoByte3C: UInt8,
        countdown98: Int,
        clearedFieldA4: Bool,
        refreshedRegistryID: Int
    ) {
        self.residentWordAfter = residentWordAfter
        self.populationLedgerDelta = populationLedgerDelta
        self.cHouseInfoByte3C = cHouseInfoByte3C
        self.countdown98 = countdown98
        self.clearedFieldA4 = clearedFieldA4
        self.refreshedRegistryID = refreshedRegistryID
    }
}

public enum OriginalHouseInfoRemovalLock {
    public static let countdownSteps = 0x20

    /// Replays `FUN_004681A0` after its floating-point count has been
    /// converted by the caller/CPU.  No validity clamp is applied because
    /// the source performs the ledger call before the 16-bit resident write.
    public static func apply(
        residentWord: Int16,
        convertedCount: Int,
        cHouseInfoByte3C: UInt8,
        refreshedRegistryID: Int
    ) -> OriginalHouseInfoRemovalLockWrite {
        // `__ftol` returns a signed 32-bit integer in the original x86
        // build.  Normalize the caller input before applying either use so
        // oversized Swift fixture values cannot invent a wider ledger delta.
        let convertedWord = Int32(truncatingIfNeeded: convertedCount)
        let residentDeltaWord = Int16(truncatingIfNeeded: convertedWord)
        let residentWordAfter = Int16(
            truncatingIfNeeded: Int(residentWord) - Int(residentDeltaWord)
        )
        return .init(
            residentWordAfter: residentWordAfter,
            populationLedgerDelta: -Int(convertedWord),
            cHouseInfoByte3C: cHouseInfoByte3C,
            countdown98: countdownSteps,
            clearedFieldA4: true,
            refreshedRegistryID: refreshedRegistryID
        )
    }
}

/// Inputs for the original negative-remaining-capacity cleanup
/// (`FUN_004AE1A0`, daily case `0x18`).  The source consumes the signed
/// `house+0x22` short produced by the capacity refresh; the vagrant figure
/// spawn itself is intentionally represented only as a count because its
/// route/registry projection is not recovered in Native.
public struct OriginalCapacityOverflowInput: Sendable, Hashable, Codable {
    public let residents: Int
    public let remainingCapacity: Int

    public init(residents: Int, remainingCapacity: Int) {
        self.residents = max(0, residents)
        self.remainingCapacity = remainingCapacity
    }
}

public struct OriginalCapacityOverflowResult: Sendable, Hashable, Codable {
    /// Number passed to `FUN_004AE150` as the type-`0xD` vagrant count.
    public let spawnedVagrantPeople: Int
    public let resultingResidents: Int
    public let invokedVagrantSpawn: Bool

    public init(
        spawnedVagrantPeople: Int,
        resultingResidents: Int,
        invokedVagrantSpawn: Bool
    ) {
        self.spawnedVagrantPeople = spawnedVagrantPeople
        self.resultingResidents = resultingResidents
        self.invokedVagrantSpawn = invokedVagrantSpawn
    }
}

/// Campaign-level inputs the daily migration producer needs (set by the
/// runtime at mission start and each monthly advance).
public struct CampaignMigrationContext: Sendable, Hashable, Codable {
    /// Live type-2 monument goal building IDs (`kind == .monument`,
    /// `values[0]`), including 85/86 for the Great Wall special arm.
    public var monumentGoalBuildingIDs: [Int]
    /// `DAT_01312214` current normal annual wage (baseline 30).
    public var normalAnnualWage: Int
    /// `DAT_01312630` consecutive debt **months** (factor uses /12 years).
    public var consecutiveDebtMonths: Int

    public init(
        monumentGoalBuildingIDs: [Int] = [],
        normalAnnualWage: Int = 30,
        consecutiveDebtMonths: Int = 0
    ) {
        self.monumentGoalBuildingIDs = monumentGoalBuildingIDs
        self.normalAnnualWage = max(0, normalAnnualWage)
        self.consecutiveDebtMonths = max(0, consecutiveDebtMonths)
    }
}

public struct DeterministicMigrationState: Sendable, Hashable, Codable {
    public private(set) var automaticMigrationAvailability: AutomaticMigrationAvailability
    public private(set) var lastAssessment: MigrationAssessment?
    public private(set) var lastDailyImmigrants: Int
    public private(set) var currentMonthImmigrants: Int
    public private(set) var lastMonthImmigrants: Int
    /// Live immigrant figures (model 11) en route to their houses. Empty while
    /// the producer is unsupported; persisted for save/replay.
    public private(set) var immigrantWalkers: [ImmigrantWalker]
    public private(set) var nextImmigrantWalkerID: Int
    /// Original `DAT_00D62418` wait-stagger word (§5.2): `+0x32` per spawn,
    /// `−0x33` (clamped) before each assignment day.
    public private(set) var immigrantWaitGlobal: Int
    /// Recovered popularity producer state (§2–§5).
    public private(set) var popularity: Int
    public private(set) var pressure: Int
    public private(set) var arrivalCooldown: Int
    public private(set) var departureCooldown: Int
    public private(set) var arrivalRequest: Int
    public private(set) var departureRequest: Int
    public private(set) var pendingArrival: Int
    public private(set) var pendingDeparture: Int
    public private(set) var unfulfilledArrivalCarry: Int
    public private(set) var assignedToday: Int
    public private(set) var assignedThisMonth: Int
    public private(set) var neverExceeded349: Bool
    /// `DAT_01312514` worst-factor blame index (1 food … 8 repression), for
    /// advisor reasons; 0 = none.
    public private(set) var factorBlame: Int

    public init(
        automaticMigrationAvailability: AutomaticMigrationAvailability = .unsupportedOriginalProducer,
        lastAssessment: MigrationAssessment? = nil,
        lastDailyImmigrants: Int = 0,
        currentMonthImmigrants: Int = 0,
        lastMonthImmigrants: Int = 0,
        immigrantWalkers: [ImmigrantWalker] = [],
        nextImmigrantWalkerID: Int = 1,
        immigrantWaitGlobal: Int = 0,
        popularity: Int = 60,
        pressure: Int = 0,
        arrivalCooldown: Int = 0,
        departureCooldown: Int = 0,
        arrivalRequest: Int = 0,
        departureRequest: Int = 0,
        pendingArrival: Int = 0,
        pendingDeparture: Int = 0,
        unfulfilledArrivalCarry: Int = 0,
        assignedToday: Int = 0,
        assignedThisMonth: Int = 0,
        neverExceeded349: Bool = false,
        factorBlame: Int = 0
    ) {
        self.automaticMigrationAvailability = automaticMigrationAvailability
        self.lastAssessment = lastAssessment
        self.lastDailyImmigrants = max(0, lastDailyImmigrants)
        self.currentMonthImmigrants = max(0, currentMonthImmigrants)
        self.lastMonthImmigrants = max(0, lastMonthImmigrants)
        self.immigrantWalkers = immigrantWalkers
        self.nextImmigrantWalkerID = max(1, nextImmigrantWalkerID)
        self.immigrantWaitGlobal = max(0, immigrantWaitGlobal)
        self.popularity = min(100, max(0, popularity))
        self.pressure = pressure
        self.arrivalCooldown = max(0, arrivalCooldown)
        self.departureCooldown = max(0, departureCooldown)
        self.arrivalRequest = max(0, arrivalRequest)
        self.departureRequest = max(0, departureRequest)
        self.pendingArrival = max(0, pendingArrival)
        self.pendingDeparture = max(0, pendingDeparture)
        self.unfulfilledArrivalCarry = max(0, unfulfilledArrivalCarry)
        self.assignedToday = max(0, assignedToday)
        self.assignedThisMonth = max(0, assignedThisMonth)
        self.neverExceeded349 = neverExceeded349
        self.factorBlame = max(0, factorBlame)
    }

    public mutating func recordUnsupportedDay(assessment: MigrationAssessment) {
        automaticMigrationAvailability = .unsupportedOriginalProducer
        lastAssessment = assessment
        lastDailyImmigrants = 0
        currentMonthImmigrants = 0
        lastMonthImmigrants = 0
    }

    public mutating func finishMonth() {
        lastDailyImmigrants = 0
        currentMonthImmigrants = 0
        lastMonthImmigrants = 0
        // `FUN_004AC650` resets the current-month assigned/accounted counter
        // (`DAT_01311FCC`) after copying it to the executable's history slot
        // (`DAT_01312604`). Native has no recovered history-slot consumer, so
        // `assignedThisMonth` is the current-month value and must not leak
        // into the next month.
        assignedThisMonth = 0
    }

    /// Original `FUN_004AD4A0` pre-assignment stagger decrement
    /// (`DAT_00D62418 -= 0x33`, clamped at 0; §5.2).
    public mutating func advanceImmigrantWaitGlobal() {
        immigrantWaitGlobal = max(0, immigrantWaitGlobal - 0x33)
    }

    /// Advances live immigrants by one Native day's original-step budget and
    /// returns the arrivals the city must apply.
    public mutating func advanceImmigrantWalkers(
        originalStepsInDay: Int
    ) -> [ImmigrantArrival] {
        DeterministicMigration.advanceImmigrants(
            walkers: &immigrantWalkers,
            originalStepsInDay: originalStepsInDay
        )
    }

    /// Appends a spawned immigrant and applies the original
    /// `DAT_00D62418 += 0x32` stagger increment (§5.2).
    public mutating func registerImmigrantWalker(_ walker: ImmigrantWalker) {
        immigrantWalkers.append(walker)
        nextImmigrantWalkerID = max(nextImmigrantWalkerID, walker.id + 1)
        immigrantWaitGlobal += 0x32
    }

    // MARK: - Producer state mutators

    public mutating func setNeverExceeded349() {
        neverExceeded349 = true
    }

    public mutating func setPopularity(_ value: Int) {
        popularity = min(100, max(0, value))
    }

    public mutating func setPressure(_ value: Int) {
        pressure = value
    }

    public mutating func setArrivalCooldown(_ value: Int) {
        arrivalCooldown = max(0, value)
    }

    public mutating func setDepartureCooldown(_ value: Int) {
        departureCooldown = max(0, value)
    }

    public mutating func setArrivalRequest(_ value: Int) {
        arrivalRequest = max(0, value)
    }

    public mutating func setDepartureRequest(_ value: Int) {
        departureRequest = max(0, value)
    }

    public mutating func setPendingArrival(_ value: Int) {
        pendingArrival = max(0, value)
    }

    public mutating func setPendingDeparture(_ value: Int) {
        pendingDeparture = max(0, value)
    }

    public mutating func setUnfulfilledArrivalCarry(_ value: Int) {
        unfulfilledArrivalCarry = max(0, value)
    }

    public mutating func setAssignedToday(_ value: Int) {
        assignedToday = max(0, value)
    }

    public mutating func addAssignedThisMonth(_ value: Int) {
        assignedThisMonth = max(0, assignedThisMonth + value)
    }

    public mutating func recordArrivals(count: Int) {
        guard count > 0 else { return }
        lastDailyImmigrants += count
        currentMonthImmigrants += count
    }

    public mutating func setFactorBlame(_ value: Int) {
        factorBlame = max(0, value)
    }

    public mutating func setAutomaticMigrationAvailability(
        _ availability: AutomaticMigrationAvailability
    ) {
        automaticMigrationAvailability = availability
    }

    private enum CodingKeys: String, CodingKey {
        case automaticMigrationAvailability
        case lastAssessment
        case lastDailyImmigrants
        case currentMonthImmigrants
        case lastMonthImmigrants
        case immigrantWalkers
        case nextImmigrantWalkerID
        case immigrantWaitGlobal
        case popularity, pressure, arrivalCooldown, departureCooldown
        case arrivalRequest, departureRequest, pendingArrival, pendingDeparture
        case unfulfilledArrivalCarry, assignedToday, assignedThisMonth
        case neverExceeded349, factorBlame
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        automaticMigrationAvailability = try container.decodeIfPresent(
            AutomaticMigrationAvailability.self,
            forKey: .automaticMigrationAvailability
        ) ?? .unsupportedOriginalProducer
        lastAssessment = try container.decodeIfPresent(
            MigrationAssessment.self,
            forKey: .lastAssessment
        )
        lastDailyImmigrants = max(
            0,
            try container.decodeIfPresent(Int.self, forKey: .lastDailyImmigrants) ?? 0
        )
        currentMonthImmigrants = max(
            0,
            try container.decodeIfPresent(Int.self, forKey: .currentMonthImmigrants) ?? 0
        )
        lastMonthImmigrants = max(
            0,
            try container.decodeIfPresent(Int.self, forKey: .lastMonthImmigrants) ?? 0
        )
        immigrantWalkers = try container.decodeIfPresent(
            [ImmigrantWalker].self,
            forKey: .immigrantWalkers
        ) ?? []
        nextImmigrantWalkerID = max(
            1,
            try container.decodeIfPresent(Int.self, forKey: .nextImmigrantWalkerID) ?? 1
        )
        immigrantWaitGlobal = max(
            0,
            try container.decodeIfPresent(Int.self, forKey: .immigrantWaitGlobal) ?? 0
        )
        popularity = min(
            100,
            max(0, try container.decodeIfPresent(Int.self, forKey: .popularity) ?? 60)
        )
        pressure = try container.decodeIfPresent(Int.self, forKey: .pressure) ?? 0
        arrivalCooldown = max(
            0,
            try container.decodeIfPresent(Int.self, forKey: .arrivalCooldown) ?? 0
        )
        departureCooldown = max(
            0,
            try container.decodeIfPresent(Int.self, forKey: .departureCooldown) ?? 0
        )
        arrivalRequest = max(
            0,
            try container.decodeIfPresent(Int.self, forKey: .arrivalRequest) ?? 0
        )
        departureRequest = max(
            0,
            try container.decodeIfPresent(Int.self, forKey: .departureRequest) ?? 0
        )
        pendingArrival = max(
            0,
            try container.decodeIfPresent(Int.self, forKey: .pendingArrival) ?? 0
        )
        pendingDeparture = max(
            0,
            try container.decodeIfPresent(Int.self, forKey: .pendingDeparture) ?? 0
        )
        unfulfilledArrivalCarry = max(
            0,
            try container.decodeIfPresent(Int.self, forKey: .unfulfilledArrivalCarry) ?? 0
        )
        assignedToday = max(
            0,
            try container.decodeIfPresent(Int.self, forKey: .assignedToday) ?? 0
        )
        assignedThisMonth = max(
            0,
            try container.decodeIfPresent(Int.self, forKey: .assignedThisMonth) ?? 0
        )
        neverExceeded349 = try container.decodeIfPresent(
            Bool.self,
            forKey: .neverExceeded349
        ) ?? false
        factorBlame = max(
            0,
            try container.decodeIfPresent(Int.self, forKey: .factorBlame) ?? 0
        )
    }
}

/// Calendar boundary recovered around the original popularity producer.
/// These addresses and phase values are evidence metadata only; Native does
/// not invoke the unsupported migration producer from this schedule.
public enum OriginalMonthlyPopularitySchedule {
    /// Per-step simulation driver (`FUN_005371A0`).
    public static let tickDriverAddress: UInt32 = 0x005371A0
    /// 0...0x32 phase dispatcher (`FUN_004AC2B0`).
    public static let phaseDispatcherAddress: UInt32 = 0x004AC2B0
    /// 16-slice boundary (`FUN_004AC650`).
    public static let boundaryAddress: UInt32 = 0x004AC650
    /// Monthly popularity producer called from the boundary function.
    public static let popularityProducerAddress: UInt32 = 0x00591200
    /// The dispatcher calls the boundary after exactly 0x33 phase steps.
    public static let dispatcherPhaseCount = 0x33
    /// `FUN_004AC650` calls `FUN_00591200` at sub-month slices 0 and 8.
    public static let producerBoundarySlices = [0, 8]
}

/// Raw housing-status scan reached from `FUN_004AC650` after the popularity
/// producer.  The executable's `FUN_0053BB30` walks the active object vector
/// from index `1`, admits objects through the global gate and virtual `+0xB8`,
/// then classifies their signed `+0x8C` word into two integer-percentage
/// buckets.  This catalog intentionally keeps the resulting bytes raw: the
/// object-vector projection and semantic meaning of the status words are not
/// recovered for Qin maps, so Native does not feed this into live simulation.
public enum OriginalHousingStatusScan {
    public struct ObjectRecord: Sendable, Hashable, Codable {
        public let globalGateOpen: Bool
        public let populationPredicatePasses: Bool
        public let statusWord: Int

        public init(
            globalGateOpen: Bool,
            populationPredicatePasses: Bool,
            statusWord: Int
        ) {
            self.globalGateOpen = globalGateOpen
            self.populationPredicatePasses = populationPredicatePasses
            self.statusWord = statusWord
        }
    }

    public struct Result: Sendable, Hashable, Codable {
        public let compositionStatus: Int
        public let advisorStatus: Int
        public let eligibleCount: Int
        public let middleBucketPercent: Int
        public let highBucketPercent: Int

        public init(
            compositionStatus: Int,
            advisorStatus: Int,
            eligibleCount: Int,
            middleBucketPercent: Int,
            highBucketPercent: Int
        ) {
            self.compositionStatus = compositionStatus
            self.advisorStatus = advisorStatus
            self.eligibleCount = eligibleCount
            self.middleBucketPercent = middleBucketPercent
            self.highBucketPercent = highBucketPercent
        }
    }

    public static let scanAddress: UInt32 = 0x0053BB30
    public static let eventBridgeAddress: UInt32 = 0x00548B70
    public static let ratioHelperAddress: UInt32 = 0x00408BA0
    public static let sourceVectorStartIndex = 1
    public static let middleBucketLowerBound = 0x47
    public static let highBucketLowerBound = 0x51
    public static let compositionMiddlePercentBoundary = 0x33
    public static let compositionHighPercentBoundary = 0x1A
    public static let advisorMiddlePercentBoundary = 0x32
    public static let advisorHighPercentBoundary = 0x19
    public static let lowHighBucketPercentBoundary = 0x0B

    /// Mirrors `FUN_00408BA0`: integer truncation toward zero, with a zero
    /// result for a zero denominator. Counts are non-negative in the source
    /// object walk; using `Int64` here keeps the pure helper deterministic for
    /// large test inputs without changing any valid 32-bit result.
    public static func integerPercent(_ numerator: Int, _ denominator: Int) -> Int {
        guard denominator != 0 else { return 0 }
        return Int((Int64(numerator) * 100) / Int64(denominator))
    }

    /// Replays the status-byte writes in `FUN_0053BB30`. `records[0]` is
    /// intentionally skipped because the source starts at vector index `1`.
    /// A record admitted by both predicates still counts in the denominator
    /// even when its `+0x8C` word is below `0x47`.
    public static func scan(_ records: [ObjectRecord]) -> Result {
        var eligibleCount = 0
        var middleBucketCount = 0
        var highBucketCount = 0

        if records.count > sourceVectorStartIndex {
            for record in records.dropFirst(sourceVectorStartIndex)
                where record.globalGateOpen && record.populationPredicatePasses {
                eligibleCount += 1
                if record.statusWord >= highBucketLowerBound {
                    highBucketCount += 1
                } else if record.statusWord >= middleBucketLowerBound {
                    middleBucketCount += 1
                }
            }
        }

        guard eligibleCount > 0 else {
            return .init(
                compositionStatus: 0x17,
                advisorStatus: 0x98,
                eligibleCount: 0,
                middleBucketPercent: 0,
                highBucketPercent: 0
            )
        }

        let middlePercent = integerPercent(middleBucketCount, eligibleCount)
        let highPercent = integerPercent(highBucketCount, eligibleCount)
        let composition: Int
        if middlePercent < compositionMiddlePercentBoundary {
            if highPercent < compositionHighPercentBoundary {
                composition = highPercent < lowHighBucketPercentBoundary ? 0x16 : 0x15
            } else {
                composition = 0x13
            }
        } else {
            composition = 0x12
        }

        let advisor: Int
        if middlePercent > advisorMiddlePercentBoundary {
            advisor = 0x93
        } else if highPercent > advisorHighPercentBoundary {
            advisor = 0x94
        } else {
            advisor = highPercent < lowHighBucketPercentBoundary ? 0x97 : 0x95
        }
        return .init(
            compositionStatus: composition,
            advisorStatus: advisor,
            eligibleCount: eligibleCount,
            middleBucketPercent: middlePercent,
            highBucketPercent: highPercent
        )
    }

    /// Mirrors `FUN_00548B70`'s raw event dispatch. Statuses `0x97` and
    /// `0x98` emit only when they differ from the prior advisor status; the
    /// other four statuses always dispatch their corresponding event ID.
    public static func eventID(previousAdvisorStatus: Int, currentAdvisorStatus: Int) -> Int? {
        switch currentAdvisorStatus {
        case 0x93: return 0xD6
        case 0x94: return 0xD7
        case 0x95: return 0xD8
        case 0x96: return 0xD9
        case 0x97: return previousAdvisorStatus == 0x97 ? nil : 0xDA
        case 0x98: return previousAdvisorStatus == 0x98 ? nil : 0xDB
        default: return nil
        }
    }
}

/// Direct canonical-PE callsites for the placement-time `+0xA0` producer
/// `FUN_0042B250`.  The list is evidence metadata only; the map-load pass has
/// no direct callsite and Native does not recompute this value for Qin maps.
public enum OriginalFengShuiPlacementProducer {
    public static let directCallSiteAddresses: [UInt32] = [
        0x004150A9, 0x0042B55D, 0x004B2516, 0x004B2882,
        0x00540F34, 0x00542B16, 0x00544C53
    ]
}

public enum DeterministicMigration {
    /// Direct canonical-PE callsites for `FUN_00591670 @ 0x591670`.
    /// `0x59165B` is the conditional wrapper `FUN_00591650`; the other three
    /// sites are the monthly popularity producer, its diagnostic renderer,
    /// and the advisor display. This is evidence metadata only and does not
    /// enable the unresolved Qin object-vector projection.
    public static let fengShuiConsumerDirectCallSiteAddresses: [UInt32] = [
        0x0053C078, 0x0059129E, 0x0059165B, 0x005B8C08
    ]

    /// Replays the source's negative spare-room cleanup.  For a negative
    /// `house+0x22`, the executable spawns that many type-`0xD` vagrant people
    /// and subtracts the overflow from residents, but clamps the result to
    /// **one** rather than zero when the overflow is at least the resident
    /// count.  Non-negative spare room is a no-op.
    public static func originalCapacityOverflowReconciliation(
        _ input: OriginalCapacityOverflowInput
    ) -> OriginalCapacityOverflowResult {
        guard input.remainingCapacity < 0 else {
            return .init(
                spawnedVagrantPeople: 0,
                resultingResidents: input.residents,
                invokedVagrantSpawn: false
            )
        }
        let overflow = -input.remainingCapacity
        let resultingResidents = overflow < input.residents
            ? input.residents - overflow
            : 1
        return .init(
            spawnedVagrantPeople: overflow,
            resultingResidents: resultingResidents,
            invokedVagrantSpawn: true
        )
    }

    /// Resolves the capacity snapshot read by the immigrant arrival writer.
    /// The source uses the special row `0xB` for an Unoccupied Elite house;
    /// every other house uses its raw `house+0x16` level index.  This is the
    /// table read before `+0x230`, so it intentionally differs from the
    /// post-arrival Native house level.
    public static func originalImmigrantCapacitySnapshot(
        houseTypeID: Int,
        houseLevelIndex: Int,
        models: BuildingModelTable,
        difficulty: GameDifficulty = .normal
    ) -> Int? {
        let sourceRow = houseTypeID == 0xB ? 0xB : houseLevelIndex
        return models.originalHouseCapacity(
            sourceRow: sourceRow,
            difficulty: difficulty
        )
    }

    /// Inputs for the original daily capacity refresh (`FUN_004AD3D0`,
    /// calendar case `0x16`). `houseAccessValue` is the already-resolved
    /// signed `house+0x24` short; the map/flood producer that supplies it is
    /// intentionally outside this contract. `cHouseInfoSettlingByte` is the
    /// raw `+0x3C` byte returned by the house `+0x1E4` callback.
    public struct OriginalCapacityRefreshInput: Sendable, Hashable, Codable {
        public let houseTypeID: Int
        public let houseLevelIndex: Int
        public let houseResidents: Int
        public let houseAccessValue: Int
        public let cHouseInfoSettlingByte: Int
        public let previousHighWater: Int

        public init(
            houseTypeID: Int,
            houseLevelIndex: Int,
            houseResidents: Int,
            houseAccessValue: Int,
            cHouseInfoSettlingByte: Int = 0,
            previousHighWater: Int = 0
        ) {
            self.houseTypeID = houseTypeID
            self.houseLevelIndex = houseLevelIndex
            self.houseResidents = max(0, houseResidents)
            self.houseAccessValue = houseAccessValue
            self.cHouseInfoSettlingByte = cHouseInfoSettlingByte
            self.previousHighWater = max(0, previousHighWater)
        }
    }

    /// Field-level result of one original capacity refresh. The source first
    /// clears `house+0x22`; only a positive `house+0x24` enters the table read.
    /// A non-zero cHouseInfo `+0x3C` substitutes current residents for the
    /// capacity contribution, then writes `capacity - residents` and raises
    /// the `house+0x26` high-water word when needed.
    public struct OriginalCapacityRefreshResult: Sendable, Hashable, Codable {
        public let included: Bool
        public let capacityContribution: Int
        public let residentContribution: Int
        public let remainingCapacity: Int
        public let highWater: Int

        public init(
            included: Bool,
            capacityContribution: Int,
            residentContribution: Int,
            remainingCapacity: Int,
            highWater: Int
        ) {
            self.included = included
            self.capacityContribution = capacityContribution
            self.residentContribution = residentContribution
            self.remainingCapacity = remainingCapacity
            self.highWater = highWater
        }
    }

    /// Replays the recovered arithmetic of `FUN_004AD3D0` for an already
    /// resolved house-access value and authored capacity table. It does not
    /// synthesize the `DAT_01391FE0` flood or cHouseInfo callback.
    public static func originalCapacityRefresh(
        _ input: OriginalCapacityRefreshInput,
        models: BuildingModelTable,
        difficulty: GameDifficulty = .normal
    ) -> OriginalCapacityRefreshResult? {
        guard input.houseAccessValue > 0 else {
            return .init(
                included: false,
                capacityContribution: 0,
                residentContribution: 0,
                remainingCapacity: 0,
                highWater: input.previousHighWater
            )
        }
        guard let capacity = originalImmigrantCapacitySnapshot(
            houseTypeID: input.houseTypeID,
            houseLevelIndex: input.houseLevelIndex,
            models: models,
            difficulty: difficulty
        ) else {
            return nil
        }

        let residents = input.houseResidents
        let effectiveCapacity = input.cHouseInfoSettlingByte == 0
            ? capacity
            : residents
        return .init(
            included: true,
            capacityContribution: effectiveCapacity,
            residentContribution: effectiveCapacity - residents,
            remainingCapacity: effectiveCapacity - residents,
            highWater: max(input.previousHighWater, residents)
        )
    }

    /// Replays the confirmed state-8 occupancy write of `FUN_004C9FD0`.
    ///
    /// The source computes capacity before the vacant-house switch.  For an
    /// empty house it clamps the figure byte to that snapshot, then calls the
    /// house vtable `+0x230` (`3` for common type IDs 2…10, `0xD` for the
    /// remaining supported house types) unless `DAT_00D62408` is non-zero.
    /// The later `cHouseInfo+0x3C` gate suppresses only the resident add and
    /// population writer; the house-link clear is unconditional.  Occupied
    /// houses use the raw figure byte without a second capacity clamp.  This
    /// helper keeps explicit raw inputs because the complete `cHouseInfo`
    /// mapping and global population/high-water side effects are not yet
    /// recovered, even though the capacity-table projection is now wired.
    public static func originalImmigrantArrivalWrite(
        _ input: OriginalImmigrantArrivalWriteInput
    ) -> OriginalImmigrantArrivalWriteResult {
        let empty = input.houseResidents == 0
        let conversionArgument: Int?
        let resultingType: Int
        if empty, !input.typeSwitchGateNonzero {
            let common = (2...10).contains(input.houseTypeID)
            conversionArgument = common ? 3 : 0xD
            resultingType = conversionArgument ?? input.houseTypeID
        } else {
            conversionArgument = nil
            resultingType = input.houseTypeID
        }

        let writeCount: Int
        if empty {
            writeCount = min(
                input.figurePeopleCount,
                max(0, input.capacitySnapshot)
            )
        } else {
            // The executable only performs the capacity clamp in the
            // `house+0x20 == 0` branch.
            writeCount = input.figurePeopleCount
        }

        let writerReached = input.houseInfoSettlingByte == 0
        let delta = writerReached ? writeCount : 0
        return OriginalImmigrantArrivalWriteResult(
            vacantConversionArgument: conversionArgument,
            resultingHouseTypeID: resultingType,
            residentWriteCount: writeCount,
            residentDelta: delta,
            resultingResidents: input.houseResidents + delta,
            remainingCapacity: input.capacitySnapshot - input.houseResidents - delta,
            invokedPopulationWriter: writerReached,
            clearedHouseLink: true
        )
    }

    /// One explicitly resolved house record consumed by the original food
    /// popularity walk (`FUN_00590F30`).  The raw quality and model columns
    /// are supplied by the caller because Native has no proven projection for
    /// `cHouseInfo+0x36` or the original house dword at `+0x8C`.
    public struct OriginalFoodPopularityHouse: Sendable, Hashable, Codable {
        public let vectorIndex: Int
        public let isLive: Bool
        public let passesHouseClass: Bool
        public let residents: Int
        public let isEliteClass: Bool
        public let foodRequired: Int
        public let rawFoodQuality: Int
        public let foodShortageStreak: Int
        public let crimeValue: Int
        public let crimeIncrement: Int
        public let crimeBase: Int

        public init(
            vectorIndex: Int,
            isLive: Bool = true,
            passesHouseClass: Bool = true,
            residents: Int,
            isEliteClass: Bool,
            foodRequired: Int,
            rawFoodQuality: Int,
            foodShortageStreak: Int = 0,
            crimeValue: Int = 0,
            crimeIncrement: Int = 0,
            crimeBase: Int = 0
        ) {
            self.vectorIndex = vectorIndex
            self.isLive = isLive
            self.passesHouseClass = passesHouseClass
            self.residents = residents
            self.isEliteClass = isEliteClass
            self.foodRequired = foodRequired
            self.rawFoodQuality = rawFoodQuality
            self.foodShortageStreak = min(3, max(0, foodShortageStreak))
            self.crimeValue = crimeValue
            self.crimeIncrement = crimeIncrement
            self.crimeBase = crimeBase
        }
    }

    public struct OriginalFoodPopularityHouseResult: Sendable, Hashable, Codable {
        public let vectorIndex: Int
        public let crimeValue: Int
        public let foodShortageStreak: Int
        public let foodScore: Int?

        public init(
            vectorIndex: Int,
            crimeValue: Int,
            foodShortageStreak: Int,
            foodScore: Int?
        ) {
            self.vectorIndex = vectorIndex
            self.crimeValue = crimeValue
            self.foodShortageStreak = foodShortageStreak
            self.foodScore = foodScore
        }
    }

    public struct OriginalFoodPopularityWalkOutcome: Sendable, Hashable, Codable {
        public let popularityTerm: Int
        public let houseResults: [OriginalFoodPopularityHouseResult]

        public init(
            popularityTerm: Int,
            houseResults: [OriginalFoodPopularityHouseResult]
        ) {
            self.popularityTerm = popularityTerm
            self.houseResults = houseResults
        }
    }

    /// Reproduces the recovered food term of `FUN_00590F30` for already
    /// resolved house records.  It preserves runtime vector order, the raw
    /// quality comparison, the three-step shortage penalty, the elite-only
    /// crime-field skip, and the strict half-away-from-zero mean adjustment.
    /// No Native food or cHouseInfo field is inferred by this helper.
    public static func originalFoodPopularityWalk(
        houses: [OriginalFoodPopularityHouse],
        popularitySnapshot: Int,
        population: Int,
        neverExceeded349: Bool
    ) -> OriginalFoodPopularityWalkOutcome {
        var sum = 0
        var count = 0
        var results: [OriginalFoodPopularityHouseResult] = []
        for house in houses {
            guard house.isLive, house.passesHouseClass else { continue }
            if house.residents == 0 {
                results.append(.init(
                    vectorIndex: house.vectorIndex,
                    crimeValue: 0,
                    foodShortageStreak: house.foodShortageStreak,
                    foodScore: nil
                ))
                continue
            }

            var crime = house.crimeValue
            if !house.isEliteClass {
                crime += house.crimeIncrement + (40 - popularitySnapshot) / 2
                crime = max(house.crimeBase, min(100, crime))
            }

            guard house.foodRequired > 0 else {
                results.append(.init(
                    vectorIndex: house.vectorIndex,
                    crimeValue: crime,
                    foodShortageStreak: 0,
                    foodScore: nil
                ))
                continue
            }

            let score: Int
            let streak: Int
            if house.rawFoodQuality >= house.foodRequired {
                streak = 0
                score = 2
            } else {
                streak = min(3, house.foodShortageStreak + 1)
                score = streak == 1 ? -1 : (streak == 2 ? -2 : -3)
            }
            sum += score
            count += 1
            results.append(.init(
                vectorIndex: house.vectorIndex,
                crimeValue: crime,
                foodShortageStreak: streak,
                foodScore: score
            ))
        }

        guard count > 0 else {
            return .init(popularityTerm: 0, houseResults: results)
        }
        var mean = sum / count
        let remainder = abs(sum % count)
        if remainder * 2 > count {
            mean += sum < 0 ? -1 : 1
        }
        if mean < 0, population < 350, !neverExceeded349 {
            mean = 0
        }
        return .init(popularityTerm: mean, houseResults: results)
    }

    /// Raw festival popularity adjustment recovered from `FUN_0048EA40`
    /// (`0x48EA40`) and `FUN_0048EAF0` (`0x48EAF0`). The executable keeps
    /// this outside the regular `FUN_00591200` factor sum: the positive phase
    /// contributes `12` when the current season differs from the festival
    /// season and `18` when it matches; the negative phase contributes `-18`
    /// on a matching season and `-12` otherwise. The negative phase is gated
    /// by the original population/qualification checks, which are represented
    /// explicitly here rather than inferred from Native event state.
    public static func originalFestivalPositiveEffect(
        seasonMatches: Bool
    ) -> Int {
        seasonMatches ? 18 : 12
    }

    /// Returns the exact negative festival adjustment, or `0` when the
    /// original `FUN_0048EAF0` gate is closed. `populationAbove350` must be
    /// supplied by the caller from the source population word; the three
    /// qualification bytes correspond to `DAT_00C5CE7E/80/82`.
    public static func originalFestivalNegativeEffect(
        seasonMatches: Bool,
        populationAbove350: Bool,
        anyQualificationFlag: Bool
    ) -> Int {
        guard populationAbove350, anyQualificationFlag else { return 0 }
        return seasonMatches ? -18 : -12
    }

    /// Returns the remaining-capacity value consumed by the original
    /// `FUN_004AD3D0`/`FUN_004ADA10` assignment walk.  An unoccupied elite
    /// building (original model 11) uses the next house-level capacity while
    /// it is still vacant: the executable adds one to `house+0x16` before
    /// resolving the model table, then the arrival writer converts 11→13
    /// (`houseLevelID` 8→10) on first occupancy.  This is distinct from the
    /// post-arrival level-10 capacity and preserves the source's ability to
    /// spawn a first immigrant batch into a zero-capacity placeholder.
    public static func assignmentRemainingCapacity(
        houseLevelID: Int,
        vacantTypeID: Int?,
        residents: Int,
        footprintMultiplier: Int,
        settlingLock: Int,
        models: BuildingModelTable
    ) -> Int {
        guard settlingLock == 0 else { return 0 }
        let effectiveLevel = vacantTypeID == 11 ? houseLevelID + 1 : houseLevelID
        let capacity = models[houseLevelID: effectiveLevel]?.populationCapacity ?? 0
        return max(
            0,
            capacity * max(1, footprintMultiplier) - max(0, residents)
        )
    }

    /// Inputs observed by the original house access/flood refresher
    /// (`FUN_00518A50`, house vtable `+0x84`).  The candidate scan itself is
    /// deliberately kept outside this helper: its map/object flag semantics
    /// are not isomorphic to Native state (§5.7).
    public struct HouseAccessRefreshInput: Sendable, Hashable, Codable {
        public let candidateFound: Bool
        public let selectedAccessPoint: GridPoint?
        public let floodDepth: Int?
        public let retryCount: Int
        /// House `+0x14` short, used only by the zero-flood branch.
        public let houseType: Int
        /// House `+0x20` short, used by the retry and zero-flood branches.
        public let houseField20: Int
        /// Value pointed to by the callback's second argument (`param_2`).
        public let externalValue: Int
        /// House `+0x10` value copied into the external pointer on the
        /// zero-flood branch when its gate is open.
        public let externalFallbackValue: Int

        public init(
            candidateFound: Bool,
            selectedAccessPoint: GridPoint? = nil,
            floodDepth: Int? = nil,
            retryCount: Int = 0,
            houseType: Int = 0,
            houseField20: Int = 0,
            externalValue: Int = 0,
            externalFallbackValue: Int = 0
        ) {
            self.candidateFound = candidateFound
            self.selectedAccessPoint = selectedAccessPoint
            self.floodDepth = floodDepth
            self.retryCount = retryCount
            self.houseType = houseType
            self.houseField20 = houseField20
            self.externalValue = externalValue
            self.externalFallbackValue = externalFallbackValue
        }
    }

    /// Exact field-level result of one `FUN_00518A50` invocation, without
    /// performing the unresolved `FUN_004AE150` side effect.  `ready` is the
    /// original boolean return (`short house+0x28 == 0`), while
    /// `qualityDepth` is the value written to house `+0x24`.
    public struct HouseAccessRefreshOutcome: Sendable, Hashable, Codable {
        public let ready: Bool
        public let retryCount: Int
        public let qualityDepth: Int
        public let selectedAccessPoint: GridPoint?
        public let externalValue: Int
        public let stateTransitionedToTwo: Bool
        public let repairRequested: Bool

        public init(
            ready: Bool,
            retryCount: Int,
            qualityDepth: Int,
            selectedAccessPoint: GridPoint?,
            externalValue: Int,
            stateTransitionedToTwo: Bool,
            repairRequested: Bool
        ) {
            self.ready = ready
            self.retryCount = retryCount
            self.qualityDepth = qualityDepth
            self.selectedAccessPoint = selectedAccessPoint
            self.externalValue = externalValue
            self.stateTransitionedToTwo = stateTransitionedToTwo
            self.repairRequested = repairRequested
        }
    }

    /// Reproduces the branch and field updates of `FUN_00518A50` exactly for
    /// already-resolved candidate/flood inputs.  `floodDepth == nil` is
    /// treated as the original zero table value.  The helper intentionally
    /// does not implement candidate selection or `FUN_004AE150`; those remain
    /// unsupported until the original map/object mapping is recovered.
    public static func refreshHouseAccess(
        _ input: HouseAccessRefreshInput
    ) -> HouseAccessRefreshOutcome {
        // The executable stores this counter as a signed 16-bit short. Keep
        // its wraparound semantics instead of widening it to an unbounded
        // Native integer.
        var retry = Int(Int16(truncatingIfNeeded: input.retryCount))
        func incrementShort(_ value: Int) -> Int {
            Int(Int16(bitPattern: UInt16(truncatingIfNeeded: value) &+ 1))
        }
        var externalValue = input.externalValue
        guard input.candidateFound else {
            retry = incrementShort(retry)
            let repairRequested = retry > 4 && input.houseField20 != 0
            if repairRequested {
                retry = 0
            }
            return HouseAccessRefreshOutcome(
                ready: retry == 0,
                retryCount: retry,
                qualityDepth: 0,
                selectedAccessPoint: nil,
                externalValue: externalValue,
                stateTransitionedToTwo: repairRequested || retry > 4,
                repairRequested: repairRequested
            )
        }

        let depth = max(0, input.floodDepth ?? 0)
        if depth > 0 {
            return HouseAccessRefreshOutcome(
                ready: true,
                retryCount: 0,
                qualityDepth: depth,
                selectedAccessPoint: input.selectedAccessPoint,
                externalValue: externalValue,
                stateTransitionedToTwo: false,
                repairRequested: false
            )
        }

        let specialZeroFlood = input.houseType == 2 && input.houseField20 == 0
        if retry == 0 && (specialZeroFlood || externalValue == 0) {
            externalValue = input.externalFallbackValue
        }
        retry = incrementShort(retry)
        let exhausted = retry > 8
        if exhausted {
            retry = 0
        }
        return HouseAccessRefreshOutcome(
            ready: exhausted,
            retryCount: retry,
            qualityDepth: 0,
            selectedAccessPoint: input.selectedAccessPoint,
            externalValue: externalValue,
            stateTransitionedToTwo: exhausted && specialZeroFlood,
            repairRequested: false
        )
    }

    /// One explicit row from the original `FUN_004BAF40` candidate scan.
    /// `offset` is the raw perimeter-table offset.  When an occupied map
    /// object accepts its `+0xD0` adjustment, `adjustedOffset` is the cell
    /// tested by the ranked pass; the fallback pass deliberately uses the
    /// raw offset, matching the executable's second loop.
    public struct HouseAccessCandidate: Sendable, Hashable, Codable {
        public let offset: GridPoint
        public let adjustedOffset: GridPoint?
        public let objectCallbackAllowed: Bool
        public let terrainFlags: UInt16
        public let floodDepth: Int
        /// Component rank from the recovered ten-entry priority table.  A
        /// missing entry is represented by `nil` and has the executable's
        /// sentinel rank 11.
        public let componentRank: Int?

        public init(
            offset: GridPoint,
            adjustedOffset: GridPoint? = nil,
            objectCallbackAllowed: Bool = true,
            terrainFlags: UInt16 = 0,
            floodDepth: Int = 0,
            componentRank: Int? = nil
        ) {
            self.offset = offset
            self.adjustedOffset = adjustedOffset
            self.objectCallbackAllowed = objectCallbackAllowed
            self.terrainFlags = terrainFlags
            self.floodDepth = floodDepth
            self.componentRank = componentRank
        }
    }

    /// Exact result of the generic object `+0xD0` callback used by
    /// `FUN_004BAF40` (and the related rectangular `FUN_004BA370` scan).
    /// The executable passes a linear map offset and lets the object adjust
    /// it only for Grand Way/Imperial Way; this helper keeps that callback
    /// separate from the unresolved object registry and map-cell projection.
    public struct HouseAccessObjectCallbackOutcome: Sendable, Hashable, Codable {
        /// The callback's raw return: `-1` rejects the candidate, `0` accepts
        /// the original offset, and `1` accepts the adjusted offset.
        public let callbackReturn: Int
        public let adjustedLinearOffset: Int

        public var accepted: Bool { callbackReturn != -1 }

        public init(callbackReturn: Int, adjustedLinearOffset: Int) {
            self.callbackReturn = callbackReturn
            self.adjustedLinearOffset = adjustedLinearOffset
        }
    }

    /// Models `FUN_00426D80 @ 0x426D80` and its
    /// `FUN_00415700`/`FUN_00420EB0` callees.  `terrainFlags` and
    /// `roadDirectionByte` are the raw per-cell bytes read by the original
    /// executable.  The canonical map row stride is `0xE4` (228); callers
    /// must not use this helper as a Native-coordinate projection.
    public static func houseAccessObjectCallback(
        modelID: Int,
        linearOffset: Int,
        terrainFlags: UInt8,
        roadDirectionByte: UInt8
    ) -> HouseAccessObjectCallbackOutcome {
        let rejectedByModelPredicate = modelID == 0x7E
            || [0xE7, 0x5B, 0x5A, 0x59, 0xE8, 0x6A, 0x69, 0x68]
                .contains(modelID)
        guard !rejectedByModelPredicate else {
            return HouseAccessObjectCallbackOutcome(
                callbackReturn: -1,
                adjustedLinearOffset: linearOffset
            )
        }

        guard modelID == 0x6F || modelID == 0x71 else {
            return HouseAccessObjectCallbackOutcome(
                callbackReturn: 0,
                adjustedLinearOffset: linearOffset
            )
        }

        var adjusted = linearOffset
        if terrainFlags & 0x40 == 0 {
            let direction = roadDirectionByte & 0x07
            if direction != 0 {
                adjusted += direction == 1 ? 1 : -1
            } else if roadDirectionByte & 0x38 == 0x08 {
                adjusted += 0xE4
            } else {
                adjusted -= 0xE4
            }
        }
        return HouseAccessObjectCallbackOutcome(
            callbackReturn: 1,
            adjustedLinearOffset: adjusted
        )
    }

    /// Pure control-flow model of `FUN_004BAF40`'s two candidate loops.
    ///
    /// The first loop admits an object-adjusted cell only when the `+0xD0`
    /// callback does not return `-1`, the adjusted map word has road bit
    /// `0x40` and lacks bit `0x04`, its flood value is positive, and its
    /// component rank beats the current strict minimum.  If no ranked cell
    /// qualifies, the executable's fallback loop ignores object/terrain
    /// flags and chooses the strictly smallest positive flood value over raw
    /// perimeter offsets.  Strict comparisons preserve table order on ties.
    /// This helper is research-only: callers must supply the recovered map
    /// and object projections explicitly; it is not wired into immigration.
    public static func selectHouseAccessCandidate(
        _ candidates: [HouseAccessCandidate]
    ) -> GridPoint? {
        var ranked: (point: GridPoint, rank: Int)?
        for candidate in candidates {
            guard candidate.objectCallbackAllowed,
                  candidate.floodDepth > 0,
                  candidate.terrainFlags & 0x40 != 0,
                  candidate.terrainFlags & 0x04 == 0 else { continue }
            let rank = candidate.componentRank ?? 11
            guard rank >= 0, rank < 12 else { continue }
            let point = candidate.adjustedOffset ?? candidate.offset
            if ranked == nil || rank < ranked!.rank {
                ranked = (point, rank)
            }
        }
        if let ranked { return ranked.point }

        var fallback: (point: GridPoint, depth: Int)?
        for candidate in candidates where candidate.floodDepth > 0 {
            if fallback == nil || candidate.floodDepth < fallback!.depth {
                fallback = (candidate.offset, candidate.floodDepth)
            }
        }
        return fallback?.point
    }

    /// One explicit perimeter row from the original house-access selector
    /// `FUN_004BA6F0 @ 0x4BA6F0`. `rawOffset` is the table cell relative to the
    /// house origin. When an occupied object accepts its class-specific
    /// adjustment, `testedOffset` is the adjusted cell used by the ranked
    /// pass. The function returns no point when that pass finds no candidate.
    public struct OriginalHouseAccessCandidate: Sendable, Hashable, Codable {
        public let rawOffset: GridPoint
        public let testedOffset: GridPoint
        public let objectPathAccepted: Bool
        public let terrainFlags: UInt8
        /// Rank from the ten-entry road-component table. `nil` is the
        /// executable's rank-11 sentinel for a component absent from that
        /// table and remains eligible under the original `< 12` comparison.
        public let componentRank: Int?

        public init(
            rawOffset: GridPoint,
            testedOffset: GridPoint? = nil,
            objectPathAccepted: Bool = true,
            terrainFlags: UInt8 = 0,
            componentRank: Int? = nil
        ) {
            self.rawOffset = rawOffset
            self.testedOffset = testedOffset ?? rawOffset
            self.objectPathAccepted = objectPathAccepted
            self.terrainFlags = terrainFlags
            self.componentRank = componentRank
        }
    }

    /// Pure candidate arbitration for `FUN_004BA6F0` after its perimeter rows
    /// have been resolved. The pass requires an accepted occupied-object path,
    /// road bit `0x40`, clear bit `0x04`, and a component rank strictly below
    /// the initial sentinel `12`. The original function has no flood-depth
    /// fallback: when no candidate passes these predicates it returns zero.
    /// Strict rank comparison preserves table order on equal-rank ties.
    ///
    /// This helper intentionally does not synthesize object callbacks or map
    /// flags. Callers must provide those recovered inputs explicitly, and the
    /// live Qin migration path remains fail-closed until its registry mapping
    /// is available.
    public static func selectOriginalHouseAccessCandidate(
        _ candidates: [OriginalHouseAccessCandidate]
    ) -> GridPoint? {
        var ranked: (point: GridPoint, rank: Int)?
        for candidate in candidates {
            guard candidate.objectPathAccepted,
                  candidate.terrainFlags & 0x40 != 0,
                  candidate.terrainFlags & 0x04 == 0 else { continue }
            let rank = candidate.componentRank ?? 11
            guard rank >= 0, rank < 12 else { continue }
            if ranked == nil || rank < ranked!.rank {
                ranked = (candidate.testedOffset, rank)
            }
        }
        return ranked?.point
    }

    /// One object-vector row consumed by `FUN_004ADD60 @ 0x4ADD60`, the
    /// nearest-house selector used by the figure state path.  All five house
    /// words are signed 16-bit fields in the executable: `accessValue` is
    /// `+0x24`, `remainingCapacity` is `+0x22`, `linkedFigureID` is `+0x32`,
    /// and `rawDistancePoint` contains the two shorts read from `+0x28` and
    /// `+0x0C` for `FUN_00408BC0`.  The latter names describe the exact source
    /// reads only; they do not assert a Native coordinate or semantic mapping.
    public struct OriginalImmigrantHouseCandidate: Sendable, Hashable, Codable {
        public let vectorIndex: Int
        public let houseCallbackAllowed: Bool
        public let accessValue: Int
        public let remainingCapacity: Int
        public let linkedFigureID: Int
        public let rawDistancePoint: GridPoint

        public init(
            vectorIndex: Int,
            houseCallbackAllowed: Bool = true,
            accessValue: Int,
            remainingCapacity: Int,
            linkedFigureID: Int = 0,
            rawDistancePoint: GridPoint
        ) {
            self.vectorIndex = vectorIndex
            self.houseCallbackAllowed = houseCallbackAllowed
            self.accessValue = Int(Int16(truncatingIfNeeded: accessValue))
            self.remainingCapacity = Int(Int16(truncatingIfNeeded: remainingCapacity))
            self.linkedFigureID = Int(Int16(truncatingIfNeeded: linkedFigureID))
            self.rawDistancePoint = GridPoint(
                x: Int(Int16(truncatingIfNeeded: rawDistancePoint.x)),
                y: Int(Int16(truncatingIfNeeded: rawDistancePoint.y))
            )
        }
    }

    /// Reproduces the pure arbitration in `FUN_004ADD60 @ 0x4ADD60`.
    ///
    /// The caller supplies the global `FUN_00426D10(0)` gate and the house
    /// vtable `+0xB8` result for each object.  A candidate must then have
    /// positive signed-short `+0x24` and `+0x22` values and a zero signed-short
    /// `+0x32` link.  `FUN_00408BC0 @ 0x408BC0` ranks by Chebyshev distance
    /// (`max(abs(dx), abs(dy))`) against the two raw shorts.  The initial
    /// distance sentinel is `1000` and the comparison is strict, so distances
    /// of 1000 or more are rejected and the first equal-distance row wins.
    /// A zero source return is represented as `nil`; vector indices are
    /// 1-based because the executable starts its object walk at index 1.
    /// This helper does not project Native objects or enable migration.
    public static func selectOriginalImmigrantHouse(
        from point: GridPoint,
        globalGateOpen: Bool,
        candidates: [OriginalImmigrantHouseCandidate]
    ) -> Int? {
        guard globalGateOpen else { return nil }

        var bestDistance = 1000
        var selected: Int?
        for candidate in candidates where candidate.vectorIndex > 0 {
            guard candidate.houseCallbackAllowed,
                  candidate.accessValue > 0,
                  candidate.remainingCapacity > 0,
                  candidate.linkedFigureID == 0 else { continue }

            let distance = max(
                abs(candidate.rawDistancePoint.x - point.x),
                abs(candidate.rawDistancePoint.y - point.y)
            )
            guard distance < bestDistance else { continue }
            bestDistance = distance
            selected = candidate.vectorIndex
        }
        return selected
    }

    /// Recovered land-entry flood pass mask (`FUN_005AE240`, §10.4):
    /// `0x4 | 0x8 | 0x10 | 0x20 | 0x40 | 0x100 | 0x200 | 0x800`. Against the
    /// recovered primary-cache write domain, the effectively produced pass
    /// bits are road `0x4`, bare/elevation land `0x10`/`0x20`, road-on-
    /// elevation `0x100`, and ferry links `0x200`/`0x800` (`0x8`/`0x40` have
    /// no producer in the canonical build).
    public static let landEntryFloodPassMask: UInt16 = 0xB7C

    /// Observes Native road-adjacent vacant housing without inventing
    /// arrivals, departures, popularity, or restriction reasons. This filter
    /// is not a recovered mapping of original `house+0x24`.
    public static func observeHousing(
        houses: [ResidentialUnit],
        roadNetwork: RoadNetwork,
        models: BuildingModelTable
    ) -> MigrationAssessment {
        let eligible = houses
            .filter { house in
                guard let location = house.location,
                      house.residents < house.capacity(using: models) else { return false }
                let buildingID = house.houseLevelID + 3
                let footprint = OriginalBuildingFootprintCatalog
                    .footprint(forBuildingID: buildingID)
                    ?? BuildingFootprint(width: 1, height: 1)
                let occupied = Set(footprint.points(at: location))
                return footprint.points(at: location)
                    .flatMap(RoadServiceCoverage.orthogonalNeighbors(of:))
                    .contains {
                        !occupied.contains($0) && roadNetwork.contains($0)
                    }
            }
            .sorted { $0.id < $1.id }
        let availableCapacity = eligible.reduce(0) {
            $0 + max(0, $1.capacity(using: models) - $1.residents)
        }
        return MigrationAssessment(
            eligibleHouseIDs: eligible.map(\.id),
            availableCapacity: availableCapacity,
            unemploymentPercent: 0,
            plannedImmigrants: 0,
            blockReason: nil
        )
    }

    /// Original land-entry flood (`FUN_005AE140` → `FUN_005AE240`, §10.4):
    /// 4-neighbour expansion in N/E/S/W order from the authored land entry;
    /// a neighbour passes iff its **own** main derived cache word has a
    /// nonzero intersection with `landEntryFloodPassMask`; depths are
    /// `n+1`; unreached cells stay `nil`. This is the recovered source of
    /// original `house+0x24` (reachability from the immigrant entry road),
    /// not a road-adjacency test.
    public static func landEntryFloodDepths(
        width: Int,
        height: Int,
        primaryPassability: [UInt16],
        seed: GridPoint
    ) -> [Int?] {
        guard width > 0, height > 0,
              primaryPassability.count == width * height,
              seed.x >= 0, seed.x < width,
              seed.y >= 0, seed.y < height else {
            return []
        }
        var depths = [Int?](repeating: nil, count: width * height)
        var queue: [GridPoint] = [seed]
        var head = 0
        depths[seed.y * width + seed.x] = 1
        let directions: [(dx: Int, dy: Int)] = [(0, -1), (1, 0), (0, 1), (-1, 0)]
        while head < queue.count {
            let point = queue[head]
            head += 1
            let nextDepth = (depths[point.y * width + point.x] ?? 0) + 1
            for direction in directions {
                let next = GridPoint(
                    x: point.x + direction.dx,
                    y: point.y + direction.dy
                )
                guard next.x >= 0, next.x < width,
                      next.y >= 0, next.y < height else {
                    continue
                }
                let index = next.y * width + next.x
                guard depths[index] == nil,
                      primaryPassability[index] & Self.landEntryFloodPassMask != 0 else {
                    continue
                }
                depths[index] = nextDepth
                queue.append(next)
            }
        }
        return depths
    }

    /// Native-day bridge: the original month is 816 simulation steps split
    /// across the 30-day compatibility clock as
    /// `floor(day×816/30) − floor((day−1)×816/30)` (27/28 alternating).
    public static func originalStepsInDay(_ day: Int) -> Int {
        let clamped = max(1, day)
        return clamped * ImmigrantWalker.originalStepsPerMonth
            / ImmigrantWalker.nativeDaysPerMonth
            - (clamped - 1) * ImmigrantWalker.originalStepsPerMonth
                / ImmigrantWalker.nativeDaysPerMonth
    }

    /// Compatibility road access point for fixture cities that do not carry
    /// the recovered terrain/component inputs. Campaign-backed migration uses
    /// `recoveredHouseRoadAccessPoint` instead; this coordinate-sorted choice
    /// is not the executable's component-ranked arbitration.
    public static func houseRoadAccessPoint(
        houseLocation: GridPoint,
        vacantBuildingID: Int,
        roadNetwork: RoadNetwork
    ) -> GridPoint? {
        let footprint = OriginalBuildingFootprintCatalog
            .footprint(forBuildingID: vacantBuildingID)
            ?? BuildingFootprint(width: 2, height: 2)
        let occupied = footprint.points(at: houseLocation)
        return Set(occupied.flatMap(RoadServiceCoverage.orthogonalNeighbors(of:)))
            .subtracting(occupied)
            .filter(roadNetwork.contains)
            .sorted { $0.y == $1.y ? $0.x < $1.x : $0.y < $1.y }
            .first
    }

    /// Source-backed `FUN_004BA6F0` access selection for a house whose
    /// candidate cells have already been resolved to their raw coordinates.
    /// The executable walks the size-specific clockwise perimeter and chooses
    /// the lowest ranked road component with a strict comparison; the first
    /// equal-rank perimeter entry therefore wins.  Callers must provide the
    /// recovered component ranks.  Object `+0xD0` adjustments and the
    /// serialized object registry are intentionally outside this helper.
    public static func recoveredHouseRoadAccessPoint(
        houseLocation: GridPoint,
        vacantBuildingID: Int,
        roadComponentRankByPoint: [GridPoint: Int]
    ) -> GridPoint? {
        guard let footprint = OriginalBuildingFootprintCatalog
            .residentialObjectFootprint(forBuildingID: vacantBuildingID),
              footprint.width == footprint.height else { return nil }
        return OriginalMultipartMonumentRoutingCatalog.roadAccessPoint(
            subBuildingOrigin: houseLocation,
            footprintSide: footprint.width,
            roadComponentRankByPoint: roadComponentRankByPoint
        )
    }

    /// Creates a physical immigrant figure en route to `destination` (the
    /// house road access point). Route uses the recovered mode-1 + mode-19
    /// worker pathfinding; nil means no route exists (fail-closed).
    public static func spawnImmigrant(
        id: Int,
        houseID: Int,
        peopleCount: Int,
        entryPoint: GridPoint,
        destination: GridPoint,
        waitSteps: Int,
        primaryValues: [UInt16],
        fallbackValues: [UInt32],
        width: Int,
        height: Int
    ) -> ImmigrantWalker? {
        guard let route = OriginalGrandCanalLayoutCatalog.workerRoute(
            primaryValues: primaryValues,
            fallbackValues: fallbackValues,
            width: width,
            height: height,
            from: entryPoint,
            to: destination
        ) else {
            return nil
        }
        guard route.points.count > 0 else { return nil }
        return ImmigrantWalker(
            id: id,
            houseID: houseID,
            peopleCount: peopleCount,
            entryPoint: entryPoint,
            route: route.points,
            waitSteps: waitSteps
        )
    }

    /// Advances every live immigrant by one Native day's original-step budget,
    /// returning the arrivals that must be applied by the city. Walkers that
    /// have not arrived yet survive.
    public static func advanceImmigrants(
        walkers: inout [ImmigrantWalker],
        originalStepsInDay: Int
    ) -> [ImmigrantArrival] {
        var arrivals: [ImmigrantArrival] = []
        var remaining: [ImmigrantWalker] = []
        for var walker in walkers {
            var arrived = false
            for _ in 0..<max(0, originalStepsInDay) {
                if walker.advanceOneUpdate() {
                    arrivals.append(ImmigrantArrival(
                        houseID: walker.houseID,
                        peopleCount: walker.peopleCount
                    ))
                    arrived = true
                    break
                }
            }
            if !arrived {
                remaining.append(walker)
            }
        }
        walkers = remaining
        return arrivals
    }

    // MARK: - Popularity / pressure / request factors (§2–§4)

    /// Raw wage matcher used by `FUN_005911D0 @ 0x5911D0`.
    ///
    /// `FUN_00592BD0 @ 0x592BD0` binds the shared nearest-value walk to the
    /// object initialized at `0x592BB0`: six thresholds at `0x85CC74`, with
    /// the current wage read from `DAT_01312214`. These are evidence
    /// addresses, not a claim that Qin has a recovered wage-object projection.
    public enum OriginalWageEffectCatalog {
        public static let matcherInitializationAddress: UInt32 = 0x00592BB0
        public static let matcherAddress: UInt32 = 0x00592BD0
        public static let nearestWalkAddress: UInt32 = 0x00592BE0
        public static let matcherObjectAddress: UInt32 = 0x0130F820
        public static let thresholdTableAddress: UInt32 = 0x0085CC74
        public static let effectTableAddress: UInt32 = 0x0085CC5C
        public static let currentWageAddress: UInt32 = 0x01312214
        public static let thresholds = [0, 20, 26, 30, 34, 40]
        public static let effects = [-10, -5, -2, 0, 2, 4]
        public static let baselineWage = 30
    }

    /// Recovered wage-effect table (§3): nearest threshold, ties keep the
    /// first index; baseline wage 30 → effect 0.
    public static func wageEffect(currentWage: Int) -> Int {
        let thresholds = OriginalWageEffectCatalog.thresholds
        let effects = OriginalWageEffectCatalog.effects
        var bestIndex = 0
        var bestDistance = Int.max
        for (index, threshold) in thresholds.enumerated() {
            let distance = abs(currentWage - threshold)
            if distance < bestDistance {
                bestDistance = distance
                bestIndex = index
            }
        }
        return effects[bestIndex]
    }

    /// The seven raw coverage thresholds used by the separate tax
    /// nearest-index object (`DAT_0130F810`, initialized at `0x592CD0`).
    /// This is deliberately an index-only research boundary: the
    /// `DAT_0130F858` result table and its Native tax-object projection remain
    /// unresolved.
    public enum OriginalTaxCoverageIndexCatalog {
        public static let thresholds = [0, 3, 7, 9, 11, 15, 20]

        /// Returns the nearest threshold index using the source's strict
        /// improvement rule. Equal-distance ties retain the first index.
        public static func nearestIndex(coveragePercent: Int) -> Int {
            var bestIndex = 0
            var bestDistance = Int.max
            for (index, threshold) in thresholds.enumerated() {
                let distance = abs(coveragePercent - threshold)
                if distance < bestDistance {
                    bestDistance = distance
                    bestIndex = index
                }
            }
            return bestIndex
        }

        /// Mirrors `FUN_00591180`: coverage below 11 selects the None row
        /// (index 0); otherwise the nearest-index object selects the band.
        public static func selectedIndex(coveragePercent: Int) -> Int {
            guard coveragePercent >= 11 else { return 0 }
            return nearestIndex(coveragePercent: coveragePercent)
        }
    }

    /// Returns whether the original tax-coverage percentage reaches the
    /// non-None threshold. `FUN_00408BA0` computes the integer percentage
    /// `numerator * 100 / denominator`; `FUN_00591180` keeps the tax-sentiment
    /// band only when that result is at least `0x0B` (11). The cross-product
    /// comparison preserves that truncation boundary without floating point.
    public static func taxCoverageMeetsOriginalThreshold(
        taxedPopulation: Int,
        population: Int
    ) -> Bool {
        guard taxedPopulation >= 0, population > 0 else { return false }
        return Int64(taxedPopulation) * 100 >= Int64(population) * 11
    }

    /// Recovered employment bands (§3): `unemployed × 100 / workforce`.
    public static func employmentEffect(unemploymentPercent: Int) -> Int {
        if unemploymentPercent < 5 { return 1 }
        if unemploymentPercent <= 10 { return 0 }
        if unemploymentPercent <= 17 { return -1 }
        if unemploymentPercent <= 25 { return -2 }
        return -3
    }

    /// Recovered debt factor (§3): consecutive debt years plus `−2` when the
    /// treasury is negative.
    public static func debtEffect(debtYears: Int, treasuryIsNegative: Bool) -> Int {
        (treasuryIsNegative ? -2 : 0) + debtYears
    }

    /// Recovered feng-shui bands (§3): population below 351 contributes 0;
    /// otherwise harmony percent bands.
    public static func fengShuiEffect(population: Int, harmonyPercent: Int) -> Int {
        guard population >= 351 else { return 0 }
        if harmonyPercent >= 100 { return 2 }
        if harmonyPercent >= 90 { return 1 }
        if harmonyPercent >= 80 { return 0 }
        if harmonyPercent >= 70 { return -1 }
        if harmonyPercent >= 60 { return -2 }
        if harmonyPercent >= 50 { return -3 }
        if harmonyPercent >= 40 { return -4 }
        return -5
    }

    /// Applies the recovered `FUN_00591670` aggregation once a caller has
    /// already classified the active object records. The executable sums
    /// each accepted record's `+0xA0` value into a total weight and sums the
    /// harmonious subset into a numerator, then truncates
    /// `numerator * 100 / total` before applying the bands above. This helper
    /// deliberately does not classify objects or derive `+0xA0`; those
    /// producer and callback mappings remain unresolved for Qin.
    public static func fengShuiEffect(
        population: Int,
        harmoniousWeight: Int,
        totalWeight: Int
    ) -> Int {
        guard population >= 0,
              harmoniousWeight >= 0,
              totalWeight > 0,
              harmoniousWeight <= totalWeight else { return 0 }
        let harmonyPercent = Int(
            (Int64(harmoniousWeight) * 100) / Int64(totalWeight)
        )
        return fengShuiEffect(population: population, harmonyPercent: harmonyPercent)
    }

    /// One already-resolved object-vector record consumed by
    /// `FUN_00591670 @ 0x591670`. `placementValue` is the signed `+0xA0`
    /// dword, while `state16` is the signed short read from `+0x16` for the
    /// `placementValue >= 2` branch. The object-vector lookup and global gate
    /// are intentionally represented by the caller, not inferred here.
    public struct OriginalFengShuiObjectRecord: Sendable, Hashable, Codable {
        public let modelID: Int
        public let placementValue: Int
        public let state16: Int

        public init(modelID: Int, placementValue: Int, state16: Int = 0) {
            self.modelID = modelID
            self.placementValue = placementValue
            self.state16 = state16
        }
    }

    /// Raw totals produced by the source feng-shui object walk before the
    /// percentage bands are applied. `acceptedRecordCount` counts non-zero
    /// `+0xA0` records that pass the global gate; small (including negative)
    /// values contribute a unit total exactly as the source's `value < 2`
    /// branch does.
    public struct OriginalFengShuiWeightAggregate: Sendable, Hashable, Codable {
        public let totalWeight: Int
        public let harmoniousWeight: Int
        public let acceptedRecordCount: Int

        public init(
            totalWeight: Int,
            harmoniousWeight: Int,
            acceptedRecordCount: Int
        ) {
            self.totalWeight = totalWeight
            self.harmoniousWeight = harmoniousWeight
            self.acceptedRecordCount = acceptedRecordCount
        }
    }

    /// Exact model-ID switch used by `FUN_00562F70 @ 0x562F70` and its
    /// `FUN_00562E80` wrapper. These IDs are excluded only from the
    /// `placementValue >= 2` harmonious branch; they are not a generic list
    /// of buildings with negative feng-shui.
    public static func originalFengShuiSpecialModel(modelID: Int) -> Bool {
        switch modelID {
        case 0x4C...0x56, 0x5C, 0x5D, 0xFD...0x10C:
            return true
        default:
            return false
        }
    }

    /// Replays the arithmetic portion of `FUN_00591670` for an already
    /// resolved object vector. The source starts at registry index 1; callers
    /// should pass records in that same scan order. No object lookup, map
    /// projection, or `+0xA0` producer is implied by this helper.
    public static func originalFengShuiWeightAggregate(
        globalGateOpen: Bool,
        records: [OriginalFengShuiObjectRecord]
    ) -> OriginalFengShuiWeightAggregate {
        guard globalGateOpen else {
            return .init(totalWeight: 0, harmoniousWeight: 0, acceptedRecordCount: 0)
        }

        var totalWeight = 0
        var harmoniousWeight = 0
        var acceptedRecordCount = 0
        for record in records where record.placementValue != 0 {
            acceptedRecordCount += 1
            if record.placementValue < 2 {
                totalWeight += 1
                if record.placementValue == 1 {
                    harmoniousWeight += 1
                }
            } else if !originalFengShuiSpecialModel(modelID: record.modelID)
                        || record.state16 == 0 {
                totalWeight += record.placementValue
                harmoniousWeight += record.placementValue
            }
        }
        return .init(
            totalWeight: totalWeight,
            harmoniousWeight: harmoniousWeight,
            acceptedRecordCount: acceptedRecordCount
        )
    }

    /// Raw counter slots consumed by `FUN_0042B250 @ 0x42B250` after the
    /// placement-time model-field lookup.  The executable indexes the first
    /// slot array from 1 (slot 0 is unused), then stores the two remaining
    /// counters in adjacent locals; their gameplay/category names are not
    /// recovered, so the Native projection keeps the source slot numbering.
    public struct OriginalFengShuiPlacementCounts: Sendable, Hashable, Codable {
        public let slot1: Int
        public let slot2: Int
        public let slot3: Int
        public let slot4: Int
        public let slot5: Int

        public init(
            slot1: Int = 0,
            slot2: Int = 0,
            slot3: Int = 0,
            slot4: Int = 0,
            slot5: Int = 0
        ) {
            self.slot1 = slot1
            self.slot2 = slot2
            self.slot3 = slot3
            self.slot4 = slot4
            self.slot5 = slot5
        }

        fileprivate var all: [Int] {
            [slot1, slot2, slot3, slot4, slot5]
        }
    }

    /// Result of the placement-time `+0xA0` feng-shui calculation.  This is
    /// intentionally a pure arithmetic boundary: callers must provide the
    /// already-sampled counter slots, while the map scan, type-specific
    /// callbacks, and object-record filtering remain outside this contract.
    public struct OriginalFengShuiPlacementOutcome: Sendable, Hashable, Codable {
        public let modelValue: Int
        public let result: Int
        public let usedCounterSlots: Bool
        public let diagnosticSlot: Int?

        public init(
            modelValue: Int,
            result: Int,
            usedCounterSlots: Bool,
            diagnosticSlot: Int?
        ) {
            self.modelValue = modelValue
            self.result = result
            self.usedCounterSlots = usedCounterSlots
            self.diagnosticSlot = diagnosticSlot
        }
    }

    /// Replays the source branch that writes an object's `+0xA0` value.
    /// Model values 0, 6, 7, and values above 7 return fixed results. Values
    /// 1...5 require all five sampled counter slots and return `1` only when
    /// the two slots for that model are zero; otherwise they return `-1` and
    /// preserve the source's last-written conflicting slot in the diagnostic.
    /// Invalid negative model values or negative counters are rejected rather
    /// than treated as a recovered gameplay rule.
    public static func originalFengShuiPlacementResult(
        modelValue: Int,
        counts: OriginalFengShuiPlacementCounts = .init()
    ) -> OriginalFengShuiPlacementOutcome? {
        guard modelValue >= 0, counts.all.allSatisfy({ $0 >= 0 }) else {
            return nil
        }

        switch modelValue {
        case 0:
            return .init(
                modelValue: modelValue,
                result: 0,
                usedCounterSlots: false,
                diagnosticSlot: nil
            )
        case 6:
            return .init(
                modelValue: modelValue,
                result: -1,
                usedCounterSlots: false,
                diagnosticSlot: nil
            )
        case 7:
            return .init(
                modelValue: modelValue,
                result: 1,
                usedCounterSlots: false,
                diagnosticSlot: nil
            )
        case 8...:
            return .init(
                modelValue: modelValue,
                result: modelValue,
                usedCounterSlots: false,
                diagnosticSlot: nil
            )
        default:
            break
        }

        let slot1 = counts.slot1
        let slot2 = counts.slot2
        let slot3 = counts.slot3
        let slot4 = counts.slot4
        let slot5 = counts.slot5
        let harmonious: Bool
        var diagnosticSlot: Int?

        switch modelValue {
        case 1:
            harmonious = slot3 == 0 && slot4 == 0
            if slot3 != 0 { diagnosticSlot = 3 }
            if slot4 != 0 { diagnosticSlot = 4 }
        case 2:
            harmonious = slot4 == 0 && slot5 == 0
            if slot5 != 0 { diagnosticSlot = 5 }
            if slot4 != 0 { diagnosticSlot = 4 }
        case 3:
            harmonious = slot1 == 0 && slot5 == 0
            if slot1 != 0 { diagnosticSlot = 1 }
            if slot5 != 0 { diagnosticSlot = 5 }
        case 4:
            harmonious = slot1 == 0 && slot2 == 0
            if slot1 != 0 { diagnosticSlot = 1 }
            if slot2 != 0 { diagnosticSlot = 2 }
        case 5:
            harmonious = slot3 == 0 && slot2 == 0
            if slot3 != 0 { diagnosticSlot = 3 }
            if slot2 != 0 { diagnosticSlot = 2 }
        default:
            return nil
        }

        return .init(
            modelValue: modelValue,
            result: harmonious ? 1 : -1,
            usedCounterSlots: true,
            diagnosticSlot: diagnosticSlot
        )
    }

    /// Recovered repression factor (§3): Watchtower (#127) count; active only
    /// when population > 350 and `population <= count×500`.
    public static func repressionEffect(population: Int, watchtowerCount: Int) -> Int {
        guard population > 350, watchtowerCount > 0,
              population <= watchtowerCount * 500 else { return 0 }
        return -min(4, (watchtowerCount * 500) / population)
    }

    /// Recovered pressure bands (§4).
    public static func pressureBand(popularity: Int) -> Int {
        let clamped = min(100, max(0, popularity))
        if clamped < 16 { return -25 }
        if clamped <= 25 { return -17 }
        if clamped <= 35 { return -8 }
        if clamped <= 49 { return 0 }
        if clamped <= 60 { return 50 }
        if clamped <= 70 { return 75 }
        return 100
    }

    /// `ceil(12 × |pressure| / 100)` (§4).
    public static func requestSize(forAbsolutePressure pressure: Int) -> Int {
        (12 * max(0, pressure) + 99) / 100
    }

    /// Inputs to the pressure/request pass recovered from
    /// `FUN_005917E0 @ 0x5917E0`.  The cooldowns are the raw arrival
    /// (`DAT_01311FC8`) and departure (`DAT_01311FC4`) gates.  War count and
    /// population are supplied explicitly because their Native producers are
    /// not yet mapped.
    public struct OriginalPressurePassInput: Sendable, Hashable, Codable {
        public let popularity: Int
        public let previousPressure: Int
        public let population: Int
        public let warTroopCount: Int
        public let arrivalCooldown: Int
        public let departureCooldown: Int

        public init(
            popularity: Int,
            previousPressure: Int,
            population: Int,
            warTroopCount: Int = 0,
            arrivalCooldown: Int = 0,
            departureCooldown: Int = 0
        ) {
            self.popularity = popularity
            self.previousPressure = previousPressure
            self.population = population
            self.warTroopCount = warTroopCount
            self.arrivalCooldown = arrivalCooldown
            self.departureCooldown = departureCooldown
        }
    }

    /// Result of one source-backed pressure/request pass.  A request is the
    /// value passed to the later assignment walk; this helper does not assign
    /// houses, spawn figures, or invoke the unresolved overlay callback.
    public struct OriginalPressurePassOutcome: Sendable, Hashable, Codable {
        public let pressure: Int
        public let arrivalRequest: Int
        public let departureRequest: Int
        public let arrivalCooldown: Int
        public let departureCooldown: Int
        public let invokedOverlayRefresh: Bool

        public init(
            pressure: Int,
            arrivalRequest: Int,
            departureRequest: Int,
            arrivalCooldown: Int,
            departureCooldown: Int,
            invokedOverlayRefresh: Bool
        ) {
            self.pressure = pressure
            self.arrivalRequest = arrivalRequest
            self.departureRequest = departureRequest
            self.arrivalCooldown = arrivalCooldown
            self.departureCooldown = departureCooldown
            self.invokedOverlayRefresh = invokedOverlayRefresh
        }
    }

    /// Replays the branch/order of `FUN_005917E0 @ 0x5917E0` with all global
    /// inputs explicit.  Cooldown returns occur before the shared
    /// pressure-change callback, and positive pressure is suppressed by
    /// `warTroopCount >= 4`; negative pressure remains eligible for departure
    /// requests under that same war count.  The callback is reported only as
    /// a boolean because its `FUN_00548340` overlay effects are unresolved.
    public static func originalPressurePass(
        _ input: OriginalPressurePassInput
    ) -> OriginalPressurePassOutcome {
        var pressure = pressureBand(popularity: input.popularity)
        var arrivalCooldown = input.arrivalCooldown
        var departureCooldown = input.departureCooldown
        var arrivalRequest = 0
        var departureRequest = 0

        if input.population > 199_999 {
            pressure = 0
            return .init(
                pressure: pressure,
                arrivalRequest: arrivalRequest,
                departureRequest: departureRequest,
                arrivalCooldown: arrivalCooldown,
                departureCooldown: departureCooldown,
                invokedOverlayRefresh: false
            )
        }

        if input.warTroopCount < 4 {
            if pressure > 0 {
                guard arrivalCooldown == 0 else {
                    arrivalCooldown -= 1
                    return .init(
                        pressure: pressure,
                        arrivalRequest: arrivalRequest,
                        departureRequest: departureRequest,
                        arrivalCooldown: arrivalCooldown,
                        departureCooldown: departureCooldown,
                        invokedOverlayRefresh: false
                    )
                }
                arrivalRequest = requestSize(forAbsolutePressure: pressure)
                departureCooldown = 2
            }
        } else if pressure > 0 {
            pressure = 0
            return .init(
                pressure: pressure,
                arrivalRequest: arrivalRequest,
                departureRequest: departureRequest,
                arrivalCooldown: arrivalCooldown,
                departureCooldown: departureCooldown,
                invokedOverlayRefresh: false
            )
        }

        if pressure < 0 {
            guard departureCooldown == 0 else {
                departureCooldown -= 1
                return .init(
                    pressure: pressure,
                    arrivalRequest: arrivalRequest,
                    departureRequest: departureRequest,
                    arrivalCooldown: arrivalCooldown,
                    departureCooldown: departureCooldown,
                    invokedOverlayRefresh: false
                )
            }
            guard input.population >= 101 else {
                return .init(
                    pressure: pressure,
                    arrivalRequest: arrivalRequest,
                    departureRequest: departureRequest,
                    arrivalCooldown: arrivalCooldown,
                    departureCooldown: departureCooldown,
                    invokedOverlayRefresh: false
                )
            }
            departureRequest = requestSize(forAbsolutePressure: -pressure)
            arrivalCooldown = 2
        }

        return .init(
            pressure: pressure,
            arrivalRequest: arrivalRequest,
            departureRequest: departureRequest,
            arrivalCooldown: arrivalCooldown,
            departureCooldown: departureCooldown,
            invokedOverlayRefresh: input.previousPressure != pressure
        )
    }

    /// Inputs to the request bookkeeping in `FUN_004AD4A0 @ 0x4AD4A0`.
    /// `arrivalPending` and `departurePending` are the raw words carried
    /// across days; the assignment/dispatch callees are intentionally not
    /// represented here because their object and route side effects are
    /// separate unresolved boundaries.
    public struct OriginalDailyMigrationBatchInput: Sendable, Hashable, Codable {
        public let arrivalRequest: Int
        public let departureRequest: Int
        public let arrivalPending: Int
        public let departurePending: Int

        public init(
            arrivalRequest: Int,
            departureRequest: Int,
            arrivalPending: Int = 0,
            departurePending: Int = 0
        ) {
            self.arrivalRequest = arrivalRequest
            self.departureRequest = departureRequest
            self.arrivalPending = arrivalPending
            self.departurePending = departurePending
        }
    }

    /// Exact pending/request result of one `FUN_004AD4A0` pass. A non-nil
    /// dispatch amount means the source calls `FUN_004ADA10` or
    /// `FUN_004ADC90`; the helper does not claim that the callee succeeds.
    public struct OriginalDailyMigrationBatchOutcome: Sendable, Hashable, Codable {
        public let arrivalPending: Int
        public let departurePending: Int
        public let arrivalDispatchAmount: Int?
        public let departureDispatchAmount: Int?
        public let requestsCleared: Bool

        public init(
            arrivalPending: Int,
            departurePending: Int,
            arrivalDispatchAmount: Int?,
            departureDispatchAmount: Int?,
            requestsCleared: Bool = true
        ) {
            self.arrivalPending = arrivalPending
            self.departurePending = departurePending
            self.arrivalDispatchAmount = arrivalDispatchAmount
            self.departureDispatchAmount = departureDispatchAmount
            self.requestsCleared = requestsCleared
        }
    }

    /// Replays the source's strict six-person batching boundary. Requests
    /// below six are accumulated with the carried word and dispatched only
    /// once the sum exceeds five; that successful-threshold path clears the
    /// carried word. Requests of six or more dispatch immediately while
    /// preserving the prior carried word. Departure uses the identical
    /// control flow with its own pending word and downstream callee.
    public static func originalDailyMigrationBatch(
        _ input: OriginalDailyMigrationBatchInput
    ) -> OriginalDailyMigrationBatchOutcome {
        func resolve(request: Int, pending: Int) -> (pending: Int, dispatch: Int?) {
            guard request > 0 else { return (pending, nil) }
            if request < 6 {
                let combined = request + pending
                guard combined > 5 else { return (combined, nil) }
                return (0, combined)
            }
            return (pending, request)
        }

        let arrival = resolve(
            request: input.arrivalRequest,
            pending: input.arrivalPending
        )
        let departure = resolve(
            request: input.departureRequest,
            pending: input.departurePending
        )
        return .init(
            arrivalPending: arrival.pending,
            departurePending: departure.pending,
            arrivalDispatchAmount: arrival.dispatch,
            departureDispatchAmount: departure.dispatch
        )
    }

    /// One live building row consumed by `FUN_0055AE30 @ 0x55AE30`. The
    /// source starts its building-vector walk at index 1; callers must retain
    /// that order rather than sorting by an authored/native identifier.
    public struct OriginalMonumentMatchingBuilding: Sendable, Hashable, Codable {
        public let vectorIndex: Int
        public let isActive: Bool
        public let modelID: Int
        public let subIndex: Int
        public let completionPercent: Int

        public init(
            vectorIndex: Int,
            isActive: Bool = true,
            modelID: Int,
            subIndex: Int = 0,
            completionPercent: Int
        ) {
            self.vectorIndex = vectorIndex
            self.isActive = isActive
            self.modelID = modelID
            self.subIndex = subIndex
            self.completionPercent = completionPercent
        }
    }

    /// One `cMonumentGoal` row consumed by the source's inner goal-vector
    /// walk. `type` is the raw goal object `+4`; only type `2` participates.
    /// `completed` is the mutable `goal+8` flag, retained so a caller can
    /// observe the source's match/mismatch writes in vector order.
    public struct OriginalMonumentMatchingGoal: Sendable, Hashable, Codable {
        public let vectorIndex: Int
        public let type: Int
        public let buildingID: Int
        public let completed: Bool

        public init(
            vectorIndex: Int,
            type: Int,
            buildingID: Int,
            completed: Bool = false
        ) {
            self.vectorIndex = vectorIndex
            self.type = type
            self.buildingID = buildingID
            self.completed = completed
        }
    }

    public struct OriginalMonumentMatchingGoalResult: Sendable, Hashable, Codable {
        public let vectorIndex: Int
        public let completed: Bool
        public let wroteCompletionFlag: Bool

        public init(
            vectorIndex: Int,
            completed: Bool,
            wroteCompletionFlag: Bool
        ) {
            self.vectorIndex = vectorIndex
            self.completed = completed
            self.wroteCompletionFlag = wroteCompletionFlag
        }
    }

    public struct OriginalMonumentMatchingOutcome: Sendable, Hashable, Codable {
        public let matchingPairCount: Int
        public let goals: [OriginalMonumentMatchingGoalResult]

        public init(
            matchingPairCount: Int,
            goals: [OriginalMonumentMatchingGoalResult]
        ) {
            self.matchingPairCount = matchingPairCount
            self.goals = goals
        }
    }

    /// Exact explicit-input reproduction of `FUN_0055AE30`. A building must
    /// be active, belong to the source monument model set, be a root
    /// (`subIndex == 0`), and have `FUN_00565410(+0xB4, 0, 0) >= 100` before
    /// its type-2 goals are tested. Ordinary IDs match directly; goal IDs
    /// `0x55`/`0x56` match building IDs `0xFD...0x10C`. Every matching pair
    /// increments the count, while each eligible mismatch writes that goal's
    /// completion flag to false. The same goal can therefore be counted more
    /// than once for duplicate matching roots, and a later eligible mismatch
    /// can clear an earlier match. Native object/registry projection is not
    /// inferred by this helper.
    public static func originalMonumentMatchingWalk(
        buildings: [OriginalMonumentMatchingBuilding],
        goals: [OriginalMonumentMatchingGoal]
    ) -> OriginalMonumentMatchingOutcome {
        var goalResults = goals.map {
            OriginalMonumentMatchingGoalResult(
                vectorIndex: $0.vectorIndex,
                completed: $0.completed,
                wroteCompletionFlag: false
            )
        }
        var matchingPairCount = 0
        for building in buildings where building.vectorIndex > 0 {
            guard building.isActive,
                  originalMonumentModelID(building.modelID),
                  building.subIndex == 0,
                  building.completionPercent >= 100 else { continue }

            for index in goals.indices where goals[index].type == 2 {
                let goal = goals[index]
                let matches = goal.buildingID == building.modelID
                    || ((goal.buildingID == 0x55 || goal.buildingID == 0x56)
                        && (0xFD...0x10C).contains(building.modelID))
                goalResults[index] = .init(
                    vectorIndex: goal.vectorIndex,
                    completed: matches,
                    wroteCompletionFlag: true
                )
                if matches { matchingPairCount += 1 }
            }
        }
        return .init(
            matchingPairCount: matchingPairCount,
            goals: goalResults
        )
    }

    /// `FUN_00562F70`'s exact monument-model switch used by the matching
    /// walk. This is intentionally separate from the Native monument catalog.
    public static func originalMonumentModelID(_ modelID: Int) -> Bool {
        (76...86).contains(modelID)
            || modelID == 92
            || modelID == 93
            || (253...268).contains(modelID)
    }

    /// Recovered popularity damping and apply branches (§2).
    public static func dampedPopularityDelta(current: Int, factorSum: Int) -> Int {
        let bias: Int
        if current < 0x0B { bias = 4 }
        else if current < 0x15 { bias = 3 }
        else if current < 0x1F { bias = 2 }
        else if current < 0x29 { bias = 1 }
        else if current < 0x3D { bias = 0 }
        else if current < 0x47 { bias = -1 }
        else if current < 0x51 { bias = -2 }
        else { bias = current < 0x5B ? -3 : -4 }
        if current < 0x29 {
            if factorSum >= 0 { return factorSum }
            let biased = bias + factorSum
            return biased > 0 ? 0 : biased
        }
        if current < 0x3D || factorSum < 0 { return factorSum }
        let biased = bias + factorSum
        return biased < 0 ? 0 : biased
    }

    /// The already-resolved factor values consumed by `FUN_00591200 @
    /// 0x591200`. `monumentPairCount` is the post-call value before the source's
    /// `* 2` term; `factorSixForBlame` is the separately scaled value used
    /// only by the worst-factor diagnostic slot 6. All producer callbacks and
    /// object-vector projections remain outside this arithmetic boundary.
    public struct OriginalPopularityProducerFactorInput: Sendable, Hashable, Codable {
        public let currentPopularity: Int
        public let taxFactor: Int
        public let wageFactor: Int
        public let employmentFactor: Int
        public let foodFactor: Int
        public let debtFactor: Int
        public let monumentPairCount: Int
        public let fengShuiFactor: Int
        public let repressionFactor: Int
        public let factorSixForBlame: Int
        public let previousFactorBlame: Int

        public init(
            currentPopularity: Int,
            taxFactor: Int,
            wageFactor: Int,
            employmentFactor: Int,
            foodFactor: Int,
            debtFactor: Int,
            monumentPairCount: Int,
            fengShuiFactor: Int,
            repressionFactor: Int,
            factorSixForBlame: Int = 0,
            previousFactorBlame: Int = 0
        ) {
            self.currentPopularity = currentPopularity
            self.taxFactor = taxFactor
            self.wageFactor = wageFactor
            self.employmentFactor = employmentFactor
            self.foodFactor = foodFactor
            self.debtFactor = debtFactor
            self.monumentPairCount = monumentPairCount
            self.fengShuiFactor = fengShuiFactor
            self.repressionFactor = repressionFactor
            self.factorSixForBlame = factorSixForBlame
            self.previousFactorBlame = previousFactorBlame
        }
    }

    /// Result of the arithmetic portion of `FUN_00591200`. The source adds
    /// the constant `1`, doubles the monument callback result, applies the
    /// current-popularity damping branches, and updates the blame index only
    /// when a factor is strictly below zero. Strict comparisons preserve the
    /// source's first-winner order on equal negative factors and preserve the
    /// previous blame index when every factor is non-negative.
    public struct OriginalPopularityProducerFactorOutcome: Sendable, Hashable, Codable {
        public let factorSum: Int
        public let popularityDelta: Int
        public let popularity: Int
        public let factorBlame: Int
        public let worstFactor: Int

        public init(
            factorSum: Int,
            popularityDelta: Int,
            popularity: Int,
            factorBlame: Int,
            worstFactor: Int
        ) {
            self.factorSum = factorSum
            self.popularityDelta = popularityDelta
            self.popularity = popularity
            self.factorBlame = factorBlame
            self.worstFactor = worstFactor
        }
    }

    /// Replays the source factor sum, damping, and worst-factor walk without
    /// synthesizing any of the unresolved callback inputs. This is the
    /// source-complete arithmetic boundary used by Native's explicit
    /// popularity update path and by independent regression tests.
    public static func originalPopularityProducerFactors(
        _ input: OriginalPopularityProducerFactorInput
    ) -> OriginalPopularityProducerFactorOutcome {
        let factorSum = input.fengShuiFactor
            + input.repressionFactor
            + 1
            + input.monumentPairCount * 2
            + input.debtFactor
            + input.foodFactor
            + input.employmentFactor
            + input.wageFactor
            + input.taxFactor
        let delta = dampedPopularityDelta(
            current: input.currentPopularity,
            factorSum: factorSum
        )
        var blame = input.previousFactorBlame
        var worst = 0
        let factors = [
            (index: 1, value: input.foodFactor),
            (index: 2, value: input.employmentFactor),
            (index: 3, value: input.taxFactor),
            (index: 4, value: input.wageFactor),
            (index: 5, value: input.debtFactor),
            (index: 6, value: input.factorSixForBlame),
            (index: 7, value: input.fengShuiFactor),
            (index: 8, value: input.repressionFactor),
        ]
        for factor in factors where factor.value < worst {
            worst = factor.value
            blame = factor.index
        }
        // `FUN_00591200` clamps the stored global immediately after applying
        // the damped delta. Keep this pure source-boundary helper faithful to
        // that write-back result as well; the live state setter repeats the
        // clamp defensively, but callers of this forensic helper must not see
        // an impossible popularity outside the original 0...100 domain.
        let updatedPopularity = min(100, max(0, input.currentPopularity + delta))
        return .init(
            factorSum: factorSum,
            popularityDelta: delta,
            popularity: updatedPopularity,
            factorBlame: blame,
            worstFactor: worst
        )
    }

    /// Monument factor term (§10.8): `2 ×` matching (complete root, type-2
    /// goal) pairs. `goalBuildingIDs` are the live `kind == .monument` goal
    /// values; `completeRootBuildingIDs` are Native's completed monument
    /// roots (legacy, phased 77/84, palace 82, canal 83, wall layouts
    /// 253…268).
    public static func monumentPopularityTerm(
        goalBuildingIDs: [Int],
        completeRootBuildingIDs: Set<Int>
    ) -> Int {
        var pairs = 0
        for goalID in goalBuildingIDs {
            if goalID == 85 || goalID == 86 {
                pairs += completeRootBuildingIDs.intersection(253...268).count
            } else if completeRootBuildingIDs.contains(goalID) {
                pairs += 1
            }
        }
        return pairs * 2
    }
}
