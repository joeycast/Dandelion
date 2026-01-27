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
    var windStrength: CGFloat = 1.2
    var style: DandelionStyle = .procedural
    var detachedSeedTimes: [Int: TimeInterval] = [:]
    var seedRestoreStartTime: TimeInterval?
    var seedRestoreDuration: TimeInterval = 1.8
    var topOverflow: CGFloat = 0  // Extra space above for seeds to fly into
    var isAnimating: Bool = true  // Set to false for static display (saves CPU)
    private let staticRenderDate = Date(timeIntervalSinceReferenceDate: 0)

    @Environment(AppearanceManager.self) private var appearance
    @Environment(\.scenePhase) private var scenePhase
    @State private var driver: DandelionSimulationDriver

    init(
        seedCount: Int = 140,
        filamentsPerSeed: Int = 20,
        windStrength: CGFloat = 1.2,
        style: DandelionStyle = .procedural,
        detachedSeedTimes: [Int: TimeInterval] = [:],
        seedRestoreStartTime: TimeInterval? = nil,
        seedRestoreDuration: TimeInterval = 1.8,
        topOverflow: CGFloat = 0,
        isAnimating: Bool = true
    ) {
        let profile = DandelionStyleProfile(
            style: style,
            seedCount: seedCount,
            filamentsPerSeed: filamentsPerSeed,
            windStrength: windStrength,
            seedRestoreDuration: seedRestoreDuration
        )

        self.seedCount = profile.seedCount
        self.filamentsPerSeed = profile.filamentsPerSeed
        self.windStrength = profile.windStrength
        self.style = style
        self.detachedSeedTimes = detachedSeedTimes
        self.seedRestoreStartTime = seedRestoreStartTime
        self.seedRestoreDuration = profile.seedRestoreDuration
        self.topOverflow = topOverflow
        self.isAnimating = isAnimating
        _driver = State(initialValue: DandelionSimulationDriver(
            seedCount: profile.seedCount,
            filamentsPerSeed: profile.filamentsPerSeed
        ))
    }

    var body: some View {
        let theme = appearance.theme
        let isIdleWind = detachedSeedTimes.isEmpty && seedRestoreStartTime == nil
        let isTimelineActive = isAnimating && scenePhase == .active
        let idleMinimumInterval: TimeInterval? = (isTimelineActive && isIdleWind) ? (1.0 / 20.0) : nil
        TimelineView(.animation(minimumInterval: idleMinimumInterval, paused: !isTimelineActive)) { timeline in
            Canvas { context, size in
                if isTimelineActive {
                    driver.step(to: timeline.date, windStrength: windStrength)
                }
                DandelionRenderer.draw(
                    in: context,
                    size: size,
                    topOverflow: topOverflow,
                    time: isTimelineActive ? timeline.date.timeIntervalSinceReferenceDate : staticRenderDate.timeIntervalSinceReferenceDate,
                    simulation: driver.simulation,
                    windStrength: windStrength,
                    style: style,
                    theme: theme,
                    detachedSeedTimes: detachedSeedTimes,
                    seedRestoreStartTime: seedRestoreStartTime,
                    seedRestoreDuration: seedRestoreDuration,
                    isIdleWind: isIdleWind
                )
            }
        }
        .accessibilityHidden(true)
    }
}

private struct DandelionStyleProfile {
    let seedCount: Int
    let filamentsPerSeed: Int
    let windStrength: CGFloat
    let seedRestoreDuration: TimeInterval

    init(
        style: DandelionStyle,
        seedCount: Int,
        filamentsPerSeed: Int,
        windStrength: CGFloat,
        seedRestoreDuration: TimeInterval
    ) {
        switch style {
        case .procedural:
            self.seedCount = seedCount
            self.filamentsPerSeed = filamentsPerSeed
            self.windStrength = windStrength
            self.seedRestoreDuration = seedRestoreDuration
        case .watercolor:
            self.seedCount = min(seedCount, 90)
            self.filamentsPerSeed = max(10, filamentsPerSeed - 6)
            self.windStrength = windStrength * 0.6
            self.seedRestoreDuration = seedRestoreDuration * 1.2
        case .pencil:
            self.seedCount = min(seedCount, 110)
            self.filamentsPerSeed = max(12, filamentsPerSeed - 4)
            self.windStrength = windStrength * 0.8
            self.seedRestoreDuration = seedRestoreDuration
        }
    }
}

private enum DandelionRenderer {
    static func draw(
        in context: GraphicsContext,
        size: CGSize,
        topOverflow: CGFloat = 0,
        time: TimeInterval,
        simulation: DandelionSimulation,
        windStrength: CGFloat,
        style: DandelionStyle,
        theme: DandelionTheme,
        detachedSeedTimes: [Int: TimeInterval],
        seedRestoreStartTime: TimeInterval?,
        seedRestoreDuration: TimeInterval,
        isIdleWind: Bool
    ) {
        var context = context
        let windField = DandelionWindField()
        let t = CGFloat(time)
        let restoreProgress = restorationProgress(
            time: time,
            startTime: seedRestoreStartTime,
            duration: seedRestoreDuration
        )
        let effectiveDetachedSeedTimes = restoreProgress >= 1 ? [:] : detachedSeedTimes
        let shouldSkipFadedDetachedSeeds = restoreProgress <= 0.0001
        let flightFadeCutoff: TimeInterval = 4.0

        // Calculate visible height (total minus overflow) for positioning the dandelion
        let visibleHeight = size.height - topOverflow
        let minSide = min(size.width, visibleHeight)
        let headRadius = minSide * 0.2
        // Position dandelion relative to visible area, offset down by topOverflow
        let stemBase = CGPoint(x: size.width * 0.5, y: topOverflow + visibleHeight * 0.92)
        let restHeadCenter = CGPoint(x: size.width * 0.5, y: topOverflow + visibleHeight * 0.38)
        let stemVector = restHeadCenter - stemBase
        let stemAngle = simulation.stemAngle
        let stemBob = sin(t * 0.35 + 1.1) * headRadius * 0.03
        let headCenter = stemBase + stemVector.rotated(by: stemAngle) + CGPoint(x: 0, y: stemBob)

        drawStem(
            in: &context,
            base: stemBase,
            headCenter: headCenter,
            headRadius: headRadius,
            style: style,
            theme: theme,
            time: t
        )

        let seeds = simulation.seeds

        // Calculate visible size for flight animations (excludes overflow area)
        let visibleSize = CGSize(width: size.width, height: visibleHeight)

        var detachedIndices: [Int] = []
        if !effectiveDetachedSeedTimes.isEmpty {
            detachedIndices.reserveCapacity(effectiveDetachedSeedTimes.count)
        }

        for index in simulation.backSeedIndices {
            let seed = seeds[index]
            if let detachedStart = effectiveDetachedSeedTimes[seed.id] {
                if shouldSkipFadedDetachedSeeds && (time - detachedStart) > flightFadeCutoff {
                    continue
                }
                detachedIndices.append(index)
                continue
            }
            drawSeed(
                seed,
                in: &context,
                size: size,
                visibleSize: visibleSize,
                headCenter: headCenter,
                headRadius: headRadius,
                time: t,
                globalAngle: stemAngle * 0.4,
                windStrength: windStrength,
                windField: windField,
                style: style,
                theme: theme,
                detachment: detachmentState(for: seed, time: time, detachedSeedTimes: effectiveDetachedSeedTimes),
                restoreProgress: restoreProgress,
                restoreDuration: CGFloat(seedRestoreDuration),
                isIdleWind: isIdleWind
            )
        }

        drawCore(in: &context, center: headCenter, radius: headRadius, style: style, theme: theme, time: t)

        for index in simulation.frontSeedIndices {
            let seed = seeds[index]
            if let detachedStart = effectiveDetachedSeedTimes[seed.id] {
                if shouldSkipFadedDetachedSeeds && (time - detachedStart) > flightFadeCutoff {
                    continue
                }
                detachedIndices.append(index)
                continue
            }
            drawSeed(
                seed,
                in: &context,
                size: size,
                visibleSize: visibleSize,
                headCenter: headCenter,
                headRadius: headRadius,
                time: t,
                globalAngle: stemAngle * 0.4,
                windStrength: windStrength,
                windField: windField,
                style: style,
                theme: theme,
                detachment: detachmentState(for: seed, time: time, detachedSeedTimes: effectiveDetachedSeedTimes),
                restoreProgress: restoreProgress,
                restoreDuration: CGFloat(seedRestoreDuration),
                isIdleWind: isIdleWind
            )
        }

        for index in detachedIndices {
            let seed = seeds[index]
            drawSeed(
                seed,
                in: &context,
                size: size,
                visibleSize: visibleSize,
                headCenter: headCenter,
                headRadius: headRadius,
                time: t,
                globalAngle: stemAngle * 0.4,
                windStrength: windStrength,
                windField: windField,
                style: style,
                theme: theme,
                detachment: detachmentState(for: seed, time: time, detachedSeedTimes: effectiveDetachedSeedTimes),
                restoreProgress: restoreProgress,
                restoreDuration: CGFloat(seedRestoreDuration),
                isIdleWind: isIdleWind
            )
        }
    }

    private static func restorationProgress(
        time: TimeInterval,
        startTime: TimeInterval?,
        duration: TimeInterval
    ) -> CGFloat {
        guard let startTime else { return 0 }
        let elapsed = max(0, time - startTime)
        return min(1, elapsed / max(duration, 0.01))
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
        let progress = min(1.0, elapsed / 2.4)
        return DetachmentState(progress: CGFloat(progress), elapsed: CGFloat(elapsed))
    }

    private static func drawStem(
        in context: inout GraphicsContext,
        base: CGPoint,
        headCenter: CGPoint,
        headRadius: CGFloat,
        style: DandelionStyle,
        theme: DandelionTheme,
        time: CGFloat
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
            .init(color: theme.accent.opacity(0.6), location: 0),
            .init(color: theme.primary.opacity(0.8), location: 1)
        ])

        let strokeStyle: StrokeStyle
        switch style {
        case .procedural, .watercolor:
            strokeStyle = StrokeStyle(lineWidth: stemWidth, lineCap: .round)
        case .pencil:
            strokeStyle = StrokeStyle(lineWidth: stemWidth * 0.9, lineCap: .round, dash: [3, 2])
        }

        context.stroke(
            stemPath,
            with: .linearGradient(
                stemGradient,
                startPoint: base,
                endPoint: headCenter
            ),
            style: strokeStyle
        )

        if style == .watercolor {
            let pulse = (sin(time * 0.5) + 1) * 0.5
            context.stroke(
                stemPath,
                with: .color(theme.primary.opacity(0.2 + pulse * 0.15)),
                style: StrokeStyle(lineWidth: stemWidth * 1.4, lineCap: .round)
            )
        }
    }

    private static func drawCore(
        in context: inout GraphicsContext,
        center: CGPoint,
        radius: CGFloat,
        style: DandelionStyle,
        theme: DandelionTheme,
        time: CGFloat
    ) {
        let coreRect = CGRect(
            x: center.x - radius * 0.58,
            y: center.y - radius * 0.58,
            width: radius * 1.16,
            height: radius * 1.16
        )
        let corePath = Path(ellipseIn: coreRect)
        let coreGradient = Gradient(stops: [
            .init(color: theme.accent.opacity(style == .pencil ? 0.6 : 0.95), location: 0),
            .init(color: theme.primary.opacity(0.75), location: 0.55),
            .init(color: theme.subtle.opacity(0.9), location: 1)
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

        if style == .watercolor {
            let pulse = (sin(time * 0.6) + 1) * 0.5
            context.fill(
                corePath,
                with: .color(theme.primary.opacity(0.18 + pulse * 0.2))
            )
        }
    }

    private static func drawSeed(
        _ seed: DandelionSeed,
        in context: inout GraphicsContext,
        size: CGSize,
        visibleSize: CGSize,
        headCenter: CGPoint,
        headRadius: CGFloat,
        time: CGFloat,
        globalAngle: CGFloat,
        windStrength: CGFloat,
        windField: DandelionWindField,
        style: DandelionStyle,
        theme: DandelionTheme,
        detachment: DetachmentState,
        restoreProgress: CGFloat,
        restoreDuration: CGFloat,
        isIdleWind: Bool
    ) {
        let depthFactor = (seed.depth + 1) * 0.5
        let depthScale = 0.78 + depthFactor * 0.32
        let baseSeedOpacity = 0.35 + depthFactor * 0.65

        let baseDirection = seed.orientation.rotated(by: globalAngle)
        let localSway = sin(time * seed.swayFrequency + seed.swayPhase) * 0.07
        let deflection = seed.angle + localSway
        let direction = baseDirection.rotated(by: deflection)

        let baseAnchor = headCenter
            + seed.projection * (headRadius * (1 - seed.anchorInset))
            + seed.anchorJitter * headRadius

        // Calculate per-seed growth progress for regrowth animation
        // Each seed has a staggered start time based on its growthDelay
        let seedGrowthProgress: CGFloat
        if restoreProgress > 0 && detachment.progress > 0 {
            // Convert overall restore progress to elapsed time equivalent
            let restoreElapsed = restoreProgress * restoreDuration
            // Scale the seed's normalized delay to actual time (tiny jitter)
            let scaledDelay = seed.growthDelay * restoreDuration
            // Subtract this seed's delay to get its individual progress
            let seedElapsed = max(0, restoreElapsed - scaledDelay)
            // Each seed takes 90% of total duration to fully grow (all grow together)
            let perSeedDuration = restoreDuration * 0.9
            seedGrowthProgress = min(1, seedElapsed / perSeedDuration)
        } else {
            seedGrowthProgress = 0
        }

        // Growth factors with easing
        // Beak grows first (0% to 100% in first half of seed's growth)
        let beakGrowth = seedGrowthProgress > 0 ? easeOutCubic(min(1, seedGrowthProgress * 2)) : 1.0
        // Pappus blooms second with spring overshoot (starts at 30%, finishes with overshoot)
        let pappusGrowthRaw = max(0, (seedGrowthProgress - 0.3) / 0.7)
        let pappusGrowth = seedGrowthProgress > 0 ? easeOutBack(min(1, pappusGrowthRaw)) : 1.0

        // During regrowth, scale down from detached state
        let isRegrowing = restoreProgress > 0 && detachment.progress > 0
        let growthScale = isRegrowing ? beakGrowth : 1.0
        let pappusScale = isRegrowing ? pappusGrowth : 1.0

        // Apply growth scaling to beak and pappus
        let beakLength = headRadius * seed.beakLength * depthScale * growthScale
        let pappusRadius = headRadius * seed.pappusRadius * depthScale * pappusScale

        // Opacity fades in during regrowth
        let growthOpacity = isRegrowing ? easeOutCubic(min(1, seedGrowthProgress * 3)) : 1.0

        // Fade out after 3 seconds of flight (matching the text animation)
        let flightFadeStart: CGFloat = 3.0
        let flightFadeDuration: CGFloat = 1.0
        let flightFadeOpacity: CGFloat
        if detachment.elapsed > flightFadeStart && !isRegrowing {
            let fadeProgress = min(1.0, (detachment.elapsed - flightFadeStart) / flightFadeDuration)
            flightFadeOpacity = 1.0 - easeInCubic(fadeProgress)
        } else {
            flightFadeOpacity = 1.0
        }

        let seedOpacity = baseSeedOpacity * growthOpacity * flightFadeOpacity

        // Skip drawing if seed hasn't started growing yet during regrowth
        if isRegrowing && seedGrowthProgress <= 0 {
            return
        }

        // Skip drawing if fully faded out
        if flightFadeOpacity <= 0 {
            return
        }

        let windVector = windField.vector(
            at: seed.projection,
            time: TimeInterval(time),
            strength: windStrength
        )
        let windBend = windVector * (headRadius * 0.12)
        let detachmentEase = detachment.progress * detachment.progress * (3 - 2 * detachment.progress)
        let flightProgress = min(1, detachment.elapsed / seed.flightDuration)
        let flightInverse = 1 - flightProgress
        let flightEase = 1 - (flightInverse * flightInverse * flightInverse)
        // Use visibleSize for flight calculations to maintain consistent animation speed
        let offscreenPadding = visibleSize.height * 0.15
        let flightOffset = CGPoint(
            x: visibleSize.width * seed.flightDrift * flightEase,
            y: -(visibleSize.height * seed.flightLift + offscreenPadding) * flightEase
        )
        let windOffset = windVector * (visibleSize.height * 0.11 * flightProgress)
        let flutterOffset = direction.perpendicular * (
            sin(time * 1.2 + seed.detachmentPhase) * visibleSize.width * 0.022 * flightProgress
        )

        // During regrowth, seeds grow from their anchor point (no detachment offset)
        // Otherwise, apply full detachment offset when flying away
        let detachmentScale = isRegrowing ? 0.0 : 1.0
        let detachmentOffset = (direction * (headRadius * seed.detachmentDistance * detachmentEase)
            + direction.perpendicular * (sin(time * 1.1 + seed.detachmentPhase) * headRadius * 0.03 * detachmentEase)
            + flightOffset
            + windOffset
            + flutterOffset) * detachmentScale
        let anchor = baseAnchor + detachmentOffset
        let pappusCenter = anchor + direction * beakLength

        context.drawLayer { layer in
            layer.opacity = seedOpacity

            // Only draw beak if it has grown enough
            if beakLength > 0.1 {
                let beakPath = Path { path in
                    path.move(to: anchor)
                    path.addLine(to: pappusCenter)
                }
                layer.stroke(
                    beakPath,
                    with: .color(theme.accent.opacity(style == .pencil ? 0.4 : 0.55)),
                    style: StrokeStyle(
                        lineWidth: max(0.6, headRadius * 0.025),
                        lineCap: .round,
                        dash: style == .pencil ? [2, 2] : []
                    )
                )

                let acheneLength = headRadius * 0.14 * depthScale * growthScale
                let acheneWidth = headRadius * 0.055 * depthScale * growthScale
                let acheneCenter = anchor + direction * (headRadius * 0.04 * growthScale)
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
                    with: .color(theme.accent.opacity(style == .pencil ? 0.6 : 0.75))
                )
            }

            // Only draw pappus if it has started blooming
            if pappusRadius > 0.1 {
                let axisA = direction.perpendicular
                let axisB = direction * (0.25 + abs(seed.depth) * 0.75)
                let filamentColor = theme.pappus.opacity(0.55 + depthFactor * 0.35)
                let filamentWidth = max(0.4, headRadius * (style == .watercolor ? 0.009 : 0.012))

                var filaments = Path()
                for index in 0..<seed.filamentAngles.count {
                    let angle = seed.filamentAngles[index]
                    let phase = seed.filamentPhases[index]
                    let lengthScale = seed.filamentLengths[index]

                    let flutter = sin(time * 1.6 + phase) * 0.12
                    let localAngle = angle + flutter
                    let directionVector = (axisA * cos(localAngle) + axisB * sin(localAngle)).normalized
                    let filamentLength = pappusRadius * lengthScale
                    let endPoint = pappusCenter + directionVector * filamentLength
                    let controlPoint = pappusCenter
                        + directionVector * (filamentLength * 0.6)
                        + windBend * pappusScale

                    filaments.move(to: pappusCenter)
                    filaments.addQuadCurve(to: endPoint, control: controlPoint)
                }

                layer.stroke(
                    filaments,
                    with: .color(filamentColor),
                    style: StrokeStyle(
                        lineWidth: filamentWidth,
                        lineCap: .round,
                        dash: style == .pencil ? [1.5, 2.5] : []
                    )
                )

                let crownSize = pappusRadius * 0.16
                let crownRect = CGRect(
                    x: pappusCenter.x - crownSize * 0.5,
                    y: pappusCenter.y - crownSize * 0.5,
                    width: crownSize,
                    height: crownSize
                )
                let crownPath = Path(ellipseIn: crownRect)
                layer.fill(crownPath, with: .color(theme.pappus.opacity(style == .watercolor ? 0.7 : 0.85)))
            }
        }
    }
}

private struct DetachmentState {
    let progress: CGFloat
    let elapsed: CGFloat
}

private struct DandelionSimulation {
    var seeds: [DandelionSeed]
    let backSeedIndices: [Int]
    let frontSeedIndices: [Int]
    var stemAngle: CGFloat = 0
    private var stemVelocity: CGFloat = 0
    private var lastUpdate: TimeInterval?
    private let windField = DandelionWindField()

    init(seedCount: Int, filamentsPerSeed: Int) {
        var rng = SeededRandomNumberGenerator(seed: 0xDA11_F0AD)
        var seeds: [DandelionSeed] = []
        seeds.reserveCapacity(seedCount)
        var backSeedIndices: [Int] = []
        var frontSeedIndices: [Int] = []
        backSeedIndices.reserveCapacity(seedCount / 2)
        frontSeedIndices.reserveCapacity(seedCount / 2)
        for index in 0..<seedCount {
            let seed = DandelionSeed.make(
                index: index,
                total: seedCount,
                filamentsPerSeed: filamentsPerSeed,
                rng: &rng
            )
            seeds.append(seed)
            if seed.depth < 0 {
                backSeedIndices.append(index)
            } else {
                frontSeedIndices.append(index)
            }
        }
        self.seeds = seeds
        self.backSeedIndices = backSeedIndices
        self.frontSeedIndices = frontSeedIndices
    }

    mutating func step(to date: Date, windStrength: CGFloat) {
        let time = date.timeIntervalSinceReferenceDate
        guard let lastUpdate else {
            self.lastUpdate = time
            return
        }
        guard time > lastUpdate else {
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

private final class DandelionSimulationDriver {
    private(set) var simulation: DandelionSimulation
    private var lastStepTime: TimeInterval?

    init(seedCount: Int, filamentsPerSeed: Int) {
        self.simulation = DandelionSimulation(
            seedCount: seedCount,
            filamentsPerSeed: filamentsPerSeed
        )
    }

    func step(to date: Date, windStrength: CGFloat) {
        let currentTime = date.timeIntervalSinceReferenceDate
        if let lastStepTime, currentTime - lastStepTime < (1.0 / 60.0) {
            return
        }
        lastStepTime = currentTime
        simulation.step(to: date, windStrength: windStrength)
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
    let growthDelay: CGFloat  // Staggered delay for regrowth animation (0 to ~0.8)
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
            let angle = base + random(in: -0.08...0.08, using: &rng)
            filamentAngles.append(angle)
            filamentPhases.append(random(in: 0...(.pi * 2), using: &rng))
            let lengthScale = random(in: 0.82...1.12, using: &rng)
            filamentLengths.append(lengthScale)
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
            flightDuration: random(in: 16.0...20.0, using: &rng), // Tweak this to adjust the amount of time the seeds spend drifting away
            flightLift: random(in: 1.1...1.5, using: &rng),
            flightDrift: random(in: -0.35...0.35, using: &rng),
            // Growth delay: all seeds grow together with slight random jitter for organic feel
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

private func wrappedAngle(_ angle: CGFloat) -> CGFloat {
    var value = angle
    while value > .pi { value -= .pi * 2 }
    while value < -.pi { value += .pi * 2 }
    return value
}

// MARK: - Easing Functions for Animations

private func easeInCubic(_ t: CGFloat) -> CGFloat {
    return t * t * t
}

private func easeOutCubic(_ t: CGFloat) -> CGFloat {
    let t1 = t - 1
    return t1 * t1 * t1 + 1
}

private func easeOutBack(_ t: CGFloat) -> CGFloat {
    // Slight overshoot for organic spring feel
    let c1: CGFloat = 1.70158
    let c3 = c1 + 1
    let t1 = t - 1
    return 1 + c3 * t1 * t1 * t1 + c1 * t1 * t1
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
        AppearanceManager().theme.background
            .ignoresSafeArea()

        DandelionBloomView()
            .frame(width: 240, height: 260)
    }
    .environment(AppearanceManager())
}
