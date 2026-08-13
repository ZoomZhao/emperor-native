import CoreFoundation
import Foundation

/// Pairs the shipping English binary text table with the user's Chinese
/// `EmperorText.txt` source table. Both files retain the same group and row
/// order, so names can be localized without changing simulation identifiers.
public struct OriginalLocalizedTextCatalog: Sendable, Hashable {
    private static let groupTableOffset = 0x20
    private static let groupRecordByteCount = 8
    private static let groupRecordCapacity = 1_000
    private static let textDataOffset = 28 + groupRecordCapacity * groupRecordByteCount
    private static let confirmedAlignedGroupIDs: Set<Int> = [127]

    private let localizedByGroup: [Int: [String: String]]
    private let unambiguousLocalizedText: [String: String]
    private let alignedRowsByGroup: [Int: [String]]

    public init(root: URL) throws {
        try self.init(
            englishURL: root.appendingPathComponent("EmperorText.eng"),
            chineseURL: root.appendingPathComponent("EmperorText.txt")
        )
    }

    public init(englishURL: URL, chineseURL: URL) throws {
        let englishGroups = try Self.englishGroups(contentsOf: englishURL)
        let chineseGroups = try Self.chineseGroups(contentsOf: chineseURL)
        var byGroup: [Int: [String: String]] = [:]
        var candidates: [String: Set<String>] = [:]

        for (groupID, englishRows) in englishGroups {
            guard let chineseRows = chineseGroups[groupID] else { continue }
            var translations: [String: String] = [:]
            for (english, chinese) in zip(englishRows, chineseRows) {
                let authored = english.trimmingCharacters(in: .whitespacesAndNewlines)
                let localized = chinese.trimmingCharacters(in: .whitespacesAndNewlines)
                guard !authored.isEmpty, !localized.isEmpty,
                      authored.caseInsensitiveCompare(localized) != .orderedSame else {
                    continue
                }
                let key = Self.normalizedKey(authored)
                translations[key] = localized
                candidates[key, default: []].insert(localized)
            }
            if !translations.isEmpty {
                byGroup[groupID] = translations
            }
        }

        localizedByGroup = byGroup
        unambiguousLocalizedText = candidates.compactMapValues { values in
            values.count == 1 ? values.first : nil
        }
        // Row-index lookup is deliberately restricted to groups whose shipping
        // English and Chinese rows were compared semantically, not merely found
        // to have equal counts. Add another ID only with recorded source evidence.
        var alignedRows: [Int: [String]] = [:]
        for groupID in Self.confirmedAlignedGroupIDs {
            guard let englishRows = englishGroups[groupID] else { continue }
            guard let chineseRows = chineseGroups[groupID],
                  englishRows.count == chineseRows.count else { continue }
            alignedRows[groupID] = chineseRows
        }
        alignedRowsByGroup = alignedRows
    }

    public func localized(_ authoredText: String, groupID: Int? = nil) -> String? {
        let key = Self.normalizedKey(authoredText)
        if let groupID, let localized = localizedByGroup[groupID]?[key] {
            return localized
        }
        return unambiguousLocalizedText[key]
    }

    /// Exact zero-based row lookup from a group whose English and Chinese rows
    /// have been confirmed aligned. Returns `nil` for any other group or when
    /// the row index is out of bounds; it never invents a row.
    public func localized(groupID: Int, rowIndex: Int) -> String? {
        guard let rows = alignedRowsByGroup[groupID], rows.indices.contains(rowIndex) else {
            return nil
        }
        return rows[rowIndex]
    }

    private static func englishGroups(contentsOf url: URL) throws -> [Int: [String]] {
        let data = try Data(contentsOf: url, options: [.mappedIfSafe])
        guard data.count >= textDataOffset,
              String(data: Data(data.prefix(16)), encoding: .ascii) == "Emperor textfile" else {
            throw GameDataError.malformedFile("Emperor text header")
        }

        var groups: [Int: [String]] = [:]
        for groupID in 1..<groupRecordCapacity {
            let recordOffset = groupTableOffset + groupID * groupRecordByteCount
            let previousOffset = recordOffset - groupRecordByteCount
            guard let count = uint32LE(in: data, at: recordOffset).map(Int.init),
                  let start = uint32LE(in: data, at: previousOffset + 4).map(Int.init),
                  let end = uint32LE(in: data, at: recordOffset + 4).map(Int.init) else {
                continue
            }
            guard count > 0, start <= end, textDataOffset + end <= data.count else {
                continue
            }
            let bytes = data.subdata(in: (textDataOffset + start)..<(textDataOffset + end))
            let rows = nullTerminatedStrings(in: bytes, maximumCount: count)
            if rows.count == count {
                groups[groupID] = rows
            }
        }
        return groups
    }

    private static func chineseGroups(contentsOf url: URL) throws -> [Int: [String]] {
        let data = try Data(contentsOf: url, options: [.mappedIfSafe])
        // CoreFoundation's GB 18030 constant is declared in CFStringEncodingExt.h
        // but is not imported into Swift on every supported macOS SDK.
        let gb18030 = CFStringEncoding(0x0632)
        let encoding = String.Encoding(
            rawValue: CFStringConvertEncodingToNSStringEncoding(
                gb18030
            )
        )
        guard let text = String(data: data, encoding: encoding) else {
            throw GameDataError.malformedFile("Chinese Emperor text encoding")
        }

        var groups: [Int: [String]] = [:]
        var groupID = 0
        var currentRows: [String]?
        for rawLine in text.components(separatedBy: CharacterSet.newlines) {
            let line = rawLine.trimmingCharacters(in: CharacterSet.whitespacesAndNewlines)
            if isGroupSeparator(line) {
                if let currentRows {
                    groups[groupID] = currentRows
                }
                groupID += 1
                currentRows = []
                continue
            }
            guard currentRows != nil, !line.isEmpty, !line.hasPrefix("//") else {
                continue
            }
            currentRows?.append(line)
        }
        if let currentRows {
            groups[groupID] = currentRows
        }
        return groups
    }

    private static func nullTerminatedStrings(
        in data: Data,
        maximumCount: Int
    ) -> [String] {
        var rows: [String] = []
        var cursor = data.startIndex
        while rows.count < maximumCount, cursor < data.endIndex,
              let terminator = data[cursor...].firstIndex(of: 0) {
            if let value = String(data: data[cursor..<terminator], encoding: .windowsCP1252) {
                rows.append(value)
            }
            cursor = terminator + 1
        }
        return rows
    }

    private static func isGroupSeparator(_ line: String) -> Bool {
        guard line.hasPrefix("//") else { return false }
        let suffix = line.dropFirst(2).trimmingCharacters(in: .whitespaces)
        return !suffix.isEmpty && suffix.allSatisfy { $0 == "-" }
    }

    private static func normalizedKey(_ value: String) -> String {
        value
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .folding(
                options: [.caseInsensitive, .diacriticInsensitive],
                locale: Locale(identifier: "en_US_POSIX")
            )
    }

    private static func uint32LE(in data: Data, at offset: Int) -> UInt32? {
        guard offset >= 0, offset + 4 <= data.count else { return nil }
        return UInt32(data[offset])
            | UInt32(data[offset + 1]) << 8
            | UInt32(data[offset + 2]) << 16
            | UInt32(data[offset + 3]) << 24
    }
}
