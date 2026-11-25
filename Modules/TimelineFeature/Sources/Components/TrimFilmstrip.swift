import DesignSystem
import SwiftUI

struct TrimFilmstrip: View {
    enum Edge { case start, end }
    static let frameCount = 8

    let range: ClosedRange<TimeInterval>
    let duration: TimeInterval
    let thumbnails: [CGImage?]
    let fallbackThumbnail: CGImage?
    let onChange: (Edge, TimeInterval) -> Void

    @State private var dragging: Edge?
    @State private var originalTime: TimeInterval = 0

    var body: some View {
        VStack(spacing: 10) {
            GeometryReader { proxy in
                let width = proxy.size.width
                let travel = max(1, width - 32)
                // Offset the two grips to either side of their time positions, keeping them visible even for a very short selection.
                let start = 8 + travel * range.lowerBound / duration
                let end = 24 + travel * range.upperBound / duration
                let startTarget = min(max(start, 22), width - 66)
                let endTarget = min(max(end, startTarget + 44), width - 22)
                ZStack(alignment: .leading) {
                    HStack(spacing: 0) {
                        ForEach(0..<Self.frameCount, id: \.self) { index in
                            ZStack {
                                ChalNaColor.surface
                                if let thumbnail = thumbnail(at: index) {
                                    Image(decorative: thumbnail, scale: 1)
                                        .resizable().scaledToFill()
                                }
                            }
                            .frame(width: width / CGFloat(Self.frameCount), height: 48)
                            .clipped()
                        }
                    }
                    .accessibilityHidden(true)
                    ChalNaColor.scrim.frame(width: max(0, start - 8))
                    ChalNaColor.scrim.frame(width: max(0, width - end - 8)).offset(x: end + 8)
                    VStack(spacing: 0) {
                        ChalNaColor.accent.frame(height: 3)
                        Spacer()
                        ChalNaColor.accent.frame(height: 3)
                    }
                    .frame(width: end - start + 16, height: 48)
                    .offset(x: start - 8)
                    grip.position(x: start, y: 24)
                    grip.position(x: end, y: 24)
                    accessibleHandle(.start, x: startTarget)
                    accessibleHandle(.end, x: endTarget)
                }
                .clipShape(RoundedRectangle(cornerRadius: ChalNaRadius.xs))
                .contentShape(Rectangle())
                .gesture(drag(start: start, end: end, startTarget: startTarget, endTarget: endTarget, travel: travel))
                .overlay(alignment: .topLeading) {
                    if let dragging {
                        Text(verbatim: timelineClock(dragging == .start ? range.lowerBound : range.upperBound))
                            .font(ChalNaTypography.caption).monospacedDigit()
                            .foregroundStyle(ChalNaColor.onAccent)
                            .padding(.horizontal, 8).padding(.vertical, 4)
                            .background(ChalNaColor.accent, in: RoundedRectangle(cornerRadius: ChalNaRadius.xs))
                            .position(x: min(max(dragging == .start ? start : end, 34), width - 34), y: -16)
                            .allowsHitTesting(false).accessibilityHidden(true)
                    }
                }
            }
            .frame(height: 48)
            HStack {
                HStack(spacing: 5) { Text("시작"); Text(verbatim: timelineClock(range.lowerBound)) }
                    .foregroundStyle(dragging == .start ? ChalNaColor.accent : ChalNaColor.textSecondary)
                Spacer()
                HStack(spacing: 5) { Text("끝"); Text(verbatim: timelineClock(range.upperBound)) }
                    .foregroundStyle(dragging == .end ? ChalNaColor.accent : ChalNaColor.textSecondary)
            }
            .font(ChalNaTypography.label).monospacedDigit()
        }
    }

    private func thumbnail(at index: Int) -> CGImage? {
        let nearest = thumbnails.indices.filter { thumbnails[$0] != nil }.min { abs($0 - index) < abs($1 - index) }
        return nearest.flatMap { thumbnails[$0] } ?? fallbackThumbnail
    }

    private var grip: some View {
        RoundedRectangle(cornerRadius: ChalNaRadius.xxs).fill(ChalNaColor.accent)
            .frame(width: 16, height: 48)
            .overlay { Capsule().fill(ChalNaColor.onAccent).frame(width: 3, height: 18) }
            .accessibilityHidden(true)
    }

    private func accessibleHandle(_ edge: Edge, x: CGFloat) -> some View {
        let current = edge == .start ? range.lowerBound : range.upperBound
        return Color.clear.frame(width: 44, height: 48)
            .accessibilityElement()
            .accessibilityLabel(edge == .start ? Text("시작점") : Text("끝점"))
            .accessibilityValue(Text(verbatim: timelineClock(current)))
            .accessibilityAdjustableAction { direction in
                switch direction {
                case .increment: onChange(edge, current + 0.1)
                case .decrement: onChange(edge, current - 0.1)
                @unknown default: break
                }
            }
            .accessibilityIdentifier(edge == .start ? "trim.start" : "trim.end")
            .position(x: x, y: 24)
    }

    private func drag(start: CGFloat, end: CGFloat, startTarget: CGFloat, endTarget: CGFloat, travel: CGFloat) -> some Gesture {
        DragGesture(minimumDistance: 0)
            .onChanged { value in
                if dragging == nil {
                    let left = abs(value.startLocation.x - start)
                    let right = abs(value.startLocation.x - end)
                    if min(left, right) <= 8 {
                        dragging = left <= right ? .start : .end
                    } else {
                        let leftTarget = abs(value.startLocation.x - startTarget)
                        let rightTarget = abs(value.startLocation.x - endTarget)
                        guard min(leftTarget, rightTarget) <= 22 else { return }
                        dragging = leftTarget <= rightTarget ? .start : .end
                    }
                    originalTime = dragging == .start ? range.lowerBound : range.upperBound
                }
                if let dragging {
                    onChange(dragging, originalTime + value.translation.width / travel * duration)
                }
            }
            .onEnded { _ in dragging = nil }
    }
}
