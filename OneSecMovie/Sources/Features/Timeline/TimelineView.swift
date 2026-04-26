import SwiftUI

/// 타임라인 편집 화면. 3가지 상태(idle · playing · reordering)를 단일 뷰에서 렌더.
public struct TimelineView: View {
    @Environment(AppRouter.self) private var router
    @Environment(EditSession.self) private var session

    @State private var model: TimelineModel
    @State private var playback = ClipPlaybackController()
    @State private var didWireController = false
    @State private var showTrimSheet = false
    @State private var showMusicSheet = false

    public init(model: TimelineModel = TimelineModel()) {
        self._model = State(initialValue: model)
    }

    public var body: some View {
        VStack(spacing: 0) {
            preview
                .padding(.horizontal, MomentsSpacing.md)
                .padding(.top, MomentsSpacing.md)

            dateSticker
                .padding(.top, MomentsSpacing.md)

            labelRow
                .padding(.horizontal, MomentsSpacing.md + 4)
                .padding(.top, MomentsSpacing.md + 4)

            FilmStrip(
                model: model,
                onTapClip: { model.select(clipAt: $0) },
                onLongPressClip: { idx in
                    guard model.clips.indices.contains(idx) else { return }
                    model.beginReorder(clipID: model.clips[idx].id)
                    // 데모용: 드롭 타깃을 앞/뒤로 약간 이동시킨 초기값 제공
                    model.updateReorderTarget(slot: min(idx + 3, model.clips.count))
                }
            )
            .padding(.horizontal, MomentsSpacing.md)
            .padding(.top, MomentsSpacing.xs)

            hintRow
                .padding(.horizontal, MomentsSpacing.md + 4)
                .padding(.top, model.isPlaying ? MomentsSpacing.md : MomentsSpacing.md)

            if model.isPlaying {
                TransportControls(
                    isPlaying: true,
                    onPrev: { model.previous() },
                    onToggle: { togglePlayback() },
                    onNext: { model.next() }
                )
                .padding(.top, MomentsSpacing.md)
            }

            Spacer(minLength: 0)
        }
        .momentsTopBar {
            header.opacity(model.isReordering ? 0.6 : 1)
        }
        .safeAreaInset(edge: .bottom) { bottomBar.padding(.horizontal, MomentsSpacing.md) }
        .momentsScreen()
        .onAppear {
            syncFromSessionIfNeeded()
            wirePlaybackControllerIfNeeded()
            playback.load(clip: model.currentClip)
        }
        .onChange(of: model.isPlaying) { _, playing in
            if playing {
                playback.play()
            } else {
                playback.pause()
            }
        }
        .onChange(of: model.currentIndex) { _, _ in
            playback.load(clip: model.currentClip)
            if model.isPlaying {
                playback.play()
            }
        }
        .onChange(of: model.clips) { _, newClips in
            // 편집 결과를 세션에 반영 (삭제/순서 변경/트림).
            if session.clips != newClips {
                session.clips = newClips
            }
        }
        .onDisappear { playback.pause() }
        .sheet(isPresented: $showTrimSheet) {
            TrimSheet(model: model)
                .presentationDetents([.height(280)])
        }
        .sheet(isPresented: $showMusicSheet) {
            MusicSheet()
                .presentationDetents([.height(260)])
        }
    }

    // MARK: - Playback wiring

    private func wirePlaybackControllerIfNeeded() {
        guard !didWireController else { return }
        didWireController = true

        // 현재 클립의 경과 시간을 global playhead(0 → totalDuration)로 환산.
        playback.onElapsed = { [model] elapsed in
            let base = model.cumulativeStart(ofClipAt: model.currentIndex)
            model.playheadSeconds = min(base + elapsed, model.totalDuration)
        }

        // 현재 클립 끝 → 다음 클립으로. 마지막이면 재생 종료 후 처음으로 복귀.
        playback.onClipEnd = { [model, playback] in
            if model.currentIndex + 1 < model.clips.count {
                model.next()
                // onChange(of: currentIndex)가 playback.load + play를 수행.
            } else {
                model.state = .idle
                model.currentIndex = 0
                model.playheadSeconds = 0
                playback.pause()
                playback.load(clip: model.currentClip)
            }
        }
    }

    // MARK: - Session sync

    private func syncFromSessionIfNeeded() {
        guard !session.clips.isEmpty else { return }
        if model.clips != session.clips {
            model.clips = session.clips
            if !session.title.isEmpty { model.title = session.title }
            model.currentIndex = 0
            model.playheadSeconds = 0
            model.state = .idle
        }
    }

    // MARK: - Header

    private var header: some View {
        HStack {
            Button(action: { router.pop() }) {
                HStack(spacing: 2) {
                    MomentsIcon(.chevronLeft, size: 14)
                    Text("뒤로").font(MomentsTypography.krBody(14, weight: .medium))
                }
                .foregroundColor(MomentsColor.taupe)
            }
            .buttonStyle(.plain)

            Spacer()

            VStack(spacing: 2) {
                HStack(spacing: 6) {
                    if model.isPlaying { PulseDot() }
                    Text(headerTitle)
                        .font(MomentsTypography.krSemibold(15))
                        .foregroundColor(MomentsColor.ink)
                }
                Text(headerSubtitle)
                    .tagLabel(color: model.isPlaying ? MomentsColor.coral : MomentsColor.taupe)
            }

            Spacer()

            Button(action: { router.push(.export) }) {
                Text("저장")
                    .font(MomentsTypography.krSemibold(14))
                    .foregroundColor(canSave ? MomentsColor.coral : MomentsColor.taupe.opacity(0.5))
            }
            .buttonStyle(.plain)
            .disabled(!canSave)
        }
    }

    private var canSave: Bool {
        !model.isReordering && !model.clips.isEmpty
    }

    private var headerTitle: String {
        switch model.state {
        case .idle:       return "편집"
        case .playing:    return "재생 중"
        case .reordering: return "순서 변경"
        }
    }

    private var headerSubtitle: String {
        switch model.state {
        case .idle:       return model.title
        case .playing:    return "PLAYING"
        case .reordering: return "REORDERING"
        }
    }

    // MARK: - Preview

    private var preview: some View {
        PreviewPanel(model: model, playback: playback, onTogglePlay: { togglePlayback() })
    }

    // MARK: - Date sticker

    @ViewBuilder
    private var dateSticker: some View {
        if let clip = model.currentClip {
            DateTapeSticker(
                text: dateStickerText(for: clip),
                rotationDegrees: model.isPlaying ? 1.5 : -1.5,
                leftTape: model.isPlaying ? .sage : .coral,
                rightTape: model.isPlaying ? .coral : .sage,
                muted: model.isReordering
            )
        }
    }

    private static let dateStickerFormatter: DateFormatter = {
        let df = DateFormatter()
        df.dateFormat = "yyyy.MM.dd"
        return df
    }()

    private func dateStickerText(for clip: Clip) -> String {
        let note = clip.locationNote.map { " · \($0)" } ?? ""
        return Self.dateStickerFormatter.string(from: clip.capturedAt) + note
    }

    // MARK: - Label row

    private var labelRow: some View {
        HStack {
            Text(labelLeft)
                .tagLabel(color: labelLeftColor)
            Spacer()
            labelRight
        }
    }

    private var labelLeft: String {
        switch model.state {
        case .idle:       return "TIMELINE · \(model.clips.count) CLIPS"
        case .playing:    return "▶ NOW PLAYING · CLIP \(model.currentIndex + 1)"
        case .reordering: return "◈ MOVING CLIP \((model.clips.firstIndex(where: { $0.id == model.draggingClipID }) ?? 0) + 1) → SLOT \((model.targetSlotIndex ?? 0) + 1)"
        }
    }

    private var labelLeftColor: Color {
        switch model.state {
        case .idle:    return MomentsColor.taupe
        default:       return MomentsColor.coral
        }
    }

    @ViewBuilder
    private var labelRight: some View {
        switch model.state {
        case .idle:
            (Text("총 ").tagLabel(color: MomentsColor.taupe)
             + Text(model.totalDurationLabel)
                .font(MomentsTypography.serifFallback(13, italic: true))
                .foregroundColor(MomentsColor.ink))
        case .playing:
            Text("\(model.playheadLabel) / \(model.totalClockLabel)").tagLabel()
        case .reordering:
            Text("HOLD · DRAG").tagLabel()
        }
    }

    // MARK: - Hint row

    @ViewBuilder
    private var hintRow: some View {
        switch model.state {
        case .idle:
            HandNoteRow("클립을 탭해 편집 · 순서 버튼 또는 길게 눌러 이동", tone: .muted)
        case .playing:
            EmptyView()
        case .reordering:
            HandNoteRow(hintForReorder, tone: .accent, size: 18)
        }
    }

    private var hintForReorder: String {
        let groups = model.clips.groupedByDay()
        guard groups.count > 1 else { return "여기에 놓으면 순서가 바뀌어요 ✦" }
        return "여기에 놓으면 \(groups[1].dayKey) 사이에 들어가요 ✦"
    }

    // MARK: - Bottom bar

    @ViewBuilder
    private var bottomBar: some View {
        switch model.state {
        case .idle:
            EditToolbar(
                onTrim:    { showTrimSheet = true },
                onReorder: { beginReorderFromButton() },
                onDelete:  { model.deleteCurrent() },
                onMusic:   { showMusicSheet = true }
            )
            .padding(.bottom, MomentsSpacing.md)
        case .playing:
            EditToolbar(dimmed: true)
                .padding(.bottom, MomentsSpacing.md)
        case .reordering:
            ReorderConfirmBar(
                onCancel: { model.cancelReorder() },
                onConfirm: { model.confirmReorder() }
            )
            .padding(.bottom, MomentsSpacing.md)
        }
    }

    // MARK: - Intents

    private func togglePlayback() {
        model.togglePlay()
    }

    private func beginReorderFromButton() {
        guard let id = model.currentClip?.id else { return }
        model.beginReorder(clipID: id)
        // 버튼으로 진입 시 초기 타겟은 "다음 슬롯"으로 힌트 제공.
        model.updateReorderTarget(slot: min(model.currentIndex + 2, model.clips.count))
    }
}

// MARK: - Pulse dot (header)

private struct PulseDot: View {
    var body: some View {
        Circle()
            .fill(MomentsColor.coral)
            .frame(width: 6, height: 6)
            .overlay(Circle().stroke(MomentsColor.coral.opacity(0.3), lineWidth: 3).padding(-3))
    }
}

// MARK: - Trim sheet (placeholder)

private struct TrimSheet: View {
    @Environment(\.dismiss) private var dismiss
    let model: TimelineModel

    var body: some View {
        VStack(spacing: MomentsSpacing.md) {
            Capsule()
                .fill(MomentsColor.taupe.opacity(0.35))
                .frame(width: 44, height: 4)
                .padding(.top, MomentsSpacing.sm)

            Text("자르기")
                .font(MomentsTypography.krSemibold(17))
                .foregroundColor(MomentsColor.ink)

            if let clip = model.currentClip {
                Text("현재 클립 · \(clip.durationSecondsLabel)")
                    .font(MomentsTypography.monoFallback(12, weight: .medium))
                    .foregroundColor(MomentsColor.taupe)
            }

            HStack(spacing: MomentsSpacing.sm) {
                Button {
                    model.trimCurrent(deltaSeconds: -0.5)
                } label: {
                    HStack(spacing: 6) {
                        MomentsIcon(.skipBack, size: 14)
                        Text("-0.5s")
                    }
                }
                .buttonStyle(.momentsOutline)

                Button {
                    model.trimCurrent(deltaSeconds: +0.5)
                } label: {
                    HStack(spacing: 6) {
                        Text("+0.5s")
                        MomentsIcon(.skipForward, size: 14)
                    }
                }
                .buttonStyle(.momentsCoral)
            }

            HandNoteRow("0.5s 부터 조정돼요", tone: .muted, size: 15)

            Button("완료") { dismiss() }
                .buttonStyle(.momentsText)
                .padding(.bottom, MomentsSpacing.sm)
        }
        .frame(maxWidth: .infinity)
        .background(MomentsColor.cream)
    }
}

// MARK: - Music sheet (placeholder)

private struct MusicSheet: View {
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(spacing: MomentsSpacing.md) {
            Capsule()
                .fill(MomentsColor.taupe.opacity(0.35))
                .frame(width: 44, height: 4)
                .padding(.top, MomentsSpacing.sm)

            HStack(spacing: MomentsSpacing.xs) {
                MomentsIcon(.music, size: 18).foregroundColor(MomentsColor.coral)
                Text("음악")
                    .font(MomentsTypography.krSemibold(17))
                    .foregroundColor(MomentsColor.ink)
            }

            HandNoteRow("배경 음악은 곧 추가될 예정이에요 ✦", tone: .accent, size: 17)
                .padding(.horizontal, MomentsSpacing.lg)

            Text("MUSIC · COMING SOON")
                .tagLabel(color: MomentsColor.coral)

            Button("닫기") { dismiss() }
                .buttonStyle(.momentsText)
                .padding(.bottom, MomentsSpacing.sm)
        }
        .frame(maxWidth: .infinity)
        .background(MomentsColor.cream)
    }
}

// MARK: - Previews

#Preview("Idle") {
    TimelineView(model: TimelineModel(state: .idle))
        .environment(AppRouter())
        .environment(EditSession())
}

#Preview("Playing") {
    TimelineView(
        model: {
            let m = TimelineModel(state: .playing, currentIndex: 3)
            m.playheadSeconds = 35
            return m
        }()
    )
    .environment(AppRouter())
    .environment(EditSession())
}

private extension TimelineModel {
    convenience init(state: TimelineState, currentIndex: Int = 0) {
        self.init()
        self.state = state
        self.currentIndex = currentIndex
    }
}

#Preview("Reordering") {
    TimelineView(
        model: {
            let m = TimelineModel()
            if let third = m.clips[safe: 2] {
                m.beginReorder(clipID: third.id)
                m.updateReorderTarget(slot: 5)
            }
            return m
        }()
    )
    .environment(AppRouter())
    .environment(EditSession())
}

private extension Array {
    subscript(safe i: Int) -> Element? { indices.contains(i) ? self[i] : nil }
}
