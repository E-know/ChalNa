import SwiftUI

/// 타임라인 편집 화면. 2가지 상태(idle · playing) — 재정렬은 UIKit `UICollectionView` drag interaction이 시스템 레벨에서 처리.
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
            header
                .padding(.horizontal, MomentsSpacing.md + 4)
                .padding(.vertical, MomentsSpacing.sm)
                .frame(maxWidth: .infinity)

            preview
                .padding(.horizontal, MomentsSpacing.md)
                .padding(.top, MomentsSpacing.md)

            dateSticker
                .padding(.top, MomentsSpacing.md)

            labelRow
                .padding(.horizontal, MomentsSpacing.md + 4)
                .padding(.top, MomentsSpacing.md + 4)

            FilmStripCollectionView(
                model: model,
                session: session,
                onTapClip: { model.select(clipAt: $0) }
            )
            .frame(height: 104)
            .padding(.horizontal, MomentsSpacing.md)
            .padding(.top, MomentsSpacing.xs)

            hintRow
                .padding(.horizontal, MomentsSpacing.md + 4)
                .padding(.top, MomentsSpacing.md)

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
        .momentsScreen()
        .safeAreaInset(edge: .bottom) { bottomBar.padding(.horizontal, MomentsSpacing.md) }
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
        !model.clips.isEmpty
    }

    private var headerTitle: String {
        switch model.state {
        case .idle:    return "편집"
        case .playing: return "재생 중"
        }
    }

    private var headerSubtitle: String {
        switch model.state {
        case .idle:    return model.title
        case .playing: return "PLAYING"
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
                muted: false
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
        case .idle:    return "TIMELINE · \(model.clips.count) CLIPS"
        case .playing: return "▶ NOW PLAYING · CLIP \(model.currentIndex + 1)"
        }
    }

    private var labelLeftColor: Color {
        switch model.state {
        case .idle:    return MomentsColor.taupe
        case .playing: return MomentsColor.coral
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
        }
    }

    // MARK: - Hint row

    @ViewBuilder
    private var hintRow: some View {
        switch model.state {
        case .idle:
            HandNoteRow("클립을 탭해 편집 · 길게 눌러서 끌어 이동", tone: .muted)
        case .playing:
            EmptyView()
        }
    }

    // MARK: - Bottom bar

    @ViewBuilder
    private var bottomBar: some View {
        switch model.state {
        case .idle:
            EditToolbar(
                rotationActive: currentRotationActive,
                onRotate:  { rotateCurrentClip() },
                onTrim:    { showTrimSheet = true },
                onDelete:  { model.deleteCurrent() },
                onMusic:   { showMusicSheet = true }
            )
            .padding(.bottom, MomentsSpacing.md)
        case .playing:
            EditToolbar(dimmed: true, rotationActive: currentRotationActive)
                .padding(.bottom, MomentsSpacing.md)
        }
    }

    // MARK: - Intents

    private func togglePlayback() {
        model.togglePlay()
    }

    // MARK: - Rotation

    private var currentRotationActive: Bool {
        guard let id = model.currentClip?.id else { return false }
        return session.rotation(for: id) != .r0
    }

    private func rotateCurrentClip() {
        guard let id = model.currentClip?.id else { return }
        session.cycleRotation(for: id)
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
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
