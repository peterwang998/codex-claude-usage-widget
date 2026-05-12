import SwiftUI
import WidgetKit

struct AIUsageEntry: TimelineEntry {
    let date: Date
    let usage: WidgetUsageData
}

struct AIUsageTimelineProvider: TimelineProvider {
    func placeholder(in context: Context) -> AIUsageEntry {
        AIUsageEntry(date: Date(), usage: .placeholder)
    }

    func getSnapshot(in context: Context, completion: @escaping (AIUsageEntry) -> Void) {
        completion(AIUsageEntry(date: Date(), usage: WidgetUsageSnapshotStore.read() ?? .placeholder))
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<AIUsageEntry>) -> Void) {
        let now = Date()
        let usage = WidgetUsageSnapshotStore.read() ?? .placeholder
        let entry = AIUsageEntry(date: now, usage: usage)
        completion(Timeline(entries: [entry], policy: .after(now.addingTimeInterval(10 * 60))))
    }
}

struct AIUsageWidget: Widget {
    let kind = "AIUsageWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: AIUsageTimelineProvider()) { entry in
            AIUsageWidgetView(entry: entry)
        }
        .configurationDisplayName("AI Usage")
        .description("Shows cached Claude and Codex usage limits from the menu-bar app.")
        .supportedFamilies([.systemSmall, .systemMedium, .systemLarge])
    }
}

@main
struct AIUsageWidgetBundle: WidgetBundle {
    var body: some Widget {
        AIUsageWidget()
    }
}

struct AIUsageWidgetView: View {
    @Environment(\.widgetFamily) private var family
    let entry: AIUsageEntry

    var body: some View {
        VStack(alignment: .leading, spacing: family == .systemSmall ? 8 : 12) {
            header

            switch family {
            case .systemSmall:
                CompactServiceView(service: entry.usage.claude)
                CompactServiceView(service: entry.usage.codex)
            default:
                ServiceWidgetSection(service: entry.usage.claude)
                ServiceWidgetSection(service: entry.usage.codex)
            }

            Spacer(minLength: 0)
        }
        .containerBackground(.fill.tertiary, for: .widget)
    }

    private var header: some View {
        HStack(spacing: 6) {
            Image(systemName: "gauge.with.dots.needle.bottom.50percent")
                .font(.caption.weight(.semibold))
            Text("AI Usage")
                .font(.caption.weight(.semibold))
            Spacer()
            Text(updatedText)
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
    }

    private var updatedText: String {
        let date = [entry.usage.claude.lastUpdated, entry.usage.codex.lastUpdated]
            .compactMap { $0 }
            .max() ?? entry.usage.generatedAt
        return date.formatted(date: .omitted, time: .shortened)
    }
}

struct CompactServiceView: View {
    let service: WidgetServiceData

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(service.name)
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(accent)
                Spacer()
                Text(primaryMetric?.value ?? service.status)
                    .font(.caption2.weight(.semibold))
                    .lineLimit(1)
                    .minimumScaleFactor(0.75)
            }

            if let metric = primaryMetric, let percent = metric.percent {
                ProgressView(value: percent, total: 100)
                    .tint(accent)
            }

            Text(primaryMetric?.label ?? service.message ?? "Waiting for app")
                .font(.caption2)
                .foregroundStyle(.secondary)
                .lineLimit(1)
        }
    }

    private var primaryMetric: WidgetMetric? {
        service.primaryMetrics.first ?? service.metrics.first
    }

    private var accent: Color {
        service.id == "codex" ? Color(red: 0.10, green: 0.48, blue: 0.67) : Color(red: 0.78, green: 0.42, blue: 0.24)
    }
}

struct ServiceWidgetSection: View {
    let service: WidgetServiceData

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text(service.name)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(accent)
                Spacer()
                Text(service.status)
                    .font(.caption2.weight(.medium))
                    .foregroundStyle(.secondary)
            }

            let metrics = service.primaryMetrics.isEmpty ? Array(service.metrics.prefix(2)) : service.primaryMetrics
            if metrics.isEmpty {
                Text(service.message ?? "Waiting for the menu-bar app to poll usage.")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
            } else {
                ForEach(metrics.prefix(2), id: \.self) { metric in
                    WidgetMetricRow(metric: metric, accent: accent)
                }
            }
        }
    }

    private var accent: Color {
        service.id == "codex" ? Color(red: 0.10, green: 0.48, blue: 0.67) : Color(red: 0.78, green: 0.42, blue: 0.24)
    }
}

struct WidgetMetricRow: View {
    let metric: WidgetMetric
    let accent: Color

    var body: some View {
        VStack(alignment: .leading, spacing: 3) {
            HStack(alignment: .firstTextBaseline) {
                Text(metric.label)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                Spacer()
                Text(metric.value)
                    .font(.caption2.weight(.semibold))
                    .lineLimit(1)
                    .minimumScaleFactor(0.75)
            }

            if let percent = metric.percent {
                ProgressView(value: percent, total: 100)
                    .tint(accent)
            }
        }
    }
}

private extension WidgetServiceData {
    var primaryMetrics: [WidgetMetric] {
        metrics.filter { metric in
            let label = metric.label.lowercased()
            if id == "claude" {
                return label == "claude current session" || label == "claude weekly usage limit"
            }
            if id == "codex" {
                guard !label.contains("gpt-") else {
                    return false
                }
                return label.contains("5-hour") || label.contains("5 hour") || label.contains("weekly")
            }
            return false
        }
    }
}
