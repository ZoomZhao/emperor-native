import Foundation

public struct ResidentialServiceConfiguration: Sendable, Hashable {
    public let buildingID: Int
    public let figureID: Int
    public let service: WalkerServiceKind

    public init(buildingID: Int, figureID: Int, service: WalkerServiceKind) {
        self.buildingID = buildingID
        self.figureID = figureID
        self.service = service
    }
}

/// Original service buildings and the roaming figure that delivers their
/// housing coverage. Multiple religious buildings intentionally share one
/// requirement because the house table accepts either Daoist or Buddhist care.
public enum OriginalResidentialServiceCatalog {
    /// Raw candidate boundary for `FUN_004E6690 @ 0x4E6690`, which chooses a
    /// figure's first cardinal exit from the four directional map-cache
    /// words. This is a pure source primitive: the live map-cache producer,
    /// object callback implementation, and multi-way RNG path remain outside
    /// the Native service/market bridge.
    public enum InitialExitDirection {
        public static let selectorAddress: UInt32 = 0x004E6690
        public static let candidateMask: UInt16 = 0x0440
        public static let objectCallbackBit: UInt16 = 0x0008
        public static let cardinalHeadings = [0, 2, 4, 6]
        public static let maximumRotationAttempts = 4

        /// One directional cache word and the result of its optional object
        /// callback. When the cache word carries bit `0x8`, the executable
        /// invokes the adjacent object callback and suppresses the candidate
        /// when that callback returns non-zero. Callers must provide that
        /// result explicitly; a missing callback is not treated as approval.
        public struct CandidateInput: Sendable, Hashable, Codable {
            public let rawCacheValue: UInt16
            public let callbackSuppresses: Bool

            public init(rawCacheValue: UInt16, callbackSuppresses: Bool = false) {
                self.rawCacheValue = rawCacheValue
                self.callbackSuppresses = callbackSuppresses
            }
        }

        /// Returns the admitted cardinal heading bytes in source table order.
        /// Exactly four inputs are required (headings `0,2,4,6`). The
        /// callback flag is consulted only when raw bit `0x8` is present,
        /// matching the four conditional callback blocks in the executable.
        public static func candidates(_ inputs: [CandidateInput]) -> [Int]? {
            guard inputs.count == cardinalHeadings.count else { return nil }
            return inputs.enumerated().compactMap { index, input in
                guard input.rawCacheValue & candidateMask != 0 else { return nil }
                if input.rawCacheValue & objectCallbackBit != 0,
                   input.callbackSuppresses {
                    return nil
                }
                return cardinalHeadings[index]
            }
        }

        /// Resolves the source's deterministic one/two-candidate branches.
        /// The multi-way branch depends on the saved map byte, crossing
        /// count, and fallback RNG; it intentionally returns `nil` here so
        /// callers cannot mistake this helper for a complete live selector.
        public static func selectAtMostTwo(
            candidates: [Int],
            currentHeading: Int,
            forbiddenHeading: Int? = nil,
            directionIncrement: Int
        ) -> Int? {
            guard !candidates.isEmpty, candidates.count <= 2,
                  candidates.allSatisfy({ cardinalHeadings.contains($0) })
            else { return nil }
            if candidates.count == 1 { return candidates[0] }

            var heading = currentHeading
            for _ in 0..<maximumRotationAttempts {
                if candidates.contains(heading), heading != forbiddenHeading {
                    return heading
                }
                heading = (heading + directionIncrement) & 7
            }
            return nil
        }

        /// The source branch used when three or four cardinal candidates are
        /// admitted. `turnCounterByte` is figure byte `+0x4F`; the source
        /// adds it to the saved map-cell byte and masks with `0x06` before
        /// testing the candidate table. A failed first test decrements the
        /// figure fallback counter `+0x51`. When that counter reaches zero,
        /// callers must supply the result of `FUN_004E71D0` explicitly; the
        /// fallback clears the forbidden heading and chooses the rotation
        /// increment (`+2` or `-2` in the source's even heading encoding).
        /// Missing fallback output is rejected rather than guessed.
        public struct MultiWayInput: Sendable, Hashable, Codable {
            public let candidates: [Int]
            public let savedMapByte: UInt8
            public let turnCounterByte: UInt8
            public let forbiddenHeading: Int?
            public let directionIncrement: Int
            public let fallbackCounter: Int
            public let fallbackHeading: Int?
            public let fallbackDirectionIncrement: Int?

            public init(
                candidates: [Int],
                savedMapByte: UInt8,
                turnCounterByte: UInt8,
                forbiddenHeading: Int? = nil,
                directionIncrement: Int,
                fallbackCounter: Int,
                fallbackHeading: Int? = nil,
                fallbackDirectionIncrement: Int? = nil
            ) {
                self.candidates = candidates
                self.savedMapByte = savedMapByte
                self.turnCounterByte = turnCounterByte
                self.forbiddenHeading = forbiddenHeading
                self.directionIncrement = directionIncrement
                self.fallbackCounter = fallbackCounter
                self.fallbackHeading = fallbackHeading
                self.fallbackDirectionIncrement = fallbackDirectionIncrement
            }
        }

        public struct MultiWayResult: Sendable, Hashable, Codable {
            public let heading: Int?
            public let nextFallbackCounter: Int
            public let usedFallback: Bool

            public init(heading: Int?, nextFallbackCounter: Int, usedFallback: Bool) {
                self.heading = heading
                self.nextFallbackCounter = nextFallbackCounter
                self.usedFallback = usedFallback
            }
        }

        /// Resolves the source's three/four-candidate branch with all
        /// unresolved data supplied by the caller. This mirrors the byte
        /// arithmetic and four-attempt rotation only; it does not invent the
        /// map-cache producer, `FUN_004E71D0` selection, or RNG stream.
        public static func selectMultiWay(_ input: MultiWayInput) -> MultiWayResult? {
            guard input.candidates.count >= 3, input.candidates.count <= 4,
                  input.candidates.allSatisfy({ cardinalHeadings.contains($0) }),
                  [2, -2].contains(input.directionIncrement) else { return nil }

            var heading = (Int(input.savedMapByte) + Int(input.turnCounterByte)) & 6
            var forbidden = input.forbiddenHeading
            var increment = input.directionIncrement
            var fallbackCounter = input.fallbackCounter
            var usedFallback = false

            if !input.candidates.contains(heading) || heading == forbidden {
                fallbackCounter -= 1
                if fallbackCounter < 1 {
                    guard let fallbackHeading = input.fallbackHeading,
                          cardinalHeadings.contains(fallbackHeading),
                          let fallbackIncrement = input.fallbackDirectionIncrement,
                          [2, -2].contains(fallbackIncrement) else {
                        return .init(heading: nil, nextFallbackCounter: fallbackCounter, usedFallback: true)
                    }
                    heading = fallbackHeading
                    increment = fallbackIncrement
                    forbidden = nil
                    usedFallback = true
                }
            }

            for _ in 0..<maximumRotationAttempts {
                if input.candidates.contains(heading), heading != forbidden {
                    return .init(
                        heading: heading,
                        nextFallbackCounter: fallbackCounter,
                        usedFallback: usedFallback
                    )
                }
                heading = (heading + increment) & 7
            }
            return .init(
                heading: nil,
                nextFallbackCounter: fallbackCounter,
                usedFallback: usedFallback
            )
        }

        public struct FallbackScore: Sendable, Hashable, Codable {
            public let heading: Int
            public let visitValue: Int

            public init(heading: Int, visitValue: Int) {
                self.heading = heading
                self.visitValue = visitValue
            }
        }

        public struct FallbackResult: Sendable, Hashable, Codable {
            public let heading: Int?
            public let directionIncrement: Int?
            public let fallbackCounter: Int

            public init(heading: Int?, directionIncrement: Int?, fallbackCounter: Int) {
                self.heading = heading
                self.directionIncrement = directionIncrement
                self.fallbackCounter = fallbackCounter
            }
        }

        /// Mirrors the non-negative visit-selector branch of
        /// `FUN_004E71D0`. The executable scans the four even headings in
        /// table order, keeps a minimum visit value, replaces an equal
        /// minimum when the supplied RNG residue is non-zero modulo the
        /// incremented tie count, then chooses `+2` for an even final RNG
        /// value or `-2` for an odd one and reloads `+0x51` to five.
        /// Scores and RNG values are explicit because their producers and
        /// call order are not reconstructed in Native.
        public static func selectFallback(
            scores: [FallbackScore],
            tieRandomValues: [UInt32],
            rotationRandomValue: UInt32
        ) -> FallbackResult? {
            guard !scores.isEmpty,
                  scores.allSatisfy({ cardinalHeadings.contains($0.heading) }),
                  scores.allSatisfy({ (0...7).contains($0.visitValue) }),
                  Set(scores.map(\.heading)).count == scores.count else {
                return nil
            }

            var selected: Int?
            var minimum = Int.max
            var tieCount = 1
            var randomIndex = 0
            for heading in cardinalHeadings {
                guard let score = scores.first(where: { $0.heading == heading }) else { continue }
                if score.visitValue < minimum {
                    minimum = score.visitValue
                    tieCount = 2
                    selected = heading
                } else if score.visitValue == minimum {
                    guard tieRandomValues.indices.contains(randomIndex) else { return nil }
                    tieCount += 1
                    if tieRandomValues[randomIndex] % UInt32(tieCount) != 0 {
                        selected = heading
                    }
                    randomIndex += 1
                }
            }
            guard let selected else {
                return .init(heading: nil, directionIncrement: nil, fallbackCounter: 5)
            }
            return .init(
                heading: selected,
                directionIncrement: rotationRandomValue & 1 == 0 ? 2 : -2,
                fallbackCounter: 5
            )
        }
    }

    /// One source-backed transition of a residential provider's byte `+0x36`.
    /// The result is deliberately a value type: it does not allocate the
    /// figure requested by `FUN_0051CF90`, update a provider registry, or
    /// write housing coverage.
    public struct ResidentialSpawnCounterTransition: Sendable, Hashable, Codable {
        public let previousCounter: UInt8
        public let nextCounter: UInt8
        public let threshold: Int
        /// The strict threshold branch was reached and the source attempted
        /// `FUN_004EA050`. The allocator's returned figure ID is not supplied
        /// here, so this is intentionally not a claim that a figure exists.
        public let didRequestFigure: Bool

        /// Backwards-compatible spelling for callers that consumed the
        /// earlier research helper. It means “spawn request branch reached,”
        /// not “figure allocation succeeded.”
        @available(*, deprecated, renamed: "didRequestFigure")
        public var didSpawn: Bool { didRequestFigure }

        public init(
            previousCounter: UInt8,
            nextCounter: UInt8,
            threshold: Int,
            didRequestFigure: Bool
        ) {
            self.previousCounter = previousCounter
            self.nextCounter = nextCounter
            self.threshold = threshold
            self.didRequestFigure = didRequestFigure
        }
    }

    public static let configurations: [ResidentialServiceConfiguration] = [
        .init(buildingID: 124, figureID: 39, service: .inspection),
        .init(buildingID: 127, figureID: 29, service: .constable),
        .init(buildingID: 125, figureID: 27, service: .tax),
        .init(buildingID: 72, figureID: 28, service: .water),
        .init(buildingID: 207, figureID: 30, service: .herbalist),
        .init(buildingID: 208, figureID: 31, service: .acupuncture),
        .init(buildingID: 211, figureID: 34, service: .music),
        .init(buildingID: 212, figureID: 32, service: .acrobat),
        .init(buildingID: 213, figureID: 33, service: .drama),
        .init(buildingID: 214, figureID: 35, service: .ancestor),
        .init(buildingID: 215, figureID: 35, service: .daoistOrBuddhist),
        .init(buildingID: 216, figureID: 35, service: .daoistOrBuddhist),
        .init(buildingID: 217, figureID: 35, service: .daoistOrBuddhist),
        .init(buildingID: 218, figureID: 35, service: .daoistOrBuddhist),
        .init(buildingID: 219, figureID: 35, service: .confucian),
    ]

    /// Entertainment-service models whose original provider lifecycle is not
    /// represented by the Native campaign bridge. Sandbox construction is
    /// retained for isolated fixtures, but campaign placement must stay
    /// fail-closed until each model's provider registry, route/collision and
    /// coverage side effects are recovered.
    public static let campaignConstructionUnsupportedBuildingIDs: Set<Int> = [
        211, 212, 213
    ]

    public static func configuration(buildingID: Int) -> ResidentialServiceConfiguration? {
        configurations.first { $0.buildingID == buildingID }
    }

    public static func isCampaignConstructionSupported(buildingID: Int) -> Bool {
        !campaignConstructionUnsupportedBuildingIDs.contains(buildingID)
    }

    /// Returns the provider spawn threshold used by the common
    /// `FUN_0051CF90 @ 0x51CF90` routine after its worker/access gates pass.
    /// The routine increments provider byte `+0x36` and creates a figure only
    /// when the new value is strictly greater than this threshold. Tax and
    /// Herbalist use `0x507E40`; Well uses its `0x51BAE0` override; Acupuncture
    /// uses `0x51CF40`; and Religion uses `0x5AB330`. A non-positive
    /// worker value still returns the selector's threshold, but callers must
    /// apply the separate `worker > 0` gate before advancing the counter.
    ///
    /// Well's `0x51BAE0` method first calls provider vtable `+0x224`; when
    /// that raw callback returns non-zero, it doubles the worker input before
    /// applying the same bands.  The callback result is an explicit input so
    /// this helper never invents the unresolved Well predicate state.
    ///
    /// This is a pure source-backed table. It does not model the unresolved
    /// provider registry, access callback, figure allocation, route, or
    /// coverage side effects.
    public static func residentialSpawnThreshold(
        figureID: Int,
        workerPercent: Int,
        wellVTable224ReturnsNonZero: Bool = false
    ) -> Int? {
        let thresholds: [Int]
        switch figureID {
        case 27:
            thresholds = [1, 3, 5, 10, 15]
        case 28:
            thresholds = [1, 3, 5, 10, 15]
        case 30:
            thresholds = [1, 3, 5, 10, 15]
        case 31:
            thresholds = [1, 3, 7, 15, 29]
        case 35:
            thresholds = [3, 6, 12, 24, 32]
        default:
            return nil
        }
        let effectiveWorkerPercent = figureID == 28 && wellVTable224ReturnsNonZero
            ? workerPercent * 2
            : workerPercent
        switch effectiveWorkerPercent {
        case 100...: return thresholds[0]
        case 75..<100: return thresholds[1]
        case 50..<75: return thresholds[2]
        case 25..<50: return thresholds[3]
        case 1..<25: return thresholds[4]
        default: return thresholds[thresholds.count - 1]
        }
    }

    /// Mirrors the counter portion of `FUN_0051CF90 @ 0x51CF90` after the
    /// caller has resolved the provider's virtual gates. A failed access or
    /// worker gate leaves byte `+0x36` unchanged. When admitted, the byte is
    /// incremented with the source's UInt8 wrap semantics. When the
    /// incremented value is strictly greater than the provider threshold,
    /// the source clears the byte *before* calling `FUN_004EA050`; the
    /// returned figure ID is not available to this pure helper, so
    /// `didRequestFigure` records only that the allocation branch was entered.
    ///
    /// `providerWorkerGatePassed` represents the source vtable `+0x58` and
    /// positive `+0x1BC` checks. `providerAccessAllowed` represents the
    /// vtable `+0x4C` and global `FUN_004AFDB0(0xAC)` checks. These inputs are
    /// explicit because Qin's provider/object registry is not recovered, and
    /// this helper must not infer those gates from Native state.
    public static func residentialSpawnCounterTransition(
        figureID: Int,
        workerPercent: Int,
        counter: UInt8,
        providerAccessAllowed: Bool,
        providerWorkerGatePassed: Bool,
        wellVTable224ReturnsNonZero: Bool = false
    ) -> ResidentialSpawnCounterTransition? {
        guard let threshold = residentialSpawnThreshold(
            figureID: figureID,
            workerPercent: workerPercent,
            wellVTable224ReturnsNonZero: wellVTable224ReturnsNonZero
        ) else { return nil }

        guard providerAccessAllowed,
              providerWorkerGatePassed,
              workerPercent > 0 else {
            return .init(
                previousCounter: counter,
                nextCounter: counter,
                threshold: threshold,
                didRequestFigure: false
            )
        }

        let incremented = counter &+ 1
        let didRequestFigure = Int(incremented) > threshold
        return .init(
            previousCounter: counter,
            nextCounter: didRequestFigure ? 0 : incremented,
            threshold: threshold,
            didRequestFigure: didRequestFigure
        )
    }

    /// The post-allocation writes performed by `FUN_0051CF90 @ 0x51CF90`
    /// after `FUN_004EA050` returns a non-zero figure registry ID. The source
    /// invokes provider vtable `+0x50`, writes the provider registry index to
    /// figure `+0x62`, invokes figure vtable `+0x22C`, advances the provider
    /// heading at `+0x38` by four modulo eight, copies that value to figure
    /// `+0x1A`, and finally calls `FUN_004E6A70`.
    ///
    /// This records only those writes and call-site constants. It does not
    /// resolve the figure object, register it in the source vector, construct
    /// a route, or settle a house; Qin campaign spawning therefore remains
    /// fail-closed.
    public struct ResidentialSpawnFigureHandoff: Sendable, Hashable, Codable {
        public let figureRegistryIndex: Int
        public let providerRegistryIndex: Int16
        public let providerHeadingBefore: UInt8
        public let providerHeadingAfter: UInt8
        public let figureParentProviderIndex: Int16
        public let figureHeadingAfter: UInt8
        public let providerAttachVTableSlot: UInt32
        public let figureParentFieldOffset: UInt32
        public let figureInitializeVTableSlot: UInt32
        public let providerHeadingFieldOffset: UInt32
        public let figureHeadingFieldOffset: UInt32
        public let bootstrapAddress: UInt32

        public init(
            figureRegistryIndex: Int,
            providerRegistryIndex: Int16,
            providerHeadingBefore: UInt8,
            providerHeadingAfter: UInt8,
            figureParentProviderIndex: Int16,
            figureHeadingAfter: UInt8,
            providerAttachVTableSlot: UInt32,
            figureParentFieldOffset: UInt32,
            figureInitializeVTableSlot: UInt32,
            providerHeadingFieldOffset: UInt32,
            figureHeadingFieldOffset: UInt32,
            bootstrapAddress: UInt32
        ) {
            self.figureRegistryIndex = figureRegistryIndex
            self.providerRegistryIndex = providerRegistryIndex
            self.providerHeadingBefore = providerHeadingBefore
            self.providerHeadingAfter = providerHeadingAfter
            self.figureParentProviderIndex = figureParentProviderIndex
            self.figureHeadingAfter = figureHeadingAfter
            self.providerAttachVTableSlot = providerAttachVTableSlot
            self.figureParentFieldOffset = figureParentFieldOffset
            self.figureInitializeVTableSlot = figureInitializeVTableSlot
            self.providerHeadingFieldOffset = providerHeadingFieldOffset
            self.figureHeadingFieldOffset = figureHeadingFieldOffset
            self.bootstrapAddress = bootstrapAddress
        }
    }

    public static let residentialSpawnProviderAttachVTableSlot: UInt32 = 0x50
    public static let residentialSpawnFigureParentFieldOffset: UInt32 = 0x62
    public static let residentialSpawnFigureInitializeVTableSlot: UInt32 = 0x22C
    public static let residentialSpawnProviderHeadingFieldOffset: UInt32 = 0x38
    public static let residentialSpawnFigureHeadingFieldOffset: UInt32 = 0x1A
    public static let residentialSpawnFigureBootstrapAddress: UInt32 = 0x004E6A70

    public static func residentialSpawnFigureHandoff(
        figureRegistryIndex: Int,
        providerRegistryIndex: Int,
        providerHeading: UInt8
    ) -> ResidentialSpawnFigureHandoff {
        let nextHeading = UInt8((Int(providerHeading) + 4) & 7)
        let parentIndex = Int16(truncatingIfNeeded: providerRegistryIndex)
        return .init(
            figureRegistryIndex: figureRegistryIndex,
            providerRegistryIndex: parentIndex,
            providerHeadingBefore: providerHeading,
            providerHeadingAfter: nextHeading,
            figureParentProviderIndex: parentIndex,
            figureHeadingAfter: nextHeading,
            providerAttachVTableSlot: residentialSpawnProviderAttachVTableSlot,
            figureParentFieldOffset: residentialSpawnFigureParentFieldOffset,
            figureInitializeVTableSlot: residentialSpawnFigureInitializeVTableSlot,
            providerHeadingFieldOffset: residentialSpawnProviderHeadingFieldOffset,
            figureHeadingFieldOffset: residentialSpawnFigureHeadingFieldOffset,
            bootstrapAddress: residentialSpawnFigureBootstrapAddress
        )
    }

    /// The side-effect-free aggregate around `FUN_00517A40 @ 0x517A40`.
    ///
    /// The original walks the live object vector in order. For each entry it
    /// requires the shared `FUN_00426D10(0)` gate, the provider's virtual
    /// `+0xB8` eligibility callback, and the provider's virtual `+0x204`
    /// capacity/availability callback before invoking `+0x234` and adding
    /// that return value to the aggregate. The callback itself can mutate
    /// provider/figure state, so callers must supply its already-resolved
    /// result; this helper only preserves admission order and the integer
    /// reduction. A mismatched input shape is rejected instead of truncating
    /// the source vector.
    public struct ProviderSpawnAggregate: Sendable, Hashable, Codable {
        public let admittedIndices: [Int]
        public let total: Int

        public init(admittedIndices: [Int], total: Int) {
            self.admittedIndices = admittedIndices
            self.total = total
        }
    }

    public static func providerSpawnAggregate(
        globalGateOpen: Bool,
        providerEligibility: [Bool],
        providerCapacityEligibility: [Bool],
        spawnResults: [Int]
    ) -> ProviderSpawnAggregate? {
        guard providerEligibility.count == providerCapacityEligibility.count,
              providerEligibility.count == spawnResults.count else {
            return nil
        }
        guard globalGateOpen else {
            return .init(admittedIndices: [], total: 0)
        }

        var admittedIndices: [Int] = []
        var total = 0
        for index in providerEligibility.indices {
            guard providerEligibility[index], providerCapacityEligibility[index] else {
                continue
            }
            admittedIndices.append(index)
            total += spawnResults[index]
        }
        return .init(admittedIndices: admittedIndices, total: total)
    }

    /// Exact state-11 terminal predicate for the entertainment venue figure
    /// FSM (`FUN_004C9950 @ 0x4C9950`). The caller marks the figure failed
    /// when its heading byte `+0x19` is 8, 9, or 10. This is a pure research
    /// boundary; it does not infer the preceding collision meaning or enable
    /// venue figures in the live roam bridge.
    public static func entertainmentVenueTerminalFailure(heading: Int) -> Bool {
        [8, 9, 10].contains(heading)
    }

    /// States admitted by the entertainment venue figure routine at
    /// `FUN_0048A9A0`.  The raw values are the figure byte at `+0x40`; the
    /// failure value is the byte written to `+0x16` by the routine.
    public enum EntertainmentVenueFSMState: UInt8, Sendable, Hashable, Codable {
        case failure = 2
        case heading = 4
        case schoolAnimation = 5
        case routeToVenue = 6
        case selectVenue = 7
        case walkToVenue = 8
        case clearRoute = 9
        case returnToHome = 10
        case terminal = 11
    }

    /// Ordered side-effect labels for one source-backed venue-FSM step. These
    /// are deliberately labels rather than executable callbacks: route
    /// buffers, provider registries, collision results, and settlement remain
    /// unresolved for map-loaded Qin objects.
    public enum EntertainmentVenueFSMOperation: String, Sendable, Hashable, Codable {
        case advanceHeading
        case advanceSchoolAnimation
        case setVisitStateByte
        case setActiveFlag
        case setVenueFigureMode
        case resetFigureTick
        case clearAuxiliaryByte
        case requestRouteToVenue
        case copyProviderEntryTarget
        case initializeVenueRoute
        case advanceProviderApproach
        case selectVenueProvider
        case copySelectedVenueTarget
        case clearMovementBudget
        case clearActiveFlag
        case moveToVenue
        case clearRouteSlot
        case requestReturnRoute
        case copyOriginalProviderTarget
        case moveAlongReturnRoute
        case moveToReturnTarget
        case invokeTerminalCallback
        case markFailure
    }

    public struct EntertainmentVenueFSMTransition: Sendable, Hashable, Codable {
        public let sourceState: EntertainmentVenueFSMState
        public let nextState: EntertainmentVenueFSMState
        public let operations: [EntertainmentVenueFSMOperation]
        public let countdownAfterDecrement: Int16?
        public let movementCounterAfterIncrement: UInt16?
        public let marksFailure: Bool

        public init(
            sourceState: EntertainmentVenueFSMState,
            nextState: EntertainmentVenueFSMState,
            operations: [EntertainmentVenueFSMOperation],
            countdownAfterDecrement: Int16? = nil,
            movementCounterAfterIncrement: UInt16? = nil,
            marksFailure: Bool = false
        ) {
            self.sourceState = sourceState
            self.nextState = nextState
            self.operations = operations
            self.countdownAfterDecrement = countdownAfterDecrement
            self.movementCounterAfterIncrement = movementCounterAfterIncrement
            self.marksFailure = marksFailure
        }
    }

    /// Inputs to the resolved branches of `FUN_0048A9A0`.  The route and
    /// provider results are supplied by the caller because their object
    /// lookup/collision implementations are not recovered; this helper only
    /// preserves the executable's state ordering and failure boundaries.
    public enum EntertainmentVenueFSMEvent: Sendable, Hashable, Codable {
        case headingTick
        case schoolAnimationTick
        case routeToVenueTick(countdownBeforeDecrement: Int16, routeSucceeded: Bool)
        case providerSelectionTick(succeeded: Bool)
        case walkToVenueTick(movementCounterBeforeIncrement: UInt16)
        case clearRouteTick
        case returnBudgetBelowSavedTick
        case returnBudgetReachedTick(routeSucceeded: Bool)
        case terminalTick(callbackFailed: Bool)
    }

    /// Applies one pure, source-backed entertainment venue FSM transition.
    /// Every returned transition falls through the routine's common heading
    /// tail; callers must still supply the unresolved route/provider results.
    public static func entertainmentVenueFSMTransition(
        for event: EntertainmentVenueFSMEvent
    ) -> EntertainmentVenueFSMTransition {
        switch event {
        case .headingTick:
            return .init(
                sourceState: .heading,
                nextState: .heading,
                operations: [.advanceHeading]
            )
        case .schoolAnimationTick:
            return .init(
                sourceState: .schoolAnimation,
                nextState: .schoolAnimation,
                operations: [.advanceSchoolAnimation]
            )
        case let .routeToVenueTick(countdownBeforeDecrement, routeSucceeded):
            let countdown = countdownBeforeDecrement &- 1
            var operations: [EntertainmentVenueFSMOperation] = [
                .setActiveFlag,
                .resetFigureTick,
                .clearAuxiliaryByte
            ]
            guard countdown <= 0 else {
                return .init(
                    sourceState: .routeToVenue,
                    nextState: .routeToVenue,
                    operations: operations,
                    countdownAfterDecrement: countdown
                )
            }
            operations.append(.requestRouteToVenue)
            guard routeSucceeded else {
                operations.append(.markFailure)
                return .init(
                    sourceState: .routeToVenue,
                    nextState: .routeToVenue,
                    operations: operations,
                    countdownAfterDecrement: countdown,
                    marksFailure: true
                )
            }
            operations.append(contentsOf: [
                .copyProviderEntryTarget,
                .initializeVenueRoute,
                .clearMovementBudget
            ])
            return .init(
                sourceState: .routeToVenue,
                nextState: .selectVenue,
                operations: operations,
                countdownAfterDecrement: countdown
            )
        case let .providerSelectionTick(succeeded):
            var operations: [EntertainmentVenueFSMOperation] = [
                .setVisitStateByte,
                .setActiveFlag,
                .setVenueFigureMode,
                .advanceProviderApproach,
                .selectVenueProvider
            ]
            guard succeeded else {
                operations.append(.markFailure)
                return .init(
                    sourceState: .selectVenue,
                    nextState: .selectVenue,
                    operations: operations,
                    marksFailure: true
                )
            }
            operations.append(contentsOf: [
                .copySelectedVenueTarget,
                .clearMovementBudget
            ])
            return .init(
                sourceState: .selectVenue,
                nextState: .walkToVenue,
                operations: operations
            )
        case let .walkToVenueTick(counterBeforeIncrement):
            let counter = counterBeforeIncrement &+ 1
            var operations: [EntertainmentVenueFSMOperation] = [
                .setVenueFigureMode,
                .clearActiveFlag
            ]
            let failed = counter >= 3200
            if failed { operations.append(.markFailure) }
            operations.append(.moveToVenue)
            return .init(
                sourceState: .walkToVenue,
                nextState: .walkToVenue,
                operations: operations,
                movementCounterAfterIncrement: counter,
                marksFailure: failed
            )
        case .clearRouteTick:
            return .init(
                sourceState: .clearRoute,
                nextState: .clearRoute,
                operations: [.clearRouteSlot]
            )
        case .returnBudgetBelowSavedTick:
            return .init(
                sourceState: .returnToHome,
                nextState: .returnToHome,
                operations: [.clearActiveFlag, .moveAlongReturnRoute]
            )
        case let .returnBudgetReachedTick(routeSucceeded):
            var operations: [EntertainmentVenueFSMOperation] = [
                .clearActiveFlag,
                .requestReturnRoute
            ]
            guard routeSucceeded else {
                operations.append(contentsOf: [.markFailure, .moveAlongReturnRoute])
                return .init(
                    sourceState: .returnToHome,
                    nextState: .returnToHome,
                    operations: operations,
                    marksFailure: true
                )
            }
            operations.append(contentsOf: [
                .copyOriginalProviderTarget,
                .moveAlongReturnRoute
            ])
            return .init(
                sourceState: .returnToHome,
                nextState: .terminal,
                operations: operations
            )
        case let .terminalTick(callbackFailed):
            var operations: [EntertainmentVenueFSMOperation] = [
                .moveToReturnTarget,
                .invokeTerminalCallback
            ]
            if callbackFailed { operations.append(.markFailure) }
            return .init(
                sourceState: .terminal,
                nextState: .terminal,
                operations: operations,
                marksFailure: callbackFailed
            )
        }
    }

    /// Raw update plan emitted by `FUN_004E47A0 @ 0x4E47A0`.
    ///
    /// The executable stores the phase in a byte at figure `+0x170`.  This
    /// helper reproduces the selector switch without assigning a semantic
    /// meaning to selectors other than the venue FSM's confirmed selector 8.
    /// A returned `movementUpdates` value is the argument passed to
    /// `FUN_004E7EB0`; `nextPhase` is the byte written back to `+0x170` (or the
    /// unchanged byte for selectors that do not touch that field).  The
    /// `&+` operation mirrors the original byte increment's modulo-256 wrap.
    /// This remains a pure research primitive and does not enable live venue
    /// figures or any unresolved provider/route/collision side effects.
    public struct EntertainmentVenueMovementUpdatePlan: Sendable, Hashable, Codable {
        public let movementUpdates: Int
        public let nextPhase: UInt8

        public init(movementUpdates: Int, nextPhase: UInt8) {
            self.movementUpdates = movementUpdates
            self.nextPhase = nextPhase
        }
    }

    public static func entertainmentVenueMovementUpdatePlan(
        selector: Int,
        phase: UInt8
    ) -> EntertainmentVenueMovementUpdatePlan {
        switch selector {
        case 0:
            return .init(movementUpdates: 0, nextPhase: phase)
        case 1:
            return phase > 2
                ? .init(movementUpdates: 1, nextPhase: 0)
                : .init(movementUpdates: 0, nextPhase: phase &+ 1)
        case 2:
            return phase > 1
                ? .init(movementUpdates: 1, nextPhase: 0)
                : .init(movementUpdates: 0, nextPhase: phase &+ 1)
        case 3:
            return phase == 0
                ? .init(movementUpdates: 1, nextPhase: 1)
                : .init(movementUpdates: 2, nextPhase: 0)
        case 4:
            return phase > 1
                ? .init(movementUpdates: 2, nextPhase: 0)
                : .init(movementUpdates: 1, nextPhase: phase &+ 1)
        case 5:
            return phase > 2
                ? .init(movementUpdates: 2, nextPhase: 0)
                : .init(movementUpdates: 1, nextPhase: phase &+ 1)
        case 6:
            return .init(movementUpdates: 1, nextPhase: phase)
        case 7:
            return phase > 2
                ? .init(movementUpdates: 2, nextPhase: 0)
                : .init(movementUpdates: 1, nextPhase: phase &+ 1)
        case 8:
            return phase > 1
                ? .init(movementUpdates: 2, nextPhase: 0)
                : .init(movementUpdates: 1, nextPhase: phase &+ 1)
        case 9:
            return phase != 0
                ? .init(movementUpdates: 2, nextPhase: 0)
                : .init(movementUpdates: 1, nextPhase: phase &+ 1)
        case 10:
            return phase > 1
                ? .init(movementUpdates: 1, nextPhase: 0)
                : .init(movementUpdates: 2, nextPhase: phase &+ 1)
        case 11:
            return phase > 2
                ? .init(movementUpdates: 1, nextPhase: 0)
                : .init(movementUpdates: 2, nextPhase: phase &+ 1)
        case 12:
            return .init(movementUpdates: 2, nextPhase: phase)
        case 13:
            return phase > 2
                ? .init(movementUpdates: 3, nextPhase: 0)
                : .init(movementUpdates: 2, nextPhase: phase &+ 1)
        case 14:
            return phase > 1
                ? .init(movementUpdates: 3, nextPhase: 0)
                : .init(movementUpdates: 2, nextPhase: phase &+ 1)
        case 15:
            return phase != 0
                ? .init(movementUpdates: 2, nextPhase: 0)
                : .init(movementUpdates: 3, nextPhase: phase &+ 1)
        case 16:
            return phase < 2
                ? .init(movementUpdates: 3, nextPhase: phase &+ 1)
                : .init(movementUpdates: 2, nextPhase: 0)
        case 17:
            return phase < 3
                ? .init(movementUpdates: 3, nextPhase: phase &+ 1)
                : .init(movementUpdates: 2, nextPhase: 0)
        default:
            return .init(movementUpdates: 3, nextPhase: phase)
        }
    }

    /// Heading source for the shared route-anchor initializer
    /// (`FUN_004E98A0 @ 0x4E98A0`).  The coordinate callback is fully
    /// recoverable (`FUN_005B2730`); the shared callback (`FUN_005B2790`)
    /// reads executable-global state that is not projected into Native, so
    /// this value remains explicitly unresolved rather than guessed.
    public enum SharedRouteHeadingSource: String, Sendable, Hashable, Codable {
        case sharedCallback
        case coordinateCallback
    }

    /// Raw route-anchor fields written by `FUN_004E98A0`.
    ///
    /// The executable stores the target and residuals as signed 16-bit words,
    /// then chooses movement axis `1` when vertical residual is no greater
    /// than horizontal residual and `2` otherwise.  `heading` is present only
    /// when the caller supplied the result of the coordinate callback; the
    /// shared callback's global slope state is intentionally not synthesized.
    public struct SharedRouteAnchor: Sendable, Hashable, Codable {
        public let targetX: Int16
        public let targetY: Int16
        public let horizontalResidual: Int16
        public let verticalResidual: Int16
        public let diagonalResidual: Int16
        public let movementAxis: UInt8
        public let headingSource: SharedRouteHeadingSource
        public let heading: UInt8?

        public init(
            targetX: Int16,
            targetY: Int16,
            horizontalResidual: Int16,
            verticalResidual: Int16,
            diagonalResidual: Int16,
            movementAxis: UInt8,
            headingSource: SharedRouteHeadingSource,
            heading: UInt8?
        ) {
            self.targetX = targetX
            self.targetY = targetY
            self.horizontalResidual = horizontalResidual
            self.verticalResidual = verticalResidual
            self.diagonalResidual = diagonalResidual
            self.movementAxis = movementAxis
            self.headingSource = headingSource
            self.heading = heading
        }
    }

    /// Exact coordinate-heading table from `FUN_005B2730 @ 0x5B2730`.
    /// Headings are the raw byte values written by the executable; `8` is the
    /// equal-coordinate/arrival result.
    public static func sharedCoordinateHeading(
        currentX: Int,
        currentY: Int,
        targetX: Int,
        targetY: Int
    ) -> UInt8 {
        if targetX < currentX {
            if targetY < currentY { return 7 }
            if targetY == currentY { return 6 }
            return 5
        }
        if targetX == currentX {
            if targetY < currentY { return 0 }
            if targetY > currentY { return 4 }
            return 8
        }
        if targetY < currentY { return 1 }
        if targetY == currentY { return 2 }
        return 3
    }

    /// Reproduces the side-ratio heading corrections in `FUN_004E98A0`.
    /// The supplied heading is the already-resolved result of
    /// `FUN_005B2730`; the shared `FUN_005B2790` path does not take these
    /// corrections.
    public static func correctedSharedCoordinateHeading(
        heading: UInt8,
        horizontalResidual: Int,
        verticalResidual: Int
    ) -> UInt8 {
        var corrected = heading
        if horizontalResidual * 2 < verticalResidual {
            switch corrected {
            case 1: corrected = 0
            case 3, 5: corrected = 4
            case 7: corrected = 0
            default: break
            }
        }
        if verticalResidual * 2 < horizontalResidual {
            switch corrected {
            case 1, 3: corrected = 2
            case 5, 7: corrected = 6
            default: break
            }
        }
        return corrected
    }

    /// Computes the source-backed route-anchor arithmetic without resolving
    /// map globals, object callbacks, collision, or provider settlement.
    /// Coordinates are expected to be the ordinary map-domain values used by
    /// the canonical build; the returned fields preserve the executable's
    /// signed-short storage width.
    public static func sharedRouteAnchor(
        currentX: Int,
        currentY: Int,
        targetX: Int,
        targetY: Int,
        headingSource: SharedRouteHeadingSource,
        coordinateHeading: UInt8? = nil
    ) -> SharedRouteAnchor {
        let storedTargetX = Int16(truncatingIfNeeded: targetX)
        let storedTargetY = Int16(truncatingIfNeeded: targetY)
        let horizontal = abs(targetX - currentX)
        let vertical = abs(targetY - currentY)
        let diagonal: Int
        if horizontal < vertical {
            diagonal = horizontal * 2 - vertical
        } else if vertical < horizontal {
            diagonal = vertical * 2 - horizontal
        } else {
            diagonal = 0
        }

        let resolvedHeading: UInt8?
        switch headingSource {
        case .sharedCallback:
            resolvedHeading = nil
        case .coordinateCallback:
            let raw = coordinateHeading ?? sharedCoordinateHeading(
                currentX: currentX,
                currentY: currentY,
                targetX: targetX,
                targetY: targetY
            )
            resolvedHeading = correctedSharedCoordinateHeading(
                heading: raw,
                horizontalResidual: horizontal,
                verticalResidual: vertical
            )
        }

        return SharedRouteAnchor(
            targetX: storedTargetX,
            targetY: storedTargetY,
            horizontalResidual: Int16(truncatingIfNeeded: horizontal),
            verticalResidual: Int16(truncatingIfNeeded: vertical),
            diagonalResidual: Int16(truncatingIfNeeded: diagonal),
            movementAxis: vertical <= horizontal ? 1 : 2,
            headingSource: headingSource,
            heading: resolvedHeading
        )
    }

    /// Raw resource-key/frame arithmetic emitted by the common tail of
    /// `FUN_0048A9A0`.  The image resolver at `FUN_00408170` is intentionally
    /// not called here: its archive base and live sprite table are presentation
    /// state, while this value type records only the values the venue FSM feeds
    /// into that resolver.
    public struct EntertainmentVenueFrameSelection: Sendable, Hashable, Codable {
        public let resourceKey: Int
        public let alternateResourceKey: Int
        public let normalizedHeading: Int
        public let frameOffset: Int

        public init(
            resourceKey: Int,
            alternateResourceKey: Int,
            normalizedHeading: Int,
            frameOffset: Int
        ) {
            self.resourceKey = resourceKey
            self.alternateResourceKey = alternateResourceKey
            self.normalizedHeading = normalizedHeading
            self.frameOffset = frameOffset
        }
    }

    /// Mirrors the common-tail inputs in the direct PE recovery of
    /// `FUN_0048A9A0 @ 0x48A9A0`.
    ///
    /// When the signed raw figure heading byte is at least eight, the source
    /// uses the saved opposite heading instead.  Otherwise the signed byte is
    /// used directly. It then subtracts the shared map direction and adds
    /// eight once when negative. Models 33 (actor) and 34
    /// (musician) select distinct two-key resource pairs; all other models,
    /// including model 32 (acrobat), use the default pair.  State 4 uses the
    /// saved countdown as the frame offset, with values `>= 8` capped to 7;
    /// every other state uses `normalizedHeading + tick * 8`.
    ///
    /// This helper does not resolve the image pointer, mutate a figure, or
    /// enable the unresolved Qin venue route/registry bridge.
    public static func entertainmentVenueFrameSelection(
        modelID: Int,
        rawHeading: Int,
        savedHeading: Int,
        sharedDirection: Int,
        tick: UInt8,
        state: EntertainmentVenueFSMState,
        savedCountdown: Int16
    ) -> EntertainmentVenueFrameSelection? {
        let rawHeadingByte = Int8(truncatingIfNeeded: rawHeading)
        let savedHeadingByte = Int8(truncatingIfNeeded: savedHeading)
        let heading = rawHeadingByte >= 8 ? Int(savedHeadingByte) : Int(rawHeadingByte)
        var normalizedHeading = heading - sharedDirection
        if normalizedHeading < 0 {
            normalizedHeading += 8
        }

        let keys: (Int, Int)
        switch modelID {
        case 33:
            keys = (19_627, 19_631)
        case 34:
            keys = (19_559, 19_562)
        default:
            keys = (19_604, 19_608)
        }

        let frameOffset: Int
        if state == .heading {
            frameOffset = savedCountdown >= 8 ? 7 : Int(savedCountdown)
        } else {
            frameOffset = normalizedHeading + Int(tick) * 8
        }
        return .init(
            resourceKey: state == .heading ? keys.1 : keys.0,
            alternateResourceKey: state == .heading ? keys.0 : keys.1,
            normalizedHeading: normalizedHeading,
            frameOffset: frameOffset
        )
    }

    /// Model-family dispatch recovered from `FUN_0051BEF0 @ 0x51BEF0`.
    ///
    /// The executable accepts Well-family IDs `0x48/0x49` (72/73),
    /// Herbalist `0xCF` (207), and Acupuncture `0xD0` (208), then constructs
    /// the corresponding provider object and installs the vtable shown below.
    /// This is a static factory map only: it does not assign the serialized
    /// provider slot at `+0xB4` (`param[0x2D]` in the decompiler), register the
    /// object, or project service coverage into Native houses. This dword slot
    /// is distinct from the house-information byte at byte offset `+0x2D`.
    public struct ProviderFactoryDescriptor: Sendable, Hashable, Codable {
        public enum Family: String, Sendable, Hashable, Codable {
            case well
            case herbalist
            case acupuncture
        }

        public let family: Family
        public let buildingModelIDs: [Int]
        /// Shared dynamic-factory entry that dispatches this family.
        public let dispatcherAddress: UInt32
        /// Model predicate used before the family constructor is selected.
        public let admissionPredicateAddress: UInt32
        /// Allocation size passed to the executable allocator.
        public let allocationSize: Int
        public let initializerAddress: UInt32
        public let vtableAddress: UInt32

        public init(
            family: Family,
            buildingModelIDs: [Int],
            dispatcherAddress: UInt32 = 0x0051C660,
            admissionPredicateAddress: UInt32 = 0x0051BE30,
            allocationSize: Int = 0x150,
            initializerAddress: UInt32,
            vtableAddress: UInt32
        ) {
            self.family = family
            self.buildingModelIDs = buildingModelIDs
            self.dispatcherAddress = dispatcherAddress
            self.admissionPredicateAddress = admissionPredicateAddress
            self.allocationSize = allocationSize
            self.initializerAddress = initializerAddress
            self.vtableAddress = vtableAddress
        }
    }

    public static let providerFactoryDescriptors: [ProviderFactoryDescriptor] = [
        .init(
            family: .well,
            buildingModelIDs: [72, 73],
            initializerAddress: 0x0051C090,
            vtableAddress: 0x007B5EB4
        ),
        .init(
            family: .herbalist,
            buildingModelIDs: [207],
            initializerAddress: 0x0051C0B0,
            vtableAddress: 0x007B6114
        ),
        .init(
            family: .acupuncture,
            buildingModelIDs: [208],
            initializerAddress: 0x0051C0D0,
            vtableAddress: 0x007B6374
        ),
    ]

    public static func providerFactoryDescriptor(
        forBuildingModelID buildingModelID: Int
    ) -> ProviderFactoryDescriptor? {
        providerFactoryDescriptors.first {
            $0.buildingModelIDs.contains(buildingModelID)
        }
    }

    /// Fixed-output callback targets in provider vtable slot `+0x200`.
    /// These are research metadata only.  The callback's three output words
    /// and any provider/house settlement semantics remain unresolved, so this
    /// catalog must not be used to synthesize a live provider or coverage.
    public struct ProviderVTableSlot200OutputEnvelope: Sendable, Hashable, Codable {
        /// `nil` means the callback writes this envelope unconditionally.  A
        /// value records the raw branch on the provider object's word at
        /// `+0x2E`; it is deliberately not given a gameplay-facing meaning.
        public let objectWord2EIsNonZero: Bool?
        public let outputWord0: UInt32
        public let outputWord1: UInt32
        public let outputWord2: UInt32

        public init(
            objectWord2EIsNonZero: Bool? = nil,
            outputWord0: UInt32,
            outputWord1: UInt32,
            outputWord2: UInt32
        ) {
            self.objectWord2EIsNonZero = objectWord2EIsNonZero
            self.outputWord0 = outputWord0
            self.outputWord1 = outputWord1
            self.outputWord2 = outputWord2
        }
    }

    public struct ProviderVTableSlot200Descriptor: Sendable, Hashable, Codable {
        public let providerModelIDs: [Int]
        public let providerVTableAddress: UInt32
        public let slotOffset: Int
        public let targetAddress: UInt32
        public let targetIndexedInCorpus: Bool
        /// Direct PE callbacks return `1` after writing an envelope.  This is
        /// a raw return value, not a Native success/coverage decision.
        public let callbackReturnValue: UInt8
        /// Raw direct-PE output envelopes.  These are not semantic mappings
        /// and must not be consumed as capacity, quality, figure, radius, or
        /// coverage values until an indexed caller proves that interpretation.
        public let outputEnvelopes: [ProviderVTableSlot200OutputEnvelope]

        public init(
            providerModelIDs: [Int],
            providerVTableAddress: UInt32,
            slotOffset: Int = 0x200,
            targetAddress: UInt32,
            targetIndexedInCorpus: Bool,
            callbackReturnValue: UInt8 = 1,
            outputEnvelopes: [ProviderVTableSlot200OutputEnvelope] = []
        ) {
            self.providerModelIDs = providerModelIDs
            self.providerVTableAddress = providerVTableAddress
            self.slotOffset = slotOffset
            self.targetAddress = targetAddress
            self.targetIndexedInCorpus = targetIndexedInCorpus
            self.callbackReturnValue = callbackReturnValue
            self.outputEnvelopes = outputEnvelopes
        }
    }

    public static let providerVTableSlot200Descriptors: [ProviderVTableSlot200Descriptor] = [
        .init(
            providerModelIDs: [72, 73],
            providerVTableAddress: 0x007B5EB4,
            targetAddress: 0x0051BB60,
            targetIndexedInCorpus: false,
            outputEnvelopes: [
                .init(outputWord0: 0x4C55, outputWord1: 4, outputWord2: 100),
            ]
        ),
        .init(
            providerModelIDs: [207],
            providerVTableAddress: 0x007B6114,
            targetAddress: 0x0051BCD0,
            targetIndexedInCorpus: false,
            outputEnvelopes: [
                .init(outputWord0: 0x4C1E, outputWord1: 4, outputWord2: 88),
            ]
        ),
        .init(
            providerModelIDs: [208],
            providerVTableAddress: 0x007B6374,
            targetAddress: 0x0051BDE0,
            targetIndexedInCorpus: false,
            outputEnvelopes: [
                .init(outputWord0: 0x4C03, outputWord1: 4, outputWord2: 80),
            ]
        ),
        .init(
            providerModelIDs: [211],
            providerVTableAddress: 0x007ACEDC,
            targetAddress: 0x0048B030,
            targetIndexedInCorpus: false,
            outputEnvelopes: [
                .init(
                    objectWord2EIsNonZero: true,
                    outputWord0: 0x4C67,
                    outputWord1: 4,
                    outputWord2: 100
                ),
                .init(
                    objectWord2EIsNonZero: false,
                    outputWord0: 0x4C69,
                    outputWord1: 0,
                    outputWord2: 100
                ),
            ]
        ),
        .init(
            providerModelIDs: [212],
            providerVTableAddress: 0x007AD140,
            targetAddress: 0x0048B1E0,
            targetIndexedInCorpus: false,
            outputEnvelopes: [
                .init(
                    objectWord2EIsNonZero: true,
                    outputWord0: 0x4C94,
                    outputWord1: 4,
                    outputWord2: 80
                ),
                .init(
                    objectWord2EIsNonZero: false,
                    outputWord0: 0x4C96,
                    outputWord1: 0,
                    outputWord2: 80
                ),
            ]
        ),
        .init(
            providerModelIDs: [213],
            providerVTableAddress: 0x007AD3A4,
            targetAddress: 0x0048B3D0,
            targetIndexedInCorpus: false,
            outputEnvelopes: [
                .init(
                    objectWord2EIsNonZero: true,
                    outputWord0: 0x4C6B,
                    outputWord1: 4,
                    outputWord2: 100
                ),
                .init(
                    objectWord2EIsNonZero: false,
                    outputWord0: 0x4C6D,
                    outputWord1: 0,
                    outputWord2: 100
                ),
            ]
        ),
    ]

    public static func providerVTableSlot200Descriptor(
        forProviderModelID providerModelID: Int
    ) -> ProviderVTableSlot200Descriptor? {
        providerVTableSlot200Descriptors.first {
            $0.providerModelIDs.contains(providerModelID)
        }
    }

    /// The shared provider figure-spawn target in vtable slot `+0x234`.
    ///
    /// Direct reads of the canonical EN/CH vtables show that Well,
    /// Herbalist, Acupuncture, Music, Acrobat, and Drama all point this slot
    /// at `FUN_0051CF90 @ 0x51CF90`.  The common routine still depends on
    /// unresolved provider callbacks, registry ownership, figure routing,
    /// and coverage/settlement consumers; this catalog is therefore raw
    /// evidence only and must not enable Qin provider spawning.
    public struct ProviderVTableSlot234Descriptor: Sendable, Hashable, Codable {
        public let providerModelIDs: [Int]
        public let providerVTableAddress: UInt32
        public let slotOffset: Int
        public let targetAddress: UInt32
        public let targetIndexedInCorpus: Bool

        public init(
            providerModelIDs: [Int],
            providerVTableAddress: UInt32,
            slotOffset: Int = 0x234,
            targetAddress: UInt32,
            targetIndexedInCorpus: Bool
        ) {
            self.providerModelIDs = providerModelIDs
            self.providerVTableAddress = providerVTableAddress
            self.slotOffset = slotOffset
            self.targetAddress = targetAddress
            self.targetIndexedInCorpus = targetIndexedInCorpus
        }
    }

    public static let providerVTableSlot234Descriptors: [ProviderVTableSlot234Descriptor] = [
        .init(
            providerModelIDs: [72, 73],
            providerVTableAddress: 0x007B5EB4,
            targetAddress: 0x0051CF90,
            targetIndexedInCorpus: true
        ),
        .init(
            providerModelIDs: [207],
            providerVTableAddress: 0x007B6114,
            targetAddress: 0x0051CF90,
            targetIndexedInCorpus: true
        ),
        .init(
            providerModelIDs: [208],
            providerVTableAddress: 0x007B6374,
            targetAddress: 0x0051CF90,
            targetIndexedInCorpus: true
        ),
        .init(
            providerModelIDs: [211],
            providerVTableAddress: 0x007ACEDC,
            targetAddress: 0x0051CF90,
            targetIndexedInCorpus: true
        ),
        .init(
            providerModelIDs: [212],
            providerVTableAddress: 0x007AD140,
            targetAddress: 0x0051CF90,
            targetIndexedInCorpus: true
        ),
        .init(
            providerModelIDs: [213],
            providerVTableAddress: 0x007AD3A4,
            targetAddress: 0x0051CF90,
            targetIndexedInCorpus: true
        ),
    ]

    public static func providerVTableSlot234Descriptor(
        forProviderModelID providerModelID: Int
    ) -> ProviderVTableSlot234Descriptor? {
        providerVTableSlot234Descriptors.first {
            $0.providerModelIDs.contains(providerModelID)
        }
    }

    /// Provider-vtable threshold method targets in slot `+0x230`.
    ///
    /// The six provider families do not share one threshold body: direct
    /// canonical EN/CH vtable reads select three residential methods and two
    /// entertainment methods.  Well's `0x51BAE0` additionally calls the
    /// provider's raw `+0x224` virtual slot and doubles its input when that
    /// callback returns non-zero.  This is executable metadata only; the
    /// callback input and all provider/figure side effects remain unresolved.
    public struct ProviderVTableSlot230Descriptor: Sendable, Hashable, Codable {
        public let providerModelIDs: [Int]
        public let providerVTableAddress: UInt32
        public let slotOffset: Int
        public let targetAddress: UInt32
        public let targetIndexedInCorpus: Bool
        public let doublesInputWhenVTable224ReturnsNonZero: Bool

        public init(
            providerModelIDs: [Int],
            providerVTableAddress: UInt32,
            slotOffset: Int = 0x230,
            targetAddress: UInt32,
            targetIndexedInCorpus: Bool,
            doublesInputWhenVTable224ReturnsNonZero: Bool = false
        ) {
            self.providerModelIDs = providerModelIDs
            self.providerVTableAddress = providerVTableAddress
            self.slotOffset = slotOffset
            self.targetAddress = targetAddress
            self.targetIndexedInCorpus = targetIndexedInCorpus
            self.doublesInputWhenVTable224ReturnsNonZero =
                doublesInputWhenVTable224ReturnsNonZero
        }
    }

    public static let providerVTableSlot230Descriptors: [ProviderVTableSlot230Descriptor] = [
        .init(
            providerModelIDs: [72, 73],
            providerVTableAddress: 0x007B5EB4,
            targetAddress: 0x0051BAE0,
            targetIndexedInCorpus: false,
            doublesInputWhenVTable224ReturnsNonZero: true
        ),
        .init(
            providerModelIDs: [207],
            providerVTableAddress: 0x007B6114,
            targetAddress: 0x00507E40,
            targetIndexedInCorpus: false
        ),
        .init(
            providerModelIDs: [208],
            providerVTableAddress: 0x007B6374,
            targetAddress: 0x0051CF40,
            targetIndexedInCorpus: false
        ),
        .init(
            providerModelIDs: [211],
            providerVTableAddress: 0x007ACEDC,
            targetAddress: 0x005AB330,
            targetIndexedInCorpus: false
        ),
        .init(
            providerModelIDs: [212],
            providerVTableAddress: 0x007AD140,
            targetAddress: 0x005AB330,
            targetIndexedInCorpus: false
        ),
        .init(
            providerModelIDs: [213],
            providerVTableAddress: 0x007AD3A4,
            targetAddress: 0x0048B380,
            targetIndexedInCorpus: false
        ),
    ]

    public static func providerVTableSlot230Descriptor(
        forProviderModelID providerModelID: Int
    ) -> ProviderVTableSlot230Descriptor? {
        providerVTableSlot230Descriptors.first {
            $0.providerModelIDs.contains(providerModelID)
        }
    }

    /// MFC runtime-class records recovered from the canonical provider
    /// executables.  These are registration metadata only: the generic Qin
    /// map loader still requests `Building`, and these descriptors must not
    /// be used to specialize an archive record or assign a provider slot.
    public struct ProviderRuntimeClassDescriptor: Sendable, Hashable, Codable {
        public let className: String
        public let runtimeClassAddress: UInt32
        public let objectSize: Int
        public let createObjectAddress: UInt32
        public let baseClassAddress: UInt32
        public let runtimeClassAccessorAddress: UInt32
        public let buildingModelIDs: [Int]

        public init(
            className: String,
            runtimeClassAddress: UInt32,
            objectSize: Int,
            createObjectAddress: UInt32,
            baseClassAddress: UInt32,
            runtimeClassAccessorAddress: UInt32,
            buildingModelIDs: [Int]
        ) {
            self.className = className
            self.runtimeClassAddress = runtimeClassAddress
            self.objectSize = objectSize
            self.createObjectAddress = createObjectAddress
            self.baseClassAddress = baseClassAddress
            self.runtimeClassAccessorAddress = runtimeClassAccessorAddress
            self.buildingModelIDs = buildingModelIDs
        }
    }

    /// Exact provider records at `.data` `0x854330`, `0x854348`, and
    /// `0x854360`.  The shared base descriptor is `cIndustrialBldg` at
    /// `0x854438`; the constructors allocate `0x150` bytes.
    public static let providerRuntimeClassDescriptors: [ProviderRuntimeClassDescriptor] = [
        .init(
            className: "cAcupuncturistBldg",
            runtimeClassAddress: 0x00854330,
            objectSize: 0x150,
            createObjectAddress: 0x0051B8A0,
            baseClassAddress: 0x00854438,
            runtimeClassAccessorAddress: 0x0051B900,
            buildingModelIDs: [208]
        ),
        .init(
            className: "cHerbalistBldg",
            runtimeClassAddress: 0x00854348,
            objectSize: 0x150,
            createObjectAddress: 0x0051B930,
            baseClassAddress: 0x00854438,
            runtimeClassAccessorAddress: 0x0051B990,
            buildingModelIDs: [207]
        ),
        .init(
            className: "cWellBldg",
            runtimeClassAddress: 0x00854360,
            objectSize: 0x150,
            createObjectAddress: 0x0051B9C0,
            baseClassAddress: 0x00854438,
            runtimeClassAccessorAddress: 0x0051BA20,
            buildingModelIDs: [72, 73]
        ),
    ]

    public static func providerRuntimeClassDescriptor(
        forBuildingModelID buildingModelID: Int
    ) -> ProviderRuntimeClassDescriptor? {
        providerRuntimeClassDescriptors.first {
            $0.buildingModelIDs.contains(buildingModelID)
        }
    }

    /// MFC runtime-class records for the entertainment family recovered from
    /// the canonical EN/CH `.data` table at `0x82BC58…0x82BD2F`.  These are
    /// registration metadata only.  The Qin map archive still declares and
    /// reads `Building` records, so this table must not specialize an archive
    /// row, allocate a venue, or assign a provider registry slot.
    public struct EntertainmentRuntimeClassDescriptor: Sendable, Hashable, Codable {
        public let className: String
        public let runtimeClassAddress: UInt32
        public let objectSize: Int
        public let createObjectAddress: UInt32
        public let baseClassAddress: UInt32
        public let buildingModelIDs: [Int]

        public init(
            className: String,
            runtimeClassAddress: UInt32,
            objectSize: Int,
            createObjectAddress: UInt32,
            baseClassAddress: UInt32,
            buildingModelIDs: [Int]
        ) {
            self.className = className
            self.runtimeClassAddress = runtimeClassAddress
            self.objectSize = objectSize
            self.createObjectAddress = createObjectAddress
            self.baseClassAddress = baseClassAddress
            self.buildingModelIDs = buildingModelIDs
        }
    }

    /// Exact entertainment-family runtime records.  Empty model-ID lists are
    /// intentional for abstract/base classes and the transient spectator
    /// record; they do not authorize mapping those records to a building.
    public static let entertainmentRuntimeClassDescriptors: [EntertainmentRuntimeClassDescriptor] = [
        .init(
            className: "cEntertainmentBldg",
            runtimeClassAddress: 0x0082BC70,
            objectSize: 0x150,
            createObjectAddress: 0x0048A750,
            baseClassAddress: 0x00854438,
            buildingModelIDs: []
        ),
        .init(
            className: "cMusicSchool",
            runtimeClassAddress: 0x0082BC88,
            objectSize: 0x150,
            createObjectAddress: 0x0048AF60,
            baseClassAddress: 0x0082BC70,
            buildingModelIDs: [211]
        ),
        .init(
            className: "cAcrobatSchool",
            runtimeClassAddress: 0x0082BCA0,
            objectSize: 0x150,
            createObjectAddress: 0x0048B110,
            baseClassAddress: 0x0082BC70,
            buildingModelIDs: [212]
        ),
        .init(
            className: "cDramaSchool",
            runtimeClassAddress: 0x0082BCB8,
            objectSize: 0x150,
            createObjectAddress: 0x0048B2C0,
            baseClassAddress: 0x0082BC70,
            buildingModelIDs: [213]
        ),
        .init(
            className: "cEntertainmentVenue",
            runtimeClassAddress: 0x0082BCD0,
            objectSize: 0x150,
            createObjectAddress: 0x0048B4B0,
            baseClassAddress: 0x0082BC70,
            buildingModelIDs: []
        ),
        .init(
            className: "cTheatre",
            runtimeClassAddress: 0x0082BCE8,
            objectSize: 0x184,
            createObjectAddress: 0x0048BA10,
            baseClassAddress: 0x0082BCD0,
            buildingModelIDs: [75]
        ),
        .init(
            className: "cTheatreSpectator",
            runtimeClassAddress: 0x0082BD00,
            objectSize: 0x10,
            createObjectAddress: 0x0048BAF0,
            baseClassAddress: 0x007CD140,
            buildingModelIDs: []
        ),
        .init(
            className: "cEntertainmentSquare",
            runtimeClassAddress: 0x0082BD18,
            objectSize: 0x230,
            createObjectAddress: 0x0048CA80,
            baseClassAddress: 0x0082BCD0,
            buildingModelIDs: [71]
        ),
    ]

    public static func entertainmentRuntimeClassDescriptor(
        forBuildingModelID buildingModelID: Int
    ) -> EntertainmentRuntimeClassDescriptor? {
        entertainmentRuntimeClassDescriptors.first {
            $0.buildingModelIDs.contains(buildingModelID)
        }
    }

    /// Accessor/registration thunks for the same entertainment runtime-class
    /// records.  The thunks pass the record address to the common MFC runtime
    /// registry helper; they are kept separate from the class hierarchy so a
    /// caller cannot mistake registration for map-object specialization.
    public struct EntertainmentRuntimeClassRegistrationDescriptor: Sendable, Hashable, Codable {
        public let className: String
        public let runtimeClassAddress: UInt32
        public let accessorAddress: UInt32
        public let registrationThunkAddress: UInt32

        public init(
            className: String,
            runtimeClassAddress: UInt32,
            accessorAddress: UInt32,
            registrationThunkAddress: UInt32
        ) {
            self.className = className
            self.runtimeClassAddress = runtimeClassAddress
            self.accessorAddress = accessorAddress
            self.registrationThunkAddress = registrationThunkAddress
        }
    }

    public static let entertainmentRuntimeClassRegistrationHelperAddress: UInt32 = 0x0040AA80
    public static let entertainmentRuntimeClassRegistrationDescriptors: [EntertainmentRuntimeClassRegistrationDescriptor] = [
        .init(className: "cEntertainmentBldg", runtimeClassAddress: 0x0082BC70, accessorAddress: 0x0048A7B0, registrationThunkAddress: 0x0048A7C0),
        .init(className: "cMusicSchool", runtimeClassAddress: 0x0082BC88, accessorAddress: 0x0048AFC0, registrationThunkAddress: 0x0048AFD0),
        .init(className: "cAcrobatSchool", runtimeClassAddress: 0x0082BCA0, accessorAddress: 0x0048B170, registrationThunkAddress: 0x0048B180),
        .init(className: "cDramaSchool", runtimeClassAddress: 0x0082BCB8, accessorAddress: 0x0048B320, registrationThunkAddress: 0x0048B330),
        .init(className: "cEntertainmentVenue", runtimeClassAddress: 0x0082BCD0, accessorAddress: 0x0048B510, registrationThunkAddress: 0x0048B520),
        .init(className: "cTheatre", runtimeClassAddress: 0x0082BCE8, accessorAddress: 0x0048BA70, registrationThunkAddress: 0x0048BA80),
        .init(className: "cTheatreSpectator", runtimeClassAddress: 0x0082BD00, accessorAddress: 0x0048BB50, registrationThunkAddress: 0x0048BB60),
        .init(className: "cEntertainmentSquare", runtimeClassAddress: 0x0082BD18, accessorAddress: 0x0048CAE0, registrationThunkAddress: 0x0048CAF0),
    ]

    /// Concrete targets recovered for provider vtable slot `+0x268`.
    ///
    /// The slot is polymorphic in the executable: its callers use the return
    /// value with different conventions, so these addresses are target
    /// metadata only.  In particular, this catalog must not be interpreted as
    /// a universal occupancy predicate, serializer, registry writer, or live
    /// provider callback.  `0x51C3A0` is a real EN/CH target body recovered
    /// from the PE bytes but is not emitted as a split-corpus function.
    public struct ProviderVTableSlotDescriptor: Sendable, Hashable, Codable {
        public let providerModelIDs: [Int]
        public let providerVTableAddress: UInt32
        public let slotOffset: Int
        public let targetAddress: UInt32
        public let targetIndexedInCorpus: Bool

        public init(
            providerModelIDs: [Int],
            providerVTableAddress: UInt32,
            slotOffset: Int,
            targetAddress: UInt32,
            targetIndexedInCorpus: Bool
        ) {
            self.providerModelIDs = providerModelIDs
            self.providerVTableAddress = providerVTableAddress
            self.slotOffset = slotOffset
            self.targetAddress = targetAddress
            self.targetIndexedInCorpus = targetIndexedInCorpus
        }
    }

    public static let providerVTableSlot268Descriptors: [ProviderVTableSlotDescriptor] = [
        .init(
            providerModelIDs: [72, 73],
            providerVTableAddress: 0x007B5EB4,
            slotOffset: 0x268,
            targetAddress: 0x0051CE00,
            targetIndexedInCorpus: true
        ),
        .init(
            providerModelIDs: [207],
            providerVTableAddress: 0x007B6114,
            slotOffset: 0x268,
            targetAddress: 0x0051CE00,
            targetIndexedInCorpus: true
        ),
        .init(
            providerModelIDs: [208],
            providerVTableAddress: 0x007B6374,
            slotOffset: 0x268,
            targetAddress: 0x0051C3A0,
            targetIndexedInCorpus: false
        ),
    ]

    public static func providerVTableSlot268Descriptor(
        forProviderModelID providerModelID: Int
    ) -> ProviderVTableSlotDescriptor? {
        providerVTableSlot268Descriptors.first {
            $0.providerModelIDs.contains(providerModelID)
        }
    }

    /// Raw construction shape of the auxiliary object created by the
    /// provider load callback (`FUN_0051CB80 @ 0x51CB80`).  The executable
    /// allocates 0x20 bytes, constructs `FUN_00526830` with the provider's
    /// `+0xB4` word, stores the resulting pointer at provider `+0x14C`, and
    /// then dispatches the provider vtable `+0x1FC` method.  These fields are
    /// executable-layout evidence only: the auxiliary object's semantic
    /// ownership, archive source, and registry/house projection are unknown,
    /// so Native must not manufacture this object for Qin map records.
    public struct ProviderLoadAuxiliaryDescriptor: Sendable, Hashable, Codable {
        public let loadCallbackAddress: UInt32
        public let genericLoadCallbackAddress: UInt32
        public let globalGateAddress: UInt32
        public let auxiliaryFactoryAddress: UInt32
        public let auxiliaryDestructorAddress: UInt32
        public let auxiliaryReleaseInitializerAddress: UInt32
        public let auxiliaryAllocationSize: Int
        public let auxiliaryBaseConstructorAddress: UInt32
        public let auxiliaryBaseVTableAddress: UInt32
        public let auxiliaryDerivedVTableAddress: UInt32
        public let auxiliaryStoredInputOffset: Int
        public let providerAuxiliaryFieldOffset: Int
        public let providerCallbackVTableMethodOffset: Int
        /// Interior provider-vtable target used by the `+0x1FC` callback.
        /// The target reads `providerAuxiliaryFieldOffset`, and only when the
        /// stored auxiliary pointer is non-null dispatches the auxiliary
        /// refresh initializer below.  This is a raw lifecycle gate, not a
        /// provider-registry or map-projection operation.
        public let providerAuxiliaryUpdateAddress: UInt32
        public let auxiliaryRefreshInitializerAddress: UInt32

        public init(
            loadCallbackAddress: UInt32,
            genericLoadCallbackAddress: UInt32,
            globalGateAddress: UInt32,
            auxiliaryFactoryAddress: UInt32,
            auxiliaryDestructorAddress: UInt32,
            auxiliaryReleaseInitializerAddress: UInt32,
            auxiliaryAllocationSize: Int,
            auxiliaryBaseConstructorAddress: UInt32,
            auxiliaryBaseVTableAddress: UInt32,
            auxiliaryDerivedVTableAddress: UInt32,
            auxiliaryStoredInputOffset: Int,
            providerAuxiliaryFieldOffset: Int,
            providerCallbackVTableMethodOffset: Int,
            providerAuxiliaryUpdateAddress: UInt32,
            auxiliaryRefreshInitializerAddress: UInt32
        ) {
            self.loadCallbackAddress = loadCallbackAddress
            self.genericLoadCallbackAddress = genericLoadCallbackAddress
            self.globalGateAddress = globalGateAddress
            self.auxiliaryFactoryAddress = auxiliaryFactoryAddress
            self.auxiliaryDestructorAddress = auxiliaryDestructorAddress
            self.auxiliaryReleaseInitializerAddress = auxiliaryReleaseInitializerAddress
            self.auxiliaryAllocationSize = auxiliaryAllocationSize
            self.auxiliaryBaseConstructorAddress = auxiliaryBaseConstructorAddress
            self.auxiliaryBaseVTableAddress = auxiliaryBaseVTableAddress
            self.auxiliaryDerivedVTableAddress = auxiliaryDerivedVTableAddress
            self.auxiliaryStoredInputOffset = auxiliaryStoredInputOffset
            self.providerAuxiliaryFieldOffset = providerAuxiliaryFieldOffset
            self.providerCallbackVTableMethodOffset = providerCallbackVTableMethodOffset
            self.providerAuxiliaryUpdateAddress = providerAuxiliaryUpdateAddress
            self.auxiliaryRefreshInitializerAddress = auxiliaryRefreshInitializerAddress
        }
    }

    public static let providerLoadAuxiliaryDescriptor = ProviderLoadAuxiliaryDescriptor(
        loadCallbackAddress: 0x0051CB80,
        genericLoadCallbackAddress: 0x004271B0,
        globalGateAddress: 0x00426D10,
        auxiliaryFactoryAddress: 0x00526830,
        auxiliaryDestructorAddress: 0x00526850,
        auxiliaryReleaseInitializerAddress: 0x00526870,
        auxiliaryAllocationSize: 0x20,
        auxiliaryBaseConstructorAddress: 0x00418D70,
        auxiliaryBaseVTableAddress: 0x007AB3F4,
        auxiliaryDerivedVTableAddress: 0x007B6B3C,
        auxiliaryStoredInputOffset: 0x14,
        providerAuxiliaryFieldOffset: 0x14C,
        providerCallbackVTableMethodOffset: 0x1FC,
        providerAuxiliaryUpdateAddress: 0x0051CC10,
        auxiliaryRefreshInitializerAddress: 0x00418D90
    )

    /// Complete direct `E8` call-site census for `FUN_0051CB80 @ 0x51CB80`
    /// recovered from both canonical PE `.text` sections. The callsites are
    /// construction/lifecycle wrappers (some are split entry points that
    /// Ghidra does not emit as a named call in the merged C corpus). The
    /// generic map loader has no direct edge to this callback; an
    /// indirect/table-driven edge remains unresolved and must not be
    /// synthesized from Qin archive records.
    public static let providerLoadCallbackDirectCallSiteAddresses: [UInt32] = [
        0x0048B678,
        0x004C1778,
        0x004C3068,
        0x00524368,
        0x0054118B,
        0x005AB1F8,
        0x005D4868,
        0x005F11A8,
    ]

    /// Result of one provider-load callback (`FUN_0051CB80 @ 0x51CB80`)
    /// after its already-resolved inputs are supplied.  This load callback
    /// dispatches the generic object callback before its global gate; only an
    /// open gate attempts the 0x20-byte auxiliary allocation.  A
    /// failed allocation leaves the provider field and callback untouched.
    /// This is a field/order primitive only: it does not allocate an object,
    /// invoke a vtable, or project a map record into a provider registry.
    public struct ProviderLoadAuxiliaryOutcome: Sendable, Hashable, Codable {
        public let genericLoadCallbackInvoked: Bool
        public let allocationAttempted: Bool
        public let didAllocateAuxiliary: Bool
        public let storedInput: Int?
        public let didInvokeProviderCallback: Bool

        public init(
            genericLoadCallbackInvoked: Bool,
            allocationAttempted: Bool,
            didAllocateAuxiliary: Bool,
            storedInput: Int?,
            didInvokeProviderCallback: Bool
        ) {
            self.genericLoadCallbackInvoked = genericLoadCallbackInvoked
            self.allocationAttempted = allocationAttempted
            self.didAllocateAuxiliary = didAllocateAuxiliary
            self.storedInput = storedInput
            self.didInvokeProviderCallback = didInvokeProviderCallback
        }
    }

    /// Replays the branch/order boundary of `FUN_0051CB80` with explicit
    /// allocation success.  The source first calls `FUN_004271B0`, then tests
    /// `FUN_00426D10(0)`.  When that gate is open it allocates `0x20`, invokes
    /// `FUN_00526830(provider + 0x2D)`, stores the resulting auxiliary pointer
    /// at provider `+0x14C`, and dispatches vtable `+0x1FC`.  The helper
    /// reports only those observable order facts and never invents the
    /// auxiliary object's semantics or registry ownership.
    public static func providerLoadAuxiliaryOutcome(
        globalGateOpen: Bool,
        allocationSucceeded: Bool,
        providerRegistryID: Int
    ) -> ProviderLoadAuxiliaryOutcome {
        let didAllocate = globalGateOpen && allocationSucceeded
        return ProviderLoadAuxiliaryOutcome(
            genericLoadCallbackInvoked: true,
            allocationAttempted: globalGateOpen,
            didAllocateAuxiliary: didAllocate,
            storedInput: didAllocate ? providerRegistryID : nil,
            didInvokeProviderCallback: didAllocate
        )
    }

    /// Concrete residential-provider coverage callbacks recovered from the
    /// model-specific vtables. These are raw dispatch/field descriptors only:
    /// the map-archive specialization, provider registry slot, and target-house
    /// projection remain unresolved, so Native does not invoke them directly.
    public struct ProviderCoverageCallbackDescriptor: Sendable, Hashable, Codable {
        public let providerModelIDs: [Int]
        public let providerVTableAddress: UInt32
        public let callbackAddress: UInt32
        /// Raw `cHouseInfo` byte offsets written by the callback. Well has two
        /// conditional destinations; the other providers have one each.
        public let houseInfoFieldOffsets: [Int]

        public init(
            providerModelIDs: [Int],
            providerVTableAddress: UInt32,
            callbackAddress: UInt32,
            houseInfoFieldOffsets: [Int]
        ) {
            self.providerModelIDs = providerModelIDs
            self.providerVTableAddress = providerVTableAddress
            self.callbackAddress = callbackAddress
            self.houseInfoFieldOffsets = houseInfoFieldOffsets
        }
    }

    public static let providerCoverageCallbackDescriptors: [ProviderCoverageCallbackDescriptor] = [
        .init(
            providerModelIDs: [72, 73],
            providerVTableAddress: 0x007B5EB4,
            callbackAddress: 0x0051BC00,
            houseInfoFieldOffsets: [0x32, 0x34]
        ),
        .init(
            providerModelIDs: [207],
            providerVTableAddress: 0x007B6114,
            callbackAddress: 0x0051BD00,
            houseInfoFieldOffsets: [0x2D]
        ),
        .init(
            providerModelIDs: [208],
            providerVTableAddress: 0x007B6374,
            callbackAddress: 0x0051BD90,
            houseInfoFieldOffsets: [0x2A]
        ),
    ]

    public static func providerCoverageCallbackDescriptor(
        forProviderModelID modelID: Int
    ) -> ProviderCoverageCallbackDescriptor? {
        providerCoverageCallbackDescriptors.first {
            $0.providerModelIDs.contains(modelID)
        }
    }

    /// Dispatch boundary for the three entertainment-school providers.  The
    /// venue figures reach the same radius-2 crossing scanner as the ordinary
    /// residential providers, but the school vtables route `+0x2C` to the
    /// distinct `0x48AD20` callback.  This is evidence metadata only: the
    /// unresolved provider registry, venue route/collision, and settlement
    /// projection are intentionally not invoked by Native.
    public struct EntertainmentCoverageDispatchDescriptor: Sendable, Hashable, Codable {
        public let crossingFunctionAddress: UInt32
        public let radiusWrapperAddress: UInt32
        public let radiusScanAddress: UInt32
        public let providerVTableAddresses: [UInt32]
        public let radiusVTableOffset: UInt32
        public let writerVTableOffset: UInt32
        public let radius: Int
        public let writerAddress: UInt32

        public init(
            crossingFunctionAddress: UInt32,
            radiusWrapperAddress: UInt32,
            radiusScanAddress: UInt32,
            providerVTableAddresses: [UInt32],
            radiusVTableOffset: UInt32,
            writerVTableOffset: UInt32,
            radius: Int,
            writerAddress: UInt32
        ) {
            self.crossingFunctionAddress = crossingFunctionAddress
            self.radiusWrapperAddress = radiusWrapperAddress
            self.radiusScanAddress = radiusScanAddress
            self.providerVTableAddresses = providerVTableAddresses
            self.radiusVTableOffset = radiusVTableOffset
            self.writerVTableOffset = writerVTableOffset
            self.radius = radius
            self.writerAddress = writerAddress
        }

        /// Canonical EN addresses, cross-checked against the byte-identical
        /// CH provider vtables and callback body.
        public static let canonical = Self(
            crossingFunctionAddress: 0x004EACD0,
            radiusWrapperAddress: 0x00429DF0,
            radiusScanAddress: 0x00429E10,
            providerVTableAddresses: [0x007ACEDC, 0x007AD140, 0x007AD3A4],
            radiusVTableOffset: 0x28,
            writerVTableOffset: 0x2C,
            radius: 2,
            writerAddress: 0x0048AD20
        )
    }

    /// Exact single-byte `cHouseInfo` write emitted by the Herbalist and
    /// Acupuncture provider callbacks (`FUN_0051BD00` / `FUN_0051BD90`).
    /// Both callbacks first require the global callback gate, the target
    /// building's `+0xB8` eligibility result, and a strictly positive signed
    /// `cHouseInfo +0x20` population.  The provider object and its registry
    /// projection are intentionally outside this pure research primitive.
    public struct ResidentialProviderHouseCoverageWrite: Sendable, Hashable, Codable {
        /// Destination byte in the target `cHouseInfo` record.
        public let houseInfoOffset: UInt8
        /// Both callbacks store a full 96-slice coverage value.
        public let value: UInt8

        public init(houseInfoOffset: UInt8, value: UInt8 = 0x60) {
            self.houseInfoOffset = houseInfoOffset
            self.value = value
        }
    }

    /// Returns the field/value written by a recovered residential provider
    /// callback.  Unknown provider models and failed source gates produce no
    /// write; this helper never creates or resolves a provider object.
    public static func residentialProviderHouseCoverageWrite(
        providerModelID: Int,
        globalGateOpen: Bool,
        targetIsEligible: Bool,
        targetPopulation: Int
    ) -> ResidentialProviderHouseCoverageWrite? {
        guard globalGateOpen, targetIsEligible, targetPopulation > 0 else {
            return nil
        }
        switch providerModelID {
        case 207:
            return .init(houseInfoOffset: 0x2D)
        case 208:
            return .init(houseInfoOffset: 0x2A)
        default:
            return nil
        }
    }

    /// Raw religion-provider coverage write emitted by `FUN_005AB580`.
    /// The callback has a stricter target-model gate than the other services:
    /// populated houses are models `2...17`, while a non-populated target is
    /// admitted only for elite vacant models `11...17`.  A non-zero provider
    /// restriction byte applies the same elite-only restriction.  The
    /// provider model maps to a `cHouseInfo` field at `0x0D + index` and the
    /// callback stores `0x28`.
    public struct ReligiousHouseCoverageWrite: Sendable, Hashable, Codable {
        public let houseInfoOffset: UInt8
        public let value: UInt8
        public let religionIndex: Int

        public init(houseInfoOffset: UInt8, value: UInt8 = 0x28, religionIndex: Int) {
            self.houseInfoOffset = houseInfoOffset
            self.value = value
            self.religionIndex = religionIndex
        }
    }

    /// Returns the exact religion callback write, or `nil` when any source
    /// admission gate fails.  `targetByte09NonZero` is the raw HouseBldg
    /// `+0x09` gate; `providerRestrictionByteNonZero` is provider `+0x174`.
    public static func religiousHouseCoverageWrite(
        providerModelID: Int,
        globalGateOpen: Bool,
        targetModelID: Int,
        targetByte09NonZero: Bool,
        targetPopulation: Int,
        providerRestrictionByteNonZero: Bool
    ) -> ReligiousHouseCoverageWrite? {
        guard globalGateOpen,
              (2...17).contains(targetModelID),
              targetByte09NonZero else {
            return nil
        }
        let eliteTarget = (11...17).contains(targetModelID)
        guard (targetPopulation > 0 || eliteTarget),
              (!providerRestrictionByteNonZero || eliteTarget) else {
            return nil
        }
        let religionIndex: Int
        switch providerModelID {
        case 214:
            religionIndex = 0
        case 215, 216:
            religionIndex = 1
        case 217, 218:
            religionIndex = 2
        case 219:
            religionIndex = 3
        default:
            return nil
        }
        return .init(
            houseInfoOffset: UInt8(0x0D + religionIndex),
            religionIndex: religionIndex
        )
    }

    /// Raw result of the provider `+0x9C` refresh callback
    /// (`FUN_0051CCA0 @ 0x51CCA0`).  This callback consumes an already-created
    /// provider object: it does not allocate, insert, or assign its registry
    /// slot.  Non-Trading-Quay models increment the per-model counters, while
    /// model 56 is admitted to the ten-entry Trading Quay registry only when
    /// capacity remains.  The staffing value is the raw return from the
    /// provider vtable `+0x1B4` method; its semantic label is unresolved.
    public struct ProviderRegistryRefreshOutcome: Sendable, Hashable, Codable {
        public let modelID: Int
        public let providerRegistryID: Int
        public let modelCountDelta: Int
        public let staffedModelCountDelta: Int
        public let tradingQuayRegistryIDs: [Int]
        public let tradingQuayStaffedCountDelta: Int
        public let didAppendTradingQuayRegistryID: Bool

        public init(
            modelID: Int,
            providerRegistryID: Int,
            modelCountDelta: Int,
            staffedModelCountDelta: Int,
            tradingQuayRegistryIDs: [Int],
            tradingQuayStaffedCountDelta: Int,
            didAppendTradingQuayRegistryID: Bool
        ) {
            self.modelID = modelID
            self.providerRegistryID = providerRegistryID
            self.modelCountDelta = modelCountDelta
            self.staffedModelCountDelta = staffedModelCountDelta
            self.tradingQuayRegistryIDs = tradingQuayRegistryIDs
            self.tradingQuayStaffedCountDelta = tradingQuayStaffedCountDelta
            self.didAppendTradingQuayRegistryID = didAppendTradingQuayRegistryID
        }
    }

    /// Address and field constants for the raw provider-statistics refresh.
    /// These values identify executable storage only; they are not a Native
    /// registry schema and must not be used to synthesize Qin trade state.
    public static let providerRegistryRefreshAddress: UInt32 = 0x0051CCA0
    /// Direct PE callsites that invoke the refresh after an object/provider
    /// record is already live.  These are not map-loader edges and do not
    /// establish how a Qin archive row acquires its `+0xB4` registry value.
    public struct ProviderRegistryRefreshCallsite: Sendable, Hashable, Codable {
        public enum Role: String, Sendable, Hashable, Codable {
            case entertainmentOpportunityDecay
            case objectModelStatisticsRefresh
        }

        public let callsiteAddress: UInt32
        public let callerAddress: UInt32
        public let role: Role

        public init(callsiteAddress: UInt32, callerAddress: UInt32, role: Role) {
            self.callsiteAddress = callsiteAddress
            self.callerAddress = callerAddress
            self.role = role
        }
    }

    public static let providerRegistryRefreshDirectCallsites: [ProviderRegistryRefreshCallsite] = [
        .init(
            callsiteAddress: 0x0048AEB9,
            callerAddress: 0x0048AE30,
            role: .entertainmentOpportunityDecay
        ),
        .init(
            callsiteAddress: 0x004C1288,
            callerAddress: 0x004C1240,
            role: .objectModelStatisticsRefresh
        ),
    ]

    public static func providerRegistryRefreshCallsite(
        at address: UInt32
    ) -> ProviderRegistryRefreshCallsite? {
        providerRegistryRefreshDirectCallsites.first {
            $0.callsiteAddress == address
        }
    }

    public static let providerRegistryModelClassifierAddress: UInt32 = 0x005E1720
    public static let providerModelCountArrayAddress: UInt32 = 0x00A5AF64
    public static let providerStaffedCountArrayAddress: UInt32 = 0x00A5AB30
    public static let tradingQuayRegistryTableAddress: UInt32 = 0x0131249C
    public static let tradingQuayRegistryCountAddress: UInt32 = 0x00A5B044
    public static let tradingQuayStaffedCountAddress: UInt32 = 0x00A5AC10
    /// `param_1[0x2D]` in the decompiler is the byte-oriented view of
    /// object offset `0xB4`.
    public static let providerRegistryFieldOffset: Int = 0x2D
    public static let providerVTableStaffingMethodOffset: Int = 0x1B4
    public static let tradingQuayModelID = 56
    public static let maximumTradingQuayRegistryEntries = 10

    /// Reproduces the counter/table update in `FUN_0051CCA0` for an already
    /// resolved provider object.  The helper returns `nil` for an impossible
    /// pre-existing table longer than the executable's ten-entry bound; it
    /// otherwise exposes only deltas and the updated raw registry IDs.
    public static func refreshProviderRegistry(
        modelID: Int,
        providerRegistryID: Int,
        providerVTableStaffingValue: Int,
        tradingQuayRegistryIDs: [Int]
    ) -> ProviderRegistryRefreshOutcome? {
        guard tradingQuayRegistryIDs.count <= maximumTradingQuayRegistryEntries else {
            return nil
        }

        if modelID == tradingQuayModelID {
            guard tradingQuayRegistryIDs.count < maximumTradingQuayRegistryEntries else {
                return ProviderRegistryRefreshOutcome(
                    modelID: modelID,
                    providerRegistryID: providerRegistryID,
                    modelCountDelta: 0,
                    staffedModelCountDelta: 0,
                    tradingQuayRegistryIDs: tradingQuayRegistryIDs,
                    tradingQuayStaffedCountDelta: 0,
                    didAppendTradingQuayRegistryID: false
                )
            }
            return ProviderRegistryRefreshOutcome(
                modelID: modelID,
                providerRegistryID: providerRegistryID,
                modelCountDelta: 0,
                staffedModelCountDelta: 0,
                tradingQuayRegistryIDs: tradingQuayRegistryIDs + [providerRegistryID],
                tradingQuayStaffedCountDelta: providerVTableStaffingValue > 0 ? 1 : 0,
                didAppendTradingQuayRegistryID: true
            )
        }

        return ProviderRegistryRefreshOutcome(
            modelID: modelID,
            providerRegistryID: providerRegistryID,
            modelCountDelta: 1,
            staffedModelCountDelta: providerVTableStaffingValue > 0 ? 1 : 0,
            tradingQuayRegistryIDs: tradingQuayRegistryIDs,
            tradingQuayStaffedCountDelta: 0,
            didAppendTradingQuayRegistryID: false
        )
    }

    /// The entertainment-provider class factories selected by
    /// `FUN_0051C660 @ 0x51C660` after `FUN_0048A7E0` admits model IDs
    /// `0xD3...0xD5` (211...213).  These are deliberately separate from the
    /// residential service factory table above: the executable uses distinct
    /// object sizes/vtables and a different downstream venue manager.  The
    /// descriptors identify only the recovered constructor and vtable; they
    /// do not assign a map-archive registry slot or enable venue coverage.
    public struct EntertainmentProviderFactoryDescriptor: Sendable, Hashable, Codable {
        public enum Family: String, Sendable, Hashable, Codable {
            case music
            case acrobat
            case drama
        }

        public let family: Family
        public let buildingModelID: Int
        /// Shared dynamic-factory entry that dispatches this family.
        public let dispatcherAddress: UInt32
        /// Model predicate used before the family constructor is selected.
        public let admissionPredicateAddress: UInt32
        /// Allocation size passed to the executable allocator.
        public let allocationSize: Int
        public let initializerAddress: UInt32
        public let vtableAddress: UInt32

        public init(
            family: Family,
            buildingModelID: Int,
            dispatcherAddress: UInt32 = 0x0051C660,
            admissionPredicateAddress: UInt32 = 0x0048A7E0,
            allocationSize: Int = 0x150,
            initializerAddress: UInt32,
            vtableAddress: UInt32
        ) {
            self.family = family
            self.buildingModelID = buildingModelID
            self.dispatcherAddress = dispatcherAddress
            self.admissionPredicateAddress = admissionPredicateAddress
            self.allocationSize = allocationSize
            self.initializerAddress = initializerAddress
            self.vtableAddress = vtableAddress
        }
    }

    public static let entertainmentProviderFactoryDescriptors: [EntertainmentProviderFactoryDescriptor] = [
        .init(
            family: .music,
            buildingModelID: 211,
            initializerAddress: 0x0048A8E0,
            vtableAddress: 0x007ACEDC
        ),
        .init(
            family: .acrobat,
            buildingModelID: 212,
            initializerAddress: 0x0048A900,
            vtableAddress: 0x007AD140
        ),
        .init(
            family: .drama,
            buildingModelID: 213,
            initializerAddress: 0x0048A920,
            vtableAddress: 0x007AD3A4
        ),
    ]

    public static func entertainmentProviderFactoryDescriptor(
        forBuildingModelID buildingModelID: Int
    ) -> EntertainmentProviderFactoryDescriptor? {
        entertainmentProviderFactoryDescriptors.first {
            $0.buildingModelID == buildingModelID
        }
    }

    /// Exact model admission for the entertainment object factory boundary.
    /// `FUN_0048A7E0` admits the three school models directly and delegates
    /// the venue cases to `FUN_0048B540`, whose only true results are model
    /// `0x47` (Entertainment Area, authored ID 71) and `0x4B` (Theatre
    /// Pavilion, authored ID 75).  This is deliberately an admission
    /// predicate only: it does not construct an object, populate the venue
    /// manager, assign a provider registry slot, or enable Qin coverage.
    public static let entertainmentFactoryAdmissionModelIDs: Set<Int> = [
        71, 75, 211, 212, 213
    ]
    public static let entertainmentFactoryAdmissionPredicateAddress: UInt32 =
        0x0048A7E0
    public static let entertainmentVenueAdmissionPredicateAddress: UInt32 =
        0x0048B540

    public static func entertainmentFactoryAdmits(modelID: Int) -> Bool {
        entertainmentFactoryAdmissionModelIDs.contains(modelID)
    }

    /// The recovered entertainment-manager registration edges for venue
    /// objects.  The two venue vtables override both relevant base slots:
    /// their `+0x90` placement callbacks call `FUN_0048B6D0` directly, while
    /// their `+0xC0` load callbacks call base `FUN_0048B670`, which first
    /// dispatches `FUN_0051CB80` and then performs the same manager append.
    /// Both routes reach the manager returned by `FUN_0048A340` through
    /// `FUN_00490300/10`.
    ///
    /// These addresses describe an already-created provider object being
    /// registered.  They do not identify the archive source, create a venue,
    /// assign `object +0x2D`, or enable Qin coverage/settlement.
    public struct EntertainmentManagerRegistrationDescriptor: Sendable, Hashable, Codable {
        public let venueModelIDs: [Int]
        public let baseVTableAddress: UInt32
        public let registrationVTableMethodOffset: Int
        public let registrationCallbackAddress: UInt32
        public let managerAccessorAddress: UInt32
        public let managerAppendWrapperAddress: UInt32
        public let managerVectorEndpointAddress: UInt32
        public let managerVectorAppendAddress: UInt32
        public let venueVTableAddresses: [UInt32]
        public let venuePlacementCallbackAddresses: [UInt32]
        public let venueLoadCallbackAddresses: [UInt32]
        public let loadRegistrationBridgeAddress: UInt32
        public let providerLoadCallbackAddress: UInt32

        public init(
            venueModelIDs: [Int],
            baseVTableAddress: UInt32,
            registrationVTableMethodOffset: Int,
            registrationCallbackAddress: UInt32,
            managerAccessorAddress: UInt32,
            managerAppendWrapperAddress: UInt32,
            managerVectorEndpointAddress: UInt32,
            managerVectorAppendAddress: UInt32,
            venueVTableAddresses: [UInt32],
            venuePlacementCallbackAddresses: [UInt32],
            venueLoadCallbackAddresses: [UInt32],
            loadRegistrationBridgeAddress: UInt32,
            providerLoadCallbackAddress: UInt32
        ) {
            self.venueModelIDs = venueModelIDs
            self.baseVTableAddress = baseVTableAddress
            self.registrationVTableMethodOffset = registrationVTableMethodOffset
            self.registrationCallbackAddress = registrationCallbackAddress
            self.managerAccessorAddress = managerAccessorAddress
            self.managerAppendWrapperAddress = managerAppendWrapperAddress
            self.managerVectorEndpointAddress = managerVectorEndpointAddress
            self.managerVectorAppendAddress = managerVectorAppendAddress
            self.venueVTableAddresses = venueVTableAddresses
            self.venuePlacementCallbackAddresses = venuePlacementCallbackAddresses
            self.venueLoadCallbackAddresses = venueLoadCallbackAddresses
            self.loadRegistrationBridgeAddress = loadRegistrationBridgeAddress
            self.providerLoadCallbackAddress = providerLoadCallbackAddress
        }
    }

    public static let entertainmentManagerRegistrationDescriptor =
        EntertainmentManagerRegistrationDescriptor(
            venueModelIDs: [71, 75],
            baseVTableAddress: 0x007ADE08,
            registrationVTableMethodOffset: 0x90,
            registrationCallbackAddress: 0x0048B6D0,
            managerAccessorAddress: 0x0048A340,
            managerAppendWrapperAddress: 0x00490300,
            managerVectorEndpointAddress: 0x004F8200,
            managerVectorAppendAddress: 0x005F01F0,
            venueVTableAddresses: [0x007AD878, 0x007AD608],
            venuePlacementCallbackAddresses: [0x0048D6D0, 0x0048C270],
            venueLoadCallbackAddresses: [0x0048D780, 0x0048BCB0],
            loadRegistrationBridgeAddress: 0x0048B670,
            providerLoadCallbackAddress: 0x0051CB80
        )

    /// Venue object storage and post-load refresh shape recovered from the
    /// venue load/placement callbacks.  The offsets are raw object offsets;
    /// the auxiliary objects' semantic fields are not named here.  This is
    /// evidence for an already-created venue instance only and must not be
    /// used to synthesize Qin objects from generic archive rows.
    public struct EntertainmentVenueLifecycleDescriptor: Sendable, Hashable, Codable {
        public let venueModelID: Int
        public let objectSize: Int
        public let auxiliaryObjectOffsets: [Int]
        public let auxiliaryConstructorAddresses: [UInt32]
        public let providerRecordPointerArrayOffset: Int?
        public let providerRecordCount: Int
        public let providerRecordPointerStride: Int
        public let providerRecordConstructorAddress: UInt32?
        public let providerRecordObjectSize: Int?
        public let providerRecordPayloadSize: Int?
        public let refreshVTableMethodOffset: Int
        public let refreshCallbackAddress: UInt32

        public init(
            venueModelID: Int,
            objectSize: Int,
            auxiliaryObjectOffsets: [Int],
            auxiliaryConstructorAddresses: [UInt32],
            providerRecordPointerArrayOffset: Int?,
            providerRecordCount: Int,
            providerRecordPointerStride: Int,
            providerRecordConstructorAddress: UInt32?,
            providerRecordObjectSize: Int?,
            providerRecordPayloadSize: Int?,
            refreshVTableMethodOffset: Int,
            refreshCallbackAddress: UInt32
        ) {
            self.venueModelID = venueModelID
            self.objectSize = objectSize
            self.auxiliaryObjectOffsets = auxiliaryObjectOffsets
            self.auxiliaryConstructorAddresses = auxiliaryConstructorAddresses
            self.providerRecordPointerArrayOffset = providerRecordPointerArrayOffset
            self.providerRecordCount = providerRecordCount
            self.providerRecordPointerStride = providerRecordPointerStride
            self.providerRecordConstructorAddress = providerRecordConstructorAddress
            self.providerRecordObjectSize = providerRecordObjectSize
            self.providerRecordPayloadSize = providerRecordPayloadSize
            self.refreshVTableMethodOffset = refreshVTableMethodOffset
            self.refreshCallbackAddress = refreshCallbackAddress
        }
    }

    public static let entertainmentVenueLifecycleDescriptors: [EntertainmentVenueLifecycleDescriptor] = [
        .init(
            venueModelID: 71,
            objectSize: 0x230,
            auxiliaryObjectOffsets: [0x228, 0x22C],
            auxiliaryConstructorAddresses: [0x0048DC20, 0x0048DB40],
            providerRecordPointerArrayOffset: nil,
            providerRecordCount: 0,
            providerRecordPointerStride: 0,
            providerRecordConstructorAddress: nil,
            providerRecordObjectSize: nil,
            providerRecordPayloadSize: nil,
            refreshVTableMethodOffset: 0x27C,
            refreshCallbackAddress: 0x0048CE40
        ),
        .init(
            venueModelID: 75,
            objectSize: 0x184,
            auxiliaryObjectOffsets: [0x150, 0x154, 0x158],
            auxiliaryConstructorAddresses: [0x0048DC20, 0x0048DB40, 0x0048DD70],
            providerRecordPointerArrayOffset: 0x15C,
            providerRecordCount: 10,
            providerRecordPointerStride: 4,
            providerRecordConstructorAddress: 0x00490450,
            providerRecordObjectSize: 0x10,
            providerRecordPayloadSize: 0x24,
            refreshVTableMethodOffset: 0x268,
            refreshCallbackAddress: 0x0048C230
        ),
    ]

    /// Shared state callbacks installed by the three entertainment-school
    /// vtables.  The offsets are intentionally raw: the executable's field
    /// meanings are not recovered, so this descriptor must not be treated as
    /// a school staffing or household-settlement implementation.
    public struct EntertainmentSchoolStateDescriptor: Sendable, Hashable, Codable {
        public let schoolModelIDs: [Int]
        public let vtableAddresses: [UInt32]
        public let resetCallbackAddress: UInt32
        public let decayCallbackAddress: UInt32
        public let stateAccessorMethodOffset: Int
        public let resetWordOffsets: [Int]
        public let resetByteOffsets: [Int]
        public let totalByteOffset: Int
        public let globalUpdateAddress: UInt32
        public let phase24UpdateCallbackAddress: UInt32
        public let phase24GuardCallbackAddress: UInt32
        public let phase24ActionCallbackAddresses: [UInt32]
        public let phase24ThresholdLookupAddress: UInt32
        public let phase24ThresholdFieldIndex: Int
        public let phase24ThresholdValuesByModelID: [Int: Int]

        public init(
            schoolModelIDs: [Int],
            vtableAddresses: [UInt32],
            resetCallbackAddress: UInt32,
            decayCallbackAddress: UInt32,
            stateAccessorMethodOffset: Int,
            resetWordOffsets: [Int],
            resetByteOffsets: [Int],
            totalByteOffset: Int,
            globalUpdateAddress: UInt32,
            phase24UpdateCallbackAddress: UInt32,
            phase24GuardCallbackAddress: UInt32,
            phase24ActionCallbackAddresses: [UInt32],
            phase24ThresholdLookupAddress: UInt32,
            phase24ThresholdFieldIndex: Int,
            phase24ThresholdValuesByModelID: [Int: Int]
        ) {
            self.schoolModelIDs = schoolModelIDs
            self.vtableAddresses = vtableAddresses
            self.resetCallbackAddress = resetCallbackAddress
            self.decayCallbackAddress = decayCallbackAddress
            self.stateAccessorMethodOffset = stateAccessorMethodOffset
            self.resetWordOffsets = resetWordOffsets
            self.resetByteOffsets = resetByteOffsets
            self.totalByteOffset = totalByteOffset
            self.globalUpdateAddress = globalUpdateAddress
            self.phase24UpdateCallbackAddress = phase24UpdateCallbackAddress
            self.phase24GuardCallbackAddress = phase24GuardCallbackAddress
            self.phase24ActionCallbackAddresses = phase24ActionCallbackAddresses
            self.phase24ThresholdLookupAddress = phase24ThresholdLookupAddress
            self.phase24ThresholdFieldIndex = phase24ThresholdFieldIndex
            self.phase24ThresholdValuesByModelID = phase24ThresholdValuesByModelID
        }
    }

    public static let entertainmentSchoolStateDescriptor = EntertainmentSchoolStateDescriptor(
        schoolModelIDs: [211, 212, 213],
        vtableAddresses: [0x007ACEDC, 0x007AD140, 0x007AD3A4],
        resetCallbackAddress: 0x0048ADC0,
        decayCallbackAddress: 0x0048AE30,
        stateAccessorMethodOffset: 0x1E8,
        resetWordOffsets: [0x4E, 0x50, 0x52, 0x54],
        resetByteOffsets: [0x5D, 0x5E, 0x5F],
        totalByteOffset: 0x5C,
        globalUpdateAddress: 0x0051CCA0,
        phase24UpdateCallbackAddress: 0x0051CEC0,
        phase24GuardCallbackAddress: 0x0051CE70,
        phase24ActionCallbackAddresses: [0x004E1C20, 0x004E1C20],
        phase24ThresholdLookupAddress: 0x0044CC50,
        phase24ThresholdFieldIndex: 10,
        phase24ThresholdValuesByModelID: [211: 0, 212: 0, 213: 0]
    )

    public static func entertainmentVenueLifecycleDescriptor(
        forVenueModelID venueModelID: Int
    ) -> EntertainmentVenueLifecycleDescriptor? {
        entertainmentVenueLifecycleDescriptors.first {
            $0.venueModelID == venueModelID
        }
    }

    /// The venue-class virtual slot at `+0x280` is not a shared callback.
    /// Direct EN/CH vtable reads resolve Theatre Pavilion to its
    /// serialization callback and Entertainment Area to its runtime figure
    /// bootstrap callback. This is dispatch metadata only: it does not
    /// specialize a generic Qin archive row or invoke either callback.
    public enum EntertainmentVenueVTable280Role: String, Sendable, Hashable, Codable {
        case serialization
        case figureBootstrap
    }

    public struct EntertainmentVenueVTable280Descriptor: Sendable, Hashable, Codable {
        public let venueModelID: Int
        public let vtableAddress: UInt32
        public let callbackAddress: UInt32
        public let role: EntertainmentVenueVTable280Role

        public init(
            venueModelID: Int,
            vtableAddress: UInt32,
            callbackAddress: UInt32,
            role: EntertainmentVenueVTable280Role
        ) {
            self.venueModelID = venueModelID
            self.vtableAddress = vtableAddress
            self.callbackAddress = callbackAddress
            self.role = role
        }
    }

    public static let entertainmentVenueVTable280Offset: UInt32 = 0x00000280
    public static let entertainmentVenueVTable280Descriptors: [EntertainmentVenueVTable280Descriptor] = [
        .init(
            venueModelID: 71,
            vtableAddress: 0x007AD878,
            callbackAddress: 0x0048CE90,
            role: .figureBootstrap
        ),
        .init(
            venueModelID: 75,
            vtableAddress: 0x007AD608,
            callbackAddress: 0x0048CC80,
            role: .serialization
        ),
    ]

    public static func entertainmentVenueVTable280Descriptor(
        forVenueModelID venueModelID: Int
    ) -> EntertainmentVenueVTable280Descriptor? {
        entertainmentVenueVTable280Descriptors.first {
            $0.venueModelID == venueModelID
        }
    }

    /// Versioned field spans emitted by the Theatre Pavilion serializer
    /// `FUN_0048CC80 @ 0x48CC80`.  These are raw object offsets and byte
    /// lengths; they are intentionally not interpreted as provider semantics.
    public struct EntertainmentPavilionSerializationFieldSpan: Sendable, Hashable, Codable {
        public let objectOffset: Int
        public let byteCount: Int

        public init(objectOffset: Int, byteCount: Int) {
            self.objectOffset = objectOffset
            self.byteCount = byteCount
        }
    }

    public struct EntertainmentPavilionSerializationDescriptor: Sendable, Hashable, Codable {
        public let venueModelID: Int
        public let callbackAddress: UInt32
        public let streamDispatchMethodOffset: Int
        public let streamDispatchFirstArgument: Int
        public let streamDispatchSecondArgument: Int
        public let loadResetFieldSpans: [EntertainmentPavilionSerializationFieldSpan]
        public let versionedFieldSpans: [Int: [EntertainmentPavilionSerializationFieldSpan]]
        public let unsupportedVersionFallback: Int

        public init(
            venueModelID: Int,
            callbackAddress: UInt32,
            streamDispatchMethodOffset: Int,
            streamDispatchFirstArgument: Int,
            streamDispatchSecondArgument: Int,
            loadResetFieldSpans: [EntertainmentPavilionSerializationFieldSpan],
            versionedFieldSpans: [Int: [EntertainmentPavilionSerializationFieldSpan]],
            unsupportedVersionFallback: Int
        ) {
            self.venueModelID = venueModelID
            self.callbackAddress = callbackAddress
            self.streamDispatchMethodOffset = streamDispatchMethodOffset
            self.streamDispatchFirstArgument = streamDispatchFirstArgument
            self.streamDispatchSecondArgument = streamDispatchSecondArgument
            self.loadResetFieldSpans = loadResetFieldSpans
            self.versionedFieldSpans = versionedFieldSpans
            self.unsupportedVersionFallback = unsupportedVersionFallback
        }

        public func fieldSpans(forArchiveVersion version: Int) -> [EntertainmentPavilionSerializationFieldSpan]? {
            versionedFieldSpans[version]
        }
    }

    public static let entertainmentPavilionSerializationDescriptor =
        EntertainmentPavilionSerializationDescriptor(
            venueModelID: 75,
            callbackAddress: 0x0048CC80,
            streamDispatchMethodOffset: 0x284,
            streamDispatchFirstArgument: 0,
            streamDispatchSecondArgument: 3,
            loadResetFieldSpans: [
                .init(objectOffset: 0x57, byteCount: 4),
                .init(objectOffset: 0x56, byteCount: 4),
                .init(objectOffset: 0x55, byteCount: 4),
                .init(objectOffset: 0x58, byteCount: 100),
                .init(objectOffset: 0x71, byteCount: 100),
                .init(objectOffset: 0x54, byteCount: 4),
            ],
            versionedFieldSpans: [
                1: [.init(objectOffset: 0x54, byteCount: 4)],
                2: [
                    .init(objectOffset: 0x54, byteCount: 4),
                    .init(objectOffset: 0x55, byteCount: 4),
                    .init(objectOffset: 0x58, byteCount: 0x50),
                    .init(objectOffset: 0x71, byteCount: 0x50),
                ],
                3: [
                    .init(objectOffset: 0x54, byteCount: 4),
                    .init(objectOffset: 0x55, byteCount: 4),
                    .init(objectOffset: 0x58, byteCount: 0x50),
                    .init(objectOffset: 0x71, byteCount: 0x50),
                ],
                4: [
                    .init(objectOffset: 0x54, byteCount: 4),
                    .init(objectOffset: 0x55, byteCount: 4),
                    .init(objectOffset: 0x58, byteCount: 100),
                    .init(objectOffset: 0x71, byteCount: 100),
                ],
                5: [
                    .init(objectOffset: 0x54, byteCount: 4),
                    .init(objectOffset: 0x55, byteCount: 4),
                    .init(objectOffset: 0x56, byteCount: 4),
                    .init(objectOffset: 0x57, byteCount: 4),
                    .init(objectOffset: 0x58, byteCount: 100),
                    .init(objectOffset: 0x71, byteCount: 100),
                ],
            ],
            unsupportedVersionFallback: 5
        )

    /// Raw transition emitted by the Entertainment Area callback
    /// `FUN_0048CE90 @ 0x48CE90`.  This callback is reached only after a
    /// concrete model-71 provider already exists; it is not an archive-row
    /// specialization rule.  The slot/status words retain their executable
    /// values (`1`, `2`, `3`, or the selector returned by `FUN_0048F420`)
    /// because their player-facing names are not recovered.
    public struct EntertainmentAreaFigureBootstrapTransition: Sendable, Hashable, Codable {
        public let providerByte65After: UInt8
        public let providerByte36After: UInt8?
        public let returnLowByte: UInt8
        public let requestedFigureModelID: Int?
        public let figureRegistryIndex: Int?
        public let managerCursorBefore: Int?
        public let managerCursorAfter: Int?
        public let managerSlotStatus: Int?
        public let managerSlotFigureRegistryIndex: Int?
        public let figureParentProviderIndex: Int16?
        public let directFigureInitialization: Bool
        public let figureReferenceRegistryIndex: Int?
        public let figureHeadingAfter: UInt8?
        public let figureProgressAfter: Int8?

        public init(
            providerByte65After: UInt8,
            providerByte36After: UInt8?,
            returnLowByte: UInt8,
            requestedFigureModelID: Int?,
            figureRegistryIndex: Int?,
            managerCursorBefore: Int?,
            managerCursorAfter: Int?,
            managerSlotStatus: Int?,
            managerSlotFigureRegistryIndex: Int?,
            figureParentProviderIndex: Int16?,
            directFigureInitialization: Bool,
            figureReferenceRegistryIndex: Int?,
            figureHeadingAfter: UInt8?,
            figureProgressAfter: Int8?
        ) {
            self.providerByte65After = providerByte65After
            self.providerByte36After = providerByte36After
            self.returnLowByte = returnLowByte
            self.requestedFigureModelID = requestedFigureModelID
            self.figureRegistryIndex = figureRegistryIndex
            self.managerCursorBefore = managerCursorBefore
            self.managerCursorAfter = managerCursorAfter
            self.managerSlotStatus = managerSlotStatus
            self.managerSlotFigureRegistryIndex = managerSlotFigureRegistryIndex
            self.figureParentProviderIndex = figureParentProviderIndex
            self.directFigureInitialization = directFigureInitialization
            self.figureReferenceRegistryIndex = figureReferenceRegistryIndex
            self.figureHeadingAfter = figureHeadingAfter
            self.figureProgressAfter = figureProgressAfter
        }
    }

    public static let entertainmentAreaFigureBootstrapAddress: UInt32 = 0x0048CE90
    public static let entertainmentAreaFigureModelID = 0x25
    public static let entertainmentAreaProviderByte65Offset = 0x65
    public static let entertainmentAreaProviderByte36Offset = 0x36
    public static let entertainmentAreaManagerCursorOffset = 0x55
    public static let entertainmentAreaManagerSlotCountOffset = 0x57
    public static let entertainmentAreaManagerFigureIDOffset = 0x58
    public static let entertainmentAreaManagerStatusOffset = 0x71
    public static let entertainmentAreaFigureParentOffset = 0x62
    public static let entertainmentAreaFigureReferenceOffset = 0x72
    public static let entertainmentAreaFigureHeadingOffset = 0x19
    public static let entertainmentAreaFigureProgressOffset = 0x41
    public static let entertainmentAreaProviderFigureGateVTableSlot: UInt32 = 0x4C
    public static let entertainmentAreaProviderWorkerGateVTableSlot: UInt32 = 0x58
    public static let entertainmentAreaFigureInitializeVTableSlot: UInt32 = 0x22C
    public static let entertainmentAreaFigureBootstrapSeedAddress: UInt32 = 0x004E6A70

    /// Replays the field-level branch order of `FUN_0048CE90` after its
    /// caller has supplied the unresolved virtual/global gate results and the
    /// allocator output.  `rotationSelector` is the already-resolved return
    /// from `FUN_0048F420`; a missing selector/reference is rejected instead
    /// of inventing a manager slot or figure link.
    public static func entertainmentAreaFigureBootstrap(
        providerPopulationWord: Int,
        providerFigureGatePassed: Bool,
        globalGatePassed: Bool,
        providerWorkerGatePassed: Bool,
        providerRegistryIndex: Int,
        managerCursor: Int,
        managerSlotCount: Int,
        allocatedFigureRegistryIndex: Int?,
        rotationSelector: Int? = nil,
        referencedFigureRegistryIndex: Int? = nil,
        referencedFigureHeading: UInt8? = nil,
        referencedFigureProgress: Int8? = nil
    ) -> EntertainmentAreaFigureBootstrapTransition {
        let providerByte65After: UInt8 = providerPopulationWord < 1 ? 2 : 0
        guard providerFigureGatePassed, globalGatePassed, providerWorkerGatePassed else {
            return .init(
                providerByte65After: providerByte65After,
                providerByte36After: nil,
                returnLowByte: 0,
                requestedFigureModelID: nil,
                figureRegistryIndex: nil,
                managerCursorBefore: nil,
                managerCursorAfter: nil,
                managerSlotStatus: nil,
                managerSlotFigureRegistryIndex: nil,
                figureParentProviderIndex: nil,
                directFigureInitialization: false,
                figureReferenceRegistryIndex: nil,
                figureHeadingAfter: nil,
                figureProgressAfter: nil
            )
        }

        // The source clears +0x36 before calling FUN_004EA050, even when the
        // allocator returns zero.
        guard let figureRegistryIndex = allocatedFigureRegistryIndex else {
            return .init(
                providerByte65After: providerByte65After,
                providerByte36After: 0,
                returnLowByte: 1,
                requestedFigureModelID: entertainmentAreaFigureModelID,
                figureRegistryIndex: nil,
                managerCursorBefore: nil,
                managerCursorAfter: nil,
                managerSlotStatus: nil,
                managerSlotFigureRegistryIndex: nil,
                figureParentProviderIndex: nil,
                directFigureInitialization: false,
                figureReferenceRegistryIndex: nil,
                figureHeadingAfter: nil,
                figureProgressAfter: nil
            )
        }

        let status: Int
        if managerCursor == 0 {
            status = 1
        } else if managerCursor < 1 || managerSlotCount - 2 < managerCursor {
            if managerCursor == managerSlotCount - 1 {
                status = 3
            } else {
                guard let rotationSelector else {
                    return .init(
                        providerByte65After: providerByte65After,
                        providerByte36After: 0,
                        returnLowByte: 1,
                        requestedFigureModelID: entertainmentAreaFigureModelID,
                        figureRegistryIndex: figureRegistryIndex,
                        managerCursorBefore: managerCursor,
                        managerCursorAfter: managerCursor + 1,
                        managerSlotStatus: nil,
                        managerSlotFigureRegistryIndex: figureRegistryIndex,
                        figureParentProviderIndex: Int16(truncatingIfNeeded: providerRegistryIndex),
                        directFigureInitialization: false,
                        figureReferenceRegistryIndex: nil,
                        figureHeadingAfter: nil,
                        figureProgressAfter: nil
                    )
                }
                status = rotationSelector
            }
        } else {
            status = 2
        }

        let parentIndex = Int16(truncatingIfNeeded: providerRegistryIndex)
        guard status == 1 else {
            guard let referencedFigureRegistryIndex,
                  let referencedFigureHeading,
                  let referencedFigureProgress else {
                return .init(
                    providerByte65After: providerByte65After,
                    providerByte36After: 0,
                    returnLowByte: 1,
                    requestedFigureModelID: entertainmentAreaFigureModelID,
                    figureRegistryIndex: figureRegistryIndex,
                    managerCursorBefore: managerCursor,
                    managerCursorAfter: managerCursor + 1,
                    managerSlotStatus: status,
                    managerSlotFigureRegistryIndex: figureRegistryIndex,
                    figureParentProviderIndex: parentIndex,
                    directFigureInitialization: false,
                    figureReferenceRegistryIndex: nil,
                    figureHeadingAfter: nil,
                    figureProgressAfter: nil
                )
            }
            // The source performs an 8-bit `sub al, 0x12`, tests the sign
            // flag, and adds `0x14` only for a negative byte. Preserve that
            // wrap/sign behavior for the full Int8 domain.
            let rawProgress = UInt8(bitPattern: referencedFigureProgress)
            let subtracted = rawProgress &- 0x12
            let progressByte = (subtracted & 0x80) == 0
                ? subtracted
                : subtracted &+ 0x14
            let progress = Int8(bitPattern: progressByte)
            return .init(
                providerByte65After: providerByte65After,
                providerByte36After: 0,
                returnLowByte: 1,
                requestedFigureModelID: entertainmentAreaFigureModelID,
                figureRegistryIndex: figureRegistryIndex,
                managerCursorBefore: managerCursor,
                managerCursorAfter: managerCursor + 1,
                managerSlotStatus: status,
                managerSlotFigureRegistryIndex: figureRegistryIndex,
                figureParentProviderIndex: parentIndex,
                directFigureInitialization: false,
                figureReferenceRegistryIndex: referencedFigureRegistryIndex,
                figureHeadingAfter: referencedFigureHeading,
                figureProgressAfter: progress
            )
        }

        return .init(
            providerByte65After: providerByte65After,
            providerByte36After: 0,
            returnLowByte: 1,
            requestedFigureModelID: entertainmentAreaFigureModelID,
            figureRegistryIndex: figureRegistryIndex,
            managerCursorBefore: managerCursor,
            managerCursorAfter: managerCursor + 1,
            managerSlotStatus: status,
            managerSlotFigureRegistryIndex: figureRegistryIndex,
            figureParentProviderIndex: parentIndex,
            directFigureInitialization: true,
            figureReferenceRegistryIndex: nil,
            figureHeadingAfter: nil,
            figureProgressAfter: nil
        )
    }

    /// The three rotating entertainment figure buckets maintained by
    /// `FUN_0048F140 @ 0x48F140` and consumed by `FUN_0048F420 @ 0x48F420`.
    ///
    /// The executable does not assign a domain name to these fields: the
    /// manager stores them at `+0x2C` (music, model 211), `+0x34` (acrobat,
    /// model 212), and `+0x3C` (drama, model 213).  A first active provider
    /// contributes three slots; each later active provider of the same model
    /// contributes one.  Consumption returns selectors 4/5/6 in those same
    /// strict intervals and then rotates the remaining cursor with a caller-
    /// supplied random offset.  This helper has no provider lookup,
    /// spawning, or coverage side effects, so it remains safe to use as a
    /// source-backed primitive while Qin's venue FSM is fail-closed.
    public struct EntertainmentProviderRotationState: Sendable, Hashable, Codable {
        /// Raw manager input for one active entertainment-school object. The
        /// executable's `FUN_0048F140` admits a school to the rotation buckets
        /// only when its virtual `+0x1BC` staffing-ratio result is strictly
        /// positive. Keep that result as an explicit boolean supplied by the
        /// caller; Native cannot derive it from assigned workers while the
        /// provider object/registry projection remains unresolved.
        public struct ProviderInput: Sendable, Hashable, Codable {
            public let buildingID: Int
            public let staffingRatioIsPositive: Bool

            public init(buildingID: Int, staffingRatioIsPositive: Bool) {
                self.buildingID = buildingID
                self.staffingRatioIsPositive = staffingRatioIsPositive
            }
        }

        public private(set) var musicSlots: Int
        public private(set) var acrobatSlots: Int
        public private(set) var dramaSlots: Int
        public private(set) var totalSlots: Int
        public private(set) var cursor: Int

        public init(
            musicSlots: Int = 0,
            acrobatSlots: Int = 0,
            dramaSlots: Int = 0,
            cursor: Int = 0
        ) {
            self.musicSlots = max(0, musicSlots)
            self.acrobatSlots = max(0, acrobatSlots)
            self.dramaSlots = max(0, dramaSlots)
            self.totalSlots = self.musicSlots + self.acrobatSlots + self.dramaSlots
            self.cursor = self.totalSlots > 0
                ? max(0, cursor) % self.totalSlots
                : 0
        }

        /// Rebuilds the three buckets from the active provider model IDs
        /// scanned by the original manager. Unknown models are ignored, as
        /// `FUN_0048F140` only increments cases `0xD3…0xD5`.
        public static func rebuilt(
            fromActiveProviderBuildingIDs buildingIDs: [Int],
            initialCursor: Int = 0
        ) -> Self {
            var music = 0
            var acrobat = 0
            var drama = 0
            for buildingID in buildingIDs {
                switch buildingID {
                case 211:
                    music = music == 0 ? 3 : music + 1
                case 212:
                    acrobat = acrobat == 0 ? 3 : acrobat + 1
                case 213:
                    drama = drama == 0 ? 3 : drama + 1
                default:
                    continue
                }
            }
            return Self(
                musicSlots: music,
                acrobatSlots: acrobat,
                dramaSlots: drama,
                cursor: initialCursor
            )
        }

        /// Rebuilds the source buckets after applying the manager's positive
        /// `+0x1BC` staffing-ratio gate. This is the complete input boundary
        /// of `FUN_0048F140`; it still does not identify the producer of that
        /// ratio, register a Qin provider, spawn a figure, or settle coverage.
        public static func rebuilt(
            fromActiveProviders providers: [ProviderInput],
            initialCursor: Int = 0
        ) -> Self {
            rebuilt(
                fromActiveProviderBuildingIDs: providers
                    .filter { $0.staffingRatioIsPositive }
                    .map(\.buildingID),
                initialCursor: initialCursor
            )
        }

        /// Consumes one slot using the strict interval checks from
        /// `FUN_0048F420`. `randomOffset` is the already-resolved result of
        /// the executable's random call; supplying it explicitly keeps this
        /// primitive deterministic and does not invent a Native RNG source.
        /// Returns the original figure selector (4 music, 5 acrobat, 6
        /// drama), or `nil` when no slot remains.
        @discardableResult
        public mutating func consume(randomOffset: Int = 0) -> Int? {
            guard totalSlots > 0 else { return nil }

            let selectedCursor = cursor
            let selector: Int
            if selectedCursor < musicSlots {
                musicSlots -= 1
                selector = 4
            } else if selectedCursor < musicSlots + acrobatSlots {
                acrobatSlots -= 1
                selector = 5
            } else {
                dramaSlots = max(0, dramaSlots - 1)
                selector = 6
            }

            let previousCursor = selectedCursor
            totalSlots -= 1
            if totalSlots > 0 {
                let normalizedOffset = ((randomOffset % totalSlots) + totalSlots) % totalSlots
                cursor = (normalizedOffset + previousCursor) % totalSlots
            } else {
                cursor = 0
            }
            return selector
        }
    }

    /// Counts the active entertainment object classes collected by
    /// `FUN_00410620 @ 0x410620` during manager initialization. The source
    /// keeps school counts (211…213) separate from venue counts (71/75);
    /// these are object totals, not staffed slots or figure capacity.
    public struct EntertainmentProviderObjectCounts: Sendable, Hashable, Codable {
        public let musicSchool: Int
        public let acrobatSchool: Int
        public let dramaSchool: Int
        public let entertainmentArea: Int
        public let theatrePavilion: Int

        public init(
            musicSchool: Int = 0,
            acrobatSchool: Int = 0,
            dramaSchool: Int = 0,
            entertainmentArea: Int = 0,
            theatrePavilion: Int = 0
        ) {
            self.musicSchool = max(0, musicSchool)
            self.acrobatSchool = max(0, acrobatSchool)
            self.dramaSchool = max(0, dramaSchool)
            self.entertainmentArea = max(0, entertainmentArea)
            self.theatrePavilion = max(0, theatrePavilion)
        }

        public static let sourceAddress: UInt32 = 0x00410620
        public static let globalGateAddress: UInt32 = 0x00426D10
        public static let schoolModelIDs = [211, 212, 213]
        public static let venueModelIDs = [71, 75]

        /// Rebuilds the manager's raw object totals from the active object
        /// model sequence. With the source global gate closed, the original
        /// leaves all five counters at zero. Unknown models are ignored.
        public static func rebuilt(
            fromActiveObjectModelIDs modelIDs: [Int],
            globalGateOpen: Bool
        ) -> Self {
            guard globalGateOpen else { return Self() }
            var musicSchool = 0
            var acrobatSchool = 0
            var dramaSchool = 0
            var entertainmentArea = 0
            var theatrePavilion = 0
            for modelID in modelIDs {
                switch modelID {
                case 211:
                    musicSchool += 1
                case 212:
                    acrobatSchool += 1
                case 213:
                    dramaSchool += 1
                case 71:
                    entertainmentArea += 1
                case 75:
                    theatrePavilion += 1
                default:
                    continue
                }
            }
            return .init(
                musicSchool: musicSchool,
                acrobatSchool: acrobatSchool,
                dramaSchool: dramaSchool,
                entertainmentArea: entertainmentArea,
                theatrePavilion: theatrePavilion
            )
        }
    }

    /// Returns the recovered entertainment-provider spawn threshold for one
    /// provider update. The PE's provider methods (`0x5AB330` for Music /
    /// Acrobat and `0x48B380` for Drama) compare an incremented counter with
    /// this value using a strict `>` gate. This table is intentionally
    /// side-effect-free: figures 32…34 remain outside the Native roam bridge
    /// until provider selection, route/collision, and coverage side effects
    /// are recovered.
    public static func entertainmentSpawnThreshold(
        providerBuildingID: Int,
        workerPercent: Int
    ) -> Int? {
        let thresholds: [Int]
        switch providerBuildingID {
        case 211, 212:
            thresholds = [3, 6, 12, 24, 32, 64]
        case 213:
            thresholds = [6, 12, 24, 32, 48, 96]
        default:
            return nil
        }
        switch workerPercent {
        case 100...: return thresholds[0]
        case 75..<100: return thresholds[1]
        case 50..<75: return thresholds[2]
        case 25..<50: return thresholds[3]
        case 1..<25: return thresholds[4]
        default: return thresholds[5]
        }
    }

    /// Returns the provider-vtable threshold method selected by the original
    /// entertainment factories.  The indexed split corpus has no standalone
    /// function file for `0x5AB330`; direct read-only EN/CH PE inspection
    /// recovered the method body and confirmed byte parity.  This is metadata
    /// only: it does not register a provider or enable Qin figure spawning.
    public static func entertainmentSpawnThresholdMethodAddress(
        providerBuildingID: Int
    ) -> UInt32? {
        switch providerBuildingID {
        case 211, 212:
            return 0x005AB330
        case 213:
            return 0x0048B380
        default:
            return nil
        }
    }

    /// Reproduces the staffing value returned by the entertainment provider
    /// vtable's `+0x1BC` method (`FUN_00428ED0`).  The source first dispatches
    /// `+0x1B0`: a non-zero provider byte at `+0x6E` forces a zero result;
    /// otherwise the denominator is the model-table employee field selected
    /// by `FUN_0044CC50(modelID, 5)`.  It then divides the signed `+0x44`
    /// word by that denominator after multiplying by 100.  Raw fields remain
    /// explicit because Qin's provider/object projection is unresolved; this
    /// helper must not substitute Native assigned-worker percentages or enable
    /// venue figures by itself.
    public static func entertainmentProviderStaffingPercent(
        providerStateByte: Int,
        rawAssignedWord: Int,
        modelEmployeeField: Int
    ) -> Int {
        guard providerStateByte == 0, modelEmployeeField > 0 else { return 0 }
        return (rawAssignedWord * 100) / modelEmployeeField
    }

    /// Raw inputs to the residential-provider record update dispatched during
    /// scheduler phase `0x14` (`FUN_0051E4A0`).  The source reads these values
    /// through provider virtual slots and from the record returned by
    /// `+0x1E8`; their player-facing meanings are intentionally not inferred.
    public struct ProviderRecordUpdateInput: Sendable, Hashable, Codable {
        public let globalGateOpen: Bool
        public let objectActive: Bool
        public let recordAdmissionPassed: Bool
        public let providerReady: Bool
        public let storedWorkCount: Int
        public let accessGatePassed: Bool
        public let parentUnclaimed: Bool
        public let auxiliaryGatePassed: Bool
        public let recordCountByte: UInt8
        public let recordOpportunityByte: UInt8
        public let recordProgressWord: Int
        public let convertedIncrement: Int
        public let recordUpperCapacity: Int

        public init(
            globalGateOpen: Bool,
            objectActive: Bool,
            recordAdmissionPassed: Bool,
            providerReady: Bool,
            storedWorkCount: Int,
            accessGatePassed: Bool,
            parentUnclaimed: Bool,
            auxiliaryGatePassed: Bool,
            recordCountByte: UInt8 = 0,
            recordOpportunityByte: UInt8 = 0,
            recordProgressWord: Int = 0,
            convertedIncrement: Int = 0,
            recordUpperCapacity: Int = 0
        ) {
            self.globalGateOpen = globalGateOpen
            self.objectActive = objectActive
            self.recordAdmissionPassed = recordAdmissionPassed
            self.providerReady = providerReady
            self.storedWorkCount = storedWorkCount
            self.accessGatePassed = accessGatePassed
            self.parentUnclaimed = parentUnclaimed
            self.auxiliaryGatePassed = auxiliaryGatePassed
            self.recordCountByte = recordCountByte
            self.recordOpportunityByte = recordOpportunityByte
            self.recordProgressWord = recordProgressWord
            self.convertedIncrement = convertedIncrement
            self.recordUpperCapacity = recordUpperCapacity
        }
    }

    /// Result of one source provider-record update.  `recordProgressWord`
    /// preserves the signed 16-bit storage width used by record `+0x04`;
    /// the two byte fields preserve their independent decrement branches.
    public struct ProviderRecordUpdateOutcome: Sendable, Hashable, Codable {
        public let recordCountByte: UInt8
        public let recordOpportunityByte: UInt8
        public let recordProgressWord: Int16
        public let didProcessProvider: Bool
        public let didDecrementCountByte: Bool
        public let didDecrementOpportunityByte: Bool
        public let didClampProgress: Bool

        public init(
            recordCountByte: UInt8,
            recordOpportunityByte: UInt8,
            recordProgressWord: Int16,
            didProcessProvider: Bool,
            didDecrementCountByte: Bool,
            didDecrementOpportunityByte: Bool,
            didClampProgress: Bool
        ) {
            self.recordCountByte = recordCountByte
            self.recordOpportunityByte = recordOpportunityByte
            self.recordProgressWord = recordProgressWord
            self.didProcessProvider = didProcessProvider
            self.didDecrementCountByte = didDecrementCountByte
            self.didDecrementOpportunityByte = didDecrementOpportunityByte
            self.didClampProgress = didClampProgress
        }
    }

    /// Reproduces the gate order and field arithmetic of
    /// `FUN_0051E4A0 @ 0x51E4A0`.  A provider is considered processable only
    /// after every explicit source gate passes.  A non-zero record count byte
    /// (`+0x63`) takes the short branch and decrements only that byte; when it
    /// is zero, a positive opportunity byte (`+0x5F`) is decremented, the
    /// converted increment is added to signed record word `+0x04`, and that
    /// word is capped against the provider's `+0x204` result.  No provider
    /// object, registry entry, route, or house state is synthesized here.
    public static func updateProviderRecord(
        _ input: ProviderRecordUpdateInput
    ) -> ProviderRecordUpdateOutcome {
        let initialProgress = Int16(truncatingIfNeeded: input.recordProgressWord)
        let gatePassed = input.globalGateOpen
            && input.objectActive
            && input.recordAdmissionPassed
            && input.providerReady
            && input.storedWorkCount > 0
            && input.accessGatePassed
            && input.parentUnclaimed
            && input.auxiliaryGatePassed
        guard gatePassed else {
            return .init(
                recordCountByte: input.recordCountByte,
                recordOpportunityByte: input.recordOpportunityByte,
                recordProgressWord: initialProgress,
                didProcessProvider: false,
                didDecrementCountByte: false,
                didDecrementOpportunityByte: false,
                didClampProgress: false
            )
        }

        if input.recordCountByte != 0 {
            return .init(
                recordCountByte: input.recordCountByte &- 1,
                recordOpportunityByte: input.recordOpportunityByte,
                recordProgressWord: initialProgress,
                didProcessProvider: true,
                didDecrementCountByte: true,
                didDecrementOpportunityByte: false,
                didClampProgress: false
            )
        }

        let decrementedOpportunity = input.recordOpportunityByte != 0
            ? input.recordOpportunityByte &- 1
            : input.recordOpportunityByte
        let progressAfterAdd = initialProgress
            &+ Int16(truncatingIfNeeded: input.convertedIncrement)
        let clamped = Int(progressAfterAdd) > input.recordUpperCapacity
        let finalProgress = clamped
            ? Int16(truncatingIfNeeded: input.recordUpperCapacity)
            : progressAfterAdd
        return .init(
            recordCountByte: input.recordCountByte,
            recordOpportunityByte: decrementedOpportunity,
            recordProgressWord: finalProgress,
            didProcessProvider: true,
            didDecrementCountByte: false,
            didDecrementOpportunityByte: input.recordOpportunityByte != 0,
            didClampProgress: clamped
        )
    }

    /// Raw inputs to the admission-failure branch dispatched by phase `0x14`
    /// (`FUN_004C0F60`).  The model whitelist and registry reset predicate are
    /// resolved here as raw inputs; Native does not derive either from a
    /// player-facing building label or a guessed provider mapping.
    public struct AdmissionFailureRecordUpdateInput: Sendable, Hashable, Codable {
        public let objectModelID: Int
        public let globalObjectGate: Bool
        public let registryResetGate: Bool
        public let recordCountByte: UInt8
        public let recordProgressWord: Int
        public let convertedIncrement: Int

        public init(
            objectModelID: Int,
            globalObjectGate: Bool = true,
            registryResetGate: Bool,
            recordCountByte: UInt8 = 0,
            recordProgressWord: Int = 0,
            convertedIncrement: Int = 0
        ) {
            self.objectModelID = objectModelID
            self.globalObjectGate = globalObjectGate
            self.registryResetGate = registryResetGate
            self.recordCountByte = recordCountByte
            self.recordProgressWord = recordProgressWord
            self.convertedIncrement = convertedIncrement
        }
    }

    /// Result of the source `FUN_004C0F60` admission-failure path.  The
    /// `recordProgressWord` and callback increment retain the executable's
    /// signed 16-bit storage width; the terminal callback is only reached on
    /// the zero-count branch.
    public struct AdmissionFailureRecordUpdateOutcome: Sendable, Hashable, Codable {
        public let recordCountByte: UInt8
        public let recordProgressWord: Int16
        public let didProcessAdmissionFailure: Bool
        public let didDecrementCountByte: Bool
        public let didClampProgress: Bool
        public let didResetProgress: Bool
        public let didInvokeTerminalCallback: Bool

        public init(
            recordCountByte: UInt8,
            recordProgressWord: Int16,
            didProcessAdmissionFailure: Bool,
            didDecrementCountByte: Bool,
            didClampProgress: Bool,
            didResetProgress: Bool,
            didInvokeTerminalCallback: Bool
        ) {
            self.recordCountByte = recordCountByte
            self.recordProgressWord = recordProgressWord
            self.didProcessAdmissionFailure = didProcessAdmissionFailure
            self.didDecrementCountByte = didDecrementCountByte
            self.didClampProgress = didClampProgress
            self.didResetProgress = didResetProgress
            self.didInvokeTerminalCallback = didInvokeTerminalCallback
        }
    }

    /// Reproduces `FUN_004C0F60 @ 0x4C0F60` after its caller has established
    /// the phase-`0x14` admission failure.  `FUN_004C11B0` admits exactly the
    /// listed model IDs.  A positive `+0x63` record byte decrements and returns
    /// before the terminal `+0x260` callback; otherwise the signed 16-bit
    /// `+0x25C(0)` result is added to record `+0x04`, capped at `10000` using
    /// the source's signed comparison, then `FUN_004AFD80(+0x2D)` may reset
    /// that word before `+0x260` is invoked.
    public static func updateAdmissionFailureRecord(
        _ input: AdmissionFailureRecordUpdateInput
    ) -> AdmissionFailureRecordUpdateOutcome {
        let initialProgress = Int16(truncatingIfNeeded: input.recordProgressWord)
        let admittedModel = [0x1A, 0x1B, 0x1C, 0xC2, 0xC3, 0xC4, 0xC5, 0xC6, 0xC7]
            .contains(input.objectModelID)
        guard admittedModel, input.globalObjectGate else {
            return .init(
                recordCountByte: input.recordCountByte,
                recordProgressWord: initialProgress,
                didProcessAdmissionFailure: false,
                didDecrementCountByte: false,
                didClampProgress: false,
                didResetProgress: false,
                didInvokeTerminalCallback: false
            )
        }

        if input.recordCountByte != 0 {
            return .init(
                recordCountByte: input.recordCountByte &- 1,
                recordProgressWord: initialProgress,
                didProcessAdmissionFailure: true,
                didDecrementCountByte: true,
                didClampProgress: false,
                didResetProgress: false,
                didInvokeTerminalCallback: false
            )
        }

        let progressAfterAdd = initialProgress
            &+ Int16(truncatingIfNeeded: input.convertedIncrement)
        let clamped = Int(progressAfterAdd) > 10_000
        let cappedProgress = clamped ? Int16(10_000) : progressAfterAdd
        let reset = input.registryResetGate
        return .init(
            recordCountByte: input.recordCountByte,
            recordProgressWord: reset ? 0 : cappedProgress,
            didProcessAdmissionFailure: true,
            didDecrementCountByte: false,
            didClampProgress: clamped,
            didResetProgress: reset,
            didInvokeTerminalCallback: true
        )
    }

    /// One provider retained by `FUN_0048A520 @ 0x48A520` after its
    /// source-visible admission checks. The field names intentionally describe
    /// their recovered storage roles rather than guessing the game's domain
    /// semantics: `registryID` is provider `+0xB4`, `selectionValue` is the
    /// result of vtable `+0x1A4` (the provider's absolute map-cell index), and
    /// `capacity` is the model-specific result of vtable `+0x25C`.
    public struct EntertainmentProviderCandidate: Sendable, Hashable {
        public let registryID: Int
        public let selectionValue: Int
        public let capacity: Int
        public let weight: Int

        public init(
            registryID: Int,
            selectionValue: Int,
            capacity: Int,
            weight: Int
        ) {
            self.registryID = registryID
            self.selectionValue = selectionValue
            self.capacity = capacity
            self.weight = weight
        }
    }

    /// Source-visible provider inputs for the entertainment venue selector.
    /// `supportsFigure`, `stateGate`, and `workValue` are the three virtual
    /// calls made by `FUN_0048A520`; their semantic names are intentionally
    /// not inferred here.
    public struct EntertainmentProviderSelectionInput: Sendable, Hashable {
        public let registryID: Int
        public let selectionValue: Int
        public let supportsFigure: Bool
        public let stateGate: Bool
        public let workValue: Int
        public let capacity: Int

        public init(
            registryID: Int,
            selectionValue: Int,
            supportsFigure: Bool,
            stateGate: Bool,
            workValue: Int,
            capacity: Int
        ) {
            self.registryID = registryID
            self.selectionValue = selectionValue
            self.supportsFigure = supportsFigure
            self.stateGate = stateGate
            self.workValue = workValue
            self.capacity = capacity
        }
    }

    /// One active-object row considered by `FUN_0048A420 @ 0x48A420` while
    /// choosing an Entertainment Area. The source compares model `0x47`
    /// (authored building `71`), then asks the provider's `+0x78` predicate
    /// and `+0x1BC` staffing result. The fields retain those raw gates rather
    /// than assigning an unproven player-facing meaning.
    public struct EntertainmentAreaSelectionInput: Sendable, Hashable {
        public let registryID: Int
        public let modelID: Int
        public let providerAccessAllowed: Bool
        public let staffingValue: Int

        public init(
            registryID: Int,
            modelID: Int,
            providerAccessAllowed: Bool,
            staffingValue: Int
        ) {
            self.registryID = registryID
            self.modelID = modelID
            self.providerAccessAllowed = providerAccessAllowed
            self.staffingValue = staffingValue
        }
    }

    /// The source object-vector position and registry value selected by the
    /// Entertainment Area lookup. The route/coverage meaning of the registry
    /// value remains unresolved.
    public struct EntertainmentAreaSelection: Sendable, Hashable {
        public let vectorIndex: Int
        public let registryID: Int

        public init(vectorIndex: Int, registryID: Int) {
            self.vectorIndex = vectorIndex
            self.registryID = registryID
        }
    }

    /// Reproduces the source-visible candidate gate and rotating scan of
    /// `FUN_0048A420 @ 0x48A420`. The original starts at a random object-vector
    /// index, wraps at the vector count, and scans exactly one full pass. It
    /// returns the first active model `71` row whose `+0x78` predicate is true
    /// and whose signed `+0x1BC` result is positive. The caller supplies the
    /// already-produced start index; no Native RNG or registry is inferred.
    public static func entertainmentAreaSelection(
        globalGate: Bool,
        startIndex: Int,
        providers: [EntertainmentAreaSelectionInput]
    ) -> EntertainmentAreaSelection? {
        guard globalGate,
              !providers.isEmpty,
              providers.indices.contains(startIndex) else { return nil }
        for offset in providers.indices {
            let index = (startIndex + offset) % providers.count
            let provider = providers[index]
            guard provider.modelID == 71,
                  provider.providerAccessAllowed,
                  provider.staffingValue > 0 else {
                continue
            }
            return .init(vectorIndex: index, registryID: provider.registryID)
        }
        return nil
    }

    /// Reproduces the closed candidate-admission portion of
    /// `FUN_0048A520 @ 0x48A520`.
    ///
    /// The original accepts only figure models `32…34`, requires the global
    /// gate plus provider slots `+0x264`, `+0x78`, and `+0x1B4` to pass, then
    /// scans the provider list in order across capacity buckets `8`, `16`,
    /// and `24`. It stops at the first non-empty bucket and retains every
    /// candidate in that bucket, assigning the recovered side weight `n×2`.
    /// This helper deliberately stops before the unresolved route/occupancy
    /// chooser (`FUN_005B0620`) and has no simulation side effects.
    public static func entertainmentProviderCandidates(
        figureModelID: Int,
        globalGate: Bool,
        providers: [EntertainmentProviderSelectionInput]
    ) -> [EntertainmentProviderCandidate] {
        guard (32...34).contains(figureModelID), globalGate else {
            return []
        }

        for bucket in [8, 16, 24] {
            let candidates = providers.compactMap { provider -> EntertainmentProviderCandidate? in
                guard provider.supportsFigure,
                      provider.stateGate,
                      provider.workValue > 0,
                      provider.capacity <= bucket else {
                    return nil
                }
                return EntertainmentProviderCandidate(
                    registryID: provider.registryID,
                    selectionValue: provider.selectionValue,
                    capacity: provider.capacity,
                    weight: provider.capacity * 2
                )
            }
            if !candidates.isEmpty {
                return candidates
            }
        }
        return []
    }

    /// Converts the entertainment provider's recovered `+0x1A4` result to a
    /// local map point. All three entertainment provider vtables dispatch this
    /// slot to `FUN_004273F0`, which returns
    /// `baseLinearOffset + x + y * rowStride`. The base is explicit because
    /// the Native map backing store is not proven to use the PE's global base.
    public static func entertainmentProviderSelectionPoint(
        selectionValue: Int,
        baseLinearOffset: Int,
        rowStride: Int = OriginalMapObjectGridProjection.mapRowStride
    ) -> GridPoint? {
        guard rowStride > 0 else { return nil }
        let local = selectionValue - baseLinearOffset
        guard local >= 0, local < rowStride * rowStride else { return nil }
        return GridPoint(x: local % rowStride, y: local / rowStride)
    }

    /// Opaque pair written by `FUN_0048BE00 @ 0x48BE00`.
    ///
    /// The executable uses these two words as inputs to the surrounding
    /// Entertainment Area update routine.  Their player-facing meaning is
    /// not recovered, so the fields intentionally retain their raw order.
    /// Figure models `32`, `33`, and `34` select one fixed pair; dispatch
    /// model `38` (`0x26`) selects one of ten slot pairs.  Unsupported model
    /// or slot values leave the source outputs untouched and are represented
    /// here by `nil`.
    public struct EntertainmentVenueRawPair: Sendable, Hashable, Codable {
        public let firstWord: Int
        public let secondWord: Int

        public init(firstWord: Int, secondWord: Int) {
            self.firstWord = firstWord
            self.secondWord = secondWord
        }
    }

    /// Returns the exact raw pair table emitted by `FUN_0048BE00`.
    public static func entertainmentVenueRawPair(
        dispatchModelID: Int,
        slot: Int = 0
    ) -> EntertainmentVenueRawPair? {
        switch dispatchModelID {
        case 32:
            return .init(firstWord: 0xAF, secondWord: -0x2D)
        case 33:
            return .init(firstWord: 0x97, secondWord: 0x12)
        case 34:
            return .init(firstWord: 0x3E, secondWord: -0x30)
        case 38:
            let pairs: [(Int, Int)] = [
                (0xFD, 0x29), (0x3F, 0x24), (0xD6, 0x32),
                (0x5F, 0x35), (0x75, 0x46), (0xD5, 0x47),
                (0xB5, 0x42), (0xBE, 0x56), (0x82, 0x4C),
                (0xA0, 0x5A),
            ]
            guard pairs.indices.contains(slot) else { return nil }
            return .init(firstWord: pairs[slot].0, secondWord: pairs[slot].1)
        default:
            return nil
        }
    }

    /// One raw candidate considered by `FUN_0048A350 @ 0x48A350`.
    ///
    /// The source scans the active-object vector for model `75` (Theatre
    /// Pavilion), requires its virtual `+0x19C` predicate, probes a route
    /// with `FUN_005B00D0`, then keeps the candidate with the smallest
    /// Chebyshev distance from the pavilion's object origin.  The route probe
    /// and predicate are supplied explicitly because their registry and path
    /// semantics are not recovered by this helper.
    public struct TheatrePavilionSelectionInput: Sendable, Hashable, Codable {
        public let objectID: Int
        public let isTheatrePavilion: Bool
        public let callbackGatePassed: Bool
        public let routeProbePassed: Bool
        public let servicePoint: GridPoint
        public let objectOrigin: GridPoint

        public init(
            objectID: Int,
            isTheatrePavilion: Bool = true,
            callbackGatePassed: Bool,
            routeProbePassed: Bool,
            servicePoint: GridPoint,
            objectOrigin: GridPoint
        ) {
            self.objectID = objectID
            self.isTheatrePavilion = isTheatrePavilion
            self.callbackGatePassed = callbackGatePassed
            self.routeProbePassed = routeProbePassed
            self.servicePoint = servicePoint
            self.objectOrigin = objectOrigin
        }
    }

    /// Selects the first minimum-distance Theatre Pavilion from the raw
    /// `FUN_0048A350` candidate scan.  `servicePoint` is retained as an input
    /// because it is the endpoint passed to the source route probe; the
    /// distance itself is measured from `objectOrigin`, matching the separate
    /// coordinate pair read by the executable.  No route, registry, or game
    /// state is mutated.
    public static func selectTheatrePavilion(
        from servicePoint: GridPoint,
        candidates: [TheatrePavilionSelectionInput]
    ) -> TheatrePavilionSelectionInput? {
        var best: TheatrePavilionSelectionInput?
        var bestDistance = Int.max
        for candidate in candidates {
            guard candidate.isTheatrePavilion,
                  candidate.callbackGatePassed,
                  candidate.routeProbePassed else {
                continue
            }
            let distance = max(
                abs(candidate.objectOrigin.x - servicePoint.x),
                abs(candidate.objectOrigin.y - servicePoint.y)
            )
            guard distance < bestDistance else { continue }
            bestDistance = distance
            best = candidate
        }
        return best
    }

    /// The three model-specific opportunity bytes stored in an entertainment
    /// provider record (`+0x5D` acrobat, `+0x5F` actor, `+0x5E` musician).
    ///
    /// `FUN_0048AE30 @ 0x48AE30` is the only recovered decay writer for this
    /// group:
    /// it decrements each non-zero byte once, counts how many bytes were
    /// non-zero before the decrement, stores that count at record `+0x5C`,
    /// and then refreshes the provider. `FUN_004AC2B0` dispatches the shared
    /// `+0x9C` slot from scheduler phase `0x21`; the three school vtables
    /// resolve that slot to `0x48AE30`. The provider registry, route, and
    /// settlement lifecycle remain unresolved, so this value type stays a
    /// side-effect-free research primitive and is not used to enable figures
    /// 32…34 in Native.
    public static let entertainmentVenueDecayVTableOffset: Int = 0x9C
    public static let entertainmentVenueDecaySchedulerPhase: Int = 0x21
    public static let entertainmentVenueDecaySchedulerCycleLength: Int = 0x33
    /// Raw provider-record byte touched by the common figure cleanup callback
    /// (`FUN_004C8B70 @ 0x4C8B70`) for figure models 32…34. The callback
    /// decrements this byte only when it is non-zero; this is deliberately
    /// separate from the three opportunity bytes used by `decayOnce()`.
    public static let entertainmentVenueFigureCleanupProviderCountOffset: Int = 0x5C

    /// The scheduler invokes the shared venue decay slot only for objects whose
    /// active-state byte is `1` or `3` (`FUN_004AF230 @ 0x4AF230`). This is a
    /// dispatch predicate, not permission to synthesize a Native provider.
    public static func entertainmentVenueDecayApplies(toActiveStateByte byte: Int) -> Bool {
        byte == 1 || byte == 3
    }

    /// Applies the raw count transition emitted by `FUN_004C8B70` for
    /// entertainment figure models 32 (acrobat), 33 (actor), and 34
    /// (musician). This is a research-only helper: the callback's exact
    /// figure-dispatch caller and the meaning/registry lifecycle of record
    /// `+0x5C` remain unresolved, so Native does not invoke it from gameplay.
    /// Unsupported figure models return `nil` rather than treating a shared
    /// switch case as an entertainment rule.
    public static func entertainmentVenueProviderCountAfterFigureCleanup(
        figureModelID: Int,
        providerRecordCount: UInt8
    ) -> UInt8? {
        guard (32...34).contains(figureModelID) else { return nil }
        return providerRecordCount == 0 ? 0 : providerRecordCount - 1
    }

    public struct EntertainmentVenueCapacityState: Sendable, Hashable, Codable {
        public private(set) var acrobat: UInt8
        public private(set) var actor: UInt8
        public private(set) var musician: UInt8

        public init(acrobat: UInt8 = 0, actor: UInt8 = 0, musician: UInt8 = 0) {
            self.acrobat = acrobat
            self.actor = actor
            self.musician = musician
        }

        /// Returns the byte selected by provider vtable `+0x25C` for a
        /// figure-model ID. Unknown model IDs return the executable's
        /// constant `32` result; callers must not interpret it as a valid
        /// capacity for unsupported figures.
        public func capacity(forFigureModelID figureModelID: Int) -> Int {
            switch figureModelID {
            case 32: return Int(acrobat)
            case 33: return Int(actor)
            case 34: return Int(musician)
            default: return 32
            }
        }

        /// Applies the recovered all-three-byte decay and returns the count
        /// written to provider record `+0x5C` before decrementing.
        @discardableResult
        public mutating func decayOnce() -> Int {
            var nonZeroCount = 0
            if acrobat > 0 {
                nonZeroCount += 1
                acrobat -= 1
            }
            if actor > 0 {
                nonZeroCount += 1
                actor -= 1
            }
            if musician > 0 {
                nonZeroCount += 1
                musician -= 1
            }
            return nonZeroCount
        }
    }

    /// Explicit raw provider projection for the scheduler's `+0x9C` callback.
    /// The active-state byte and record `+0x5C` count are kept next to the
    /// three opportunity bytes so a caller cannot accidentally apply the
    /// capacity decay while dropping the source's count write.
    public struct EntertainmentVenueProviderProjection: Sendable, Hashable, Codable {
        public let activeState: Int
        public private(set) var capacity: EntertainmentVenueCapacityState
        public private(set) var recordCount: UInt8

        public init(
            activeState: Int,
            capacity: EntertainmentVenueCapacityState = .init(),
            recordCount: UInt8 = 0
        ) {
            self.activeState = activeState
            self.capacity = capacity
            self.recordCount = recordCount
        }

        /// Applies `FUN_0048AE30` only when the shared scheduler admits the
        /// provider's active-state byte. The returned boolean distinguishes a
        /// dispatched callback from an inactive provider with unchanged data.
        @discardableResult
        public mutating func decayIfActive() -> Bool {
            guard OriginalResidentialServiceCatalog.entertainmentVenueDecayApplies(
                toActiveStateByte: activeState
            ) else { return false }
            recordCount = UInt8(capacity.decayOnce())
            return true
        }
    }

    /// Exact write contract of the venue provider `+0x260` callback
    /// (`FUN_0048B710 @ 0x48B710`). This is metadata only: the live Native
    /// venue walker remains disabled until its route/collision and registry
    /// lifecycle are recovered.
    public struct EntertainmentVenuePerformanceWrite: Sendable, Hashable, Codable {
        /// Provider-record byte written by the callback (`+0x5D/+0x5E/+0x5F`).
        public let recordOffset: UInt8
        /// The callback writes a full 32-slice opportunity value.
        public let value: UInt8
        /// Model 33 also increments the raw auxiliary byte at `+0x64` and
        /// clears it when the incremented value reaches 5.
        public let incrementsAuxiliaryCounter: Bool
        public let auxiliaryCounterOffset: UInt8
        public let auxiliaryCounterResetThreshold: UInt8

        public init(
            recordOffset: UInt8,
            value: UInt8 = 32,
            incrementsAuxiliaryCounter: Bool = false,
            auxiliaryCounterOffset: UInt8 = 0x64,
            auxiliaryCounterResetThreshold: UInt8 = 5
        ) {
            self.recordOffset = recordOffset
            self.value = value
            self.incrementsAuxiliaryCounter = incrementsAuxiliaryCounter
            self.auxiliaryCounterOffset = auxiliaryCounterOffset
            self.auxiliaryCounterResetThreshold = auxiliaryCounterResetThreshold
        }
    }

    /// Returns the provider-record write performed after the venue FSM reaches
    /// its heading-8 callback. Unknown figure models are ignored exactly as
    /// in the executable's default branch.
    public static func entertainmentVenuePerformanceWrite(
        figureModelID: Int
    ) -> EntertainmentVenuePerformanceWrite? {
        switch figureModelID {
        case 32:
            return .init(recordOffset: 0x5D)
        case 33:
            return .init(recordOffset: 0x5F, incrementsAuxiliaryCounter: true)
        case 34:
            return .init(recordOffset: 0x5E)
        default:
            return nil
        }
    }

    /// One source-accurate provider-record transition emitted by
    /// `FUN_0048B710 @ 0x48B710`. The callback always writes the
    /// figure-specific opportunity byte to `0x20`; model `33` additionally
    /// increments record `+0x64` with UInt8 wrap semantics and clears that
    /// byte when the incremented value reaches `5`.
    ///
    /// This is deliberately separate from `EntertainmentVenuePerformanceWrite`:
    /// the latter describes the fixed write shape, while this value type keeps
    /// the prior/next auxiliary state needed by the actor branch. It does not
    /// resolve the venue provider or enable the venue FSM in live simulation.
    public struct EntertainmentVenuePerformanceTransition: Sendable, Hashable, Codable {
        public let recordOffset: UInt8
        public let recordValue: UInt8
        public let auxiliaryCounterOffset: UInt8
        public let auxiliaryCounterBefore: UInt8
        public let auxiliaryCounterAfter: UInt8
        public let auxiliaryCounterWasTouched: Bool
        public let auxiliaryCounterDidReset: Bool

        public init(
            recordOffset: UInt8,
            recordValue: UInt8,
            auxiliaryCounterOffset: UInt8 = 0x64,
            auxiliaryCounterBefore: UInt8,
            auxiliaryCounterAfter: UInt8,
            auxiliaryCounterWasTouched: Bool,
            auxiliaryCounterDidReset: Bool
        ) {
            self.recordOffset = recordOffset
            self.recordValue = recordValue
            self.auxiliaryCounterOffset = auxiliaryCounterOffset
            self.auxiliaryCounterBefore = auxiliaryCounterBefore
            self.auxiliaryCounterAfter = auxiliaryCounterAfter
            self.auxiliaryCounterWasTouched = auxiliaryCounterWasTouched
            self.auxiliaryCounterDidReset = auxiliaryCounterDidReset
        }
    }

    /// Replays the provider-record writes for one supported entertainment
    /// figure. Unknown models return `nil`, matching the callback's default
    /// branch. Models `32` and `34` leave `+0x64` untouched; model `33`
    /// stores `before + 1` first and then clears it when that value is `>= 5`.
    public static func entertainmentVenuePerformanceTransition(
        figureModelID: Int,
        auxiliaryCounter: UInt8 = 0
    ) -> EntertainmentVenuePerformanceTransition? {
        switch figureModelID {
        case 32:
            return .init(
                recordOffset: 0x5D,
                recordValue: 0x20,
                auxiliaryCounterBefore: auxiliaryCounter,
                auxiliaryCounterAfter: auxiliaryCounter,
                auxiliaryCounterWasTouched: false,
                auxiliaryCounterDidReset: false
            )
        case 33:
            let incremented = auxiliaryCounter &+ 1
            let didReset = incremented >= 5
            return .init(
                recordOffset: 0x5F,
                recordValue: 0x20,
                auxiliaryCounterBefore: auxiliaryCounter,
                auxiliaryCounterAfter: didReset ? 0 : incremented,
                auxiliaryCounterWasTouched: true,
                auxiliaryCounterDidReset: didReset
            )
        case 34:
            return .init(
                recordOffset: 0x5E,
                recordValue: 0x20,
                auxiliaryCounterBefore: auxiliaryCounter,
                auxiliaryCounterAfter: auxiliaryCounter,
                auxiliaryCounterWasTouched: false,
                auxiliaryCounterDidReset: false
            )
        default:
            return nil
        }
    }

    /// Exact `cHouseInfo` write emitted by the entertainment provider
    /// callback (`FUN_0048AD20 @ 0x48AD20`). This remains a pure research
    /// primitive: the live venue walker is still disabled until its provider
    /// registry, route/collision, and settlement lifecycle are recovered.
    public struct EntertainmentHouseCoverageWrite: Sendable, Hashable, Codable {
        /// Destination byte in the target `cHouseInfo` record.
        public let houseInfoOffset: UInt8
        /// The callback writes a full 96-slice coverage value.
        public let value: UInt8

        public init(houseInfoOffset: UInt8, value: UInt8 = 0x60) {
            self.houseInfoOffset = houseInfoOffset
            self.value = value
        }
    }

    /// Returns the figure-specific house byte written by the recovered
    /// entertainment coverage callback. The executable first requires the
    /// target building's `+0xB8` eligibility predicate and a strictly
    /// positive target population; either failed gate produces no write.
    /// Unknown figure models are ignored by the callback's default branch.
    public static func entertainmentHouseCoverageWrite(
        figureModelID: Int,
        targetIsEligible: Bool,
        targetPopulation: Int
    ) -> EntertainmentHouseCoverageWrite? {
        guard targetIsEligible, targetPopulation > 0 else { return nil }
        switch figureModelID {
        case 32:
            return .init(houseInfoOffset: 0x2B)
        case 33:
            return .init(houseInfoOffset: 0x2E)
        case 34:
            return .init(houseInfoOffset: 0x2C)
        default:
            return nil
        }
    }
}

/// Model IDs admitted by the executable's post-load missing-object repair
/// switch (`FUN_0052F1D0 @ 0x52F1D0`, consumed by `FUN_0052F030`).  This is a
/// research-only boundary: the repair pass scans already-active objects and
/// may create a replacement object, but it is not the service-provider
/// factory or a provider-registry projection.
public enum OriginalMapArchiveRepairCatalog {
    public static let predicateAddress: UInt32 = 0x0052F1D0
    public static let repairPassAddress: UInt32 = 0x0052F030

    /// Relevant direct callees in the canonical `FUN_0052FDA0` map-load tail,
    /// in source order. These are research metadata only: the inspected
    /// bodies revalidate existing state or serialize auxiliary tables; none is
    /// a recovered residential-service projection edge.
    public static let mainMapLoadAddress: UInt32 = 0x0052FDA0
    public static let directPostLoadTailAddresses: [UInt32] = [
        0x0042D790, // generic Building archive loader
        0x004E1E40, // existing-object +0xF8 revalidation
        0x00506240, // serializer object accessor
        0x00480740, // serializer object accessor
        0x00510E60, // existing object/state reconciliation
        0x00564E30, // worker/commodity table pass
        0x00593140, // auxiliary serializer
        0x0052CD90, // auxiliary serializer
        0x00493F00, // auxiliary serializer
        0x005501B0, // repeated fixed table record serializer
    ]

    /// Version gates from `FUN_0052E7C0 @ 0x52E7C0`.  The map serializer
    /// reads the variable-size Building archive only for schema versions
    /// greater than 3, and reads the trailing `DAT_00F2B290` byte grid only
    /// for versions greater than 4.  Keep these as explicit predicates so a
    /// legacy map cannot be mistaken for a provider/object archive.
    public static let mapSerializerAddress: UInt32 = 0x0052E7C0
    public static let buildingArchiveMinimumVersionExclusive = 3
    public static let roadWaterAuxiliaryMinimumVersionExclusive = 4

    public static func serializesBuildingArchive(formatVersion: Int) -> Bool {
        formatVersion > buildingArchiveMinimumVersionExclusive
    }

    public static func serializesRoadWaterAuxiliaryGrid(formatVersion: Int) -> Bool {
        formatVersion > roadWaterAuxiliaryMinimumVersionExclusive
    }

    /// Direct factory edges recovered from the indexed corpus.  The generic
    /// factory has only two direct callers: `FUN_00427150`, whose sole
    /// corpus caller (`FUN_00541110`) copies an existing object's `+0x158`,
    /// and `Creating_pctd_type_pctd`, the create/replace path below.  This is
    /// a negative map-load boundary, not a claim that an unindexed indirect
    /// or table-driven dispatch cannot exist.
    public static let dynamicFactoryAddress: UInt32 = 0x0042D360
    /// Exact direct E8 call instructions found in both canonical PE images;
    /// the first is the generic `+0x18` conversion caller and the second is
    /// the explicit create/replace path.  This is a confirmed negative for a
    /// direct map-loader factory edge, not a claim that an indirect dispatch
    /// cannot exist.
    public static let dynamicFactoryDirectCallSiteAddresses: [UInt32] = [
        0x0042715E, 0x0042D714
    ]
    public static let dynamicFactoryDirectCallerAddresses: [UInt32] = [
        0x00427150,
        0x0042D540,
    ]
    public static let dynamicFactoryIndirectResidentialDispatcherAddress: UInt32 = 0x0051C660
    public static let dynamicFactoryGenericCallerAddress: UInt32 = 0x00427150
    public static let dynamicFactoryGenericCallerOnlyCallerAddress: UInt32 = 0x00541110

    /// Complete raw `.text` census of indirect calls through vtable slot
    /// `+0x18` in both canonical EN/CH PEs.  This slot is overloaded across
    /// weather, figures, UI, event, monument, and other object families; it
    /// must not be treated as a generic Building-specialization signal.
    /// The list is research metadata only and is intentionally not consumed
    /// by map loading or simulation.
    public static let canonicalIndirectVTableSlot18CallSiteAddresses: [UInt32] = [
        0x0042F1ED, 0x00435ED1, 0x0044ADD2, 0x0044D799, 0x0044D8C0,
        0x0044DD07, 0x004669A2, 0x0046B913, 0x00477E76, 0x004E18F9,
        0x004E6349, 0x004EC4AC, 0x004F3A89, 0x004F3C21, 0x004F3E0E,
        0x004F43F1, 0x004F49F3, 0x004F7B7B, 0x0050373D, 0x005126D6,
        0x005126F4, 0x00512B50, 0x00512E16, 0x00514872, 0x00515AA5,
        0x0052325C, 0x005234E7, 0x0053B05C, 0x0053B124, 0x00541137,
        0x0054FCE2, 0x0054FEF9, 0x0055AE04, 0x0055B757, 0x0055B789,
        0x0055B7AA, 0x0055DCFC, 0x00563FCA, 0x00578775, 0x0057BC3F,
        0x0057D35D, 0x005894DD, 0x005B4C90, 0x005B4E26, 0x005C04B6,
        0x005C766C, 0x005C76E9, 0x005C7726, 0x005C7775, 0x005D0D5A,
        0x005FCC8C, 0x00602B50, 0x006143AC, 0x006163E6, 0x006163FA,
        0x00616508, 0x00616843, 0x00616928, 0x00617A5F, 0x00617FD3,
        0x0062DA25, 0x00640CEC, 0x00644C87, 0x00646B40, 0x00646D2C,
        0x0064D03F, 0x0065405A, 0x0065B4AD, 0x0065D94B, 0x0065F0F4,
        0x006C4477, 0x006C62CB, 0x006C6FD1, 0x006CDAB6, 0x006E522A,
        0x006E5E32, 0x006E5F04, 0x00735E74, 0x0073EB9F, 0x007403A6,
        0x007456B8, 0x00747929, 0x00756DBE, 0x007803DF,
    ]

    /// No slot-`+0x18` call instruction occurs inside the recovered generic
    /// archive loader or its direct map-load tail.  This is a confirmed
    /// negative for that direct virtual-call edge only; table-driven and
    /// register-propagated dispatch remain outside the census contract.
    public static let mapLoadIndirectVTableSlot18CallSiteAddresses: [UInt32] = []

    /// Static loader boundary recovered from the canonical executable. The
    /// archive path first constructs a generic `Building` descriptor, inserts
    /// it into the object list, and then invokes the object's `+0xC0` load
    /// callback. These addresses are research metadata only: the callback
    /// does not specialize residential-service providers or reconstruct their
    /// provider registry links.
    public static let mapLoaderAddress: UInt32 = 0x0042D790
    public static let genericClassLoaderAddress: UInt32 = 0x0042D0E0
    /// The `Building` MFC descriptor at `0x817890` stores constructor
    /// `FUN_0042D050`, which installs the base vtable `0x7AB59C`.  Keep this
    /// separate from the factory's `FUN_0051C9A0` fallback and its
    /// intermediate `cIndustrialBldg` vtable `0x7B65E4`.
    public static let genericBuildingConstructorAddress: UInt32 = 0x0042D050
    public static let genericBuildingVTableAddress: UInt32 = 0x007AB59C
    public static let factoryFallbackConstructorAddress: UInt32 = 0x0051C9A0
    public static let factoryFallbackVTableAddress: UInt32 = 0x007B65E4
    public static let listInsertAddress: UInt32 = 0x0042B590
    public static let listInsertHelperAddress: UInt32 = 0x005F01F0
    public static let loadCallbackVTableOffset: UInt32 = 0x000000C0
    public static let genericLoadCallbackAddress: UInt32 = 0x004271B0
    public static let genericClassToken = "Building"
    /// `FUN_0042D790` invokes the loaded object's `+0xC0` callback only when
    /// byte `local_18[1]` is non-zero.  The decompiler's `local_18` points to
    /// the object base, so this is the raw object offset `+0x04`; its semantic
    /// name is intentionally unresolved.
    public static let loadCallbackEligibilityFieldOffset: Int = 0x04

    /// Existing-object map-load/revalidation passes call vtable `+0xF8`
    /// (`FUN_004E1E40` and the main setup wrapper `FUN_00534BF0`).  The
    /// Qin-relevant vtables inspected in the canonical EN/CH images all point
    /// at the same pure predicate: `xor eax,eax; cmp word [ecx+0x1C],0;
    /// setg al; ret`.  This is evidence metadata only; it is not a provider
    /// registration or archive-specialization hook.
    public static let existingObjectRevalidationVTableOffset: UInt32 = 0xF8
    public static let existingObjectRevalidationCallbackAddress: UInt32 = 0x00416A90
    public static let existingObjectRevalidationStateWordOffset: Int = 0x1C
    public static let existingObjectRevalidationRequiresPositiveStateWord = true

    public struct ExistingObjectRevalidationVTableDescriptor: Sendable, Hashable, Codable {
        public let label: String
        public let vtableAddress: UInt32
        public let callbackAddress: UInt32

        public init(label: String, vtableAddress: UInt32, callbackAddress: UInt32) {
            self.label = label
            self.vtableAddress = vtableAddress
            self.callbackAddress = callbackAddress
        }
    }

    /// Vtable words read directly from both canonical PE images.  The list is
    /// intentionally limited to classes which participate in the Qin map,
    /// placement, or provider/venue catalogs already recorded here.
    public static let existingObjectRevalidationVTableDescriptors: [ExistingObjectRevalidationVTableDescriptor] = [
        .init(label: "Building", vtableAddress: 0x007AB59C, callbackAddress: existingObjectRevalidationCallbackAddress),
        .init(label: "HouseBldg", vtableAddress: 0x007ABA38, callbackAddress: existingObjectRevalidationCallbackAddress),
        .init(label: "Well", vtableAddress: 0x007B5EB4, callbackAddress: existingObjectRevalidationCallbackAddress),
        .init(label: "Herbalist", vtableAddress: 0x007B6114, callbackAddress: existingObjectRevalidationCallbackAddress),
        .init(label: "Acupuncture", vtableAddress: 0x007B6374, callbackAddress: existingObjectRevalidationCallbackAddress),
        .init(label: "Common/Grand Market", vtableAddress: 0x007B6F3C, callbackAddress: existingObjectRevalidationCallbackAddress),
        .init(label: "Entertainment Area", vtableAddress: 0x007AD878, callbackAddress: existingObjectRevalidationCallbackAddress),
        .init(label: "Music School", vtableAddress: 0x007ACEDC, callbackAddress: existingObjectRevalidationCallbackAddress),
        .init(label: "Acrobat School", vtableAddress: 0x007AD140, callbackAddress: existingObjectRevalidationCallbackAddress),
        .init(label: "Drama School", vtableAddress: 0x007AD3A4, callbackAddress: existingObjectRevalidationCallbackAddress),
        .init(label: "Laborers' Camp", vtableAddress: 0x007B4FF8, callbackAddress: existingObjectRevalidationCallbackAddress),
        .init(label: "Residential Wall", vtableAddress: 0x007AAAB8, callbackAddress: existingObjectRevalidationCallbackAddress),
        .init(label: "Residential Gate", vtableAddress: 0x007AAFB0, callbackAddress: existingObjectRevalidationCallbackAddress),
    ]

    public static func existingObjectRevalidationDescriptor(
        forVTableAddress vtableAddress: UInt32
    ) -> ExistingObjectRevalidationVTableDescriptor? {
        existingObjectRevalidationVTableDescriptors.first {
            $0.vtableAddress == vtableAddress
        }
    }

    public static func invokesLoadCallback(eligibilityByte: UInt8) -> Bool {
        eligibilityByte != 0
    }

    /// Gate for the post-load object pass `FUN_0042DA10 @ 0x42DA10`.
    ///
    /// The executable walks the active object vector from index 1 and invokes
    /// each object's virtual `+0x1C8` method when the global
    /// `FUN_00426D10(0)` gate is open, or when the object's raw state byte at
    /// `+0x04` equals `6`.  This helper records only that dispatch gate.  The
    /// concrete `+0x1C8` implementations are class-dependent; for the
    /// Qin-relevant vtables listed below, the raw EN/CH tables point at the
    /// constant-false `FUN_00413A00`.  Unlisted classes remain unresolved, so
    /// Native must not invoke this pass from map loading or simulation.
    public static let postLoadObjectPassAddress: UInt32 = 0x0042DA10
    public static let postLoadObjectCallbackVTableOffset: UInt32 = 0x000001C8
    public static let postLoadObjectStateFieldOffset: Int = 0x04
    public static let postLoadObjectForcedStateByte: UInt8 = 0x06

    /// `+0x1C8` callback target recovered from the Qin-relevant EN/CH vtable
    /// words. `FUN_00413A00` is an exact `return 0` body in both variants.
    /// These are raw dispatch facts only; they do not establish provider
    /// registration, archive projection, or settlement semantics.
    public static let postLoadObjectNoOpCallbackAddress: UInt32 = 0x00413A00

    public struct PostLoadObjectNoOpVTableDescriptor: Sendable, Hashable, Codable {
        public let label: String
        public let vtableAddress: UInt32
        public let callbackAddress: UInt32

        public init(label: String, vtableAddress: UInt32, callbackAddress: UInt32) {
            self.label = label
            self.vtableAddress = vtableAddress
            self.callbackAddress = callbackAddress
        }
    }

    /// Base Building plus the three residential-service and four
    /// entertainment vtables whose `+0x1C8` words were read directly from
    /// both hash-matched PE images.
    public static let postLoadObjectNoOpVTableDescriptors: [PostLoadObjectNoOpVTableDescriptor] = [
        .init(label: "Building", vtableAddress: 0x007AB59C, callbackAddress: postLoadObjectNoOpCallbackAddress),
        .init(label: "Well", vtableAddress: 0x007B5EB4, callbackAddress: postLoadObjectNoOpCallbackAddress),
        .init(label: "Herbalist", vtableAddress: 0x007B6114, callbackAddress: postLoadObjectNoOpCallbackAddress),
        .init(label: "Acupuncture", vtableAddress: 0x007B6374, callbackAddress: postLoadObjectNoOpCallbackAddress),
        .init(label: "Entertainment Area", vtableAddress: 0x007AD878, callbackAddress: postLoadObjectNoOpCallbackAddress),
        .init(label: "Music School", vtableAddress: 0x007ACEDC, callbackAddress: postLoadObjectNoOpCallbackAddress),
        .init(label: "Acrobat School", vtableAddress: 0x007AD140, callbackAddress: postLoadObjectNoOpCallbackAddress),
        .init(label: "Drama School", vtableAddress: 0x007AD3A4, callbackAddress: postLoadObjectNoOpCallbackAddress),
    ]

    public static func postLoadObjectNoOpVTableDescriptor(
        forVTableAddress vtableAddress: UInt32
    ) -> PostLoadObjectNoOpVTableDescriptor? {
        postLoadObjectNoOpVTableDescriptors.first {
            $0.vtableAddress == vtableAddress
        }
    }

    public static func postLoadObjectCallbackIsNoOp(forVTableAddress vtableAddress: UInt32) -> Bool {
        postLoadObjectNoOpVTableDescriptor(forVTableAddress: vtableAddress) != nil
    }

    /// The callback used by `FUN_004B11F0` after a created or repaired object
    /// has been linked into the map.  This is a different virtual slot from
    /// the map-load `+0xC0` callback and the post-load `+0x1C8` walk above.
    /// Direct EN/CH vtable reads show that the generic `Building` object is a
    /// constant-false stub, while HouseBldg and the service/entertainment
    /// providers use class-specific callbacks.  These are dispatch facts
    /// only: they do not authorize promoting a Qin archive row into a
    /// specialized runtime object.
    public static let linkedObjectCallbackVTableOffset: UInt32 = 0x00000100
    public static let linkedObjectCallbackAddress: UInt32 = 0x004B11F0
    public static let genericBuildingLinkedCallbackAddress: UInt32 = 0x00428F10
    public static let genericBuildingLinkedCallbackReturnsFalse = true
    public static let houseBldgLinkedCallbackAddress: UInt32 = 0x00519F30
    public static let residentialServiceLinkedCallbackAddress: UInt32 = 0x0051DD20
    public static let entertainmentAreaLinkedCallbackAddress: UInt32 = 0x0048D230

    public struct LinkedObjectCallbackVTableDescriptor: Sendable, Hashable, Codable {
        public let label: String
        public let vtableAddress: UInt32
        public let callbackAddress: UInt32

        public init(label: String, vtableAddress: UInt32, callbackAddress: UInt32) {
            self.label = label
            self.vtableAddress = vtableAddress
            self.callbackAddress = callbackAddress
        }
    }

    /// Vtable slices read at `vtable + 0x100` in both canonical executables.
    public static let linkedObjectCallbackVTableDescriptors: [LinkedObjectCallbackVTableDescriptor] = [
        .init(label: "Building", vtableAddress: 0x007AB59C, callbackAddress: genericBuildingLinkedCallbackAddress),
        .init(label: "HouseBldg", vtableAddress: 0x007ABA38, callbackAddress: houseBldgLinkedCallbackAddress),
        .init(label: "Well", vtableAddress: 0x007B5EB4, callbackAddress: residentialServiceLinkedCallbackAddress),
        .init(label: "Herbalist", vtableAddress: 0x007B6114, callbackAddress: residentialServiceLinkedCallbackAddress),
        .init(label: "Acupuncture", vtableAddress: 0x007B6374, callbackAddress: residentialServiceLinkedCallbackAddress),
        .init(label: "Entertainment Area", vtableAddress: 0x007AD878, callbackAddress: entertainmentAreaLinkedCallbackAddress),
        .init(label: "Music School", vtableAddress: 0x007ACEDC, callbackAddress: residentialServiceLinkedCallbackAddress),
        .init(label: "Acrobat School", vtableAddress: 0x007AD140, callbackAddress: residentialServiceLinkedCallbackAddress),
        .init(label: "Drama School", vtableAddress: 0x007AD3A4, callbackAddress: residentialServiceLinkedCallbackAddress),
    ]

    public static func linkedObjectCallbackAddress(
        forVTableAddress vtableAddress: UInt32
    ) -> UInt32? {
        linkedObjectCallbackVTableDescriptors.first {
            $0.vtableAddress == vtableAddress
        }?.callbackAddress
    }

    /// cMarket's post-load callback is a thunk rather than the common
    /// constant-false callback used by the service/entertainment vtables
    /// above.  `0x543770` loads `cMarket + 0x158` and dispatches its helper's
    /// virtual `+0x60` entry.  The helper target differs by market model:
    /// Common Market uses the same no-op body, while Grand Market uses the
    /// map-cache rebuild at `0x543360`.  These are raw dispatch facts only;
    /// neither target writes a provider registry link or settles a house.
    public static let cMarketVTableAddress: UInt32 = 0x007B6F3C
    public static let cMarketPostLoadThunkAddress: UInt32 = 0x00543770
    public static let commonMarketHelperVTableAddress: UInt32 = 0x007AB800
    public static let grandMarketHelperVTableAddress: UInt32 = 0x007AB878
    public static let commonMarketHelperPostLoadAddress: UInt32 = 0x00413A00
    public static let grandMarketHelperPostLoadAddress: UInt32 = 0x00543360

    public static func cMarketHelperPostLoadAddress(
        forMarketBuildingID buildingID: Int
    ) -> UInt32? {
        switch buildingID {
        case 59: return commonMarketHelperPostLoadAddress
        case 60: return grandMarketHelperPostLoadAddress
        default: return nil
        }
    }

    public static func invokesPostLoadObjectCallback(
        globalGateOpen: Bool,
        objectStateByte: UInt8
    ) -> Bool {
        globalGateOpen || objectStateByte == postLoadObjectForcedStateByte
    }

    /// Exact switch cases from `FUN_0052F1D0`, kept in ascending model order.
    public static let admittedModelIDs: [Int] = [
        83, 89, 90, 91, 104, 105, 106, 123, 129, 130, 131, 210, 231, 232,
        253, 254, 255, 256, 257, 258, 259, 260, 261, 262, 263, 264, 265,
        266, 267, 268
    ]

    public static func admits(modelID: Int) -> Bool {
        admittedModelIDs.contains(modelID)
    }
}

/// The three provider-link slots that the original HouseBldg helpers inspect.
///
/// `FUN_00429700` reads the direct house-object slot at `+0x2E`, while
/// `FUN_00429780` and `FUN_00429810` read the two `cHouseInfo` slots at
/// `+0x6A` and `+0x6C` through the house `+0x1E8` accessor.  These are raw
/// object-layout facts only; Native has not recovered the Qin archive's
/// provider registry or a safe projection into these slots.
public enum OriginalResidentialProviderLinkCatalog {
    public enum Slot: Int, CaseIterable, Sendable, Hashable {
        case directHouseObject = 0x2E
        case houseInfoPrimary = 0x6A
        case houseInfoSecondary = 0x6C
    }

    /// Mirrors the common active/parent/type checks in
    /// `FUN_00429700`, `FUN_00429780`, and `FUN_00429810`.
    ///
    /// The two type bytes are the two arguments supplied by the caller.  The
    /// executable accepts either one, then requires the provider's parent
    /// word (`+0x62`) to equal the house registry ID (`+0x2D`).
    public static func validatesTypedLink(
        providerActive: Bool,
        providerType: UInt8,
        acceptedTypeA: UInt8,
        acceptedTypeB: UInt8,
        providerParentID: Int,
        houseRegistryID: Int
    ) -> Bool {
        providerActive
            && (providerType == acceptedTypeA || providerType == acceptedTypeB)
            && providerParentID == houseRegistryID
    }

    /// Mirrors the untyped `param_2 == 0` branch used by
    /// `FUN_004291A0`: an active provider is retained when its parent word
    /// matches the house registry ID, without a provider-type comparison.
    public static func validatesUntypedLink(
        providerActive: Bool,
        providerParentID: Int,
        houseRegistryID: Int
    ) -> Bool {
        providerActive && providerParentID == houseRegistryID
    }
}

/// The exact branch boundary shared by the source house-evolution and
/// migration paths at `FUN_00519F30 @ 0x519F30`.
///
/// This is deliberately a pure dispatch primitive.  Native has not recovered
/// the object-vector/provider projection or the complete lifecycle of the
/// vacant-house type switch, so this must not mutate a `ResidentialUnit`.
public enum OriginalHouseVacantTypeTransition {
    public enum Action: Sendable, Hashable, Codable {
        /// `FUN_00519060(object + 0x2D)` rebuilds a vacant house when the
        /// source's cHouseInfo/resident gates are zero and its provider
        /// predicate is false.
        case rebuildVacant(objectRegistryIndex: Int)
        /// The source invokes the current house vtable `+0x230` with the
        /// caller-supplied argument when the rebuild branch is not admitted.
        case invokeTypeSwitch(argument: Int)
    }

    public static let dispatchAddress: UInt32 = 0x00519F30
    public static let cHouseInfoGetterVTableOffset: UInt32 = 0x1E4
    public static let cHouseInfoGateOffset: UInt32 = 0x3C
    public static let residentWordOffset: UInt32 = 0x20
    public static let providerPredicateVTableOffset: UInt32 = 0x204
    public static let vacantRebuildAddress: UInt32 = 0x00519060
    public static let typeSwitchVTableOffset: UInt32 = 0x230

    /// Mirrors the source ordering exactly.  The `+0x204` predicate is
    /// consulted only when both cHouseInfo `+0x3C` and the resident word are
    /// zero; otherwise the source falls through directly to `+0x230`.
    public static func action(
        houseInfoGateIsZero: Bool,
        residentWordIsZero: Bool,
        providerPredicatePasses: Bool,
        objectRegistryIndex: Int,
        typeSwitchArgument: Int
    ) -> Action {
        if houseInfoGateIsZero,
           residentWordIsZero,
           !providerPredicatePasses {
            return .rebuildVacant(objectRegistryIndex: objectRegistryIndex)
        }
        return .invokeTypeSwitch(argument: typeSwitchArgument)
    }
}

/// The recovered well-provider transition at executable `0x51CEC0`.
///
/// This is deliberately a pure research primitive. Native does not yet have
/// an isomorphic provider object or the refresh-time field writer for its
/// appeal-buffer index, so the transition is not wired into `CitySimulation`
/// or the `.water` requirement.
/// `appealValue` is the sign-extended byte read from the original
/// `DAT_00F11C70` buffer by `0x4273F0 → 0x44F180`; `threshold` is the runtime
/// value returned by `FUN_0044CC50(buildingID, 10)`.
public enum OriginalWaterProviderState {
    /// Direct-call metadata for the original provider state scheduler.
    /// The scheduler is entered from calendar phase `0x24` only in the
    /// canonical direct-call census; its object-vector and vtable dispatch
    /// remain source evidence rather than a Native provider bridge.
    public struct ProviderSchedulerBoundary: Sendable, Hashable, Codable {
        public static let schedulerAddress: UInt32 = 0x00517AD0
        public static let phaseDispatcherAddress: UInt32 = 0x004AC2B0
        public static let phaseValue: Int = 0x24
        public static let directCallSites: [UInt32] = [0x004AC473]
        public static let directCallerAddresses: [UInt32] = [0x004AC2B0]
        public static let providerEligibilityVTableOffset: UInt32 = 0xB8
        public static let providerUpdateVTableOffset: UInt32 = 0x218
        public static let globalGateAddress: UInt32 = 0x00426D10
    }

    /// The only direct caller of `FUN_00511860 @ 0x511860` in the
    /// hash-matched EN/CH PEs is the omitted/interior eHIB command dispatcher
    /// at `0x515800`.  Its command switch subtracts 100 from
    /// `DAT_010C6F60`; command `0x69` reaches the adjacency callback at
    /// `0x515913`, which can write the Well-family `+0x6F` byte.  This is an
    /// input/ownership boundary only: the command's user-facing meaning,
    /// upstream record producer, and live provider linkage remain unknown.
    public struct WellCommandStateTrigger: Sendable, Hashable, Codable {
        public static let dispatcherAddress: UInt32 = 0x00515800
        public static let callbackAddress: UInt32 = 0x00511860
        public static let callbackCallSiteAddress: UInt32 = 0x00515913
        public static let commandGlobalAddress: UInt32 = 0x010C6F60
        public static let commandValue: Int = 0x69

        /// The PE callsite is command-owned, not a monthly/calendar or
        /// map-load producer.  Keep this explicit so a future Qin bridge
        /// cannot treat the callback as an automatic service scheduler.
        public static let isAutomaticSimulationProducer = false
    }

    /// Raw zero-initialized provider fields established by the shared
    /// residential-provider constructor (`FUN_0051C2E0 @ 0x51C2E0`) before
    /// the Well vtable is installed. The constructor clears the provider word
    /// read by `+0x224` (`+0x16`) and the command byte at `+0x6F`.
    /// `FUN_0048E110`'s alternate `+0x54/+0x58` check is on the independent
    /// global object returned by `FUN_0048DF30`, so it is intentionally not
    /// included here. These are storage facts only: later provider and global
    /// context writers are not recovered.
    public struct NewlyConstructedProviderState: Sendable, Hashable, Codable {
        public let providerWord16: Int16
        public let providerByte6F: UInt8

        public init(
            providerWord16: Int16 = 0,
            providerByte6F: UInt8 = 0
        ) {
            self.providerWord16 = providerWord16
            self.providerByte6F = providerByte6F
        }

        public static let sourceConstructorAddress: UInt32 = 0x0051C2E0
        public static let sharedBaseConstructorAddress: UInt32 = 0x0051BA50
        public static let wellInitializerAddress: UInt32 = 0x0051C090

        /// The state emitted by a newly allocated Well-family provider before
        /// any later command or context update is applied.
        public static let well = Self()
    }

    /// `FUN_0051CEC0` obtains the Well transition threshold through
    /// `FUN_0044CC50(72, 10)`. Building-model field 10 is the authored
    /// evolve-desirability value; Well row 72 supplies 40, and every
    /// difficulty modifier keeps field 10 at 100%, so the runtime value is
    /// 40 across the authored difficulty rows.
    public static let wellAppealThreshold = 40

    /// `FUN_00511080`'s case-6 Well branch raises the candidate provider's
    /// `+0x6F` byte to `FUN_00511700(6) = 0x60`, preserving a larger existing
    /// byte. The command/event trigger and registry projection remain outside
    /// this pure research boundary.
    public static let wellCommandStateValue: UInt8 = 0x60

    /// The controller-record envelope that can publish the external command
    /// consumed by `TBD_Hit_eHIB_CallTroops @ 0x515800`.  This mirrors
    /// `FUN_005C0E80 @ 0x5C0E80`: an inactive record is ignored; the global
    /// `+0x70` gate takes the primary callback, otherwise record mode `1` or
    /// `3` takes the secondary callback when its corresponding global gate is
    /// open.  The command/payload are copied before the callback is invoked.
    /// This is an input-envelope fact only; it does not assign a meaning to
    /// command `0x69`, invoke the callback, or connect it to a live Qin
    /// provider.
    public struct ControllerCommandDispatch: Sendable, Hashable, Codable {
        public enum Callback: String, Sendable, Hashable, Codable {
            case primary14C
            case secondary150
        }

        public let command: Int
        public let payload: Int
        public let callback: Callback

        public init(command: Int, payload: Int, callback: Callback) {
            self.command = command
            self.payload = payload
            self.callback = callback
        }
    }

    /// Reproduces the complete gate order of `FUN_005C0E80`.
    public static func controllerCommandDispatch(
        recordActive: Bool,
        primaryGateOpen: Bool,
        secondaryGateOneOpen: Bool,
        secondaryGateThreeOpen: Bool,
        recordMode: UInt8,
        command: Int,
        payload: Int
    ) -> ControllerCommandDispatch? {
        guard recordActive else { return nil }
        if primaryGateOpen {
            return .init(command: command, payload: payload, callback: .primary14C)
        }
        if (secondaryGateOneOpen && recordMode == 1)
            || (secondaryGateThreeOpen && recordMode == 3) {
            return .init(command: command, payload: payload, callback: .secondary150)
        }
        return nil
    }

    /// One exact phase-`0x24` provider-scheduler admission pass from
    /// `FUN_00517AD0 @ 0x517AD0`. The executable walks the live provider
    /// vector in stored order, checks the shared `FUN_00426D10(0)` gate for
    /// each entry, then checks that provider's virtual `+0xB8` eligibility
    /// before invoking virtual `+0x218`. This helper returns only the vector
    /// indices that reach the update call; it does not invent the unresolved
    /// provider registry or invoke any vtable method.
    public static func phase24ProviderUpdateIndices(
        globalGateOpen: Bool,
        providerEligibility: [Bool]
    ) -> [Int] {
        guard globalGateOpen else { return [] }
        return providerEligibility.indices.filter { providerEligibility[$0] }
    }

    /// Admission result from the eight-neighbour candidate scan used by
    /// `FUN_00511710 @ 0x511710` and `FUN_00511B10 @ 0x511B10`.
    ///
    /// The source-category meaning is not recovered, so callers must supply
    /// the category byte observed on the controller.  Category 4 has an
    /// additional six-slot/object callback check for models 59, 60, and 71;
    /// that unresolved result is represented explicitly rather than treated
    /// as an unconditional match.
    public enum AdjacentTargetAdmission: Sendable, Hashable {
        case rejected
        case accepted
        case requiresAuxiliaryCheck
    }

    /// Reproduces the model whitelist in `FUN_00511B10` after the candidate's
    /// vtable `+0x1D0` active check in `FUN_00511710`.
    ///
    /// This is a field-level research primitive only.  It does not scan map
    /// cells, resolve registry IDs, or invoke the `+0x1D0` virtual predicate.
    /// For category 4, pass `auxiliaryCheckPassed` only when the executable's
    /// additional `FUN_00544A00` six-slot check (and, for model 71, its
    /// `+0x268` child resolution) has already succeeded.
    public static func adjacentTargetAdmission(
        sourceCategory: Int,
        targetModelID: Int,
        targetReportsActive: Bool = false,
        auxiliaryCheckPassed: Bool = false
    ) -> AdjacentTargetAdmission {
        guard !targetReportsActive else { return .rejected }

        switch sourceCategory {
        case 0:
            return [31, 33, 35, 124].contains(targetModelID) ? .accepted : .rejected
        case 1:
            return [192, 193].contains(targetModelID) ? .accepted : .rejected
        case 2:
            return [43, 239].contains(targetModelID) ? .accepted : .rejected
        case 3:
            return targetModelID == 46 ? .accepted : .rejected
        case 4:
            switch targetModelID {
            case 66:
                return .accepted
            case 59, 60, 71:
                return auxiliaryCheckPassed ? .accepted : .requiresAuxiliaryCheck
            default:
                return .rejected
            }
        case 5:
            return [53, 54, 219, 220, 221, 223, 224, 225].contains(targetModelID)
                ? .accepted : .rejected
        case 6:
            return [72, 73].contains(targetModelID) ? .accepted : .rejected
        case 7:
            return [237, 127].contains(targetModelID) ? .accepted : .rejected
        case 8:
            return [226, 36].contains(targetModelID) ? .accepted : .rejected
        case 9:
            return targetModelID == 125 ? .accepted : .rejected
        case 10:
            return [220, 221, 223, 224, 225].contains(targetModelID)
                ? .accepted : .rejected
        case 11:
            return [56, 58].contains(targetModelID) ? .accepted : .rejected
        default:
            return .rejected
        }
    }

    public static func raisedWellCommandState(currentByte6F: UInt8) -> UInt8 {
        max(currentByte6F, wellCommandStateValue)
    }

    /// One exact `FUN_0042DA70 @ 0x42DA70` command-state decay pass.
    ///
    /// `FUN_0042DA70` is called by `FUN_004AC650` when the 0x33-step scheduler
    /// phase wraps.  With the global `FUN_00426D10(0)` gate open, each active
    /// object's non-zero `+0x6F` byte is decremented once; a byte that reaches
    /// zero invokes that object's vtable `+0x100` callback with its model and
    /// creation-origin arguments.  The object vector, callback receiver, and
    /// provider registry are deliberately not represented here.
    public struct CommandStateDecayOutcome: Sendable, Hashable, Codable {
        public let nextByte6F: UInt8
        public let didExpire: Bool

        public init(nextByte6F: UInt8, didExpire: Bool) {
            self.nextByte6F = nextByte6F
            self.didExpire = didExpire
        }
    }

    public static func decayCommandState(
        currentByte6F: UInt8,
        globalGateOpen: Bool
    ) -> CommandStateDecayOutcome {
        guard globalGateOpen, currentByte6F > 0 else {
            return .init(nextByte6F: currentByte6F, didExpire: false)
        }
        let next = currentByte6F - 1
        return .init(nextByte6F: next, didExpire: next == 0)
    }

    /// Result of the bounded registry-parent walk in
    /// `FUN_004B3930 @ 0x4B3930`.  The executable resolves the current
    /// object through `FUN_0047F1B0`, reads its signed-short `+0x3C` parent
    /// link, and stops on the first link below `1`.  A missing dictionary
    /// entry is represented separately so a research caller cannot silently
    /// treat an absent object as a root.  After 500 positive links the
    /// executable returns `0`; the explicit case preserves that source
    /// outcome without making `0` a valid Native registry identifier.
    public enum RegistryParentChainResolution: Sendable, Hashable, Codable {
        case terminal(registryID: Int)
        case missing(registryID: Int)
        case sourceZeroAfterHopLimit
    }

    /// Raw object offset and loop bound used by `FUN_004B3930`.
    public static let registryParentLinkFieldOffset: Int = 0x3C
    public static let registryParentMaximumHops = 500

    /// Follows only the confirmed `+0x3C` parent-link arithmetic.  The
    /// subsequent `FUN_004B38C0` root virtual checks and `+0xB4` projection
    /// are intentionally outside this helper because their receiver and
    /// provider semantics remain unresolved.
    public static func resolveRegistryParentChain(
        startRegistryID: Int,
        parentRegistryIDs: [Int: Int16]
    ) -> RegistryParentChainResolution {
        var current = startRegistryID
        for _ in 0..<registryParentMaximumHops {
            guard let parent = parentRegistryIDs[current] else {
                return .missing(registryID: current)
            }
            guard parent >= 1 else {
                return .terminal(registryID: current)
            }
            current = Int(parent)
        }
        return .sourceZeroAfterHopLimit
    }

    /// Mirrors the parent-link repair tail of `FUN_0051CCA0 @ 0x51CCA0`.
    /// The caller supplies the object already resolved from the non-zero
    /// parent short through the executable's registry lookup. The original
    /// keeps the short only when the target active byte is exactly `1` and
    /// target word `+0x68` equals the provider registry index `+0x2D`;
    /// otherwise it clears the short to zero. This remains a field-level
    /// primitive because Native has not recovered the provider registry or
    /// serialized parent-link source.
    public static func validatedParentShort(
        parentShort: Int16,
        targetActiveByte: UInt8,
        targetField68: Int16,
        providerRegistryID: Int
    ) -> Int16 {
        guard parentShort != 0 else { return 0 }
        guard targetActiveByte == 1,
              Int(targetField68) == providerRegistryID else {
            return 0
        }
        return parentShort
    }

    /// The two independent `cHouseInfo` water bytes written by `0x51BC00`.
    ///
    /// This is intentionally a low-level field identity, not a Native service
    /// requirement. The original callback writes `+0x34` when the provider
    /// `+0x224` predicate is true or when its alternate global-context branch
    /// matches; all other successful calls write `+0x32`. Both bytes have
    /// distinct consumers and lifetimes.
    public enum HouseInfoWaterByte: Sendable, Hashable {
        case primary32
        case secondary34
    }

    /// Result of one confirmed `FUN_0051BC00` water callback invocation.
    /// The provider/house object lookup is intentionally outside this helper;
    /// callers must supply its already-resolved gate values explicitly.
    public struct HouseInfoWaterWriteOutcome: Sendable, Hashable {
        public let didWrite: Bool
        public let destination: HouseInfoWaterByte?
        public let primary32: Int
        public let secondary34: Int

        public init(
            didWrite: Bool,
            destination: HouseInfoWaterByte?,
            primary32: Int,
            secondary34: Int
        ) {
            self.didWrite = didWrite
            self.destination = destination
            self.primary32 = primary32
            self.secondary34 = secondary34
        }
    }

    /// Building-side compact status projected by `FUN_005179B0 @ 0x5179B0`.
    ///
    /// This is a separate object field from both `cHouseInfo` water bytes:
    /// the phase pass clears Building `+0x39`, then assigns `1` when `+0x32`
    /// is non-zero and `2` when `+0x34` is non-zero. Because the second test
    /// runs last, `.secondary34` wins when both bytes are live. The helper is
    /// intentionally pure; the registry/object bridge that supplies the
    /// projection is not yet recovered, so gameplay does not call it.
    public enum BuildingWaterStatus: Int, Sendable, Hashable {
        case none = 0
        case primary32 = 1
        case secondary34 = 2
    }

    /// Reproduces the Well vtable `+0x224` predicate at `0x5B3AD0`.
    ///
    /// The executable compares provider word `+0x16` as a signed 16-bit
    /// value (`jg`) and then tests provider byte `+0x6F` as an unsigned byte.
    /// This is intentionally lower-level than a `.water` service result: the
    /// provider object, its map registry identity, and the writers that feed
    /// these fields are not recovered for Native.
    public static func providerVTable224Predicate(
        providerWord16: Int16,
        providerByte6F: UInt8
    ) -> Bool {
        providerWord16 > 0 || providerByte6F > 0
    }

    /// Selects the destination byte used by `FUN_0051BC00 @ 0x51BC00`.
    ///
    /// The Well provider is created by `FUN_0051BEF0(72)` and uses vtable
    /// `0x7B5EB4`, whose `+0x224 = FUN_005B3AD0` returns true when
    /// `providerVTable224Predicate` is true. The `FUN_0048CB10` /
    /// `0x7AD878` constant-false slot belongs to Entertainment Area model 71,
    /// not Well. The predicate's human-facing meaning remains unknown, so
    /// callers must supply the recovered low-level state explicitly.
    public static func houseInfoWaterByte(
        providerVTable224: Bool,
        globalContextActive: Bool,
        globalState54: Int,
        globalState58: Int
    ) -> HouseInfoWaterByte {
        if providerVTable224
            || (globalContextActive && globalState54 == 3 && globalState58 == 4) {
            return .secondary34
        }
        return .primary32
    }

    /// Applies the exact gate and byte write from `FUN_0051BC00 @ 0x51BC00`.
    /// `globalGateOpen` models the initial `FUN_00426D10(0)` check;
    /// `targetVTableB8` is the candidate-house `+0xB8` result and
    /// `targetField20` is the positive `cHouseInfo +0x20` check. A successful
    /// callback writes `0x60` to the selected byte while preserving the other.
    public static func writeHouseInfoWater(
        globalGateOpen: Bool,
        targetVTableB8: Bool,
        targetField20: Int,
        providerVTable224: Bool,
        globalContextActive: Bool,
        globalState54: Int,
        globalState58: Int,
        primary32: Int,
        secondary34: Int
    ) -> HouseInfoWaterWriteOutcome {
        guard globalGateOpen, targetVTableB8, targetField20 > 0 else {
            return HouseInfoWaterWriteOutcome(
                didWrite: false,
                destination: nil,
                primary32: primary32,
                secondary34: secondary34
            )
        }
        let destination = houseInfoWaterByte(
            providerVTable224: providerVTable224,
            globalContextActive: globalContextActive,
            globalState54: globalState54,
            globalState58: globalState58
        )
        return HouseInfoWaterWriteOutcome(
            didWrite: true,
            destination: destination,
            primary32: destination == .primary32 ? 0x60 : primary32,
            secondary34: destination == .secondary34 ? 0x60 : secondary34
        )
    }

    /// Projects the two independent house-info bytes to Building `+0x39`.
    ///
    /// This preserves the executable's assignment order exactly: a non-zero
    /// secondary byte overrides a non-zero primary byte.
    public static func buildingWaterStatus(
        primary32: Int,
        secondary34: Int
    ) -> BuildingWaterStatus {
        if secondary34 != 0 {
            return .secondary34
        }
        if primary32 != 0 {
            return .primary32
        }
        return .none
    }

    /// Applies the exact mode-0/mode-1 ordering from `0x51CEC0`.
    ///
    /// The existing provider word is changed to `0` only when appeal is below
    /// the threshold and the provider predicate is true. It is changed to `1`
    /// only when appeal is at or above the threshold and the predicate is
    /// false. Otherwise the original word is preserved.
    public static func nextFlag(
        currentFlag: Int,
        appealValue: Int,
        threshold: Int,
        providerPredicate: Bool
    ) -> Int {
        if appealValue < threshold, providerPredicate {
            return 0
        }
        if appealValue >= threshold, !providerPredicate {
            return 1
        }
        return currentFlag
    }
}

/// One daily pass of the source HouseBldg service countdown at
/// `FUN_005185C0 @ 0x5185C0`.
///
/// The executable does not clear `cHouseInfo+0x3C` merely because a house is
/// currently eligible.  It first requires the global gate, the object's
/// `+0xB8` eligibility callback, a non-zero `cHouseInfo+0x3C`, and a positive
/// object countdown at `+0x98` (`p[0x26]`).  A zero resident word clears both
/// the flag and countdown without incrementing the global counter.  A
/// non-zero resident word decrements the countdown, increments
/// `DAT_0131289C`, and clears the flag only when the countdown reaches zero.
/// This keeps the raw transition explicit while leaving the callback and
/// object-registry projection outside Native gameplay.
public enum OriginalHouseInfoServiceCountdown {
    public struct Outcome: Sendable, Hashable, Codable {
        public let nextCountdown: Int
        public let nextFlag3C: Bool
        public let globalCounterDelta: Int
        public let didAdvance: Bool
        public let didClearFlag: Bool

        public init(
            nextCountdown: Int,
            nextFlag3C: Bool,
            globalCounterDelta: Int,
            didAdvance: Bool,
            didClearFlag: Bool
        ) {
            self.nextCountdown = nextCountdown
            self.nextFlag3C = nextFlag3C
            self.globalCounterDelta = globalCounterDelta
            self.didAdvance = didAdvance
            self.didClearFlag = didClearFlag
        }
    }

    /// Replays one object iteration; callers supply already-resolved raw
    /// callback/registry inputs and apply the returned fields themselves.
    public static func advance(
        globalGateOpen: Bool,
        objectEligible: Bool,
        flag3CSet: Bool,
        residentWord: Int16,
        countdown: Int
    ) -> Outcome {
        guard globalGateOpen,
              objectEligible,
              flag3CSet,
              countdown > 0 else {
            return .init(
                nextCountdown: countdown,
                nextFlag3C: flag3CSet,
                globalCounterDelta: 0,
                didAdvance: false,
                didClearFlag: false
            )
        }

        guard residentWord != 0 else {
            return .init(
                nextCountdown: 0,
                nextFlag3C: false,
                globalCounterDelta: 0,
                didAdvance: false,
                didClearFlag: true
            )
        }

        let nextCountdown = countdown - 1
        let didClearFlag = nextCountdown == 0
        return .init(
            nextCountdown: nextCountdown,
            nextFlag3C: didClearFlag ? false : flag3CSet,
            globalCounterDelta: 1,
            didAdvance: true,
            didClearFlag: didClearFlag
        )
    }
}

/// Byte-level state advanced by the original inhabited-house service pass.
///
/// `FUN_00517280 @ 0x517280` is called from scheduler phase `0x23`
/// (`FUN_00517B40 @ 0x517B40`). It decrements the packed `cHouseInfo`
/// service bytes independently; in particular, water bytes `+0x32` and
/// `+0x34` are not one shared timer. The four bytes at `+0x0D…+0x10` use the
/// same non-zero decrement but are kept as a fixed-width array because their
/// semantic labels are not recovered. This value type is research-only: the
/// provider registry/object projection that would supply these bytes is still
/// unknown, so Native gameplay does not instantiate or advance it.
public struct OriginalHouseInfoCountdownState: Sendable, Hashable, Codable {
    public private(set) var field2A: UInt8
    public private(set) var field2B: UInt8
    public private(set) var field2C: UInt8
    public private(set) var field2D: UInt8
    public private(set) var field2E: UInt8
    public private(set) var field32: UInt8
    public private(set) var field33: UInt8
    public private(set) var field34: UInt8
    public private(set) var fields0DThrough10: [UInt8]

    public init(
        field2A: Int = 0,
        field2B: Int = 0,
        field2C: Int = 0,
        field2D: Int = 0,
        field2E: Int = 0,
        field32: Int = 0,
        field33: Int = 0,
        field34: Int = 0,
        fields0DThrough10: [Int] = Array(repeating: 0, count: 4)
    ) {
        self.field2A = UInt8(truncatingIfNeeded: field2A)
        self.field2B = UInt8(truncatingIfNeeded: field2B)
        self.field2C = UInt8(truncatingIfNeeded: field2C)
        self.field2D = UInt8(truncatingIfNeeded: field2D)
        self.field2E = UInt8(truncatingIfNeeded: field2E)
        self.field32 = UInt8(truncatingIfNeeded: field32)
        self.field33 = UInt8(truncatingIfNeeded: field33)
        self.field34 = UInt8(truncatingIfNeeded: field34)
        self.fields0DThrough10 = fields0DThrough10.prefix(4).map {
            UInt8(truncatingIfNeeded: $0)
        }
        if self.fields0DThrough10.count < 4 {
            self.fields0DThrough10.append(
                contentsOf: repeatElement(0, count: 4 - self.fields0DThrough10.count)
            )
        }
    }

    /// Advances one phase-`0x23` service-decay pass. The first eight fields
    /// use the exact `< 2 → 0, otherwise −1` byte operation from
    /// `0x517280`; the four unnamed bytes use `!= 0 → −1`.
    public mutating func advanceOriginalServiceDecaySlice() {
        field2A = Self.decayWithTwoFloor(field2A)
        field2B = Self.decayWithTwoFloor(field2B)
        field2C = Self.decayWithTwoFloor(field2C)
        field2D = Self.decayWithTwoFloor(field2D)
        field2E = Self.decayWithTwoFloor(field2E)
        field32 = Self.decayWithTwoFloor(field32)
        field34 = Self.decayWithTwoFloor(field34)
        field33 = Self.decayWithTwoFloor(field33)
        for index in fields0DThrough10.indices where fields0DThrough10[index] != 0 {
            fields0DThrough10[index] &-= 1
        }
    }

    private static func decayWithTwoFloor(_ value: UInt8) -> UInt8 {
        value < 2 ? 0 : value - 1
    }
}

public struct ResidentialServiceBuilding: Identifiable, Sendable, Hashable, Codable {
    public let id: Int
    public let buildingID: Int
    public let service: WalkerServiceKind
    public let figureID: Int
    public let roadAccessPoint: GridPoint
    public let walkerID: Int
}

public enum HouseEvolutionRequirement: Sendable, Hashable, Codable {
    case desirability(current: Int, required: Int)
    case service(WalkerServiceKind)
    case foodQuality(current: Int, required: Int)
    case commodityAlternatives([Int])

    /// Exact upgrade-reason ordinal written by `FUN_0051A660 @ 0x51A660`
    /// during the target-model pass. The inspector later renders
    /// `EmperorText` group 127 at `reasonCode + 0x27` (`0x51AF60`). This is
    /// metadata for preserving original blocker priority; it does not claim
    /// that Native has recovered the provider/coverage writers that produce
    /// the underlying house-info bytes.
    public var originalUpgradeReasonCode: Int? {
        switch self {
        case .desirability:
            // Code 17 is the separate "nearby buildings reduced appeal"
            // classifier, which Native cannot attribute. Code 18 is the
            // generic low-appeal blocker represented by this requirement.
            return 18
        case .foodQuality:
            return 20
        case let .service(service):
            switch service {
            case .water: return 19
            case .music: return 21
            case .acrobat: return 22
            case .drama: return 23
            case .acupuncture: return 24
            case .herbalist: return 25
            case .ancestor: return 26
            case .confucian: return 27
            case .daoistOrBuddhist: return 28
            case .inspection, .constable, .tax: return nil
            }
        case let .commodityAlternatives(ids):
            switch Set(ids) {
            case [25]: return 29       // ceramics
            case [19]: return 30       // hemp
            case [13]: return 31       // tea
            case [22, 23]: return 32   // bronzeware or lacquerware
            case [24]: return 33       // silk
            default: return nil
            }
        }
    }

    /// Original `EmperorText` group 127 upgrade-reason row used for the
    /// requirement, zero-based. Group 127 keeps the same row ordering and row
    /// count (75) in `EmperorText.eng` and `EmperorText.txt`, so the Chinese row
    /// can be fetched by index from the aligned table. Service and commodity
    /// rows remain semantic mappings pending recovery of their reason writers.
    ///
    /// Desirability maps to row 57 (the generic low-appeal line); row 56 names
    /// negative nearby buildings as the trigger, which the current native state
    /// cannot attribute, so it is intentionally never selected. Unsupported
    /// service/commodity requirement shapes return `nil` and must not be
    /// rendered with invented prose.
    public var emperorTextGroup127UpgradeReasonRowIndex: Int? {
        guard let reasonCode = originalUpgradeReasonCode else { return nil }
        return reasonCode + 0x27
    }
}

public enum HouseEvolutionDirection: String, Sendable, Hashable, Codable {
    case evolved
    case devolved
}

public struct HouseEvolutionChange: Identifiable, Sendable, Hashable, Codable {
    public let houseID: Int
    public let fromLevelID: Int
    public let toLevelID: Int
    public let direction: HouseEvolutionDirection
    public let displacedResidents: Int

    public var id: Int { houseID }
}

public struct HouseEvolutionEvaluation: Identifiable, Sendable, Hashable, Codable {
    public let houseID: Int
    public let levelID: Int
    public let desirability: Int
    public let nextLevelID: Int?
    public let missingEvolutionRequirements: [HouseEvolutionRequirement]

    public var id: Int { houseID }
    public var canEvolve: Bool {
        nextLevelID != nil && missingEvolutionRequirements.isEmpty
    }
}

public struct HousingMonthlySettlement: Sendable, Hashable, Codable {
    public let changes: [HouseEvolutionChange]
    public let evaluations: [HouseEvolutionEvaluation]

    public var evolvedCount: Int { changes.count { $0.direction == .evolved } }
    public var devolvedCount: Int { changes.count { $0.direction == .devolved } }
    public var displacedResidents: Int { changes.reduce(0) { $0 + $1.displacedResidents } }
}

public enum DeterministicHousingEvolution {
    public static let marketCommodityIDs: Set<Int> = [13, 19, 22, 23, 24, 25]

    public static func nextLevel(after levelID: Int) -> Int? {
        switch levelID {
        case 0..<7: levelID + 1
        case 8..<14: levelID + 1
        default: nil
        }
    }

    public static func previousLevel(before levelID: Int) -> Int? {
        switch levelID {
        case 1...7: levelID - 1
        case 9...14: levelID - 1
        default: nil
        }
    }

    /// Evaluates the exact live requirements used by the next monthly
    /// settlement. The native UI uses this to explain upgrade blockers on
    /// hover without waiting for a month-end snapshot.
    public static func evaluate(
        house: ResidentialUnit,
        models: BuildingModelTable,
        difficulty: GameDifficulty
    ) -> HouseEvolutionEvaluation? {
        guard house.location != nil,
              let current = models[houseLevelID: house.houseLevelID],
              house.residents > 0
                || (house.houseLevelID == 8 && current.populationCapacity == 0) else {
            return nil
        }
        let next = nextLevel(after: house.houseLevelID)
        // The original evolves a house when it satisfies the **target**
        // level's authored requirements (food quality, services, goods), not
        // the current level's. Checking the current level would let a Hut
        // (food 0) evolve into a Plain Cottage (food 20) without food.
        var evolutionMissing: [HouseEvolutionRequirement] = []
        if let next, let nextModel = models[houseLevelID: next] {
            evolutionMissing = requirementsMissing(model: nextModel, house: house)
        }
        let evolveThreshold = threshold(
            current.evolveDesirability,
            fieldIndex: 1,
            models: models,
            difficulty: difficulty
        )
        if next != nil, house.desirability < evolveThreshold {
            evolutionMissing.insert(
                .desirability(current: house.desirability, required: evolveThreshold),
                at: 0
            )
        }
        return HouseEvolutionEvaluation(
            houseID: house.id,
            levelID: house.houseLevelID,
            desirability: house.desirability,
            nextLevelID: next,
            missingEvolutionRequirements: next == nil ? [] : evolutionMissing
        )
    }

    public static func settle(
        houses: inout [ResidentialUnit],
        models: BuildingModelTable,
        difficulty: GameDifficulty
    ) -> HousingMonthlySettlement {
        var changes: [HouseEvolutionChange] = []
        var evaluations: [HouseEvolutionEvaluation] = []

        for index in houses.indices.sorted(by: { houses[$0].id < houses[$1].id }) {
            guard let evaluation = evaluate(
                house: houses[index],
                models: models,
                difficulty: difficulty
            ), let current = models[houseLevelID: houses[index].houseLevelID] else { continue }
            let currentLevel = houses[index].houseLevelID
            let next = evaluation.nextLevelID
            let evolutionMissing = evaluation.missingEvolutionRequirements
            evaluations.append(evaluation)

            if let previousLevel = previousLevel(before: currentLevel),
               let previous = models[houseLevelID: previousLevel] {
                let devolveThreshold = threshold(
                    current.devolveDesirability,
                    fieldIndex: 0,
                    models: models,
                    difficulty: difficulty
                )
                let lostMaintenance = !requirementsMissing(
                    model: previous,
                    house: houses[index]
                ).isEmpty
                if houses[index].desirability < devolveThreshold || lostMaintenance {
                    let oldResidents = houses[index].residents
                    houses[index].houseLevelID = previousLevel
                    let capacity = houses[index].capacity(using: models)
                    houses[index].residents = min(oldResidents, capacity)
                    if oldResidents > houses[index].residents {
                        // Original `FUN_00468420` eviction path sets the
                        // `cHouseInfo+0x3C` settling lock with a 32-step
                        // countdown after residents are removed (§10.6).
                        houses[index].startSettlingLock()
                    }
                    changes.append(HouseEvolutionChange(
                        houseID: houses[index].id,
                        fromLevelID: currentLevel,
                        toLevelID: previousLevel,
                        direction: .devolved,
                        displacedResidents: oldResidents - houses[index].residents
                    ))
                    continue
                }
            }

            if let next, evolutionMissing.isEmpty {
                houses[index].houseLevelID = next
                changes.append(HouseEvolutionChange(
                    houseID: houses[index].id,
                    fromLevelID: currentLevel,
                    toLevelID: next,
                    direction: .evolved,
                    displacedResidents: 0
                ))
            }
        }

        return HousingMonthlySettlement(changes: changes, evaluations: evaluations)
    }

    public static func requirementsMissing(
        model: HouseModel,
        house: ResidentialUnit
    ) -> [HouseEvolutionRequirement] {
        var missing: [HouseEvolutionRequirement] = []
        let services: [(Int, WalkerServiceKind)] = [
            (model.waterRequired, .water),
            (model.herbalistRequired, .herbalist),
            (model.acupunctureRequired, .acupuncture),
            (model.musicRequired, .music),
            (model.acrobatRequired, .acrobat),
            (model.dramaRequired, .drama),
            (model.ancestorAccessRequired, .ancestor),
            (model.confucianAccessRequired, .confucian),
            (model.daoistOrBuddhistAccessRequired, .daoistOrBuddhist),
        ]
        for (required, service) in services where
            required > 0 && !house.serviceCoverage.contains(service) {
            missing.append(.service(service))
        }

        if model.foodQualityRequired > 0,
           house.lastSuppliedFoodQualityRawValue < model.foodQualityRequired {
            missing.append(.foodQuality(
                current: house.lastSuppliedFoodQualityRawValue,
                required: model.foodQualityRequired
            ))
        }
        for alternatives in commodityAlternatives(for: model) where
            house.lastSuppliedCommodityIDs.isDisjoint(with: alternatives) {
            missing.append(.commodityAlternatives(alternatives.sorted()))
        }

        // `FUN_0051A660` checks the target model in this exact order and
        // stores the first failing ordinal in cHouseInfo +0x3A. Keep the
        // Native list in that order so every visible blocker follows the
        // original inspector priority instead of the parser's field order.
        return missing.enumerated().sorted { lhs, rhs in
            switch (lhs.element.originalUpgradeReasonCode, rhs.element.originalUpgradeReasonCode) {
            case let (left?, right?):
                return left == right ? lhs.offset < rhs.offset : left < right
            case (_?, nil):
                return true
            case (nil, _?):
                return false
            case (nil, nil):
                return lhs.offset < rhs.offset
            }
        }.map(\.element)
    }

    public static func commodityAlternatives(for model: HouseModel) -> [Set<Int>] {
        var result: [Set<Int>] = []
        if model.hempRequired > 0 { result.append([19]) }
        if model.ceramicsRequired > 0 { result.append([25]) }
        if model.teaRequired > 0 { result.append([13]) }
        if model.silkRequired > 0 { result.append([24]) }
        if model.luxuryWareRequired > 0 { result.append([23, 22]) }
        return result
    }

    private static func threshold(
        _ base: Int,
        fieldIndex: Int,
        models: BuildingModelTable,
        difficulty: GameDifficulty
    ) -> Int {
        guard models.houseDifficultyModifiers.indices.contains(difficulty.rawValue),
              models.houseDifficultyModifiers[difficulty.rawValue].values.indices.contains(fieldIndex) else {
            return base
        }
        return base + models.houseDifficultyModifiers[difficulty.rawValue].values[fieldIndex]
    }
}

public enum DeterministicDesirability {
    public static func contribution(
        from model: BuildingModel,
        source: GridPoint,
        to target: GridPoint
    ) -> Int {
        guard model.initialDesirability != 0 else { return 0 }
        let distance = abs(source.x - target.x) + abs(source.y - target.y)
        guard distance <= model.maximumDesirabilityRange else { return 0 }
        let steps = model.desirabilityStep > 0 ? distance / model.desirabilityStep : 0
        return model.initialDesirability + steps * model.desirabilityStepSize
    }
}

/// Raw per-building appeal contribution used by the original monthly
/// population pass `FUN_005180E0 @ 0x5180E0`.
public struct OriginalAppealPopulationContribution: Sendable, Hashable, Codable {
    public let appealScore: Int
    public let rawFixedPoint: Int
    public let roundedPopulationUnits: Int

    public init(
        appealScore: Int,
        rawFixedPoint: Int,
        roundedPopulationUnits: Int
    ) {
        self.appealScore = appealScore
        self.rawFixedPoint = rawFixedPoint
        self.roundedPopulationUnits = roundedPopulationUnits
    }
}

/// Side-effect-free arithmetic from the original appeal-buffer consumer.
/// `FUN_005180E0` subtracts the authored model column `0` from the signed
/// appeal byte returned by the object's `+0x1F8` slot, maps that delta through
/// five strict intervals, doubles every branch at or below `50`, and adds `20` when
/// the original selector-9 blessing predicate is true. It then multiplies by
/// the signed resident word, model column `0x12`, and `10`; only positive
/// results are rounded with `(raw + 5000) / 10000`. The model columns and
/// anchor/occupancy inputs are explicit because their Native projection is not
/// recovered.
public enum OriginalAppealPopulationAccumulator {
    /// `FUN_00590A70` initializes `DAT_0130F96C` to 9 during both the normal
    /// model initialization (`FUN_005D1400`) and city-start setup
    /// (`FUN_0042E6A0`). This is a recovered input constant, not a signal that
    /// the unresolved appeal ledger is safe to wire into Qin simulation.
    public static let defaultAppealScale = 9

    public static func contribution(
        appealValue: Int8,
        modelColumn0: Int,
        appealScale: Int,
        residentCount: Int16,
        modelColumn18: Int,
        hasSelectorNineBlessing: Bool
    ) -> OriginalAppealPopulationContribution? {
        let delta = Int(appealValue) - modelColumn0
        if appealScale == 0 {
            return makeContribution(
                appealScore: 0,
                residentCount: residentCount,
                modelColumn18: modelColumn18,
                hasSelectorNineBlessing: hasSelectorNineBlessing
            )
        }

        let score: Int
        if delta < 0x33 {
            if delta < 0x29 {
                if delta > 0x1E {
                    score = appealScale * 10 + 0x0F
                } else if delta < 0x15 {
                    score = delta > 10 ? appealScale * 10 + 5 : appealScale * 5
                } else {
                    score = appealScale * 5 + 5
                }
            } else {
                score = appealScale * 5 + 10
            }
            let (doubled, overflow) = score.multipliedReportingOverflow(by: 2)
            guard !overflow else { return nil }
            return makeContribution(
                appealScore: doubled,
                residentCount: residentCount,
                modelColumn18: modelColumn18,
                hasSelectorNineBlessing: hasSelectorNineBlessing
            )
        }

        return makeContribution(
            appealScore: appealScale * 10 + 0x19,
            residentCount: residentCount,
            modelColumn18: modelColumn18,
            hasSelectorNineBlessing: hasSelectorNineBlessing
        )
    }

    private static func makeContribution(
        appealScore: Int,
        residentCount: Int16,
        modelColumn18: Int,
        hasSelectorNineBlessing: Bool
    ) -> OriginalAppealPopulationContribution? {
        var score = appealScore
        if score > 0, hasSelectorNineBlessing {
            let (blessed, overflow) = score.addingReportingOverflow(0x14)
            guard !overflow else { return nil }
            score = blessed
        }
        let (residentTerm, residentOverflow) =
            score.multipliedReportingOverflow(by: Int(residentCount))
        guard !residentOverflow else { return nil }
        let (weighted, weightOverflow) =
            residentTerm.multipliedReportingOverflow(by: modelColumn18)
        guard !weightOverflow else { return nil }
        let (raw, rawOverflow) = weighted.multipliedReportingOverflow(by: 10)
        guard !rawOverflow else { return nil }
        let rounded: Int
        if raw > 0 {
            let (biased, biasOverflow) = raw.addingReportingOverflow(5_000)
            guard !biasOverflow else { return nil }
            rounded = biased / 10_000
        } else {
            rounded = 0
        }
        return .init(
            appealScore: score,
            rawFixedPoint: raw,
            roundedPopulationUnits: rounded
        )
    }
}

/// The `HouseBldg` vtable `+0x204` class split used by
/// `FUN_005180E0`. Its direct PE target `FUN_00518D90` returns true exactly
/// when the signed house word at `house+0x14` is at least `11`. This is a
/// classification primitive only; it does not project the unresolved appeal
/// ledger or migration totals into Native state.
public enum OriginalHouseAppealPopulationClass {
    public static func isUpperClass(houseField14: Int16) -> Bool {
        houseField14 >= 11
    }
}

/// Raw output of the original `FUN_00517BC0` tax-weighted appeal ledger.
/// The source accumulates covered-house residents weighted by authored house
/// column `0x12`, scales each class bucket by the appeal scale, then applies
/// the month-index multiplier to the combined value. This is a research
/// projection only; the executable's ledger is not connected to Native tax
/// settlement.
public struct OriginalAppealTaxLedgerProjection: Sendable, Hashable, Codable {
    public let lowerScaledUnits: Int
    public let upperScaledUnits: Int
    public let appealTaxDelta: Int
    public let displayBase: Int

    public init(
        lowerScaledUnits: Int,
        upperScaledUnits: Int,
        appealTaxDelta: Int,
        displayBase: Int
    ) {
        self.lowerScaledUnits = lowerScaledUnits
        self.upperScaledUnits = upperScaledUnits
        self.appealTaxDelta = appealTaxDelta
        self.displayBase = displayBase
    }
}

/// Fixed-point change written into the per-house appeal/tax accumulator by
/// `FUN_005180E0 @ 0x5180E0` for a tax-covered house. The executable keeps the
/// prior value at `cHouseInfo + 0x40`, adds the `__ftol` result of the current
/// contribution, rounds both endpoints with `(value + 5000) / 10000`, and
/// accumulates their integer difference into `DAT_01312240` or `DAT_01312244`.
/// The source does not expose the producer of the fixed-point increment here,
/// so both values are explicit inputs and this helper is not wired into the
/// live simulation.
public struct OriginalAppealTaxDeltaProjection: Sendable, Hashable, Codable {
    public let previousFixedPoint: Int
    public let updatedFixedPoint: Int
    public let previousRoundedUnits: Int
    public let updatedRoundedUnits: Int
    public let deltaUnits: Int

    public init(
        previousFixedPoint: Int,
        updatedFixedPoint: Int,
        previousRoundedUnits: Int,
        updatedRoundedUnits: Int,
        deltaUnits: Int
    ) {
        self.previousFixedPoint = previousFixedPoint
        self.updatedFixedPoint = updatedFixedPoint
        self.previousRoundedUnits = previousRoundedUnits
        self.updatedRoundedUnits = updatedRoundedUnits
        self.deltaUnits = deltaUnits
    }
}

public enum OriginalAppealTaxLedger {
    /// Mirrors the reader `FUN_004AFFB0 @ 0x4AFFB0`, which returns the
    /// rounded integer represented by `cHouseInfo + 0x40` using the same
    /// `(value + 5000) / 10000` expression as the monthly updater.
    public static func roundedFixedPointUnits(_ fixedPoint: Int) -> Int? {
        let (biased, overflow) = fixedPoint.addingReportingOverflow(5_000)
        guard !overflow else { return nil }
        return biased / 10_000
    }

    /// Mirrors the per-house `+0x40` update inside `FUN_005180E0`.
    /// `incrementFixedPoint` is the already-converted `__ftol` contribution;
    /// the producer and its object/appeal projection remain unresolved.
    public static func projectTaxDelta(
        previousFixedPoint: Int,
        incrementFixedPoint: Int
    ) -> OriginalAppealTaxDeltaProjection? {
        let (updatedFixedPoint, updateOverflow) =
            previousFixedPoint.addingReportingOverflow(incrementFixedPoint)
        guard !updateOverflow else { return nil }
        guard let previousRoundedUnits = roundedFixedPointUnits(previousFixedPoint),
              let updatedRoundedUnits = roundedFixedPointUnits(updatedFixedPoint) else {
            return nil
        }
        let (deltaUnits, deltaOverflow) =
            updatedRoundedUnits.subtractingReportingOverflow(previousRoundedUnits)
        guard !deltaOverflow else { return nil }
        return .init(
            previousFixedPoint: previousFixedPoint,
            updatedFixedPoint: updatedFixedPoint,
            previousRoundedUnits: previousRoundedUnits,
            updatedRoundedUnits: updatedRoundedUnits,
            deltaUnits: deltaUnits
        )
    }

    /// Mirrors `FUN_00517BC0`: `monthIndex == 0` uses multiplier `1`, while
    /// later scheduler months use `13 - monthIndex`. The percentage helper
    /// is the original integer `(weighted * appealScale) / 100` operation.
    public static func project(
        lowerWeightedUnits: Int,
        upperWeightedUnits: Int,
        lowerTaxDelta: Int,
        upperTaxDelta: Int,
        appealScale: Int,
        monthIndex: Int
    ) -> OriginalAppealTaxLedgerProjection? {
        let (lowerProduct, lowerOverflow) =
            lowerWeightedUnits.multipliedReportingOverflow(by: appealScale)
        let (upperProduct, upperOverflow) =
            upperWeightedUnits.multipliedReportingOverflow(by: appealScale)
        guard !lowerOverflow, !upperOverflow else { return nil }
        let lowerScaled = lowerProduct / 100
        let upperScaled = upperProduct / 100
        let monthMultiplier = monthIndex == 0 ? 1 : 13 - monthIndex
        let (scaledSum, sumOverflow) =
            lowerScaled.addingReportingOverflow(upperScaled)
        guard !sumOverflow else { return nil }
        let (scaledTotal, scaledOverflow) =
            scaledSum.multipliedReportingOverflow(by: monthMultiplier)
        let (deltaTotal, deltaOverflow) =
            lowerTaxDelta.addingReportingOverflow(upperTaxDelta)
        guard !scaledOverflow, !deltaOverflow else { return nil }
        let (displayBase, totalOverflow) =
            scaledTotal.addingReportingOverflow(deltaTotal)
        guard !totalOverflow else { return nil }
        return .init(
            lowerScaledUnits: lowerScaled,
            upperScaledUnits: upperScaled,
            appealTaxDelta: deltaTotal,
            displayBase: displayBase
        )
    }
}

/// Geometry recovered from the original appeal producer's ring tables.
///
/// This catalog is intentionally not consumed by the simulation yet. The
/// executable's transient occupancy/sector state and the final house-anchor
/// copy are still unresolved; callers must not treat these offsets as a
/// complete desirability implementation.
public enum OriginalAppealPropagationCatalog {
    public static let maximumRange = 10

    /// The common single-cell appeal getter installed at vtable `+0x1F8`
    /// for the Qin building/provider classes checked in the canonical EN/CH
    /// images.  The body at `0x4273D0` reads the object's canonical linear
    /// map index (`+0x10`), performs the intermediate call at `0x53C870`,
    /// and returns `DAT_00F11C70[index]` through `0x44F180`. The intermediate
    /// return value is not itself the appeal buffer; the pushed index remains
    /// the argument consumed by `0x44F180`.
    /// This is evidence metadata only: Native does not currently expose the
    /// executable object layout or wire this getter into live simulation.
    public struct CommonSingleCellReaderDescriptor: Sendable, Hashable, Codable {
        public let functionAddress: UInt32
        public let objectMapIndexOffset: UInt32
        public let appealBufferAddress: UInt32
        public let intermediateCallAddress: UInt32
        public let bufferReadHelperAddress: UInt32
        public let mapStride: Int
        public let qinVTableAddresses: [UInt32]

        public init(
            functionAddress: UInt32,
            objectMapIndexOffset: UInt32,
            appealBufferAddress: UInt32,
            intermediateCallAddress: UInt32,
            bufferReadHelperAddress: UInt32,
            mapStride: Int,
            qinVTableAddresses: [UInt32]
        ) {
            self.functionAddress = functionAddress
            self.objectMapIndexOffset = objectMapIndexOffset
            self.appealBufferAddress = appealBufferAddress
            self.intermediateCallAddress = intermediateCallAddress
            self.bufferReadHelperAddress = bufferReadHelperAddress
            self.mapStride = mapStride
            self.qinVTableAddresses = qinVTableAddresses
        }
    }

    public static let commonSingleCellReaderDescriptor = CommonSingleCellReaderDescriptor(
        functionAddress: 0x004273D0,
        objectMapIndexOffset: 0x10,
        appealBufferAddress: 0x00F11C70,
        intermediateCallAddress: 0x0053C870,
        bufferReadHelperAddress: 0x0044F180,
        mapStride: 0xE4,
        qinVTableAddresses: [
            0x007AB59C, // base Building/House
            0x007ABA38, // HouseBldg
            0x007AD878, // Entertainment Area
            0x007B5EB4, // Well
            0x007B6114, // Herbalist's Stall
            0x007B6374, // Acupuncturist's Clinic
        ]
    )

    /// Copies one object's computed appeal byte from the shared buffer using
    /// the exact read order of `FUN_004ACD10 @ 0x4ACD10`.
    ///
    /// For a one-cell object the caller supplies the already-resolved anchor
    /// returned by the object's vtable `+0x1F8`. For a multi-cell object the
    /// same value is the top-left origin and the helper takes the signed-byte
    /// maximum over the row-major first-dword offsets of the `0xE4`-stride
    /// footprint table. A non-zero object `+0x60` flag adds ten after the
    /// copy. The map/object anchor and that flag's producer are deliberately
    /// explicit: this remains a research primitive and is not live Native
    /// desirability wiring.
    public static func copyObjectAppeal(
        appealBuffer: [Int8],
        anchorLinearIndex: Int,
        footprintSide: Int,
        objectOffset60NonZero: Bool,
        mapStride: Int = 0xE4
    ) -> Int8? {
        guard mapStride > 0,
              (1...6).contains(footprintSide),
              anchorLinearIndex >= 0 else { return nil }

        var value: Int8
        if footprintSide == 1 {
            guard appealBuffer.indices.contains(anchorLinearIndex) else { return nil }
            value = appealBuffer[anchorLinearIndex]
        } else {
            var maximum: Int8?
            for y in 0..<footprintSide {
                for x in 0..<footprintSide {
                    let offset = y * mapStride + x
                    let index = anchorLinearIndex + offset
                    guard appealBuffer.indices.contains(index) else { return nil }
                    let candidate = appealBuffer[index]
                    if maximum.map({ candidate > $0 }) ?? true {
                        maximum = candidate
                    }
                }
            }
            guard let maximum else { return nil }
            value = maximum
        }

        return objectOffset60NonZero ? value &+ 10 : value
    }

    /// Reproduces the creation-time `+0x60` adjustment flag produced by
    /// `FUN_004BAEE0 @ 0x4BAEE0`.
    ///
    /// The executable scans the ordered perimeter row for the object's side
    /// in `DAT_00820038` and tests bit `0x04` in the canonical terrain layer
    /// (`DAT_00F6A9E0`) at each candidate cell. The map array is supplied as
    /// a full canonical backing grid so callers cannot accidentally interpret
    /// an active-map slice with the wrong `0xE4` stride. Coordinates and the
    /// map-base projection remain explicit research inputs.
    public static func objectOffset60Flag(
        terrainFlags: [UInt32],
        origin: GridPoint,
        footprintSide: Int,
        mapStride: Int = 0xE4
    ) -> Bool? {
        guard mapStride > 0,
              (1...6).contains(footprintSide),
              terrainFlags.count >= mapStride * mapStride else { return nil }

        for offset in OriginalMultipartMonumentRoutingCatalog.roadAccessOffsets(
            footprintSide: footprintSide
        ) {
            let point = GridPoint(
                x: origin.x + offset.x,
                y: origin.y + offset.y
            )
            guard point.x >= 0, point.x < mapStride,
                  point.y >= 0, point.y < mapStride else { return nil }
            let index = point.y * mapStride + point.x
            guard terrainFlags.indices.contains(index) else { return nil }
            if terrainFlags[index] & 0x04 != 0 {
                return true
            }
        }
        return false
    }

    public struct NegativePropagationState: Sendable, Hashable {
        public let sectorActive: [Bool]
        public let blockingRadius: [Int]

        public init(sectorActive: [Bool], blockingRadius: [Int]) {
            precondition(sectorActive.count == 16)
            precondition(blockingRadius.count == 16)
            self.sectorActive = sectorActive
            self.blockingRadius = blockingRadius
        }

        public static let empty = NegativePropagationState(
            sectorActive: Array(repeating: false, count: 16),
            blockingRadius: Array(repeating: 0, count: 16)
        )
    }

    public struct NegativePropagationResult: Sendable, Hashable {
        public let shouldWrite: Bool
        public let state: NegativePropagationState

        public init(shouldWrite: Bool, state: NegativePropagationState) {
            self.shouldWrite = shouldWrite
            self.state = state
        }
    }

    /// Returns the value written for one propagation ring by
    /// `FUN_0044ECD0 @ 0x44ECD0`, before the occupancy-sector arbitration in
    /// `FUN_0044ED90`.  The executable emits the current value first, then
    /// advances it after `stepDistance` rings.  If a signed progression would
    /// cross zero, the original bit-mask branch snaps it to zero; every cell
    /// write is finally clamped to the byte range `[-100, 100]`.
    ///
    /// This is a side-effect-free research primitive. It does not identify
    /// the map anchor or occupancy state and therefore is not consumed by the
    /// live Native simulation path.
    public static func propagatedValue(
        initialValue: Int,
        stepDistance: Int,
        stepSize: Int,
        radius: Int
    ) -> Int? {
        guard initialValue != 0,
              (1...maximumRange).contains(radius) else { return nil }

        var value = initialValue
        var ringsSinceStep = 0
        let startsNegative = initialValue < 1
        for currentRadius in 1...radius {
            if currentRadius == radius {
                return min(100, max(-100, value))
            }
            ringsSinceStep += 1
            guard stepDistance <= ringsSinceStep else { continue }

            value += stepSize
            // `flag2 - 1 & value` in the PE preserves the value while it
            // remains on the original side of zero and yields zero once it
            // crosses the sign boundary.
            let remainsOnOriginalSide = startsNegative ? value < 0 : value >= 1
            if !remainsOnOriginalSide {
                value = 0
            }
            ringsSinceStep = 0
        }
        return nil
    }

    /// Reproduces the negative-value occupancy arbitration in
    /// `FUN_0044ED90 @ 0x44ED90` without touching a map or simulation state.
    ///
    /// An unoccupied cell writes only when its angular sector is unset or the
    /// current radius is no later than the sector's nearest blocking radius.
    /// An occupied cell is never written: it records the nearer blocking
    /// radius and, for short rings, can seed the adjacent even/odd sectors
    /// when their blocking radius is exactly one. `sector == nil` is the
    /// executable's `FUN_0044E770 == -1` path. This helper intentionally does
    /// not decide whether a map cell is occupied; that predicate is still the
    /// unresolved class-dependent `vtable +0x268` callback.
    public static func negativePropagationStep(
        occupied: Bool,
        sector: Int?,
        radius: Int,
        ringCellCount: Int,
        state: NegativePropagationState = .empty
    ) -> NegativePropagationResult {
        guard let sector, (0..<16).contains(sector) else {
            return NegativePropagationResult(
                shouldWrite: !occupied,
                state: state
            )
        }

        var active = state.sectorActive
        var nearest = state.blockingRadius

        guard occupied else {
            let shouldWrite = !active[sector] || radius <= nearest[sector]
            return NegativePropagationResult(
                shouldWrite: shouldWrite,
                state: state
            )
        }

        if !active[sector] || radius < nearest[sector] {
            active[sector] = true
            nearest[sector] = radius

            if ringCellCount < 16, sector.isMultiple(of: 2) {
                let clockwise = (sector + 2) & 15
                let counterClockwise = (sector + 14) & 15
                if active[clockwise], nearest[clockwise] == 1 {
                    let adjacent = (sector + 1) & 15
                    active[adjacent] = true
                    nearest[adjacent] = radius
                }
                if active[counterClockwise], nearest[counterClockwise] == 1 {
                    let adjacent = (sector + 15) & 15
                    active[adjacent] = true
                    nearest[adjacent] = radius
                }
            }
        }

        return NegativePropagationResult(
            shouldWrite: false,
            state: NegativePropagationState(
                sectorActive: active,
                blockingRadius: nearest
            )
        )
    }

    /// Returns the original perimeter ordering for one propagation ring.
    /// `footprintSide == 1` is the `FUN_004B0710`/`FUN_004BB810` path; sides
    /// 2…6 follow the `FUN_0044CDE0` shape objects. Offsets are relative to
    /// the object's top-left map origin and are returned in the same order as
    /// the executable's generated arrays.
    public static func squareRingOffsets(
        footprintSide: Int,
        radius: Int
    ) -> [GridPoint]? {
        guard (1...6).contains(footprintSide),
              (1...maximumRange).contains(radius) else { return nil }

        if footprintSide == 1 {
            let minimum = -radius
            let maximum = radius
            return (minimum...maximum).flatMap { y in
                (minimum...maximum).compactMap { x in
                    guard x == minimum || x == maximum || y == minimum || y == maximum else {
                        return nil
                    }
                    return GridPoint(x: x, y: y)
                }
            }
        }

        // This is a literal translation of the five loops in
        // `FUN_0044CDE0 @ 0x44CDE0`.  The generated rings are intentionally
        // not symmetric around the footprint: `n2` starts at -1 and the
        // final loop closes only the remaining top-left segment.  Replacing
        // this with an enclosing rectangle changes both point order and the
        // occupied-cell probes performed by the appeal producer.
        var n2 = -1
        var side = footprintSide
        var result: [GridPoint] = []

        for _ in 0..<radius {
            var ring: [GridPoint] = []
            ring.reserveCapacity(4 * (side + 1))
            var x = 0
            while x < side {
                ring.append(GridPoint(x: x, y: n2))
                x += 1
            }

            var y = n2
            while y < side {
                ring.append(GridPoint(x: x, y: y))
                y += 1
            }

            while n2 < x {
                ring.append(GridPoint(x: x, y: y))
                x -= 1
            }

            while n2 < y {
                ring.append(GridPoint(x: x, y: y))
                y -= 1
            }

            while x < 0 {
                ring.append(GridPoint(x: x, y: y))
                x += 1
            }

            result = ring
            n2 -= 1
            side += 1
        }
        return result
    }
}
