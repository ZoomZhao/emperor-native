import Foundation

/// The two fields consumed by the original cMarket `+0x268` availability
/// predicate (`FUN_005D4AC0`). The executable treats a record as empty only
/// when both raw fields are zero; otherwise it adds the second field to the
/// returned total. The semantic mapping of these fields to Native inventory
/// remains intentionally unresolved.
public struct OriginalMarketProviderRecord: Sendable, Hashable, Codable {
    public let rawField4: Int
    public let rawField8: Int

    public init(rawField4: Int, rawField8: Int) {
        self.rawField4 = rawField4
        self.rawField8 = rawField8
    }
}

/// Raw auxiliary-to-image offset mapping used by the Grand Market helper's
/// cache writer (`FUN_00542450 @ 0x542450`).  The caller at
/// `FUN_00543360 @ 0x543360` passes `param_2 == 0`, so modes `0…6` follow the
/// table below while modes `>= 7` return zero without consulting the
/// auxiliary value.  Modes `0`, `2`, `4`, and `6` values above `123` add
/// `cityStatsOffsetValue * 12`; the call site loads that value from
/// `DAT_0130F960 + 0x263C` through `FUN_00413BC0`.  The field's gameplay
/// meaning and producer are unresolved, so callers must supply it explicitly.
///
/// This is an image-offset primitive only.  It does not identify the image
/// archive entry returned by `FUN_00408170`, nor does it rebuild the dynamic
/// `DAT_00FE9880` cache or enable Qin market/provider behavior.
public enum OriginalMarketGrandHelperAuxiliaryOffset {
    /// Returns the offset for a layout auxiliary value in the Grand helper's
    /// authored `100…135` domain. `nil` marks a `124…135` tail whose explicit
    /// city-stats input was omitted, or an input outside the recovered domain.
    public static func offset(
        auxiliary: Int,
        directionMode: Int,
        cityStatsOffsetValue: Int? = nil
    ) -> Int? {
        guard (100...135).contains(auxiliary), directionMode >= 0 else {
            return nil
        }

        switch directionMode {
        case 0:
            if auxiliary <= 123 { return auxiliary - 100 }
            guard let cityStatsOffsetValue else { return nil }
            return cityStatsOffsetValue * 12 + modeZeroTail[auxiliary - 124]
        case 1, 3, 5:
            return 0
        case 2:
            if auxiliary <= 123 { return modeTwoOffset[auxiliary - 100] }
            guard let cityStatsOffsetValue else { return nil }
            return cityStatsOffsetValue * 12 + modeTwoTail[auxiliary - 124]
        case 4:
            if auxiliary <= 123 { return modeFourOffset[auxiliary - 100] }
            guard let cityStatsOffsetValue else { return nil }
            return cityStatsOffsetValue * 12 + modeFourTail[auxiliary - 124]
        case 6:
            if auxiliary <= 123 { return modeSixOffset[auxiliary - 100] }
            guard let cityStatsOffsetValue else { return nil }
            return cityStatsOffsetValue * 12 + modeSixTail[auxiliary - 124]
        default:
            // `param_2 == 0` makes the `DAT_0101D0D0 < 7` guard false.
            return 0
        }
    }

    private static let modeTwoOffset = [
        0x17, 0x13, 0x0F, 0x14, 0x10, 0x0C, 0x16, 0x12,
        0x0E, 0x15, 0x11, 0x0D, 0x00, 0x06, 0x09, 0x03,
        0x01, 0x07, 0x0A, 0x04, 0x02, 0x08, 0x0B, 0x05
    ]

    private static let modeFourOffset = [
        0x05, 0x04, 0x03, 0x02, 0x01, 0x00, 0x0B, 0x0A,
        0x09, 0x08, 0x07, 0x06, 0x17, 0x16, 0x15, 0x14,
        0x13, 0x12, 0x11, 0x10, 0x0F, 0x0E, 0x0D, 0x0C
    ]

    private static let modeSixOffset = [
        0x0C, 0x10, 0x14, 0x0F, 0x13, 0x17, 0x0D, 0x11,
        0x15, 0x0E, 0x12, 0x16, 0x05, 0x0B, 0x08, 0x02,
        0x04, 0x0A, 0x07, 0x01, 0x03, 0x09, 0x06, 0x00
    ]

    private static let modeZeroTail = [
        0x23, 0x21, 0x1F, 0x22, 0x20, 0x1E,
        0x18, 0x1B, 0x19, 0x1C, 0x1A, 0x1D
    ]

    private static let modeTwoTail = modeZeroTail

    private static let modeFourTail = [
        0x1D, 0x1C, 0x1A, 0x1B, 0x19, 0x18,
        0x23, 0x22, 0x21, 0x20, 0x1F, 0x1E
    ]

    private static let modeSixTail = [
        0x1E, 0x20, 0x22, 0x1F, 0x21, 0x23,
        0x1D, 0x1A, 0x1C, 0x19, 0x1B, 0x18
    ]
}

/// Result of the cStall `+0x260` Dinners quality write recovered at
/// `FUN_00541760 @ 0x541760`. The market writer supplies `acceptedAmount`
/// after clipping the cart deposit (the recovered cart call requests 100 and
/// the writer uses `100 - overflow`); `incomingTypeCount` is the raw byte read
/// from `figure+0x13`, not a `FoodQuality` enum value. This is a raw market
/// arithmetic projection only: it does not populate Native inventory or bind
/// an unresolved Qin provider/settlement path.
public struct OriginalMarketQualityBlendResult: Sendable, Hashable, Codable {
    public let oldQuality: Int
    public let oldStock: Int
    public let acceptedAmount: Int
    public let incomingTypeCount: Int
    public let incomingQuality: Int
    public let blendedQuality: Int

    public init(
        oldQuality: Int,
        oldStock: Int,
        acceptedAmount: Int,
        incomingTypeCount: Int,
        incomingQuality: Int,
        blendedQuality: Int
    ) {
        self.oldQuality = oldQuality
        self.oldStock = oldStock
        self.acceptedAmount = acceptedAmount
        self.incomingTypeCount = incomingTypeCount
        self.incomingQuality = incomingQuality
        self.blendedQuality = blendedQuality
    }
}

/// Pure reproduction of the live cMarket `+0x180` blend in
/// `FUN_00541760 @ 0x541760` for commodity key `0x1C` (Dinners).
///
/// The executable computes `round((oldQuality * oldStock + 20 * acceptedAmount
/// * incomingTypeCount) / (oldStock + acceptedAmount))` through
/// `FUN_00541730 @ 0x541730`. All supported inputs are non-negative raw words;
/// for that domain the helper's integer half-up form is exactly the recovered
/// positive-float round (`fraction >= 0.5` increments). A nil result denotes
/// the source-invalid zero denominator or a checked arithmetic overflow.
public enum OriginalMarketQualityBlend {
    public static let incomingContributionPerType = 20

    public static func blend(
        oldQuality: Int,
        oldStock: Int,
        acceptedAmount: Int,
        incomingTypeCount: Int
    ) -> OriginalMarketQualityBlendResult? {
        guard oldQuality >= 0,
              oldStock >= 0,
              acceptedAmount >= 0,
              (0...255).contains(incomingTypeCount) else {
            return nil
        }

        let (denominator, denominatorOverflow) =
            oldStock.addingReportingOverflow(acceptedAmount)
        guard !denominatorOverflow, denominator > 0 else { return nil }

        let (oldTerm, oldTermOverflow) =
            oldQuality.multipliedReportingOverflow(by: oldStock)
        let (incomingQuality, incomingQualityOverflow) =
            incomingTypeCount.multipliedReportingOverflow(by: incomingContributionPerType)
        let (incomingTerm, incomingTermOverflow) =
            incomingQuality.multipliedReportingOverflow(by: acceptedAmount)
        guard !oldTermOverflow,
              !incomingQualityOverflow,
              !incomingTermOverflow else {
            return nil
        }

        let (numerator, numeratorOverflow) = oldTerm.addingReportingOverflow(incomingTerm)
        guard !numeratorOverflow else { return nil }

        // Non-negative integer half-up is equivalent to FUN_00541730's
        // positive float round and avoids introducing a platform-dependent
        // floating-point intermediate into save/replay logic.
        let (roundedNumerator, roundedNumeratorOverflow) =
            numerator.addingReportingOverflow(denominator / 2)
        guard !roundedNumeratorOverflow else { return nil }
        let rounded = roundedNumerator / denominator
        return .init(
            oldQuality: oldQuality,
            oldStock: oldStock,
            acceptedAmount: acceptedAmount,
            incomingTypeCount: incomingTypeCount,
            incomingQuality: incomingQuality,
            blendedQuality: rounded
        )
    }
}

/// Raw band function recovered at `FUN_00545100 @ 0x545100`.
///
/// The executable uses this only as a comparison while handling a market
/// object event; the semantic meaning of the stored cMarket word remains
/// unresolved. Keeping the thresholds separate prevents this research
/// projection from being mistaken for Native food-quality bands.
public enum OriginalMarketStoredBand {
    public static func band(for rawValue: Int) -> Int {
        if rawValue > 0x59 { return 5 }
        if rawValue > 0x45 { return 4 }
        if rawValue > 0x31 { return 3 }
        if rawValue > 0x1D { return 2 }
        return rawValue > 0 ? 1 : 0
    }
}

/// The house-quality update performed by the normal cMarket delivery callback
/// (`FUN_005437B0 @ 0x5437B0`). The callback first replaces the raw house byte
/// when the market dword is better; otherwise it selects one of five weighted
/// integer blends from `delivered/existingStock`. This is deliberately a raw
/// arithmetic primitive: it does not identify the provider record or enable
/// Qin settlement.
public enum OriginalMarketHouseQualityBlend {
    /// The final threshold is the exact single-precision PE constant
    /// `0x3EA8F5C3` (approximately `0.3300000131`), not decimal `0.33`.
    public static let lowerRatio = Double(Float(bitPattern: 0x3EA8F5C3))

    /// Returns the byte value written at `cHouseInfo+0x36`.
    ///
    /// `nil` denotes an invalid raw input. The caller must apply the original
    /// elite-house quality gate separately; this helper only models the
    /// replace/blend arithmetic after that gate has admitted the write.
    public static func resolve(
        currentQuality: Int,
        marketQuality: Int,
        existingStock: Int,
        deliveredAmount: Int
    ) -> Int? {
        guard (0...255).contains(currentQuality),
              (0...255).contains(marketQuality),
              existingStock >= 0,
              deliveredAmount > 0 else {
            return nil
        }
        if marketQuality > currentQuality {
            return marketQuality
        }

        let ratio = existingStock > 0
            ? Double(deliveredAmount) / Double(existingStock)
            : 10.0
        if ratio > 3 { return (currentQuality + 3 * marketQuality) / 4 }
        if ratio > 2 { return (currentQuality + 2 * marketQuality) / 3 }
        if ratio > 0.5 { return (currentQuality + marketQuality) / 2 }
        if ratio > lowerRatio { return (2 * currentQuality + marketQuality) / 3 }
        return (3 * currentQuality + marketQuality) / 4
    }
}

/// Result of the month-boundary Dinners depletion pass recovered at
/// `FUN_00518690 @ 0x518690`.  The source consumes a raw cHouseInfo stock
/// word (`+0x12`) using `floor(residents * 25 / 100)` when the authored food
/// requirement is positive; when the stock is exhausted it also clears the
/// raw quality byte (`+0x36`).  This value is intentionally a raw house-info
/// projection and does not connect the unresolved Qin provider population to
/// Native market settlement.
public struct OriginalMarketMonthlyFoodDepletionResult: Sendable, Hashable, Codable {
    public let stock: Int
    public let qualityRawValue: Int
    public let consumedAmount: Int

    public init(stock: Int, qualityRawValue: Int, consumedAmount: Int) {
        self.stock = stock
        self.qualityRawValue = qualityRawValue
        self.consumedAmount = consumedAmount
    }
}

/// Pure month-boundary arithmetic from `FUN_00518690`.
public enum OriginalMarketMonthlyFoodDepletion {
    public static let residentDrawPercent = 25
    public static let cheatQualityRawValue = 20

    /// Replays one occupied house's Dinners-stock branch. Inputs are the
    /// signed raw house-info words after decoding; unsupported negative or
    /// out-of-byte quality values return `nil` instead of inventing a clamp.
    /// `cheatEnabled` selects the source's alternate branch, which replaces
    /// stock with the calculated draw and writes raw quality `20`.
    public static func apply(
        stock: Int,
        qualityRawValue: Int,
        residents: Int,
        requiredQuality: Int,
        cheatEnabled: Bool
    ) -> OriginalMarketMonthlyFoodDepletionResult? {
        guard (0...Int(Int16.max)).contains(stock),
              (0...255).contains(qualityRawValue),
              (0...Int(Int16.max)).contains(residents) else {
            return nil
        }

        let draw = residents * residentDrawPercent / 100
        if cheatEnabled {
            return .init(
                stock: draw,
                qualityRawValue: cheatQualityRawValue,
                consumedAmount: 0
            )
        }

        guard requiredQuality > 0 else {
            return .init(
                stock: stock,
                qualityRawValue: qualityRawValue,
                consumedAmount: 0
            )
        }

        let consumed = min(stock, draw)
        let remaining = stock - consumed
        return .init(
            stock: remaining,
            qualityRawValue: remaining == 0 ? 0 : qualityRawValue,
            consumedAmount: consumed
        )
    }
}

/// The bounded cMarket `+0x180` write in `FUN_00511080` case 4.
///
/// For a non-negative current raw word, the executable first proposes
/// `current + 0x14`. If that proposal's `FUN_00545100` band exceeds the
/// cMarket `+0x184` cap, it retries `current + 0x13` down through `current`
/// until the band is within the cap, then writes the accepted raw word. This
/// helper intentionally exposes only that arithmetic boundary; it does not
/// claim a market-quality meaning or connect the event path to Qin.
public enum OriginalMarketStoredState {
    public static func advance(currentValue: Int, maximumBand: Int) -> Int? {
        guard currentValue >= 0, maximumBand >= 0 else { return nil }

        let (initial, overflow) = currentValue.addingReportingOverflow(0x14)
        guard !overflow else { return nil }
        if OriginalMarketStoredBand.band(for: initial) <= maximumBand {
            return initial
        }

        // FUN_00511080 initializes n=0x14, decrements before the first
        // retry, and never proposes a value below the current raw word.
        for decrement in stride(from: 0x13, through: 0, by: -1) {
            let (candidate, candidateOverflow) =
                currentValue.addingReportingOverflow(decrement)
            guard !candidateOverflow else { return nil }
            if OriginalMarketStoredBand.band(for: candidate) <= maximumBand {
                return candidate
            }
        }
        return nil
    }
}

/// The cHouseInfo inventory-slot projection used by the original market
/// writer (`FUN_00447600 @ 0x447600`). This is a slot identity, not a claim
/// that every provider-record source has already been mapped to Native.
public enum OriginalMarketHouseInfoSlot {
    public static func slot(forCommodityID commodityID: Int) -> Int? {
        switch commodityID {
        case 0x1C: return 0 // Dinners
        case 0x13: return 1 // Hemp
        case 0x19: return 2 // Ceramics
        case 0x18: return 3 // Silk
        case 0x17: return 4 // Bronzeware
        case 0x16: return 5 // Lacquerware
        case 0x0D: return 6 // Tea
        default: return nil
        }
    }
}

/// Selector admission for a child object in the original cMarket container.
///
/// `FUN_005408D0 @ 0x5408D0` is the cStall vtable `+0xC8` method.  This helper
/// keeps its model-specific predicate explicit without pretending that the
/// resulting `+0x44` aggregate is a Native worker or coverage value.  `nil`
/// means the supplied model is outside the recovered cStall factory set and
/// must not be classified by this helper.
public enum OriginalMarketChildAdmission {
    public static let cStallModelIDs = Set(62...70)
    public static let emptyShopModelID = 62

    public static func cStallAdmits(
        selector: Int,
        shopBuildingID: Int
    ) -> Bool? {
        guard cStallModelIDs.contains(shopBuildingID) else { return nil }
        if selector == -2 { return true }
        if selector == -1 { return shopBuildingID == emptyShopModelID }
        return shopBuildingID == selector
    }
}

/// Raw cStall implementation of virtual `+0x1B8` (`FUN_00416B10`). The
/// executable returns the receiver's `+0x44` field as a sign-extended 16-bit
/// value; that field's player-facing meaning is unresolved. Non-cStall model
/// IDs return `nil` so a market or other building cannot be classified as a
/// shop child by this helper.
public enum OriginalMarketChildWorkerValue {
    public static let vTableOffset = 0x1B8
    public static let sourceAddress = 0x00416B10

    public static func value(
        shopBuildingID: Int,
        rawField44: Int
    ) -> Int? {
        guard OriginalMarketChildAdmission.cStallModelIDs.contains(shopBuildingID) else {
            return nil
        }
        return Int(Int16(truncatingIfNeeded: rawField44))
    }
}

/// Raw six-slot inputs consumed by the cMarket peddler worker-ratio helpers.
/// `employeeField` is the authored model-table field 5 passed through
/// `FUN_0044CC50(modelID, 5)`; `rawField44` is the signed cStall word read by
/// `FUN_00416B10`.  A slot marked absent is the same as a non-positive entry
/// in cMarket's `+0x15C` child-ID array.
public struct OriginalMarketPeddlerWorkerAggregateInput: Sendable, Hashable, Codable {
    public let slotPresent: Bool
    public let shopBuildingID: Int
    public let rawField44: Int
    public let employeeField: Int

    public init(
        slotPresent: Bool,
        shopBuildingID: Int,
        rawField44: Int = 0,
        employeeField: Int = 0
    ) {
        self.slotPresent = slotPresent
        self.shopBuildingID = shopBuildingID
        self.rawField44 = rawField44
        self.employeeField = employeeField
    }
}

/// The two raw aggregates passed to `FUN_00543ED0` by
/// `FUN_00544A40`/`FUN_00544A80(-1)`.  The executable's numerator is not a
/// sum of every shop child: selector `-1` admits only Empty Shop (`0x3E`),
/// while the denominator sums model-table employee fields for present,
/// non-Empty-Shop children.  Provider/route/settlement semantics remain
/// unresolved, so this is deliberately a side-effect-free boundary.
public struct OriginalMarketPeddlerWorkerAggregate: Sendable, Hashable, Codable {
    public let rawEmptyShopField44: Int
    public let filledShopEmployeeUnits: Int

    public init(rawEmptyShopField44: Int, filledShopEmployeeUnits: Int) {
        self.rawEmptyShopField44 = rawEmptyShopField44
        self.filledShopEmployeeUnits = filledShopEmployeeUnits
    }

    public static func from(
        entries: [OriginalMarketPeddlerWorkerAggregateInput]
    ) -> Self? {
        guard entries.count <= 6,
              entries.allSatisfy({
                  !$0.slotPresent
                      || OriginalMarketChildAdmission.cStallModelIDs.contains($0.shopBuildingID)
              }) else { return nil }

        var rawEmptyShopField44 = 0
        var filledShopEmployeeUnits = 0
        for entry in entries where entry.slotPresent {
            if entry.shopBuildingID == OriginalMarketChildAdmission.emptyShopModelID {
                // FUN_00416B10 sign-extends the stored 16-bit word.
                rawEmptyShopField44 += Int(Int16(truncatingIfNeeded: entry.rawField44))
            } else {
                filledShopEmployeeUnits += entry.employeeField
            }
        }
        return .init(
            rawEmptyShopField44: rawEmptyShopField44,
            filledShopEmployeeUnits: filledShopEmployeeUnits
        )
    }
}

/// Raw category-index boundary for cStall children.  The executable's
/// `FUN_004271D0` callback reads the first dword from the fixed
/// `DAT_008235A8 + modelID * 0x18` table; canonical EN/CH bytes return `2`
/// for every model admitted by `FUN_005418D0` (Empty Shop 62 and shop models
/// 64...70).  The category has no recovered player-facing meaning, so this
/// catalog is research-only and is not a workforce or inventory mapping.
public enum OriginalMarketCStallCategoryCatalog {
    public static let admittedShopModelIDs: Set<Int> = [62, 64, 65, 66, 67, 68, 69, 70]
    public static let sourceCategoryIndex = 2

    public static func sourceCategoryIndex(forShopBuildingID buildingID: Int) -> Int? {
        admittedShopModelIDs.contains(buildingID) ? sourceCategoryIndex : nil
    }
}

/// Explicit inputs to the generic object-admission callback used by
/// `FUN_004AE220` (`FUN_004271D0 @ 0x4271D0`).  These names intentionally
/// retain source offsets and callback positions rather than assigning a
/// provider or inventory meaning to the words.
public struct OriginalMarketPoolAdmissionInput: Sendable, Hashable, Codable {
    public let tableCategory: Int
    public let globalActive: Bool
    public let objectWord4E: Int
    public let emptyShopConflict: Bool
    public let objectWord3C: Int
    public let specialCategoryConflict: Bool
    public let callback198Accepted: Bool
    public let callback78Accepted: Bool

    public init(
        tableCategory: Int,
        globalActive: Bool,
        objectWord4E: Int,
        emptyShopConflict: Bool,
        objectWord3C: Int,
        specialCategoryConflict: Bool,
        callback198Accepted: Bool,
        callback78Accepted: Bool
    ) {
        self.tableCategory = tableCategory
        self.globalActive = globalActive
        self.objectWord4E = objectWord4E
        self.emptyShopConflict = emptyShopConflict
        self.objectWord3C = objectWord3C
        self.specialCategoryConflict = specialCategoryConflict
        self.callback198Accepted = callback198Accepted
        self.callback78Accepted = callback78Accepted
    }
}

public enum OriginalMarketPoolAdmissionCatalog {
    public static let sourceAddress: UInt32 = 0x004271D0
    public static let tableAddress: UInt32 = 0x008235A8
    public static let tableRowStride = 0x18
    public static let emptyShopPredicateArgument = 0x3E
    public static let specialCategoryValues: Set<Int> = [0, 1, 7]

    /// Mirrors the boolean gate order in `FUN_004271D0` without performing
    /// its source-side writes to object `+0x46` or the out-parameter.
    public static func accepts(_ input: OriginalMarketPoolAdmissionInput) -> Bool {
        guard input.tableCategory >= 0, input.tableCategory != 9 else { return false }
        guard input.globalActive else { return false }
        guard input.objectWord4E == 0 else { return false }
        guard !input.emptyShopConflict else { return false }
        guard input.objectWord3C == 0 else { return false }
        if specialCategoryValues.contains(input.tableCategory) {
            guard !input.specialCategoryConflict else { return false }
        }
        guard input.callback198Accepted else { return false }
        return input.callback78Accepted
    }
}

/// One raw five-dword row consumed by `FUN_004F19A0 @ 0x4F19A0`.
/// The executable's table labels are not recovered; keeping the words
/// positional prevents a guessed inventory/worker interpretation from
/// leaking into the Native market model.
public struct OriginalMarketCStallPoolRecord: Sendable, Hashable, Codable {
    public let sourceWord0: Int
    public let sourceWord1: Int
    public let sourceWord2: Int
    public let sourceWord3: Int
    public let sourceWord4: Int

    public init(
        sourceWord0: Int,
        sourceWord1: Int,
        sourceWord2: Int,
        sourceWord3: Int,
        sourceWord4: Int
    ) {
        self.sourceWord0 = sourceWord0
        self.sourceWord1 = sourceWord1
        self.sourceWord2 = sourceWord2
        self.sourceWord3 = sourceWord3
        self.sourceWord4 = sourceWord4
    }
}

/// The two ten-slot arrays built by `FUN_004F19A0` before it calls each cStall
/// `+0x18C` callback.  These are raw source arrays, not Native stock or labor
/// values; the cStall callback still consumes them with selectors `1` and `2`.
public struct OriginalMarketCStallPoolProjection: Sendable, Hashable, Codable {
    public let firstPool: [Int]
    public let secondPool: [Int]

    public init(firstPool: [Int], secondPool: [Int]) {
        self.firstPool = firstPool
        self.secondPool = secondPool
    }
}

public enum OriginalMarketCStallPoolProjectionCatalog {
    public static let sourceAddress: UInt32 = 0x004F19A0
    public static let sourceTableAddress: UInt32 = 0x01312144
    public static let sourceRecordCount = 9
    public static let sourceRecordStride = 0x14
    public static let callbackPoolSlotCount = 10
    public static let callbackSelectors = [1, 2]

    /// Reproduces the raw array preparation in `FUN_004F19A0`.
    /// For each of the nine fixed rows, the source writes `sourceWord3` to
    /// the first pool and `sourceWord1 - sourceWord3` to the second only when
    /// `sourceWord1 < sourceWord0`; otherwise both entries remain zero.  The
    /// tenth local-array slot is never touched and therefore stays zero.
    /// This helper intentionally stops before the virtual cStall callback and
    /// assigns no semantic meaning to either pool.
    public static func project(
        records: [OriginalMarketCStallPoolRecord]
    ) -> OriginalMarketCStallPoolProjection? {
        guard records.count == sourceRecordCount else { return nil }

        var firstPool = Array(repeating: 0, count: callbackPoolSlotCount)
        var secondPool = Array(repeating: 0, count: callbackPoolSlotCount)
        for (index, record) in records.enumerated() where record.sourceWord1 < record.sourceWord0 {
            firstPool[index] = record.sourceWord3
            secondPool[index] = record.sourceWord1 - record.sourceWord3
        }
        return .init(firstPool: firstPool, secondPool: secondPool)
    }
}

/// Result of the fixed nine-row balancing pass at `FUN_004F1590`.
/// Every field remains positional/raw: the executable's row words and global
/// totals have not acquired a verified player-facing inventory meaning.
public struct OriginalMarketCStallPoolBalanceResult: Sendable, Hashable, Codable {
    public let rows: [OriginalMarketCStallPoolRecord]
    public let sourceTotal: Int
    public let normalizedTotal: Int
    public let unallocatedTotal: Int
    public let normalizedShortfall: Int
    public let normalizedShortfallPercent: Int

    public init(
        rows: [OriginalMarketCStallPoolRecord],
        sourceTotal: Int,
        normalizedTotal: Int,
        unallocatedTotal: Int,
        normalizedShortfall: Int,
        normalizedShortfallPercent: Int
    ) {
        self.rows = rows
        self.sourceTotal = sourceTotal
        self.normalizedTotal = normalizedTotal
        self.unallocatedTotal = unallocatedTotal
        self.normalizedShortfall = normalizedShortfall
        self.normalizedShortfallPercent = normalizedShortfallPercent
    }
}

public enum OriginalMarketCStallPoolBalanceCatalog {
    public static let sourceAddress: UInt32 = 0x004F1590
    public static let sourceTableAddress: UInt32 = 0x01312138
    public static let targetAddress: UInt32 = 0x01312134
    public static let normalizedTotalAddress: UInt32 = 0x01312200
    public static let unallocatedTotalAddress: UInt32 = 0x01312210
    public static let normalizedShortfallAddress: UInt32 = 0x01312204
    public static let normalizedShortfallPercentAddress: UInt32 = 0x01312208
    public static let recordCount = 9
    public static let recordStride = 0x14
    public static let categoryCount = 6

    /// Reproduces the raw row balancing in `FUN_004F1590`.
    ///
    /// The source first clears row word 1 and changes row word 4 to `3` only
    /// when it is greater than `5`.  When the row-word-0 sum exceeds the
    /// supplied target, it allocates by category `5...0`, using the source's
    /// integer percentage/scaling helpers and ordered one-unit top-ups.  The
    /// returned rows are exactly the inputs consumed by `FUN_004F19A0`; no
    /// semantic stock, labor, or provider interpretation is introduced.
    public static func balance(
        records: [OriginalMarketCStallPoolRecord],
        targetTotal: Int
    ) -> OriginalMarketCStallPoolBalanceResult? {
        guard records.count == recordCount else { return nil }

        // [word0, word1, word2, word3, word4]
        var rows = records.map {
            var words = [
                $0.sourceWord0, $0.sourceWord1, $0.sourceWord2,
                $0.sourceWord3, $0.sourceWord4,
            ]
            words[1] = 0
            if words[4] > 5 { words[4] = 3 }
            return words
        }
        let sourceTotal = rows.reduce(0) { $0 + $1[0] }
        var remaining = targetTotal < sourceTotal ? targetTotal : sourceTotal

        @inline(__always) func percent(_ numerator: Int, _ denominator: Int) -> Int {
            denominator == 0 ? 0 : (numerator * 100) / denominator
        }

        @inline(__always) func scale(_ value: Int, _ percentage: Int) -> Int {
            (value * percentage) / 100
        }

        func categorySums(_ category: Int) -> (deficit: Int, base: Int) {
            rows.reduce(into: (0, 0)) { sums, row in
                guard row[4] == category else { return }
                sums.deficit += row[0] - row[2]
                sums.base += row[2]
            }
        }

        func distributeCategory(_ category: Int, remaining: inout Int) {
            let sums = categorySums(category)
            let shareBase: Int
            let shareDeficit: Int
            if category == 0 {
                shareBase = 0
                shareDeficit = 0
            } else if remaining <= sums.base {
                shareBase = percent(remaining, sums.base)
                shareDeficit = 0
            } else {
                shareBase = 100
                shareDeficit = min(100, percent(remaining - sums.base, sums.deficit))
            }

            var residualBase = sums.base
            var residualDeficit = sums.deficit
            for index in rows.indices where rows[index][4] == category {
                let base = rows[index][2]
                let total = rows[index][0]
                let allocatedBase = scale(base, shareBase)
                let allocatedDeficit = scale(total - base, shareDeficit)
                rows[index][3] = allocatedBase
                rows[index][1] = allocatedBase + allocatedDeficit
                remaining -= allocatedBase + allocatedDeficit
                residualBase -= allocatedBase
                residualDeficit -= allocatedDeficit
                if remaining < 1 { break }
            }

            guard category != 0 else { return }
            while residualBase > 0 && remaining > 0 {
                var progressed = false
                for index in rows.indices where rows[index][4] == category {
                    guard remaining > 0, residualBase > 0 else { break }
                    if rows[index][3] < rows[index][2] {
                        rows[index][3] += 1
                        rows[index][1] += 1
                        remaining -= 1
                        residualBase -= 1
                        progressed = true
                    }
                }
                guard progressed else { break }
            }
            while residualDeficit > 0 && remaining > 0 {
                var progressed = false
                for index in rows.indices where rows[index][4] == category {
                    guard remaining > 0, residualDeficit > 0 else { break }
                    if rows[index][1] < rows[index][0] {
                        rows[index][1] += 1
                        remaining -= 1
                        residualDeficit -= 1
                        progressed = true
                    }
                }
                guard progressed else { break }
            }
        }

        if targetTotal < sourceTotal {
            var category = 5
            while category > 0 && remaining > 0 {
                distributeCategory(category, remaining: &remaining)
                category -= 1
            }

            // `LAB_004F179C` repeats the same arithmetic for category zero,
            // then performs the two ordered one-unit top-up loops.
            if remaining > 0 {
                let sums = categorySums(0)
                let shareBase: Int
                let shareDeficit: Int
                if sums.base < remaining {
                    shareBase = 100
                    shareDeficit = min(100, percent(remaining - sums.base, sums.deficit))
                } else {
                    shareBase = percent(remaining, 0)
                    shareDeficit = 0
                }
                var residualBase = sums.base
                var residualDeficit = sums.deficit
                for index in rows.indices where rows[index][4] == 0 {
                    let base = rows[index][2]
                    let total = rows[index][0]
                    let allocatedBase = scale(base, shareBase)
                    let allocatedDeficit = scale(total - base, shareDeficit)
                    rows[index][3] = allocatedBase
                    rows[index][1] = allocatedBase + allocatedDeficit
                    remaining -= allocatedBase + allocatedDeficit
                    residualBase -= allocatedBase
                    residualDeficit -= allocatedDeficit
                    if remaining < 1 { break }
                }
                while residualBase > 0 && remaining > 0 {
                    var progressed = false
                    for index in rows.indices where rows[index][4] == 0 {
                        guard remaining > 0, residualBase > 0 else { break }
                        if rows[index][3] < rows[index][2] {
                            rows[index][3] += 1
                            rows[index][1] += 1
                            remaining -= 1
                            residualBase -= 1
                            progressed = true
                        }
                    }
                    guard progressed else { break }
                }
                while residualDeficit > 0 && remaining > 0 {
                    var progressed = false
                    for index in rows.indices where rows[index][4] == 0 {
                        guard remaining > 0, residualDeficit > 0 else { break }
                        if rows[index][1] < rows[index][0] {
                            rows[index][1] += 1
                            remaining -= 1
                            residualDeficit -= 1
                            progressed = true
                        }
                    }
                    guard progressed else { break }
                }
            }
        } else {
            for index in rows.indices {
                rows[index][1] = rows[index][0]
                rows[index][3] = rows[index][2]
            }
            remaining = sourceTotal
        }

        let normalizedTotal = targetTotal < sourceTotal ? targetTotal : sourceTotal
        let unallocatedTotal = rows.reduce(0) { $0 + ($1[0] - $1[1]) }
        let normalizedShortfall = targetTotal - normalizedTotal
        let normalizedShortfallPercent = percent(normalizedShortfall, targetTotal)
        let resultRows = rows.map {
            OriginalMarketCStallPoolRecord(
                sourceWord0: $0[0], sourceWord1: $0[1], sourceWord2: $0[2],
                sourceWord3: $0[3], sourceWord4: $0[4]
            )
        }
        return .init(
            rows: resultRows,
            sourceTotal: sourceTotal,
            normalizedTotal: normalizedTotal,
            unallocatedTotal: unallocatedTotal,
            normalizedShortfall: normalizedShortfall,
            normalizedShortfallPercent: normalizedShortfallPercent
        )
    }
}

/// Raw inputs to the cStall `+0x18C` field producer (`FUN_0051E310`).
/// `statusCode` is the word written by the receiver's `+0x188` callback;
/// `selector` and the two pool values are the arguments supplied by
/// `FUN_004F19A0`.  The two ratio pairs are kept explicit because their
/// source record fields have not acquired a player-facing semantic name.
public struct OriginalMarketCStallField44Input: Sendable, Hashable, Codable {
    public let callbackAccepted: Bool
    public let statusCode: Int
    public let selector: Int
    public let providerUsesPrimaryPool: Bool
    public let providerCapacity: Int
    public let currentField44: Int
    public let primaryRatioNumerator: Int
    public let primaryRatioDenominator: Int
    public let secondaryRatioNumerator: Int
    public let secondaryRatioDenominator: Int
    public let primaryPoolValue: Int
    public let secondaryPoolValue: Int

    public init(
        callbackAccepted: Bool,
        statusCode: Int,
        selector: Int,
        providerUsesPrimaryPool: Bool,
        providerCapacity: Int,
        currentField44: Int,
        primaryRatioNumerator: Int = 0,
        primaryRatioDenominator: Int = 0,
        secondaryRatioNumerator: Int = 0,
        secondaryRatioDenominator: Int = 0,
        primaryPoolValue: Int = 0,
        secondaryPoolValue: Int = 0
    ) {
        self.callbackAccepted = callbackAccepted
        self.statusCode = statusCode
        self.selector = selector
        self.providerUsesPrimaryPool = providerUsesPrimaryPool
        self.providerCapacity = providerCapacity
        self.currentField44 = currentField44
        self.primaryRatioNumerator = primaryRatioNumerator
        self.primaryRatioDenominator = primaryRatioDenominator
        self.secondaryRatioNumerator = secondaryRatioNumerator
        self.secondaryRatioDenominator = secondaryRatioDenominator
        self.primaryPoolValue = primaryPoolValue
        self.secondaryPoolValue = secondaryPoolValue
    }
}

/// Ordered raw result of one cStall `+0x18C` producer call.  This mirrors the
/// source's low-width field writes while leaving provider registration,
/// market ownership, and settlement outside the helper.
public struct OriginalMarketCStallField44Output: Sendable, Hashable, Codable {
    public let nextField44: Int16
    public let primaryPoolValue: Int
    public let secondaryPoolValue: Int
    public let consumedPoolValue: Int
    public let usedPrimaryPool: Bool
    public let ratioPercent: Int?
    public let allocatedAmount: Int?

    public init(
        nextField44: Int16,
        primaryPoolValue: Int,
        secondaryPoolValue: Int,
        consumedPoolValue: Int,
        usedPrimaryPool: Bool,
        ratioPercent: Int?,
        allocatedAmount: Int?
    ) {
        self.nextField44 = nextField44
        self.primaryPoolValue = primaryPoolValue
        self.secondaryPoolValue = secondaryPoolValue
        self.consumedPoolValue = consumedPoolValue
        self.usedPrimaryPool = usedPrimaryPool
        self.ratioPercent = ratioPercent
        self.allocatedAmount = allocatedAmount
    }
}

public enum OriginalMarketCStallField44Producer {
    /// Reproduces the byte-level arithmetic of `FUN_0051E310 @ 0x51E310`.
    /// The receiver's `+0x188` callback result and status word are explicit;
    /// a failed callback jumps straight to the epilogue when its status is
    /// exactly `9`, preserving `+0x44`; other failed callbacks clear it.
    /// Selectors `<= 1` reset the field, allocate the smaller of the
    /// provider capacity and the selected ratio share, and subtract that
    /// amount from the selected pool. Selectors `> 1` top up toward provider
    /// capacity from the selected pool. All writes to `+0x44` preserve the
    /// source's signed 16-bit storage width.
    public static func apply(
        _ input: OriginalMarketCStallField44Input
    ) -> OriginalMarketCStallField44Output {
        let primary = input.primaryPoolValue
        let secondary = input.secondaryPoolValue
        guard input.callbackAccepted else {
            if input.statusCode == 9 {
                return .init(
                    nextField44: Int16(truncatingIfNeeded: input.currentField44),
                    primaryPoolValue: primary,
                    secondaryPoolValue: secondary,
                    consumedPoolValue: 0,
                    usedPrimaryPool: input.providerUsesPrimaryPool,
                    ratioPercent: nil,
                    allocatedAmount: nil
                )
            }
            return .init(
                nextField44: 0,
                primaryPoolValue: primary,
                secondaryPoolValue: secondary,
                consumedPoolValue: 0,
                usedPrimaryPool: input.providerUsesPrimaryPool,
                ratioPercent: nil,
                allocatedAmount: nil
            )
        }

        if input.selector <= 1 {
            let ratioNumerator = input.providerUsesPrimaryPool
                ? input.primaryRatioNumerator
                : input.secondaryRatioNumerator
            let ratioDenominator = input.providerUsesPrimaryPool
                ? input.primaryRatioDenominator
                : input.secondaryRatioDenominator
            let ratio = ratioDenominator == 0
                ? 0
                : (ratioNumerator * 100) / ratioDenominator
            let ratioShare = (input.providerCapacity * ratio) / 100
            let allocated = min(input.providerCapacity, ratioShare)
            let nextPrimary = input.providerUsesPrimaryPool
                ? primary - allocated
                : primary
            let nextSecondary = input.providerUsesPrimaryPool
                ? secondary
                : secondary - allocated
            return .init(
                nextField44: Int16(truncatingIfNeeded: allocated),
                primaryPoolValue: nextPrimary,
                secondaryPoolValue: nextSecondary,
                consumedPoolValue: allocated,
                usedPrimaryPool: input.providerUsesPrimaryPool,
                ratioPercent: ratio,
                allocatedAmount: allocated
            )
        }

        let current = Int(Int16(truncatingIfNeeded: input.currentField44))
        guard current < input.providerCapacity else {
            return .init(
                nextField44: Int16(truncatingIfNeeded: current),
                primaryPoolValue: primary,
                secondaryPoolValue: secondary,
                consumedPoolValue: 0,
                usedPrimaryPool: input.providerUsesPrimaryPool,
                ratioPercent: nil,
                allocatedAmount: nil
            )
        }

        let needed = input.providerCapacity - current
        let selectedPool = input.providerUsesPrimaryPool ? primary : secondary
        if needed > selectedPool {
            let nextField = Int16(truncatingIfNeeded: current)
                &+ Int16(truncatingIfNeeded: selectedPool)
            return .init(
                nextField44: nextField,
                primaryPoolValue: input.providerUsesPrimaryPool ? 0 : primary,
                secondaryPoolValue: input.providerUsesPrimaryPool ? secondary : 0,
                consumedPoolValue: selectedPool,
                usedPrimaryPool: input.providerUsesPrimaryPool,
                ratioPercent: nil,
                allocatedAmount: selectedPool
            )
        }

        let nextField = Int16(truncatingIfNeeded: current)
            &+ Int16(truncatingIfNeeded: needed)
        return .init(
            nextField44: nextField,
            primaryPoolValue: input.providerUsesPrimaryPool ? primary - needed : primary,
            secondaryPoolValue: input.providerUsesPrimaryPool ? secondary : secondary - needed,
            consumedPoolValue: needed,
            usedPrimaryPool: input.providerUsesPrimaryPool,
            ratioPercent: nil,
            allocatedAmount: needed
        )
    }
}

/// One cMarket child slot as consumed by `FUN_00544340 @ 0x544340`.
/// `isActive` is the child vtable `+0xC8(-1)` result; `commodityID` is the
/// selected provider-record key. These fields are deliberately raw and do
/// not imply a Native inventory or settlement record.
public struct OriginalMarketActiveCommodityEntry: Sendable, Hashable, Codable {
    public let isActive: Bool
    public let commodityID: Int

    public init(isActive: Bool, commodityID: Int) {
        self.isActive = isActive
        self.commodityID = commodityID
    }
}

/// Reproduces the six-slot cMarket scan in `FUN_00544340`.
/// The original increments its result only when a child passes the active
/// selector `-1` and its record key equals the requested commodity. A nil
/// result rejects a synthetic table larger than the executable's six slots.
public enum OriginalMarketActiveCommodityCount {
    public static let sourceAddress = 0x00544340
    public static let maximumChildSlots = 6

    public static func count(
        entries: [OriginalMarketActiveCommodityEntry],
        commodityID: Int
    ) -> Int? {
        guard entries.count <= maximumChildSlots else { return nil }
        return entries.reduce(into: 0) { total, entry in
            if entry.isActive && entry.commodityID == commodityID {
                total += 1
            }
        }
    }
}

/// The seven shop/provider rows recovered from the original PE table at
/// `DAT_008572E8` (row stride `0x40`). `slotIndex` is the zero-based static
/// table-row/selection index; it is not a fixed cMarket runtime-record slot.
/// The original placement path (`FUN_005428B0`) assigns runtime record slots
/// dynamically from the active Common/Grand market layout (four or six bays).
/// `shopBuildingID` and `commodityID` are the table's literal model/resource
/// keys. `placementCapacity` is the exact capacity
/// selected by the row's `+0x18` flag during `FUN_00540F80` placement setup;
/// `nil` is reserved for an unmapped row and is never synthesized into a
/// runtime record. This is a research catalog only: it does not synthesize
/// Native provider records or bypass the unresolved provider object-to-market
/// ownership path.
public struct OriginalMarketProviderSlot: Sendable, Hashable, Codable {
    public let slotIndex: Int
    public let shopBuildingID: Int
    public let commodityID: Int

    public init(slotIndex: Int, shopBuildingID: Int, commodityID: Int) {
        self.slotIndex = slotIndex
        self.shopBuildingID = shopBuildingID
        self.commodityID = commodityID
    }

    /// Placement capacity recovered from `DAT_008572E8` row `+0x18`.
    public var placementCapacity: Int? {
        switch shopBuildingID {
        case 66: return 800 // row flag +0x18 = 0
        case 64...65, 67...70: return 400 // row flag +0x18 = 1
        default: return nil
        }
    }
}

public enum OriginalMarketProviderSlotCatalog {
    /// Exact row order from `DAT_008572E8`: Food, Hemp, Tea, Ceramics,
    /// Bronzeware, Lacquerware, Silk.
    public static let entries: [OriginalMarketProviderSlot] = [
        .init(slotIndex: 0, shopBuildingID: 66, commodityID: 0x1C),
        .init(slotIndex: 1, shopBuildingID: 67, commodityID: 0x13),
        .init(slotIndex: 2, shopBuildingID: 70, commodityID: 0x0D),
        .init(slotIndex: 3, shopBuildingID: 65, commodityID: 0x19),
        .init(slotIndex: 4, shopBuildingID: 64, commodityID: 0x17),
        .init(slotIndex: 5, shopBuildingID: 68, commodityID: 0x16),
        .init(slotIndex: 6, shopBuildingID: 69, commodityID: 0x18),
    ]

    public static func entry(forShopBuildingID buildingID: Int) -> OriginalMarketProviderSlot? {
        entries.first { $0.shopBuildingID == buildingID }
    }

    public static func entry(forCommodityID commodityID: Int) -> OriginalMarketProviderSlot? {
        entries.first { $0.commodityID == commodityID }
    }
}

/// One non-Dinners pass in the normal cMarket house-delivery writer
/// (`FUN_005437B0 @ 0x5437B0`). The writer walks six contiguous 0x40-byte
/// records beginning at `0x857344`; each record's first dword is the cMarket
/// provider-record slot used for the `+0x1E8` count decrement, while the
/// preceding dword is the raw commodity key passed to `+0x264`.
///
/// This is a raw writer-order descriptor only. It does not identify the
/// provider-record population source or enable Qin settlement.
public struct OriginalMarketHouseDeliveryPass: Sendable, Hashable, Codable {
    public let tableAddress: UInt32
    public let providerRecordSlot: Int
    public let commodityID: Int

    public init(
        tableAddress: UInt32,
        providerRecordSlot: Int,
        commodityID: Int
    ) {
        self.tableAddress = tableAddress
        self.providerRecordSlot = providerRecordSlot
        self.commodityID = commodityID
    }
}

public enum OriginalMarketHouseDeliveryPassCatalog {
    /// Direct PE order from `FUN_005437B0`: Hemp, Tea, Ceramics,
    /// Lacquerware, Bronzeware, Silk. Dinners (`0x1C`) is handled by the
    /// separate callback branch before this loop.
    public static let entries: [OriginalMarketHouseDeliveryPass] = [
        .init(tableAddress: 0x00857344, providerRecordSlot: 1, commodityID: 0x13),
        .init(tableAddress: 0x00857384, providerRecordSlot: 2, commodityID: 0x0D),
        .init(tableAddress: 0x008573C4, providerRecordSlot: 3, commodityID: 0x19),
        .init(tableAddress: 0x00857404, providerRecordSlot: 4, commodityID: 0x16),
        .init(tableAddress: 0x00857444, providerRecordSlot: 5, commodityID: 0x17),
        .init(tableAddress: 0x00857484, providerRecordSlot: 6, commodityID: 0x18),
    ]

    public static func entry(forCommodityID commodityID: Int)
        -> OriginalMarketHouseDeliveryPass? {
        entries.first { $0.commodityID == commodityID }
    }
}

/// One 16-byte entry in a market-helper layout bank. The original stores
/// `(x, y, kind, aux)` as four little-endian dwords. `kind == 2 && aux != 0`
/// is the allocator's active-bay predicate; all other rows are decorative or
/// structural layout entries and do not receive a runtime provider slot.
public struct OriginalMarketLayoutEntry: Sendable, Hashable, Codable {
    public let index: Int
    public let x: Int
    public let y: Int
    public let kind: Int
    public let aux: Int

    public init(index: Int, x: Int, y: Int, kind: Int, aux: Int) {
        self.index = index
        self.x = x
        self.y = y
        self.kind = kind
        self.aux = aux
    }

    public var isActiveBay: Bool { kind == 2 && aux != 0 }
}

/// The market-helper layout banks consumed by the original `FUN_005428B0`
/// allocator. These are static evidence descriptors only: they expose the
/// complete authored bank and the active-bay ordinal that the executable can
/// assign, but do not bind a shop selection row to a bay or create Native
/// provider records.
public struct OriginalMarketLayoutDescriptor: Sendable, Hashable, Codable {
    public let marketBuildingID: Int
    public let helperEntryCount: Int
    public let layoutBankAddress: UInt32
    public let activeLayoutEntryIndices: [Int]
    public let layoutEntries: [OriginalMarketLayoutEntry]

    public init(
        marketBuildingID: Int,
        helperEntryCount: Int,
        layoutBankAddress: UInt32,
        activeLayoutEntryIndices: [Int],
        layoutEntries: [OriginalMarketLayoutEntry] = []
    ) {
        self.marketBuildingID = marketBuildingID
        self.helperEntryCount = helperEntryCount
        self.layoutBankAddress = layoutBankAddress
        self.activeLayoutEntryIndices = activeLayoutEntryIndices
        self.layoutEntries = layoutEntries
    }

    public var activeBayCount: Int { activeLayoutEntryIndices.count }

    /// Returns the compact runtime slot assigned to an active layout entry.
    /// Non-active entries have no runtime provider-record slot.
    public func runtimeSlot(forLayoutEntryIndex index: Int) -> Int? {
        activeLayoutEntryIndices.firstIndex(of: index)
    }

    public func layoutEntry(at index: Int) -> OriginalMarketLayoutEntry? {
        layoutEntries.first { $0.index == index }
    }
}

public enum OriginalMarketLayoutCatalog {
    /// `cMarket`'s provider-container method `0x4E1BF0` returns six records.
    /// Common/Grand helpers consume different layout banks but share this
    /// maximum record count.
    public static let maximumProviderRecordCount = 6

    /// `FUN_00543450` selects the Grand helper for building ID `0x3C` (60)
    /// and the Common helper for building ID `0x3B` (59).
    public static let common = OriginalMarketLayoutDescriptor(
        marketBuildingID: 59,
        helperEntryCount: 28,
        layoutBankAddress: 0x008574A8,
        activeLayoutEntryIndices: [0, 2, 20, 22],
        layoutEntries: commonLayoutEntries
    )

    public static let grand = OriginalMarketLayoutDescriptor(
        marketBuildingID: 60,
        helperEntryCount: 42,
        layoutBankAddress: 0x00857828,
        activeLayoutEntryIndices: [0, 2, 4, 30, 32, 34],
        layoutEntries: grandLayoutEntries
    )

    public static let entries: [OriginalMarketLayoutDescriptor] = [common, grand]

    public static func descriptor(forMarketBuildingID buildingID: Int) -> OriginalMarketLayoutDescriptor? {
        entries.first { $0.marketBuildingID == buildingID }
    }

    private static let commonLayoutEntries: [OriginalMarketLayoutEntry] = [
        (0, 0, 0, 2, 1), (1, 1, 0, 2, 0), (2, 2, 0, 2, 1), (3, 3, 0, 2, 0),
        (4, 0, 1, 2, 0), (5, 1, 1, 2, 0), (6, 2, 1, 2, 0), (7, 3, 1, 2, 0),
        (8, 0, 2, 4, 0), (9, 1, 2, 4, 0), (10, 2, 2, 4, 0), (11, 3, 2, 4, 0),
        (12, 0, 3, 1, 0), (13, 1, 3, 1, 0), (14, 2, 3, 1, 0), (15, 3, 3, 1, 0),
        (16, 0, 4, 4, 0), (17, 1, 4, 4, 0), (18, 2, 4, 4, 0), (19, 3, 4, 4, 0),
        (20, 0, 5, 2, 1), (21, 1, 5, 2, 0), (22, 2, 5, 2, 1), (23, 3, 5, 2, 0),
        (24, 0, 6, 2, 0), (25, 1, 6, 2, 0), (26, 2, 6, 2, 0), (27, 3, 6, 2, 0),
    ].map { OriginalMarketLayoutEntry(index: $0.0, x: $0.1, y: $0.2, kind: $0.3, aux: $0.4) }

    private static let grandLayoutEntries: [OriginalMarketLayoutEntry] = [
        (0, 0, 0, 2, 1), (1, 1, 0, 2, 0), (2, 2, 0, 2, 1), (3, 3, 0, 2, 0),
        (4, 4, 0, 2, 1), (5, 5, 0, 2, 0), (6, 0, 1, 2, 0), (7, 1, 1, 2, 0),
        (8, 2, 1, 2, 0), (9, 3, 1, 2, 0), (10, 4, 1, 2, 0), (11, 5, 1, 2, 0),
        (12, 0, 2, 4, 112), (13, 1, 2, 4, 113), (14, 2, 2, 4, 130), (15, 3, 2, 4, 131),
        (16, 4, 2, 4, 114), (17, 5, 2, 4, 115), (18, 0, 3, 1, 116), (19, 1, 3, 1, 117),
        (20, 2, 3, 1, 132), (21, 3, 3, 1, 133), (22, 4, 3, 1, 118), (23, 5, 3, 1, 119),
        (24, 0, 4, 4, 120), (25, 1, 4, 4, 121), (26, 2, 4, 4, 134), (27, 3, 4, 4, 135),
        (28, 4, 4, 4, 122), (29, 5, 4, 4, 123), (30, 0, 5, 2, 1), (31, 1, 5, 2, 0),
        (32, 2, 5, 2, 1), (33, 3, 5, 2, 0), (34, 4, 5, 2, 1), (35, 5, 5, 2, 0),
        (36, 0, 6, 2, 0), (37, 1, 6, 2, 0), (38, 2, 6, 2, 0), (39, 3, 6, 2, 0),
        (40, 4, 6, 2, 0), (41, 5, 6, 2, 0),
    ].map { OriginalMarketLayoutEntry(index: $0.0, x: $0.1, y: $0.2, kind: $0.3, aux: $0.4) }
}

/// The runtime slot/object links written by the market placement allocator.
///
/// `FUN_005428B0 @ 0x5428B0` assigns a compact ordinal to each active helper
/// entry and stores the placeholder object's registry ID in
/// `market+0x15C[ordinal]`; `FUN_00540E70 @ 0x540E70` preserves that ordinal
/// when the clicked placeholder is replaced by a selected shop.  This value
/// is therefore an explicit-input binding of an already-created placeholder,
/// not a guess that the static `DAT_008572E8` row index names a bay.
public struct OriginalMarketRuntimeShopSlot: Sendable, Hashable, Codable {
    public let marketRegistryID: Int
    public let runtimeSlot: Int
    public let layoutEntryIndex: Int
    public let shopRegistryID: Int
    public let shopBuildingID: Int
    /// Raw model-data capacity written by `FUN_00540F80`; `nil` is the empty
    /// placeholder model (`0x3E`), which has no selected table row yet.
    public let rawCapacityDelta: Int?

    public init(
        marketRegistryID: Int,
        runtimeSlot: Int,
        layoutEntryIndex: Int,
        shopRegistryID: Int,
        shopBuildingID: Int,
        rawCapacityDelta: Int?
    ) {
        self.marketRegistryID = marketRegistryID
        self.runtimeSlot = runtimeSlot
        self.layoutEntryIndex = layoutEntryIndex
        self.shopRegistryID = shopRegistryID
        self.shopBuildingID = shopBuildingID
        self.rawCapacityDelta = rawCapacityDelta
    }
}

public enum OriginalMarketRuntimeShopBinding {
    public static let emptyShopBuildingID = 62

    /// Binds the supplied, coordinate-selected placeholder objects in the
    /// allocator's active-entry order. Both arrays must contain exactly one
    /// object per active bay; malformed or out-of-family model IDs return
    /// `nil` rather than inventing a row-to-bay permutation.
    public static func bind(
        marketRegistryID: Int,
        layout: OriginalMarketLayoutDescriptor,
        shopBuildingIDs: [Int],
        shopRegistryIDs: [Int]
    ) -> [OriginalMarketRuntimeShopSlot]? {
        guard shopBuildingIDs.count == layout.activeBayCount,
              shopRegistryIDs.count == layout.activeBayCount,
              shopBuildingIDs.allSatisfy({
                  $0 == emptyShopBuildingID || (64...70).contains($0)
              }) else {
            return nil
        }

        return zip(shopBuildingIDs, shopRegistryIDs).enumerated().map { ordinal, pair in
            let (shopBuildingID, shopRegistryID) = pair
            return OriginalMarketRuntimeShopSlot(
                marketRegistryID: marketRegistryID,
                runtimeSlot: ordinal,
                layoutEntryIndex: layout.activeLayoutEntryIndices[ordinal],
                shopRegistryID: shopRegistryID,
                shopBuildingID: shopBuildingID,
                rawCapacityDelta: rawCapacityDelta(forShopBuildingID: shopBuildingID)
            )
        }
    }

    /// The raw 400/800 value selected by the shop table's `+0x18` flag.
    /// Empty placeholders do not select a `DAT_008572E8` row and return `nil`.
    public static func rawCapacityDelta(forShopBuildingID shopBuildingID: Int) -> Int? {
        guard shopBuildingID != emptyShopBuildingID else { return nil }
        return OriginalMarketProviderSlotCatalog
            .entry(forShopBuildingID: shopBuildingID)?.placementCapacity
    }

    /// Mirrors the selected-record removal arithmetic in
    /// `FUN_00544B30 @ 0x544B30` for a valid non-negative raw quantity word.
    /// The executable subtracts the same 400/800 value used at placement and
    /// clamps the result at zero. This remains a raw record helper; it does
    /// not identify Native inventory or enable market settlement.
    public static func rawQuantityAfterRemoval(
        currentRawQuantity: Int,
        shopBuildingID: Int
    ) -> Int? {
        guard currentRawQuantity >= 0,
              let delta = rawCapacityDelta(forShopBuildingID: shopBuildingID) else {
            return nil
        }
        return max(0, currentRawQuantity - delta)
    }
}

/// The requirement-index and threshold tables read by the original
/// residential commodity predicate (`FUN_00588CB0 @ 0x588CB0`). These are
/// copied from the hash-matched English/Chinese PE data at
/// `DAT_0085C334`, `DAT_0085C34C`, and `DAT_0085C3DC`; they are intentionally
/// exposed as a pure lookup and are not wired to Native house evolution until
/// the cHouseInfo quantity lifecycle is recovered.
public enum OriginalResidentialRequirementTable {
    /// `DAT_0085C334[requirementIndex]`; index zero is handled by the
    /// executable's separate `FUN_00519D40` branch and has no commodity ID.
    public static func commodityID(forRequirementIndex requirementIndex: Int) -> Int? {
        switch requirementIndex {
        case 1: return 0x13 // Hemp
        case 2: return 0x19 // Ceramics
        case 3: return 0x0D // Tea
        case 4: return 0x18 // Silk
        case 5: return 0x16 // Lacquerware; 0x17 is checked as an alternative
        default: return nil
        }
    }

    /// Returns the table value selected by the executable's building-ID
    /// split. Non-elite rows (IDs 2…10) have four columns; elite rows
    /// (IDs 13…17) have six. IDs 11 and 12 are the unoccupied/abandoned elite
    /// rows and use the same elite table with the source's clamped row index.
    /// Inputs outside the residential model domain return `nil`.
    public static func threshold(buildingID: Int, requirementIndex: Int) -> Int? {
        guard (2...17).contains(buildingID) else { return nil }
        if (11...17).contains(buildingID) {
            guard (0..<6).contains(requirementIndex) else { return nil }
            let row: [[Int]] = [
                [1, 2, 2, 0, 0, 0],
                [2, 2, 2, 0, 0, 0],
                [4, 2, 2, 0, 0, 2],
                [5, 2, 2, 0, 2, 2],
                [5, 2, 2, 2, 2, 2],
            ]
            return row[min(max(buildingID - 13, 0), row.count - 1)][requirementIndex]
        }

        guard (0..<4).contains(requirementIndex) else { return nil }
        let row: [[Int]] = [
            [2, 0, 0, 0],
            [5, 0, 0, 0],
            [7, 2, 0, 0],
            [10, 2, 0, 0],
            [12, 2, 0, 0],
            [15, 2, 0, 0],
            [20, 2, 2, 0],
            [20, 2, 3, 0],
            [20, 2, 3, 2],
        ]
        return row[min(max(buildingID - 2, 0), row.count - 1)][requirementIndex]
    }
}

/// Raw result of the elite-house stock consumer at `FUN_005F05D0`.
///
/// The executable iterates seven logical passes in the order
/// Silk/Hemp/Ceramics/Tea/Bronzeware/Lacquerware/Dinners and addresses the
/// corresponding `cHouseInfo` words through `DAT_00875CA8`. This projection
/// preserves that pass order while returning the updated raw words by
/// cHouseInfo slot. It deliberately omits the executable's object-state and
/// global-counter writes; the caller/scheduler and Native quantity lifecycle
/// are still unresolved, so this is research-only and is not used by live
/// housing evolution.
public struct OriginalEliteHouseStockConsumptionResult: Sendable, Hashable {
    /// Updated raw `cHouseInfo` words, indexed by slot 0…6.
    public let stockByHouseInfoSlot: [Int]
    /// Per-pass shortage left in the consumer's local target after a word is
    /// cleared. A zero entry means the pass had enough stock.
    public let deficitByPass: [Int]
    /// Per-pass amount selected for subtraction/clearing, after the signed
    /// divide-by-four operation and current-stock quotient adjustment.
    public let selectedAmountByPass: [Int]

    public init(
        stockByHouseInfoSlot: [Int],
        deficitByPass: [Int],
        selectedAmountByPass: [Int]
    ) {
        self.stockByHouseInfoSlot = stockByHouseInfoSlot
        self.deficitByPass = deficitByPass
        self.selectedAmountByPass = selectedAmountByPass
    }
}

public enum OriginalEliteHouseStockConsumption {
    /// `DAT_00875CA8`, decoded as cHouseInfo slots for the seven passes.
    public static let houseInfoSlotByPass = [3, 1, 2, 6, 4, 5, 0]

    /// The zero-based `ALL HOUSES` field positions read by `FUN_005F05D0`
    /// for IDs 13…17. Luxury ware is intentionally read twice: pass 4 checks
    /// bronzeware and pass 5 checks lacquerware even though both use field 13.
    public static let modelFieldIndexByPass = [12, 9, 10, 11, 13, 13, 17]

    /// Replays the raw seven-pass mutation for an occupied elite house
    /// (`buildingID` 12…17, excluding special ID 11). Native's
    /// `HouseModel.id` is the zero-based house-level row, so it must equal
    /// `buildingID - 3` (the executable
    /// building-ID projection used by `CitySimulation`). The `residentCount`
    /// argument is the value
    /// returned by the house vtable's `+0x21c` method (`FUN_00519D40`), not the
    /// model's population capacity. The supplied stock words are raw values
    /// before the consumer runs and must be in cHouseInfo slot order 0…6.
    ///
    /// ID 11 is intentionally unsupported: the source has a special literal
    /// target array whose seventh local is not initialized in the recovered
    /// body. ID 12 follows the generic model-field branch and is supported.
    public static func consume(
        buildingID: Int,
        model: HouseModel,
        residentCount: Int,
        stockByHouseInfoSlot: [Int]
    ) -> OriginalEliteHouseStockConsumptionResult? {
        guard (12...17).contains(buildingID), buildingID != 11,
              model.id == buildingID - 3,
              stockByHouseInfoSlot.count == 7 else {
            return nil
        }

        // The executable doubles each model field, then applies the signed
        // divide-by-four expression during the pass. For non-negative values
        // this is truncation toward zero; the sign correction only preserves
        // C's truncation behavior for negative values.
        var doubledTargets = [
            model.silkRequired,
            model.hempRequired,
            model.ceramicsRequired,
            model.teaRequired,
            model.luxuryWareRequired,
            model.luxuryWareRequired,
            model.populationCapacity,
        ].map { $0 * 2 }

        // The dinner/capacity target is raised to the current resident count
        // when its divided doubled model target is smaller than the resident
        // quotient by four.
        let residentQuotient = signedDivideBy4(residentCount)
        if signedDivideBy4(doubledTargets[6]) < residentQuotient {
            doubledTargets[6] = residentCount
        }

        var updated = stockByHouseInfoSlot
        var deficits = Array(repeating: 0, count: 7)
        var selected = Array(repeating: 0, count: 7)

        for pass in 0..<7 {
            let slot = houseInfoSlotByPass[pass]
            var amount = signedDivideBy4(doubledTargets[pass])
            if pass < 6 {
                // The source raises each non-Dinners target to the current
                // stock's signed quotient by four before subtracting it.
                amount = max(amount, signedDivideBy4(updated[slot]))
            }
            selected[pass] = amount

            if updated[slot] < amount {
                deficits[pass] = amount - updated[slot]
                updated[slot] = 0
            } else {
                updated[slot] -= amount
            }
        }

        return OriginalEliteHouseStockConsumptionResult(
            stockByHouseInfoSlot: updated,
            deficitByPass: deficits,
            selectedAmountByPass: selected
        )
    }

    private static func signedDivideBy4(_ value: Int) -> Int {
        // Matches `(value + (value >> 31 & 3)) >> 2` in the 32-bit PE.
        (value + ((value >> 31) & 3)) >> 2
    }
}

/// The coordinate selected by the original model-23 market spawn helper
/// (`FUN_00544910` -> `FUN_00543160`).  The helper scans the authored market
/// entrance table from record 3 and stops after the third `kind == 1` record;
/// all four common/grand-market banks therefore select the `(3, 3)` record.
///
/// This is deliberately a record-level selector only.  The executable's
/// subsequent route/collision consumer and the meaning of the selected point
/// relative to Native's road-access point remain unresolved.
public struct OriginalMarketPeddlerSpawnSelection: Sendable, Hashable {
    public let marketBuildingID: Int
    public let orientationBank: Int
    public let selectedRecordIndex: Int
    public let offset: GridPoint

    public init(
        marketBuildingID: Int,
        orientationBank: Int,
        selectedRecordIndex: Int,
        offset: GridPoint
    ) {
        self.marketBuildingID = marketBuildingID
        self.orientationBank = orientationBank
        self.selectedRecordIndex = selectedRecordIndex
        self.offset = offset
    }
}

public enum OriginalMarketPeddlerSpawnSelector {
    public static let commonMarketBuildingID = 59
    public static let grandMarketBuildingID = 60

    /// Returns the exact table record selected by `FUN_00543160` for a
    /// common (59) or grand (60) market and orientation bank 0 or 1.
    /// `nil` represents an input outside the recovered helper domain.
    public static func select(
        marketBuildingID: Int,
        orientationBank: Int
    ) -> OriginalMarketPeddlerSpawnSelection? {
        guard (marketBuildingID == commonMarketBuildingID
            || marketBuildingID == grandMarketBuildingID),
            (0...1).contains(orientationBank) else {
            return nil
        }

        // Common bank 0 has record 15; grand bank 0 has record 21.  Bank 1
        // is the transposed table, but the same scan still lands on (3, 3).
        let recordIndex = marketBuildingID == commonMarketBuildingID ? 15 : 21
        return .init(
            marketBuildingID: marketBuildingID,
            orientationBank: orientationBank,
            selectedRecordIndex: recordIndex,
            offset: GridPoint(x: 3, y: 3)
        )
    }

    /// Adds the recovered table offset to the market object's map origin.
    /// This does not assert that the origin is a Native road-access point.
    public static func point(
        marketOrigin: GridPoint,
        marketBuildingID: Int,
        orientationBank: Int
    ) -> GridPoint? {
        guard let selection = select(
            marketBuildingID: marketBuildingID,
            orientationBank: orientationBank
        ) else { return nil }
        return GridPoint(
            x: marketOrigin.x + selection.offset.x,
            y: marketOrigin.y + selection.offset.y
        )
    }
}

public enum OriginalMarketProviderAvailability {
    /// Reproduces `FUN_005D4AC0 @ 0x5D4AC0` after the cMarket provider
    /// container has yielded its contiguous records. Null/empty containers
    /// naturally return zero. This is a pure primitive and deliberately does
    /// not claim that `rawField4/rawField8` are Native commodity quantities.
    public static func total(
        records: some Collection<OriginalMarketProviderRecord>
    ) -> Int {
        records.reduce(into: 0) { total, record in
            guard record.rawField4 != 0 || record.rawField8 != 0 else { return }
            total += record.rawField8
        }
    }
}

/// One child slot considered by the original cMarket `+0x1B8` aggregate
/// (`FUN_00544EC0 @ 0x544EC0`).  The executable visits exactly six slots,
/// ignores null/inactive entries, and admits a child only when its vtable
/// `+0xC8(-1)` predicate is true.  `workerValue` is the already-resolved
/// child `+0x1B8` result; its semantic owner is not recovered, so this
/// projection must not be populated from Native workforce or inventory.
public struct OriginalMarketWorkerAggregateEntry: Sendable, Hashable, Codable {
    public let isActive: Bool
    public let passesSelectorMinusOne: Bool
    public let workerValue: Int

    public init(
        isActive: Bool,
        passesSelectorMinusOne: Bool,
        workerValue: Int
    ) {
        self.isActive = isActive
        self.passesSelectorMinusOne = passesSelectorMinusOne
        self.workerValue = workerValue
    }
}

/// Pure six-slot aggregate used by the original cMarket refill gate.  The
/// fixed slot count is part of the executable contract; extra entries are
/// rejected instead of silently changing the traversal domain.
public enum OriginalMarketWorkerAggregate {
    public static let slotCount = 6
    public static let selector = -1

    public static func total(
        entries: [OriginalMarketWorkerAggregateEntry]
    ) -> Int? {
        guard entries.count <= slotCount else { return nil }
        return entries.reduce(into: 0) { total, entry in
            guard entry.isActive, entry.passesSelectorMinusOne else { return }
            total += entry.workerValue
        }
    }
}

/// The raw per-resource score prepared by cMarket `+0x26C`
/// (`0x5D4B10`) before it asks the map/route selector to choose a candidate
/// point. This is deliberately a score primitive, not a Native market
/// quality or inventory value.
public enum OriginalMarketProviderSelectionScore {
    /// Reproduces the score write for one resource-index entry. The
    /// executable starts every entry at `100`; only a state byte of `2`, a
    /// positive cMarket `+0x25C` acceptance result, a quantity below the
    /// authored capacity, and a nonzero resource index replace it with
    /// `quantity * 100 / capacity` using signed integer division.
    ///
    /// `nil` represents the invalid zero-capacity divisor that the original
    /// caller's authored tables are expected to prevent. This helper is
    /// research-only and is not wired to Qin market settlement or route
    /// selection.
    public static func score(
        resourceIndex: Int,
        state: Int,
        keyAccepted: Bool,
        quantity: Int,
        capacity: Int
    ) -> Int? {
        guard resourceIndex > 0,
              state == 2,
              keyAccepted,
              quantity < capacity else {
            return 100
        }
        guard capacity != 0 else { return nil }
        return (quantity * 100) / capacity
    }
}

/// The cMarket `+0x25C` readiness predicate (`FUN_005D4900`). The caller
/// supplies values read from the selected provider container: the slot count,
/// the number of records for which `FUN_004B04F0` returned false, the matching
/// quantity from `+0x264`, and the authored capacity word. This is a raw
/// admission gate only; it does not identify a Native provider or market
/// settlement path.
public enum OriginalMarketProviderKeyAvailability {
    /// Returns the executable's boolean result. The first clause admits a
    /// partially empty provider container or any quantity not divisible by
    /// `400`; the second requires quantity to remain strictly below capacity.
    public static func isAvailable(
        recordCount: Int,
        nonEmptyRecordCount: Int,
        quantity: Int,
        capacity: Int
    ) -> Bool {
        ((quantity % 400) != 0 || nonEmptyRecordCount != recordCount)
            && quantity < capacity
    }
}

/// One ordered cell considered by the original peddler endpoint scan
/// (`FUN_004BA370`). The caller supplies the result of the object vtable
/// `+0xD0` adjustment, the post-adjustment low terrain flags, and the rank of
/// the cell's component in `DAT_01312588`. A missing component-table entry is
/// represented by `nil`, which preserves the executable's rank-11 sentinel.
/// The `+0xD0` return value is not an admission gate in `FUN_004BA370`; the
/// caller supplies the point after any callback-written adjustment. (The
/// neighboring `FUN_004BAF40` has a distinct return-value gate and must not
/// be conflated with this scan.)
public struct OriginalMarketPeddlerEndpointCandidate: Sendable, Hashable, Codable {
    public let rawPoint: GridPoint
    public let adjustedPoint: GridPoint?
    public let terrainFlags: UInt32
    public let componentRank: Int?

    public init(
        rawPoint: GridPoint,
        adjustedPoint: GridPoint? = nil,
        terrainFlags: UInt32,
        componentRank: Int? = nil
    ) {
        self.rawPoint = rawPoint
        self.adjustedPoint = adjustedPoint
        self.terrainFlags = terrainFlags
        self.componentRank = componentRank
    }
}

/// Ordered rectangular cells visited by the original peddler endpoint scan
/// (`FUN_004BA370`). The executable receives the square span from the cMarket
/// object and expands it by the caller-supplied rotation before clamping to
/// the map. This helper deliberately takes that span as an explicit input:
/// the meaning of cMarket `+0x1C` is not yet mapped to Native footprint data.
public enum OriginalMarketPeddlerEndpointScan {
    /// Returns the source's row-major scan order (y ascending, then x
    /// ascending) for one rotation attempt. A clamped rectangle with no cells
    /// returns an empty array. Invalid map dimensions or a negative rotation
    /// are outside the `FUN_004BA580` caller domain and return `nil`.
    public static func rectangularPoints(
        anchor: GridPoint,
        scanSpan: Int,
        rotation: Int,
        mapWidth: Int,
        mapHeight: Int
    ) -> [GridPoint]? {
        guard mapWidth > 0, mapHeight > 0, rotation >= 0 else { return nil }

        let xStart = max(0, anchor.x - rotation)
        let xEnd = min(mapWidth - 1, anchor.x + scanSpan - 1 + rotation)
        let yStart = max(0, anchor.y - rotation)
        let yEnd = min(mapHeight - 1, anchor.y + scanSpan - 1 + rotation)
        guard xStart <= xEnd, yStart <= yEnd else { return [] }

        return (yStart...yEnd).flatMap { y in
            (xStart...xEnd).map { x in GridPoint(x: x, y: y) }
        }
    }
}

/// The endpoint arbitration performed by `FUN_004BA370` after its caller has
/// produced the ordered rectangular scan. This is deliberately separate from
/// route construction: it selects the first lowest component rank, applies
/// no household targeting, and returns `nil` when every candidate is rejected.
public enum OriginalMarketPeddlerEndpointSelection {
    /// Preserves the source's strict rank comparison and table-order ties.
    /// The source accepts ranks `0...11`; `11` is also the explicit sentinel
    /// for a component absent from the twelve-entry priority table.
    public static func select(
        _ candidates: [OriginalMarketPeddlerEndpointCandidate]
    ) -> GridPoint? {
        var selected: (point: GridPoint, rank: Int)?
        for candidate in candidates {
            guard candidate.terrainFlags & 0x40 == 0x40,
                  candidate.terrainFlags & 0x04 == 0 else { continue }
            let rank = candidate.componentRank ?? 11
            guard rank >= 0, rank < 12 else { continue }
            let point = candidate.adjustedPoint ?? candidate.rawPoint
            if selected == nil || rank < selected!.rank {
                selected = (point, rank)
            }
        }
        return selected?.point
    }
}

/// Route-search inputs used by a model-23 peddler after construction.
/// `FUN_004C71D0` → `FUN_004C72B0` clears figure `+0x80`, and the model-23
/// initializer `FUN_004C9160` does not replace it. Consequently the first
/// `FUN_004E83E0` dispatch uses mode zero (`FUN_005AE740`), which seeds the
/// current map cell and expands four cardinal neighbours through
/// `FUN_005AE840`. This descriptor records the search primitive only; the PE
/// layer projection, collision rejection, endpoint consumer, and peddler
/// settlement remain unresolved, so it is not a campaign route bridge.
public struct OriginalMarketPeddlerRouteSearchDescriptor: Sendable, Hashable, Codable {
    public let figureConstructorAddress: UInt32
    public let figureInitializerAddress: UInt32
    public let routeDispatchAddress: UInt32
    public let routeMode: Int
    public let routeSearchAddress: UInt32
    public let neighbourExpansionAddress: UInt32
    public let searchResetAddress: UInt32
    public let traversableMask: UInt16
    public let mapStride: Int
    public let queueCapacity: Int

    public init(
        figureConstructorAddress: UInt32,
        figureInitializerAddress: UInt32,
        routeDispatchAddress: UInt32,
        routeMode: Int,
        routeSearchAddress: UInt32,
        neighbourExpansionAddress: UInt32,
        searchResetAddress: UInt32,
        traversableMask: UInt16,
        mapStride: Int,
        queueCapacity: Int
    ) {
        self.figureConstructorAddress = figureConstructorAddress
        self.figureInitializerAddress = figureInitializerAddress
        self.routeDispatchAddress = routeDispatchAddress
        self.routeMode = routeMode
        self.routeSearchAddress = routeSearchAddress
        self.neighbourExpansionAddress = neighbourExpansionAddress
        self.searchResetAddress = searchResetAddress
        self.traversableMask = traversableMask
        self.mapStride = mapStride
        self.queueCapacity = queueCapacity
    }

    /// Canonical English-build addresses, with the route body cross-checked
    /// against the Chinese executable (`identical` at `0x5AE740`).
    public static let canonical = Self(
        figureConstructorAddress: 0x004C71D0,
        figureInitializerAddress: 0x004C9160,
        routeDispatchAddress: 0x004E83E0,
        routeMode: 0,
        routeSearchAddress: 0x005AE740,
        neighbourExpansionAddress: 0x005AE840,
        searchResetAddress: 0x00521140,
        traversableMask: 0x0B1D,
        mapStride: 0xE4,
        queueCapacity: 0xCB10
    )
}

/// One record returned by the cMarket helper's virtual `+0x70` accessor.
/// These are authored relative map offsets used by `FUN_00542350`'s nearest
/// record reducer; they are not a Native route or a player-facing entrance
/// classification.
public struct OriginalMarketPeddlerHelperRecord: Sendable, Hashable, Codable {
    public let offset: GridPoint

    public init(offset: GridPoint) {
        self.offset = offset
    }
}

/// Static cMarket helper records used by `FUN_00544EA0` → `FUN_00542350`.
/// The executable exposes two records per orientation bank (`0` or `1`):
/// Common Market `(0,3),(3,3)` / `(3,0),(3,3)` and Grand Market
/// `(0,3),(5,3)` / `(3,0),(3,5)`. The catalog is research-only; callers must
/// still recover the runtime helper instance and downstream route consumer.
public enum OriginalMarketPeddlerHelperRecordCatalog {
    public static func records(
        forMarketBuildingID buildingID: Int,
        orientationBank: Int
    ) -> [OriginalMarketPeddlerHelperRecord]? {
        guard orientationBank == 0 || orientationBank == 1 else { return nil }
        switch (buildingID, orientationBank) {
        case (OriginalMarketCatalog.commonMarketBuildingID, 0):
            return [
                .init(offset: GridPoint(x: 0, y: 3)),
                .init(offset: GridPoint(x: 3, y: 3))
            ]
        case (OriginalMarketCatalog.commonMarketBuildingID, 1):
            return [
                .init(offset: GridPoint(x: 3, y: 0)),
                .init(offset: GridPoint(x: 3, y: 3))
            ]
        case (OriginalMarketCatalog.grandMarketBuildingID, 0):
            return [
                .init(offset: GridPoint(x: 0, y: 3)),
                .init(offset: GridPoint(x: 5, y: 3))
            ]
        case (OriginalMarketCatalog.grandMarketBuildingID, 1):
            return [
                .init(offset: GridPoint(x: 3, y: 0)),
                .init(offset: GridPoint(x: 3, y: 5))
            ]
        default:
            return nil
        }
    }

    /// Applies the executable's strict Manhattan nearest-record reduction.
    /// Equal distances retain stored record order; an empty record list
    /// returns the original target, matching `FUN_00542350`.
    public static func nearestTarget(
        target: GridPoint,
        marketOrigin: GridPoint,
        marketBuildingID: Int,
        orientationBank: Int
    ) -> GridPoint? {
        guard let records = records(
            forMarketBuildingID: marketBuildingID,
            orientationBank: orientationBank
        ) else { return nil }
        guard !records.isEmpty else { return target }

        var selected = target
        var bestDistance = Int.max
        for record in records {
            let point = GridPoint(
                x: marketOrigin.x + record.offset.x,
                y: marketOrigin.y + record.offset.y
            )
            let distance = abs(target.x - point.x) + abs(target.y - point.y)
            if distance < bestDistance {
                bestDistance = distance
                selected = point
            }
        }
        return selected
    }
}

/// The statically recovered callback chain used when a market-owned figure
/// crosses a nearby object.  `FUN_004EACD0` first dispatches the figure's
/// home object through `+0x28`; for a cMarket home this is
/// `FUN_00429DF0`, which forwards to the Chebyshev scan
/// `FUN_00429E10` with radius 2.  The scan then invokes the cMarket
/// `+0x2C` callback (`FUN_005437B0`) for each admitted house.
///
/// This descriptor records dispatch evidence only.  It does not provide the
/// provider-record source, collision/rejection route state, or the complete
/// set of market writers, so it must not be used as a live Qin settlement
/// bridge.
public struct OriginalMarketPeddlerCoverageDispatch: Sendable, Hashable, Codable {
    public let crossingFunctionAddress: UInt32
    public let marketRadiusWrapperAddress: UInt32
    public let radiusScanAddress: UInt32
    public let marketVTableAddress: UInt32
    public let marketRadiusVTableOffset: UInt32
    public let marketWriterVTableOffset: UInt32
    public let radius: Int
    public let writerAddress: UInt32

    public init(
        crossingFunctionAddress: UInt32,
        marketRadiusWrapperAddress: UInt32,
        radiusScanAddress: UInt32,
        marketVTableAddress: UInt32,
        marketRadiusVTableOffset: UInt32,
        marketWriterVTableOffset: UInt32,
        radius: Int,
        writerAddress: UInt32
    ) {
        self.crossingFunctionAddress = crossingFunctionAddress
        self.marketRadiusWrapperAddress = marketRadiusWrapperAddress
        self.radiusScanAddress = radiusScanAddress
        self.marketVTableAddress = marketVTableAddress
        self.marketRadiusVTableOffset = marketRadiusVTableOffset
        self.marketWriterVTableOffset = marketWriterVTableOffset
        self.radius = radius
        self.writerAddress = writerAddress
    }

    /// Canonical English-build addresses, cross-checked against the Chinese
    /// executable where the split corpus marks the shared functions
    /// `identical`. The unsplit writer range is byte-identical in both PE
    /// files even though it has no `functions-index.csv` row.
    public static let canonical = Self(
        crossingFunctionAddress: 0x004EACD0,
        marketRadiusWrapperAddress: 0x00429DF0,
        radiusScanAddress: 0x00429E10,
        marketVTableAddress: 0x007B6F3C,
        marketRadiusVTableOffset: 0x28,
        marketWriterVTableOffset: 0x2C,
        radius: 2,
        writerAddress: 0x005437B0
    )
}

/// The early-return predicate used by the original peddler roam handler
/// (`FUN_004E3A10 @ 0x4E3A10`).  This is deliberately a pure state boundary:
/// the caller still has to select the provider/market endpoint and build the
/// return route after the predicate succeeds.
public enum OriginalMarketPeddlerReturnGate {
    /// Figure model bytes exempt from the normal `4/5` budget gate in the
    /// hash-matched executable.  The decompiler renders these bytes as `%`
    /// (`0x25`) and `O` (`0x4F`).
    public static let percentModelID = 0x25
    public static let letterOModelID = 0x4F

    /// Returns true exactly when `FUN_004E3A10` allows the peddler to begin
    /// its provider/market return request.  The executable compares the
    /// signed `behaviorRange * 4 / 5` quotient against the signed travelled
    /// budget and requires both coordinate pairs to match.
    public static func shouldReturn(
        modelID: Int,
        traveledBudget: Int,
        behaviorRange: Int,
        currentPoint: GridPoint,
        savedPoint: GridPoint
    ) -> Bool {
        guard modelID != percentModelID,
              modelID != letterOModelID else {
            return false
        }
        // The PE reads the stored word as an `int16_t` before widening it.
        let signedRange = Int(Int16(truncatingIfNeeded: behaviorRange))
        let (scaledRange, overflow) = signedRange.multipliedReportingOverflow(by: 4)
        guard !overflow else { return false }
        return scaledRange / 5 <= traveledBudget && currentPoint == savedPoint
    }
}

/// Return-route dispatch and state writes recovered from
/// `FUN_004E3A80 @ 0x4E3A80`. A peddler whose linked object has class word
/// `0x3B` or `0x3C` (Common/Grand Market) asks `FUN_00544910` for the market
/// entrance target; other linked objects use their virtual `+0x19C` endpoint
/// method. Both paths then call `FUN_004BA580(..., 2)`, which attempts scan
/// rotations `0…2`. This is a state/dispatch descriptor only: the endpoint
/// callback's native meaning, PE layer projection, collision rejection, and
/// provider/house settlement are still unresolved.
public struct OriginalMarketPeddlerReturnRouteDescriptor: Sendable, Hashable, Codable {
    public let roamHandlerAddress: UInt32
    public let returnGateAddress: UInt32
    public let routeRetryAddress: UInt32
    public let marketEndpointSelectorAddress: UInt32
    public let routeClearAddress: UInt32
    public let marketClassWords: [Int]
    public let retryMaximumRotation: Int
    public let successFigureState: Int
    public let targetXOffset: UInt32
    public let targetYOffset: UInt32
    public let travelledBudgetOffset: UInt32

    public init(
        roamHandlerAddress: UInt32,
        returnGateAddress: UInt32,
        routeRetryAddress: UInt32,
        marketEndpointSelectorAddress: UInt32,
        routeClearAddress: UInt32,
        marketClassWords: [Int],
        retryMaximumRotation: Int,
        successFigureState: Int,
        targetXOffset: UInt32,
        targetYOffset: UInt32,
        travelledBudgetOffset: UInt32
    ) {
        self.roamHandlerAddress = roamHandlerAddress
        self.returnGateAddress = returnGateAddress
        self.routeRetryAddress = routeRetryAddress
        self.marketEndpointSelectorAddress = marketEndpointSelectorAddress
        self.routeClearAddress = routeClearAddress
        self.marketClassWords = marketClassWords
        self.retryMaximumRotation = retryMaximumRotation
        self.successFigureState = successFigureState
        self.targetXOffset = targetXOffset
        self.targetYOffset = targetYOffset
        self.travelledBudgetOffset = travelledBudgetOffset
    }

    public static let canonical = Self(
        roamHandlerAddress: 0x004E3A80,
        returnGateAddress: 0x004E3A10,
        routeRetryAddress: 0x004BA580,
        marketEndpointSelectorAddress: 0x00544910,
        routeClearAddress: 0x004E8A30,
        marketClassWords: [0x3B, 0x3C],
        retryMaximumRotation: 2,
        successFigureState: 2,
        targetXOffset: 0x2C,
        targetYOffset: 0x2E,
        travelledBudgetOffset: 0x4C
    )

    /// Selects only the endpoint-dispatch branch recovered in the PE. The
    /// non-market result deliberately does not invent the virtual callback's
    /// returned coordinates.
    public static func usesMarketEntrance(forLinkedObjectClassWord value: Int) -> Bool {
        canonical.marketClassWords.contains(value)
    }
}

/// The post-selection projection emitted by cMarket's `FUN_00543DC0
/// @ 0x543DC0`. The executable has already selected a linear map cell through
/// the receiver's vtable `+0x194`; this value therefore does not attempt to
/// recover that selector or the cache byte that feeds the callback. The
/// callback target itself is the tiny raw setter `FUN_00427410 @ 0x427410`,
/// which writes the supplied byte to cMarket's backing object at `+0x18`.
public struct OriginalMarketAccessRefreshProjection: Sendable, Hashable, Codable {
    public let selectedLinearIndex: Int
    public let mapPoint: GridPoint
    public let callbackInput: UInt8
    public let floodValue: Int

    /// The source returns the stored flood/cache word as a boolean result.
    public var isReachable: Bool { floodValue != 0 }

    public init(
        selectedLinearIndex: Int,
        mapPoint: GridPoint,
        callbackInput: UInt8,
        floodValue: Int
    ) {
        self.selectedLinearIndex = selectedLinearIndex
        self.mapPoint = mapPoint
        self.callbackInput = callbackInput
        self.floodValue = floodValue
    }
}

/// Pure arithmetic for the cMarket access/flood refresh writer. `mapBase`
/// corresponds to `DAT_0101D0C8`, `mapRowStride` is the executable's linear
/// row width (`0xE4` in the canonical build), and `callbackInput` is the byte
/// passed to the receiver vtable `+0x1AC`. The callback writes that byte to the
/// market backing object at `+0x18`; object mutation remains outside this value
/// helper. Callers must supply the recovered input and the post-callback
/// flood/cache word (`DAT_01391FE0[selected]`).
public enum OriginalMarketAccessRefresh {
    /// cMarket vtable `0x7B6F3C` slot `+0x1AC` target.
    public static let callbackAddress: UInt32 = 0x00427410
    /// Destination field written by `FUN_00427410` on its cMarket receiver.
    public static let callbackDestinationOffset: Int = 0x18

    public static func project(
        selectedLinearIndex: Int,
        mapBaseLinearIndex: Int,
        mapRowStride: Int,
        callbackInput: UInt8,
        floodValue: Int
    ) -> OriginalMarketAccessRefreshProjection? {
        guard mapRowStride > 0,
              selectedLinearIndex >= mapBaseLinearIndex else {
            return nil
        }
        let offset = selectedLinearIndex - mapBaseLinearIndex
        return OriginalMarketAccessRefreshProjection(
            selectedLinearIndex: selectedLinearIndex,
            mapPoint: GridPoint(x: offset % mapRowStride, y: offset / mapRowStride),
            callbackInput: callbackInput,
            floodValue: floodValue
        )
    }
}

/// Raw cMarket provider-selection gate recovered from `FUN_00541220`.
/// `FUN_00427410` stores the selected component label at market/backing-object
/// `+0x18`; the selection tail continues only when that byte is `0` or `1`.
/// This is an admission predicate over the executable's raw labels, not a
/// semantic claim that either value means a particular market state.
public enum OriginalMarketProviderSelectionComponentGate {
    public static let destinationOffset: Int = 0x18
    public static let acceptedComponentLabels: Set<UInt8> = [0, 1]

    public static func accepts(componentLabel: UInt8) -> Bool {
        acceptedComponentLabels.contains(componentLabel)
    }
}

/// Shared four-direction cache flood used by the original candidate expanders
/// `FUN_005B0220` and `FUN_005B0360`. The PE clears its distance buffer,
/// seeds the start cell with `1`, then expands north/east/south/west. Each
/// direction reads the corresponding current-cell layer and admits it when
/// the layer word intersects the caller's mask; the candidate receives the
/// current value plus one.
///
/// The four layer arrays are explicit because their PE-to-Native projection
/// is not yet recovered. Each direction reads its layer at the current cell
/// before enqueuing the neighboring cell. This helper therefore records the
/// candidate-expander algorithm without manufacturing map layers, provider
/// objects, or settlement state.
public enum OriginalDirectionalAccessFlood {
    /// Mode-zero (`FUN_005B0220`) admission mask.
    public static let unweightedPassMask: UInt16 = 0x010C

    /// Nonzero-mode (`FUN_005B0360`) admission mask.
    public static let weightedPassMask: UInt16 = 0x0B0C

    /// Returns the rebuilt cache, with `0` for unreached cells and `1` at the
    /// seed. Invalid dimensions, layer shapes, or an out-of-map seed return
    /// `nil`. The source's fixed 228-cell row stride is represented by the
    /// caller's `width`; no hard-coded classic-map width is introduced here.
    public static func build(
        width: Int,
        height: Int,
        seed: GridPoint,
        passMask: UInt16,
        northLayer: [UInt16],
        eastLayer: [UInt16],
        southLayer: [UInt16],
        westLayer: [UInt16]
    ) -> [Int]? {
        guard width > 0,
              height > 0,
              northLayer.count == width * height,
              eastLayer.count == width * height,
              southLayer.count == width * height,
              westLayer.count == width * height,
              seed.x >= 0, seed.x < width,
              seed.y >= 0, seed.y < height else {
            return nil
        }

        func index(of point: GridPoint) -> Int {
            point.y * width + point.x
        }
        func contains(_ point: GridPoint) -> Bool {
            point.x >= 0 && point.x < width && point.y >= 0 && point.y < height
        }

        var cache = [Int](repeating: 0, count: width * height)
        var queue = [GridPoint](repeating: seed, count: width * height)
        let seedIndex = index(of: seed)
        cache[seedIndex] = 1
        queue[0] = seed
        var head = 0
        var tail = 1

        let directions: [(delta: GridPoint, layer: [UInt16])] = [
            (GridPoint(x: 0, y: -1), northLayer),
            (GridPoint(x: 1, y: 0), eastLayer),
            (GridPoint(x: 0, y: 1), southLayer),
            (GridPoint(x: -1, y: 0), westLayer),
        ]
        while head < tail {
            let current = queue[head]
            head += 1
            let currentDepth = cache[index(of: current)] + 1
            for direction in directions {
                let next = GridPoint(
                    x: current.x + direction.delta.x,
                    y: current.y + direction.delta.y
                )
                guard contains(next) else { continue }
                let nextIndex = index(of: next)
                guard cache[nextIndex] == 0,
                      direction.layer[index(of: current)] & passMask != 0 else { continue }
                cache[nextIndex] = currentDepth
                queue[tail] = next
                tail += 1
            }
        }
        return cache
    }
}

/// Address-level view of the original four directional routing layers.
///
/// `FUN_005AD440 @ 0x5AD440` writes one central 16-bit cache rooted at
/// `DAT_013789C0`.  The two candidate expanders do not consume four
/// independently-built arrays: `FUN_005B0220 @ 0x5B0220` and
/// `FUN_005B0360 @ 0x5B0360` read offset views at
/// `DAT_013787F8` (one row north), `DAT_013789C2` (one cell east),
/// `DAT_01378B88` (one row south), and `DAT_013789BE` (one cell west).
/// The recovered address deltas are `-0x1C8`, `+2`, `+0x1C8`, and `-2`;
/// `0x1C8 == 2 * 228` is the original 16-bit storage row stride.
///
/// This helper only exposes the pointer arithmetic.  It deliberately does
/// not derive the central cache from terrain/object state, because the
/// `FUN_005AD440` producer still depends on unresolved PE globals and live
/// object callbacks.  Callers must provide the already-derived padded cache.
public enum OriginalDirectionalLayerViews {
    public static let centralAddress: UInt32 = 0x013789C0
    public static let storageRowStride: Int = 228
    /// `FUN_005AD920` clears `0x6588` DWORDs, i.e. one 228×228 map of
    /// 16-bit cells (`0xCB10` cells, two bytes each).
    public static let storageCellCount: Int = 228 * 228
    public static let storageDWordCount: Int = 0x6588
    public static let northAddress: UInt32 = 0x013787F8
    public static let eastAddress: UInt32 = 0x013789C2
    public static let southAddress: UInt32 = 0x01378B88
    public static let westAddress: UInt32 = 0x013789BE
    public static let northCellOffset = -storageRowStride
    public static let eastCellOffset = 1
    public static let southCellOffset = storageRowStride
    public static let westCellOffset = -1

    public struct CellIndices: Sendable, Hashable, Codable {
        public let north: Int
        public let east: Int
        public let south: Int
        public let west: Int

        public init(north: Int, east: Int, south: Int, west: Int) {
            self.north = north
            self.east = east
            self.south = south
            self.west = west
        }
    }

    /// Directional aliases projected from a compact Native rectangle when the
    /// aliased cell is also present in that rectangle.  `nil` is intentional:
    /// the original cache is a centered 228×228 backing grid, while Native
    /// keeps only the authored mission rectangle.  A direction that crosses
    /// that rectangle's edge therefore has no source-backed value and must
    /// not be filled by wrapping, clamping, or a zero sentinel.
    public struct ActiveRectangleValues: Sendable, Hashable, Codable {
        public let width: Int
        public let height: Int
        public let north: [UInt16?]
        public let east: [UInt16?]
        public let south: [UInt16?]
        public let west: [UInt16?]

        public init(
            width: Int,
            height: Int,
            north: [UInt16?],
            east: [UInt16?],
            south: [UInt16?],
            west: [UInt16?]
        ) {
            self.width = width
            self.height = height
            self.north = north
            self.east = east
            self.south = south
            self.west = west
        }
    }

    /// Returns the four source indices for one map cell in a padded 228-cell
    /// row-stride cache.  `centralIndex` is the index written by
    /// `FUN_005AD440`; no bounds or border normalization is invented here.
    public static func cellIndices(centralIndex: Int) -> CellIndices {
        CellIndices(
            north: centralIndex + northCellOffset,
            east: centralIndex + eastCellOffset,
            south: centralIndex + southCellOffset,
            west: centralIndex + westCellOffset
        )
    }

    /// Reads the four directional views for a central cell.  A missing padded
    /// border or an out-of-range view returns `nil`; this keeps the source's
    /// pointer arithmetic explicit instead of silently wrapping a Native
    /// row-major array.
    public static func values(
        from paddedCentralValues: [UInt16],
        centralIndex: Int
    ) -> (north: UInt16, east: UInt16, south: UInt16, west: UInt16)? {
        let indices = cellIndices(centralIndex: centralIndex)
        guard [indices.north, indices.east, indices.south, indices.west]
            .allSatisfy({ paddedCentralValues.indices.contains($0) }) else {
            return nil
        }
        return (
            north: paddedCentralValues[indices.north],
            east: paddedCentralValues[indices.east],
            south: paddedCentralValues[indices.south],
            west: paddedCentralValues[indices.west]
        )
    }

    /// Projects the four PE alias views from an active, compact rectangle.
    /// `baseLinearOffset` and `centralRowStride` are the already-recovered
    /// coordinates of the rectangle in the 228×228 cache.  A projected value
    /// is present only when its alias remains inside the supplied rectangle;
    /// callers must keep `nil` cells fail-closed until the surrounding backing
    /// map is available.
    public static func activeRectangleValues(
        from centralValues: [UInt16],
        width: Int,
        height: Int,
        baseLinearOffset: Int,
        centralRowStride: Int = storageRowStride
    ) -> ActiveRectangleValues? {
        guard width > 0,
              height > 0,
              centralValues.count == width * height,
              baseLinearOffset >= 0,
              centralRowStride >= width else {
            return nil
        }

        func floorQuotient(_ value: Int, _ divisor: Int) -> Int {
            let quotient = value / divisor
            let remainder = value % divisor
            return remainder < 0 ? quotient - 1 : quotient
        }

        func value(atBackingIndex backingIndex: Int) -> UInt16? {
            let delta = backingIndex - baseLinearOffset
            let row = floorQuotient(delta, centralRowStride)
            let column = delta - row * centralRowStride
            guard row >= 0, row < height, column >= 0, column < width else {
                return nil
            }
            return centralValues[row * width + column]
        }

        var layers = Array(
            repeating: [UInt16?](repeating: nil, count: width * height),
            count: 4
        )
        for row in 0..<height {
            for column in 0..<width {
                let localIndex = row * width + column
                let centralIndex = baseLinearOffset + row * centralRowStride + column
                layers[0][localIndex] = value(atBackingIndex: centralIndex + northCellOffset)
                layers[1][localIndex] = value(atBackingIndex: centralIndex + eastCellOffset)
                layers[2][localIndex] = value(atBackingIndex: centralIndex + southCellOffset)
                layers[3][localIndex] = value(atBackingIndex: centralIndex + westCellOffset)
            }
        }
        return ActiveRectangleValues(
            width: width,
            height: height,
            north: layers[0],
            east: layers[1],
            south: layers[2],
            west: layers[3]
        )
    }
}

/// Rebuilds the cMarket access cache produced by `FUN_005B1080 @ 0x5B1080`.
/// The four PE writes are offset views of one central cache
/// (`DAT_01391C50/01391FE4/01392370/01391FDC` around `DAT_01391FE0`). The
/// north admission reads the primary layer at the north candidate; east,
/// south, and west admissions read their directional layer at the current
/// cell. This mixed indexing is distinct from `OriginalDirectionalAccessFlood`.
public enum OriginalMarketAccessFlood {
    public static let passMask: UInt16 = 0x010C

    public static func build(
        width: Int,
        height: Int,
        seed: GridPoint,
        northLayer: [UInt16],
        eastLayer: [UInt16],
        southLayer: [UInt16],
        westLayer: [UInt16]
    ) -> [Int]? {
        guard width > 0,
              height > 0,
              northLayer.count == width * height,
              eastLayer.count == width * height,
              southLayer.count == width * height,
              westLayer.count == width * height,
              seed.x >= 0, seed.x < width,
              seed.y >= 0, seed.y < height else {
            return nil
        }

        func index(of point: GridPoint) -> Int {
            point.y * width + point.x
        }
        func contains(_ point: GridPoint) -> Bool {
            point.x >= 0 && point.x < width && point.y >= 0 && point.y < height
        }

        var cache = [Int](repeating: 0, count: width * height)
        var queue = [GridPoint](repeating: seed, count: width * height)
        cache[index(of: seed)] = 1
        queue[0] = seed
        var head = 0
        var tail = 1
        let directions: [(delta: GridPoint, layer: [UInt16], readsCandidate: Bool)] = [
            (GridPoint(x: 0, y: -1), northLayer, true),
            (GridPoint(x: 1, y: 0), eastLayer, false),
            (GridPoint(x: 0, y: 1), southLayer, false),
            (GridPoint(x: -1, y: 0), westLayer, false),
        ]
        while head < tail {
            let current = queue[head]
            head += 1
            let currentIndex = index(of: current)
            let currentDepth = cache[currentIndex] + 1
            for direction in directions {
                let next = GridPoint(
                    x: current.x + direction.delta.x,
                    y: current.y + direction.delta.y
                )
                guard contains(next) else { continue }
                let nextIndex = index(of: next)
                let layerIndex = direction.readsCandidate ? nextIndex : currentIndex
                guard cache[nextIndex] == 0,
                      direction.layer[layerIndex] & passMask != 0 else { continue }
                cache[nextIndex] = currentDepth
                queue[tail] = next
                tail += 1
            }
        }
        return cache
    }
}

/// The map-auxiliary byte read by cMarket's helper-coordinate accessor
/// (`FUN_00543E70 @ 0x543E70`). The executable anchors helper record `1` to
/// the market object's `+0x0A/+0x0C` map origin, then indexes
/// `DAT_00EC5A10` with the canonical `0xE4` row stride. This is a raw map
/// projection only; the helper-record table and the consumer of the byte are
/// still unresolved.
public struct OriginalMarketHelperAuxiliaryProjection: Sendable, Hashable, Codable {
    public let selectedLinearIndex: Int
    public let helperRecordOffset: GridPoint
    public let auxiliaryValue: UInt8

    public init(
        selectedLinearIndex: Int,
        helperRecordOffset: GridPoint,
        auxiliaryValue: UInt8
    ) {
        self.selectedLinearIndex = selectedLinearIndex
        self.helperRecordOffset = helperRecordOffset
        self.auxiliaryValue = auxiliaryValue
    }
}

/// Pure projection of `FUN_00543E70` after its opaque helper `+0x70` call has
/// supplied record `1`. Callers must provide the map auxiliary byte array and
/// its linear base; no helper records or Native market coverage are created.
public enum OriginalMarketHelperAuxiliary {
    public static func project(
        marketOrigin: GridPoint,
        helperRecordOffset: GridPoint,
        mapBaseLinearIndex: Int,
        mapRowStride: Int,
        auxiliaryValues: [UInt8]
    ) -> OriginalMarketHelperAuxiliaryProjection? {
        guard mapRowStride > 0 else { return nil }
        let (rowOffset, rowOverflow) =
            marketOrigin.y.addingReportingOverflow(helperRecordOffset.y)
        let (columnOffset, columnOverflow) =
            marketOrigin.x.addingReportingOverflow(helperRecordOffset.x)
        guard !rowOverflow, !columnOverflow else { return nil }
        let (rowBase, rowBaseOverflow) =
            rowOffset.multipliedReportingOverflow(by: mapRowStride)
        let (linear, linearOverflow) =
            rowBase.addingReportingOverflow(columnOffset)
        guard !rowBaseOverflow, !linearOverflow else { return nil }
        let (selected, selectedOverflow) =
            mapBaseLinearIndex.addingReportingOverflow(linear)
        guard !selectedOverflow,
              selected >= mapBaseLinearIndex else { return nil }
        let arrayIndex = selected - mapBaseLinearIndex
        guard auxiliaryValues.indices.contains(arrayIndex) else { return nil }
        return .init(
            selectedLinearIndex: selected,
            helperRecordOffset: helperRecordOffset,
            auxiliaryValue: auxiliaryValues[arrayIndex]
        )
    }
}

/// The raw three-way provider-fill result returned by cMarket's
/// `FUN_005D5C70 @ 0x5D5C70` family. The executable reports `0` as soon as
/// any provider record is all-zero, `1` when every record is non-empty and
/// the raw quantity sum is at least `3200`, and `2` otherwise (including an
/// empty container). This is a record-state primitive only; the enclosing
/// class and player-facing label are not recovered.
public enum OriginalMarketProviderFillState: Int, Sendable, Codable {
    case hasEmptyRecord = 0
    case meetsQuantityThreshold = 1
    case belowQuantityThreshold = 2

    /// Reproduces the exact `FUN_005D5C70` record walk and return values.
    /// Empty means both raw fields are zero, matching `FUN_004B04F0`.
    public static func classify(
        records: some Collection<OriginalMarketProviderRecord>
    ) -> Self {
        var hasEmptyRecord = false
        var quantityTotal = 0
        for record in records {
            if record.rawField4 == 0 && record.rawField8 == 0 {
                hasEmptyRecord = true
            } else {
                quantityTotal += record.rawField8
            }
        }
        if hasEmptyRecord {
            return .hasEmptyRecord
        }
        return quantityTotal >= 3_200
            ? .meetsQuantityThreshold
            : .belowQuantityThreshold
    }
}

/// The raw global accumulation pass behind cMarket `+0x280`
/// (`FUN_005D5B10`). The executable skips only an all-zero provider record,
/// then calls cMarket `+0x284` with that record's `+0x04` value as the index
/// and `+0x08` value as the amount. The reducer's `FUN_004B04D0` equality
/// check confirms that `rawField4` is the cMarket internal commodity selector;
/// the record writer and complete Native inventory lifecycle remain unresolved.
public enum OriginalMarketProviderAccumulator {
    public static func add(
        records: some Collection<OriginalMarketProviderRecord>,
        to initial: [Int: Int] = [:]
    ) -> [Int: Int] {
        var totals = initial
        for record in records {
            guard record.rawField4 != 0 || record.rawField8 != 0 else { continue }
            totals[record.rawField4, default: 0] += record.rawField8
        }
        return totals
    }
}

/// Pure projection of the provider-side word update performed by the shared
/// `FUN_004EACD0 @ 0x4EACD0` crossing callback. After dispatching the home
/// object's callback, the executable reads the provider word at `+0x1C` as a
/// signed 16-bit value, adds the callback's signed 16-bit result, stores the
/// wrapped 16-bit sum, and clamps only values above `300` to `300`. The
/// provider object's identity and the semantic meaning of this word remain
/// unresolved, so this helper is intentionally not wired into live coverage.
public enum OriginalProviderCrossingAccumulator {
    public static let saturationLimit: Int16 = 300

    public static func nextValue(
        currentWord: Int16,
        callbackResult: Int16
    ) -> Int16 {
        let sum = Int32(currentWord) + Int32(callbackResult)
        let wrapped = Int16(truncatingIfNeeded: sum)
        return wrapped > saturationLimit ? saturationLimit : wrapped
    }
}

/// Result of the record-level reducer behind cMarket `+0x298`
/// (`FUN_005D50C0`). The records remain raw because the executable's provider
/// container has not been mapped to Native commodity inventory.
public struct OriginalMarketProviderConsumptionResult: Sendable, Hashable {
    public let records: [OriginalMarketProviderRecord]
    public let remainder: Int

    public init(records: [OriginalMarketProviderRecord], remainder: Int) {
        self.records = records
        self.remainder = remainder
    }
}

public enum OriginalMarketProviderConsumption {
    /// Reproduces the closed record-reducer portion of
    /// `FUN_005D50C0 @ 0x5D50C0` without invoking cMarket callbacks.
    ///
    /// For a positive request, the original repeatedly scans records in
    /// container order, chooses the matching non-zero quantity with the
    /// smallest raw quantity (strict `<`, so ties keep the first record),
    /// subtracts as much as possible, and returns any unfulfilled remainder.
    /// When a record reaches zero, `clearRecordWhenEmpty` controls whether its
    /// raw field-4 commodity ID is cleared, matching `FUN_005D2760`'s clear
    /// flag. Non-positive requests return zero and leave records untouched.
    /// The source assumes provider quantities are non-negative; the literal
    /// `!= 0 && < 10000` selection guard is preserved for raw records.
    public static func reduce(
        records: [OriginalMarketProviderRecord],
        commodityID: Int,
        requestedAmount: Int,
        clearRecordWhenEmpty: Bool
    ) -> OriginalMarketProviderConsumptionResult {
        guard requestedAmount > 0 else {
            return .init(records: records, remainder: 0)
        }

        var updated = records
        var remainder = requestedAmount
        while remainder > 0 {
            var selectedIndex: Int?
            var selectedQuantity = 10_000
            for index in updated.indices {
                let record = updated[index]
                guard record.rawField4 == commodityID,
                      record.rawField8 != 0,
                      record.rawField8 < selectedQuantity else {
                    continue
                }
                selectedQuantity = record.rawField8
                selectedIndex = index
            }
            guard let selectedIndex else { break }

            let record = updated[selectedIndex]
            let consumed: Int
            if remainder < record.rawField8 {
                consumed = remainder
                remainder = 0
            } else {
                consumed = record.rawField8
                remainder -= consumed
            }

            var nextField4 = record.rawField4
            var nextField8 = record.rawField8 - consumed
            if nextField8 < 1 {
                nextField8 = 0
                if clearRecordWhenEmpty {
                    nextField4 = 0
                }
            }
            updated[selectedIndex] = OriginalMarketProviderRecord(
                rawField4: nextField4,
                rawField8: nextField8
            )
        }

        return .init(records: updated, remainder: remainder)
    }
}

/// Result of the raw provider-record stocking helper
/// (`FUN_005D2790 @ 0x5D2790`).
public struct OriginalMarketProviderStockingResult: Sendable, Hashable {
    public let record: OriginalMarketProviderRecord
    public let overflow: Int

    public init(record: OriginalMarketProviderRecord, overflow: Int) {
        self.record = record
        self.overflow = overflow
    }
}

public enum OriginalMarketProviderStocking {
    /// Reproduces the record-level write/add operation used by the market
    /// provider update path. The executable writes the commodity field
    /// unconditionally, adds `amount` to raw quantity, clips only at the
    /// supplied record capacity, and returns the clipped overflow. The
    /// default capacity `400` is the value passed by the provider-record
    /// constructor `FUN_005D2690` through `LAB_00543680`.
    public static func add(
        record: OriginalMarketProviderRecord,
        commodityID: Int,
        amount: Int,
        capacity: Int = 400
    ) -> OriginalMarketProviderStockingResult {
        let uncapped = record.rawField8 + amount
        guard uncapped > capacity else {
            return .init(
                record: .init(rawField4: commodityID, rawField8: uncapped),
                overflow: 0
            )
        }
        return .init(
            record: .init(rawField4: commodityID, rawField8: capacity),
            overflow: uncapped - capacity
        )
    }
}

/// Result of the cStall `+0x260` deposit boundary (`FUN_00541760`). The
/// stall writes its own provider record first; only the clipped overflow is
/// forwarded to the parent cMarket `+0x154` callback. This remains a raw
/// record contract: the parent callback's second argument, provider source,
/// and any Native inventory/settlement projection are unresolved.
public struct OriginalMarketStallDepositResult: Sendable, Hashable, Codable {
    public let record: OriginalMarketProviderRecord
    public let acceptedAmount: Int
    public let overflowAmount: Int

    public init(
        record: OriginalMarketProviderRecord,
        acceptedAmount: Int,
        overflowAmount: Int
    ) {
        self.record = record
        self.acceptedAmount = acceptedAmount
        self.overflowAmount = overflowAmount
    }
}

/// Pure cStall `+0x260` record/overflow split. `FUN_005D2790` writes the raw
/// key, adds the requested amount, clips only above record capacity, and
/// returns that overflow. The cStall caller then forwards the overflow to its
/// parent cMarket `+0x154`; no parent callback is invoked here.
public enum OriginalMarketStallDeposit {
    public static func deposit(
        record: OriginalMarketProviderRecord,
        commodityID: Int,
        amount: Int,
        capacity: Int = 400
    ) -> OriginalMarketStallDepositResult {
        let stocked = OriginalMarketProviderStocking.add(
            record: record,
            commodityID: commodityID,
            amount: amount,
            capacity: capacity
        )
        return .init(
            record: stocked.record,
            acceptedAmount: amount - stocked.overflow,
            overflowAmount: stocked.overflow
        )
    }
}

/// Result of the shared storage/trade provider-record writer loop
/// (`FUN_005D4E80 @ 0x5D4E80`). This intentionally exposes only record-level
/// state and the callback count; the executable's demand and route mapping
/// are still unresolved.
public struct OriginalMarketProviderWriterResult: Sendable, Hashable {
    public let records: [OriginalMarketProviderRecord]
    public let selectedRecordIndices: [Int]
    public let callbackAmount: Int
    public let returnValue: Int

    public init(
        records: [OriginalMarketProviderRecord],
        selectedRecordIndices: [Int],
        callbackAmount: Int,
        returnValue: Int
    ) {
        self.records = records
        self.selectedRecordIndices = selectedRecordIndices
        self.callbackAmount = callbackAmount
        self.returnValue = returnValue
    }
}

/// Shared provider-record writer behind the storage/trade receiver `+0x154`
/// slot (`FUN_005D4E80 @ 0x5D4E80`). Direct PE pointer/RTTI evidence places
/// that slot on storage and trade receiver classes, not on cMarket; the
/// cMillBldg `0x555230` wrapper is one confirmed forwarder. This helper is
/// intentionally side-effect-free and must not be used as a cMarket settlement
/// or Native inventory bridge until the receiver demand and commodity mappings
/// are recovered.
public enum OriginalMarketProviderWriter {
    /// Reproduces the record-selection and one-unit loop in `FUN_005D4E80`.
    /// Empty records or records whose raw key already equals `commodityID`
    /// are candidates when their free-capacity value is non-zero. The source
    /// initializes its quantity sentinel to `-1` and keeps the candidate with
    /// the strict greatest raw quantity; ties retain the first record. Each
    /// iteration calls the receiver's `+0x284(commodityID, 1)` callback and then
    /// applies `FUN_005D2790` semantics. A complete positive request returns
    /// that request; a failed scan returns zero after preserving prior writes.
    /// No Native inventory or route side effect is attached here.
    public static func add(
        records: [OriginalMarketProviderRecord],
        commodityID: Int,
        requestedUnits: Int,
        capacities: [Int]? = nil,
        defaultCapacity: Int = 400
    ) -> OriginalMarketProviderWriterResult {
        guard requestedUnits > 0 else {
            return .init(
                records: records,
                selectedRecordIndices: [],
                callbackAmount: 0,
                returnValue: 0
            )
        }

        let resolvedCapacities: [Int]
        if let capacities, capacities.count == records.count {
            resolvedCapacities = capacities
        } else {
            resolvedCapacities = Array(repeating: defaultCapacity, count: records.count)
        }

        var updated = records
        var selected: [Int] = []
        var callbackAmount = 0

        for _ in 0..<requestedUnits {
            var candidateIndex: Int?
            var candidateQuantity = -1
            for index in updated.indices {
                let record = updated[index]
                let isEmpty = record.rawField4 == 0 && record.rawField8 == 0
                guard isEmpty || record.rawField4 == commodityID else { continue }
                let freeCapacity = resolvedCapacities[index] - record.rawField8
                guard freeCapacity != 0 else { continue }
                guard candidateIndex == nil || record.rawField8 > candidateQuantity else { continue }
                candidateIndex = index
                candidateQuantity = record.rawField8
            }

            guard let index = candidateIndex else {
                return .init(
                    records: updated,
                    selectedRecordIndices: selected,
                    callbackAmount: callbackAmount,
                    returnValue: 0
                )
            }

            let stocked = OriginalMarketProviderStocking.add(
                record: updated[index],
                commodityID: commodityID,
                amount: 1,
                capacity: resolvedCapacities[index]
            )
            updated[index] = stocked.record
            selected.append(index)
            callbackAmount += 1
        }

        return .init(
            records: updated,
            selectedRecordIndices: selected,
            callbackAmount: callbackAmount,
            returnValue: requestedUnits
        )
    }
}

/// Result of the cMarket-specific raw provider refill at vtable `+0x154`
/// (`0x543BC0`). Unlike the shared storage/trade writer above, this path
/// never admits an all-zero record: it selects only records whose raw key
/// already equals the requested key and performs a one-unit refill.
public struct OriginalMarketProviderRefillResult: Sendable, Hashable {
    public let records: [OriginalMarketProviderRecord]
    public let selectedRecordIndices: [Int]
    public let returnValue: Int

    public init(
        records: [OriginalMarketProviderRecord],
        selectedRecordIndices: [Int],
        returnValue: Int
    ) {
        self.records = records
        self.selectedRecordIndices = selectedRecordIndices
        self.returnValue = returnValue
    }
}

/// Pure record-level reproduction of the cMarket `+0x154` body at
/// `FUN_00543BC0`. The receiver-state gates and the derivation of the
/// positive remaining count are intentionally outside this helper because
/// their model-data and market-state mappings are not yet recovered.
public enum OriginalMarketProviderRefill {
    /// Refill `requestedUnits` one unit at a time. Each scan accepts only a
    /// matching raw key, requires a non-zero free-capacity value, and chooses
    /// the strictly greatest current quantity (sentinel `-1`; first tie is
    /// retained). A failed scan returns zero after preserving any prior
    /// writes, matching the executable's early return.
    public static func add(
        records: [OriginalMarketProviderRecord],
        commodityID: Int,
        requestedUnits: Int,
        capacities: [Int]? = nil,
        defaultCapacity: Int = 400
    ) -> OriginalMarketProviderRefillResult {
        guard requestedUnits > 0 else {
            return .init(records: records, selectedRecordIndices: [], returnValue: 0)
        }

        let resolvedCapacities: [Int]
        if let capacities, capacities.count == records.count {
            resolvedCapacities = capacities
        } else {
            resolvedCapacities = Array(repeating: defaultCapacity, count: records.count)
        }

        var updated = records
        var selected: [Int] = []
        for _ in 0..<requestedUnits {
            var candidateIndex: Int?
            var candidateQuantity = -1
            for index in updated.indices {
                let record = updated[index]
                guard record.rawField4 == commodityID,
                      resolvedCapacities[index] - record.rawField8 != 0,
                      record.rawField8 > candidateQuantity else {
                    continue
                }
                candidateIndex = index
                candidateQuantity = record.rawField8
            }

            guard let index = candidateIndex else {
                return .init(
                    records: updated,
                    selectedRecordIndices: selected,
                    returnValue: 0
                )
            }

            updated[index] = OriginalMarketProviderStocking.add(
                record: updated[index],
                commodityID: commodityID,
                amount: 1,
                capacity: resolvedCapacities[index]
            ).record
            selected.append(index)
        }

        return .init(
            records: updated,
            selectedRecordIndices: selected,
            returnValue: requestedUnits
        )
    }
}

/// Pure cMarket `+0xC8` predicate recovered at `FUN_00543D50`. The monthly
/// Dinners pass calls this slot with selector `-3`; that selector is an
/// unconditional acceptance branch after the receiver-model and `-7`
/// checks. The auxiliary result is supplied explicitly because its vtable
/// implementation is not part of the recovered cMarket gate.
public enum OriginalMarketMonthlyDinnersGate {
    public static let selector = -3

    public static func isEligible(
        receiverModelID: Int,
        selector: Int = Self.selector,
        auxiliaryResult: Int? = nil
    ) -> Bool {
        if receiverModelID == selector || selector == -7 || selector == Self.selector {
            return true
        }
        return auxiliaryResult == selector
    }
}

/// The two quantities written by the residential market callback's house
/// vtable `+0x228` (`0x51A3A0`) before the Dinners settlement branch. The
/// executable writes the target stock to the first call-site local and the
/// per-callback cap to the second; see `migration-popularity-producer.md`
/// §10.22. This helper is intentionally independent of Native inventory.
public struct OriginalMarketFoodDeliveryDemand: Sendable, Hashable {
    public let targetStock: Int
    public let perCallbackCap: Int
    public let requestedAmount: Int

    public init(targetStock: Int, perCallbackCap: Int, requestedAmount: Int) {
        self.targetStock = targetStock
        self.perCallbackCap = perCallbackCap
        self.requestedAmount = requestedAmount
    }

    /// Reproduces `FUN_0051A3A0` output ordering and the surrounding
    /// `FUN_005437B0` target-minus-current/cap clamp. Residents are treated as
    /// non-negative, matching the serialized house word; current stock is
    /// clamped at zero for the pure Native boundary.
    public static func resolve(residents: Int, currentStock: Int) -> Self {
        let normalizedResidents = max(0, residents)
        let targetStock = normalizedResidents == 0 ? 10 : normalizedResidents * 2
        let perCallbackCap = normalizedResidents == 0
            ? 5
            : max(1, normalizedResidents / 2)
        let remaining = max(0, targetStock - max(0, currentStock))
        return .init(
            targetStock: targetStock,
            perCallbackCap: perCallbackCap,
            requestedAmount: min(remaining, perCallbackCap)
        )
    }
}

public enum OriginalMarketCatalog {
    /// A direct EN/CH PE callsite into the shared destination selector.
    /// This is a call-graph fact only: it does not assign market, provider,
    /// or Qin archive semantics to the selector.
    public struct DestinationSelectorCallSite: Sendable, Hashable, Codable {
        public let callerAddress: UInt32
        public let callSiteAddress: UInt32

        public init(callerAddress: UInt32, callSiteAddress: UInt32) {
            self.callerAddress = callerAddress
            self.callSiteAddress = callSiteAddress
        }
    }

    /// One of the six global destination-admission strategy instances used by
    /// `FUN_00521DF0 @ 0x521DF0`.  The selector is an index in the original
    /// `FUN_0051EB00` switch (1...5, with the default object for selector 0).
    /// These objects are consumed by the figure/object destination chain; the
    /// table records identity only and deliberately does not infer a market,
    /// provider, or Qin archive meaning from a strategy's model switch.
    public struct DestinationSelectorDescriptor: Sendable, Hashable, Codable {
        public let selector: Int
        public let globalStateAddress: UInt32
        public let constructorAddress: UInt32
        public let vTableAddress: UInt32
        public let admissionCallbackAddress: UInt32

        public init(
            selector: Int,
            globalStateAddress: UInt32,
            constructorAddress: UInt32,
            vTableAddress: UInt32,
            admissionCallbackAddress: UInt32
        ) {
            self.selector = selector
            self.globalStateAddress = globalStateAddress
            self.constructorAddress = constructorAddress
            self.vTableAddress = vTableAddress
            self.admissionCallbackAddress = admissionCallbackAddress
        }
    }

    public static let destinationSelectorDispatchAddress: UInt32 = 0x0051EB00
    public static let destinationSelectorConsumerAddress: UInt32 = 0x00521DF0
    public static let destinationSelectorRetryWrapperAddress: UInt32 = 0x00521C90
    public static let destinationSelectorStateUpdaterAddress: UInt32 = 0x00521D20

    /// The complete direct `E8` callsite set for `FUN_00521DF0` in both
    /// canonical EN/CH PE images.  The map-load entry points are absent; the
    /// three sites are the two retry calls and the state-updater call.
    public static let destinationSelectorDirectCallSites: [DestinationSelectorCallSite] = [
        .init(callerAddress: destinationSelectorRetryWrapperAddress, callSiteAddress: 0x00521CBA),
        .init(callerAddress: destinationSelectorRetryWrapperAddress, callSiteAddress: 0x00521CFB),
        .init(callerAddress: destinationSelectorStateUpdaterAddress, callSiteAddress: 0x00521DDC),
    ]

    /// EN/CH-identical vtable/constructor inventory recovered from the six
    /// objects returned by `FUN_0051EB00`.  Selector 0 uses the default branch.
    /// The first vtable word is the callback invoked by `FUN_00521DF0`.
    public static let destinationSelectorDescriptors: [DestinationSelectorDescriptor] = [
        .init(
            selector: 0,
            globalStateAddress: 0x010BFFB8,
            constructorAddress: 0x0051EA60,
            vTableAddress: 0x007B6AF8,
            admissionCallbackAddress: 0x0051FCE0
        ),
        .init(
            selector: 1,
            globalStateAddress: 0x010BFFB4,
            constructorAddress: 0x0051EAA0,
            vTableAddress: 0x007B6B0C,
            admissionCallbackAddress: 0x0051F870
        ),
        .init(
            selector: 2,
            globalStateAddress: 0x010BFFB0,
            constructorAddress: 0x0051EAE0,
            vTableAddress: 0x007B6B20,
            admissionCallbackAddress: 0x0051F690
        ),
        .init(
            selector: 3,
            globalStateAddress: 0x010BFFBC,
            constructorAddress: 0x0051EA20,
            vTableAddress: 0x007B6AE4,
            admissionCallbackAddress: 0x0051F1A0
        ),
        .init(
            selector: 4,
            globalStateAddress: 0x010BFFC0,
            constructorAddress: 0x0051E9E0,
            vTableAddress: 0x007B6AD0,
            admissionCallbackAddress: 0x0051EF80
        ),
        .init(
            selector: 5,
            globalStateAddress: 0x010BFFC4,
            constructorAddress: 0x0051E990,
            vTableAddress: 0x007B6AA8,
            admissionCallbackAddress: 0x0051EBA0
        ),
    ]

    public static func destinationSelectorDescriptor(
        for selector: Int
    ) -> DestinationSelectorDescriptor? {
        destinationSelectorDescriptors.first { $0.selector == selector }
    }

    public static let commonMarketBuildingID = 59
    public static let grandMarketBuildingID = 60
    /// Static class/factory identity recovered from EN/CH `local/source`.
    /// `FUN_00543D90` is the cMarket model recognizer used by
    /// `FUN_005D3580`; only model IDs 59 and 60 reach the cMarket
    /// constructor `FUN_00543450`.  These are research metadata, not a
    /// serialized-archive specialization rule.
    public static let marketFactoryAddress: UInt32 = 0x005D3580
    public static let marketModelRecognizerAddress: UInt32 = 0x00543D90
    public static let marketConstructorAddress: UInt32 = 0x00543450
    /// Standalone common-market allocation wrapper recovered at
    /// `FUN_00540680`. It allocates `0x18c` bytes and invokes the constructor
    /// with argument `0`, which selects the common-market defaults. The
    /// indexed EN/CH corpus has no direct caller for this wrapper, so it is
    /// metadata for the explicit construction family only; it is not a
    /// map-load specialization edge.
    public static let commonMarketAllocationWrapperAddress: UInt32 = 0x00540680
    public static let commonMarketAllocationWrapperAllocationSize = 0x18c
    public static let commonMarketAllocationWrapperConstructorArgument = 0
    public static let recognizedMarketBuildingIDs: [Int] = [
        commonMarketBuildingID,
        grandMarketBuildingID
    ]
    public static let buyerFigureID = 24
    public static let peddlerFigureID = 23
    public static let shopBuildingIDs = [66, 67, 65, 70, 69, 68, 64]

    public static func shopCapacity(forMarketBuildingID buildingID: Int) -> Int? {
        switch buildingID {
        case commonMarketBuildingID: 4
        case grandMarketBuildingID: 6
        default: nil
        }
    }

    public static func peddlerCapacity(forMarketBuildingID buildingID: Int) -> Int? {
        switch buildingID {
        case commonMarketBuildingID: 2
        // The executable's cMarket +0x4C(0x17) gate exposes three live
        // peddler slots for the Grand Market (type 3). This is independent
        // of the six authored shop bays, which are a separate shop-capacity
        // concept (§10.17f).
        case grandMarketBuildingID: 3
        default: nil
        }
    }

    /// Threshold used by the peddler-specific market wrapper
    /// (`FUN_00543ED0`). It increments the per-market byte first and spawns
    /// only when the incremented value is strictly greater than this
    /// threshold. Zero workers return before this table in the original.
    public static func peddlerSpawnThreshold(workerPercent: Int) -> Int {
        switch workerPercent {
        case 100...: return 2
        case 75..<100: return 3
        case 50..<75: return 4
        case 25..<50: return 5
        case 1..<25: return 10
        default: return 0
        }
    }

    /// Reproduces the raw ratio that `FUN_00543ED0 @ 0x543ED0` feeds into
    /// its peddler threshold table.  The executable calls
    /// `FUN_00408BA0(empty-child raw +0x44, filled-shop employee total)`,
    /// which is integer `(numerator * 100) / denominator` and returns zero
    /// for a zero denominator.  The producer and semantic label of the
    /// cStall `+0x44` word remain unresolved; callers must provide that raw
    /// value explicitly rather than deriving it from Native staffing.
    public static func peddlerWorkerPercent(
        rawEmptyChildWorkerUnits: Int,
        filledShopEmployeeUnits: Int
    ) -> Int? {
        guard filledShopEmployeeUnits != 0 else { return 0 }
        let (scaled, overflow) =
            rawEmptyChildWorkerUnits.multipliedReportingOverflow(by: 100)
        guard !overflow else { return nil }
        return scaled / filledShopEmployeeUnits
    }

    /// Pure admission result for the first half of `FUN_00543ED0`.  The
    /// cMarket `+0x268` stock test is kept separate from the worker-ratio
    /// arithmetic; a positive worker ratio alone does not authorize a model
    /// 23 allocation.  This descriptor is research-only and is not consumed
    /// by the campaign scheduler while cStall `+0x44` production and the
    /// route/coverage projection remain unknown.
    public static func peddlerSpawnGate(
        rawEmptyChildWorkerUnits: Int,
        filledShopEmployeeUnits: Int,
        hasMarketStock: Bool
    ) -> (workerPercent: Int, threshold: Int, admits: Bool)? {
        guard let workerPercent = peddlerWorkerPercent(
            rawEmptyChildWorkerUnits: rawEmptyChildWorkerUnits,
            filledShopEmployeeUnits: filledShopEmployeeUnits
        ) else { return nil }
        let threshold = peddlerSpawnThreshold(workerPercent: workerPercent)
        return (
            workerPercent: workerPercent,
            threshold: threshold,
            admits: hasMarketStock && workerPercent > 0
        )
    }

    public static func commodityID(forShopBuildingID buildingID: Int) -> Int? {
        switch buildingID {
        case 64: 23 // Bronzeware
        case 65: 25 // Ceramics
        case 67: 19 // Hemp
        case 68: 22 // Lacquerware
        case 69: 24 // Silk
        case 70: 13 // Tea
        default: nil // Food shop is handled with the mill/food-quality system.
        }
    }

    public static func supports(shopBuildingID: Int) -> Bool {
        shopBuildingID == OriginalFoodCatalog.foodShopBuildingID
            || commodityID(forShopBuildingID: shopBuildingID) != nil
    }
}

/// The peddler-link storage returned by the market's generic `+0x1E8`
/// accessor.  This is deliberately kept separate from the six contiguous
/// 16-byte commodity records at `market+0x154`: the accessor body
/// `FUN_00416B50 @ 0x416B50` is only `lea eax,[ecx+0xC8]; ret`, so its result
/// is the market's attached information object at `+0xC8`.  The executable
/// stores the primary figure link on the market itself and the additional
/// links in that attached object.  No provider-registry or inventory meaning
/// is inferred by this descriptor.
public enum OriginalMarketPeddlerLinkStorage {
    public static let marketVTableAddress: UInt32 = 0x007B6F3C
    public static let accessorVTableOffset = 0x1E8
    public static let accessorAddress: UInt32 = 0x00416B50
    public static let attachedInfoOffset = 0xC8
    public static let primaryMarketSlotOffset = 0x2E
    public static let attachedInfoSecondSlotOffset = 0x6A
    public static let attachedInfoThirdSlotOffset = 0x6C
    public static let figureModelOffset = 0x12
    public static let figureActiveOffset = 0x16
    public static let figureParentMarketOffset = 0x62
    public static let registrationAddress: UInt32 = 0x004272A0
    public static let primaryValidatorAddress: UInt32 = 0x00429700
    public static let secondValidatorAddress: UInt32 = 0x00429780
    public static let thirdValidatorAddress: UInt32 = 0x00429810

    /// Type 2 (Common Market Square) checks two links; type 3 (Grand Market
    /// Square) checks all three.  Other market-type values are outside the
    /// recovered peddler-slot dispatch and return no slot layout.
    public static func slotOffsets(forMarketType marketType: Int) -> [Int]? {
        switch marketType {
        case 2: return [primaryMarketSlotOffset, attachedInfoSecondSlotOffset]
        case 3:
            return [
                primaryMarketSlotOffset,
                attachedInfoSecondSlotOffset,
                attachedInfoThirdSlotOffset,
            ]
        default: return nil
        }
    }

    /// Validator entry used by the cMarket `+0x3C/+0x40/+0x44` slots.
    public static func validatorAddress(forSlotOrdinal ordinal: Int) -> UInt32? {
        switch ordinal {
        case 0: return primaryValidatorAddress
        case 1: return secondValidatorAddress
        case 2: return thirdValidatorAddress
        default: return nil
        }
    }

    /// The destination selected by `FUN_004272A0 @ 0x4272A0` when a peddler
    /// figure ID is registered with a market. These are storage slots, not
    /// commodity records or Native peddler IDs.
    public enum RegistrationSlot: String, Sendable, Hashable, Codable {
        case primaryMarket
        case attachedInfoSecond
        case attachedInfoThird
    }

    /// Replays the source's slot-selection order without resolving figures
    /// or mutating a market. The source treats market type `1` specially,
    /// uses `< 1` for empty signed-short link tests, checks the Grand Market's
    /// third slot before validating the primary figure, and finally falls
    /// back to the attached-info second slot. The second attached figure is
    /// intentionally not tested here: the recovered writer only resolves it
    /// as an unused lookup; its validator performs the later active/model/
    /// parent checks.
    public static func registrationSlot(
        marketType: Int,
        primaryLink: Int,
        attachedInfoSecondLink: Int,
        attachedInfoThirdLink: Int,
        primaryFigureIsActive: Bool,
        thirdFigureIsActive: Bool
    ) -> RegistrationSlot {
        if marketType == 1 {
            return .primaryMarket
        }
        if primaryLink < 1 {
            return .primaryMarket
        }
        if attachedInfoSecondLink > 0 {
            if marketType == 3, attachedInfoThirdLink < 1 {
                return .attachedInfoThird
            }
            if !primaryFigureIsActive {
                return .primaryMarket
            }
            if marketType == 3, !thirdFigureIsActive {
                return .attachedInfoThird
            }
        }
        return .attachedInfoSecond
    }

    /// Result of one source peddler-link validator. `clearsStoredLink` is
    /// true only on the branches that write the corresponding short link to
    /// zero; an already-empty slot is simply rejected without a write.
    public struct LinkValidationResult: Sendable, Hashable, Codable {
        public let isValid: Bool
        public let clearsStoredLink: Bool

        public init(isValid: Bool, clearsStoredLink: Bool) {
            self.isValid = isValid
            self.clearsStoredLink = clearsStoredLink
        }
    }

    /// Replays `FUN_00429700`, `FUN_00429780`, and `FUN_00429810`'s shared
    /// figure checks. The two model arguments are the source's accepted
    /// alternatives; the parent comparison uses the market's raw registry
    /// value. Object lookup is explicit so an absent registry entry cannot be
    /// silently treated as a valid figure.
    public static func validateLink(
        slot: RegistrationSlot,
        storedLink: Int,
        figureExists: Bool,
        figureIsActive: Bool,
        figureModelID: Int,
        acceptedModelIDs: (Int, Int),
        figureParentMarketID: Int,
        marketRegistryID: Int
    ) -> LinkValidationResult {
        let empty = slot == .primaryMarket || slot == .attachedInfoThird
            ? storedLink < 1
            : storedLink <= 0
        guard !empty else {
            return .init(isValid: false, clearsStoredLink: false)
        }

        let valid = figureExists
            && figureIsActive
            && (figureModelID == acceptedModelIDs.0
                || figureModelID == acceptedModelIDs.1)
            && figureParentMarketID == marketRegistryID
        return .init(isValid: valid, clearsStoredLink: !valid)
    }
}

public struct MarketSquare: Identifiable, Sendable, Hashable, Codable {
    public let id: Int
    public let buildingID: Int
    public let roadAccessPoint: GridPoint
    public private(set) var shopBuildingIDs: [Int]
    public var inventoryByCommodityID: [Int: Int]
    public var activeBuyerByCommodityID: [Int: Int]
    // Optional backing keeps pre-bridge saves decodable while preserving the
    // original cMarket +0x36 spawn counter once the city scheduler is active.
    private var originalPeddlerSpawnCounterState: Int?
    // cMarket +0x38 rotates by four after a successful model-23 allocation.
    // The selected coordinate table is not yet mapped, so this is persisted
    // as state without replacing the current route-origin representation.
    private var originalPeddlerSpawnRotationState: Int?

    public var peddlerCapacity: Int {
        OriginalMarketCatalog.peddlerCapacity(forMarketBuildingID: buildingID) ?? 0
    }

    public init(
        id: Int,
        buildingID: Int,
        roadAccessPoint: GridPoint,
        shopBuildingIDs: [Int],
        inventoryByCommodityID: [Int: Int] = [:],
        activeBuyerByCommodityID: [Int: Int] = [:]
    ) {
        self.id = id
        self.buildingID = buildingID
        self.roadAccessPoint = roadAccessPoint
        self.shopBuildingIDs = shopBuildingIDs
        self.inventoryByCommodityID = inventoryByCommodityID
        self.activeBuyerByCommodityID = activeBuyerByCommodityID
        originalPeddlerSpawnCounterState = 0
        originalPeddlerSpawnRotationState = 0
    }

    public var originalPeddlerSpawnCounter: Int {
        originalPeddlerSpawnCounterState ?? 0
    }

    public var originalPeddlerSpawnRotation: Int {
        originalPeddlerSpawnRotationState ?? 0
    }

    /// Consumes one original provider spawn opportunity. The caller must have
    /// already applied the positive-worker and available-slot gates.
    mutating func consumeOriginalPeddlerSpawnOpportunity(workerPercent: Int) -> Bool {
        let next = originalPeddlerSpawnCounter + 1
        originalPeddlerSpawnCounterState = next
        guard next > OriginalMarketCatalog.peddlerSpawnThreshold(
            workerPercent: workerPercent
        ) else { return false }
        originalPeddlerSpawnCounterState = 0
        return true
    }

    mutating func advanceOriginalPeddlerSpawnRotation() {
        originalPeddlerSpawnRotationState = (originalPeddlerSpawnRotation + 4) & 7
    }

    public var stockedCommodityIDs: [Int] {
        shopBuildingIDs.compactMap(OriginalMarketCatalog.commodityID(forShopBuildingID:))
    }

    public var hasFoodShop: Bool {
        shopBuildingIDs.contains(OriginalFoodCatalog.foodShopBuildingID)
    }

    public var remainingShopCapacity: Int {
        max(
            0,
            (OriginalMarketCatalog.shopCapacity(forMarketBuildingID: buildingID) ?? 0)
                - shopBuildingIDs.count
        )
    }

    @discardableResult
    mutating func addShop(buildingID: Int) -> Bool {
        guard remainingShopCapacity > 0,
              OriginalMarketCatalog.supports(shopBuildingID: buildingID) else {
            return false
        }
        shopBuildingIDs.append(buildingID)
        return true
    }
}

public struct MarketBuyer: Identifiable, Sendable, Hashable, Codable {
    public let id: Int
    public let figureID: Int
    public let marketID: Int
    public let warehouseID: Int?
    public let millID: Int?
    public let cargoes: [DeliveryCargo]
    public let route: [GridPoint]
    public let warehouseRouteIndex: Int
    public private(set) var routeIndex: Int
    public private(set) var hasReachedWarehouse: Bool
    // Optional backing preserves saves written before the selector-8 buyer
    // cadence was represented. The original constructor zeros both bytes.
    private var originalSpeedPhaseState: Int?
    private var originalSubstepProgressState: Int?

    public var currentPoint: GridPoint? {
        route.indices.contains(routeIndex) ? route[routeIndex] : nil
    }

    public var hasReturned: Bool {
        hasReachedWarehouse && routeIndex == route.count - 1
    }

    init(
        id: Int,
        marketID: Int,
        warehouseID: Int? = nil,
        millID: Int? = nil,
        cargoes: [DeliveryCargo],
        outboundPath: [GridPoint]
    ) {
        self.id = id
        figureID = OriginalMarketCatalog.buyerFigureID
        self.marketID = marketID
        self.warehouseID = warehouseID
        self.millID = millID
        self.cargoes = cargoes
        warehouseRouteIndex = max(0, outboundPath.count - 1)
        route = outboundPath + Array(outboundPath.dropLast().reversed())
        routeIndex = 0
        hasReachedWarehouse = outboundPath.count == 1
        originalSpeedPhaseState = 0
        originalSubstepProgressState = 0
    }

    private enum CodingKeys: String, CodingKey {
        case id, figureID, marketID, warehouseID, millID, cargo, cargoes, route
        case warehouseRouteIndex, routeIndex, hasReachedWarehouse
        case originalSpeedPhase, originalSubstepProgress
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(Int.self, forKey: .id)
        figureID = try container.decode(Int.self, forKey: .figureID)
        marketID = try container.decode(Int.self, forKey: .marketID)
        warehouseID = try container.decodeIfPresent(Int.self, forKey: .warehouseID)
        millID = try container.decodeIfPresent(Int.self, forKey: .millID)
        if let decoded = try container.decodeIfPresent([DeliveryCargo].self, forKey: .cargoes) {
            cargoes = decoded
        } else if let legacy = try container.decodeIfPresent(DeliveryCargo.self, forKey: .cargo) {
            cargoes = [legacy]
        } else {
            cargoes = []
        }
        route = try container.decode([GridPoint].self, forKey: .route)
        warehouseRouteIndex = try container.decode(Int.self, forKey: .warehouseRouteIndex)
        routeIndex = try container.decode(Int.self, forKey: .routeIndex)
        hasReachedWarehouse = try container.decode(Bool.self, forKey: .hasReachedWarehouse)
        originalSpeedPhaseState = try container.decodeIfPresent(Int.self, forKey: .originalSpeedPhase)
        originalSubstepProgressState = try container.decodeIfPresent(Int.self, forKey: .originalSubstepProgress)
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(figureID, forKey: .figureID)
        try container.encode(marketID, forKey: .marketID)
        try container.encodeIfPresent(warehouseID, forKey: .warehouseID)
        try container.encodeIfPresent(millID, forKey: .millID)
        try container.encode(cargoes, forKey: .cargoes)
        try container.encode(route, forKey: .route)
        try container.encode(warehouseRouteIndex, forKey: .warehouseRouteIndex)
        try container.encode(routeIndex, forKey: .routeIndex)
        try container.encode(hasReachedWarehouse, forKey: .hasReachedWarehouse)
        try container.encodeIfPresent(originalSpeedPhaseState, forKey: .originalSpeedPhase)
        try container.encodeIfPresent(originalSubstepProgressState, forKey: .originalSubstepProgress)
    }

    mutating func advanceOneRoadStep() -> Bool {
        guard routeIndex + 1 < route.count else { return false }
        routeIndex += 1
        if routeIndex == warehouseRouteIndex { hasReachedWarehouse = true }
        return true
    }

    /// Consumes one original buyer figure update. Model 24 uses selector 8:
    /// phases 0/1 perform one substep and phase 2 performs two, while each
    /// twentieth accumulated substep crosses one route point. This mirrors
    /// the recovered `FUN_004E47A0 → FUN_004E7EB0` cadence without claiming
    /// the unresolved destination/collision FSM.
    mutating func advanceOriginalFigureUpdate() -> Int {
        let plan = OriginalResidentialServiceCatalog.entertainmentVenueMovementUpdatePlan(
            selector: 8,
            phase: UInt8(truncatingIfNeeded: originalSpeedPhaseState ?? 0)
        )
        originalSpeedPhaseState = Int(plan.nextPhase)

        var moved = 0
        var progress = originalSubstepProgressState ?? 0
        for _ in 0..<plan.movementUpdates {
            progress += 1
            guard progress >= 20 else { continue }
            progress = 0
            if advanceOneRoadStep() { moved += 1 }
        }
        originalSubstepProgressState = progress
        return moved
    }
}

public struct MarketPeddler: Identifiable, Sendable, Hashable, Codable {
    public let id: Int
    public let figureID: Int
    public let marketID: Int
    public let commodityID: Int
    public let route: [GridPoint]
    public let foodQualityRawValue: Int?
    public private(set) var routeIndex: Int
    public private(set) var remainingAmount: Int
    public private(set) var foodCargoes: [DeliveryCargo]?
    // Optional backing preserves legacy peddler saves. The original spawn
    // path initializes selector-8 progress at 20 before its first think tick.
    private var originalSpeedPhaseState: Int?
    private var originalSubstepProgressState: Int?

    public var currentPoint: GridPoint? {
        route.indices.contains(routeIndex) ? route[routeIndex] : nil
    }

    public var hasCompletedRoute: Bool {
        route.isEmpty || routeIndex == route.count - 1
    }

    init(
        id: Int,
        marketID: Int,
        commodityID: Int,
        amount: Int,
        route: [GridPoint],
        foodQuality: FoodQuality? = nil,
        foodCargoes: [DeliveryCargo]? = nil
    ) {
        self.id = id
        figureID = OriginalMarketCatalog.peddlerFigureID
        self.marketID = marketID
        self.commodityID = commodityID
        self.route = route
        foodQualityRawValue = foodQuality?.rawValue
        routeIndex = 0
        remainingAmount = max(0, amount)
        self.foodCargoes = foodCargoes
        originalSpeedPhaseState = 0
        originalSubstepProgressState = 20
    }

    mutating func advanceOneRoadStep(barrierPoints: Set<GridPoint>) -> Bool {
        guard routeIndex + 1 < route.count else { return false }
        // Confirmed safety boundary: a roaming peddler never enters a roadblock.
        // The original post-collision direction choice is still unknown, so
        // Native leaves the peddler in place instead of inventing a reroute.
        guard !barrierPoints.contains(route[routeIndex + 1]) else { return false }
        routeIndex += 1
        return true
    }

    /// Consumes one original peddler figure update. Model 23 enters the
    /// selector-8 movement path: phases 0/1 perform one substep and phase 2
    /// performs two, with a route crossing at twenty accumulated substeps.
    /// The route and writer remain Native compatibility data; only this clock
    /// is recovered from the executable.
    mutating func advanceOriginalFigureUpdate(
        barrierPoints: Set<GridPoint>
    ) -> Int {
        let plan = OriginalResidentialServiceCatalog.entertainmentVenueMovementUpdatePlan(
            selector: 8,
            phase: UInt8(truncatingIfNeeded: originalSpeedPhaseState ?? 0)
        )
        originalSpeedPhaseState = Int(plan.nextPhase)

        var moved = 0
        var progress = originalSubstepProgressState ?? 20
        for _ in 0..<plan.movementUpdates {
            progress += 1
            guard progress >= 20 else { continue }
            guard routeIndex + 1 < route.count else {
                progress = 0
                continue
            }
            guard !barrierPoints.contains(route[routeIndex + 1]) else {
                // Preserve the existing no-entry roadblock boundary. The
                // unresolved original turn choice is intentionally not added.
                progress = 20
                continue
            }
            progress = 0
            routeIndex += 1
            moved += 1
        }
        originalSubstepProgressState = progress
        return moved
    }

    mutating func deliver(_ amount: Int) -> Int {
        let delivered = min(max(0, amount), remainingAmount)
        remainingAmount -= delivered
        if var cargoes = foodCargoes, delivered > 0 {
            var toConsume = delivered
            for index in cargoes.indices where toConsume > 0 {
                let taken = min(toConsume, cargoes[index].amount)
                cargoes[index] = DeliveryCargo(
                    commodityID: cargoes[index].commodityID,
                    amount: cargoes[index].amount - taken
                )
                toConsume -= taken
            }
            foodCargoes = cargoes.filter { $0.amount > 0 }
        }
        return delivered
    }
}

public struct HouseholdCommodityDelivery: Sendable, Hashable, Codable {
    public let houseID: Int
    public let commodityID: Int
    public let amount: Int

    public init(houseID: Int, commodityID: Int, amount: Int) {
        self.houseID = houseID
        self.commodityID = commodityID
        self.amount = amount
    }
}

public struct HouseholdCommodityConsumption: Sendable, Hashable, Codable {
    public let houseID: Int
    public let commodityID: Int
    public let requestedAmount: Int
    public let consumedAmount: Int

    public init(
        houseID: Int,
        commodityID: Int,
        requestedAmount: Int,
        consumedAmount: Int
    ) {
        self.houseID = houseID
        self.commodityID = commodityID
        self.requestedAmount = requestedAmount
        self.consumedAmount = consumedAmount
    }
}

public struct MarketMonthlySettlement: Sendable, Hashable, Codable {
    public let purchasedLoads: [DeliveryCargo]
    public let householdDeliveries: [HouseholdCommodityDelivery]
    public let householdConsumption: [HouseholdCommodityConsumption]
    public let underSuppliedHouseIDs: [Int]
}

public struct DeterministicMarketState: Sendable, Hashable, Codable {
    public private(set) var markets: [MarketSquare]
    public private(set) var buyers: [MarketBuyer]
    public private(set) var peddlers: [MarketPeddler]
    public private(set) var lastSettlement: MarketMonthlySettlement?
    private var nextMarketID: Int
    private var nextBuyerID: Int
    private var nextPeddlerID: Int
    // Optional so saves written before continuous market movement still decode.
    private var purchasedLoadsThisMonthStorage: [DeliveryCargo]?
    private var householdDeliveriesThisMonthStorage: [HouseholdCommodityDelivery]?
    // The original provider scheduler uses a 51-step phase wheel and calls
    // market +0x20 at phase 0x1F. Optional backing preserves older saves.
    private var originalSchedulerPhaseState: Int?

    public init() {
        markets = []
        buyers = []
        peddlers = []
        lastSettlement = nil
        nextMarketID = 1
        nextBuyerID = 1
        nextPeddlerID = 1
        purchasedLoadsThisMonthStorage = []
        householdDeliveriesThisMonthStorage = []
        originalSchedulerPhaseState = 0
    }

    @discardableResult
    public mutating func addMarket(
        buildingID: Int,
        roadAccessPoint: GridPoint,
        shopBuildingIDs: [Int],
        roadNetwork: RoadNetwork
    ) -> Int? {
        guard roadNetwork.contains(roadAccessPoint),
              let capacity = OriginalMarketCatalog.shopCapacity(forMarketBuildingID: buildingID),
              shopBuildingIDs.count <= capacity,
              shopBuildingIDs.allSatisfy(OriginalMarketCatalog.supports(shopBuildingID:)) else {
            return nil
        }
        let id = nextMarketID
        nextMarketID += 1
        markets.append(MarketSquare(
            id: id,
            buildingID: buildingID,
            roadAccessPoint: roadAccessPoint,
            shopBuildingIDs: shopBuildingIDs
        ))
        return id
    }

    /// Adds one independently staffed shop to an existing market square.
    /// Duplicate shop types are intentional: the original game allows players
    /// to trade variety for additional capacity of a high-demand commodity.
    @discardableResult
    public mutating func addShop(marketID: Int, shopBuildingID: Int) -> Bool {
        guard let index = markets.firstIndex(where: { $0.id == marketID }) else {
            return false
        }
        return markets[index].addShop(buildingID: shopBuildingID)
    }

    /// Removes a market and every buyer/peddler owned by it. Their carried
    /// goods disappear with the demolished market.
    @discardableResult
    public mutating func removeMarket(id: Int) -> MarketSquare? {
        guard let index = markets.firstIndex(where: { $0.id == id }) else { return nil }
        buyers.removeAll { $0.marketID == id }
        peddlers.removeAll { $0.marketID == id }
        return markets.remove(at: index)
    }

    @discardableResult
    public mutating func cancelBuyers(targetingWarehouseID warehouseID: Int) -> [Int] {
        cancelBuyers { $0.warehouseID == warehouseID }
    }

    @discardableResult
    public mutating func cancelBuyers(targetingMillID millID: Int) -> [Int] {
        cancelBuyers { $0.millID == millID }
    }

    /// Cancels market travelers whose authored route used a removed road.
    @discardableResult
    public mutating func cancelTravelers(using point: GridPoint) -> [Int] {
        let buyerIDs = cancelBuyers { $0.route.contains(point) }
        let peddlerIDs = peddlers.filter { $0.route.contains(point) }.map(\.id)
        let peddlerIDSet = Set(peddlerIDs)
        peddlers.removeAll { peddlerIDSet.contains($0.id) }
        return (buyerIDs + peddlerIDs).sorted()
    }

    private mutating func cancelBuyers(
        where shouldCancel: (MarketBuyer) -> Bool
    ) -> [Int] {
        let ids = Set(buyers.filter(shouldCancel).map(\.id))
        guard !ids.isEmpty else { return [] }
        buyers.removeAll { ids.contains($0.id) }
        for index in markets.indices {
            markets[index].activeBuyerByCommodityID = markets[index]
                .activeBuyerByCommodityID.filter { !ids.contains($0.value) }
        }
        return ids.sorted()
    }

    @discardableResult
    public mutating func advanceMonth(
        houses: inout [ResidentialUnit],
        logistics: inout DeterministicLogisticsState,
        production: inout DeterministicProductionState,
        roadNetwork: RoadNetwork,
        models: OriginalEconomyModels,
        replaySeed: UInt64,
        barrierPoints: Set<GridPoint> = []
    ) -> MarketMonthlySettlement {
        let buyerRange = max(1, models.figures[figureID: OriginalMarketCatalog.buyerFigureID]?.behaviorRange ?? 50)
        let peddlerRange = max(1, models.figures[figureID: OriginalMarketCatalog.peddlerFigureID]?.behaviorRange ?? 60)
        scheduleBuyers(
            houses: houses,
            logistics: &logistics,
            production: &production,
            roadNetwork: roadNetwork,
            models: models.buildings,
            maximumOneWayRoadSteps: buyerRange
        )
        _ = advanceBuyers(roadStepsPerBuyer: buyerRange)
        schedulePeddlers(
            houses: houses,
            roadNetwork: roadNetwork,
            models: models.buildings,
            maximumRoadSteps: peddlerRange,
            replaySeed: replaySeed,
            barrierPoints: barrierPoints
        )
        _ = advancePeddlers(
            roadStepsPerPeddler: peddlerRange,
            houses: &houses,
            models: models.buildings,
            barrierPoints: barrierPoints
        )
        return settleMonth(houses: &houses, models: models.buildings)
    }

    /// Consumes household stock and closes the current market accounting month.
    /// Buyer and peddler movement must happen through the explicit step methods.
    @discardableResult
    public mutating func settleMonth(
        houses: inout [ResidentialUnit],
        models: BuildingModelTable
    ) -> MarketMonthlySettlement {
        let consumption = consumeHouseholdCommodities(
            houses: &houses,
            models: models
        )
        let underSupplied = Set(
            consumption.filter { $0.consumedAmount < $0.requestedAmount }.map(\.houseID)
        ).sorted()
        let settlement = MarketMonthlySettlement(
            purchasedLoads: purchasedLoadsThisMonthStorage ?? [],
            householdDeliveries: householdDeliveriesThisMonthStorage ?? [],
            householdConsumption: consumption,
            underSuppliedHouseIDs: underSupplied
        )
        lastSettlement = settlement
        purchasedLoadsThisMonthStorage = []
        householdDeliveriesThisMonthStorage = []
        return settlement
    }

    public mutating func scheduleBuyers(
        houses: [ResidentialUnit],
        logistics: inout DeterministicLogisticsState,
        production: inout DeterministicProductionState,
        roadNetwork: RoadNetwork,
        models: BuildingModelTable,
        maximumOneWayRoadSteps: Int,
        activeMarketIDs: Set<Int>? = nil,
        activeMillIDs: Set<Int>? = nil
    ) {
        for marketIndex in markets.indices.sorted(by: { markets[$0].id < markets[$1].id }) {
            let marketID = markets[marketIndex].id
            guard activeMarketIDs?.contains(marketID) ?? true else { continue }
            let marketRoad = markets[marketIndex].roadAccessPoint
            for commodityID in markets[marketIndex].stockedCommodityIDs.sorted() {
                guard markets[marketIndex].inventoryByCommodityID[commodityID, default: 0] < 100,
                      markets[marketIndex].activeBuyerByCommodityID[commodityID] == nil,
                      houses.contains(where: { Self.house($0, needs: commodityID, models: models) }),
                      let target = nearestWarehouse(
                        commodityID: commodityID,
                        marketRoad: marketRoad,
                        logistics: logistics,
                        roadNetwork: roadNetwork,
                        maximumSteps: maximumOneWayRoadSteps
                      ) else { continue }
                let amount = min(100, target.available)
                let taken = logistics.takeStoredGoods(
                    warehouseID: target.warehouseID,
                    commodityID: commodityID,
                    amount: amount,
                    production: &production
                )
                guard taken > 0 else { continue }
                let buyerID = nextBuyerID
                nextBuyerID += 1
                buyers.append(MarketBuyer(
                    id: buyerID,
                    marketID: marketID,
                    warehouseID: target.warehouseID,
                    cargoes: [DeliveryCargo(commodityID: commodityID, amount: taken)],
                    outboundPath: target.path
                ))
                markets[marketIndex].activeBuyerByCommodityID[commodityID] = buyerID
            }

            let storedFood = markets[marketIndex].inventoryByCommodityID.reduce(0) { partial, entry in
                partial + (OriginalFoodCatalog.isMillCommodity(entry.key) ? entry.value : 0)
            }
            if markets[marketIndex].hasFoodShop,
               storedFood < 100,
               markets[marketIndex].activeBuyerByCommodityID[-1] == nil,
               houses.contains(where: { Self.houseNeedsFood($0, models: models) }),
               let target = nearestMill(
                marketRoad: marketRoad,
                logistics: logistics,
                roadNetwork: roadNetwork,
                maximumSteps: maximumOneWayRoadSteps,
                activeMillIDs: activeMillIDs
               ) {
                let cargoes = logistics.takeFoodBundle(
                    millID: target.millID,
                    maximumAmount: 100,
                    production: &production
                )
                if !cargoes.isEmpty {
                    let buyerID = nextBuyerID
                    nextBuyerID += 1
                    buyers.append(MarketBuyer(
                        id: buyerID,
                        marketID: marketID,
                        millID: target.millID,
                        cargoes: cargoes,
                        outboundPath: target.path
                    ))
                    markets[marketIndex].activeBuyerByCommodityID[-1] = buyerID
                }
            }
        }
    }

    public mutating func advanceBuyers(
        roadStepsPerBuyer: Int,
        activeMarketIDs: Set<Int>? = nil
    ) -> [DeliveryCargo] {
        var purchased: [DeliveryCargo] = []
        var completedIDs: [Int] = []
        for index in buyers.indices.sorted(by: { buyers[$0].id < buyers[$1].id }) {
            guard activeMarketIDs?.contains(buyers[index].marketID) ?? true else { continue }
            for _ in 0..<max(0, roadStepsPerBuyer) {
                _ = buyers[index].advanceOneRoadStep()
                if buyers[index].hasReturned { break }
            }
            guard buyers[index].hasReturned,
                  let marketIndex = markets.firstIndex(where: { $0.id == buyers[index].marketID }) else { continue }
            for cargo in buyers[index].cargoes {
                markets[marketIndex].inventoryByCommodityID[cargo.commodityID, default: 0] += cargo.amount
            }
            markets[marketIndex].activeBuyerByCommodityID = markets[marketIndex]
                .activeBuyerByCommodityID.filter { $0.value != buyers[index].id }
            purchased.append(contentsOf: buyers[index].cargoes)
            completedIDs.append(buyers[index].id)
        }
        buyers.removeAll { completedIDs.contains($0.id) }
        purchasedLoadsThisMonthStorage = (purchasedLoadsThisMonthStorage ?? []) + purchased
        return purchased
    }

    /// Advances marketplace buyers by original figure updates. Model 24 uses
    /// selector 8, so each update contributes the recovered 1/1/2 substep
    /// cadence and a route point advances only at the twentieth substep.
    /// The explicit road-step API above remains for old fixtures and callers
    /// that intentionally exercise the pre-cadence compatibility path.
    public mutating func advanceOriginalBuyers(
        originalFigureUpdatesPerBuyer: Int,
        activeMarketIDs: Set<Int>? = nil
    ) -> [DeliveryCargo] {
        var purchased: [DeliveryCargo] = []
        var completedIDs: [Int] = []
        for index in buyers.indices.sorted(by: { buyers[$0].id < buyers[$1].id }) {
            guard activeMarketIDs?.contains(buyers[index].marketID) ?? true else { continue }
            for _ in 0..<max(0, originalFigureUpdatesPerBuyer) {
                _ = buyers[index].advanceOriginalFigureUpdate()
                if buyers[index].hasReturned { break }
            }
            guard buyers[index].hasReturned,
                  let marketIndex = markets.firstIndex(where: { $0.id == buyers[index].marketID }) else { continue }
            for cargo in buyers[index].cargoes {
                markets[marketIndex].inventoryByCommodityID[cargo.commodityID, default: 0] += cargo.amount
            }
            markets[marketIndex].activeBuyerByCommodityID = markets[marketIndex]
                .activeBuyerByCommodityID.filter { $0.value != buyers[index].id }
            purchased.append(contentsOf: buyers[index].cargoes)
            completedIDs.append(buyers[index].id)
        }
        buyers.removeAll { completedIDs.contains($0.id) }
        purchasedLoadsThisMonthStorage = (purchasedLoadsThisMonthStorage ?? []) + purchased
        return purchased
    }

    public mutating func schedulePeddlers(
        houses: [ResidentialUnit],
        roadNetwork: RoadNetwork,
        models: BuildingModelTable,
        maximumRoadSteps: Int,
        replaySeed: UInt64,
        activeMarketIDs: Set<Int>? = nil,
        barrierPoints: Set<GridPoint> = [],
        originalSpawnGate: Bool = false,
        workerPercentByMarketID: [Int: Int] = [:],
        allowCompatibilityRouteFallback: Bool = false
    ) {
        for marketIndex in markets.indices.sorted(by: { markets[$0].id < markets[$1].id }) {
            let marketID = markets[marketIndex].id
            guard activeMarketIDs?.contains(marketID) ?? true else { continue }
            var freeSlots = markets[marketIndex].peddlerCapacity
                - peddlers.count(where: { $0.marketID == marketID })
            guard freeSlots > 0 else { continue }
            if originalSpawnGate {
                // FUN_00543ED0 derives this value from the unresolved cStall
                // `+0x44` aggregate and the filled-shop employee total. A
                // missing entry is not equivalent to 100%; keep the original
                // timing bridge fail-closed until the raw producer is mapped.
                guard let workerPercent = workerPercentByMarketID[marketID] else {
                    continue
                }
                guard workerPercent > 0,
                      markets[marketIndex].consumeOriginalPeddlerSpawnOpportunity(
                          workerPercent: workerPercent
                      ) else { continue }
                // FUN_0051CF90 creates at most one figure per provider call.
                freeSlots = min(freeSlots, 1)
            }
            for commodityID in markets[marketIndex].stockedCommodityIDs.sorted() where freeSlots > 0 {
                let available = markets[marketIndex].inventoryByCommodityID[commodityID, default: 0]
                guard available > 0,
                      !peddlers.contains(where: { $0.marketID == marketID && $0.commodityID == commodityID }),
                      houses.contains(where: { Self.house($0, needs: commodityID, models: models) }) else { continue }
                let amount = min(100, available)
                let route: [GridPoint]?
                if originalSpawnGate && !allowCompatibilityRouteFallback {
                    // The recovered model-23 path starts from a map-cache
                    // endpoint selected by FUN_004E3A80/FUN_004BA370. The
                    // household-targeting route below is only a compatibility
                    // fixture and must never stand in for that missing map
                    // projection in a campaign-backed city.
                    route = nil
                } else {
                    route = Self.deliveryRoute(
                        from: markets[marketIndex].roadAccessPoint,
                        commodityID: commodityID,
                        houses: houses,
                        models: models,
                        roadNetwork: roadNetwork,
                        maximumRoadSteps: maximumRoadSteps,
                        barrierPoints: barrierPoints
                    ) ?? DeterministicRoadPatrol.route(
                        from: markets[marketIndex].roadAccessPoint,
                        maximumRoadSteps: maximumRoadSteps,
                        roadNetwork: roadNetwork,
                        replaySeed: replaySeed ^ UInt64(marketID),
                        trip: nextPeddlerID,
                        barrierPoints: barrierPoints
                    )
                }
                guard let route, !route.isEmpty else { continue }
                markets[marketIndex].inventoryByCommodityID[commodityID, default: 0] -= amount
                peddlers.append(MarketPeddler(
                    id: nextPeddlerID,
                    marketID: marketID,
                    commodityID: commodityID,
                    amount: amount,
                    route: route
                ))
                if originalSpawnGate {
                    // FUN_00543ED0 advances cMarket +0x38 only after the
                    // model-23 allocation succeeds.
                    markets[marketIndex].advanceOriginalPeddlerSpawnRotation()
                }
                nextPeddlerID += 1
                freeSlots -= 1
            }
            if freeSlots > 0,
               markets[marketIndex].hasFoodShop,
               !peddlers.contains(where: { $0.marketID == marketID && $0.commodityID == -1 }),
               houses.contains(where: { Self.houseNeedsFood($0, models: models) }) {
                if originalSpawnGate && !allowCompatibilityRouteFallback {
                    // Do not withdraw a food bundle before the unresolved
                    // model-23 endpoint has been recovered. The original
                    // timing bridge must leave campaign stock unchanged when
                    // it cannot prove an allocation.
                    continue
                }
                let quality = OriginalFoodCatalog.quality(
                    in: markets[marketIndex].inventoryByCommodityID
                )
                let cargoes = takeMarketFoodBundle(at: marketIndex, maximumAmount: 100)
                let amount = cargoes.reduce(0) { $0 + $1.amount }
                let route = DeterministicRoadPatrol.route(
                    from: markets[marketIndex].roadAccessPoint,
                    maximumRoadSteps: maximumRoadSteps,
                    roadNetwork: roadNetwork,
                    replaySeed: replaySeed ^ UInt64(marketID),
                    trip: nextPeddlerID,
                    barrierPoints: barrierPoints
                )
                if amount > 0, quality != .none, !route.isEmpty {
                    peddlers.append(MarketPeddler(
                        id: nextPeddlerID,
                        marketID: marketID,
                        commodityID: -1,
                        amount: amount,
                        route: route,
                        foodQuality: quality,
                        foodCargoes: cargoes
                    ))
                    if originalSpawnGate {
                        // The food peddler is the same model-23 allocation
                        // path; rotate only after the figure is created.
                        markets[marketIndex].advanceOriginalPeddlerSpawnRotation()
                    }
                    nextPeddlerID += 1
                } else {
                    restoreFoodBundle(cargoes, toMarketAt: marketIndex)
                }
            }
        }
    }

    /// Advances the original 51-step provider scheduler and evaluates market
    /// peddler spawn opportunities at phase `0x1F`. This is the production
    /// bridge; the older direct `schedulePeddlers` API intentionally remains
    /// available for deterministic fixtures that model an already-issued
    /// spawn request. `allowCompatibilityRouteFallback` is reserved for
    /// unscoped native sandbox cities and keeps those historical fixtures
    /// running; campaign-backed runs leave it false until the original route
    /// writer is recovered.
    public mutating func advanceOriginalPeddlerSpawnScheduler(
        originalSteps: Int,
        houses: [ResidentialUnit],
        roadNetwork: RoadNetwork,
        models: BuildingModelTable,
        maximumRoadSteps: Int,
        replaySeed: UInt64,
        activeMarketIDs: Set<Int>? = nil,
        workerPercentByMarketID: [Int: Int] = [:],
        barrierPoints: Set<GridPoint> = [],
        allowCompatibilityRouteFallback: Bool = false
    ) {
        for _ in 0..<max(0, originalSteps) {
            let phase = originalSchedulerPhaseState ?? 0
            if phase == 0x1F {
                schedulePeddlers(
                    houses: houses,
                    roadNetwork: roadNetwork,
                    models: models,
                    maximumRoadSteps: maximumRoadSteps,
                    replaySeed: replaySeed,
                    activeMarketIDs: activeMarketIDs,
                    barrierPoints: barrierPoints,
                    originalSpawnGate: true,
                    workerPercentByMarketID: workerPercentByMarketID,
                    allowCompatibilityRouteFallback: allowCompatibilityRouteFallback
                )
            }
            originalSchedulerPhaseState = (phase + 1) % 0x33
        }
    }

    public mutating func advancePeddlers(
        roadStepsPerPeddler: Int,
        houses: inout [ResidentialUnit],
        models: BuildingModelTable,
        activeMarketIDs: Set<Int>? = nil,
        barrierPoints: Set<GridPoint> = []
    ) -> [HouseholdCommodityDelivery] {
        var deliveries: [HouseholdCommodityDelivery] = []
        var completedIDs: [Int] = []
        for index in peddlers.indices.sorted(by: { peddlers[$0].id < peddlers[$1].id }) {
            guard activeMarketIDs?.contains(peddlers[index].marketID) ?? true else { continue }
            distribute(at: index, houses: &houses, models: models, deliveries: &deliveries)
            for _ in 0..<max(0, roadStepsPerPeddler) {
                let moved = peddlers[index].advanceOneRoadStep(
                    barrierPoints: barrierPoints
                )
                guard moved else {
                    if peddlers[index].hasCompletedRoute {
                        distribute(at: index, houses: &houses, models: models, deliveries: &deliveries)
                    }
                    break
                }
                distribute(at: index, houses: &houses, models: models, deliveries: &deliveries)
                if peddlers[index].hasCompletedRoute { break }
            }
            guard peddlers[index].hasCompletedRoute else { continue }
            if peddlers[index].remainingAmount > 0,
               let marketIndex = markets.firstIndex(where: { $0.id == peddlers[index].marketID }) {
                if let foodCargoes = peddlers[index].foodCargoes {
                    restoreFoodBundle(foodCargoes, toMarketAt: marketIndex)
                } else {
                    markets[marketIndex].inventoryByCommodityID[peddlers[index].commodityID, default: 0]
                        += peddlers[index].remainingAmount
                }
            }
            completedIDs.append(peddlers[index].id)
        }
        peddlers.removeAll { completedIDs.contains($0.id) }
        householdDeliveriesThisMonthStorage = (householdDeliveriesThisMonthStorage ?? []) + deliveries
        return deliveries
    }

    /// Advances peddlers by original figure updates. Model 23's selector-8
    /// phase is persisted on each figure; the unresolved route/coverage
    /// provider-selection semantics remain the same fail-closed Native
    /// boundary as above. At each confirmed route crossing, the shared
    /// radius-two object scan is now used before the market-specific stock
    /// and commodity gates are applied.
    public mutating func advanceOriginalPeddlers(
        originalFigureUpdatesPerPeddler: Int,
        houses: inout [ResidentialUnit],
        models: BuildingModelTable,
        activeMarketIDs: Set<Int>? = nil,
        barrierPoints: Set<GridPoint> = [],
        coverageBlockerPoints: Set<GridPoint> = []
    ) -> [HouseholdCommodityDelivery] {
        var deliveries: [HouseholdCommodityDelivery] = []
        var completedIDs: [Int] = []
        for index in peddlers.indices.sorted(by: { peddlers[$0].id < peddlers[$1].id }) {
            guard activeMarketIDs?.contains(peddlers[index].marketID) ?? true else { continue }
            distribute(
                at: index,
                houses: &houses,
                models: models,
                deliveries: &deliveries,
                usesOriginalCoverageScan: true,
                appliesOriginalFoodCallbackCap: true,
                coverageBlockerPoints: coverageBlockerPoints
            )
            for _ in 0..<max(0, originalFigureUpdatesPerPeddler) {
                let moved = peddlers[index].advanceOriginalFigureUpdate(
                    barrierPoints: barrierPoints
                )
                if moved > 0 {
                    distribute(
                        at: index,
                        houses: &houses,
                        models: models,
                        deliveries: &deliveries,
                        usesOriginalCoverageScan: true,
                        appliesOriginalFoodCallbackCap: true,
                        coverageBlockerPoints: coverageBlockerPoints
                    )
                }
                if peddlers[index].hasCompletedRoute { break }
            }
            guard peddlers[index].hasCompletedRoute else { continue }
            if peddlers[index].remainingAmount > 0,
               let marketIndex = markets.firstIndex(where: { $0.id == peddlers[index].marketID }) {
                if let foodCargoes = peddlers[index].foodCargoes {
                    restoreFoodBundle(foodCargoes, toMarketAt: marketIndex)
                } else {
                    markets[marketIndex].inventoryByCommodityID[peddlers[index].commodityID, default: 0]
                        += peddlers[index].remainingAmount
                }
            }
            completedIDs.append(peddlers[index].id)
        }
        peddlers.removeAll { completedIDs.contains($0.id) }
        householdDeliveriesThisMonthStorage = (householdDeliveriesThisMonthStorage ?? []) + deliveries
        return deliveries
    }

    private mutating func distribute(
        at peddlerIndex: Int,
        houses: inout [ResidentialUnit],
        models: BuildingModelTable,
        deliveries: inout [HouseholdCommodityDelivery],
        usesOriginalCoverageScan: Bool = false,
        appliesOriginalFoodCallbackCap: Bool = false,
        coverageBlockerPoints: Set<GridPoint> = []
    ) {
        guard peddlers[peddlerIndex].remainingAmount > 0,
              let roadPoint = peddlers[peddlerIndex].currentPoint else { return }
        let commodityID = peddlers[peddlerIndex].commodityID
        // `FUN_004EACD0 → FUN_00429E10` scans the two rings around the figure
        // and applies the market callback to each visible residential object.
        // That recovered geometry belongs only to the original-timing bridge;
        // the older direct `advancePeddlers` API remains a fixture route with
        // its historical road-neighbor boundary.
        let candidateHouseIndices: [Int]
        if usesOriginalCoverageScan {
            candidateHouseIndices = Array(
                OriginalResidentialServiceCoverage.houseIndices(
                    servicedFrom: roadPoint,
                    service: .water,
                    providerBuildingID: nil,
                    houses: houses,
                    blockerPoints: coverageBlockerPoints
                )
            )
        } else {
            candidateHouseIndices = houses.indices.filter { houseIndex in
                guard let location = houses[houseIndex].location else { return false }
                return Self.roadNeighbors(of: houses[houseIndex], at: location)
                    .contains(roadPoint)
            }
        }
        for houseIndex in candidateHouseIndices.sorted(by: { houses[$0].id < houses[$1].id }) {
            guard peddlers[peddlerIndex].remainingAmount > 0,
                  houses[houseIndex].houseLevelID >= 0,
                  houses[houseIndex].houseLevelID < 15,
                  houses[houseIndex].residents > 0,
                  houses[houseIndex].location != nil else { continue }
            let desiredStock = houses[houseIndex].residents * 2
            let needed: Int
            if commodityID == -1 {
                guard Self.houseNeedsFood(houses[houseIndex], models: models) else { continue }
                let uncapped = max(0, desiredStock - houses[houseIndex].foodSupplyAmount)
                if appliesOriginalFoodCallbackCap {
                    needed = min(
                        uncapped,
                        OriginalMarketFoodDeliveryDemand.resolve(
                            residents: houses[houseIndex].residents,
                            currentStock: houses[houseIndex].foodSupplyAmount
                        ).perCallbackCap
                    )
                } else {
                    needed = uncapped
                }
            } else {
                guard Self.house(houses[houseIndex], needs: commodityID, models: models) else { continue }
                needed = max(0, desiredStock - houses[houseIndex][commodityID: commodityID])
            }
            let amount = peddlers[peddlerIndex].deliver(needed)
            guard amount > 0 else { continue }
            if commodityID == -1 {
                let qualityRawValue = peddlers[peddlerIndex].foodQualityRawValue ?? 0
                houses[houseIndex].addFoodSupply(
                    amount: amount,
                    qualityRawValue: qualityRawValue
                )
            } else {
                houses[houseIndex].addSupply(commodityID: commodityID, amount: amount)
            }
            deliveries.append(HouseholdCommodityDelivery(
                houseID: houses[houseIndex].id,
                commodityID: commodityID,
                amount: amount
            ))
        }
    }

    private func consumeHouseholdCommodities(
        houses: inout [ResidentialUnit],
        models: BuildingModelTable
    ) -> [HouseholdCommodityConsumption] {
        var result: [HouseholdCommodityConsumption] = []
        // FUN_00518690 walks the runtime house vector from begin to end; it
        // never sorts by the object's registry/id field. Preserve the
        // persisted array order so per-house mutation and the consumption
        // record sequence remain replay-equivalent.
        for index in houses.indices {
            guard houses[index].residents > 0,
                  let model = models[houseLevelID: houses[index].houseLevelID] else { continue }
            let evolutionFoodQualityRawValue = houses[index].foodSupplyAmount >= houses[index].residents
                ? houses[index].foodQualityRawValue
                : FoodQuality.none.rawValue
            let physicallyStockedCommodityIDs = Set(
                DeterministicHousingEvolution.marketCommodityIDs.filter {
                    houses[index][commodityID: $0] >= houses[index].residents
                }
            )
            let deliveredCommodityIDs = Set(
                (householdDeliveriesThisMonthStorage ?? []).compactMap {
                    $0.houseID == houses[index].id && $0.commodityID >= 0
                        ? $0.commodityID : nil
                }
            )
            houses[index].recordEvolutionSupplies(
                foodQualityRawValue: evolutionFoodQualityRawValue,
                commodityIDs: physicallyStockedCommodityIDs.union(deliveredCommodityIDs)
            )
            var hasShortage = false
            if model.foodQualityRequired > 0 {
                // FUN_00518690 calls FUN_00408B80(house+0x20, 0x19): the
                // month-settlement Dinners draw is floor(residents * 25 / 100),
                // not one unit per resident. Keep the original integer
                // truncation before consuming the save-backed stock word.
                let requested = houses[index].residents * 25 / 100
                let suppliedQualityRawValue = houses[index].foodQualityRawValue
                let consumed = houses[index].consumeFood(requested)
                let meetsQuality = suppliedQualityRawValue >= model.foodQualityRequired
                let effectiveConsumption = meetsQuality ? consumed : 0
                result.append(HouseholdCommodityConsumption(
                    houseID: houses[index].id,
                    commodityID: -1,
                    requestedAmount: requested,
                    consumedAmount: effectiveConsumption
                ))
                hasShortage = consumed < requested || !meetsQuality
            }
            for alternatives in Self.requiredCommodityAlternatives(for: model) {
                let commodityID = alternatives.max {
                    houses[index][commodityID: $0] < houses[index][commodityID: $1]
                } ?? alternatives[0]
                let requested = houses[index].residents
                let consumed = houses[index].consumeSupply(
                    commodityID: commodityID,
                    amount: requested
                )
                result.append(HouseholdCommodityConsumption(
                    houseID: houses[index].id,
                    commodityID: commodityID,
                    requestedAmount: requested,
                    consumedAmount: consumed
                ))
                hasShortage = hasShortage || consumed < requested
            }
            houses[index].commodityShortageMonths = hasShortage
                ? houses[index].commodityShortageMonths + 1 : 0
        }
        return result
    }

    private func nearestWarehouse(
        commodityID: Int,
        marketRoad: GridPoint,
        logistics: DeterministicLogisticsState,
        roadNetwork: RoadNetwork,
        maximumSteps: Int
    ) -> (warehouseID: Int, available: Int, path: [GridPoint])? {
        logistics.warehouses.compactMap { warehouse -> (Int, Int, [GridPoint])? in
            let available = warehouse.inventoryByCommodityID[commodityID, default: 0]
            guard available > 0,
                  let path = GridPathfinder.shortestPath(
                    width: roadNetwork.width,
                    height: roadNetwork.height,
                    from: marketRoad,
                    to: warehouse.roadAccessPoint,
                    isPassable: roadNetwork.contains
                  ), path.count - 1 <= maximumSteps else { return nil }
            return (warehouse.id, available, path)
        }.min {
            if $0.2.count != $1.2.count { return $0.2.count < $1.2.count }
            return $0.0 < $1.0
        }
    }

    private func nearestMill(
        marketRoad: GridPoint,
        logistics: DeterministicLogisticsState,
        roadNetwork: RoadNetwork,
        maximumSteps: Int,
        activeMillIDs: Set<Int>? = nil
    ) -> (millID: Int, path: [GridPoint])? {
        logistics.mills.compactMap { mill -> (Int, [GridPoint])? in
            guard activeMillIDs?.contains(mill.id) ?? true,
                  mill.foodQuality != .none,
                  !logistics.hasIncomingFoodDelivery(toMillID: mill.id),
                  let path = GridPathfinder.shortestPath(
                    width: roadNetwork.width,
                    height: roadNetwork.height,
                    from: marketRoad,
                    to: mill.roadAccessPoint,
                    isPassable: roadNetwork.contains
                  ), path.count - 1 <= maximumSteps else { return nil }
            return (mill.id, path)
        }.min {
            if $0.1.count != $1.1.count { return $0.1.count < $1.1.count }
            return $0.0 < $1.0
        }
    }

    private mutating func takeMarketFoodBundle(
        at marketIndex: Int,
        maximumAmount: Int
    ) -> [DeliveryCargo] {
        let stockedIDs = markets[marketIndex].inventoryByCommodityID.keys
            .filter {
                OriginalFoodCatalog.isMillCommodity($0)
                    && markets[marketIndex].inventoryByCommodityID[$0, default: 0] > 0
            }
            .sorted()
        let total = stockedIDs.reduce(0) {
            $0 + markets[marketIndex].inventoryByCommodityID[$1, default: 0]
        }
        var remaining = min(max(0, maximumAmount), total)
        var amounts: [Int: Int] = [:]
        while remaining > 0 {
            let activeIDs = stockedIDs.filter {
                markets[marketIndex].inventoryByCommodityID[$0, default: 0] > 0
            }
            guard !activeIDs.isEmpty else { break }
            let share = max(1, remaining / activeIDs.count)
            var moved = 0
            for commodityID in activeIDs where remaining > 0 {
                let available = markets[marketIndex].inventoryByCommodityID[commodityID, default: 0]
                let taken = min(share, available, remaining)
                markets[marketIndex].inventoryByCommodityID[commodityID] = available - taken
                amounts[commodityID, default: 0] += taken
                remaining -= taken
                moved += taken
            }
            guard moved > 0 else { break }
        }
        return amounts.keys.sorted().map {
            DeliveryCargo(commodityID: $0, amount: amounts[$0, default: 0])
        }
    }

    private mutating func restoreFoodBundle(_ cargoes: [DeliveryCargo], toMarketAt index: Int) {
        for cargo in cargoes {
            markets[index].inventoryByCommodityID[cargo.commodityID, default: 0] += cargo.amount
        }
    }

    private static func house(
        _ house: ResidentialUnit,
        needs commodityID: Int,
        models: BuildingModelTable
    ) -> Bool {
        guard house.residents > 0 else { return false }
        let levels = [house.houseLevelID, nextHouseLevel(after: house.houseLevelID)].compactMap { $0 }
        return levels.contains { level in
            guard let model = models[houseLevelID: level] else { return false }
            return requiredCommodityAlternatives(for: model).contains { $0.contains(commodityID) }
        }
    }

    private static func roadNeighbors(
        of house: ResidentialUnit,
        at location: GridPoint
    ) -> Set<GridPoint> {
        let buildingID = house.houseLevelID + 3
        let footprint = OriginalBuildingFootprintCatalog
            .footprint(forBuildingID: buildingID)
            ?? BuildingFootprint(width: 1, height: 1)
        return Set(
            footprint.points(at: location)
                .flatMap(RoadServiceCoverage.orthogonalNeighbors(of:))
        ).subtracting(footprint.points(at: location))
    }

    /// Native's existing household-delivery approximation. The exact original
    /// roaming branch selection is still unknown, but the recovered roadblock
    /// contract is not: a peddler route must never enter a barrier tile.
    private static func deliveryRoute(
        from marketRoad: GridPoint,
        commodityID: Int,
        houses: [ResidentialUnit],
        models: BuildingModelTable,
        roadNetwork: RoadNetwork,
        maximumRoadSteps: Int,
        barrierPoints: Set<GridPoint>
    ) -> [GridPoint]? {
        let isPassable: (GridPoint) -> Bool = {
            roadNetwork.contains($0) && !barrierPoints.contains($0)
        }
        var remaining = houses
            .filter {
                house($0, needs: commodityID, models: models)
                    && $0[commodityID: commodityID] < $0.residents * 2
            }
            .filter { house in
                guard let location = house.location else { return false }
                return roadNeighbors(of: house, at: location).contains {
                    GridPathfinder.shortestPath(
                        width: roadNetwork.width,
                        height: roadNetwork.height,
                        from: marketRoad,
                        to: $0,
                        isPassable: isPassable
                    ).map { $0.count - 1 <= maximumRoadSteps * 2 } ?? false
                }
            }
        guard !remaining.isEmpty else { return nil }

        var route = [marketRoad]
        var current = marketRoad
        while !remaining.isEmpty {
            let candidates = remaining.compactMap {
                house -> (house: ResidentialUnit, path: [GridPoint])? in
                guard let location = house.location else { return nil }
                let path = roadNeighbors(of: house, at: location).compactMap {
                    GridPathfinder.shortestPath(
                        width: roadNetwork.width,
                        height: roadNetwork.height,
                        from: current,
                        to: $0,
                        isPassable: isPassable
                    )
                }.min(by: { $0.count < $1.count })
                return path.map { (house, $0) }
            }
            guard let next = candidates.min(by: {
                if $0.house.houseLevelID != $1.house.houseLevelID {
                    return $0.house.houseLevelID > $1.house.houseLevelID
                }
                if $0.path.count != $1.path.count {
                    return $0.path.count < $1.path.count
                }
                return $0.house.id < $1.house.id
            }) else { break }
            route.append(contentsOf: next.path.dropFirst())
            current = next.path.last ?? current
            remaining.removeAll { $0.id == next.house.id }
        }
        guard route.count > 1,
              let returnPath = GridPathfinder.shortestPath(
                width: roadNetwork.width,
                height: roadNetwork.height,
                from: current,
                to: marketRoad,
                isPassable: isPassable
              ) else { return nil }
        route.append(contentsOf: returnPath.dropFirst())
        return route
    }

    private static func houseNeedsFood(
        _ house: ResidentialUnit,
        models: BuildingModelTable
    ) -> Bool {
        guard house.residents > 0 else { return false }
        let levels = [house.houseLevelID, nextHouseLevel(after: house.houseLevelID)].compactMap { $0 }
        return levels.contains { level in
            models[houseLevelID: level]?.foodQualityRequired ?? 0 > 0
        }
    }

    private static func nextHouseLevel(after level: Int) -> Int? {
        switch level {
        case 0..<7: level + 1
        case 8..<14: level + 1
        default: nil
        }
    }

    private static func requiredCommodityAlternatives(for model: HouseModel) -> [[Int]] {
        var result: [[Int]] = []
        if model.hempRequired > 0 { result.append([19]) }
        if model.ceramicsRequired > 0 { result.append([25]) }
        if model.teaRequired > 0 { result.append([13]) }
        if model.silkRequired > 0 { result.append([24]) }
        if model.luxuryWareRequired > 0 { result.append([23, 22]) }
        return result
    }
}
