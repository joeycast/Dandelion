#!/usr/bin/env swift

import CoreGraphics
import Foundation
import ImageIO
import UniformTypeIdentifiers

struct Config {
    var outputPath: String?
    var pngOutputPath: String?
    var size: CGFloat = 1024
    var seedCount: Int = 140
    var filamentsPerSeed: Int = 20
    var windStrength: CGFloat = 0
    var time: TimeInterval = 0
    var includeBackground: Bool = true
    var backgroundHex: String = "#000000"
}

enum Exit: Error {
    case message(String)
}

func parseArgs() throws -> Config {
    var config = Config()
    var args = Array(CommandLine.arguments.dropFirst())

    func popValue() throws -> String {
        guard !args.isEmpty else { throw Exit.message("Missing value for previous flag") }
        return args.removeFirst()
    }

    while !args.isEmpty {
        let arg = args.removeFirst()
        switch arg {
        case "-o", "--output":
            config.outputPath = try popValue()
        case "--png-output":
            config.pngOutputPath = try popValue()
        case "--size":
            config.size = CGFloat(Double(try popValue()) ?? 1024)
        case "--seed-count":
            config.seedCount = Int(try popValue()) ?? 140
        case "--filaments":
            config.filamentsPerSeed = Int(try popValue()) ?? 20
        case "--wind":
            config.windStrength = CGFloat(Double(try popValue()) ?? 0)
        case "--time":
            config.time = Double(try popValue()) ?? 0
        case "--transparent":
            config.includeBackground = false
        case "--background":
            config.backgroundHex = try popValue()
            config.includeBackground = true
        case "-h", "--help":
            throw Exit.message(
                """
                Usage: Scripts/generate_dandelion_svg.swift [options]

                  -o, --output <path>     Output file (defaults to stdout)
                  --png-output <path>     Output PNG file
                  --size <points>         Canvas size (default: 1024)
                  --seed-count <n>        Seeds (default: 140)
                  --filaments <n>         Filaments per seed base (default: 20)
                  --wind <strength>       Wind strength (default: 0)
                  --time <seconds>        Time for sway/flutter (default: 0)
                  --transparent           No background rect
                  --background <#RRGGBB>  Background color (default: #000000)
                """
            )
        default:
            throw Exit.message("Unknown argument: \(arg)")
        }
    }

    return config
}

struct SVG {
    var out = ""

    mutating func append(_ string: String) {
        out.append(string)
    }

    mutating func appendLine(_ string: String = "") {
        out.append(string)
        out.append("\n")
    }
}

@inline(__always)
func fmt(_ value: CGFloat, decimals: Int = 2) -> String {
    String(format: "%.\(decimals)f", Double(value))
}

@inline(__always)
func fmt01(_ value: CGFloat) -> String {
    fmt(value.clamped(0, 1), decimals: 3)
}

private func parseHexRGB(_ hex: String) throws -> (CGFloat, CGFloat, CGFloat) {
    var value = hex.trimmingCharacters(in: .whitespacesAndNewlines).uppercased()
    if value.hasPrefix("#") { value.removeFirst() }
    guard value.count == 6 else {
        throw Exit.message("Expected #RRGGBB, got: \(hex)")
    }

    func byte(at offset: Int) throws -> CGFloat {
        let start = value.index(value.startIndex, offsetBy: offset)
        let end = value.index(start, offsetBy: 2)
        let slice = value[start..<end]
        guard let int = UInt8(slice, radix: 16) else {
            throw Exit.message("Invalid hex color: \(hex)")
        }
        return CGFloat(int) / 255.0
    }

    let r = try byte(at: 0)
    let g = try byte(at: 2)
    let b = try byte(at: 4)
    return (r, g, b)
}

private struct DandelionIconGenerator {
    static func generate(config: Config) -> String {
        let canvas = CGSize(width: config.size, height: config.size)
        let visibleHeight = canvas.height
        let minSide = min(canvas.width, visibleHeight)
        let headRadius = minSide * 0.2

        let stemBase = CGPoint(x: canvas.width * 0.5, y: visibleHeight * 0.92)
        let restHeadCenter = CGPoint(x: canvas.width * 0.5, y: visibleHeight * 0.38)

        let stemAngle: CGFloat = 0
        let stemVector = restHeadCenter - stemBase
        let stemBob = sin(CGFloat(config.time) * 0.35 + 1.1) * headRadius * 0.03
        let headCenter = stemBase + stemVector.rotated(by: stemAngle) + CGPoint(x: 0, y: stemBob)

        var rng = SeededRandomNumberGenerator(seed: 0xDA11_F0AD)
        var seeds: [DandelionSeed] = []
        seeds.reserveCapacity(config.seedCount)
        for index in 0..<config.seedCount {
            seeds.append(
                DandelionSeed.make(
                    index: index,
                    total: config.seedCount,
                    filamentsPerSeed: config.filamentsPerSeed,
                    rng: &rng
                )
            )
        }

        let backSeeds = seeds.filter { $0.depth < 0 }
        let frontSeeds = seeds.filter { $0.depth >= 0 }

        var svg = SVG()
        svg.appendLine(#"<?xml version="1.0" encoding="UTF-8"?>"#)
        svg.appendLine(
            """
            <svg xmlns="http://www.w3.org/2000/svg" width="\(fmt(config.size))" height="\(fmt(config.size))" viewBox="0 0 \(fmt(config.size)) \(fmt(config.size))" fill="none">
              <defs>
                <linearGradient id="stemGradient" gradientUnits="userSpaceOnUse" x1="\(fmt(stemBase.x))" y1="\(fmt(stemBase.y))" x2="\(fmt(headCenter.x))" y2="\(fmt(headCenter.y))">
                  <stop offset="0" stop-color="#A3BD5C"/>
                  <stop offset="1" stop-color="#C2D46B"/>
                </linearGradient>
                <radialGradient id="coreGradient" gradientUnits="userSpaceOnUse" cx="\(fmt(headCenter.x))" cy="\(fmt(headCenter.y))" r="\(fmt(headRadius * 0.9))">
                  <stop offset="0" stop-color="#D9BF73" stop-opacity="0.95"/>
                  <stop offset="0.55" stop-color="#FAEDBF" stop-opacity="0.75"/>
                  <stop offset="1" stop-color="#E0DBD1" stop-opacity="0.90"/>
                </radialGradient>
              </defs>
            """
        )

        if config.includeBackground {
            svg.appendLine(#"  <rect width="100%" height="100%" fill=""# + config.backgroundHex + #""/>"#)
        }

        // Stem
        let stemPath = stemPathData(base: stemBase, headCenter: headCenter)
        let stemWidth = max(1.2, headRadius * 0.08)
        svg.appendLine(
            """
              <path d="\(stemPath)" stroke="url(#stemGradient)" stroke-width="\(fmt(stemWidth))" stroke-linecap="round"/>
            """
        )

        // Seeds (back)
        let windField = DandelionWindField()
        let globalAngle = stemAngle * 0.4
        let t = CGFloat(config.time)
        for seed in backSeeds {
            svg.append(seedGroup(
                seed: seed,
                headCenter: headCenter,
                headRadius: headRadius,
                time: t,
                globalAngle: globalAngle,
                windStrength: config.windStrength,
                windField: windField
            ))
        }

        // Core
        let coreRadius = headRadius * 0.58
        svg.appendLine(
            """
              <circle cx="\(fmt(headCenter.x))" cy="\(fmt(headCenter.y))" r="\(fmt(coreRadius))" fill="url(#coreGradient)"/>
            """
        )

        // Seeds (front)
        for seed in frontSeeds {
            svg.append(seedGroup(
                seed: seed,
                headCenter: headCenter,
                headRadius: headRadius,
                time: t,
                globalAngle: globalAngle,
                windStrength: config.windStrength,
                windField: windField
            ))
        }

        svg.appendLine("</svg>")
        return svg.out
    }

    static func writePNG(config: Config, to url: URL) throws {
        let canvas = CGSize(width: config.size, height: config.size)
        let visibleHeight = canvas.height
        let minSide = min(canvas.width, visibleHeight)
        let headRadius = minSide * 0.2

        let stemBase = CGPoint(x: canvas.width * 0.5, y: visibleHeight * 0.92)
        let restHeadCenter = CGPoint(x: canvas.width * 0.5, y: visibleHeight * 0.38)

        let stemAngle: CGFloat = 0
        let stemVector = restHeadCenter - stemBase
        let stemBob = sin(CGFloat(config.time) * 0.35 + 1.1) * headRadius * 0.03
        let headCenter = stemBase + stemVector.rotated(by: stemAngle) + CGPoint(x: 0, y: stemBob)

        var rng = SeededRandomNumberGenerator(seed: 0xDA11_F0AD)
        var seeds: [DandelionSeed] = []
        seeds.reserveCapacity(config.seedCount)
        for index in 0..<config.seedCount {
            seeds.append(
                DandelionSeed.make(
                    index: index,
                    total: config.seedCount,
                    filamentsPerSeed: config.filamentsPerSeed,
                    rng: &rng
                )
            )
        }

        let backSeeds = seeds.filter { $0.depth < 0 }
        let frontSeeds = seeds.filter { $0.depth >= 0 }

        let width = Int(canvas.width.rounded())
        let height = Int(canvas.height.rounded())
        guard width > 0, height > 0 else {
            throw Exit.message("Invalid canvas size: \(canvas)")
        }

        let colorSpace = CGColorSpaceCreateDeviceRGB()
        let bitmapInfo = CGImageAlphaInfo.premultipliedLast.rawValue
        guard let context = CGContext(
            data: nil,
            width: width,
            height: height,
            bitsPerComponent: 8,
            bytesPerRow: 0,
            space: colorSpace,
            bitmapInfo: bitmapInfo
        ) else {
            throw Exit.message("Failed to create CGContext")
        }

        // Match SwiftUI/SVG coordinate space (origin top-left, y down).
        context.translateBy(x: 0, y: canvas.height)
        context.scaleBy(x: 1, y: -1)

        context.setAllowsAntialiasing(true)
        context.setShouldAntialias(true)
        context.setLineCap(.round)

        if config.includeBackground {
            let (r, g, b) = try parseHexRGB(config.backgroundHex)
            context.setFillColor(CGColor(colorSpace: colorSpace, components: [r, g, b, 1])!)
            context.fill(CGRect(origin: .zero, size: canvas))
        }

        drawStemPNG(in: context, colorSpace: colorSpace, base: stemBase, headCenter: headCenter, headRadius: headRadius)

        let windField = DandelionWindField()
        let globalAngle = stemAngle * 0.4
        let t = CGFloat(config.time)

        for seed in backSeeds {
            drawSeedPNG(
                seed,
                in: context,
                colorSpace: colorSpace,
                headCenter: headCenter,
                headRadius: headRadius,
                time: t,
                globalAngle: globalAngle,
                windStrength: config.windStrength,
                windField: windField
            )
        }

        drawCorePNG(in: context, colorSpace: colorSpace, center: headCenter, headRadius: headRadius)

        for seed in frontSeeds {
            drawSeedPNG(
                seed,
                in: context,
                colorSpace: colorSpace,
                headCenter: headCenter,
                headRadius: headRadius,
                time: t,
                globalAngle: globalAngle,
                windStrength: config.windStrength,
                windField: windField
            )
        }

        guard let image = context.makeImage() else {
            throw Exit.message("Failed to create CGImage")
        }

        guard let destination = CGImageDestinationCreateWithURL(
            url as CFURL,
            UTType.png.identifier as CFString,
            1,
            nil
        ) else {
            throw Exit.message("Failed to create PNG destination")
        }
        CGImageDestinationAddImage(destination, image, nil)
        guard CGImageDestinationFinalize(destination) else {
            throw Exit.message("Failed to write PNG to \(url.path)")
        }
    }

    private static func drawStemPNG(
        in context: CGContext,
        colorSpace: CGColorSpace,
        base: CGPoint,
        headCenter: CGPoint,
        headRadius: CGFloat
    ) {
        let stemVector = headCenter - base
        let controlOffset = stemVector.perpendicular.normalized * (stemVector.length * 0.18)
        let control = base + stemVector * 0.5 + controlOffset
        let stemWidth = max(1.2, headRadius * 0.08)

        let path = CGMutablePath()
        path.move(to: base)
        path.addQuadCurve(to: headCenter, control: control)

        let c0 = CGColor(colorSpace: colorSpace, components: [0.64, 0.74, 0.36, 1])!
        let c1 = CGColor(colorSpace: colorSpace, components: [0.76, 0.83, 0.42, 1])!
        let gradient = CGGradient(colorsSpace: colorSpace, colors: [c0, c1] as CFArray, locations: [0, 1])!

        context.saveGState()
        context.addPath(path)
        context.setLineWidth(stemWidth)
        context.replacePathWithStrokedPath()
        context.clip()
        context.drawLinearGradient(gradient, start: base, end: headCenter, options: [])
        context.restoreGState()
    }

    private static func drawCorePNG(in context: CGContext, colorSpace: CGColorSpace, center: CGPoint, headRadius: CGFloat) {
        let coreRadius = headRadius * 0.58
        let coreRect = CGRect(
            x: center.x - coreRadius,
            y: center.y - coreRadius,
            width: coreRadius * 2,
            height: coreRadius * 2
        )

        let accent = CGColor(colorSpace: colorSpace, components: [0.85, 0.75, 0.45, 0.95])!
        let primary = CGColor(colorSpace: colorSpace, components: [0.98, 0.93, 0.75, 0.75])!
        let subtle = CGColor(colorSpace: colorSpace, components: [0.88, 0.86, 0.82, 0.90])!
        let gradient = CGGradient(colorsSpace: colorSpace, colors: [accent, primary, subtle] as CFArray, locations: [0, 0.55, 1])!

        context.saveGState()
        context.addEllipse(in: coreRect)
        context.clip()
        context.drawRadialGradient(
            gradient,
            startCenter: center,
            startRadius: 1,
            endCenter: center,
            endRadius: headRadius * 0.9,
            options: []
        )
        context.restoreGState()
    }

    private static func drawSeedPNG(
        _ seed: DandelionSeed,
        in context: CGContext,
        colorSpace: CGColorSpace,
        headCenter: CGPoint,
        headRadius: CGFloat,
        time: CGFloat,
        globalAngle: CGFloat,
        windStrength: CGFloat,
        windField: DandelionWindField
    ) {
        let depthFactor = (seed.depth + 1) * 0.5
        let depthScale = 0.78 + depthFactor * 0.32
        let baseSeedOpacity = 0.35 + depthFactor * 0.65

        let baseDirection = seed.orientation.rotated(by: globalAngle)
        let localSway = sin(time * seed.swayFrequency + seed.swayPhase) * 0.07
        let direction = baseDirection.rotated(by: seed.angle + localSway)

        let anchor = headCenter
            + seed.projection * (headRadius * (1 - seed.anchorInset))
            + seed.anchorJitter * headRadius

        let beakLength = headRadius * seed.beakLength * depthScale
        let pappusCenter = anchor + direction * beakLength
        let pappusRadius = headRadius * seed.pappusRadius * depthScale

        let windVector = windField.vector(at: seed.projection, time: TimeInterval(time), strength: windStrength)
        let windBend = windVector * (headRadius * 0.12)

        let beakWidth = max(0.6, headRadius * 0.025)
        let filamentWidth = max(0.4, headRadius * 0.012)

        context.saveGState()
        context.setAlpha(baseSeedOpacity)

        // Beak
        context.beginPath()
        context.move(to: anchor)
        context.addLine(to: pappusCenter)
        context.setStrokeColor(CGColor(colorSpace: colorSpace, components: [0.85, 0.75, 0.45, 0.55])!)
        context.setLineWidth(beakWidth)
        context.strokePath()

        // Achene
        let acheneLength = headRadius * 0.14 * depthScale
        let acheneWidth = headRadius * 0.055 * depthScale
        let acheneCenter = anchor + direction * (headRadius * 0.04)
        let acheneAngle = atan2(direction.y, direction.x)

        context.saveGState()
        context.translateBy(x: acheneCenter.x, y: acheneCenter.y)
        context.rotate(by: acheneAngle)
        let acheneRect = CGRect(
            x: -acheneLength * 0.5,
            y: -acheneWidth * 0.5,
            width: acheneLength,
            height: acheneWidth
        )
        let achenePath = CGPath(
            roundedRect: acheneRect,
            cornerWidth: acheneWidth * 0.5,
            cornerHeight: acheneWidth * 0.5,
            transform: nil
        )
        context.addPath(achenePath)
        context.setFillColor(CGColor(colorSpace: colorSpace, components: [0.85, 0.75, 0.45, 0.75])!)
        context.fillPath()
        context.restoreGState()

        // Filaments
        let axisA = direction.perpendicular
        let axisB = direction * (0.25 + abs(seed.depth) * 0.75)
        context.beginPath()
        for index in 0..<seed.filamentAngles.count {
            let angle = seed.filamentAngles[index]
            let phase = seed.filamentPhases[index]
            let lengthScale = seed.filamentLengths[index]

            let flutter = sin(time * 1.6 + phase) * 0.12
            let localAngle = angle + flutter
            let directionVector = (axisA * cos(localAngle) + axisB * sin(localAngle)).normalized

            let filamentLength = pappusRadius * lengthScale
            let endPoint = pappusCenter + directionVector * filamentLength
            let controlPoint = pappusCenter + directionVector * (filamentLength * 0.6) + windBend

            context.move(to: pappusCenter)
            context.addQuadCurve(to: endPoint, control: controlPoint)
        }
        let filamentOpacity = 0.65 + depthFactor * 0.3
        context.setStrokeColor(CGColor(colorSpace: colorSpace, components: [0.97, 0.95, 0.90, filamentOpacity])!)
        context.setLineWidth(filamentWidth)
        context.strokePath()

        // Crown
        let crownRadius = (pappusRadius * 0.16) * 0.5
        let crownRect = CGRect(
            x: pappusCenter.x - crownRadius,
            y: pappusCenter.y - crownRadius,
            width: crownRadius * 2,
            height: crownRadius * 2
        )
        context.setFillColor(CGColor(colorSpace: colorSpace, components: [0.97, 0.95, 0.90, 0.85])!)
        context.fillEllipse(in: crownRect)

        context.restoreGState()
    }

    private static func stemPathData(base: CGPoint, headCenter: CGPoint) -> String {
        let stemVector = headCenter - base
        let controlOffset = stemVector.perpendicular.normalized * (stemVector.length * 0.18)
        let control = base + stemVector * 0.5 + controlOffset

        return "M \(fmt(base.x)) \(fmt(base.y)) Q \(fmt(control.x)) \(fmt(control.y)) \(fmt(headCenter.x)) \(fmt(headCenter.y))"
    }

    private static func seedGroup(
        seed: DandelionSeed,
        headCenter: CGPoint,
        headRadius: CGFloat,
        time: CGFloat,
        globalAngle: CGFloat,
        windStrength: CGFloat,
        windField: DandelionWindField
    ) -> String {
        let depthFactor = (seed.depth + 1) * 0.5
        let depthScale = 0.78 + depthFactor * 0.32
        let baseSeedOpacity = 0.35 + depthFactor * 0.65

        let baseDirection = seed.orientation.rotated(by: globalAngle)
        let localSway = sin(time * seed.swayFrequency + seed.swayPhase) * 0.07
        let direction = baseDirection.rotated(by: seed.angle + localSway)

        let anchor = headCenter
            + seed.projection * (headRadius * (1 - seed.anchorInset))
            + seed.anchorJitter * headRadius

        let beakLength = headRadius * seed.beakLength * depthScale
        let pappusCenter = anchor + direction * beakLength
        let pappusRadius = headRadius * seed.pappusRadius * depthScale

        let windVector = windField.vector(
            at: seed.projection,
            time: TimeInterval(time),
            strength: windStrength
        )
        let windBend = windVector * (headRadius * 0.12)

        let beakWidth = max(0.6, headRadius * 0.025)
        let filamentWidth = max(0.4, headRadius * 0.012)

        let beakStrokeOpacity: CGFloat = 0.55
        let acheneFillOpacity: CGFloat = 0.75
        let crownFillOpacity: CGFloat = 0.85
        let filamentStrokeOpacity: CGFloat = 0.65 + depthFactor * 0.3

        let acheneLength = headRadius * 0.14 * depthScale
        let acheneWidth = headRadius * 0.055 * depthScale
        let acheneCenter = anchor + direction * (headRadius * 0.04)
        let acheneAngle = atan2(direction.y, direction.x) * (180 / .pi)
        let acheneX = acheneCenter.x - acheneLength * 0.5
        let acheneY = acheneCenter.y - acheneWidth * 0.5

        let crownR = (pappusRadius * 0.16) * 0.5

        let filamentPath = filamentsPathData(
            seed: seed,
            pappusCenter: pappusCenter,
            pappusRadius: pappusRadius,
            depthFactor: depthFactor,
            direction: direction,
            time: time,
            windBend: windBend
        )

        return """
          <g opacity="\(fmt01(baseSeedOpacity))">
            <path d="M \(fmt(anchor.x)) \(fmt(anchor.y)) L \(fmt(pappusCenter.x)) \(fmt(pappusCenter.y))" stroke="#D9BF73" stroke-opacity="\(fmt01(beakStrokeOpacity))" stroke-width="\(fmt(beakWidth))" stroke-linecap="round"/>
            <rect x="\(fmt(acheneX))" y="\(fmt(acheneY))" width="\(fmt(acheneLength))" height="\(fmt(acheneWidth))" rx="\(fmt(acheneWidth * 0.5))" ry="\(fmt(acheneWidth * 0.5))" fill="#D9BF73" fill-opacity="\(fmt01(acheneFillOpacity))" transform="rotate(\(fmt(acheneAngle, decimals: 2)) \(fmt(acheneCenter.x)) \(fmt(acheneCenter.y)))"/>
            <path d="\(filamentPath)" stroke="#F7F2E6" stroke-opacity="\(fmt01(filamentStrokeOpacity))" stroke-width="\(fmt(filamentWidth))" stroke-linecap="round" fill="none"/>
            <circle cx="\(fmt(pappusCenter.x))" cy="\(fmt(pappusCenter.y))" r="\(fmt(crownR))" fill="#F7F2E6" fill-opacity="\(fmt01(crownFillOpacity))"/>
          </g>
        """
    }

    private static func filamentsPathData(
        seed: DandelionSeed,
        pappusCenter: CGPoint,
        pappusRadius: CGFloat,
        depthFactor: CGFloat,
        direction: CGPoint,
        time: CGFloat,
        windBend: CGPoint
    ) -> String {
        let axisA = direction.perpendicular
        let axisB = direction * (0.25 + abs(seed.depth) * 0.75)

        var d = ""
        d.reserveCapacity(seed.filamentAngles.count * 50)

        for index in 0..<seed.filamentAngles.count {
            let angle = seed.filamentAngles[index]
            let phase = seed.filamentPhases[index]
            let lengthScale = seed.filamentLengths[index]

            let flutter = sin(time * 1.6 + phase) * 0.12
            let localAngle = angle + flutter
            let directionVector = (axisA * cos(localAngle) + axisB * sin(localAngle)).normalized

            let filamentLength = pappusRadius * lengthScale
            let endPoint = pappusCenter + directionVector * filamentLength
            let controlPoint = pappusCenter + directionVector * (filamentLength * 0.6) + windBend

            d.append("M \(fmt(pappusCenter.x)) \(fmt(pappusCenter.y)) ")
            d.append("Q \(fmt(controlPoint.x)) \(fmt(controlPoint.y)) \(fmt(endPoint.x)) \(fmt(endPoint.y)) ")
        }

        return d
    }
}

private struct DandelionSeed: Identifiable {
    let id: Int
    let projection: CGPoint
    let orientation: CGPoint
    let depth: CGFloat
    let baseAngle: CGFloat
    let beakLength: CGFloat
    let pappusRadius: CGFloat
    let filamentAngles: [CGFloat]
    let filamentPhases: [CGFloat]
    let filamentLengths: [CGFloat]
    let anchorInset: CGFloat
    let anchorJitter: CGPoint
    let flexibility: CGFloat
    let damping: CGFloat
    let mass: CGFloat
    let swayFrequency: CGFloat
    let swayPhase: CGFloat
    let detachmentDistance: CGFloat
    let detachmentPhase: CGFloat
    let flightDuration: CGFloat
    let flightLift: CGFloat
    let flightDrift: CGFloat
    let growthDelay: CGFloat
    var angle: CGFloat
    var angularVelocity: CGFloat

    static func make(
        index: Int,
        total: Int,
        filamentsPerSeed: Int,
        rng: inout SeededRandomNumberGenerator
    ) -> DandelionSeed {
        let goldenAngle = Double.pi * (3 - sqrt(5))
        let t = total == 1 ? 0.5 : Double(index) / Double(total - 1)
        let y = 1 - (t * 2)
        let radius = sqrt(max(0, 1 - y * y))
        let theta = goldenAngle * Double(index)
        let x = cos(theta) * radius
        let z = sin(theta) * radius

        let projection = CGPoint(x: CGFloat(x), y: CGFloat(y))
        let orientation = projection.normalized.fallback
        let depth = CGFloat(z)
        let baseAngle = atan2(orientation.y, orientation.x)

        let filamentCount = max(12, filamentsPerSeed + Int.random(in: -3...3, using: &rng))
        var filamentAngles: [CGFloat] = []
        var filamentPhases: [CGFloat] = []
        var filamentLengths: [CGFloat] = []
        filamentAngles.reserveCapacity(filamentCount)
        filamentPhases.reserveCapacity(filamentCount)
        filamentLengths.reserveCapacity(filamentCount)

        for i in 0..<filamentCount {
            let base = (CGFloat(i) / CGFloat(filamentCount)) * (2 * .pi)
            filamentAngles.append(base + random(in: -0.08...0.08, using: &rng))
            filamentPhases.append(random(in: 0...(.pi * 2), using: &rng))
            filamentLengths.append(random(in: 0.82...1.12, using: &rng))
        }

        return DandelionSeed(
            id: index,
            projection: projection,
            orientation: orientation,
            depth: depth,
            baseAngle: baseAngle,
            beakLength: random(in: 0.28...0.38, using: &rng),
            pappusRadius: random(in: 0.18...0.26, using: &rng),
            filamentAngles: filamentAngles,
            filamentPhases: filamentPhases,
            filamentLengths: filamentLengths,
            anchorInset: random(in: 0.02...0.08, using: &rng),
            anchorJitter: CGPoint(
                x: random(in: -0.02...0.02, using: &rng),
                y: random(in: -0.02...0.02, using: &rng)
            ),
            flexibility: random(in: 0.75...1.1, using: &rng),
            damping: random(in: 0.75...1.05, using: &rng),
            mass: random(in: 0.85...1.2, using: &rng),
            swayFrequency: random(in: 0.6...1.25, using: &rng),
            swayPhase: random(in: 0...(.pi * 2), using: &rng),
            detachmentDistance: random(in: 0.18...0.32, using: &rng),
            detachmentPhase: random(in: 0...(.pi * 2), using: &rng),
            flightDuration: random(in: 16.0...20.0, using: &rng),
            flightLift: random(in: 1.1...1.5, using: &rng),
            flightDrift: random(in: -0.35...0.35, using: &rng),
            growthDelay: random(in: 0...0.08, using: &rng),
            angle: 0,
            angularVelocity: 0
        )
    }
}

private struct DandelionWindField {
    func vector(at position: CGPoint, time: TimeInterval, strength: CGFloat) -> CGPoint {
        let t = CGFloat(time)
        let tFast = t * 1.35
        let x = position.x
        let y = position.y

        let slow = sin(tFast * 0.18 + x * 1.4) * 0.55
            + sin(tFast * 0.05 + y * 1.1) * 0.35
        let drift = sin(tFast * 0.42 + x * 2.1 + y * 1.6) * 0.25
        let swirl = cos(tFast * 0.26 + y * 1.8) * 0.18
        let windX = (slow + drift) * 0.22
        let windY = (sin(tFast * 0.12 + x * 1.7) * 0.18 + swirl) * 0.18

        return CGPoint(x: windX, y: windY) * strength
    }
}

private struct SeededRandomNumberGenerator: RandomNumberGenerator {
    private var state: UInt64

    init(seed: UInt64) {
        self.state = seed == 0 ? 0x1234_5678_9ABC_DEF0 : seed
    }

    mutating func next() -> UInt64 {
        state ^= state << 13
        state ^= state >> 7
        state ^= state << 17
        return state
    }
}

private func random(
    in range: ClosedRange<CGFloat>,
    using rng: inout SeededRandomNumberGenerator
) -> CGFloat {
    let value = Double.random(
        in: Double(range.lowerBound)...Double(range.upperBound),
        using: &rng
    )
    return CGFloat(value)
}

private extension CGPoint {
    static func +(lhs: CGPoint, rhs: CGPoint) -> CGPoint {
        CGPoint(x: lhs.x + rhs.x, y: lhs.y + rhs.y)
    }

    static func -(lhs: CGPoint, rhs: CGPoint) -> CGPoint {
        CGPoint(x: lhs.x - rhs.x, y: lhs.y - rhs.y)
    }

    static func *(lhs: CGPoint, rhs: CGFloat) -> CGPoint {
        CGPoint(x: lhs.x * rhs, y: lhs.y * rhs)
    }

    static func /(lhs: CGPoint, rhs: CGFloat) -> CGPoint {
        CGPoint(x: lhs.x / rhs, y: lhs.y / rhs)
    }

    var length: CGFloat {
        hypot(x, y)
    }

    var normalized: CGPoint {
        let len = length
        guard len > 0.0001 else { return .zero }
        return self / len
    }

    var fallback: CGPoint {
        if length > 0.0001 { return self }
        return CGPoint(x: 0, y: -1)
    }

    var perpendicular: CGPoint {
        CGPoint(x: -y, y: x)
    }

    func rotated(by angle: CGFloat) -> CGPoint {
        let cosAngle = cos(angle)
        let sinAngle = sin(angle)
        return CGPoint(
            x: x * cosAngle - y * sinAngle,
            y: x * sinAngle + y * cosAngle
        )
    }
}

private extension CGFloat {
    func clamped(_ minValue: CGFloat, _ maxValue: CGFloat) -> CGFloat {
        Swift.min(Swift.max(self, minValue), maxValue)
    }
}

do {
    let config = try parseArgs()

    if let outputPath = config.outputPath {
        let svg = DandelionIconGenerator.generate(config: config)
        let url = URL(fileURLWithPath: outputPath)
        try svg.write(to: url, atomically: true, encoding: .utf8)
    } else if config.pngOutputPath == nil {
        print(DandelionIconGenerator.generate(config: config))
    }

    if let pngOutputPath = config.pngOutputPath {
        let url = URL(fileURLWithPath: pngOutputPath)
        try DandelionIconGenerator.writePNG(config: config, to: url)
    }
} catch Exit.message(let message) {
    if message.contains("Usage:") {
        print(message)
        exit(EXIT_SUCCESS)
    }
    fputs("Error: \(message)\n", stderr)
    exit(EXIT_FAILURE)
} catch {
    fputs("Error: \(error)\n", stderr)
    exit(EXIT_FAILURE)
}
