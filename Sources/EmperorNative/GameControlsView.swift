import EmperorCore
import AppKit
import AVFoundation
import Combine
import SwiftUI
import UniformTypeIdentifiers

/// Resource deposit overlays toggled from `GameControlsView` and painted by
/// `CityCanvas`. Each kind maps to the original terrain feature that the
/// matching extraction building harvests, so the highlight shows where that
/// resource can be gathered on the map.
enum ResourceOverlayKind: String, CaseIterable, Identifiable {
    case food = "食物"
    case wood = "木材"
    case stone = "石材"
    case clay = "粘土"
    case water = "供水"
    case inspection = "巡察"
    case medical = "医疗"
    case entertainment = "娱乐"
    case religion = "宗教"
    case tax = "税务"
    case housingSupply = "住房供给"
    case walkers = "城市行人"

    var id: Self { self }

    static let terrainCases: [Self] = [.food, .wood, .stone, .clay]
    static let serviceCases: [Self] = [
        .water, .inspection, .medical, .entertainment, .religion, .tax,
        .housingSupply,
    ]
    static let peopleCases: [Self] = [.walkers]

    var symbol: String {
        switch self {
        case .food: "fish.fill"
        case .wood: "tree.fill"
        case .stone: "mountain.2.fill"
        case .clay: "drop.circle.fill"
        case .water: "drop.fill"
        case .inspection: "wrench.and.screwdriver.fill"
        case .medical: "cross.case.fill"
        case .entertainment: "music.note"
        case .religion: "sparkles"
        case .tax: "banknote.fill"
        case .housingSupply: "house.and.flag.fill"
        case .walkers: "figure.walk"
        }
    }

    /// Semi-transparent highlight colour painted over matching deposit tiles.
    var color: Color {
        switch self {
        case .food: .cyan
        case .wood: .green
        case .stone: .gray
        case .clay: .orange
        case .water: .cyan
        case .inspection: .yellow
        case .medical: .mint
        case .entertainment: .pink
        case .religion: .purple
        case .tax: .green
        case .housingSupply: .cyan
        case .walkers: .yellow
        }
    }

    /// The terrain feature that marks a tile as holding this resource deposit:
    /// 食物 → water (渔港 fishing grounds), 木材 → tree (伐木场),
    /// 石材 → rock (采石场), 粘土 → scrub earth (粘土坑).
    func matches(_ flags: TerrainFlags) -> Bool {
        switch self {
        case .food: flags.contains(.water)
        case .wood: flags.contains(.tree)
        case .stone: flags.contains(.rock)
        case .clay: flags.contains(.scrub)
        case .water, .inspection, .medical, .entertainment, .religion, .tax,
             .housingSupply, .walkers:
            false
        }
    }

    func covers(_ house: ResidentialUnit, models: BuildingModelTable) -> Bool {
        switch self {
        case .water:
            house.serviceCoverage.contains(.water)
        case .inspection:
            house.serviceCoverage.contains(.inspection)
        case .medical:
            house.serviceCoverage.contains(.herbalist)
                || house.serviceCoverage.contains(.acupuncture)
        case .entertainment:
            house.serviceCoverage.contains(.music)
                || house.serviceCoverage.contains(.acrobat)
                || house.serviceCoverage.contains(.drama)
        case .religion:
            house.serviceCoverage.contains(.ancestor)
                || house.serviceCoverage.contains(.confucian)
                || house.serviceCoverage.contains(.daoistOrBuddhist)
        case .tax:
            house.hasTaxCoverage
        case .housingSupply:
            house.residents < house.capacity(using: models)
        case .food, .wood, .stone, .clay, .walkers:
            false
        }
    }
}

struct GameControlsView: View {
    @ObservedObject var library: LibraryModel
    let city: DeterministicCityState
    let models: OriginalEconomyModels

    var body: some View {
        VStack(spacing: 10) {
        LazyVGrid(
            columns: [GridItem(.adaptive(minimum: 128, maximum: 190), spacing: 12)],
            alignment: .leading,
            spacing: 10
        ) {
            Button {
                library.selectConstructionTool(.house)
            } label: {
                Label("选择住宅工具 · 15", systemImage: "hammer.fill")
                    .frame(maxWidth: .infinity)
            }
            .disabled(
                city.economy.treasury < (EconomyRulesEngine(models: models).constructionCost(buildingID: 2, difficulty: city.difficulty) ?? .max)
            )

            Picker("税率", selection: Binding(
                get: { library.cityState?.taxBandID ?? 2 },
                set: { library.setTaxBand($0) }
            )) {
                ForEach(models.taxSentiment.bands) { band in
                    Text("税率 \(band.taxRatePercent)%").tag(band.id)
                }
            }
            .labelsHidden()
            .frame(maxWidth: .infinity)

            Button {
                library.toggleOriginalMusic()
            } label: {
                Label(
                    library.musicIsPlaying ? "暂停音乐" : "原版音乐",
                    systemImage: library.musicIsPlaying ? "pause.fill" : "music.note"
                )
                .frame(maxWidth: .infinity)
            }

            Button {
                library.loadCity()
            } label: {
                Label("载入", systemImage: "folder")
                    .frame(maxWidth: .infinity)
            }
            .keyboardShortcut("o", modifiers: .command)

            Button {
                library.saveCity()
            } label: {
                Label("保存", systemImage: "square.and.arrow.down")
                    .frame(maxWidth: .infinity)
            }
            .keyboardShortcut("s", modifiers: .command)

            HStack(spacing: 6) {
                ForEach(Array(0...3), id: \.self) { speed in
                    Button {
                        library.setGameSpeed(speed)
                    } label: {
                        Text(speed == 0 ? "⏸" : "\(speed)x")
                            .font(EmperorTheme.labelMedium)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 5)
                            .foregroundStyle(
                                library.gameSpeed == speed ? Color.white : Color.primary
                            )
                            .background(
                                library.gameSpeed == speed
                                    ? Color.accentColor
                                    : Color.primary.opacity(0.08),
                                in: Capsule()
                            )
                    }
                    .buttonStyle(.plain)
                    .accessibilityIdentifier("game-speed-\(speed)")
                }
            }
        }
        .buttonStyle(.bordered)

        resourceOverlayToggles

        if let saveStatus = library.saveStatus {
            HStack(spacing: 8) {
                Image(systemName: saveStatus.hasPrefix("已") ? "checkmark.circle.fill" : "exclamationmark.triangle.fill")
                Text(saveStatus)
                Spacer()
            }
            .font(EmperorTheme.bodySmall)
            .foregroundStyle(.secondary)
            .accessibilityIdentifier("player-command-status")
            .accessibilityValue(saveStatus)
        }
        }
    }

    /// Toggle buttons (食物/木材/石材/粘土) that ask `CityCanvas` to paint
    /// semi-transparent highlights over tiles holding the matching deposit.
    private var resourceOverlayToggles: some View {
        VStack(alignment: .leading, spacing: 6) {
            Label("资源矿藏图层", systemImage: "square.3.layers.3d.down.right")
                .font(EmperorTheme.bold(size: 12))
            HStack(spacing: 8) {
                ForEach(ResourceOverlayKind.terrainCases) { kind in
                    let isActive = library.activeResourceOverlays.contains(kind)
                    Button {
                        library.toggleResourceOverlay(kind)
                    } label: {
                        Label(kind.rawValue, systemImage: kind.symbol)
                            .font(EmperorTheme.labelMedium)
                            .padding(.horizontal, 10)
                            .padding(.vertical, 6)
                            .foregroundStyle(isActive ? Color.white : Color.primary)
                            .background(
                                isActive ? kind.color.opacity(0.85) : Color.primary.opacity(0.08),
                                in: Capsule()
                            )
                            .overlay(
                                Capsule().strokeBorder(kind.color.opacity(isActive ? 0 : 0.5), lineWidth: 1)
                            )
                    }
                    .buttonStyle(.plain)
                    .help("在地图上高亮\(kind.rawValue)矿藏格")
                }
                Menu {
                    ForEach(ResourceOverlayKind.serviceCases) { kind in
                        Button {
                            library.toggleResourceOverlay(kind)
                        } label: {
                            Label(
                                kind.rawValue,
                                systemImage: library.activeResourceOverlays.contains(kind)
                                    ? "checkmark.circle.fill"
                                    : kind.symbol
                            )
                        }
                    }
                } label: {
                    Label("服务覆盖", systemImage: "person.line.dotted.person.fill")
                        .font(EmperorTheme.labelMedium)
                }
                Spacer(minLength: 0)
            }
        }
        .padding(10)
        .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 10))
    }
}
