import AppKit
import Combine
import Foundation
import SwiftUI
import WebKit
import WidgetKit

enum DashboardURLs {
    static let claudeUsage = URL(string: "https://claude.ai/settings/usage")!
    static let codexUsage = URL(string: "https://chatgpt.com/codex/cloud/settings/analytics")!
    static let codexPath = "/codex/cloud/settings/analytics"
}

enum AppLog {
    static let isDebugEnabled = ProcessInfo.processInfo.environment["AI_USAGE_WIDGET_DEBUG_LOGS"] == "1"

    static let url: URL = {
        let appGroupBase = FileManager.default
            .containerURL(forSecurityApplicationGroupIdentifier: WidgetUsageSnapshotStore.appGroupIdentifier)?
            .appendingPathComponent("Logs", isDirectory: true)
        let fallbackBase = try? FileManager.default
            .url(
                for: .applicationSupportDirectory,
                in: .userDomainMask,
                appropriateFor: nil,
                create: true
            )
            .appendingPathComponent("AIUsageWidget", isDirectory: true)
            .appendingPathComponent("Logs", isDirectory: true)
        let base = appGroupBase ?? fallbackBase ?? FileManager.default.temporaryDirectory
            .appendingPathComponent("AIUsageWidget", isDirectory: true)
        try? FileManager.default.createDirectory(at: base, withIntermediateDirectories: true)
        return base.appendingPathComponent("usage-widget.log")
    }()

    static func write(_ message: String) {
        let timestamp = ISO8601DateFormatter().string(from: Date())
        let line = "[\(timestamp)] \(message)\n"
        guard let data = line.data(using: .utf8) else {
            return
        }

        if !FileManager.default.fileExists(atPath: url.path) {
            FileManager.default.createFile(atPath: url.path, contents: nil)
        }

        do {
            let handle = try FileHandle(forWritingTo: url)
            try handle.seekToEnd()
            try handle.write(contentsOf: data)
            try handle.close()
        } catch {
            NSLog("AI Usage Widget log write failed: \(error.localizedDescription)")
        }
    }

    static func section(_ title: String, body: String) {
        write("---- \(title) ----\n\(body)\n---- end \(title) ----")
    }
}

enum DisplayMode: String {
    case minimal
    case detailed

    var label: String {
        switch self {
        case .minimal:
            return "Minimal"
        case .detailed:
            return "Detailed"
        }
    }

    var toggleLabel: String {
        switch self {
        case .minimal:
            return "Switch to detailed view"
        case .detailed:
            return "Switch to minimal view"
        }
    }
}

@main
struct UsageWidgetApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
    @StateObject private var monitor = UsageMonitor()
    @Environment(\.openWindow) private var openWindow

    var body: some Scene {
        MenuBarExtra {
            DashboardView(monitor: monitor, compact: true)
                .frame(width: 430)
                .padding(.horizontal, 10)
                .padding(.vertical, 10)
        } label: {
            Label(monitor.menuTitle, systemImage: monitor.menuSymbol)
        }
        .menuBarExtraStyle(.window)

        Window("AI Usage Widget", id: "widget") {
            DashboardView(monitor: monitor, compact: false)
                .frame(width: 460)
                .padding(18)
        }
        .windowResizability(.contentSize)
    }
}

final class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)
        AppLog.write("App launched. Log path: \(AppLog.url.path)")
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        false
    }
}

@MainActor
final class UsageMonitor: ObservableObject {
    @Published private(set) var claude: DashboardSnapshot
    @Published private(set) var codex: DashboardSnapshot
    @Published var displayMode: DisplayMode {
        didSet {
            UserDefaults.standard.set(displayMode.rawValue, forKey: "displayMode")
        }
    }

    private let claudePoller: DashboardPoller
    private let codexPoller: DashboardPoller

    var menuTitle: String {
        let degraded = [claude.status, codex.status].contains { $0 != .ready && $0 != .refreshing }
        if degraded {
            return "AI Usage"
        }

        let pieces = [claude.shortBadge, codex.shortBadge].compactMap { $0 }
        return pieces.isEmpty ? "AI Usage" : pieces.joined(separator: " / ")
    }

    var menuSymbol: String {
        if [claude.status, codex.status].contains(.loginRequired) {
            return "person.crop.circle.badge.exclamationmark"
        }
        if [claude.status, codex.status].contains(.error) {
            return "exclamationmark.triangle"
        }
        return "gauge.with.dots.needle.bottom.50percent"
    }

    init() {
        let initialClaude = DashboardSnapshot(service: .claude)
        let initialCodex = DashboardSnapshot(service: .codex)
        claude = initialClaude
        codex = initialCodex
        displayMode = DisplayMode(rawValue: UserDefaults.standard.string(forKey: "displayMode") ?? "") ?? .minimal

        claudePoller = DashboardPoller(service: .claude, url: DashboardURLs.claudeUsage)
        codexPoller = DashboardPoller(service: .codex, url: DashboardURLs.codexUsage)

        claudePoller.onSnapshot = { [weak self] snapshot in
            self?.claude = snapshot
            self?.publishWidgetSnapshot()
        }
        codexPoller.onSnapshot = { [weak self] snapshot in
            self?.codex = snapshot
            self?.publishWidgetSnapshot()
        }

        publishWidgetSnapshot()
        claudePoller.start()
        codexPoller.start(stagger: 20)
    }

    func refreshAll() {
        claudePoller.refresh(reason: .manual)
        codexPoller.refresh(reason: .manual)
    }

    func refresh(_ service: UsageService) {
        switch service {
        case .claude:
            claudePoller.refresh(reason: .manual)
        case .codex:
            codexPoller.refresh(reason: .manual)
        }
    }

    func openLoginWindow(for service: UsageService) {
        let url = service == .claude ? DashboardURLs.claudeUsage : DashboardURLs.codexUsage
        LoginWindowController.shared.open(service: service, url: url) { [weak self] in
            self?.refresh(service)
        }
    }

    func openExternalDashboard(for service: UsageService) {
        let url = service == .claude ? DashboardURLs.claudeUsage : DashboardURLs.codexUsage
        NSWorkspace.shared.open(url)
    }

    func openLogFile() {
        NSWorkspace.shared.open(AppLog.url)
    }

    func toggleDisplayMode() {
        displayMode = displayMode == .minimal ? .detailed : .minimal
    }

    func toggleDesktopWidget() {
        DesktopWidgetWindowController.shared.toggle(monitor: self)
    }

    private func publishWidgetSnapshot() {
        WidgetUsageSnapshotStore.write(
            WidgetUsageData(
                generatedAt: Date(),
                claude: WidgetServiceData(snapshot: claude),
                codex: WidgetServiceData(snapshot: codex)
            )
        )
        WidgetCenter.shared.reloadAllTimelines()
    }
}

private extension WidgetServiceData {
    init(snapshot: DashboardSnapshot) {
        self.init(
            id: snapshot.service.rawValue,
            name: snapshot.service.displayName,
            status: snapshot.status.label,
            message: snapshot.message,
            lastUpdated: snapshot.lastUpdated,
            nextRefresh: snapshot.nextRefresh,
            metrics: snapshot.metrics.map {
                WidgetMetric(
                    label: $0.label,
                    value: $0.value,
                    detail: $0.detail,
                    percent: $0.percent
                )
            }
        )
    }
}

enum UsageService: String, CaseIterable, Identifiable {
    case claude
    case codex

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .claude:
            return "Claude"
        case .codex:
            return "Codex"
        }
    }

    var dashboardName: String {
        switch self {
        case .claude:
            return "claude.ai/settings/usage"
        case .codex:
            return "chatgpt.com/codex analytics"
        }
    }

    var accent: Color {
        switch self {
        case .claude:
            return Color(red: 0.78, green: 0.42, blue: 0.24)
        case .codex:
            return Color(red: 0.10, green: 0.48, blue: 0.67)
        }
    }

    var symbolName: String {
        switch self {
        case .claude:
            return "sparkles"
        case .codex:
            return "terminal"
        }
    }
}

enum DashboardStatus: String {
    case idle
    case refreshing
    case ready
    case loginRequired
    case noUsageFound
    case error

    var label: String {
        switch self {
        case .idle:
            return "Idle"
        case .refreshing:
            return "Refreshing"
        case .ready:
            return "Ready"
        case .loginRequired:
            return "Sign in needed"
        case .noUsageFound:
            return "Loaded, parser unsure"
        case .error:
            return "Error"
        }
    }
}

struct UsageMetric: Identifiable, Equatable {
    let id = UUID()
    var label: String
    var value: String
    var detail: String?
    var percent: Double?
}

struct DashboardSnapshot: Equatable {
    var service: UsageService
    var status: DashboardStatus = .idle
    var metrics: [UsageMetric] = []
    var highlights: [String] = []
    var lastUpdated: Date?
    var nextRefresh: Date?
    var loadedURL: String?
    var message: String?
    var rawSample: String?

    var shortBadge: String? {
        guard status == .ready || status == .noUsageFound else {
            return nil
        }
        if let percent = metrics.compactMap(\.percent).first {
            return "\(service.displayName) \(Int(percent.rounded()))%"
        }
        if let metric = metrics.first {
            return "\(service.displayName) \(metric.value)"
        }
        return nil
    }
}

enum RefreshReason {
    case timer
    case manual
}

@MainActor
final class DashboardPoller: NSObject, WKNavigationDelegate {
    var onSnapshot: ((DashboardSnapshot) -> Void)?

    private let service: UsageService
    private let url: URL
    private let webView: WKWebView
    private var snapshot: DashboardSnapshot
    private var timer: Timer?
    private var retryTimer: Timer?

    private let normalRefreshInterval: TimeInterval = 10 * 60
    private let minimumManualRefreshInterval: TimeInterval = 60
    private let errorRetryInterval: TimeInterval = 20 * 60
    private var lastManualRefresh: Date?
    private var targetRedirectsRemaining = 2

    init(service: UsageService, url: URL) {
        self.service = service
        self.url = url
        snapshot = DashboardSnapshot(service: service)

        let configuration = WKWebViewConfiguration()
        configuration.websiteDataStore = .default()
        configuration.preferences.javaScriptCanOpenWindowsAutomatically = false

        webView = WKWebView(frame: NSRect(x: 0, y: 0, width: 1440, height: 1100), configuration: configuration)
        super.init()
        webView.navigationDelegate = self
    }

    func start(stagger: TimeInterval = 0) {
        scheduleTimer()
        Task { @MainActor in
            if stagger > 0 {
                try? await Task.sleep(nanoseconds: UInt64(stagger * 1_000_000_000))
            }
            refresh(reason: .timer)
        }
    }

    func refresh(reason: RefreshReason) {
        if reason == .manual {
            let now = Date()
            if let lastManualRefresh, now.timeIntervalSince(lastManualRefresh) < minimumManualRefreshInterval {
                publish(message: "Manual refresh is limited to once per minute.")
                return
            }
            lastManualRefresh = now
        }

        retryTimer?.invalidate()
        targetRedirectsRemaining = 2
        snapshot.status = .refreshing
        snapshot.message = reason == .manual ? "Manual refresh requested." : "Polling dashboard."
        snapshot.nextRefresh = Date().addingTimeInterval(normalRefreshInterval)
        onSnapshot?(snapshot)
        AppLog.write("\(service.displayName) refresh started. reason=\(reason) target=\(url.absoluteString)")

        var request = URLRequest(url: url)
        request.cachePolicy = .reloadIgnoringLocalCacheData
        request.timeoutInterval = 45
        webView.load(request)
    }

    func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
        AppLog.write("\(service.displayName) didFinish url=\(webView.url?.absoluteString ?? "nil")")
        if redirectToTargetDashboardIfNeeded(webView) {
            return
        }

        Task { @MainActor in
            try? await Task.sleep(nanoseconds: 3_000_000_000)
            if redirectToTargetDashboardIfNeeded(webView) {
                return
            }
            await scrape()
            try? await Task.sleep(nanoseconds: 4_000_000_000)
            if redirectToTargetDashboardIfNeeded(webView) {
                return
            }
            await scrape()
        }
    }

    func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: Error) {
        AppLog.write("\(service.displayName) navigation failed: \(error.localizedDescription)")
        markError(error.localizedDescription)
    }

    func webView(_ webView: WKWebView, didFailProvisionalNavigation navigation: WKNavigation!, withError error: Error) {
        AppLog.write("\(service.displayName) provisional navigation failed: \(error.localizedDescription)")
        markError(error.localizedDescription)
    }

    private func scheduleTimer() {
        timer?.invalidate()
        timer = Timer.scheduledTimer(withTimeInterval: normalRefreshInterval, repeats: true) { [weak self] _ in
            Task { @MainActor in
                self?.refresh(reason: .timer)
            }
        }
    }

    private func scheduleErrorRetry() {
        retryTimer?.invalidate()
        retryTimer = Timer.scheduledTimer(withTimeInterval: errorRetryInterval, repeats: false) { [weak self] _ in
            Task { @MainActor in
                self?.refresh(reason: .timer)
            }
        }
    }

    private func redirectToTargetDashboardIfNeeded(_ webView: WKWebView) -> Bool {
        guard service == .codex,
              targetRedirectsRemaining > 0,
              let currentURL = webView.url,
              currentURL.host?.lowercased().contains("chatgpt.com") == true,
              currentURL.path != DashboardURLs.codexPath,
              !currentURL.path.lowercased().contains("auth"),
              !currentURL.path.lowercased().contains("login")
        else {
            return false
        }

        targetRedirectsRemaining -= 1
        AppLog.write("Codex redirected away from analytics to \(currentURL.absoluteString). Re-loading \(url.absoluteString). redirectsRemaining=\(targetRedirectsRemaining)")
        webView.load(URLRequest(url: url))
        return true
    }

    private func scrape() async {
        do {
            let js = """
            (() => {
              const bodyText = document.body ? document.body.innerText : "";
              const documentText = document.documentElement ? document.documentElement.innerText : "";
              const text = bodyText || documentText || "";
              const progress = Array.from(document.querySelectorAll('[role="progressbar"], progress, meter')).map((el) => ({
                text: (el.innerText || "").trim(),
                ariaLabel: el.getAttribute('aria-label') || "",
                ariaValueNow: el.getAttribute('aria-valuenow') || el.value || "",
                ariaValueMin: el.getAttribute('aria-valuemin') || el.min || "",
                ariaValueMax: el.getAttribute('aria-valuemax') || el.max || "",
                title: el.getAttribute('title') || ""
              }));
              const headings = Array.from(document.querySelectorAll('h1,h2,h3,[role="heading"]'))
                .map((el) => (el.innerText || el.textContent || "").trim())
                .filter(Boolean);
              return JSON.stringify({
                title: document.title || "",
                url: location.href,
                text,
                headings,
                progress
              });
            })();
            """

            let result = try await webView.evaluateJavaScript(js)
            guard let json = result as? String, let data = json.data(using: .utf8) else {
                markError("The dashboard returned an unreadable page payload.")
                return
            }

            let page = try JSONDecoder().decode(PagePayload.self, from: data)
            logPagePayload(page)
            let parsed = UsageParser.parse(service: service, page: page)
            logParsedSnapshot(parsed)
            snapshot = parsed
            snapshot.nextRefresh = Date().addingTimeInterval(normalRefreshInterval)
            onSnapshot?(snapshot)

            if parsed.status == .error {
                scheduleErrorRetry()
            }
        } catch {
            AppLog.write("\(service.displayName) scrape failed: \(error.localizedDescription)")
            markError(error.localizedDescription)
        }
    }

    private func logPagePayload(_ page: PagePayload) {
        let lines = page.text
            .replacingOccurrences(of: "\u{00a0}", with: " ")
            .components(separatedBy: .newlines)
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }

        if AppLog.isDebugEnabled {
            let progressSample = page.progress.prefix(8).enumerated().map { index, node in
                "#\(index + 1) text=\(node.text) ariaLabel=\(node.ariaLabel) now=\(node.ariaValueNow) min=\(node.ariaValueMin) max=\(node.ariaValueMax) title=\(node.title)"
            }.joined(separator: "\n")

            AppLog.section(
                "\(service.displayName) page payload debug",
                body: """
                url: \(page.url)
                title: \(page.title)
                textLength: \(page.text.count)
                lineCount: \(lines.count)
                headings: \(page.headings.prefix(12).joined(separator: " | "))
                progressCount: \(page.progress.count)
                progressSample:
                \(progressSample.isEmpty ? "(none)" : progressSample)
                firstLines:
                \(lines.prefix(80).joined(separator: "\n"))
                """
            )
        } else {
            AppLog.write("\(service.displayName) page payload summary: url=\(page.url) title=\(page.title) textLength=\(page.text.count) lineCount=\(lines.count) headings=\(page.headings.count) progressCount=\(page.progress.count)")
        }
    }

    private func logParsedSnapshot(_ snapshot: DashboardSnapshot) {
        let metricLines = snapshot.metrics.map { metric in
            "- \(metric.label): \(metric.value) percent=\(metric.percent.map { String($0) } ?? "nil") detail=\(metric.detail ?? "nil")"
        }.joined(separator: "\n")

        AppLog.section(
            "\(service.displayName) parsed snapshot",
            body: """
            status: \(snapshot.status.label)
            message: \(snapshot.message ?? "nil")
            metricCount: \(snapshot.metrics.count)
            metrics:
            \(metricLines.isEmpty ? "(none)" : metricLines)
            highlights:
            \(snapshot.highlights.joined(separator: "\n"))
            """
        )
    }

    private func publish(message: String) {
        snapshot.message = message
        onSnapshot?(snapshot)
    }

    private func markError(_ message: String) {
        AppLog.write("\(service.displayName) marked error: \(message)")
        snapshot.status = .error
        snapshot.message = message
        snapshot.nextRefresh = Date().addingTimeInterval(errorRetryInterval)
        onSnapshot?(snapshot)
        scheduleErrorRetry()
    }
}

struct PagePayload: Decodable {
    struct ProgressNode: Decodable {
        var text: String
        var ariaLabel: String
        var ariaValueNow: String
        var ariaValueMin: String
        var ariaValueMax: String
        var title: String
    }

    var title: String
    var url: String
    var text: String
    var headings: [String]
    var progress: [ProgressNode]
}

enum UsageParser {
    static func parse(service: UsageService, page: PagePayload) -> DashboardSnapshot {
        var snapshot = DashboardSnapshot(service: service)
        snapshot.lastUpdated = Date()
        snapshot.loadedURL = page.url

        let normalizedText = page.text
            .replacingOccurrences(of: "\u{00a0}", with: " ")
            .replacingOccurrences(of: "\r", with: "\n")

        let lines = normalizedText
            .components(separatedBy: .newlines)
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }

        snapshot.rawSample = lines.prefix(14).joined(separator: "\n")

        if looksUnauthenticated(service: service, url: page.url, lines: lines) {
            snapshot.status = .loginRequired
            snapshot.message = "Open the embedded login window and sign in once. This app keeps its own WebKit cookies."
            snapshot.highlights = conciseHighlights(from: lines, service: service)
            return snapshot
        }

        let progressMetrics = parseProgress(page.progress, service: service)
        let lineMetrics: [UsageMetric]
        let metrics: [UsageMetric]

        if service == .codex {
            let codexCardMetrics = parseCodexAnalyticsCards(lines)
            AppLog.write("Codex parser lines=\(lines.count) cardMetrics=\(codexCardMetrics.count) progressMetrics=\(progressMetrics.count)")
            lineMetrics = codexCardMetrics.isEmpty ? parseMetricLines(lines, service: service) : codexCardMetrics
            metrics = codexCardMetrics.isEmpty ? lineMetrics + progressMetrics : lineMetrics
        } else if service == .claude {
            let claudeCardMetrics = parseClaudeUsageCards(lines)
            AppLog.write("Claude parser lines=\(lines.count) cardMetrics=\(claudeCardMetrics.count) progressMetrics=\(progressMetrics.count)")
            lineMetrics = claudeCardMetrics.isEmpty ? parseMetricLines(lines, service: service) : claudeCardMetrics
            metrics = claudeCardMetrics.isEmpty ? progressMetrics + lineMetrics : lineMetrics
        } else {
            lineMetrics = parseMetricLines(lines, service: service)
            metrics = progressMetrics + lineMetrics
        }

        snapshot.metrics = Array(dedupe(metrics).prefix(6))
        snapshot.highlights = conciseHighlights(from: lines, service: service)

        if service == .codex && lines.contains(where: { $0.lowercased().contains("loading usage data") }) && snapshot.metrics.isEmpty {
            snapshot.status = .refreshing
            snapshot.message = "Codex usage data is still loading."
        } else if snapshot.metrics.isEmpty && snapshot.highlights.isEmpty {
            snapshot.status = .noUsageFound
            snapshot.message = "The page loaded, but no recognizable usage text was found. Use Show page to inspect the dashboard."
        } else {
            snapshot.status = .ready
            snapshot.message = "Polled from \(service.dashboardName)."
        }

        return snapshot
    }

    private static func looksUnauthenticated(service: UsageService, url: String, lines: [String]) -> Bool {
        let loweredURL = url.lowercased()
        if loweredURL.contains("/login") || loweredURL.contains("/auth") || loweredURL.contains("oauth") {
            return true
        }

        let joined = lines.prefix(30).joined(separator: " ").lowercased()
        let signInTerms = ["log in", "login", "sign in", "continue with google", "continue with apple"]
        let usageTerms: [String]

        switch service {
        case .claude:
            usageTerms = ["usage", "limit", "session", "plan"]
        case .codex:
            usageTerms = ["codex", "analytics", "usage", "limit", "cloud"]
        }

        return signInTerms.contains { joined.contains($0) } && !usageTerms.contains { joined.contains($0) }
    }

    private static func parseProgress(_ nodes: [PagePayload.ProgressNode], service: UsageService) -> [UsageMetric] {
        nodes.compactMap { node in
            let rawLabel = [node.ariaLabel, node.title, node.text]
                .map { clean($0) }
                .first { !$0.isEmpty } ?? "Usage"
            let label = explicitMetricLabel(rawLabel, service: service)

            let percent = percentFromProgress(node)
            guard percent != nil || !label.isEmpty else {
                return nil
            }

            let value = percent.map { "\(Int($0.rounded()))%" } ?? clean(node.ariaValueNow)
            guard !value.isEmpty else {
                return nil
            }

            return UsageMetric(label: label, value: value, detail: nil, percent: percent)
        }
    }

    private static func parseClaudeUsageCards(_ lines: [String]) -> [UsageMetric] {
        var metrics: [UsageMetric] = []

        if let sessionIndex = firstIndex(containing: "current session", in: lines) {
            let plan = previousNonNavigationLine(before: sessionIndex, in: lines)
            let starts = nextLine(containing: "starts when", after: sessionIndex, in: lines, maxDistance: 3)
            let detail = [plan, starts].compactMap { $0 }.joined(separator: " - ")
            let valueLine = nextPercentLine(after: sessionIndex, in: lines, maxDistance: 5)
            if let valueLine {
                metrics.append(
                    UsageMetric(
                        label: "Claude current session",
                        value: valueLine,
                        detail: detail.isEmpty ? nil : detail,
                        percent: firstPercent(in: valueLine)
                    )
                )
            } else {
                metrics.append(
                    UsageMetric(
                        label: "Claude current session",
                        value: "Starts when a message is sent",
                        detail: detail.isEmpty ? nil : detail,
                        percent: nil
                    )
                )
            }
        }

        if let weeklyIndex = firstIndex(containing: "weekly limits", in: lines) {
            let reset = nextLine(containing: "resets in", after: weeklyIndex, in: lines, maxDistance: 8)
            let valueLine = nextPercentLine(after: weeklyIndex, in: lines, maxDistance: 8)
            if let valueLine {
                metrics.append(
                    UsageMetric(
                        label: "Claude weekly usage limit",
                        value: valueLine,
                        detail: reset,
                        percent: firstPercent(in: valueLine)
                    )
                )
            } else if let reset {
                metrics.append(
                    UsageMetric(
                        label: "Claude weekly usage limit",
                        value: reset.replacingOccurrences(of: "Resets in ", with: "Resets in "),
                        detail: nil,
                        percent: nil
                    )
                )
            }
        }

        if let designIndex = firstIndex(containing: "claude design", in: lines) {
            let detail = nextNonValueLine(after: designIndex, in: lines, maxDistance: 3)
            if let valueLine = nextPercentLine(after: designIndex, in: lines, maxDistance: 5) {
                metrics.append(
                    UsageMetric(
                        label: "Claude Design",
                        value: valueLine,
                        detail: detail,
                        percent: firstPercent(in: valueLine)
                    )
                )
            }
        }

        if let routineIndex = firstIndex(containing: "daily included routine runs", in: lines) {
            let detail = nextNonValueLine(after: routineIndex, in: lines, maxDistance: 4)
            if let valueLine = nextFractionLine(after: routineIndex, in: lines, maxDistance: 5) {
                metrics.append(
                    UsageMetric(
                        label: "Claude daily routine runs",
                        value: valueLine,
                        detail: detail,
                        percent: fractionPercent(in: valueLine)
                    )
                )
            }
        }

        if let extraIndex = firstIndex(containing: "extra usage", in: lines) {
            let valueLine = nextCurrencyLine(after: extraIndex, in: lines, maxDistance: 8)
            let reset = nextLine(containing: "resets", after: extraIndex, in: lines, maxDistance: 8)
            let percentLine = nextPercentLine(after: extraIndex, in: lines, maxDistance: 8)
            if let valueLine {
                let detail = [reset, percentLine].compactMap { $0 }.joined(separator: " · ")
                metrics.append(
                    UsageMetric(
                        label: "Claude extra usage",
                        value: valueLine,
                        detail: detail.isEmpty ? nil : detail,
                        percent: percentLine.flatMap(firstPercent)
                    )
                )
            }
        }

        if let spendIndex = firstIndex(containing: "monthly spend limit", in: lines) {
            let valueLine = previousCurrencyLine(before: spendIndex, in: lines, maxDistance: 3)
                ?? nextCurrencyLine(after: spendIndex, in: lines, maxDistance: 4)
            let balance = nextCurrencyLine(after: spendIndex, in: lines, maxDistance: 6)
            let reloadIndex = firstIndex(containing: "auto-reload", in: Array(lines.suffix(from: spendIndex)))
                .map { spendIndex + $0 }
            let reloadState = reloadIndex.flatMap { nextLine(after: $0, in: lines, maxDistance: 2) }

            if let valueLine {
                let detailParts = [
                    balance.map { "\($0) current balance" },
                    reloadState.map { "Auto-reload \($0)" }
                ].compactMap { $0 }
                metrics.append(
                    UsageMetric(
                        label: "Claude monthly spend limit",
                        value: valueLine,
                        detail: detailParts.isEmpty ? nil : detailParts.joined(separator: " · "),
                        percent: nil
                    )
                )
            }
        }

        return metrics
    }

    private static func firstIndex(containing needle: String, in lines: [String]) -> Int? {
        lines.firstIndex { $0.lowercased().contains(needle) }
    }

    private static func nextPercentLine(after index: Int, in lines: [String], maxDistance: Int) -> String? {
        let end = min(index + maxDistance, lines.count - 1)
        guard end > index else {
            return nil
        }

        for nextIndex in (index + 1)...end {
            let line = clean(lines[nextIndex])
            if firstPercent(in: line) != nil {
                return line
            }
        }

        return nil
    }

    private static func nextLine(containing needle: String, after index: Int, in lines: [String], maxDistance: Int) -> String? {
        let end = min(index + maxDistance, lines.count - 1)
        guard end > index else {
            return nil
        }

        for nextIndex in (index + 1)...end {
            let line = clean(lines[nextIndex])
            if line.lowercased().contains(needle) {
                return line
            }
        }

        return nil
    }

    private static func nextLine(after index: Int, in lines: [String], maxDistance: Int) -> String? {
        let end = min(index + maxDistance, lines.count - 1)
        guard end > index else {
            return nil
        }

        for nextIndex in (index + 1)...end {
            let line = clean(lines[nextIndex])
            if !line.isEmpty {
                return line
            }
        }

        return nil
    }

    private static func nextNonValueLine(after index: Int, in lines: [String], maxDistance: Int) -> String? {
        let end = min(index + maxDistance, lines.count - 1)
        guard end > index else {
            return nil
        }

        for nextIndex in (index + 1)...end {
            let line = clean(lines[nextIndex])
            guard !line.isEmpty else {
                continue
            }
            if firstPercent(in: line) == nil,
               fractionPercent(in: line) == nil,
               line.range(of: #"^\$?\d+(?:\.\d+)?(?:\s+\w+)?$"#, options: .regularExpression) == nil {
                return line
            }
        }

        return nil
    }

    private static func nextFractionLine(after index: Int, in lines: [String], maxDistance: Int) -> String? {
        nextLineMatching(#"^\d+(?:\.\d+)?\s*/\s*\d+(?:\.\d+)?$"#, after: index, in: lines, maxDistance: maxDistance)
    }

    private static func nextCurrencyLine(after index: Int, in lines: [String], maxDistance: Int) -> String? {
        nextLineMatching(#"^\$\d+(?:\.\d+)?(?:\s+\w+)?$"#, after: index, in: lines, maxDistance: maxDistance)
    }

    private static func previousCurrencyLine(before index: Int, in lines: [String], maxDistance: Int) -> String? {
        guard index > 0 else {
            return nil
        }

        let start = max(0, index - maxDistance)
        for previousIndex in stride(from: index - 1, through: start, by: -1) {
            let line = clean(lines[previousIndex])
            if line.range(of: #"^\$\d+(?:\.\d+)?(?:\s+\w+)?$"#, options: .regularExpression) != nil {
                return line
            }
        }

        return nil
    }

    private static func nextLineMatching(_ pattern: String, after index: Int, in lines: [String], maxDistance: Int) -> String? {
        let end = min(index + maxDistance, lines.count - 1)
        guard end > index else {
            return nil
        }

        for nextIndex in (index + 1)...end {
            let line = clean(lines[nextIndex])
            if line.range(of: pattern, options: .regularExpression) != nil {
                return line
            }
        }

        return nil
    }

    private static func previousNonNavigationLine(before index: Int, in lines: [String]) -> String? {
        guard index > 0 else {
            return nil
        }

        let skip = ["usage", "plan usage limits", "max"]
        for previousIndex in stride(from: index - 1, through: 0, by: -1) {
            let line = clean(lines[previousIndex])
            let lowered = line.lowercased()
            if line.isEmpty || skip.contains(lowered) {
                continue
            }
            if line.count <= 80 {
                return line
            }
        }

        return nil
    }

    private static func parseCodexAnalyticsCards(_ lines: [String]) -> [UsageMetric] {
        var limitMetrics: [UsageMetric] = []
        var creditMetrics: [UsageMetric] = []

        for (index, line) in lines.enumerated() {
            let lowered = line.lowercased()

            if isCodexLimitCardLabel(lowered),
               let percent = nextPercent(after: index, in: lines, maxDistance: 3) {
                let label = codexAnalyticsLimitLabel(from: line)
                let detail = codexAnalyticsDetail(after: index, in: lines)
                limitMetrics.append(
                    UsageMetric(
                        label: label,
                        value: "\(formatPercent(percent)) remaining",
                        detail: detail,
                        percent: percent
                    )
                )
                continue
            }

            if lowered.contains("credits remaining"),
               let value = nextPlainNumber(after: index, in: lines, maxDistance: 3) {
                creditMetrics.append(
                    UsageMetric(
                        label: "Codex credits remaining",
                        value: value,
                        detail: "Credits extend Codex beyond plan limits.",
                        percent: nil
                    )
                )
            }
        }

        return limitMetrics.isEmpty ? [] : limitMetrics + creditMetrics
    }

    private static func isCodexLimitCardLabel(_ lowered: String) -> Bool {
        lowered.contains("usage limit") &&
            (lowered.contains("5 hour") || lowered.contains("5-hour") || lowered.contains("weekly"))
    }

    private static func codexAnalyticsLimitLabel(from line: String) -> String {
        let label = clean(line)
        let lowered = label.lowercased()

        if lowered.contains("gpt-") {
            return label
                .replacingOccurrences(of: "5 hour", with: "5-hour", options: .caseInsensitive)
                .replacingOccurrences(of: "Weekly", with: "weekly")
        }
        if lowered.contains("5 hour") {
            return "Codex 5-hour usage limit"
        }
        if lowered.contains("weekly") || lowered.contains("week") {
            return "Codex weekly usage limit"
        }
        return explicitMetricLabel(label, service: .codex)
    }

    private static func codexAnalyticsDetail(after index: Int, in lines: [String]) -> String? {
        let end = min(index + 5, lines.count - 1)
        guard end > index else {
            return nil
        }

        for nextIndex in (index + 1)...end {
            let line = clean(lines[nextIndex])
            if line.lowercased().contains("reset") {
                return line
            }
        }

        return nil
    }

    private static func nextPercent(after index: Int, in lines: [String], maxDistance: Int) -> Double? {
        let end = min(index + maxDistance, lines.count - 1)
        guard end > index else {
            return nil
        }

        for nextIndex in (index + 1)...end {
            if let percent = firstPercent(in: lines[nextIndex]) {
                return percent
            }
        }

        return nil
    }

    private static func nextPlainNumber(after index: Int, in lines: [String], maxDistance: Int) -> String? {
        let end = min(index + maxDistance, lines.count - 1)
        guard end > index else {
            return nil
        }

        for nextIndex in (index + 1)...end {
            let line = clean(lines[nextIndex])
            if line.range(of: #"^\d+(?:\.\d+)?$"#, options: .regularExpression) != nil {
                return line
            }
        }

        return nil
    }

    private static func formatPercent(_ percent: Double) -> String {
        if percent.rounded() == percent {
            return "\(Int(percent))%"
        }
        return String(format: "%.1f%%", percent)
    }

    private static func percentFromProgress(_ node: PagePayload.ProgressNode) -> Double? {
        if let now = Double(node.ariaValueNow.trimmingCharacters(in: .whitespacesAndNewlines)) {
            let min = Double(node.ariaValueMin.trimmingCharacters(in: .whitespacesAndNewlines)) ?? 0
            let max = Double(node.ariaValueMax.trimmingCharacters(in: .whitespacesAndNewlines)) ?? 100
            guard max > min else {
                return nil
            }
            return ((now - min) / (max - min) * 100).clamped(to: 0...100)
        }

        return firstPercent(in: [node.ariaLabel, node.title, node.text].joined(separator: " "))
    }

    private static func parseMetricLines(_ lines: [String], service: UsageService) -> [UsageMetric] {
        let keywordGroups: [[String]]
        switch service {
        case .claude:
            keywordGroups = [
                ["session"],
                ["weekly"],
                ["usage"],
                ["limit"],
                ["resets", "reset"],
                ["remaining", "left"],
                ["sonnet", "opus"]
            ]
        case .codex:
            keywordGroups = [
                ["codex"],
                ["cloud"],
                ["analytics"],
                ["usage"],
                ["limit"],
                ["resets", "reset"],
                ["remaining", "left"],
                ["task", "tasks"]
            ]
        }

        var result: [UsageMetric] = []

        for (index, line) in lines.enumerated() {
            let lowered = line.lowercased()
            guard keywordGroups.flatMap({ $0 }).contains(where: { lowered.contains($0) }) else {
                continue
            }

            let value = metricValue(in: line) ?? nextValue(after: index, in: lines)
            guard let value, !value.isEmpty else {
                continue
            }

            let label = labelFrom(line: line, service: service)
            let detail = neighboringDetail(index: index, lines: lines)
            result.append(UsageMetric(label: label, value: value, detail: detail, percent: firstPercent(in: line)))
        }

        return result
    }

    private static func metricValue(in line: String) -> String? {
        let patterns = [
            #"(?i)\b\d{1,3}(?:\.\d+)?\s?%"#,
            #"(?i)\b\d+(?:\.\d+)?\s*(?:of|/)\s*\d+(?:\.\d+)?\b"#,
            #"(?i)\b\d+\s*(?:h|hr|hrs|hour|hours)\s*(?:\d+\s*(?:m|min|mins|minute|minutes))?\b"#,
            #"(?i)\b\d+\s*(?:m|min|mins|minute|minutes)\b"#,
            #"(?i)\b(?:today|tomorrow|in\s+\d+|at\s+\d{1,2}:\d{2})\b.*"#
        ]

        for pattern in patterns {
            if let match = line.range(of: pattern, options: .regularExpression) {
                return clean(String(line[match]))
            }
        }

        return nil
    }

    private static func nextValue(after index: Int, in lines: [String]) -> String? {
        let end = min(index + 3, lines.count - 1)
        guard end > index else {
            return nil
        }

        for nextIndex in (index + 1)...end {
            if let value = metricValue(in: lines[nextIndex]) {
                return value
            }
        }

        return nil
    }

    private static func labelFrom(line: String, service: UsageService) -> String {
        var label = line
        if let value = metricValue(in: line), let range = label.range(of: value) {
            label.removeSubrange(range)
        }
        label = clean(label.replacingOccurrences(of: ":", with: ""))
        if label.count > 44 {
            label = String(label.prefix(44)).trimmingCharacters(in: .whitespacesAndNewlines) + "..."
        }
        return explicitMetricLabel(label, service: service)
    }

    private static func explicitMetricLabel(_ rawLabel: String, service: UsageService) -> String {
        let label = clean(rawLabel)
        let lowered = label.lowercased()

        switch service {
        case .claude:
            if lowered.contains("session") {
                return "Claude session limit"
            }
            if lowered.contains("weekly") || lowered.contains("week") {
                return "Claude weekly limit"
            }
            if lowered.contains("reset") || lowered.contains("resets") {
                return "Claude reset time"
            }
            if lowered.contains("remaining") || lowered.contains("left") {
                return "Claude remaining"
            }
            if lowered.contains("opus") {
                return "Claude Opus usage"
            }
            if lowered.contains("sonnet") {
                return "Claude Sonnet usage"
            }
            if lowered.contains("plan") {
                return "Claude plan"
            }
            if lowered.contains("usage") || lowered.contains("limit") || label.isEmpty {
                return "Claude usage limit"
            }
            return label.hasPrefix("Claude") ? label : "Claude \(label)"

        case .codex:
            if lowered.contains("credits remaining") {
                return "Codex credits remaining"
            }
            if lowered.contains("gpt-") {
                return label
                    .replacingOccurrences(of: "5 hour", with: "5-hour", options: .caseInsensitive)
                    .replacingOccurrences(of: "Weekly", with: "weekly")
            }
            if lowered.contains("5 hour") {
                return "Codex 5-hour usage limit"
            }
            if lowered.contains("weekly") || lowered.contains("week") {
                return "Codex weekly usage limit"
            }
            if lowered.contains("cloud") || lowered.contains("analytics") {
                return "Codex cloud usage"
            }
            if lowered.contains("session") {
                return "Codex session limit"
            }
            if lowered.contains("task") || lowered.contains("tasks") {
                return "Codex task limit"
            }
            if lowered.contains("reset") || lowered.contains("resets") {
                return "Codex reset time"
            }
            if lowered.contains("remaining") || lowered.contains("left") {
                return "Codex remaining"
            }
            if lowered.contains("usage") || lowered.contains("limit") || label.isEmpty {
                return "Codex usage limit"
            }
            return label.hasPrefix("Codex") ? label : "Codex \(label)"
        }
    }

    private static func neighboringDetail(index: Int, lines: [String]) -> String? {
        let start = max(0, index - 1)
        let end = min(lines.count - 1, index + 1)
        let text = (start...end)
            .map { lines[$0] }
            .filter { $0.count <= 100 }
            .joined(separator: "  ")

        return text == lines[index] ? nil : clean(text)
    }

    private static func conciseHighlights(from lines: [String], service: UsageService) -> [String] {
        let keywords: [String]
        switch service {
        case .claude:
            keywords = ["session", "weekly", "usage", "limit", "reset", "remaining", "plan"]
        case .codex:
            keywords = ["codex", "cloud", "analytics", "usage", "limit", "reset", "remaining", "task"]
        }

        var highlights: [String] = []
        for line in lines {
            let lowered = line.lowercased()
            guard line.count <= 120, keywords.contains(where: { lowered.contains($0) }) else {
                continue
            }
            highlights.append(line)
            if highlights.count == 5 {
                break
            }
        }

        return highlights
    }

    private static func dedupe(_ metrics: [UsageMetric]) -> [UsageMetric] {
        var seen = Set<String>()
        var result: [UsageMetric] = []

        for metric in metrics {
            let key = "\(metric.label.lowercased())|\(metric.value.lowercased())"
            guard !seen.contains(key) else {
                continue
            }
            seen.insert(key)
            result.append(metric)
        }

        return result
    }

    private static func firstPercent(in text: String) -> Double? {
        let pattern = #"(?i)\b(\d{1,3}(?:\.\d+)?)\s?%"#
        guard let regex = try? NSRegularExpression(pattern: pattern) else {
            return nil
        }
        let range = NSRange(text.startIndex..<text.endIndex, in: text)
        guard let match = regex.firstMatch(in: text, range: range), match.numberOfRanges > 1,
              let swiftRange = Range(match.range(at: 1), in: text),
              let value = Double(text[swiftRange])
        else {
            return nil
        }
        return value.clamped(to: 0...100)
    }

    private static func fractionPercent(in text: String) -> Double? {
        let pattern = #"^\s*(\d+(?:\.\d+)?)\s*/\s*(\d+(?:\.\d+)?)\s*$"#
        guard let regex = try? NSRegularExpression(pattern: pattern) else {
            return nil
        }
        let range = NSRange(text.startIndex..<text.endIndex, in: text)
        guard let match = regex.firstMatch(in: text, range: range),
              match.numberOfRanges > 2,
              let numeratorRange = Range(match.range(at: 1), in: text),
              let denominatorRange = Range(match.range(at: 2), in: text),
              let numerator = Double(text[numeratorRange]),
              let denominator = Double(text[denominatorRange]),
              denominator > 0
        else {
            return nil
        }
        return (numerator / denominator * 100).clamped(to: 0...100)
    }

    private static func clean(_ text: String) -> String {
        text
            .replacingOccurrences(of: #"\s+"#, with: " ", options: .regularExpression)
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }
}

@MainActor
final class LoginWindowController: NSObject, WKNavigationDelegate {
    static let shared = LoginWindowController()

    private var windows: [UsageService: NSWindow] = [:]
    private var refreshHandlers: [UsageService: () -> Void] = [:]
    private var servicesByWebView = [ObjectIdentifier: UsageService]()
    private var targetRedirectsByWebView = [ObjectIdentifier: Int]()

    func open(service: UsageService, url: URL, onClose: @escaping () -> Void) {
        refreshHandlers[service] = onClose

        if let existing = windows[service] {
            existing.makeKeyAndOrderFront(nil)
            NSApp.activate(ignoringOtherApps: true)
            return
        }

        let configuration = WKWebViewConfiguration()
        configuration.websiteDataStore = .default()

        let webView = WKWebView(frame: NSRect(x: 0, y: 0, width: 980, height: 720), configuration: configuration)
        webView.navigationDelegate = self
        let webViewID = ObjectIdentifier(webView)
        servicesByWebView[webViewID] = service
        targetRedirectsByWebView[webViewID] = 3
        webView.load(URLRequest(url: url))

        let window = LoginWindow(service: service)
        window.title = "\(service.displayName) Dashboard Login"
        window.contentView = webView
        window.setContentSize(NSSize(width: 980, height: 720))
        window.center()
        window.delegate = self
        windows[service] = window

        window.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }

    func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
        let webViewID = ObjectIdentifier(webView)
        guard servicesByWebView[webViewID] == .codex,
              (targetRedirectsByWebView[webViewID] ?? 0) > 0,
              let currentURL = webView.url,
              currentURL.host?.lowercased().contains("chatgpt.com") == true,
              currentURL.path != DashboardURLs.codexPath,
              !currentURL.path.lowercased().contains("auth"),
              !currentURL.path.lowercased().contains("login")
        else {
            return
        }

        targetRedirectsByWebView[webViewID, default: 0] -= 1
        webView.load(URLRequest(url: DashboardURLs.codexUsage))
    }
}

final class LoginWindow: NSWindow {
    let service: UsageService

    init(service: UsageService) {
        self.service = service
        super.init(
            contentRect: NSRect(x: 0, y: 0, width: 980, height: 720),
            styleMask: [.titled, .closable, .miniaturizable, .resizable],
            backing: .buffered,
            defer: false
        )
    }
}

extension LoginWindowController: NSWindowDelegate {
    func windowShouldClose(_ sender: NSWindow) -> Bool {
        guard let window = sender as? LoginWindow else {
            return true
        }

        window.orderOut(nil)
        refreshHandlers[window.service]?()
        return false
    }

    func windowWillClose(_ notification: Notification) {
        guard let window = notification.object as? LoginWindow else {
            return
        }

        if let webView = window.contentView as? WKWebView {
            let webViewID = ObjectIdentifier(webView)
            servicesByWebView[webViewID] = nil
            targetRedirectsByWebView[webViewID] = nil
        }
        windows[window.service] = nil
        refreshHandlers[window.service]?()
        refreshHandlers[window.service] = nil
    }
}

@MainActor
final class DesktopWidgetWindowController: NSObject, NSWindowDelegate {
    static let shared = DesktopWidgetWindowController()

    private var window: NSWindow?

    func toggle(monitor: UsageMonitor) {
        if let window, window.isVisible {
            window.orderOut(nil)
            return
        }

        show(monitor: monitor)
    }

    private func show(monitor: UsageMonitor) {
        if let window {
            window.makeKeyAndOrderFront(nil)
            return
        }

        let content = DesktopWidgetView(monitor: monitor)
        let hostingView = NSHostingView(rootView: content)
        let window = NSWindow(
            contentRect: NSRect(x: 120, y: 120, width: 430, height: 560),
            styleMask: [.titled, .closable, .resizable, .fullSizeContentView],
            backing: .buffered,
            defer: false
        )

        window.title = "AI Usage Desktop Widget"
        window.contentView = hostingView
        window.delegate = self
        window.isOpaque = false
        window.backgroundColor = .clear
        window.hasShadow = true
        window.titleVisibility = .hidden
        window.titlebarAppearsTransparent = true
        window.isMovableByWindowBackground = true
        window.level = .floating
        window.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        window.setFrameAutosaveName("AIUsageDesktopWidget")
        window.makeKeyAndOrderFront(nil)

        self.window = window
    }

    func windowShouldClose(_ sender: NSWindow) -> Bool {
        sender.orderOut(nil)
        return false
    }
}

struct DesktopWidgetView: View {
    @ObservedObject var monitor: UsageMonitor

    var body: some View {
        DashboardView(monitor: monitor, compact: true)
            .padding(16)
            .background(.ultraThinMaterial)
            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .stroke(Color.primary.opacity(0.10))
            }
    }
}

struct DashboardView: View {
    @ObservedObject var monitor: UsageMonitor
    var compact: Bool

    var body: some View {
        VStack(spacing: 12) {
            header
            ServiceCard(snapshot: monitor.claude, monitor: monitor)
            ServiceCard(snapshot: monitor.codex, monitor: monitor)
            footer
        }
    }

    private var header: some View {
        HStack(spacing: 10) {
            Image(systemName: "gauge.with.dots.needle.bottom.50percent")
                .font(.system(size: 18, weight: .semibold))
            VStack(alignment: .leading, spacing: 2) {
                Text("AI Usage")
                    .font(.system(size: 15, weight: .semibold))
                Text("Polling Claude and ChatGPT/Codex dashboards")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            Button {
                monitor.refreshAll()
            } label: {
                Image(systemName: "arrow.clockwise")
            }
            .buttonStyle(.borderless)
            .help("Refresh both dashboards")

            Button {
                monitor.toggleDesktopWidget()
            } label: {
                Image(systemName: "rectangle.inset.filled.and.person.filled")
            }
            .buttonStyle(.borderless)
            .help("Toggle desktop widget")

            Button {
                monitor.toggleDisplayMode()
            } label: {
                Image(systemName: monitor.displayMode == .minimal ? "list.bullet.rectangle" : "rectangle.grid.2x2")
            }
            .buttonStyle(.borderless)
            .help(monitor.displayMode.toggleLabel)
        }
    }

    private var footer: some View {
        VStack(alignment: .leading, spacing: 5) {
            HStack {
                Text("\(monitor.displayMode.label) view")
                Text("Auto-refresh: 10 min")
                Spacer()
                Button {
                    monitor.openLogFile()
                } label: {
                    Label("Open Log", systemImage: "doc.text.magnifyingglass")
                }
                .buttonStyle(.borderless)
            }

            Text("Manual refresh: 1 min throttle")
                .lineLimit(1)
        }
        .font(.caption2)
        .foregroundStyle(.secondary)
        .padding(.top, 2)
        .padding(.horizontal, 8)
        .padding(.bottom, 4)
    }
}

struct ServiceCard: View {
    var snapshot: DashboardSnapshot
    @ObservedObject var monitor: UsageMonitor

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 8) {
                Label(snapshot.service.displayName, systemImage: snapshot.service.symbolName)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(snapshot.service.accent)
                Spacer()
                StatusPill(status: snapshot.status)
            }

            if visibleMetrics.isEmpty {
                emptyState
            } else {
                VStack(spacing: 8) {
                    ForEach(visibleMetrics) { metric in
                        MetricRowView(metric: metric, accent: snapshot.service.accent)
                    }
                }
            }

            if monitor.displayMode == .detailed && snapshot.metrics.isEmpty && !snapshot.highlights.isEmpty {
                VStack(alignment: .leading, spacing: 3) {
                    ForEach(snapshot.highlights.prefix(3), id: \.self) { line in
                        Text(line)
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                            .lineLimit(2)
                    }
                }
            }

            HStack(spacing: 10) {
                Button {
                    monitor.refresh(snapshot.service)
                } label: {
                    Label("Refresh", systemImage: "arrow.clockwise")
                }

                Button {
                    monitor.openLoginWindow(for: snapshot.service)
                } label: {
                    Label("Show Page", systemImage: "macwindow")
                }

                Button {
                    monitor.openExternalDashboard(for: snapshot.service)
                } label: {
                    Image(systemName: "safari")
                }
                .help("Open in default browser")

                Spacer()
            }
            .buttonStyle(.borderless)
            .font(.caption)

            HStack {
                Text(lastUpdatedText)
                Spacer()
                Text(nextRefreshText)
            }
            .font(.caption2)
            .foregroundStyle(.secondary)
        }
        .padding(12)
        .padding(.horizontal, 4)
        .background(.regularMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .stroke(Color.primary.opacity(0.08))
        }
    }

    private var visibleMetrics: [UsageMetric] {
        guard monitor.displayMode == .minimal else {
            return snapshot.metrics
        }

        let primary = snapshot.metrics.filter { metric in
            let label = metric.label.lowercased()

            switch snapshot.service {
            case .claude:
                return label == "claude current session" || label == "claude weekly usage limit"
            case .codex:
                guard !label.contains("gpt-") else {
                    return false
                }
                return label.contains("5-hour") || label.contains("5 hour") || label.contains("weekly")
            }
        }

        return primary.isEmpty ? Array(snapshot.metrics.prefix(2)) : primary
    }

    private var emptyState: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(snapshot.message ?? "Waiting for first poll.")
                .font(.caption)
                .foregroundStyle(.secondary)
                .lineLimit(3)
            if let rawSample = snapshot.rawSample, snapshot.status == .noUsageFound {
                Text(rawSample)
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
                    .lineLimit(4)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var lastUpdatedText: String {
        guard let lastUpdated = snapshot.lastUpdated else {
            return "Not updated yet"
        }
        return "Updated \(lastUpdated.formatted(date: .omitted, time: .shortened))"
    }

    private var nextRefreshText: String {
        guard let nextRefresh = snapshot.nextRefresh else {
            return ""
        }
        return "Next \(nextRefresh.formatted(date: .omitted, time: .shortened))"
    }
}

struct StatusPill: View {
    var status: DashboardStatus

    var color: Color {
        switch status {
        case .ready:
            return .green
        case .refreshing:
            return .blue
        case .loginRequired:
            return .orange
        case .noUsageFound:
            return .yellow
        case .error:
            return .red
        case .idle:
            return .secondary
        }
    }

    var body: some View {
        Text(status.label)
            .font(.caption2.weight(.medium))
            .foregroundStyle(color)
            .padding(.horizontal, 7)
            .padding(.vertical, 3)
            .background(color.opacity(0.12))
            .clipShape(Capsule())
    }
}

struct MetricRowView: View {
    var metric: UsageMetric
    var accent: Color

    var body: some View {
        VStack(alignment: .leading, spacing: 5) {
            HStack(alignment: .firstTextBaseline) {
                Text(metric.label)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                Spacer()
                Text(metric.value)
                    .font(.system(size: 13, weight: .semibold, design: .rounded))
                    .lineLimit(1)
                    .minimumScaleFactor(0.85)
            }

            if let percent = metric.percent {
                ProgressView(value: percent, total: 100)
                    .tint(accent)
            }

            if let detail = metric.detail, !detail.isEmpty {
                Text(detail)
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
                    .lineLimit(2)
            }
        }
    }
}

extension Comparable {
    func clamped(to limits: ClosedRange<Self>) -> Self {
        min(max(self, limits.lowerBound), limits.upperBound)
    }
}
