// swift-tools-version: 6.0

import PackageDescription

let package = Package(
    name: "CodexClaudeUsageWidget",
    platforms: [
        .macOS(.v14)
    ],
    products: [
        .executable(name: "ai-usage-widget", targets: ["UsageWidget"])
    ],
    targets: [
        .executableTarget(
            name: "UsageWidget",
            path: "Sources",
            exclude: ["UsageWidgetExtension"],
            swiftSettings: [
                .define("AI_USAGE_WIDGET_SHOW_TIP_LINK")
            ]
        )
    ]
)
