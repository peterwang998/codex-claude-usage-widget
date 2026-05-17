#!/usr/bin/env swift
import AppKit
import CoreGraphics
import Foundation
import ImageIO
import UniformTypeIdentifiers

let root = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
let resourcesURL = root.appendingPathComponent("Resources", isDirectory: true)
let iconsetURL = resourcesURL.appendingPathComponent("AppIcon.iconset", isDirectory: true)
let icnsURL = resourcesURL.appendingPathComponent("AppIcon.icns")
let fileManager = FileManager.default

try? fileManager.removeItem(at: iconsetURL)
try fileManager.createDirectory(at: iconsetURL, withIntermediateDirectories: true)

struct IconSpec {
    let pixels: Int
    let filename: String
}

let specs = [
    IconSpec(pixels: 16, filename: "icon_16x16.png"),
    IconSpec(pixels: 32, filename: "icon_16x16@2x.png"),
    IconSpec(pixels: 32, filename: "icon_32x32.png"),
    IconSpec(pixels: 64, filename: "icon_32x32@2x.png"),
    IconSpec(pixels: 128, filename: "icon_128x128.png"),
    IconSpec(pixels: 256, filename: "icon_128x128@2x.png"),
    IconSpec(pixels: 256, filename: "icon_256x256.png"),
    IconSpec(pixels: 512, filename: "icon_256x256@2x.png"),
    IconSpec(pixels: 512, filename: "icon_512x512.png"),
    IconSpec(pixels: 1024, filename: "icon_512x512@2x.png")
]

func cgColor(_ red: CGFloat, _ green: CGFloat, _ blue: CGFloat, _ alpha: CGFloat = 1) -> CGColor {
    CGColor(red: red, green: green, blue: blue, alpha: alpha)
}

func point(center: CGPoint, radius: CGFloat, degrees: CGFloat) -> CGPoint {
    let radians = degrees * .pi / 180
    return CGPoint(
        x: center.x + cos(radians) * radius,
        y: center.y + sin(radians) * radius
    )
}

func drawArc(
    in context: CGContext,
    center: CGPoint,
    radius: CGFloat,
    start: CGFloat,
    end: CGFloat,
    width: CGFloat,
    color: CGColor
) {
    context.saveGState()
    context.setStrokeColor(color)
    context.setLineWidth(width)
    context.setLineCap(.round)
    context.addArc(
        center: center,
        radius: radius,
        startAngle: start * .pi / 180,
        endAngle: end * .pi / 180,
        clockwise: false
    )
    context.strokePath()
    context.restoreGState()
}

func drawIcon(pixels: Int) throws -> Data {
    let size = CGFloat(pixels)
    let colorSpace = CGColorSpaceCreateDeviceRGB()
    guard let context = CGContext(
        data: nil,
        width: pixels,
        height: pixels,
        bitsPerComponent: 8,
        bytesPerRow: pixels * 4,
        space: colorSpace,
        bitmapInfo: CGImageAlphaInfo.noneSkipLast.rawValue
    ) else {
        throw NSError(domain: "AIUsageIcon", code: 1)
    }

    context.setAllowsAntialiasing(true)
    context.setShouldAntialias(true)
    context.interpolationQuality = .high

    let rect = CGRect(x: 0, y: 0, width: size, height: size)
    context.setFillColor(cgColor(0.018, 0.022, 0.031))
    context.fill(rect)

    let inset = size * 0.055
    let iconRect = rect.insetBy(dx: inset, dy: inset)
    let cornerRadius = size * 0.22
    let iconPath = CGPath(
        roundedRect: iconRect,
        cornerWidth: cornerRadius,
        cornerHeight: cornerRadius,
        transform: nil
    )

    context.saveGState()
    context.addPath(iconPath)
    context.clip()

    let gradientColors = [
        cgColor(0.018, 0.022, 0.031),
        cgColor(0.055, 0.135, 0.165),
        cgColor(0.020, 0.026, 0.038)
    ] as CFArray
    let gradient = CGGradient(colorsSpace: colorSpace, colors: gradientColors, locations: [0.0, 0.52, 1.0])!
    context.drawLinearGradient(
        gradient,
        start: CGPoint(x: iconRect.minX, y: iconRect.maxY),
        end: CGPoint(x: iconRect.maxX, y: iconRect.minY),
        options: []
    )

    context.setFillColor(cgColor(0.04, 0.55, 0.78, 0.20))
    context.fillEllipse(in: CGRect(x: size * 0.20, y: size * 0.18, width: size * 0.60, height: size * 0.60))
    context.restoreGState()

    context.saveGState()
    context.addPath(CGPath(
        roundedRect: iconRect.insetBy(dx: size * 0.018, dy: size * 0.018),
        cornerWidth: cornerRadius * 0.92,
        cornerHeight: cornerRadius * 0.92,
        transform: nil
    ))
    context.setStrokeColor(cgColor(1, 1, 1, 0.16))
    context.setLineWidth(max(1.0, size * 0.012))
    context.strokePath()
    context.restoreGState()

    let center = CGPoint(x: size * 0.50, y: size * 0.38)
    let radius = size * 0.31
    let baseWidth = max(2.4, size * 0.040)

    drawArc(
        in: context,
        center: center,
        radius: radius,
        start: 205,
        end: 335,
        width: baseWidth,
        color: cgColor(1, 1, 1, 0.22)
    )
    drawArc(
        in: context,
        center: center,
        radius: radius,
        start: 205,
        end: 292,
        width: baseWidth,
        color: cgColor(0.07, 0.57, 0.78)
    )
    drawArc(
        in: context,
        center: center,
        radius: radius,
        start: 292,
        end: 335,
        width: baseWidth,
        color: cgColor(0.90, 0.43, 0.22)
    )

    context.saveGState()
    context.setLineCap(.round)
    context.setLineWidth(max(1.0, size * 0.012))
    context.setStrokeColor(cgColor(1, 1, 1, 0.66))
    for index in 0...8 {
        let angle = CGFloat(205 + (130.0 / 8.0) * CGFloat(index))
        let inner = point(center: center, radius: radius - size * 0.050, degrees: angle)
        let outer = point(center: center, radius: radius - size * 0.013, degrees: angle)
        context.move(to: inner)
        context.addLine(to: outer)
        context.strokePath()
    }
    context.restoreGState()

    let needleTip = point(center: center, radius: radius * 0.72, degrees: 306)
    context.saveGState()
    context.setStrokeColor(cgColor(1, 1, 1, 0.94))
    context.setLineWidth(max(2.2, size * 0.026))
    context.setLineCap(.round)
    context.move(to: center)
    context.addLine(to: needleTip)
    context.strokePath()
    context.restoreGState()

    let hubRect = CGRect(
        x: center.x - size * 0.044,
        y: center.y - size * 0.044,
        width: size * 0.088,
        height: size * 0.088
    )
    context.setFillColor(cgColor(0.07, 0.57, 0.78))
    context.fillEllipse(in: hubRect)
    context.setFillColor(cgColor(1, 1, 1, 0.92))
    context.fillEllipse(in: hubRect.insetBy(dx: size * 0.024, dy: size * 0.024))

    NSGraphicsContext.saveGraphicsState()
    NSGraphicsContext.current = NSGraphicsContext(cgContext: context, flipped: false)
    let paragraphStyle = NSMutableParagraphStyle()
    paragraphStyle.alignment = .center
    let attrs: [NSAttributedString.Key: Any] = [
        .font: NSFont.systemFont(ofSize: size * 0.17, weight: .heavy),
        .foregroundColor: NSColor.white.withAlphaComponent(0.92),
        .paragraphStyle: paragraphStyle,
        .kern: size * 0.004
    ]
    NSString(string: "AI").draw(
        in: CGRect(x: size * 0.29, y: size * 0.64, width: size * 0.42, height: size * 0.19),
        withAttributes: attrs
    )
    NSGraphicsContext.restoreGraphicsState()

    guard let image = context.makeImage() else {
        throw NSError(domain: "AIUsageIcon", code: 2)
    }

    let data = NSMutableData()
    guard let destination = CGImageDestinationCreateWithData(data, UTType.png.identifier as CFString, 1, nil) else {
        throw NSError(domain: "AIUsageIcon", code: 3)
    }
    CGImageDestinationAddImage(destination, image, nil)
    guard CGImageDestinationFinalize(destination) else {
        throw NSError(domain: "AIUsageIcon", code: 4)
    }
    return data as Data
}

var pngsByFilename: [String: Data] = [:]
for spec in specs {
    let png = try drawIcon(pixels: spec.pixels)
    pngsByFilename[spec.filename] = png
    try png.write(to: iconsetURL.appendingPathComponent(spec.filename))
}

func fourCharData(_ value: String) -> Data {
    Data(value.utf8)
}

func uint32Data(_ value: Int) -> Data {
    var bigEndian = UInt32(value).bigEndian
    return Data(bytes: &bigEndian, count: MemoryLayout<UInt32>.size)
}

let icnsChunks = [
    ("icp4", "icon_16x16.png"),
    ("ic11", "icon_16x16@2x.png"),
    ("icp5", "icon_32x32.png"),
    ("ic12", "icon_32x32@2x.png"),
    ("ic07", "icon_128x128.png"),
    ("ic13", "icon_128x128@2x.png"),
    ("ic08", "icon_256x256.png"),
    ("ic14", "icon_256x256@2x.png"),
    ("ic09", "icon_512x512.png"),
    ("ic10", "icon_512x512@2x.png")
]

let totalLength = 8 + icnsChunks.reduce(0) { partial, chunk in
    partial + 8 + (pngsByFilename[chunk.1]?.count ?? 0)
}

var icnsData = Data()
icnsData.append(fourCharData("icns"))
icnsData.append(uint32Data(totalLength))

for (type, filename) in icnsChunks {
    guard let png = pngsByFilename[filename] else {
        throw NSError(domain: "AIUsageIcon", code: 5)
    }
    icnsData.append(fourCharData(type))
    icnsData.append(uint32Data(8 + png.count))
    icnsData.append(png)
}

try icnsData.write(to: icnsURL)
print(icnsURL.path)
