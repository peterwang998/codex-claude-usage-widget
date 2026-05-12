import Foundation

struct WidgetMetric: Codable, Hashable {
    var label: String
    var value: String
    var detail: String?
    var percent: Double?
}

struct WidgetServiceData: Codable, Hashable {
    var id: String
    var name: String
    var status: String
    var message: String?
    var lastUpdated: Date?
    var nextRefresh: Date?
    var metrics: [WidgetMetric]
}

struct WidgetUsageData: Codable, Hashable {
    var generatedAt: Date
    var claude: WidgetServiceData
    var codex: WidgetServiceData

    static let placeholder = WidgetUsageData(
        generatedAt: Date(),
        claude: WidgetServiceData(
            id: "claude",
            name: "Claude",
            status: "Waiting",
            message: "Open the menu-bar app to poll usage.",
            lastUpdated: nil,
            nextRefresh: nil,
            metrics: []
        ),
        codex: WidgetServiceData(
            id: "codex",
            name: "Codex",
            status: "Waiting",
            message: "Open the menu-bar app to poll usage.",
            lastUpdated: nil,
            nextRefresh: nil,
            metrics: []
        )
    )
}

enum WidgetUsageSnapshotStore {
    static var appGroupIdentifier: String {
        Bundle.main.object(forInfoDictionaryKey: "AIUsageWidgetAppGroupIdentifier") as? String
            ?? "group.local.peter.ai-usage-widget"
    }

    private static let fileName = "usage-widget-snapshot.json"

    static var snapshotURL: URL? {
        if let groupURL = FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: appGroupIdentifier) {
            return groupURL.appendingPathComponent(fileName)
        }

        return try? FileManager.default
            .url(
                for: .applicationSupportDirectory,
                in: .userDomainMask,
                appropriateFor: nil,
                create: true
            )
            .appendingPathComponent("AIUsageWidget", isDirectory: true)
            .appendingPathComponent(fileName)
    }

    static func read() -> WidgetUsageData? {
        guard let snapshotURL,
              let data = try? Data(contentsOf: snapshotURL)
        else {
            return nil
        }

        return try? JSONDecoder().decode(WidgetUsageData.self, from: data)
    }

    static func write(_ snapshot: WidgetUsageData) {
        guard let snapshotURL else {
            return
        }

        do {
            try FileManager.default.createDirectory(
                at: snapshotURL.deletingLastPathComponent(),
                withIntermediateDirectories: true
            )
            let encoder = JSONEncoder()
            encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
            try encoder.encode(snapshot).write(to: snapshotURL, options: .atomic)
        } catch {
            NSLog("AI Usage Widget failed to write widget snapshot: \(error.localizedDescription)")
        }
    }
}
