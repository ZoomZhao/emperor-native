import EmperorCore
import SwiftUI

struct ClassicMapMessageRow: Identifiable, Equatable {
    let id: String
    let title: String
    let body: String
    let detail: String?
}

struct ClassicMapMessagePanel: View {
    let messages: [ClassicMapMessageRow]
    let selectedIndex: Int
    let onSelectIndex: (Int) -> Void
    let onDismiss: () -> Void

    @ViewBuilder
    var body: some View {
        let safeIndex = min(max(0, selectedIndex), max(0, messages.count - 1))
        if messages.indices.contains(safeIndex) {
            let message = messages[safeIndex]
            VStack(spacing: 0) {
                Text(message.title)
                    .font(EmperorTheme.labelMedium)
                    .foregroundStyle(EmperorTheme.gold)
                    .frame(maxWidth: .infinity)
                    .frame(height: 23)
                    .background(EmperorTheme.tileBrown.opacity(0.92))
                    .overlay(alignment: .bottom) {
                        Rectangle().fill(EmperorTheme.border).frame(height: 1)
                    }

                HStack(alignment: .bottom, spacing: 10) {
                    VStack(alignment: .leading, spacing: 5) {
                        Text(message.body)
                            .font(EmperorTheme.bodySmall)
                            .foregroundStyle(EmperorTheme.onSurface)
                            .lineLimit(3)
                            .frame(maxWidth: .infinity, alignment: .leading)
                        if let detail = message.detail {
                            Text(detail)
                                .font(EmperorTheme.caption)
                                .foregroundStyle(EmperorTheme.onSurfaceMuted)
                                .lineLimit(1)
                        }
                    }

                    if messages.count > 1 {
                        HStack(spacing: 3) {
                            Button("◀") {
                                onSelectIndex(max(0, safeIndex - 1))
                            }
                            .disabled(safeIndex == 0)
                            .accessibilityLabel("上一条城市消息")

                            Text("\(safeIndex + 1)/\(messages.count)")
                                .font(EmperorTheme.caption)
                                .foregroundStyle(EmperorTheme.onSurfaceMuted)

                            Button("▶") {
                                onSelectIndex(min(messages.count - 1, safeIndex + 1))
                            }
                            .disabled(safeIndex == messages.count - 1)
                            .accessibilityLabel("下一条城市消息")
                        }
                        .buttonStyle(ClassicMessageGlyphButtonStyle())
                    }

                    Button("?") {}
                        .buttonStyle(ClassicMessageGlyphButtonStyle())
                        .help("城市消息帮助")
                        .accessibilityLabel("城市消息帮助")

                    Button("确定", action: onDismiss)
                        .buttonStyle(EmperorClassicButtonStyle(.primary))
                        .accessibilityIdentifier("city-message-panel-confirm")
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 9)
            }
            .frame(width: EmperorTheme.cityMapColumnWidth)
            .frame(height: EmperorTheme.mapMessagePanelHeight)
            .background(EmperorTheme.panelBrown.opacity(0.98))
            .overlay(Rectangle().strokeBorder(EmperorTheme.border, lineWidth: 2))
            .accessibilityElement(children: .contain)
            .accessibilityIdentifier("city-message-panel")
        }
    }
}

private struct ClassicMessageGlyphButtonStyle: ButtonStyle {
    @Environment(\.isEnabled) private var isEnabled

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(EmperorTheme.bold(size: 10))
            .foregroundStyle(isEnabled ? EmperorTheme.gold : EmperorTheme.onSurfaceMuted)
            .frame(width: 24, height: 22)
            .background(
                configuration.isPressed
                    ? EmperorTheme.tileBrown.opacity(0.6)
                    : EmperorTheme.deepBrown
            )
            .overlay(Rectangle().strokeBorder(EmperorTheme.border, lineWidth: 1))
            .opacity(isEnabled ? 1 : 0.45)
    }
}

struct ClassicMapLoadingView: View {
    var body: some View {
        VStack(spacing: 8) {
            ProgressView()
                .controlSize(.small)
                .tint(EmperorTheme.gold)
            Text("正在展开任务地图…")
                .font(EmperorTheme.bodySmall)
                .foregroundStyle(EmperorTheme.onSurface)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(EmperorTheme.deepBrown)
        .accessibilityElement(children: .combine)
        .accessibilityIdentifier("city-map-loading")
    }
}

struct ClassicMapStatusStrip: View {
    let text: String

    var body: some View {
        Text(text)
            .font(EmperorTheme.bodySmall)
            .foregroundStyle(EmperorTheme.onSurface)
            .lineLimit(1)
            .padding(.horizontal, 10)
            .frame(height: 24)
            .background(EmperorTheme.deepBrown.opacity(0.92))
            .overlay(Rectangle().strokeBorder(EmperorTheme.border, lineWidth: 1))
            .accessibilityIdentifier("player-command-status")
            .accessibilityValue(text)
    }
}
