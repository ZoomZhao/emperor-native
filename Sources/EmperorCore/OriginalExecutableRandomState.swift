import Foundation

/// The shared two-register random state recovered from the canonical English
/// executable.  This is a source-backed replay primitive, not a replacement
/// for any caller whose random-call order is still unknown.
public struct OriginalExecutableRandomSnapshot: Sendable, Hashable, Codable {
    public let stateA: UInt32
    public let stateB: UInt32
    public let low15: UInt32
    public let lowByte: UInt8
    public let low3: UInt8
    public let secondaryLow15: UInt32
    public let secondaryLowByte: UInt8
    public let secondaryLow3: UInt8

    public init(
        stateA: UInt32,
        stateB: UInt32,
        low15: UInt32,
        lowByte: UInt8,
        low3: UInt8,
        secondaryLow15: UInt32,
        secondaryLowByte: UInt8,
        secondaryLow3: UInt8
    ) {
        self.stateA = stateA
        self.stateB = stateB
        self.low15 = low15
        self.lowByte = lowByte
        self.low3 = low3
        self.secondaryLow15 = secondaryLow15
        self.secondaryLowByte = secondaryLowByte
        self.secondaryLow3 = secondaryLow3
    }
}

/// Exact state transition for `FUN_004189b0 @ 0x4189b0`.
///
/// The executable writes the previously published low byte into a 100-entry
/// ring, advances both 32-bit registers for 31 LFSR rounds, then publishes
/// the masked values used by callers (`& 0x7fff`, `& 0x7f`, and `& 7`).  The
/// ring is retained because it is part of the routine's observable state even
/// though the recovered save stream persists only the two 32-bit registers.
public struct OriginalExecutableRandomState: Sendable, Hashable, Codable {
    public static let initialStateA: UInt32 = 0x5465_7687
    public static let initialStateB: UInt32 = 0x7264_1663
    public static let historyCapacity = 100

    public private(set) var stateA: UInt32
    public private(set) var stateB: UInt32
    public private(set) var low15: UInt32
    public private(set) var lowByte: UInt8
    public private(set) var low3: UInt8
    public private(set) var secondaryLow15: UInt32
    public private(set) var secondaryLowByte: UInt8
    public private(set) var secondaryLow3: UInt8
    public private(set) var historyIndex: Int
    public private(set) var history: [UInt8]

    public init(
        stateA: UInt32 = Self.initialStateA,
        stateB: UInt32 = Self.initialStateB,
        low15: UInt32 = 0,
        lowByte: UInt8 = 0,
        low3: UInt8 = 0,
        secondaryLow15: UInt32 = 0,
        secondaryLowByte: UInt8 = 0,
        secondaryLow3: UInt8 = 0,
        historyIndex: Int = 0,
        history: [UInt8] = Array(repeating: 0, count: Self.historyCapacity)
    ) {
        precondition((0..<Self.historyCapacity).contains(historyIndex))
        precondition(history.count == Self.historyCapacity)
        self.stateA = stateA
        self.stateB = stateB
        self.low15 = low15
        self.lowByte = lowByte
        self.low3 = low3
        self.secondaryLow15 = secondaryLow15
        self.secondaryLowByte = secondaryLowByte
        self.secondaryLow3 = secondaryLow3
        self.historyIndex = historyIndex
        self.history = history
    }

    /// Startup state after the executable's `FUN_00529a80 @ 0x529a80`
    /// 100-call warm-up.
    public static func startup() -> Self {
        var state = Self()
        state.warmUp()
        return state
    }

    /// Performs the exact 31-round transition and returns the newly
    /// published masked values.
    @discardableResult
    public mutating func advance() -> OriginalExecutableRandomSnapshot {
        history[historyIndex] = lowByte
        historyIndex = (historyIndex + 1) % Self.historyCapacity

        for _ in 0..<31 {
            let feedbackA = ((stateA >> 4) & 1) != (stateA & 1)
            let feedbackB = ((stateB >> 4) & 1) != (stateB & 1)
            stateA >>= 1
            stateB >>= 1
            if feedbackA { stateA |= 0x4000_0000 }
            if feedbackB { stateB |= 0x4000_0000 }
        }

        low15 = stateA & 0x7fff
        lowByte = UInt8(truncatingIfNeeded: stateA & 0x7f)
        low3 = UInt8(truncatingIfNeeded: stateA & 7)
        secondaryLow15 = stateB & 0x7fff
        secondaryLowByte = UInt8(truncatingIfNeeded: stateB & 0x7f)
        secondaryLow3 = UInt8(truncatingIfNeeded: stateB & 7)
        return snapshot
    }

    /// Applies the exact 100-call initialization warm-up.
    public mutating func warmUp() {
        for _ in 0..<Self.historyCapacity {
            advance()
        }
    }

    public var snapshot: OriginalExecutableRandomSnapshot {
        OriginalExecutableRandomSnapshot(
            stateA: stateA,
            stateB: stateB,
            low15: low15,
            lowByte: lowByte,
            low3: low3,
            secondaryLow15: secondaryLow15,
            secondaryLowByte: secondaryLowByte,
            secondaryLow3: secondaryLow3
        )
    }
}
