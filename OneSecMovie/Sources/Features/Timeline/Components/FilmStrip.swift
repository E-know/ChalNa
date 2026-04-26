import SwiftUI

/// 어두운 잉크 배경의 가로 스크롤 필름 스트립.
/// 클립 셀 + 날짜 sprocket 구분자 + (reordering 시) 고스트/인서트 가이드/부동 클립을 렌더.
struct FilmStrip: View {
    let model: TimelineModel
    let onTapClip: (Int) -> Void
    let onLongPressClip: (Int) -> Void

    var body: some View {
        ZStack(alignment: .topLeading) {
            RoundedRectangle(cornerRadius: MomentsRadius.card, style: .continuous)
                .fill(MomentsColor.ink)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(alignment: .bottom, spacing: MomentsSpacing.xs) {
                    ForEach(Array(content.enumerated()), id: \.offset) { _, item in
                        stripItem(item)
                    }
                }
                .padding(MomentsSpacing.sm)
            }

            if model.isReordering {
                floatingDraggedClip
                    .padding(.leading, 180)
                    .padding(.top, -28)
            }
        }
        .fixedSize(horizontal: false, vertical: true)
    }

    // MARK: - Content sequencing

    private enum StripItem {
        case dayLabel(String, highlighted: Bool)
        case clip(Clip, index: Int)
        case insertGuide
        case ghost(Clip)
    }

    /// 날짜 + 클립 + (reorder 시) ghost/insert-guide를 섞어 단일 순회 가능한 리스트로 변환.
    private var content: [StripItem] {
        var items: [StripItem] = []
        let groups = model.clips.groupedByDay()
        var runningIndex = 0
        let playingDayKey: String? = {
            guard case .playing = model.state, let clip = model.currentClip else { return nil }
            let df = DateFormatter(); df.dateFormat = "MM.dd"
            return df.string(from: clip.capturedAt)
        }()

        // Reorder 상태에서 target slot 인덱스
        let target = model.targetSlotIndex ?? -1
        let ghostID = model.draggingClipID

        for (dayKey, dayClips) in groups {
            items.append(.dayLabel(dayKey, highlighted: dayKey == playingDayKey))
            for clip in dayClips {
                // insert guide — 이 슬롯 앞에 들어갈 위치라면 먼저 가이드
                if runningIndex == target, model.isReordering { items.append(.insertGuide) }
                if clip.id == ghostID {
                    items.append(.ghost(clip))
                } else {
                    items.append(.clip(clip, index: runningIndex))
                }
                runningIndex += 1
            }
        }
        // 끝에 오는 경우
        if runningIndex == target, model.isReordering { items.append(.insertGuide) }
        return items
    }

    // MARK: - Item rendering

    @ViewBuilder
    private func stripItem(_ item: StripItem) -> some View {
        switch item {
        case .dayLabel(let key, let highlighted):
            DaySprocket(label: key, highlighted: highlighted)

        case .clip(let clip, let index):
            clipColumn(clip: clip, index: index)

        case .insertGuide:
            InsertGuide()

        case .ghost(let clip):
            VStack(spacing: 4) {
                ClipThumbCard(state: .ghost) { clip.preset.view() }
                Text("—")
                    .font(MomentsTypography.monoFallback(8, weight: .medium))
                    .foregroundColor(MomentsColor.coral.opacity(0.8))
            }
        }
    }

    private func clipColumn(clip: Clip, index: Int) -> some View {
        let visualState = cardState(for: clip, index: index)
        let rot = rotationForIndex(index)
        return VStack(spacing: 4) {
            ZStack {
                ClipThumbCard(state: visualState, rotationDegrees: rot) {
                    ZStack {
                        clip.thumbnailView()
                        if clip.kind == .live {
                            LiveBadge(size: 10)
                                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                                .padding(2)
                        }
                        if visualState == .playing {
                            Circle()
                                .fill(Color.white.opacity(0.9))
                                .frame(width: 20, height: 20)
                                .overlay(MomentsIcon(.pause, size: 7).foregroundColor(MomentsColor.ink))
                        }
                    }
                }
                if visualState == .playing {
                    playheadArrow
                        .offset(y: 36)
                }
            }
            durationLabel(state: visualState, clip: clip)
        }
        .contentShape(Rectangle())
        .onTapGesture { onTapClip(index) }
        .onLongPressGesture(minimumDuration: 0.35) { onLongPressClip(index) }
    }

    private var playheadArrow: some View {
        Triangle()
            .fill(MomentsColor.coral)
            .frame(width: 10, height: 6)
    }

    @ViewBuilder
    private func durationLabel(state: ClipThumbState, clip: Clip) -> some View {
        switch state {
        case .playing:
            Text("▶ \(clip.durationSecondsLabel)")
                .font(MomentsTypography.monoFallback(9, weight: .bold))
                .foregroundColor(MomentsColor.coral)
        case .selected:
            Text(clip.durationSecondsLabel)
                .font(MomentsTypography.monoFallback(9, weight: .medium))
                .foregroundColor(MomentsColor.coral)
        case .dimmed where model.isPlaying && isPastPlaying(index: model.clips.firstIndex(of: clip) ?? -1):
            Text("✓")
                .font(MomentsTypography.monoFallback(8, weight: .medium))
                .foregroundColor(MomentsColor.cream.opacity(0.6))
        default:
            Text(clip.durationSecondsLabel)
                .font(MomentsTypography.monoFallback(9, weight: .medium))
                .foregroundColor(MomentsColor.cream.opacity(0.7))
        }
    }

    // MARK: - Floating dragged clip

    @ViewBuilder
    private var floatingDraggedClip: some View {
        if let id = model.draggingClipID, let clip = model.clips.first(where: { $0.id == id }) {
            ZStack(alignment: .topTrailing) {
                ClipThumbCard(state: .lifted, rotationDegrees: -5, size: CGSize(width: 46, height: 60)) {
                    ZStack {
                        clip.thumbnailView()
                        if clip.kind == .live {
                            LiveBadge(size: 11)
                                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                                .padding(3)
                        }
                    }
                }
                Circle()
                    .fill(MomentsColor.coral)
                    .frame(width: 20, height: 20)
                    .overlay(MomentsIcon(.chevronRight, size: 10).foregroundColor(.white))
                    .offset(x: 6, y: -6)
            }
            .overlay {
                // 손가락 터치 가이드 글로우
                FingerGlow()
                    .offset(x: -6, y: -4)
            }
        }
    }

    // MARK: - Helpers

    private func cardState(for clip: Clip, index: Int) -> ClipThumbState {
        if model.isPlaying {
            return index == model.currentIndex ? .playing : .dimmed
        }
        if model.isReordering {
            return .dimmed
        }
        return index == model.currentIndex ? .selected : .normal
    }

    private func rotationForIndex(_ i: Int) -> Double {
        switch i % 3 {
        case 0: return -1
        case 1: return 1
        default: return 0.3
        }
    }

    private func isPastPlaying(index: Int) -> Bool {
        index < model.currentIndex
    }
}

// MARK: - Day sprocket

private struct DaySprocket: View {
    let label: String
    let highlighted: Bool

    var body: some View {
        VStack(spacing: 6) {
            Text(label)
                .font(MomentsTypography.handFallback(13))
                .foregroundColor(highlighted ? MomentsColor.coral : MomentsColor.cream)
            SprocketLine()
                .frame(width: 2, height: 64)
        }
        .opacity(highlighted ? 1.0 : 0.85)
        .padding(.horizontal, 2)
    }
}

private struct SprocketLine: View {
    var body: some View {
        GeometryReader { proxy in
            let count = max(1, Int(proxy.size.height / 8))
            VStack(spacing: 3) {
                ForEach(0..<count, id: \.self) { _ in
                    Circle()
                        .fill(MomentsColor.cream)
                        .frame(width: 2.2, height: 2.2)
                }
            }
            .frame(width: 2.2)
            .frame(maxHeight: .infinity)
        }
    }
}

// MARK: - Insert guide (코랄 세로 바 + 위 삼각형)

private struct InsertGuide: View {
    var body: some View {
        VStack(spacing: 2) {
            Triangle()
                .fill(MomentsColor.coral)
                .frame(width: 10, height: 6)
                .rotationEffect(.degrees(180))
            RoundedRectangle(cornerRadius: 2, style: .continuous)
                .fill(MomentsColor.coral)
                .frame(width: 3, height: 60)
                .shadow(color: MomentsColor.coral.opacity(0.7), radius: 6)
        }
        .padding(.horizontal, 2)
    }
}

// MARK: - Finger glow

private struct FingerGlow: View {
    var body: some View {
        ZStack {
            Circle()
                .fill(RadialGradient(
                    colors: [MomentsColor.coral.opacity(0.35), .clear],
                    center: .center, startRadius: 0, endRadius: 32
                ))
                .frame(width: 56, height: 56)
                .overlay(
                    Circle().stroke(MomentsColor.coral.opacity(0.6), lineWidth: 1.5)
                )
            Circle()
                .fill(MomentsColor.coral.opacity(0.3))
                .frame(width: 22, height: 22)
                .overlay(
                    Circle().stroke(MomentsColor.coral.opacity(0.8), lineWidth: 1)
                )
                .offset(x: 14, y: 14)
        }
        .allowsHitTesting(false)
    }
}

// MARK: - Triangle shape

private struct Triangle: Shape {
    func path(in rect: CGRect) -> Path {
        var p = Path()
        p.move(to: CGPoint(x: rect.midX, y: rect.maxY))
        p.addLine(to: CGPoint(x: rect.minX, y: rect.minY))
        p.addLine(to: CGPoint(x: rect.maxX, y: rect.minY))
        p.closeSubpath()
        return p
    }
}
