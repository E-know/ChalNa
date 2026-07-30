import SwiftUI
import ComposableArchitecture
import AppCore
import Models
import DesignSystem

/// 타임라인 편집 화면. TCA store 기반.
public struct TimelineView: View {
    @Environment(EditSession.self) private var session

    @Bindable var store: StoreOf<TimelineFeature>
    @State private var playback = ClipPlaybackController()
    @State private var didWireController = false
    @State private var labelEditorClip: Clip?

    public init(store: StoreOf<TimelineFeature> = Store(initialState: TimelineFeature.State()) { TimelineFeature() }) {
        self.store = store
    }

    public var body: some View {
        VStack(spacing: 0) {
            header

            // 프리뷰가 유일한 가변 요소다. 남는 공간을 전부 먹는다.
            PreviewPanel(store: store, playback: playback)
                .padding(.horizontal, 20)
                .padding(.top, 12)
                .layoutPriority(1)

            TransportControls(
                isPlaying: store.isPlaying,
                onPrev: { store.send(.previousTapped) },
                onToggle: { store.send(.togglePlay) },
                onNext: { store.send(.nextTapped) }
            )
            .padding(.top, 12)

            hintRow
                .padding(.horizontal, 20)
                .padding(.top, 10)

            FilmStripCollectionView(
                store: store,
                session: session,
                onTapClip: { store.send(.clipTapped(index: $0)) }
            )
            .frame(height: 96)
            .padding(.horizontal, 20)
            .padding(.top, 8)
        }
        .chalNaScreen()
        .safeAreaInset(edge: .bottom) {
            bottomBar
                .padding(.horizontal, 20)
                .padding(.top, 8)
                .padding(.bottom, 8)
        }
        .onAppear {
            syncFromSessionIfNeeded()
            wirePlaybackControllerIfNeeded()
            playback.load(clip: store.currentClip)
        }
        .onChange(of: store.isPlaying) { _, playing in
            if playing { playback.play() } else { playback.pause() }
        }
        .onChange(of: store.currentIndex) { _, _ in
            playback.load(clip: store.currentClip)
            if store.isPlaying { playback.play() }
        }
        .onChange(of: store.clips) { _, newClips in
            if session.clips != newClips {
                session.clips = newClips
            }
        }
        .onDisappear { playback.pause() }
        .confirmationDialog(
            "클립을 삭제할까요?",
            isPresented: $store.isConfirmingDelete.sending(\.deletePresentedChanged),
            titleVisibility: .visible
        ) {
            Button("삭제", role: .destructive) { store.send(.deleteConfirmed) }
            Button("취소", role: .cancel) { store.send(.deleteCancelled) }
        } message: {
            Text("삭제한 클립은 현재 타임라인에서 제거됩니다.")
        }
        .fullScreenCover(item: $labelEditorClip) { clip in
            LabelEditorView(
                clip: clip,
                rotation: session.rotation(for: clip.id),
                transform: session.transform(for: clip.id),
                initialLabel: session.label(for: clip.id),
                onCommit: { newLabel in
                    session.setLabel(newLabel, for: clip.id)
                    labelEditorClip = nil
                },
                onCancel: { labelEditorClip = nil }
            )
        }
    }

    // MARK: - Playback wiring

    private func wirePlaybackControllerIfNeeded() {
        guard !didWireController else { return }
        didWireController = true

        // 현재 클립의 경과 → reducer 의 playheadSeconds 갱신
        playback.onElapsed = { elapsed in
            store.send(.playheadElapsedUpdated(elapsed))
        }

        // 클립 끝 → reducer 가 next or 종료 처리. 그 후 controller load.
        playback.onClipEnd = { [playback] in
            store.send(.currentClipEnded)
            if !store.isPlaying {
                playback.pause()
                playback.load(clip: store.currentClip)
            }
        }
    }

    // MARK: - Session sync

    private func syncFromSessionIfNeeded() {
        guard !session.clips.isEmpty else { return }
        if store.clips != session.clips {
            store.send(.syncFromSession(clips: session.clips, title: session.title))
        }
    }

    // MARK: - Header

    private var header: some View {
        ChalNaNavBar(
            title: "편집",
            caption: store.title.isEmpty ? nil : store.title,
            leading: .back { store.send(.dismissTapped) },
            showsDivider: true
        )
    }

    private var canSave: Bool { !store.clips.isEmpty }

    // MARK: - Hint row

    /// 힌트 1줄. 재생 중에는 숨긴다.
    ///
    /// 기존에는 이 위에 `labelRow`(TIMELINE · N CLIPS + 총 길이)가 따로 있었지만
    /// 클립 수는 필름스트립이, 총 길이는 스크럽바가, 현재 인덱스는 캔버스 배지가
    /// 이미 말하고 있었다. 같은 정보를 35pt 더 써서 두 번 말하던 것을 지웠다.
    @ViewBuilder
    private var hintRow: some View {
        if store.isPlaying {
            // 자리를 유지해 재생/정지 전환 시 레이아웃이 튀지 않게 한다.
            Color.clear.frame(height: 16)
        } else {
            Text("클립을 탭해 편집 · 길게 눌러서 끌어 이동")
                .font(ChalNaTypography.caption)
                .foregroundColor(ChalNaColor.textSecondary)
                .lineLimit(1)
                .minimumScaleFactor(0.85)
                .frame(maxWidth: .infinity, alignment: .center)
                .frame(height: 16)
        }
    }

    // MARK: - Bottom bar

    @ViewBuilder
    private var bottomBar: some View {
        if store.isPlaying {
            EditToolbar(dimmed: true, adjustActive: currentAdjustActive, canSave: canSave)
        } else {
            EditToolbar(
                adjustActive: currentAdjustActive,
                labelActive: currentLabelActive,
                canSave: canSave,
                onAdjust: { openAdjust() },
                onLabel: { openLabelEditor() },
                onDelete: { store.send(.deleteCurrentRequested) },
                onSave: { store.send(.saveTapped) }
            )
        }
    }

    // MARK: - Adjust (조정 화면 진입)

    /// 회전 또는 줌/이동이 적용돼 있으면 툴바 점 표시.
    private var currentAdjustActive: Bool {
        guard let id = store.currentClip?.id else { return false }
        return session.rotation(for: id) != .r0 || session.transform(for: id) != .fill
    }

    private func openAdjust() {
        guard store.currentClip != nil else { return }
        store.send(.adjustCurrentTapped)
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
    }

    // MARK: - Label

    private var currentLabelActive: Bool {
        guard let id = store.currentClip?.id else { return false }
        return session.label(for: id).isVisible
    }

    private func openLabelEditor() {
        labelEditorClip = store.currentClip
    }
}

// MARK: - Previews

#Preview("Idle") {
    TimelineView()
        .environment(EditSession())
}

#Preview("Playing") {
    TimelineView(
        store: Store(initialState: TimelineFeature.State(currentIndex: 3, playbackState: .playing, playheadSeconds: 35)) {
            TimelineFeature()
        }
    )
    .environment(EditSession())
}

#Preview("Timeline · xxxLarge") {
    TimelineView()
        .environment(EditSession(title: SampleData.filmTitle, clips: SampleData.jejuTimeline))
        .environment(\.dynamicTypeSize, .xxxLarge)
}
