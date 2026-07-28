import EmperorCore
import AppKit
import CoreGraphics
import CoreText
import Foundation
import ImageIO

private func formattedBytes(_ count: Int) -> String {
    ByteCountFormatter.string(fromByteCount: Int64(count), countStyle: .file)
}

private func source(from arguments: [String]) throws -> GameDataSource {
    if let dataIndex = arguments.firstIndex(of: "--data"), arguments.indices.contains(dataIndex + 1) {
        return try GameDataSource(root: URL(fileURLWithPath: arguments[dataIndex + 1], isDirectory: true))
    }
    return try .openDefault()
}

private func semanticBitmapName(_ archive: SG3Archive, imageID: Int) -> String {
    archive.bitmap(containingImageID: imageID)?.name ?? "<unmapped>"
}

private func exportBitmap(
    _ archive: SG3Archive,
    image: SG3Archive.Image
) -> SG3Archive.Bitmap? {
    if let ranged = archive.bitmap(containingImageID: image.id) {
        return ranged
    }
    guard archive.bitmaps.indices.contains(image.bitmapGroupID) else { return nil }
    let candidate = archive.bitmaps[image.bitmapGroupID]
    return candidate.name.isEmpty ? nil : candidate
}

private func safePathComponent(_ value: String, fallback: String) -> String {
    let stem = URL(fileURLWithPath: value).deletingPathExtension().lastPathComponent
    let sanitized = stem.replacingOccurrences(
        of: "[^A-Za-z0-9._-]+",
        with: "_",
        options: .regularExpression
    ).trimmingCharacters(in: CharacterSet(charactersIn: "._-"))
    return sanitized.isEmpty ? fallback : sanitized
}

private func csvField(_ value: String) -> String {
    "\"\(value.replacingOccurrences(of: "\"", with: "\"\""))\""
}

private func writePNG(_ image: CGImage, to url: URL) throws {
    guard let destination = CGImageDestinationCreateWithURL(
        url as CFURL,
        "public.png" as CFString,
        1,
        nil
    ) else {
        throw GameDataError.unsupported("could not create PNG destination \(url.path)")
    }
    CGImageDestinationAddImage(destination, image, nil)
    guard CGImageDestinationFinalize(destination) else {
        throw GameDataError.unsupported("could not write PNG \(url.path)")
    }
}

private struct ContactSheetSprite {
    let imageID: Int
    let image: CGImage
}

private struct SpriteCatalogPreview {
    let archiveName: String
    let categoryName: String
    let imageID: Int
    let relativePath: String
    let image: CGImage
}

private func contactSheet(_ sprites: [ContactSheetSprite]) -> CGImage? {
    guard !sprites.isEmpty else { return nil }
    let columns = 8
    let cellWidth = 144
    let cellHeight = 116
    let rows = (sprites.count + columns - 1) / columns
    let width = columns * cellWidth
    let height = rows * cellHeight
    guard let context = CGContext(
        data: nil,
        width: width,
        height: height,
        bitsPerComponent: 8,
        bytesPerRow: 0,
        space: CGColorSpaceCreateDeviceRGB(),
        bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
    ) else { return nil }

    context.setFillColor(CGColor(red: 0.055, green: 0.067, blue: 0.055, alpha: 1))
    context.fill(CGRect(x: 0, y: 0, width: width, height: height))
    context.interpolationQuality = .none
    let font = CTFontCreateWithName("Menlo-Bold" as CFString, 12, nil)
    let textColor = CGColor(red: 0.94, green: 0.73, blue: 0.25, alpha: 1)

    for (index, sprite) in sprites.enumerated() {
        let column = index % columns
        let row = index / columns
        let cellX = column * cellWidth
        let cellY = height - (row + 1) * cellHeight
        let originX = CGFloat(cellX)
        let originY = CGFloat(cellY)
        let resolvedCellWidth = CGFloat(cellWidth)
        let resolvedCellHeight = CGFloat(cellHeight)
        context.setStrokeColor(CGColor(red: 0.35, green: 0.23, blue: 0.12, alpha: 1))
        let cellRect = CGRect(
            x: originX + 0.5,
            y: originY + 0.5,
            width: resolvedCellWidth - 1,
            height: resolvedCellHeight - 1
        )
        context.stroke(cellRect)

        let imageArea = CGRect(
            x: originX + 5,
            y: originY + 22,
            width: resolvedCellWidth - 10,
            height: resolvedCellHeight - 27
        )
        let scale = min(
            imageArea.width / CGFloat(max(1, sprite.image.width)),
            imageArea.height / CGFloat(max(1, sprite.image.height))
        )
        let drawWidth = CGFloat(sprite.image.width) * scale
        let drawHeight = CGFloat(sprite.image.height) * scale
        context.draw(
            sprite.image,
            in: CGRect(
                x: imageArea.midX - drawWidth / 2,
                y: imageArea.midY - drawHeight / 2,
                width: drawWidth,
                height: drawHeight
            )
        )

        let label = NSAttributedString(
            string: "#\(sprite.imageID)",
            attributes: [
                NSAttributedString.Key(kCTFontAttributeName as String): font,
                NSAttributedString.Key(kCTForegroundColorAttributeName as String): textColor,
            ]
        )
        let line = CTLineCreateWithAttributedString(label)
        context.textPosition = CGPoint(x: originX + 6, y: originY + 5)
        CTLineDraw(line, context)
    }
    return context.makeImage()
}

private func completeSpriteCatalogSheet(
    _ previews: [SpriteCatalogPreview]
) -> CGImage? {
    guard !previews.isEmpty else { return nil }
    let columns = 5
    let cellWidth = 300
    let cellHeight = 210
    let titleHeight = 72
    let rows = (previews.count + columns - 1) / columns
    let width = columns * cellWidth
    let height = titleHeight + rows * cellHeight
    guard let context = CGContext(
        data: nil,
        width: width,
        height: height,
        bitsPerComponent: 8,
        bytesPerRow: 0,
        space: CGColorSpaceCreateDeviceRGB(),
        bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
    ) else { return nil }

    context.setFillColor(CGColor(red: 0.045, green: 0.052, blue: 0.043, alpha: 1))
    context.fill(CGRect(x: 0, y: 0, width: width, height: height))
    context.interpolationQuality = .none

    func drawText(
        _ text: String,
        in rectangle: CGRect,
        font: CTFont,
        color: CGColor
    ) {
        let paragraph = NSMutableParagraphStyle()
        paragraph.lineBreakMode = .byCharWrapping
        paragraph.paragraphSpacing = 1
        let attributed = NSAttributedString(
            string: text,
            attributes: [
                NSAttributedString.Key(kCTFontAttributeName as String): font,
                NSAttributedString.Key(kCTForegroundColorAttributeName as String): color,
                .paragraphStyle: paragraph,
            ]
        )
        let framesetter = CTFramesetterCreateWithAttributedString(attributed)
        let path = CGMutablePath()
        path.addRect(rectangle)
        let frame = CTFramesetterCreateFrame(
            framesetter,
            CFRange(location: 0, length: attributed.length),
            path,
            nil
        )
        CTFrameDraw(frame, context)
    }

    let titleFont = CTFontCreateWithName("Menlo-Bold" as CFString, 20, nil)
    let labelFont = CTFontCreateWithName("Menlo" as CFString, 11, nil)
    let titleColor = CGColor(red: 0.95, green: 0.74, blue: 0.24, alpha: 1)
    let labelColor = CGColor(red: 0.91, green: 0.88, blue: 0.78, alpha: 1)
    drawText(
        "Emperor DATA_IMAGES · \(previews.count) categories · first sprite of each category",
        in: CGRect(x: 20, y: height - 52, width: width - 40, height: 32),
        font: titleFont,
        color: titleColor
    )

    for (index, preview) in previews.enumerated() {
        let column = index % columns
        let row = index / columns
        let cellX = column * cellWidth
        let cellY = height - titleHeight - (row + 1) * cellHeight
        let originX = CGFloat(cellX)
        let originY = CGFloat(cellY)
        let resolvedCellWidth = CGFloat(cellWidth)
        let resolvedCellHeight = CGFloat(cellHeight)
        context.setFillColor(CGColor(red: 0.075, green: 0.085, blue: 0.070, alpha: 1))
        context.fill(
            CGRect(
                x: originX + 4,
                y: originY + 4,
                width: resolvedCellWidth - 8,
                height: resolvedCellHeight - 8
            )
        )
        context.setStrokeColor(CGColor(red: 0.35, green: 0.23, blue: 0.12, alpha: 1))
        context.stroke(
            CGRect(
                x: originX + 4.5,
                y: originY + 4.5,
                width: resolvedCellWidth - 9,
                height: resolvedCellHeight - 9
            )
        )

        let imageArea = CGRect(
            x: originX + 12,
            y: originY + 70,
            width: resolvedCellWidth - 24,
            height: resolvedCellHeight - 82
        )
        let scale = min(
            imageArea.width / CGFloat(max(1, preview.image.width)),
            imageArea.height / CGFloat(max(1, preview.image.height))
        )
        let drawWidth = CGFloat(preview.image.width) * scale
        let drawHeight = CGFloat(preview.image.height) * scale
        context.draw(
            preview.image,
            in: CGRect(
                x: imageArea.midX - drawWidth / 2,
                y: imageArea.midY - drawHeight / 2,
                width: drawWidth,
                height: drawHeight
            )
        )

        drawText(
            "\(preview.archiveName)\n\(preview.categoryName)\n#\(preview.imageID)",
            in: CGRect(
                x: originX + 12,
                y: originY + 10,
                width: resolvedCellWidth - 24,
                height: 54
            ),
            font: labelFont,
            color: labelColor
        )
    }
    return context.makeImage()
}

private func writeCompleteSpriteCatalog(to outputDirectory: URL) throws -> Int {
    let fileManager = FileManager.default
    let archiveDirectories = try fileManager.contentsOfDirectory(
        at: outputDirectory,
        includingPropertiesForKeys: [.isDirectoryKey],
        options: [.skipsHiddenFiles]
    ).filter {
        (try? $0.resourceValues(forKeys: [.isDirectoryKey]).isDirectory) == true
    }.sorted {
        $0.lastPathComponent.localizedStandardCompare($1.lastPathComponent)
            == .orderedAscending
    }
    var previews: [SpriteCatalogPreview] = []
    for archiveDirectory in archiveDirectories {
        let categoryDirectories = try fileManager.contentsOfDirectory(
            at: archiveDirectory,
            includingPropertiesForKeys: [.isDirectoryKey],
            options: [.skipsHiddenFiles]
        ).filter {
            (try? $0.resourceValues(forKeys: [.isDirectoryKey]).isDirectory) == true
        }.sorted {
            $0.lastPathComponent.localizedStandardCompare($1.lastPathComponent)
                == .orderedAscending
        }
        for categoryDirectory in categoryDirectories {
            let firstSpriteURL = try fileManager.contentsOfDirectory(
                at: categoryDirectory,
                includingPropertiesForKeys: nil,
                options: [.skipsHiddenFiles]
            ).filter {
                $0.pathExtension.lowercased() == "png"
                    && !$0.lastPathComponent.hasPrefix("CONTACT_SHEET_")
            }.sorted {
                $0.lastPathComponent.localizedStandardCompare($1.lastPathComponent)
                    == .orderedAscending
            }.first
            guard let firstSpriteURL,
                  let imageID = Int(firstSpriteURL.lastPathComponent.prefix(6)),
                  let source = CGImageSourceCreateWithURL(firstSpriteURL as CFURL, nil),
                  let image = CGImageSourceCreateImageAtIndex(source, 0, nil) else {
                continue
            }
            let rawCategoryName = categoryDirectory.lastPathComponent
            let categoryName = rawCategoryName.replacingOccurrences(
                of: #"^\d{3}_"#,
                with: "",
                options: .regularExpression
            )
            let relativePath = firstSpriteURL.path.replacingOccurrences(
                of: outputDirectory.path + "/",
                with: ""
            )
            previews.append(SpriteCatalogPreview(
                archiveName: archiveDirectory.lastPathComponent,
                categoryName: categoryName,
                imageID: imageID,
                relativePath: relativePath,
                image: image
            ))
        }
    }
    previews.sort {
        if $0.archiveName != $1.archiveName {
            return $0.archiveName.localizedStandardCompare($1.archiveName)
                == .orderedAscending
        }
        return $0.categoryName.localizedStandardCompare($1.categoryName)
            == .orderedAscending
    }
    guard let sheet = completeSpriteCatalogSheet(previews) else {
        throw GameDataError.unsupported("could not create complete sprite catalog")
    }
    try writePNG(
        sheet,
        to: outputDirectory.appendingPathComponent("SPRITE_CATALOG.png")
    )
    var csv = ["archive,category,first_image_id,path"]
    csv.append(contentsOf: previews.map {
        [
            csvField($0.archiveName),
            csvField($0.categoryName),
            String($0.imageID),
            csvField($0.relativePath),
        ].joined(separator: ",")
    })
    try Data((csv.joined(separator: "\n") + "\n").utf8).write(
        to: outputDirectory.appendingPathComponent("SPRITE_CATALOG.csv"),
        options: .atomic
    )
    return previews.count
}

private func logicalAnimationPosition(
    _ archive: SG3Archive,
    imageID: Int
) -> (logicalGroup: Int, direction: Int, frame: Int)? {
    guard let entry = archive.groupImageIDs.enumerated()
        .filter({ $0.element != 0 && Int($0.element) <= imageID })
        .max(by: { $0.element < $1.element }) else { return nil }
    let start = Int(entry.element)
    guard archive.images.indices.contains(start) else { return nil }
    let frameCount = max(1, archive.images[start].spriteCount)
    let offset = imageID - start
    return (entry.offset, offset / frameCount, offset % frameCount)
}

do {
    let rawArguments = Array(CommandLine.arguments.dropFirst())
    let game = try source(from: rawArguments)
    var arguments: [String] = []
    var argumentIndex = 0
    while argumentIndex < rawArguments.count {
        if rawArguments[argumentIndex] == "--data" {
            argumentIndex += 2
        } else {
            arguments.append(rawArguments[argumentIndex])
            argumentIndex += 1
        }
    }
    let command = arguments.first ?? "summary"

    switch command {
    case "summary":
        let catalog = try GameDataCatalog.scan(game)
        let models = try ModelCatalog.scan(game)
        let economy = try OriginalEconomyModels(source: game)
        print("Emperor Native data source")
        print("  root: \(game.root.path)")
        print("  maps: \(catalog.maps.count)")
        print("  campaigns: \(catalog.campaigns.count)")
        print("  sprite packs: \(catalog.spriteDescriptions.count) SG3 + \(catalog.spritePixels.count) RGB555")
        print("  model files: \(models.count), \(models.reduce(0) { $0 + $1.nonEmptyLineCount }) significant lines")
        print("  economy tables: \(economy.buildings.buildings.count) buildings, \(economy.buildings.houses.count) house levels, \(economy.trade.prices.count) commodities")
        print("  audio: \(catalog.waveAudio.count) WAV + \(catalog.music.count) MP3")

        if let map = catalog.maps.first(where: { $0.name == "Erlitou.map" }) ?? catalog.maps.first {
            let probe = try MapProbe(url: map.url)
            print("  sample map: \(map.name), chunks=\(probe.chunkCount), decoded=\(formattedBytes(probe.decodedByteCount)), size=\(probe.width ?? 0)x\(probe.height ?? 0)")
        }
        let terrain = game.dataDirectory.appendingPathComponent("China_Terrain.sg3")
        if FileManager.default.fileExists(atPath: terrain.path) {
            let archive = try SG3Archive(contentsOf: terrain)
            let nonEmpty = archive.images.filter { $0.width > 0 && $0.height > 0 }
            print("  sample sprites: China_Terrain v\(archive.header.version), \(archive.images.count) records, \(nonEmpty.count) non-empty")
        }

    case "economy":
        let models = try OriginalEconomyModels(source: game)
        let rules = EconomyRulesEngine(models: models)
        print("Original economy models")
        print("  buildings: \(models.buildings.buildings.count); houses: \(models.buildings.houses.count)")
        print("  commodities: \(models.trade.prices.count); land capacity: \(models.trade.landCapacity); sea capacity: \(models.trade.seaCapacity)")
        print("  Silk price: \(rules.commodityPrice(named: "Silk") ?? 0)")
        print("  Tax Office cost VE/N/VH: \(rules.constructionCost(buildingID: 125, difficulty: .veryEasy) ?? 0)/\(rules.constructionCost(buildingID: 125, difficulty: .normal) ?? 0)/\(rules.constructionCost(buildingID: 125, difficulty: .veryHard) ?? 0)")
        print("  9% tax sentiment VE/N/VH: \(rules.taxSentiment(bandID: 3, difficulty: .veryEasy) ?? 0)/\(rules.taxSentiment(bandID: 3, difficulty: .normal) ?? 0)/\(rules.taxSentiment(bandID: 3, difficulty: .veryHard) ?? 0)")

    case "campaign":
        guard arguments.count >= 2 else { throw GameDataError.unsupported("usage: emperor-inspect campaign <file>") }
        let campaign = try CampaignArchive(url: URL(fileURLWithPath: arguments[1]))
        print("\(campaign.title): \(campaign.missions.count) missions, \(campaign.containerChunkCount) chunks, \(formattedBytes(campaign.decodedByteCount)) decoded")
        print("  \(campaign.campaignDescription)")
        for mission in campaign.missions {
            print("  \(mission.sequenceNumber). \(mission.title) [world=\(mission.primaryWorldObjectID)/\(mission.secondaryWorldObjectID), prerequisite=\(mission.prerequisiteMissionIndex)]")
        }

    case "campaign-goals":
        guard arguments.count >= 2 else { throw GameDataError.unsupported("usage: emperor-inspect campaign-goals <file>") }
        let url = URL(fileURLWithPath: arguments[1])
        let campaign = try CampaignArchive(url: url)
        let archive = try CampaignGoalArchive(campaignURL: url, missionCount: campaign.missions.count)
        let section = archive.sectionOffset.map { "0x" + String($0, radix: 16) } ?? "none"
        let end = archive.endOffset.map { "0x" + String($0, radix: 16) } ?? "none"
        print("\(campaign.title): goal section \(section)..<\(end)")
        for (mission, goalSet) in zip(campaign.missions, archive.missions) {
            print("  \(mission.sequenceNumber). \(mission.title): \(goalSet.goals.count) goals")
            for goal in goalSet.goals {
                let values = goal.values.map(String.init).joined(separator: ",")
                print("    \(goal.kind.rawValue) type=\(goal.typeID) variant=\(goal.variant) values=[\(values)]")
            }
        }

    case "campaign-settings":
        guard arguments.count >= 2 else {
            throw GameDataError.unsupported("usage: emperor-inspect campaign-settings <file>")
        }
        let url = URL(fileURLWithPath: arguments[1])
        let campaign = try CampaignArchive(url: url)
        let settings = try CampaignMissionSettingsArchive(
            campaignURL: url,
            missionCount: campaign.missions.count
        )
        print("\(campaign.title): settings at 0x\(String(settings.yearTableOffset, radix: 16)), stride 0x\(String(settings.missionRecordStride, radix: 16))")
        for (mission, start) in zip(campaign.missions, settings.missions) {
            let year = start.startYear < 0 ? "\(-start.startYear) BCE" : "\(start.startYear) CE"
            print("  \(mission.sequenceNumber). \(mission.title): \(year) month=\(start.startMonth) funds=\(start.initialFunds) buildings=\(start.allowedBuildingMenuIDs.count) resources=\(start.allowedResourceCommodityIDs)")
            if arguments.contains("--raw") {
                print("    buildingMenuIDs=\(start.allowedBuildingMenuIDs)")
            }
        }

    case "campaign-events":
        guard arguments.count >= 2 else { throw GameDataError.unsupported("usage: emperor-inspect campaign-events <file>") }
        let url = URL(fileURLWithPath: arguments[1])
        let campaign = try CampaignArchive(url: url)
        let archive = try CampaignEventArchive(campaignURL: url, missionCount: campaign.missions.count)
        print("\(campaign.title): event table v\(archive.archiveVersion) at 0x\(String(archive.sectionOffset, radix: 16)), record=\(archive.serializedRecordByteCount), slot=\(archive.missionSlotByteCount)")
        for (mission, eventSet) in zip(campaign.missions, archive.missions) {
            print("  \(mission.sequenceNumber). \(mission.title): \(eventSet.events.count) events")
            for event in eventSet.events {
                let name = event.kind?.displayName ?? "Unknown \(event.kindRawValue)"
                let product = event.product.bounds.map { "\($0.lowerBound)...\($0.upperBound)" } ?? "-"
                let amount = event.amount.bounds.map { "\($0.lowerBound)...\($0.upperBound)" } ?? "-"
                let year = event.year.bounds.map { "+\($0.lowerBound)...\($0.upperBound)" } ?? "-"
                let city = event.cityFrom.bounds.map {
                    "\($0.lowerBound)...\($0.upperBound)"
                } ?? "-"
                let secondary = event.secondarySelection.bounds.map {
                    "\($0.lowerBound)...\($0.upperBound)"
                } ?? "-"
                print("    #\(event.id) \(name) trigger=\(event.triggerMode.rawValue) month=\(event.monthNumber) product=\(product) amount=\(amount) year=\(year) city=\(city) secondary=\(secondary) status=\(event.statusChangeCode) time=\(event.timeAllowed) flags=0x\(String(event.flags, radix: 16))")
            }
        }

    case "campaign-event-kinds":
        struct Observation {
            let campaign: String
            let mission: Int
            let event: CampaignEventRecord
        }
        let campaigns = try CampaignCatalog.load(game)
        var observations: [CampaignEventKind: [Observation]] = [:]
        for campaign in campaigns {
            let archive = try CampaignEventArchive(
                campaignURL: campaign.url,
                missionCount: campaign.missions.count
            )
            for mission in archive.missions {
                for event in mission.events {
                    guard let kind = event.kind else { continue }
                    observations[kind, default: []].append(Observation(
                        campaign: campaign.title,
                        mission: mission.id + 1,
                        event: event
                    ))
                }
            }
        }
        func rangeText(_ range: CampaignEventRange) -> String {
            range.bounds.map { $0.lowerBound == $0.upperBound
                ? String($0.lowerBound) : "\($0.lowerBound)...\($0.upperBound)" } ?? "-"
        }
        for kind in CampaignEventKind.allCases {
            guard let items = observations[kind], !items.isEmpty else { continue }
            print("\(kind.rawValue) \(kind.displayName): \(items.count)")
            for item in items.prefix(8) {
                let event = item.event
                print("  \(item.campaign) m\(item.mission) #\(event.id): product=\(rangeText(event.product)) amount=\(rangeText(event.amount)) city=\(rangeText(event.cityFrom)) secondary=\(rangeText(event.secondarySelection)) status=\(event.statusChangeCode) time=\(event.timeAllowed) trigger=\(event.triggerMode.rawValue) flags=0x\(String(event.flags, radix: 16))")
            }
        }

    case "campaign-empire":
        guard arguments.count >= 2 else { throw GameDataError.unsupported("usage: emperor-inspect campaign-empire <file>") }
        let url = URL(fileURLWithPath: arguments[1])
        guard let empire = try CampaignEmpireMap.loadIfPresent(campaignURL: url) else {
            print("\(url.lastPathComponent): no embedded empire map")
            break
        }
        let names = try OriginalCityNameCatalog(
            contentsOf: game.root.appendingPathComponent("EmperorText.eng")
        )
        let economy = try OriginalEconomyModels(source: game)
        let includeRaw = arguments.contains("--raw")
        print("\(url.lastPathComponent): empire at 0x\(String(empire.decodedOffset, radix: 16)), \(empire.objects.count) objects, \(empire.activeCities.count) active cities")
        for city in empire.activeCities {
            let name = names[nameID: city.nameID] ?? "#\(city.nameID)"
            let route = city.routeKind(using: economy.trade)?.rawValue ?? "interval-\(city.tradeVisitInterval)"
            let demand = city.demandCommodityIDs.map {
                "\(economy.trade[commodityID: $0]?.name ?? "#\($0)"):\(city.annualLoadsByCommodityID[$0, default: 0])"
            }.joined(separator: ",")
            let supply = city.supplyCommodityIDs.map {
                "\(economy.trade[commodityID: $0]?.name ?? "#\($0)"):\(city.annualLoadsByCommodityID[$0, default: 0])"
            }.joined(separator: ",")
            print("  [\(city.id)] \(name) \(route) buys=[\(demand)] sells=[\(supply)]")
            if includeRaw {
                print("    prefix[0..<96]=\(city.rawPrefix.prefix(96).map { String(format: "%02x", $0) }.joined(separator: " "))")
                for relationshipID in [0, 13] where city.relationships.indices.contains(relationshipID) {
                    let relationship = city.relationships[relationshipID]
                    print("    rel[\(relationshipID)][0..<64]=\(relationship.rawPayload.prefix(64).map { String(format: "%02x", $0) }.joined(separator: " "))")
                }
            }
        }

    case "campaign-mission-maps":
        guard arguments.count >= 2 else { throw GameDataError.unsupported("usage: emperor-inspect campaign-mission-maps <file>") }
        let url = URL(fileURLWithPath: arguments[1])
        let campaign = try CampaignArchive(url: url)
        let catalog = try GameDataCatalog.scan(game)
        let maps = try CampaignMissionMapArchive(
            campaignURL: url,
            missionCount: campaign.missions.count,
            candidateMapURLs: catalog.maps.map(\.url)
        )
        let empire = try CampaignEmpireMap.loadIfPresent(campaignURL: url)
        let cityNames = try OriginalCityNameCatalog(
            contentsOf: game.root.appendingPathComponent("EmperorText.eng")
        )
        let table = maps.mapNameTableOffset.map { "0x" + String($0, radix: 16) } ?? "none"
        print("\(campaign.title): mission map table \(table)")
        for (mission, assignment) in zip(campaign.missions, maps.missions) {
            let continuation = assignment.isContinuation ? " continuation-of=\(assignment.sourceMissionIndex + 1)" : ""
            let originalMap = try EmperorMap(url: assignment.embeddedMap.mapURL)
            let terrain = DeterministicTerrainState(map: originalMap)
            let playerCityName = empire.flatMap { map in
                map.cities.indices.contains(assignment.playerCityID)
                    ? cityNames[nameID: map.cities[assignment.playerCityID].nameID]
                    : nil
            } ?? "slot-\(assignment.playerCityID)"
            print("  \(mission.sequenceNumber). \(mission.title): \(assignment.embeddedMap.mapURL.lastPathComponent) \(originalMap.width)x\(originalMap.height) roads=\(terrain.roadPoints.count) water=\(terrain.waterTileCount) player=\(playerCityName)[\(assignment.playerCityID)]\(continuation)")
        }

    case "campaign-map-candidates":
        guard arguments.count >= 2 else {
            throw GameDataError.unsupported(
                "usage: emperor-inspect campaign-map-candidates <campaign>"
            )
        }
        let campaignURL = URL(fileURLWithPath: arguments[1])
        let container = try SierraChunkedFile(contentsOf: campaignURL)
        let metadataEnd = container.chunks.prefix(29).reduce(0) {
            $0 + $1.uncompressedSize
        }
        let metadata = container.decodedData.prefix(metadataEnd)
        let lowercase = Data(metadata.map {
            (65...90).contains($0) ? $0 + 32 : $0
        })
        let catalog = try GameDataCatalog.scan(game)
        var matches: [(String, Int)] = []
        for map in catalog.maps {
            let name = map.url.deletingPathExtension().lastPathComponent.lowercased()
            let pattern = Data(name.utf8)
            var start = 0
            while start < lowercase.count,
                  let match = lowercase.range(of: pattern, in: start..<lowercase.count) {
                matches.append((map.name, match.lowerBound))
                start = match.lowerBound + 1
            }
        }
        print("\(campaignURL.lastPathComponent): \(matches.count) installed-map name matches")
        for match in matches.sorted(by: {
            $0.1 == $1.1 ? $0.0 < $1.0 : $0.1 < $1.1
        }) {
            print("  \(match.0) @ 0x\(String(match.1, radix: 16))")
        }

    case "campaign-strings":
        guard arguments.count >= 2 else {
            throw GameDataError.unsupported("usage: emperor-inspect campaign-strings <campaign> [contains]")
        }
        let campaignURL = URL(fileURLWithPath: arguments[1])
        let container = try SierraChunkedFile(contentsOf: campaignURL)
        let metadataEnd = container.chunks.prefix(29).reduce(0) {
            $0 + $1.uncompressedSize
        }
        let data = container.decodedData
        let needle = arguments.count > 2 ? arguments[2].lowercased() : nil
        var start: Int?
        var strings: [(Int, String)] = []
        for offset in 0...metadataEnd {
            let byte = offset < metadataEnd ? data[offset] : 0
            if (32...126).contains(byte) {
                start = start ?? offset
            } else if let runStart = start {
                if offset - runStart >= 3,
                   let value = String(data: data[runStart..<offset], encoding: .ascii),
                   needle.map({ value.lowercased().contains($0) }) ?? true {
                    strings.append((runStart, value))
                }
                start = nil
            }
        }
        for item in strings.prefix(1_000) {
            print("0x\(String(item.0, radix: 16)): \(item.1)")
        }

    case "campaigns":
        let campaigns = try CampaignCatalog.load(game)
        print("Campaigns: \(campaigns.count), missions: \(campaigns.reduce(0) { $0 + $1.missions.count })")
        for campaign in campaigns {
            print("  \(campaign.title): \(campaign.missions.count) [table=0x\(String(campaign.detectedMissionTableOffset, radix: 16))]")
        }

    case "container-find":
        guard arguments.count >= 3 else {
            throw GameDataError.unsupported("usage: emperor-inspect container-find <file> <ascii-pattern>")
        }
        let decoded = try SierraChunkedFile(contentsOf: URL(fileURLWithPath: arguments[1])).decodedData
        let pattern = Data(arguments[2].utf8)
        guard !pattern.isEmpty else { throw GameDataError.unsupported("pattern must not be empty") }
        var offsets: [Int] = []
        var searchStart = decoded.startIndex
        while searchStart < decoded.endIndex,
              let match = decoded.range(of: pattern, in: searchStart..<decoded.endIndex) {
            offsets.append(match.lowerBound)
            searchStart = match.lowerBound + 1
        }
        print("\(arguments[2]): \(offsets.count) matches")
        for offset in offsets {
            print("  \(offset) (0x\(String(offset, radix: 16)))")
        }

    case "campaign-map-match":
        guard arguments.count >= 3 else {
            throw GameDataError.unsupported("usage: emperor-inspect campaign-map-match <campaign> <map>")
        }
        let campaignChunks = try SierraChunkedFile(contentsOf: URL(fileURLWithPath: arguments[1])).chunks
        let mapChunks = try SierraChunkedFile(contentsOf: URL(fileURLWithPath: arguments[2])).chunks
        var matches: [Int] = []
        if campaignChunks.count >= mapChunks.count {
            for start in 0...(campaignChunks.count - mapChunks.count) {
                if mapChunks.indices.allSatisfy({ campaignChunks[start + $0].data == mapChunks[$0].data }) {
                    matches.append(start)
                }
            }
        }
        print("\(URL(fileURLWithPath: arguments[2]).lastPathComponent): \(matches.map(String.init).joined(separator: ", "))")

    case "campaign-record-words":
        guard arguments.count >= 2 else {
            throw GameDataError.unsupported("usage: emperor-inspect campaign-record-words <campaign>")
        }
        let url = URL(fileURLWithPath: arguments[1])
        let campaign = try CampaignArchive(url: url)
        let reader = BinaryReader(data: try SierraChunkedFile(contentsOf: url).decodedData)
        for mission in campaign.missions {
            let base = campaign.detectedMissionTableOffset + mission.id * CampaignArchive.missionRecordByteCount
            var words: [String] = []
            for relative in stride(from: 0, through: 92, by: 4) {
                let value = try reader.uint32LE(at: base + relative)
                if value != 0 {
                    words.append("+\(relative)=\(Int32(bitPattern: value))")
                }
            }
            print("\(mission.sequenceNumber). \(mission.title): \(words.joined(separator: " "))")
        }

    case "campaign-goal-scan":
        guard arguments.count >= 2 else {
            throw GameDataError.unsupported("usage: emperor-inspect campaign-goal-scan <campaign>")
        }
        let url = URL(fileURLWithPath: arguments[1])
        let container = try SierraChunkedFile(contentsOf: url)
        let decoded = container.decodedData
        let campaign = try CampaignArchive(url: url)
        let metadataEnd = container.chunks.prefix(29).reduce(0) { $0 + $1.uncompressedSize }
        let missionSlots = 10
        let goalsPerMission = 6
        print("count-table + goal-table candidates")
        for recordSize in [76, 80, 84, 88] {
            let tableSize = missionSlots * goalsPerMission * recordSize
            var candidates: [(score: Int, offset: Int, counts: [Int])] = []
            for countBase in stride(from: 0, through: metadataEnd - 40 - tableSize, by: 4) {
                var counts: [Int] = []
                var validCounts = true
                for mission in 0..<missionSlots {
                    let offset = countBase + mission * 4
                    let count = Int(decoded[offset])
                    if count > goalsPerMission || decoded[offset + 1] != 0 || decoded[offset + 2] != 0 || decoded[offset + 3] != 0 {
                        validCounts = false
                        break
                    }
                    counts.append(count)
                }
                guard validCounts,
                      counts.prefix(campaign.missions.count).reduce(0, +) >= 2,
                      counts.dropFirst(campaign.missions.count).allSatisfy({ $0 == 0 }) else { continue }
                let goalBase = countBase + 40
                var score = 0
                var validGoals = true
                for mission in 0..<missionSlots {
                    for slot in 0..<goalsPerMission {
                        let offset = goalBase + (mission * goalsPerMission + slot) * recordSize
                        let type = Int(decoded[offset]) | Int(decoded[offset + 1]) << 8
                        let isActive = slot < counts[mission]
                        if isActive {
                            guard (0...32).contains(type) else {
                                validGoals = false
                                break
                            }
                            score += 20
                        }
                        for separator in [2, 3, 6, 7, 10, 11, 14, 15] where decoded[offset + separator] == 0 {
                            score += 1
                        }
                    }
                    if !validGoals { break }
                }
                if validGoals { candidates.append((score, countBase, counts)) }
            }
            print("  recordSize=\(recordSize)")
            for candidate in candidates.sorted(by: { $0.score > $1.score }).prefix(12) {
                print("    countOffset=\(candidate.offset) (0x\(String(candidate.offset, radix: 16))) score=\(candidate.score) counts=\(candidate.counts.map(String.init).joined(separator: ","))")
            }
        }

    case "campaign-count-offsets":
        let campaigns = try CampaignCatalog.load(game).filter { $0.missions.count > 1 }
        struct CandidateObservation {
            let campaign: String
            let counts: [UInt32]
        }
        var observations: [Int: [CandidateObservation]] = [:]
        for campaign in campaigns {
            let container = try SierraChunkedFile(contentsOf: campaign.url)
            let metadataEnd = container.chunks.prefix(29).reduce(0) { $0 + $1.uncompressedSize }
            let decoded = container.decodedData
            for offset in stride(from: 0, through: metadataEnd - 40, by: 4) {
                var counts: [UInt32] = []
                var valid = true
                for slot in 0..<10 {
                    let base = offset + slot * 4
                    let value = UInt32(decoded[base])
                        | UInt32(decoded[base + 1]) << 8
                        | UInt32(decoded[base + 2]) << 16
                        | UInt32(decoded[base + 3]) << 24
                    if value > 8 {
                        valid = false
                        break
                    }
                    counts.append(value)
                }
                guard valid,
                      counts.prefix(campaign.missions.count).contains(where: { $0 > 0 }),
                      counts.dropFirst(campaign.missions.count).allSatisfy({ $0 == 0 }) else { continue }
                observations[offset, default: []].append(CandidateObservation(
                    campaign: campaign.title,
                    counts: counts
                ))
            }
        }
        for candidate in observations.sorted(by: {
            if $0.value.count != $1.value.count { return $0.value.count > $1.value.count }
            return $0.key < $1.key
        }).prefix(40) {
            print("offset=\(candidate.key) (0x\(String(candidate.key, radix: 16))) matches=\(candidate.value.count)")
            for observation in candidate.value.prefix(12) {
                print("  \(observation.campaign): \(observation.counts.map(String.init).joined(separator: ","))")
            }
        }

    case "campaign-find-counts":
        guard arguments.count >= 3 else {
            throw GameDataError.unsupported("usage: emperor-inspect campaign-find-counts <campaign> <comma-separated-counts>")
        }
        let url = URL(fileURLWithPath: arguments[1])
        let expected = arguments[2].split(separator: ",").compactMap { UInt8($0) }
        guard !expected.isEmpty else { throw GameDataError.unsupported("counts must not be empty") }
        let container = try SierraChunkedFile(contentsOf: url)
        let decoded = container.decodedData
        let metadataEnd = container.chunks.prefix(29).reduce(0) { $0 + $1.uncompressedSize }
        for strideBytes in [1, 2, 4, 8, 12, 16, 76, 80, 84, 88, 224, 300, 320, 324, 356, 456, 1_020, 2_032, 4_560] {
            var offsets: [Int] = []
            let span = (expected.count - 1) * strideBytes + 1
            guard metadataEnd >= span else { continue }
            for base in 0...(metadataEnd - span) {
                guard expected.indices.allSatisfy({ decoded[base + $0 * strideBytes] == expected[$0] }) else { continue }
                if strideBytes > 1 {
                    let paddingIsZero = expected.indices.allSatisfy { index in
                        let paddingEnd = base + index * strideBytes + min(strideBytes, 4)
                        return decoded[(base + index * strideBytes + 1)..<paddingEnd].allSatisfy { $0 == 0 }
                    }
                    guard paddingIsZero else { continue }
                }
                offsets.append(base)
            }
            print("stride=\(strideBytes): \(offsets.prefix(50).map { "\($0)(0x\(String($0, radix: 16)))" }.joined(separator: ", "))")
        }

    case "campaign-number-density":
        guard arguments.count >= 3 else {
            throw GameDataError.unsupported("usage: emperor-inspect campaign-number-density <campaign> <comma-separated-u16-values>")
        }
        let url = URL(fileURLWithPath: arguments[1])
        let expected = arguments[2].split(separator: ",").compactMap { UInt16($0) }
        let container = try SierraChunkedFile(contentsOf: url)
        let decoded = container.decodedData
        let metadataEnd = container.chunks.prefix(29).reduce(0) { $0 + $1.uncompressedSize }
        let windowSize = 8_192
        var windows: [(score: Int, offset: Int, found: [UInt16])] = []
        for base in stride(from: 0, to: metadataEnd, by: 256) {
            let end = min(base + windowSize, metadataEnd)
            let found = expected.filter { value in
                let pattern = Data([UInt8(value & 0xff), UInt8(value >> 8)])
                return decoded.range(of: pattern, in: base..<end) != nil
            }
            windows.append((found.count, base, found))
        }
        var accepted: [Int] = []
        for window in windows.sorted(by: { $0.score > $1.score }) {
            guard accepted.allSatisfy({ abs($0 - window.offset) >= windowSize / 2 }) else { continue }
            accepted.append(window.offset)
            print("offset=\(window.offset) (0x\(String(window.offset, radix: 16))) score=\(window.score) values=\(window.found.map(String.init).joined(separator: ","))")
            if accepted.count == 20 { break }
        }

    case "campaign-number-pairs":
        guard arguments.count >= 4,
              let firstValue = UInt16(arguments[2]),
              let secondValue = UInt16(arguments[3]) else {
            throw GameDataError.unsupported("usage: emperor-inspect campaign-number-pairs <campaign> <u16-a> <u16-b> [maximum-distance]")
        }
        let url = URL(fileURLWithPath: arguments[1])
        let container = try SierraChunkedFile(contentsOf: url)
        let decoded = container.decodedData
        let metadataEnd = container.chunks.prefix(29).reduce(0) { $0 + $1.uncompressedSize }
        let maximumDistance = arguments.count > 4 ? (Int(arguments[4]) ?? 1_000) : 1_000
        func occurrences(of value: UInt16) -> [Int] {
            guard metadataEnd >= 2 else { return [] }
            return (0..<(metadataEnd - 1)).filter { offset in
                UInt16(decoded[offset]) | UInt16(decoded[offset + 1]) << 8 == value
            }
        }
        let firstOffsets = occurrences(of: firstValue)
        let secondOffsets = occurrences(of: secondValue)
        var pairs: [(Int, Int)] = []
        for first in firstOffsets {
            for second in secondOffsets where abs(first - second) <= maximumDistance {
                pairs.append((first, second))
            }
        }
        print("\(firstValue): \(firstOffsets.count), \(secondValue): \(secondOffsets.count), nearby pairs: \(pairs.count)")
        for pair in pairs.prefix(200) {
            print("  \(pair.0) (0x\(String(pair.0, radix: 16))) -> \(pair.1) (0x\(String(pair.1, radix: 16))), delta=\(pair.1 - pair.0)")
        }

    case "campaign-goal-classes":
        let campaigns = try CampaignCatalog.load(game)
        var occurrences: [String: [(String, Int)]] = [:]
        for campaign in campaigns {
            let container = try SierraChunkedFile(contentsOf: campaign.url)
            let decoded = container.decodedData
            let metadataEnd = container.chunks.prefix(29).reduce(0) { $0 + $1.uncompressedSize }
            for offset in 0..<metadataEnd where decoded[offset] == 0x63 {
                var end = offset
                while end < metadataEnd, end - offset < 64 {
                    let byte = decoded[end]
                    guard (65...90).contains(byte) || (97...122).contains(byte) || (48...57).contains(byte) else { break }
                    end += 1
                }
                guard end - offset >= 5,
                      let value = String(data: decoded[offset..<end], encoding: .ascii),
                      value.hasSuffix("Goal") else { continue }
                occurrences[value, default: []].append((campaign.title, offset))
            }
        }
        for goalClass in occurrences.sorted(by: { $0.key < $1.key }) {
            let samples = goalClass.value.prefix(4).map { "\($0.0)@0x\(String($0.1, radix: 16))" }.joined(separator: ", ")
            print("\(goalClass.key): \(goalClass.value.count) [\(samples)]")
        }

    case "campaign-mfc-classes":
        guard arguments.count >= 2 else {
            throw GameDataError.unsupported("usage: emperor-inspect campaign-mfc-classes <campaign>")
        }
        let container = try SierraChunkedFile(contentsOf: URL(fileURLWithPath: arguments[1]))
        let decoded = container.decodedData
        let metadataEnd = container.chunks.prefix(29).reduce(0) { $0 + $1.uncompressedSize }
        var classes: [String: [Int]] = [:]
        guard metadataEnd >= 7 else { throw GameDataError.malformedFile("campaign metadata") }
        for offset in 0..<(metadataEnd - 6) where decoded[offset] == 0xff && decoded[offset + 1] == 0xff {
            let nameLength = Int(decoded[offset + 4]) | Int(decoded[offset + 5]) << 8
            guard (2...64).contains(nameLength), offset + 6 + nameLength <= metadataEnd else { continue }
            let bytes = decoded[(offset + 6)..<(offset + 6 + nameLength)]
            guard bytes.allSatisfy({ (32...126).contains($0) }),
                  let name = String(data: bytes, encoding: .ascii) else { continue }
            classes[name, default: []].append(offset)
        }
        for item in classes.sorted(by: { $0.value[0] < $1.value[0] }) {
            let offsets = item.value.prefix(8).map { "0x" + String($0, radix: 16) }.joined(separator: ",")
            print("\(item.key): \(item.value.count) [\(offsets)]")
        }

    case "campaign-maps":
        guard arguments.count >= 2 else {
            throw GameDataError.unsupported("usage: emperor-inspect campaign-maps <campaign>")
        }
        let catalog = try GameDataCatalog.scan(game)
        let matches = try CampaignEmbeddedMapResolver.resolve(
            campaignURL: URL(fileURLWithPath: arguments[1]),
            candidateMapURLs: catalog.maps.map(\.url)
        )
        for match in matches {
            if match.isEmbedded {
                print("\(match.mapURL.lastPathComponent): chunks \(match.campaignChunkRange.lowerBound)..<\(match.campaignChunkRange.upperBound)")
            } else {
                print("\(match.mapURL.lastPathComponent): external reference")
            }
        }

    case "model-braces":
        let url = game.modelDirectory.appendingPathComponent("EmperorBuildingModels.txt")
        let modelText = try LegacyModelText.read(url)
        let table = LegacyBraceTable(text: modelText, sectionNames: ["BUILDING MODS", "ALL BUILDINGS", "HOUSE MODS", "ALL HOUSES"])
        for section in Dictionary(grouping: table.rows, by: \.section).sorted(by: { $0.key < $1.key }) {
            print("\(section.key): \(section.value.count) rows, first=\(section.value.first?.name ?? "-")")
        }

    case "map":
        guard arguments.count >= 2 else { throw GameDataError.unsupported("usage: emperor-inspect map <file>") }
        let url = URL(fileURLWithPath: arguments[1])
        let probe = try MapProbe(url: url)
        print("\(url.lastPathComponent): \(probe.chunkCount) chunks, \(formattedBytes(probe.decodedByteCount)) decoded")
        print("format=\(probe.formatVersion.map(String.init) ?? "unknown") size=\(probe.width ?? 0)x\(probe.height ?? 0) description=\(probe.description ?? "-")")

    case "map-preview-png":
        guard arguments.count >= 7,
              let focusX = Int(arguments[2]),
              let focusY = Int(arguments[3]),
              let outputWidth = Int(arguments[4]),
              let outputHeight = Int(arguments[5]),
              outputWidth > 0,
              outputHeight > 0 else {
            throw GameDataError.unsupported(
                "usage: emperor-inspect map-preview-png <map> <focus-x> <focus-y> <width> <height> <output-png>"
            )
        }
        let map = try EmperorMap(url: URL(fileURLWithPath: arguments[1]))
        let archiveURL = game.dataDirectory.appendingPathComponent("China_Terrain.sg3")
        let archive = try SG3Archive(contentsOf: archiveURL)
        let pixels = try Data(
            contentsOf: archiveURL.deletingPathExtension().appendingPathExtension("555"),
            options: [.mappedIfSafe]
        )
        let elevationURL = game.dataDirectory.appendingPathComponent("China_Elevation.sg3")
        let elevationArchive = try SG3Archive(contentsOf: elevationURL)
        let elevationPixels = try Data(
            contentsOf: elevationURL.deletingPathExtension().appendingPathExtension("555"),
            options: [.mappedIfSafe]
        )
        guard let context = CGContext(
            data: nil,
            width: outputWidth,
            height: outputHeight,
            bitsPerComponent: 8,
            bytesPerRow: outputWidth * 4,
            space: CGColorSpaceCreateDeviceRGB(),
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        ) else {
            throw GameDataError.unsupported("could not create map preview bitmap")
        }
        context.translateBy(x: 0, y: CGFloat(outputHeight))
        context.scaleBy(x: 1, y: -1)
        context.setFillColor(CGColor(red: 0.32, green: 0.47, blue: 0.12, alpha: 1))
        context.fill(CGRect(x: 0, y: 0, width: outputWidth, height: outputHeight))

        let viewportColumns = min(32, map.width)
        let viewportRows = min(32, map.height)
        let startX = min(max(0, focusX - viewportColumns / 2), max(0, map.width - viewportColumns))
        let startY = min(max(0, focusY - viewportRows / 2), max(0, map.height - viewportRows))
        let tileWidth = CGFloat(80)
        let tileHeight = CGFloat(40)
        let origin = CGPoint(
            x: CGFloat(outputWidth) * 0.5,
            y: CGFloat(outputHeight) * 0.5
                - CGFloat(viewportColumns / 2 + viewportRows / 2) * tileHeight * 0.5
        )
        var decoded: [Int: CGImage] = [:]
        var elevationDecoded: [Int: CGImage] = [:]
        var vegetationDecoded: [Int: CGImage] = [:]
        func terrainImage(localID: Int) -> CGImage? {
            if let cached = decoded[localID] { return cached }
            guard archive.images.indices.contains(localID),
                  let sprite = try? SpriteDecoder.decode(
                    image: archive.images[localID],
                    pixelData: pixels
                  ),
                  let rendered = sprite.makeCGImage() else { return nil }
            decoded[localID] = rendered
            return rendered
        }
        func elevationImage(localID: Int) -> CGImage? {
            if let cached = elevationDecoded[localID] { return cached }
            guard elevationArchive.images.indices.contains(localID),
                  let sprite = try? SpriteDecoder.decode(
                    image: elevationArchive.images[localID],
                    pixelData: elevationPixels
                  ),
                  let rendered = sprite.makeCGImage() else { return nil }
            elevationDecoded[localID] = rendered
            return rendered
        }
        func vegetationImage(localID: Int) -> CGImage? {
            if let cached = vegetationDecoded[localID] { return cached }
            guard archive.images.indices.contains(localID),
                  let sprite = try? SpriteDecoder.decode(
                    image: archive.images[localID],
                    pixelData: pixels
                  ),
                  let rendered = sprite.greenVegetationOnly().makeCGImage() else { return nil }
            vegetationDecoded[localID] = rendered
            return rendered
        }
        func drawTerrainImage(
            _ image: CGImage,
            center: CGPoint,
            scale: CGFloat = 1
        ) {
            let drawWidth = CGFloat(image.width) * scale
            let drawHeight = CGFloat(image.height) * scale
            let rectangle = CGRect(
                x: center.x - drawWidth * 0.5,
                y: center.y + tileHeight * 0.5 - drawHeight,
                width: drawWidth,
                height: drawHeight
            )
            // The preview canvas uses top-left coordinates. CGImage drawing
            // follows Quartz's bottom-left convention, so cancel the canvas
            // flip locally or tall sprites (notably trees) appear upside down.
            context.saveGState()
            context.translateBy(x: rectangle.minX, y: rectangle.maxY)
            context.scaleBy(x: 1, y: -1)
            context.draw(
                image,
                in: CGRect(origin: .zero, size: rectangle.size)
            )
            context.restoreGState()
        }
        var mappedTileCount = 0
        var zeroTileCount = 0
        var unresolvedTileCount = 0
        for diagonal in 0..<(viewportColumns + viewportRows - 1) {
            for row in 0..<viewportRows {
                let column = diagonal - row
                guard column >= 0, column < viewportColumns else { continue }
                let mapX = startX + column
                let mapY = startY + row
                let center = CGPoint(
                    x: origin.x + CGFloat(column - row) * tileWidth * 0.5,
                    y: origin.y + CGFloat(column + row) * tileHeight * 0.5
                )
                let diamond = CGMutablePath()
                diamond.move(to: CGPoint(x: center.x, y: center.y - tileHeight * 0.5))
                diamond.addLine(to: CGPoint(x: center.x + tileWidth * 0.5, y: center.y))
                diamond.addLine(to: CGPoint(x: center.x, y: center.y + tileHeight * 0.5))
                diamond.addLine(to: CGPoint(x: center.x - tileWidth * 0.5, y: center.y))
                diamond.closeSubpath()
                let terrain = map.terrain(at: GridPoint(x: mapX, y: mapY))
                if terrain?.contains(.water) == true {
                    context.setFillColor(CGColor(red: 0.13, green: 0.32, blue: 0.42, alpha: 1))
                } else {
                    context.setFillColor(CGColor(red: 0.32, green: 0.47, blue: 0.12, alpha: 1))
                }
                context.addPath(diamond)
                context.fillPath()
                // Elevation (including Banpo 0x40000 object IDs) before fertile
                // grass, otherwise cliff faces collapse to the grass bed.
                if let elevID = map.chinaElevationSpriteID(
                    x: mapX,
                    y: mapY,
                    imageCount: elevationArchive.images.count
                ), let image = elevationImage(localID: elevID) {
                    mappedTileCount += 1
                    drawTerrainImage(image, center: center)
                    continue
                }
                let plainFertile = terrain?.contains(.fertile) == true
                    && terrain?.intersection([
                        .tree, .rock, .water, .building, .road, .flood,
                        .elevation, .irrigation, .wall, .beach, .quarry,
                        .saltMarsh, .offMap, .pinnacle, .deepWater, .monument
                    ]).isEmpty == true
                if plainFertile {
                    if let grass = vegetationImage(
                        localID: 238 + abs(mapX &* 31 &+ mapY &* 17) % 9
                    ) {
                        drawTerrainImage(grass, center: center, scale: 1.10)
                    }
                    mappedTileCount += 1
                    continue
                } else if let localID = map.chinaTerrainSpriteID(
                    x: mapX,
                    y: mapY,
                    imageCount: archive.images.count
                ) {
                    if let image = terrainImage(localID: localID) {
                        mappedTileCount += 1
                        drawTerrainImage(image, center: center)
                        continue
                    }
                }
                if map.imageID(x: mapX, y: mapY) == 0 {
                    zeroTileCount += 1
                } else {
                    unresolvedTileCount += 1
                    if terrain?.contains(.water) != true,
                       terrain?.contains(.deepWater) != true,
                       terrain?.contains(.elevation) != true,
                       let fallback = terrainImage(
                        localID: 238 + abs(mapX &* 31 &+ mapY &* 17) % 9
                       ) {
                        drawTerrainImage(fallback, center: center)
                    }
                }
            }
        }
        guard let preview = context.makeImage(),
              let destination = CGImageDestinationCreateWithURL(
                URL(fileURLWithPath: arguments[6]) as CFURL,
                "public.png" as CFString,
                1,
                nil
              ) else {
            throw GameDataError.unsupported("could not create map preview PNG")
        }
        CGImageDestinationAddImage(destination, preview, nil)
        guard CGImageDestinationFinalize(destination) else {
            throw GameDataError.unsupported("could not write map preview PNG")
        }
        print(
            "wrote \(arguments[6]) focus=\(focusX),\(focusY) "
                + "viewport=\(startX),\(startY) \(viewportColumns)x\(viewportRows) "
                + "mapped=\(mappedTileCount) zero=\(zeroTileCount) unresolved=\(unresolvedTileCount)"
        )

    case "map-images":
        guard arguments.count >= 2 else { throw GameDataError.unsupported("usage: emperor-inspect map-images <file>") }
        let map = try EmperorMap(url: URL(fileURLWithPath: arguments[1]))
        let terrainImageCount = try SG3Archive(
            contentsOf: game.dataDirectory.appendingPathComponent("China_Terrain.sg3")
        ).images.count
        let elevationArchive = try SG3Archive(
            contentsOf: game.dataDirectory.appendingPathComponent("China_Elevation.sg3")
        )
        let dirtElevationImageCount = try SG3Archive(
            contentsOf: game.dataDirectory.appendingPathComponent("China_Elevation_dirt.sg3")
        ).images.count
        let greatWallImageCount = try SG3Archive(
            contentsOf: game.dataDirectory.appendingPathComponent("China_Mon_GreatWall_1.sg3")
        ).images.count
        let grandCanalImageCount = try SG3Archive(
            contentsOf: game.dataDirectory.appendingPathComponent("China_Mon_Grand_Canal.sg3")
        ).images.count
        let earthenGreatWallImageCount = try SG3Archive(
            contentsOf: game.dataDirectory.appendingPathComponent(
                "China_Mon_Earthen_Greatwall_1.sg3"
            )
        ).images.count
        let cells = (0..<map.height).flatMap { y in
            (0..<map.width).compactMap { x -> (UInt32, Int?, Int?, Int?, Int?, Int?, Int?)? in
                guard let imageID = map.imageID(x: x, y: y) else { return nil }
                return (
                    imageID,
                    map.chinaTerrainSpriteID(x: x, y: y, imageCount: terrainImageCount),
                    map.chinaElevationSpriteID(
                        x: x,
                        y: y,
                        imageCount: elevationArchive.images.count
                    ),
                    map.chinaElevationDirtSpriteID(x: x, y: y, imageCount: dirtElevationImageCount),
                    map.chinaGreatWall1SpriteID(x: x, y: y, imageCount: greatWallImageCount),
                    map.chinaGrandCanalSpriteID(x: x, y: y, imageCount: grandCanalImageCount),
                    map.chinaEarthenGreatWall1SpriteID(
                        x: x,
                        y: y,
                        imageCount: earthenGreatWallImageCount
                    )
                )
            }
        }
        let active = cells.map(\.0)
        let nonzero = active.filter { $0 != 0 }
        let terrain = cells.compactMap(\.1)
        let elevation = cells.compactMap(\.2)
        let dirtElevation = cells.compactMap(\.3)
        let greatWall = cells.compactMap(\.4)
        let grandCanal = cells.compactMap(\.5)
        let earthenGreatWall = cells.compactMap(\.6)
        let unresolved = cells.compactMap { cell in
            cell.0 != 0 && cell.1 == nil && cell.2 == nil && cell.3 == nil
                && cell.4 == nil && cell.5 == nil && cell.6 == nil ? cell.0 : nil
        }
        let parityCounts = (0..<map.height).reduce(into: [0, 0]) { result, y in
            for x in 0..<map.width where map.imageID(x: x, y: y) != 0 {
                result[(x + y) & 1] += 1
            }
        }
        print("\(map.url.lastPathComponent): active=\(active.count), nonzero=\(nonzero.count), unique=\(Set(nonzero).count)")
        print("  nonzero parity even=\(parityCounts[0]), odd=\(parityCounts[1])")
        print("  global range=\(nonzero.min() ?? 0)...\(nonzero.max() ?? 0)")
        print("  China_Terrain local range=\(terrain.min() ?? 0)...\(terrain.max() ?? 0), mapped=\(terrain.count)")
        print("  China_Elevation local range=\(elevation.min() ?? 0)...\(elevation.max() ?? 0), mapped=\(elevation.count)")
        print("  China_Elevation_dirt mapped=\(dirtElevation.count), China_Mon_GreatWall_1 mapped=\(greatWall.count), China_Mon_Grand_Canal mapped=\(grandCanal.count), China_Mon_Earthen_Greatwall_1 mapped=\(earthenGreatWall.count)")
        print("  unresolved nonzero=\(unresolved.count), unique=\(Set(unresolved).count), range=\(unresolved.min() ?? 0)...\(unresolved.max() ?? 0)")
        print("  unresolved common: \(Dictionary(grouping: unresolved, by: { $0 }).mapValues(\.count).sorted { $0.value > $1.value }.prefix(12).map { "\($0.key):\($0.value)" }.joined(separator: ", "))")
        print("  most common: \(Dictionary(grouping: nonzero, by: { $0 }).mapValues(\.count).sorted { $0.value > $1.value }.prefix(12).map { "\($0.key):\($0.value)" }.joined(separator: ", "))")

    case "map-flag-images":
        guard arguments.count >= 3 else {
            throw GameDataError.unsupported(
                "usage: emperor-inspect map-flag-images <map> <raw-flags-hex>"
            )
        }
        let rawText = arguments[2].lowercased().hasPrefix("0x")
            ? String(arguments[2].dropFirst(2)) : arguments[2]
        guard let requestedFlags = UInt32(rawText, radix: 16) else {
            throw GameDataError.unsupported("raw flags must be hexadecimal")
        }
        let map = try EmperorMap(url: URL(fileURLWithPath: arguments[1]))
        let archive = try SG3Archive(
            contentsOf: game.dataDirectory.appendingPathComponent("China_Terrain.sg3")
        )
        let matches = (0..<map.height).flatMap { y in
            (0..<map.width).compactMap { x -> (UInt32, Int?)? in
                guard map.terrainFlags(x: x, y: y) == requestedFlags,
                      let globalID = map.imageID(x: x, y: y) else { return nil }
                return (
                    globalID,
                    map.chinaTerrainSpriteID(x: x, y: y, imageCount: archive.images.count)
                )
            }
        }
        let localCounts = Dictionary(grouping: matches.compactMap(\.1), by: { $0 })
            .mapValues(\.count)
            .sorted { $0.value > $1.value }
        let unresolvedCounts = Dictionary(
            grouping: matches.filter { $0.1 == nil }.map(\.0),
            by: { $0 }
        ).mapValues(\.count).sorted { $0.value > $1.value }
        print(
            "\(map.url.lastPathComponent): flags=0x\(String(requestedFlags, radix: 16)) "
                + "cells=\(matches.count) mapped=\(matches.count - unresolvedCounts.reduce(0) { $0 + $1.value })"
        )
        for item in localCounts.prefix(40) {
            let image = archive.images[item.key]
            let logical = logicalAnimationPosition(archive, imageID: item.key)?.logicalGroup
            print(
                "  local #\(item.key) count=\(item.value) "
                    + "size=\(image.width)x\(image.height) "
                    + "logical=\(logical.map(String.init) ?? "-") "
                    + "bitmap=\(semanticBitmapName(archive, imageID: item.key))"
            )
        }
        if !unresolvedCounts.isEmpty {
            print(
                "  unresolved: "
                    + unresolvedCounts.prefix(40)
                        .map { "\($0.key):\($0.value)" }
                        .joined(separator: ", ")
            )
        }

    case "map-image-range":
        guard arguments.count >= 4,
              let lower = UInt32(arguments[2]),
              let upper = UInt32(arguments[3]),
              lower <= upper else {
            throw GameDataError.unsupported("usage: emperor-inspect map-image-range <file> <lower> <upper>")
        }
        let map = try EmperorMap(url: URL(fileURLWithPath: arguments[1]))
        var matches: [UInt32: [(GridPoint, UInt32)]] = [:]
        for y in 0..<map.height {
            for x in 0..<map.width {
                guard let imageID = map.imageID(x: x, y: y),
                      (lower...upper).contains(imageID) else { continue }
                matches[imageID, default: []].append((
                    GridPoint(x: x, y: y),
                    map.terrainFlags(x: x, y: y) ?? 0
                ))
            }
        }
        print("\(map.url.lastPathComponent): image IDs \(lower)...\(upper), cells=\(matches.values.reduce(0) { $0 + $1.count })")
        for item in matches.sorted(by: { $0.key < $1.key }) {
            let flagCounts = Dictionary(grouping: item.value, by: \.1).mapValues(\.count)
            let flags = flagCounts.sorted { $0.value > $1.value }.prefix(4)
                .map { String(format: "0x%08x:%d", $0.key, $0.value) }
                .joined(separator: ",")
            let samples = item.value.prefix(4).map { "(\($0.0.x),\($0.0.y))" }.joined(separator: ",")
            print("  \(item.key): \(item.value.count), flags=[\(flags)], cells=\(samples)")
        }

    case "map-cliffs":
        guard arguments.count >= 2 else {
            throw GameDataError.unsupported("usage: emperor-inspect map-cliffs <file>")
        }
        let map = try EmperorMap(url: URL(fileURLWithPath: arguments[1]))
        let elevationArchive = try SG3Archive(
            contentsOf: game.dataDirectory.appendingPathComponent("China_Elevation.sg3")
        )
        func isPackedCliff(_ x: Int, _ y: Int) -> Bool {
            guard let imageID = map.imageID(x: x, y: y) else { return false }
            return imageID >> 14
                == EmperorMap.chinaElevationObjectImageFlag >> 14
        }
        func compassMask(x: Int, y: Int, predicate: (Int, Int) -> Bool) -> Int {
            var result = 0
            if predicate(x, y - 1) { result |= 1 }
            if predicate(x + 1, y) { result |= 2 }
            if predicate(x, y + 1) { result |= 4 }
            if predicate(x - 1, y) { result |= 8 }
            return result
        }
        var rows: [String] = []
        for y in 0..<map.height {
            for x in 0..<map.width {
                guard let globalID = map.imageID(x: x, y: y),
                      globalID >> 14
                        == EmperorMap.chinaElevationObjectImageFlag >> 14,
                      let rawSpriteID = map.chinaElevationObjectSpriteID(
                        x: x,
                        y: y,
                        imageCount: elevationArchive.images.count
                      ) else { continue }
                let raisedMask = map.chinaElevationNeighborMask(x: x, y: y)
                let displaySpriteID = EmperorMap.chinaElevationDisplaySpriteID(
                    rawSpriteID,
                    neighborMask: raisedMask
                )
                let cliffMask = compassMask(x: x, y: y, predicate: isPackedCliff)
                let flags = map.terrainFlags(x: x, y: y) ?? 0
                let edge = map.edgeValue(x: x, y: y) ?? 0
                rows.append(
                    String(
                        format: "%d,%d,%u,%d,%d,0x%08x,%u,0x%x,0x%x",
                        x,
                        y,
                        globalID,
                        rawSpriteID,
                        displaySpriteID,
                        flags,
                        edge,
                        raisedMask,
                        cliffMask
                    )
                )
            }
        }
        print("x,y,global_id,raw_sg3_id,display_sg3_id,terrain_flags,edge,raised_nesw,cliff_nesw")
        for row in rows { print(row) }

    case "map-hex":
        guard arguments.count >= 2 else {
            throw GameDataError.unsupported("usage: emperor-inspect map-hex <file> [offset] [length]")
        }
        let url = URL(fileURLWithPath: arguments[1])
        let decoded = try SierraChunkedFile(contentsOf: url).decodedData
        let offset = arguments.count > 2 ? (Int(arguments[2]) ?? 0) : 0
        let length = arguments.count > 3 ? (Int(arguments[3]) ?? 256) : 256
        guard offset >= 0, length > 0, offset + length <= decoded.count else {
            throw GameDataError.unsupported("requested range is outside decoded data")
        }
        for rowOffset in stride(from: offset, to: offset + length, by: 16) {
            let rowEnd = min(rowOffset + 16, offset + length)
            let hex = decoded[rowOffset..<rowEnd].map { String(format: "%02x", $0) }.joined(separator: " ")
            let ascii = decoded[rowOffset..<rowEnd].map { (32...126).contains($0) ? Character(UnicodeScalar($0)) : "." }.map(String.init).joined()
            print(String(format: "%08x", rowOffset) + "  " + hex.padding(toLength: 47, withPad: " ", startingAt: 0) + "  " + ascii)
        }

    case "map-cell":
        guard arguments.count >= 4,
              let x = Int(arguments[2]),
              let y = Int(arguments[3]) else {
            throw GameDataError.unsupported("usage: emperor-inspect map-cell <file> <x> <y>")
        }
        let map = try EmperorMap(url: URL(fileURLWithPath: arguments[1]))
        guard let flags = map.terrainFlags(x: x, y: y) else {
            throw GameDataError.unsupported("map-cell coordinate outside active map")
        }
        print(String(
            format: "(%d,%d): flags=0x%08x image=%u edge=%u legacy=[%@]",
            x,
            y,
            flags,
            map.imageID(x: x, y: y) ?? 0,
            map.edgeValue(x: x, y: y) ?? 0,
            (0..<map.legacyByteGrids.count).map { String(map.legacyByteValue(grid: $0, x: x, y: y) ?? 0) }.joined(separator: ",")
        ))

    case "map-point-candidates":
        guard arguments.count >= 2 else {
            throw GameDataError.unsupported("usage: emperor-inspect map-point-candidates <file>")
        }
        let url = URL(fileURLWithPath: arguments[1])
        let decoded = try SierraChunkedFile(contentsOf: url).decodedData
        let map = try EmperorMap(url: url)
        func uint16(at offset: Int) -> Int {
            Int(decoded[offset]) | (Int(decoded[offset + 1]) << 8)
        }
        for offset in stride(from: 0x100, through: EmperorMap.headerByteCount - 8, by: 2) {
            let x1 = uint16(at: offset)
            let y1 = uint16(at: offset + 2)
            let x2 = uint16(at: offset + 4)
            let y2 = uint16(at: offset + 6)
            guard x1 < map.width, y1 < map.height, x2 < map.width, y2 < map.height else { continue }
            let f1 = map.terrainFlags(x: x1, y: y1) ?? 0
            let f2 = map.terrainFlags(x: x2, y: y2) ?? 0
            let water1 = f1 & 4 != 0
            let water2 = f2 & 4 != 0
            let edge1 = min(x1, y1, map.width - 1 - x1, map.height - 1 - y1)
            let edge2 = min(x2, y2, map.width - 1 - x2, map.height - 1 - y2)
            guard edge1 <= 16 || edge2 <= 16 else { continue }
            print(String(format: "0x%03x (%d,%d) (%d,%d) water=%d/%d edge=%d/%d flags=%08x/%08x", offset, x1, y1, x2, y2, water1 ? 1 : 0, water2 ? 1 : 0, edge1, edge2, f1, f2))
        }

    case "map-point-score":
        guard arguments.count >= 2 else {
            throw GameDataError.unsupported("usage: emperor-inspect map-point-score <directory>")
        }
        let directory = URL(fileURLWithPath: arguments[1], isDirectory: true)
        let urls = try FileManager.default.contentsOfDirectory(at: directory, includingPropertiesForKeys: nil)
            .filter { $0.pathExtension.lowercased() == "map" }
        struct PointScore { var valid = 0; var land = 0; var water = 0; var mixed = 0; var nearEdge = 0 }
        var scores: [Int: PointScore] = [:]
        for url in urls {
            guard let decoded = try? SierraChunkedFile(contentsOf: url).decodedData,
                  let map = try? EmperorMap(url: url) else { continue }
            func uint16(at offset: Int) -> Int { Int(decoded[offset]) | (Int(decoded[offset + 1]) << 8) }
            for offset in stride(from: 0x2b0, through: 0x3b0, by: 2) {
                let x1 = uint16(at: offset), y1 = uint16(at: offset + 2)
                let x2 = uint16(at: offset + 4), y2 = uint16(at: offset + 6)
                guard x1 > 0, y1 > 0, x2 > 0, y2 > 0,
                      x1 < map.width, y1 < map.height, x2 < map.width, y2 < map.height else { continue }
                let water1 = (map.terrainFlags(x: x1, y: y1) ?? 0) & 4 != 0
                let water2 = (map.terrainFlags(x: x2, y: y2) ?? 0) & 4 != 0
                let edge1 = min(x1, y1, map.width - 1 - x1, map.height - 1 - y1)
                let edge2 = min(x2, y2, map.width - 1 - x2, map.height - 1 - y2)
                var score = scores[offset, default: PointScore()]
                score.valid += 1
                if water1 && water2 { score.water += 1 }
                else if !water1 && !water2 { score.land += 1 }
                else { score.mixed += 1 }
                if edge1 <= 16 && edge2 <= 16 { score.nearEdge += 1 }
                scores[offset] = score
            }
        }
        print("maps=\(urls.count)")
        for item in scores.sorted(by: { $0.key < $1.key }) where item.value.valid >= max(4, urls.count / 8) {
            let value = item.value
            print(String(format: "0x%03x valid=%3d land=%3d water=%3d mixed=%3d near=%3d", item.key, value.valid, value.land, value.water, value.mixed, value.nearEdge))
        }

    case "map-schema-candidates":
        guard arguments.count >= 2 else {
            throw GameDataError.unsupported("usage: emperor-inspect map-schema-candidates <file>")
        }
        let url = URL(fileURLWithPath: arguments[1])
        let decoded = try SierraChunkedFile(contentsOf: url).decodedData
        let binary = BinaryReader(data: decoded)
        for offset in stride(from: 0, to: min(decoded.count - 24, 128_000), by: 4) {
            let count = Int(try binary.uint32LE(at: offset))
            guard (8...400).contains(count), offset + 4 + count * 20 <= decoded.count else { continue }
            var plausible = 0
            var products: [Int] = []
            for index in 0..<min(count, 40) {
                let base = offset + 4 + index * 20
                let compressed = try binary.uint32LE(at: base)
                let fieldSize = Int(try binary.uint32LE(at: base + 8))
                let fieldCount = Int(try binary.uint32LE(at: base + 12))
                let tail = try binary.uint32LE(at: base + 16)
                guard compressed <= 1, fieldSize > 0, fieldSize <= 2_000_000,
                      fieldCount > 0, fieldCount <= 2_000_000, tail == 0 else { break }
                plausible += 1
                products.append(fieldSize * fieldCount)
            }
            if plausible >= min(count, 8) {
                print("offset=\(offset) count=\(count) records=\(plausible) sizes=\(products.prefix(12).map(String.init).joined(separator: ","))")
            }
        }

    case "map-chunks":
        guard arguments.count >= 2 else {
            throw GameDataError.unsupported("usage: emperor-inspect map-chunks <file>")
        }
        let url = URL(fileURLWithPath: arguments[1])
        let container = try SierraChunkedFile(contentsOf: url)
        for chunk in container.chunks {
            let nonzero = chunk.data.reduce(into: 0) { if $1 != 0 { $0 += 1 } }
            let unique = Set(chunk.data).count
            let percent = Double(nonzero) * 100 / Double(chunk.data.count)
            print(String(format: "  %02d decoded=%6d compressed=%6d nonzero=%5.1f%% unique=%3d", chunk.index, chunk.uncompressedSize, chunk.compressedSize, percent, unique))
        }

    case "map-grid-candidates":
        guard arguments.count >= 2 else {
            throw GameDataError.unsupported("usage: emperor-inspect map-grid-candidates <file>")
        }
        let url = URL(fileURLWithPath: arguments[1])
        let decoded = try SierraChunkedFile(contentsOf: url).decodedData
        let metadata = BinaryReader(data: decoded)
        let width = Int(try metadata.uint32LE(at: 0x54))
        let height = Int(try metadata.uint32LE(at: 0x58))
        let start = Int(try metadata.uint32LE(at: 0x5c))
        let x0 = start % 228
        let y0 = start / 228

        func value(at byteOffset: Int, bytes: Int) -> UInt32 {
            switch bytes {
            case 1:
                return UInt32(decoded[byteOffset])
            case 2:
                return UInt32(decoded[byteOffset]) | UInt32(decoded[byteOffset + 1]) << 8
            default:
                return UInt32(decoded[byteOffset])
                    | UInt32(decoded[byteOffset + 1]) << 8
                    | UInt32(decoded[byteOffset + 2]) << 16
                    | UInt32(decoded[byteOffset + 3]) << 24
            }
        }

        let outsidePoints = [(0, 0), (50, 0), (227, 0), (0, 50), (227, 50),
                             (0, 113), (227, 113), (0, 177), (227, 177),
                             (0, 227), (113, 227), (227, 227),
                             (x0 - 1, y0), (x0 + width, y0),
                             (x0 - 1, y0 + height - 1), (x0 + width, y0 + height - 1)]
        let insidePoints = stride(from: 0, to: height, by: max(1, height / 8)).flatMap { y in
            stride(from: 0, to: width, by: max(1, width / 8)).map { x in (x0 + x, y0 + y) }
        }

        for bytes in [1, 2, 4] {
            let gridBytes = 228 * 228 * bytes
            var matches: [(score: Int, offset: Int, outside: UInt32, distinct: Int)] = []
            for base in stride(from: 0, through: decoded.count - gridBytes, by: bytes) {
                let outsideValues = outsidePoints.map { point in value(at: base + (point.1 * 228 + point.0) * bytes, bytes: bytes) }
                let counts = Dictionary(grouping: outsideValues, by: { $0 }).mapValues(\.count)
                guard let dominant = counts.max(by: { $0.value < $1.value }), dominant.value >= 14 else { continue }
                let insideValues = insidePoints.map { point in value(at: base + (point.1 * 228 + point.0) * bytes, bytes: bytes) }
                let distinct = Set(insideValues).count
                let differing = insideValues.count(where: { $0 != dominant.key })
                let score = dominant.value * 4 + min(distinct, 24) * 2 + differing
                guard distinct >= 3, differing >= insideValues.count / 5 else { continue }
                matches.append((score, base, dominant.key, distinct))
            }
            print("elementBytes=\(bytes)")
            for match in matches.sorted(by: { $0.score > $1.score }).prefix(12) {
                print(String(format: "  offset=%8d score=%3d outside=0x%08x sampledDistinct=%d", match.offset, match.score, match.outside, match.distinct))
            }
        }

    case "map-layout":
        guard arguments.count >= 2 else {
            throw GameDataError.unsupported("usage: emperor-inspect map-layout <file>")
        }
        let url = URL(fileURLWithPath: arguments[1])
        let decoded = try SierraChunkedFile(contentsOf: url).decodedData
        let map = try EmperorMap(url: url)
        let x0 = map.startOffset % EmperorMap.gridSide
        let y0 = map.startOffset / EmperorMap.gridSide
        print("\(url.lastPathComponent): header=\(EmperorMap.headerByteCount), image=u32@\(EmperorMap.imageGridOffset), edge=u8@\(EmperorMap.edgeGridOffset), terrain=u32@\(EmperorMap.terrainGridOffset)")
        for unit in 9..<36 {
            let base = EmperorMap.headerByteCount + unit * EmperorMap.gridCellCount
            guard base + EmperorMap.gridCellCount <= decoded.count else { break }
            var activeCounts: [UInt8: Int] = [:]
            var outsideCounts: [UInt8: Int] = [:]
            for y in 0..<EmperorMap.gridSide {
                for x in 0..<EmperorMap.gridSide {
                    let value = decoded[base + y * EmperorMap.gridSide + x]
                    if x >= x0, x < x0 + map.width, y >= y0, y < y0 + map.height {
                        activeCounts[value, default: 0] += 1
                    } else {
                        outsideCounts[value, default: 0] += 1
                    }
                }
            }
            let activeTop = activeCounts.sorted { $0.value > $1.value }.prefix(5).map { "\($0.key):\($0.value)" }.joined(separator: ",")
            let outsideTop = outsideCounts.sorted { $0.value > $1.value }.prefix(2).map { "\($0.key):\($0.value)" }.joined(separator: ",")
            print(String(format: "  unit=%02d offset=%7d active{%3d} [%@] outside{%3d} [%@]", unit, base, activeCounts.count, activeTop, outsideCounts.count, outsideTop))
        }

    case "map-terrain-correlate":
        guard arguments.count >= 2 else {
            throw GameDataError.unsupported("usage: emperor-inspect map-terrain-correlate <file>")
        }
        let map = try EmperorMap(url: URL(fileURLWithPath: arguments[1]))
        let archive = try SG3Archive(contentsOf: game.dataDirectory.appendingPathComponent("China_Terrain.sg3"))
        var byGroup: [Int: [UInt32: Int]] = [:]
        var groupTotals: [Int: Int] = [:]
        var bySprite: [Int: [UInt32: Int]] = [:]
        var spriteTotals: [Int: Int] = [:]
        var bitCounts: [Int: Int] = [:]
        var roadPoints: [GridPoint] = []
        for y in 0..<map.height {
            for x in 0..<map.width {
                if map.terrain(at: GridPoint(x: x, y: y))?.contains(.road) == true {
                    roadPoints.append(GridPoint(x: x, y: y))
                }
                guard let spriteID = map.chinaTerrainSpriteID(x: x, y: y, imageCount: archive.images.count),
                      let flags = map.terrainFlags(x: x, y: y) else { continue }
                let group = archive.images[spriteID].groupID
                byGroup[group, default: [:]][flags, default: 0] += 1
                groupTotals[group, default: 0] += 1
                bySprite[spriteID, default: [:]][flags, default: 0] += 1
                spriteTotals[spriteID, default: 0] += 1
                for bit in 0..<32 where flags & (UInt32(1) << UInt32(bit)) != 0 {
                    bitCounts[bit, default: 0] += 1
                }
            }
        }
        print("\(map.url.lastPathComponent): mapped terrain tiles=\(groupTotals.values.reduce(0, +))")
        if let minX = roadPoints.map(\.x).min(),
           let maxX = roadPoints.map(\.x).max(),
           let minY = roadPoints.map(\.y).min(),
           let maxY = roadPoints.map(\.y).max() {
            let center = GridPoint(x: map.width / 2, y: map.height / 2)
            let nearest = roadPoints.min {
                let lhs = ($0.x - center.x) * ($0.x - center.x)
                    + ($0.y - center.y) * ($0.y - center.y)
                let rhs = ($1.x - center.x) * ($1.x - center.x)
                    + ($1.y - center.y) * ($1.y - center.y)
                if lhs != rhs { return lhs < rhs }
                return $0.y == $1.y ? $0.x < $1.x : $0.y < $1.y
            }
            print(
                "  roads=\(roadPoints.count) bbox=\(minX),\(minY)...\(maxX),\(maxY) "
                    + "nearest-center=\(nearest.map { "\($0.x),\($0.y)" } ?? "-")"
            )
        }
        for group in groupTotals.sorted(by: { $0.value > $1.value }).prefix(30) {
            let top = (byGroup[group.key] ?? [:]).sorted { $0.value > $1.value }.prefix(4)
                .map { String(format: "0x%08x:%d", $0.key, $0.value) }.joined(separator: ",")
            print("  group=\(group.key) tiles=\(group.value) flags=[\(top)]")
        }
        print("  top local sprites:")
        for sprite in spriteTotals.sorted(by: { $0.value > $1.value }).prefix(35) {
            let top = (bySprite[sprite.key] ?? [:]).sorted { $0.value > $1.value }.prefix(3)
                .map { String(format: "0x%08x:%d", $0.key, $0.value) }.joined(separator: ",")
            print("    #\(sprite.key) tiles=\(sprite.value) flags=[\(top)]")
        }
        print("  set bits: \(bitCounts.sorted { $0.key < $1.key }.map { "\($0.key):\($0.value)" }.joined(separator: ", "))")

    case "sg3":
        guard arguments.count >= 2 else { throw GameDataError.unsupported("usage: emperor-inspect sg3 <file>") }
        let url = URL(fileURLWithPath: arguments[1])
        let archive = try SG3Archive(contentsOf: url)
        print("\(url.lastPathComponent): version=\(archive.header.version), entries=\(archive.images.count), names=\(archive.header.bitmapNamesUsed)")
        print("  local=\(archive.images.count { !$0.isExternal }), external=\(archive.images.count { $0.isExternal }), nonempty=\(archive.images.count { $0.width > 0 && $0.height > 0 })")
        print("  bitmaps: \(archive.bitmapNames.prefix(archive.header.bitmapNamesUsed).filter { !$0.isEmpty }.joined(separator: ", "))")
        print("  group starts: \(archive.groupImageIDs.enumerated().filter { $0.element != 0 }.map { "\($0.offset)=\($0.element)" }.joined(separator: ", "))")
        for image in archive.images.filter({ $0.width > 0 && $0.height > 0 }).prefix(20) {
            print("  #\(image.id) \(image.width)x\(image.height) type=\(image.type) offset=\(image.dataOffset) bytes=\(image.dataLength) compressed=\(image.isFullyCompressed)")
        }

    case "data-images-catalog":
        guard arguments.count >= 2 else {
            throw GameDataError.unsupported(
                "usage: emperor-inspect data-images-catalog <DATA_IMAGES-directory>"
            )
        }
        let outputDirectory = URL(
            fileURLWithPath: arguments[1],
            isDirectory: true
        )
        let count = try writeCompleteSpriteCatalog(to: outputDirectory)
        print(
            "wrote \(outputDirectory.appendingPathComponent("SPRITE_CATALOG.png").path) "
                + "with \(count) category previews"
        )

    case "sg3-export-all":
        guard arguments.count >= 3 else {
            throw GameDataError.unsupported(
                "usage: emperor-inspect sg3-export-all <data-directory> <output-directory>"
            )
        }
        let dataDirectory = URL(fileURLWithPath: arguments[1], isDirectory: true)
        let outputDirectory = URL(fileURLWithPath: arguments[2], isDirectory: true)
        let fileManager = FileManager.default
        try fileManager.createDirectory(
            at: outputDirectory,
            withIntermediateDirectories: true
        )
        let archives = try fileManager.contentsOfDirectory(
            at: dataDirectory,
            includingPropertiesForKeys: nil,
            options: [.skipsHiddenFiles]
        ).filter {
            $0.pathExtension.lowercased() == "sg3"
        }.sorted {
            $0.lastPathComponent.localizedStandardCompare($1.lastPathComponent)
                == .orderedAscending
        }
        var globalCSV = [
            "archive,image_id,bitmap_id,bitmap_category,logical_group,direction,frame,width,height,type,path,status"
        ]
        var exportedCount = 0
        var failedCount = 0
        var skippedArchives: [String] = []

        for archiveURL in archives {
            let archiveName = archiveURL.deletingPathExtension().lastPathComponent
            let pixelsURL = archiveURL.deletingPathExtension().appendingPathExtension("555")
            guard fileManager.fileExists(atPath: pixelsURL.path) else {
                skippedArchives.append("\(archiveURL.lastPathComponent)：缺少配对的 .555")
                continue
            }
            let archive = try SG3Archive(contentsOf: archiveURL)
            let pixels = try Data(contentsOf: pixelsURL, options: [.mappedIfSafe])
            let archiveDirectory = outputDirectory.appendingPathComponent(
                safePathComponent(archiveName, fallback: "archive"),
                isDirectory: true
            )
            try fileManager.createDirectory(
                at: archiveDirectory,
                withIntermediateDirectories: true
            )

            var categoryIDs: [String: [Int]] = [:]
            var categoryNames: [String: String] = [:]
            var categoryBitmapIDs: [String: Int?] = [:]
            for image in archive.images
                where image.width > 0 && image.height > 0 && !image.isExternal {
                let bitmap = exportBitmap(archive, image: image)
                let categoryName = bitmap?.name ?? "Unclassified"
                let categoryID = bitmap?.id
                let prefix = categoryID.map { String(format: "%03d", $0) } ?? "999"
                let key = prefix + "_" + safePathComponent(
                    categoryName,
                    fallback: "Unclassified"
                )
                categoryIDs[key, default: []].append(image.id)
                categoryNames[key] = categoryName
                categoryBitmapIDs[key] = categoryID
            }

            var archiveCSV = [
                "image_id,bitmap_id,bitmap_category,logical_group,direction,frame,width,height,type,path,status"
            ]
            var archiveExported = 0
            for key in categoryIDs.keys.sorted() {
                let categoryDirectory = archiveDirectory.appendingPathComponent(
                    key,
                    isDirectory: true
                )
                try fileManager.createDirectory(
                    at: categoryDirectory,
                    withIntermediateDirectories: true
                )
                let categoryName = categoryNames[key] ?? "Unclassified"
                let bitmapID = categoryBitmapIDs[key] ?? nil
                var sheetSprites: [ContactSheetSprite] = []
                var sheetNumber = 1

                func flushContactSheet() throws {
                    guard let sheet = contactSheet(sheetSprites) else { return }
                    let sheetURL = categoryDirectory.appendingPathComponent(
                        String(format: "CONTACT_SHEET_%03d.png", sheetNumber)
                    )
                    try writePNG(sheet, to: sheetURL)
                    sheetSprites.removeAll(keepingCapacity: true)
                    sheetNumber += 1
                }

                for imageID in categoryIDs[key, default: []].sorted() {
                    let record = archive.images[imageID]
                    let fileName = String(
                        format: "%06d_%dx%d.png",
                        imageID,
                        record.width,
                        record.height
                    )
                    let imageURL = categoryDirectory.appendingPathComponent(fileName)
                    let archiveComponent = safePathComponent(
                        archiveName,
                        fallback: "archive"
                    )
                    let relativePath = "\(archiveComponent)/\(key)/\(fileName)"
                    let logical = logicalAnimationPosition(archive, imageID: imageID)
                    let bitmapIDText = bitmapID.map { String($0) } ?? ""
                    let logicalGroupText = logical.map { String($0.logicalGroup) } ?? ""
                    let directionText = logical.map { String($0.direction) } ?? ""
                    let frameText = logical.map { String($0.frame) } ?? ""
                    let values: [String] = [
                        String(imageID),
                        bitmapIDText,
                        csvField(categoryName),
                        logicalGroupText,
                        directionText,
                        frameText,
                        String(record.width),
                        String(record.height),
                        String(record.type),
                        csvField(relativePath),
                    ]
                    do {
                        let decoded = try SpriteDecoder.decode(
                            image: record,
                            pixelData: pixels
                        )
                        guard let image = decoded.makeCGImage() else {
                            throw GameDataError.unsupported(
                                "could not create CGImage for #\(imageID)"
                            )
                        }
                        try writePNG(image, to: imageURL)
                        sheetSprites.append(ContactSheetSprite(
                            imageID: imageID,
                            image: image
                        ))
                        if sheetSprites.count == 64 {
                            try flushContactSheet()
                        }
                        let row = (values + ["ok"]).joined(separator: ",")
                        archiveCSV.append(row)
                        globalCSV.append(
                            ([csvField(archiveName)] + values + ["ok"])
                                .joined(separator: ",")
                        )
                        archiveExported += 1
                        exportedCount += 1
                    } catch {
                        let status = csvField("error: \(error.localizedDescription)")
                        archiveCSV.append((values + [status]).joined(separator: ","))
                        globalCSV.append(
                            ([csvField(archiveName)] + values + [status])
                                .joined(separator: ",")
                        )
                        failedCount += 1
                    }
                }
                try flushContactSheet()
            }
            try Data((archiveCSV.joined(separator: "\n") + "\n").utf8).write(
                to: archiveDirectory.appendingPathComponent("INDEX.csv"),
                options: .atomic
            )
            print("\(archiveName): exported \(archiveExported)")
        }

        let readme = """
        # Emperor DATA image export

        每个一级目录对应一个 SG3/555 资源包；二级目录按 SG3 中的原始 bitmap
        名称分类。单张图片文件名以六位原始图号开头，例如 `000201_78x102.png`。

        每个分类目录包含若干 `CONTACT_SHEET_*.png`，缩略图下方的 `#数字`
        就是原始图号。选图时可以直接提供“资源包名称 + 图号”。

        根目录 `SPRITE_CATALOG.png` 是完整分类总览：每个分类显示分类名称、
        第一张图片及其图号；`SPRITE_CATALOG.csv` 提供同一份可检索索引。

        根目录 `INDEX.csv` 汇总全部资源；每个资源包目录也有自己的 `INDEX.csv`。
        未配对 `.555` 的 SG3：\(skippedArchives.isEmpty ? "无" : skippedArchives.joined(separator: "；"))

        导出成功：\(exportedCount)
        解码失败：\(failedCount)
        """
        try Data((readme + "\n").utf8).write(
            to: outputDirectory.appendingPathComponent("README.md"),
            options: .atomic
        )
        try Data((globalCSV.joined(separator: "\n") + "\n").utf8).write(
            to: outputDirectory.appendingPathComponent("INDEX.csv"),
            options: .atomic
        )
        let catalogPreviewCount = try writeCompleteSpriteCatalog(
            to: outputDirectory
        )
        print(
            "exported \(exportedCount) images from \(archives.count - skippedArchives.count) archives"
                + " to \(outputDirectory.path); failed=\(failedCount), skippedArchives=\(skippedArchives.count), "
                + "catalogPreviews=\(catalogPreviewCount)"
        )

    case "sprite-png":
        guard arguments.count >= 4 else {
            throw GameDataError.unsupported("usage: emperor-inspect sprite-png <sg3-file> <image-id> <output-png>")
        }
        let archiveURL = URL(fileURLWithPath: arguments[1])
        guard let imageID = Int(arguments[2]) else {
            throw GameDataError.unsupported("image-id must be an integer")
        }
        let archive = try SG3Archive(contentsOf: archiveURL)
        guard archive.images.indices.contains(imageID) else {
            throw GameDataError.unsupported("image-id is outside the archive")
        }
        let pixelsURL = archiveURL.deletingPathExtension().appendingPathExtension("555")
        let decoded = try SpriteDecoder.decode(
            image: archive.images[imageID],
            pixelData: Data(contentsOf: pixelsURL, options: [.mappedIfSafe])
        )
        guard let image = decoded.makeCGImage(),
              let destination = CGImageDestinationCreateWithURL(
                URL(fileURLWithPath: arguments[3]) as CFURL,
                "public.png" as CFString,
                1,
                nil
              ) else {
            throw GameDataError.unsupported("could not create PNG destination")
        }
        CGImageDestinationAddImage(destination, image, nil)
        guard CGImageDestinationFinalize(destination) else {
            throw GameDataError.unsupported("could not write PNG")
        }
        print("wrote \(arguments[3]) (\(decoded.width)x\(decoded.height))")

    case "sg3-image":
        guard arguments.count >= 3,
              let imageID = Int(arguments[2]) else {
            throw GameDataError.unsupported("usage: emperor-inspect sg3-image <sg3-file> <image-id>")
        }
        let archive = try SG3Archive(contentsOf: URL(fileURLWithPath: arguments[1]))
        guard archive.images.indices.contains(imageID) else {
            throw GameDataError.unsupported("image-id is outside the archive")
        }
        let image = archive.images[imageID]
        print("#\(image.id) \(image.width)x\(image.height) group=\(image.groupID):\(image.groupIndex) sprites=\(image.spriteCount) offset=(\(image.spriteOffsetX),\(image.spriteOffsetY)) type=\(image.type) bitmap=\(image.bitmapGroupID) external=\(image.isExternal)")

    case "sg3-template-match":
        guard arguments.count >= 3,
              let templateID = Int(arguments[2]) else {
            throw GameDataError.unsupported(
                "usage: emperor-inspect sg3-template-match <sg3-file> <template-id>"
            )
        }
        let archiveURL = URL(fileURLWithPath: arguments[1])
        let archive = try SG3Archive(contentsOf: archiveURL)
        let pixels = try Data(
            contentsOf: archiveURL.deletingPathExtension().appendingPathExtension("555"),
            options: [.mappedIfSafe]
        )
        guard archive.images.indices.contains(templateID) else {
            throw GameDataError.unsupported("template-id is outside the archive")
        }
        let template = try SpriteDecoder.decode(
            image: archive.images[templateID],
            pixelData: pixels
        )
        let templateBytes = [UInt8](template.rgba)
        func alpha(_ bytes: [UInt8], width: Int, height: Int, x: Int, bottomY: Int) -> Bool {
            let y = height - 1 - bottomY
            guard x >= 0, x < width, y >= 0, y < height else { return false }
            return bytes[(y * width + x) * 4 + 3] != 0
        }
        var matches: [(id: Int, score: Double, intersection: Int, union: Int)] = []
        for record in archive.images
            where record.id != templateID
                && record.width == template.width
                && record.width > 0
                && record.height > 0
                && !record.isExternal {
            guard let candidate = try? SpriteDecoder.decode(
                image: record,
                pixelData: pixels
            ) else { continue }
            let candidateBytes = [UInt8](candidate.rgba)
            var intersection = 0
            var union = 0
            let height = max(template.height, candidate.height)
            for bottomY in 0..<height {
                for x in 0..<template.width {
                    let inTemplate = alpha(
                        templateBytes,
                        width: template.width,
                        height: template.height,
                        x: x,
                        bottomY: bottomY
                    )
                    let inCandidate = alpha(
                        candidateBytes,
                        width: candidate.width,
                        height: candidate.height,
                        x: x,
                        bottomY: bottomY
                    )
                    if inTemplate && inCandidate { intersection += 1 }
                    if inTemplate || inCandidate { union += 1 }
                }
            }
            guard union > 0 else { continue }
            matches.append((
                record.id,
                Double(intersection) / Double(union),
                intersection,
                union
            ))
        }
        for match in matches.sorted(by: { $0.score > $1.score }).prefix(20) {
            print(
                String(
                    format: "#%d score=%.4f intersection=%d union=%d",
                    match.id,
                    match.score,
                    match.intersection,
                    match.union
                )
            )
        }

    case "terrain-sprites":
        guard arguments.count >= 2 else {
            throw GameDataError.unsupported("usage: emperor-inspect terrain-sprites <sg3-file>")
        }
        let url = URL(fileURLWithPath: arguments[1])
        let archive = try SG3Archive(contentsOf: url)
        let pixelsURL = url.deletingPathExtension().appendingPathExtension("555")
        let pixels = try Data(contentsOf: pixelsURL, options: [.mappedIfSafe])
        let candidates = archive.images.filter { $0.type == 30 && $0.width == 78 && $0.height == 40 }
        print("\(url.lastPathComponent): \(candidates.count) single-tile isometric sprites")
        for image in candidates {
            let sprite = try SpriteDecoder.decode(image: image, pixelData: pixels)
            let bytes = [UInt8](sprite.rgba)
            var red = 0
            var green = 0
            var blue = 0
            var opaque = 0
            for offset in stride(from: 0, to: bytes.count, by: 4) where bytes[offset + 3] != 0 {
                red += Int(bytes[offset])
                green += Int(bytes[offset + 1])
                blue += Int(bytes[offset + 2])
                opaque += 1
            }
            guard opaque > 0 else { continue }
            print("  #\(image.id) avg=\(red / opaque),\(green / opaque),\(blue / opaque) opaque=\(opaque)")
        }

    case "sg3-groups":
        guard arguments.count >= 2 else { throw GameDataError.unsupported("usage: emperor-inspect sg3-groups <file>") }
        let url = URL(fileURLWithPath: arguments[1])
        let archive = try SG3Archive(contentsOf: url)
        let groups = Dictionary(grouping: archive.images.filter { $0.width > 0 && $0.height > 0 }, by: \.groupID)
        for groupID in groups.keys.sorted() {
            guard let images = groups[groupID]?.sorted(by: { $0.groupIndex < $1.groupIndex }),
                  let first = images.first else { continue }
            let bitmap = semanticBitmapName(archive, imageID: first.id)
            print("group=\(groupID) images=\(images.count) first=#\(first.id) \(first.width)x\(first.height) type=\(first.type) sprites=\(first.spriteCount) bitmap=\(bitmap)")
        }

    case "sg3-logical-groups":
        guard arguments.count >= 2 else {
            throw GameDataError.unsupported("usage: emperor-inspect sg3-logical-groups <file>")
        }
        let archive = try SG3Archive(contentsOf: URL(fileURLWithPath: arguments[1]))
        for (groupID, rawImageID) in archive.groupImageIDs.enumerated() where rawImageID != 0 {
            let imageID = Int(rawImageID)
            guard archive.images.indices.contains(imageID) else { continue }
            let image = archive.images[imageID]
            let bitmap = semanticBitmapName(archive, imageID: imageID)
            print("logical=\(groupID) first=#\(imageID) \(image.width)x\(image.height) type=\(image.type) sprites=\(image.spriteCount) bitmap=\(bitmap)")
        }

    case "sg3-figure":
        guard arguments.count >= 3 else {
            throw GameDataError.unsupported("usage: emperor-inspect sg3-figure <file> <bitmap-name>")
        }
        let archive = try SG3Archive(contentsOf: URL(fileURLWithPath: arguments[1]))
        let requestedName = arguments[2].lowercased()
        if let animation = OriginalFigureSpriteCatalog.animations.first(where: {
            $0.sourceBitmapName.lowercased() == requestedName
        }) {
            let first = animation.framesByDirection[0][0]
            let last = animation.framesByDirection[7].last ?? first
            print("bitmap=\(animation.sourceBitmapName) role=\(animation.role.rawValue) figure=\(animation.figureID) images=#\(first)...#\(last) logical=\(animation.logicalGroupID) directions=8 frames=\(animation.framesByDirection[0].count)")
            for direction in FigureMovementDirection.allCases {
                let ids = animation.framesByDirection[direction.rawValue]
                guard let imageID = ids.first, archive.images.indices.contains(imageID) else { continue }
                let image = archive.images[imageID]
                print("  direction=\(direction.rawValue) first=#\(imageID) frames=\(ids.count) size=\(image.width)x\(image.height) offset=\(image.spriteOffsetX),\(image.spriteOffsetY) type=\(image.type)")
            }
            break
        }
        guard let mapping = archive.inferredBitmapLogicalGroupMappings().first(where: {
            $0.bitmapName.lowercased() == requestedName
        }) else {
            throw GameDataError.unsupported("bitmap '\(arguments[2])' was not found")
        }
        let bitmap = archive.bitmaps[mapping.bitmapID]
        print("bitmap=\(bitmap.name) images=#\(mapping.imageIDs.lowerBound)...#\(mapping.imageIDs.upperBound - 1) logical=\(mapping.logicalGroups.lowerBound)..<\(mapping.logicalGroups.upperBound) source=\(bitmap.width)x\(bitmap.height)")
        for (logicalGroup, rawStart) in archive.groupImageIDs.enumerated() where rawStart != 0 {
            let imageID = Int(rawStart)
            guard mapping.logicalGroups.contains(logicalGroup),
                  archive.images.indices.contains(imageID) else {
                continue
            }
            let image = archive.images[imageID]
            let nextStart = archive.groupImageIDs.dropFirst(logicalGroup + 1).first(where: { $0 != 0 })
                .map(Int.init) ?? mapping.imageIDs.upperBound
            print("  logical=\(logicalGroup) first=#\(imageID) directions=\(image.spriteCount > 0 ? min(8, max(1, nextStart - imageID) / image.spriteCount) : 0) frames=\(image.spriteCount) size=\(image.width)x\(image.height) offset=\(image.spriteOffsetX),\(image.spriteOffsetY) type=\(image.type)")
        }

    case "sg3-bitmap-map":
        guard arguments.count >= 2 else {
            throw GameDataError.unsupported("usage: emperor-inspect sg3-bitmap-map <file>")
        }
        let archive = try SG3Archive(contentsOf: URL(fileURLWithPath: arguments[1]))
        let mappings = archive.inferredBitmapLogicalGroupMappings()
        guard mappings.count == archive.header.bitmapNamesUsed else {
            throw GameDataError.malformedFile(
                "could not infer all bitmap ranges (mapped \(mappings.count)/\(archive.header.bitmapNamesUsed))"
            )
        }
        for mapping in mappings {
            print("bitmap=\(mapping.bitmapID) name=\(mapping.bitmapName) logical=\(mapping.logicalGroups.lowerBound)..<\(mapping.logicalGroups.upperBound) images=#\(mapping.imageIDs.lowerBound)..<#\(mapping.imageIDs.upperBound)")
        }

    case "sg3-bitmap-candidates":
        guard arguments.count >= 2 else {
            throw GameDataError.unsupported("usage: emperor-inspect sg3-bitmap-candidates <file>")
        }
        let archive = try SG3Archive(contentsOf: URL(fileURLWithPath: arguments[1]))
        let groups = archive.groupImageIDs.enumerated().compactMap {
            $0.element == 0 ? nil : ($0.offset, Int($0.element))
        }
        for bitmap in archive.bitmaps.prefix(archive.header.bitmapNamesUsed) {
            var candidates: [String] = []
            for startIndex in groups.indices {
                var maximumWidth = 0
                var maximumHeight = 0
                for endIndex in (startIndex + 1)...min(groups.count, startIndex + 12) {
                    let first = groups[endIndex - 1].1
                    let last = endIndex < groups.count ? groups[endIndex].1 : archive.images.count
                    for imageID in first..<last {
                        maximumWidth = max(maximumWidth, archive.images[imageID].width)
                        maximumHeight = max(maximumHeight, archive.images[imageID].height)
                    }
                    if maximumWidth == bitmap.width, maximumHeight == bitmap.height {
                        candidates.append("\(groups[startIndex].0)..<\(endIndex < groups.count ? groups[endIndex].0 : SG3Archive.groupCount)")
                    }
                }
            }
            print("bitmap=\(bitmap.id) name=\(bitmap.name) size=\(bitmap.width)x\(bitmap.height) candidates=\(candidates.prefix(12).joined(separator: ","))")
        }

    case "sg3-range":
        guard arguments.count >= 4 else { throw GameDataError.unsupported("usage: emperor-inspect sg3-range <file> <first> <last>") }
        let archive = try SG3Archive(contentsOf: URL(fileURLWithPath: arguments[1]))
        let firstID = Int(arguments[2]) ?? 0
        let lastID = Int(arguments[3]) ?? firstID
        for id in max(0, firstID)...min(lastID, archive.images.count - 1) {
            let image = archive.images[id]
            let bitmap = semanticBitmapName(archive, imageID: id)
            let animation = logicalAnimationPosition(archive, imageID: id)
            let logical = animation.map { " logical=\($0.logicalGroup) direction=\($0.direction) frame=\($0.frame)" } ?? ""
            print("#\(id) \(image.width)x\(image.height) group=\(image.groupID):\(image.groupIndex) type=\(image.type) sprites=\(image.spriteCount) offset=\(image.spriteOffsetX),\(image.spriteOffsetY) bitmap=\(bitmap)\(logical)")
        }

    default:
        throw GameDataError.unsupported("unknown command \(command)")
    }
} catch {
    FileHandle.standardError.write(Data("error: \(error.localizedDescription)\n".utf8))
    exit(1)
}
