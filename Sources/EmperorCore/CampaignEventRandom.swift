import Foundation

/// Explicit research model of the event-manager random stream recovered from
/// `FUN_004189B0 @ 0x4189B0`.
///
/// The executable keeps two independent 32-bit shift-register words.  Each
/// advance performs the same 31-round feedback step on both words, then
/// exposes low-bit projections of the primary word.  This helper is not wired
/// to `CampaignEventScheduler`: the stream is shared by unrelated figure,
/// trade, building, and network callers, so a Qin scheduler cannot consume it
/// faithfully until the complete call order is recovered.
public struct OriginalEventManagerRandomState: Sendable, Hashable, Codable {
    public static let startupPrimarySeed: UInt32 = 0x5465_7687
    public static let startupSecondarySeed: UInt32 = 0x7264_1663

    /// Direct `CALL rel32` callers recovered from the hash-matched EN/CH
    /// `.text` sections. This is a consumer-census boundary only: several
    /// callers are unrelated to campaign events, and indirect/vtable calls
    /// are not represented. The shared stream must not be wired to a Qin
    /// scheduler until the complete runtime call order is recovered.
    public static let directCallerAddresses: [UInt32] = [
        0x0041_89A0, 0x0043_FF00, 0x0044_0700, 0x0044_1940,
        0x0044_20E0, 0x0044_2200, 0x0044_4490, 0x0044_4D40,
        0x0044_4F60, 0x0048_8940, 0x0048_93F0, 0x0049_25F0,
        0x0049_3530, 0x0049_3B60, 0x0049_4440, 0x0049_44A0,
        0x0049_4EA0, 0x0049_6E60, 0x0049_7670, 0x0049_8F60,
        0x0049_9150, 0x0049_F8B0, 0x004A_3280, 0x004A_8ED0,
        0x004A_90A0, 0x004A_9300, 0x004B_0AC0, 0x004B_AB00,
        0x004E_71D0, 0x0050_9670, 0x0052_2AE0, 0x0052_9A80,
        0x0052_CAF0, 0x0053_5540, 0x0053_71A0, 0x0054_DB10,
        0x0054_DF70, 0x0054_E870, 0x005A_0340, 0x005A_0550,
        0x005C_80E0, 0x005C_88E0, 0x005C_89F0, 0x005E_7140,
        0x005E_7CC0,
    ]

    public private(set) var primaryState: UInt32
    public private(set) var secondaryState: UInt32

    public init(
        primaryState: UInt32 = Self.startupPrimarySeed,
        secondaryState: UInt32 = Self.startupSecondarySeed
    ) {
        self.primaryState = primaryState
        self.secondaryState = secondaryState
    }

    public var primaryLow15: UInt32 { primaryState & 0x7FFF }
    public var primaryLow7: UInt32 { primaryState & 0x7F }
    public var primaryLow3: UInt32 { primaryState & 7 }

    /// Mirrors the source's 100-call warm-up after startup seed/reset.
    public mutating func warmUp(iterations: Int = 100) {
        guard iterations > 0 else { return }
        for _ in 0..<iterations { advance() }
    }

    /// Advances both source words once and returns the primary low-7 value
    /// exposed as `DAT_010C713C`.
    @discardableResult
    public mutating func advance() -> UInt32 {
        for _ in 0..<31 {
            let primaryBit4 = (primaryState >> 4) & 1
            let primaryBit0 = primaryState & 1
            let secondaryBit4 = (secondaryState >> 4) & 1
            let secondaryBit0 = secondaryState & 1
            primaryState >>= 1
            secondaryState >>= 1
            if primaryBit4 != primaryBit0 { primaryState |= 0x4000_0000 }
            if secondaryBit4 != secondaryBit0 { secondaryState |= 0x4000_0000 }
        }
        return primaryLow7
    }

    /// Mirrors the initial-wait branch in `FUN_0049F8B0`.  The raw event type
    /// is intentionally explicit; its semantic mapping to authored campaign
    /// kinds remains unresolved.  The source consumes three RNG advances for
    /// every call, including formulas that use fewer saved projections.
    public mutating func nextWaitTicks(forRawEventType rawType: UInt8) -> Int {
        let first = advance()
        let second = advance()
        let third = advance()
        switch rawType {
        case 0, 1, 2:
            return 3 + Int(first % 12) + Int(second % 12) + Int(third % 12)
        case 3:
            return 2 + Int(first % 3) + Int(second % 3)
        case 4:
            return 12 + Int(first % 13) + Int(second % 13)
        case 5:
            return 1 + Int(first % 3)
        case 6:
            return 7 + Int(first % 10) + Int(second % 10) + Int(third % 10)
        default:
            return 24
        }
    }
}
