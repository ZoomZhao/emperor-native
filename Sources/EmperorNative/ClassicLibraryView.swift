import EmperorCore
import SwiftUI

struct ClassicLibraryView: View {
    @ObservedObject var library: LibraryModel
    let source: GameDataSource
    let catalog: GameDataCatalog
    let models: [ModelFileSummary]
    let economy: OriginalEconomyModels
    @State private var query = ""
    @State private var page = 0
    private let pageSize = 12

    var body: some View {
        VStack(spacing: 0) {
            ClassicLobbyHeader(library: library, activeSection: .maps)
            catalogSummary

            HStack(spacing: 0) {
                mapIndex
                    .frame(width: 282)

                Rectangle()
                    .fill(EmperorTheme.border)
                    .frame(width: 1)

                mapPreview

                Rectangle()
                    .fill(EmperorTheme.border)
                    .frame(width: 1)

                mapInspector
                    .frame(width: 292)
            }
            .padding(16)
            .padding(.top, 0)

            footer
        }
        .background(ClassicLobbyBackground())
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("classic-library")
    }

    private var catalogSummary: some View {
        HStack(spacing: 0) {
            summaryMetric(
                title: "地图",
                value: catalog.maps.count,
                symbol: "map.fill"
            )
            summaryMetric(
                title: "战役",
                value: catalog.campaigns.count,
                symbol: "flag.fill"
            )
            summaryMetric(
                title: "图像档案",
                value: catalog.spriteDescriptions.count + catalog.spritePixels.count,
                symbol: "photo.stack.fill"
            )
            summaryMetric(
                title: "规则模型",
                value: models.count,
                symbol: "slider.horizontal.3"
            )
            summaryMetric(
                title: "声音",
                value: catalog.waveAudio.count + catalog.music.count,
                symbol: "waveform"
            )
        }
        .frame(height: 54)
        .background(EmperorTheme.surfaceRaised.opacity(0.76))
        .overlay(alignment: .bottom) {
            Rectangle().fill(EmperorTheme.border).frame(height: 1)
        }
    }

    private func summaryMetric(title: String, value: Int, symbol: String) -> some View {
        HStack(spacing: 8) {
            Image(systemName: symbol)
                .foregroundStyle(EmperorTheme.primary)
            VStack(alignment: .leading, spacing: 1) {
                Text(title)
                    .font(EmperorTheme.caption)
                    .foregroundStyle(EmperorTheme.onSurfaceMuted)
                Text(value.formatted())
                    .font(EmperorTheme.metric)
                    .foregroundStyle(EmperorTheme.onSurface)
            }
            Spacer(minLength: 0)
        }
        .padding(.horizontal, 14)
        .frame(maxWidth: .infinity)
        .overlay(alignment: .trailing) {
            Rectangle()
                .fill(EmperorTheme.border.opacity(0.72))
                .frame(width: 1, height: 30)
        }
    }

    private var mapIndex: some View {
        VStack(spacing: 0) {
            sectionHeading(
                eyebrow: "原版档案",
                title: "地图索引",
                symbol: "map.fill"
            )

            HStack(spacing: 7) {
                Image(systemName: "magnifyingglass")
                    .foregroundStyle(EmperorTheme.onSurfaceMuted)
                TextField("搜索地图名称", text: $query)
                    .textFieldStyle(.plain)
                    .font(EmperorTheme.bodyMedium)
                    .foregroundStyle(EmperorTheme.onSurface)
                    .accessibilityIdentifier("library-map-search")
                if !query.isEmpty {
                    Button {
                        query = ""
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                    }
                    .buttonStyle(.plain)
                    .foregroundStyle(EmperorTheme.onSurfaceMuted)
                    .help("清除搜索")
                }
            }
            .padding(.horizontal, 10)
            .frame(height: 36)
            .background(EmperorTheme.surfaceDeep)
            .overlay(Rectangle().strokeBorder(EmperorTheme.border))
            .padding(10)
            .onChange(of: query) { _ in
                page = 0
            }

            ScrollView {
                LazyVStack(spacing: 0) {
                    ForEach(pagedMaps) { entry in
                        mapRow(entry)
                    }
                }
            }

            HStack {
                Button {
                    page = max(0, page - 1)
                } label: {
                    Image(systemName: "chevron.left")
                }
                .buttonStyle(.plain)
                .disabled(page == 0)
                .help("上一页")

                Text("\(page + 1) / \(pageCount)")
                    .font(EmperorTheme.metric)

                Spacer()
                Text(visibleRangeLabel)
                Spacer()

                Button {
                    page = min(pageCount - 1, page + 1)
                } label: {
                    Image(systemName: "chevron.right")
                }
                .buttonStyle(.plain)
                .disabled(page + 1 >= pageCount)
                .help("下一页")
            }
            .font(EmperorTheme.caption)
            .foregroundStyle(EmperorTheme.onSurfaceMuted)
            .padding(.horizontal, 10)
            .frame(height: 30)
            .background(EmperorTheme.surfaceDeep)
            .overlay(alignment: .top) {
                Rectangle().fill(EmperorTheme.border).frame(height: 1)
            }
        }
        .background(EmperorTheme.surface.opacity(0.96))
        .overlay(Rectangle().strokeBorder(EmperorTheme.border))
    }

    private func mapRow(_ entry: GameDataCatalog.Entry) -> some View {
        let isSelected = library.selectedMapURL == entry.url
        return Button {
            library.selectMapEntry(entry)
        } label: {
            HStack(spacing: 9) {
                Image(systemName: isSelected ? "map.fill" : "map")
                    .foregroundStyle(
                        isSelected ? EmperorTheme.onPrimary : EmperorTheme.primary
                    )
                    .frame(width: 20)
                VStack(alignment: .leading, spacing: 2) {
                    Text(ClassicTextLocalization.mapName(entry.url))
                        .font(EmperorTheme.bodyMedium)
                        .foregroundStyle(
                            isSelected ? EmperorTheme.onPrimary : EmperorTheme.onSurface
                        )
                        .lineLimit(1)
                    Text(ByteCountFormatter.string(
                        fromByteCount: entry.byteCount,
                        countStyle: .file
                    ))
                    .font(EmperorTheme.caption)
                    .foregroundStyle(
                        isSelected
                            ? EmperorTheme.onPrimary.opacity(0.72)
                            : EmperorTheme.onSurfaceMuted
                    )
                }
                Spacer(minLength: 0)
                Image(systemName: "chevron.right")
                    .font(EmperorTheme.caption)
                    .foregroundStyle(
                        isSelected ? EmperorTheme.onPrimary : EmperorTheme.onSurfaceMuted
                    )
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 7)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                isSelected
                    ? EmperorTheme.primary
                    : EmperorTheme.surface.opacity(0.72)
            )
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(
            "\(ClassicTextLocalization.mapName(entry.url))，\(entry.byteCount) 字节"
        )
        .accessibilityIdentifier("library-map-\(stableSlug(entry.name))")
        .overlay(alignment: .bottom) {
            Rectangle()
                .fill(EmperorTheme.border.opacity(0.45))
                .frame(height: 1)
        }
    }

    private var mapPreview: some View {
        VStack(spacing: 0) {
            HStack(spacing: 10) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("地图预览")
                        .font(EmperorTheme.caption)
                        .foregroundStyle(EmperorTheme.onSurfaceMuted)
                    Text(selectedMapTitle)
                        .font(EmperorTheme.headlineMedium)
                        .foregroundStyle(EmperorTheme.onSurface)
                        .lineLimit(1)
                }
                Spacer()
                if let probe = library.selectedMap {
                    Label(
                        "\(probe.width ?? 0) × \(probe.height ?? 0)",
                        systemImage: "square.grid.3x3.fill"
                    )
                    .font(EmperorTheme.metric)
                    .foregroundStyle(EmperorTheme.primary)
                }
            }
            .padding(.horizontal, 12)
            .frame(height: 54)
            .background(EmperorTheme.surfaceRaised.opacity(0.78))
            .overlay(alignment: .bottom) {
                Rectangle().fill(EmperorTheme.border).frame(height: 1)
            }

            ZStack {
                MapDiagnosticView(
                    probe: library.selectedMap,
                    rendered: library.renderedMap
                )
                if library.selectedMapURL != library.selectedMap?.url {
                    loadingOverlay
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(EmperorTheme.surfaceDeep)
        .overlay(Rectangle().strokeBorder(EmperorTheme.border))
    }

    private var loadingOverlay: some View {
        VStack(spacing: 9) {
            ProgressView()
                .controlSize(.large)
                .tint(EmperorTheme.primary)
            Text("正在读取原版地图…")
                .font(EmperorTheme.headlineSmall)
                .foregroundStyle(EmperorTheme.onSurface)
        }
        .padding(18)
        .background(EmperorTheme.surfaceDeep.opacity(0.92))
        .overlay(Rectangle().strokeBorder(EmperorTheme.border))
    }

    private var mapInspector: some View {
        VStack(spacing: 0) {
            sectionHeading(
                eyebrow: "解析信息",
                title: "档案详情",
                symbol: "info.square.fill"
            )
            InspectorView(
                source: source,
                catalog: catalog,
                models: models,
                economy: economy,
                map: library.selectedMap,
                campaign: nil,
                embeddedCampaignMapCount: nil,
                campaignMissionMaps: nil,
                campaignGoals: nil,
                campaignEvents: nil,
                campaignEmpireMap: nil,
                city: nil,
                latestSettlement: nil
            )
            .background(EmperorTheme.surface.opacity(0.96))
        }
        .overlay(Rectangle().strokeBorder(EmperorTheme.border))
    }

    private func sectionHeading(
        eyebrow: String,
        title: String,
        symbol: String
    ) -> some View {
        HStack(spacing: 9) {
            Image(systemName: symbol)
                .font(.system(size: 17, weight: .bold))
                .foregroundStyle(EmperorTheme.primary)
                .frame(width: 32, height: 32)
                .background(EmperorTheme.surfaceDeep)
                .overlay(Rectangle().strokeBorder(EmperorTheme.border))
            VStack(alignment: .leading, spacing: 1) {
                Text(eyebrow)
                    .font(EmperorTheme.caption)
                    .foregroundStyle(EmperorTheme.onSurfaceMuted)
                Text(title)
                    .font(EmperorTheme.headlineMedium)
                    .foregroundStyle(EmperorTheme.onSurface)
            }
        }
        .padding(.horizontal, 10)
        .frame(maxWidth: .infinity, minHeight: 54, alignment: .leading)
        .background(EmperorTheme.surfaceRaised.opacity(0.78))
        .overlay(alignment: .bottom) {
            Rectangle().fill(EmperorTheme.border).frame(height: 1)
        }
    }

    private var footer: some View {
        HStack(spacing: 10) {
            Label("运行时读取用户安装的原版资料", systemImage: "externaldrive.fill")
            Spacer()
            Text(source.root.path)
                .lineLimit(1)
                .truncationMode(.middle)
                .help(source.root.path)
            Spacer()
            Text(library.saveStatus ?? "选择地图以查看真实地形和解析信息")
                .lineLimit(1)
        }
        .font(EmperorTheme.caption)
        .foregroundStyle(EmperorTheme.onSurfaceMuted)
        .padding(.horizontal, 16)
        .frame(height: 30)
        .background(EmperorTheme.surfaceDeep)
        .overlay(alignment: .top) {
            Rectangle().fill(EmperorTheme.border).frame(height: 1)
        }
    }

    private var filteredMaps: [GameDataCatalog.Entry] {
        let normalized = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !normalized.isEmpty else { return catalog.maps }
        return catalog.maps.filter {
            $0.name.localizedCaseInsensitiveContains(normalized)
                || ClassicTextLocalization.mapName($0.url)
                    .localizedCaseInsensitiveContains(normalized)
        }
    }

    private var pageCount: Int {
        max(1, (filteredMaps.count + pageSize - 1) / pageSize)
    }

    private var pagedMaps: [GameDataCatalog.Entry] {
        let safePage = min(max(0, page), pageCount - 1)
        let lower = safePage * pageSize
        let upper = min(filteredMaps.count, lower + pageSize)
        guard lower < upper else { return [] }
        return Array(filteredMaps[lower..<upper])
    }

    private var visibleRangeLabel: String {
        guard !filteredMaps.isEmpty else { return "没有匹配地图" }
        let lower = page * pageSize + 1
        let upper = min(filteredMaps.count, lower + pageSize - 1)
        return "\(lower)–\(upper) / \(filteredMaps.count)"
    }

    private var selectedMapTitle: String {
        guard let url = library.selectedMapURL ?? library.selectedMap?.url else {
            return "尚未选择地图"
        }
        return ClassicTextLocalization.mapName(url)
    }

    private func stableSlug(_ value: String) -> String {
        let scalars = value.lowercased().unicodeScalars.map {
            CharacterSet.alphanumerics.contains($0) ? Character(String($0)) : "-"
        }
        return String(scalars)
            .replacingOccurrences(of: "--", with: "-")
            .trimmingCharacters(in: CharacterSet(charactersIn: "-"))
    }
}
