//
//  DandelionBloomView.swift
//  Dandelion
//
//  Procedural, softly animated dandelion head
//

import SwiftUI

struct DandelionBloomView: View {
    var seedCount: Int = 140
    var filamentsPerSeed: Int = 20
    var windStrength: CGFloat = 0.8
    var detachedSeedTimes: [Int: TimeInterval] = [:]

    @State private var simulation: DandelionSimulation

    init(
        seedCount: Int = 140,
        filamentsPerSeed: Int = 20,
        windStrength: CGFloat = 0.8,
        detachedSeedTimes: [Int: TimeInterval] = [:]
    ) {
        self.seedCount = seedCount
        self.filamentsPerSeed = filamentsPerSeed
        self.windStrength = windStrength
        self.detachedSeedTimes = detachedSeedTimes
        _simulation = State(initialValue: DandelionSimulation(
            seedCount: seedCount,
            filamentsPerSeed: filamentsPerSeed
        ))
    }

    var body: some View {
        TimelineView(.animation) { timeline in
            Canvas { context, size in
                DandelionRenderer.draw(
                    in: context,
                    size: size,
                    time: timeline.date.timeIntervalSinceReferenceDate,
                    simulation: simulation,
                    windStrength: windStrength,
                    detachedSeedTimes: detachedSeedTimes
                )
            }
            .onChange(of: timeline.date) { _, newDate in
                simulation.step(to: newDate, windStrength: windStrength)
            }
        }
        .accessibilityHidden(true)
    }
}

private enum DandelionRenderer {
    static func draw(
        in context: GraphicsContext,
        size: CGSize,
        time: TimeInterval,
        simulation: DandelionSimulation,
        windStrength: CGFloat,
        detachedSeedTimes: [Int: TimeInterval]
    ) {
        var context = context
        let windField = DandelionWindField()
        let t = CGFloat(time)

        let minSide = min(size.width, size.height)
        let headRadius = minSide * 0.2
        let stemBase = CGPoint(x: size.width * 0.5, y: size.height * 0.92)
        let restHeadCenter = CGPoint(x: size.width * 0.5, y: size.height * 0.34)
        let stemVector = restHeadCenter - stemBase
        let stemAngle = simulation.stemAngle
        let stemBob = sin(t * 0.35 + 1.1) * headRadius * 0.03
        let headCenter = stemBase + stemVector.rotated(by: stemAngle) + CGPoint(x: 0, y: stemBob)

        drawStem(in: &context, base: stemBase, headCenter: headCenter, headRadius: headRadius)

        let seeds = simulation.seeds
        let attachedSeeds = seeds.filter { detachedSeedTimes[$0.id] == nil }
        let detachedSeeds = seeds.filter { detachedSeedTimes[$0.id] != nil }
        let backSeeds = attachedSeeds.filter { $0.depth < 0 }
        let frontSeeds = attachedSeeds.filter { $0.depth >= 0 }

        for seed in backSeeds {
            drawSeed(
                seed,
                in: &context,
                size: size,
                headCenter: headCenter,
                headRadius: headRadius,
                time: t,
                globalAngle: stemAngle * 0.4,
                windStrength: windStrength,
                windField: windField,
                detachment: detachmentState(for: seed, time: time, detachedSeedTimes: detachedSeedTimes)
            )
        }

        drawCore(in: &context, center: headCenter, radius: headRadius)

        for seed in frontSeeds {
            drawSeed(
                seed,
                in: &context,
                size: size,
                headCenter: headCenter,
                headRadius: headRadius,
                time: t,
                globalAngle: stemAngle * 0.4,
                windStrength: windStrength,
                windField: windField,
                detachment: detachmentState(for: seed, time: time, detachedSeedTimes: detachedSeedTimes)
            )
        }

        for seed in detachedSeeds {
            drawSeed(
                seed,
                in: &context,
                size: size,
                headCenter: headCenter,
                headRadius: headRadius,
                time: t,
                globalAngle: stemAngle * 0.4,
                windStrength: windStrength,
                windField: windField,
                detachment: detachmentState(for: seed, time: time, detachedSeedTimes: detachedSeedTimes)
            )
        }
    }

    private static func detachmentState(
        for seed: DandelionSeed,
        time: TimeInterval,
        detachedSeedTimes: [Int: TimeInterval]
    ) -> DetachmentState {
        guard let startTime = detachedSeedTimes[seed.id] else {
            return DetachmentState(progress: 0, elapsed: 0)
        }
        let elapsed = max(0, time - startTime)
        let progress = min(1.0, elapsed / 1.0)
        return DetachmentState(progress: CGFloat(progress), elapsed: CGFloat(elapsed))
    }

    private static func drawStem(
        in context: inout GraphicsContext,
        base: CGPoint,
        headCenter: CGPoint,
        headRadius: CGFloat
    ) {
        let stemWidth = max(1.2, headRadius * 0.08)
        let stemVector = headCenter - base
        let controlOffset = stemVector.perpendicular.normalized * (stemVector.length * 0.18)

        var stemPath = Path()
        stemPath.move(to: base)
        stemPath.addQuadCurve(
            to: headCenter,
            control: base + stemVector * 0.5 + controlOffset
        )

        let stemGradient = Gradient(stops: [
            .init(color: Color(red: 0.64, green: 0.74, blue: 0.36), location: 0),
            .init(color: Color(red: 0.76, green: 0.83, blue: 0.42), location: 1)
        ])

        context.stroke(
            stemPath,
            with: .linearGradient(
                stemGradient,
                startPoint: base,
                endPoint: headCenter
            ),
            style: StrokeStyle(lineWidth: stemWidth, lineCap: .round)
        )
    }

    private static func drawCore(
        in context: inout GraphicsContext,
        center: CGPoint,
        radius: CGFloat
    ) {
        let coreRect = CGRect(
            x: center.x - radius * 0.58,
            y: center.y - radius * 0.58,
            width: radius * 1.16,
            height: radius * 1.16
        )
        let corePath = Path(ellipseIn: coreRect)
        let coreGradient = Gradient(stops: [
            .init(color: Color.dandelionAccent.opacity(0.95), location: 0),
            .init(color: Color.dandelionPrimary.opacity(0.75), location: 0.55),
            .init(color: Color.dandelionSubtle.opacity(0.9), location: 1)
        ])

        context.fill(
            corePath,
            with: .radialGradient(
                coreGradient,
                center: center,
                startRadius: 1,
                endRadius: radius * 0.9
            )
        )
    }

    private static func drawSeed(
        _ seed: DandelionSeed,
        in context: inout GraphicsContext,
        size: CGSize,
        headCenter: CGPoint,
        headRadius: CGFloat,
        time: CGFloat,
        globalAngle: CGFloat,
        windStrength: CGFloat,
        windField: DandelionWindField,
        detachment: DetachmentState
    ) {
        let depthFactor = (seed.depth + 1) * 0.5
        let depthScale = 0.78 + depthFactor * 0.32
        let seedOpacity = 0.35 + depthFactor * 0.65

        let baseDirection = seed.orientation.rotated(by: globalAngle)
        let localSway = sin(time * seed.swayFrequency + seed.swayPhase) * 0.04
        let deflection = seed.angle + localSway
        let direction = baseDirection.rotated(by: deflection)

        let baseAnchor = headCenter
            + seed.projection * (headRadius * (1 - seed.anchorInset))
            + seed.anchorJitter * headRadius

        let beakLength = headRadius * seed.beakLength * depthScale
        let pappusRadius = headRadius * seed.pappusRadius * depthScale

        let windVector = windField.vector(
            at: seed.projection,
            time: TimeInterval(time),
            strength: windStrength
        )
        let windBend = windVector * (headRadius * 0.08)
        let detachmentEase = detachment.progress * detachment.progress * (3 - 2 * detachment.progress)
        let flightProgress = min(1, detachment.elapsed / seed.flightDuration)
        let flightInverse = 1 - flightProgress
        let flightEase = 1 - (flightInverse * flightInverse * flightInverse)
        let offscreenPadding = size.height * 0.15
        let flightOffset = CGPoint(
            x: size.width * seed.flightDrift * flightEase,
            y: -(size.height * seed.flightLift + offscreenPadding) * flightEase
        )
        let windOffset = windVector * (size.height * 0.08 * flightProgress)
        let flutterOffset = direction.perpendicular * (
            sin(time * 1.2 + seed.detachmentPhase) * size.width * 0.015 * flightProgress
        )
        let detachmentOffset = direction * (headRadius * seed.detachmentDistance * detachmentEase)
            + direction.perpendicular * (sin(time * 1.1 + seed.detachmentPhase) * headRadius * 0.02 * detachmentEase)
            + flightOffset
            + windOffset
            + flutterOffset
        let anchor = baseAnchor + detachmentOffset
        let pappusCenter = anchor + direction * beakLength

        context.drawLayer { layer in
            layer.opacity = seedOpacity

            let beakPath = Path { path in
                path.move(to: anchor)
                path.addLine(to: pappusCenter)
            }
            layer.stroke(
                beakPath,
                with: .color(Color.dandelionAccent.opacity(0.55)),
                style: StrokeStyle(lineWidth: max(0.6, headRadius * 0.025), lineCap: .round)
            )

            let acheneLength = headRadius * 0.14 * depthScale
            let acheneWidth = headRadius * 0.055 * depthScale
            let acheneCenter = anchor + direction * (headRadius * 0.04)
            let achenePath = Path(
                roundedRect: CGRect(
                    x: -acheneLength * 0.5,
                    y: -acheneWidth * 0.5,
                    width: acheneLength,
                    height: acheneWidth
                ),
                cornerRadius: acheneWidth * 0.5
            )
            let acheneAngle = atan2(direction.y, direction.x)
            let acheneTransform = CGAffineTransform(translationX: acheneCenter.x, y: acheneCenter.y)
                .rotated(by: acheneAngle)
            layer.fill(
                achenePath.applying(acheneTransform),
                with: .color(Color.dandelionAccent.opacity(0.75))
            )

            let axisA = direction.perpendicular
            let axisB = direction * (0.25 + abs(seed.depth) * 0.75)
            let filamentColor = Color.dandelionPappus.opacity(0.65 + depthFactor * 0.3)
            let filamentWidth = max(0.4, headRadius * 0.012)

            var filaments = Path()
            for index in 0..<seed.filamentAngles.count {
                let angle = seed.filamentAngles[index]
                let phase = seed.filamentPhases[index]
                let lengthScale = seed.filamentLengths[index]

                let flutter = sin(time * 1.6 + phase) * 0.08
                let localAngle = angle + flutter
                let directionVector = (axisA * cos(localAngle) + axisB * sin(localAngle)).normalized
                let filamentLength = pappusRadius * lengthScale
                let endPoint = pappusCenter + directionVector * filamentLength
                let controlPoint = pappusCenter
                    + directionVector * (filamentLength * 0.6)
                    + windBend

                filaments.move(to: pappusCenter)
                filaments.addQuadCurve(to: endPoint, control: controlPoint)
            }

            layer.stroke(
                filaments,
                with: .color(filamentColor),
                style: StrokeStyle(lineWidth: filamentWidth, lineCap: .round)
            )

            let crownSize = pappusRadius * 0.16
            let crownRect = CGRect(
                x: pappusCenter.x - crownSize * 0.5,
                y: pappusCenter.y - crownSize * 0.5,
                width: crownSize,
                height: crownSize
            )
            let crownPath = Path(ellipseIn: crownRect)
            layer.fill(crownPath, with: .color(Color.dandelionPappus.opacity(0.85)))
        }
    }
}

private struct DetachmentState {
    let progress: CGFloat
    let elapsed: CGFloat
}

private struct DandelionSimulation {
    var seeds: [DandelionSeed]
    var stemAngle: CGFloat = 0
    private var stemVelocity: CGFloat = 0
    private var lastUpdate: TimeInterval?
    private let windField = DandelionWindField()

    init(seedCount: Int, filamentsPerSeed: Int) {
        var rng = SeededRandomNumberGenerator(seed: 0xDA11_F0AD)
        var seeds: [DandelionSeed] = []
        seeds.reserveCapacity(seedCount)
        for index in 0..<seedCount {
            seeds.append(
                DandelionSeed.make(
                    index: index,
                    total: seedCount,
                    filamentsPerSeed: filamentsPerSeed,
                    rng: &rng
                )
            )
        }
        self.seeds = seeds
    }

    mutating func step(to date: Date, windStrength: CGFloat) {
        let time = date.timeIntervalSinceReferenceDate
        guard let lastUpdate else {
            self.lastUpdate = time
            return
        }

        let dt = min(max(time - lastUpdate, 0), 1.0 / 30.0)
        self.lastUpdate = time

        let stemWind = windField.vector(at: .zero, time: time, strength: windStrength)
        let stemTarget = stemWind.x * 0.45
        let stemStiffness: CGFloat = 6.5
        let stemDamping: CGFloat = 3.4
        let stemAcceleration = (stemTarget - stemAngle) * stemStiffness - stemVelocity * stemDamping
        stemVelocity += stemAcceleration * CGFloat(dt)
        stemAngle += stemVelocity * CGFloat(dt)
        stemAngle = stemAngle.clamped(-0.26, 0.26)

        for index in seeds.indices {
            var seed = seeds[index]
            let wind = windField.vector(
                at: seed.projection,
                time: time,
                strength: windStrength * (0.65 + seed.flexibility * 0.35)
            )
            let desiredDirection = (seed.orientation + wind).normalized
            let desiredAngle = atan2(desiredDirection.y, desiredDirection.x)
            let targetOffset = wrappedAngle(desiredAngle - seed.baseAngle) * (0.7 * seed.flexibility)

            let stiffness: CGFloat = 18.0 * seed.flexibility
            let damping: CGFloat = 5.2 * seed.damping
            let acceleration = (targetOffset - seed.angle) * stiffness - seed.angularVelocity * damping
            seed.angularVelocity += (acceleration / seed.mass) * CGFloat(dt)
            seed.angle += seed.angularVelocity * CGFloat(dt)
            seed.angle = seed.angle.clamped(-0.45, 0.45)

            seeds[index] = seed
        }
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
            flightDuration: random(in: 5.0...7.2, using: &rng),
            flightLift: random(in: 1.1...1.5, using: &rng),
            flightDrift: random(in: -0.35...0.35, using: &rng),
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

private func wrappedAngle(_ angle: CGFloat) -> CGFloat {
    var value = angle
    while value > .pi { value -= .pi * 2 }
    while value < -.pi { value += .pi * 2 }
    return value
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

#Preview {
    ZStack {
        Color.dandelionBackground
            .ignoresSafeArea()

        DandelionBloomView()
            .frame(width: 240, height: 260)
    }
}
