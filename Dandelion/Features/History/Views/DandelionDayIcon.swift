//
//  DandelionDayIcon.swift
//  Dandelion
//
//  Small dandelion icon for the release history calendar
//

import SwiftUI

struct DandelionDayIcon: View {
    let isFullBloom: Bool
    let size: CGFloat
    @Environment(AppearanceManager.self) private var appearance

    var body: some View {
        Canvas { context, canvasSize in
            let theme = appearance.theme
            let center = CGPoint(x: canvasSize.width / 2, y: canvasSize.height * 0.35)

            if isFullBloom {
                let stemBase = CGPoint(x: canvasSize.width / 2, y: canvasSize.height * 0.95)
                // Draw stem
                drawStem(in: &context, from: stemBase, to: center, size: canvasSize, theme: theme)
                // Draw full dandelion bloom
                drawBloom(in: &context, center: center, size: canvasSize, theme: theme)
            } else {
                // Draw a simple dot for empty/future days
                drawEmptyDayDot(in: &context, center: center, size: canvasSize, theme: theme)
            }
        }
        .frame(width: size, height: size)
    }

    private func drawStem(
        in context: inout GraphicsContext,
        from base: CGPoint,
        to top: CGPoint,
        size: CGSize,
        theme: DandelionTheme
    ) {
        var path = Path()
        path.move(to: base)
        path.addLine(to: top)

        context.stroke(
            path,
            with: .color(theme.accent.opacity(0.6)),
            style: StrokeStyle(lineWidth: size.width * 0.04, lineCap: .round)
        )
    }

    private func drawBloom(
        in context: inout GraphicsContext,
        center: CGPoint,
        size: CGSize,
        theme: DandelionTheme
    ) {
        let bloomRadius = size.width * 0.32
        let seedCount = 8

        // Draw radiating seed lines
        for i in 0..<seedCount {
            let angle = (CGFloat(i) / CGFloat(seedCount)) * .pi * 2
            let endPoint = CGPoint(
                x: center.x + cos(angle) * bloomRadius,
                y: center.y + sin(angle) * bloomRadius
            )

            var path = Path()
            path.move(to: center)
            path.addLine(to: endPoint)

            context.stroke(
                path,
                with: .color(theme.pappus.opacity(0.85)),
                style: StrokeStyle(lineWidth: size.width * 0.025, lineCap: .round)
            )

            // Small dot at end of each seed
            let dotSize = size.width * 0.07
            let dotRect = CGRect(
                x: endPoint.x - dotSize / 2,
                y: endPoint.y - dotSize / 2,
                width: dotSize,
                height: dotSize
            )
            context.fill(Path(ellipseIn: dotRect), with: .color(theme.pappus))
        }

        // Center core
        let coreSize = size.width * 0.14
        let coreRect = CGRect(
            x: center.x - coreSize / 2,
            y: center.y - coreSize / 2,
            width: coreSize,
            height: coreSize
        )
        context.fill(Path(ellipseIn: coreRect), with: .color(theme.accent))
    }

    private func drawEmptyDayDot(
        in context: inout GraphicsContext,
        center: CGPoint,
        size: CGSize,
        theme: DandelionTheme
    ) {
        // Small dot for empty day
        let dotSize = size.width * 0.18
        let dotRect = CGRect(
            x: center.x - dotSize / 2,
            y: center.y - dotSize / 2,
            width: dotSize,
            height: dotSize
        )
        context.fill(Path(ellipseIn: dotRect), with: .color(theme.secondary.opacity(0.4)))
    }
}

#Preview {
    HStack(spacing: 20) {
        DandelionDayIcon(isFullBloom: true, size: 24)
        DandelionDayIcon(isFullBloom: false, size: 24)
        DandelionDayIcon(isFullBloom: true, size: 40)
        DandelionDayIcon(isFullBloom: false, size: 40)
    }
    .padding()
    .background(AppearanceManager().theme.background)
}
