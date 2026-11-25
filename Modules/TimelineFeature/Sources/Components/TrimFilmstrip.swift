import DesignSystem
import SwiftUI

struct TrimFilmstrip: View {
    enum Edge { case start, end }
    enum ScrubPhase { case moving, ended, cancelled }
    private enum DragTarget: Equatable { case boundary(Edge), playhead }
    static let frameCount = 8

    let range: ClosedRange<TimeInterval>
    let duration: TimeInterval
    let playhead: TimeInterval
    let thumbnails: [CGImage?]
    let fallbackThumbnail: CGImage?
    let onScrub: (TimeInterval, ScrubPhase) -> Void
    let onChange: (Edge, TimeInterval) -> Void

    @State private var dragging: DragTarget?
    @State private var originalTime: TimeInterval = 0
    @GestureState private var touching = false

    var body: some View {
        VStack(spacing: 10) {
            GeometryReader { proxy in
                let width = proxy.size.width
                let travel = max(1, width - 32)
                // Offset the two grips to either side of their time positions, keeping them visible even for a very short selection.
                let start = 8 + travel * range.lowerBound / duration
                let end = 24 + travel * range.upperBound / duration
                let marker = 16 + travel * playhead / duration
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
                .frame(height: 48)
                .clipShape(RoundedRectangle(cornerRadius: ChalNaRadius.xs))
                .overlay(alignment: .topLeading) {
                    Image(decorative: "trim_playhead").renderingMode(.original)
                        .frame(width: 44, height: 64)
                        .offset(x: marker - 22, y: -16)
                        .allowsHitTesting(false).accessibilityHidden(true)
                }
                .overlay(alignment: .topLeading) {
                    Color.clear.frame(width: 44, height: 44)
                        .accessibilityElement()
                        .accessibilityLabel(Text("재생 위치"))
                        .accessibilityValue(Text(verbatim: timelineClock(playhead)))
                        .accessibilityAdjustableAction { direction in
                            switch direction {
                            case .increment: onScrub(playhead + 0.1, .ended)
                            case .decrement: onScrub(playhead - 0.1, .ended)
                            @unknown default: break
                            }
                        }
                        .accessibilityIdentifier("trim.playhead")
                        .offset(x: min(max(marker - 22, 0), width - 44), y: -16)
                }
                .overlay(alignment: .topLeading) {
                    if let dragging {
                        let (time, x) = switch dragging {
                        case .playhead: (playhead, marker)
                        case .boundary(.start): (range.lowerBound, start)
                        case .boundary(.end): (range.upperBound, end)
                        }
                        Text(verbatim: timelineClock(time))
                            .font(ChalNaTypography.caption).monospacedDigit()
                            .foregroundStyle(ChalNaColor.onAccent)
                            .padding(.horizontal, 8).padding(.vertical, 4)
                            .background(ChalNaColor.accent, in: RoundedRectangle(cornerRadius: ChalNaRadius.xs))
                            .fixedSize()
                            .position(x: min(max(x, 34), width - 34), y: -28)
                            .allowsHitTesting(false).accessibilityHidden(true)
                    }
                }
                .padding(.top, 16)
                .contentShape(Rectangle())
                .gesture(drag(start: start, end: end, marker: marker, startTarget: startTarget, endTarget: endTarget, travel: travel))
                .onChange(of: touching) { _, active in
                    guard !active, let dragging else { return }
                    if dragging == .playhead { onScrub(playhead, .cancelled) }
                    self.dragging = nil
                }
            }
            .frame(height: 64)
            HStack {
                HStack(spacing: 5) { Text("시작"); Text(verbatim: timelineClock(range.lowerBound)) }
                    .foregroundStyle(dragging == .boundary(.start) ? ChalNaColor.accent : ChalNaColor.textSecondary)
                Spacer()
                HStack(spacing: 5) { Text("끝"); Text(verbatim: timelineClock(range.upperBound)) }
                    .foregroundStyle(dragging == .boundary(.end) ? ChalNaColor.accent : ChalNaColor.textSecondary)
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

    private func drag(start: CGFloat, end: CGFloat, marker: CGFloat, startTarget: CGFloat, endTarget: CGFloat, travel: CGFloat) -> some Gesture {
        DragGesture(minimumDistance: 0)
            .updating($touching) { _, touching, _ in touching = true }
            .onChanged { value in
                if dragging == nil {
                    let point = value.startLocation
                    let nearMarker = abs(point.x - marker) <= 22
                    let left = abs(point.x - start)
                    let right = abs(point.x - end)
                    let leftTarget = abs(point.x - startTarget)
                    let rightTarget = abs(point.x - endTarget)
                    // The cap remains draggable above either grip. The middle of each grip always edits its boundary.
                    if nearMarker && point.y < 32 {
                        dragging = .playhead
                    } else if point.y >= 16 && min(left, right) <= 8 {
                        dragging = .boundary(left <= right ? .start : .end)
                    } else if point.y >= 16 && min(leftTarget, rightTarget) <= 22 {
                        dragging = .boundary(leftTarget <= rightTarget ? .start : .end)
                    } else {
                        dragging = .playhead
                    }
                    switch dragging {
                    case .boundary(.start): originalTime = range.lowerBound
                    case .boundary(.end): originalTime = range.upperBound
                    case .playhead: originalTime = nearMarker ? playhead : (point.x - 16) / travel * duration
                    case nil: return
                    }
                }
                let time = originalTime + value.translation.width / travel * duration
                switch dragging {
                case let .boundary(edge): onChange(edge, time)
                case .playhead: onScrub(time, .moving)
                case nil: break
                }
            }
            .onEnded { value in
                if dragging == .playhead { onScrub(originalTime + value.translation.width / travel * duration, .ended) }
                dragging = nil
            }
    }
}
