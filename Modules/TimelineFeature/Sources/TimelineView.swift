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
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
                .chalNaHeaderBar(scrollProgress: 1)

            preview
                .padding(.horizontal, 16)
                .padding(.top, 16)

            TransportControls(
                isPlaying: store.isPlaying,
                onPrev: { store.send(.previousTapped) },
                onToggle: { store.send(.togglePlay) },
                onNext: { store.send(.nextTapped) }
            )
            .padding(.top, 12)

            labelRow
                .padding(.horizontal, 20)
                .padding(.top, 20)

            FilmStripCollectionView(
                store: store,
                session: session,
                onTapClip: { store.send(.clipTapped(index: $0)) }
            )
            .frame(height: 104)
            .padding(.horizontal, 16)
            .padding(.top, 8)

            hintRow
                .padding(.horizontal, 20)
                .padding(.top, 16)

            Spacer(minLength: 0)
        }
        .chalNaScreen()
        .safeAreaInset(edge: .bottom) { bottomBar.padding(.horizontal, 16) }
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
        ChalNaNavigationBar(
            title: headerTitle,
            subtitle: headerSubtitle
        ) {
            ChalNaHeaderBackButton {
                store.send(.dismissTapped)
            }
        } trailing: {
            EmptyView()
        }
    }

    private var canSave: Bool { !store.clips.isEmpty }

    private var headerTitle: String { String(localized: "편집") }

    private var headerSubtitle: String { store.title }

    // MARK: - Preview

    private var preview: some View {
        PreviewPanel(store: store, playback: playback)
    }

    // MARK: - Label row

    private var labelRow: some View {
        HStack {
            Text(labelLeft).tagLabel(color: labelLeftColor)
            Spacer()
            labelRight
        }
    }

    private var labelLeft: String {
        store.isPlaying
            ? "▶ NOW PLAYING · CLIP \(store.currentIndex + 1)"
            : "TIMELINE · \(store.clips.count) CLIPS"
    }

    private var labelLeftColor: Color {
        store.isPlaying ? ChalNaColor.Purple.p600 : ChalNaColor.Gray.g500
    }

    @ViewBuilder
    private var labelRight: some View {
        if store.isPlaying {
            Text("\(store.playheadLabel) / \(store.totalClockLabel)").tagLabel()
        } else {
            (Text("총 ").tagLabel(color: ChalNaColor.Gray.g500)
             + Text(store.totalDurationLabel)
                .font(ChalNaTypography.krBody(13, weight: .medium))
                .foregroundColor(ChalNaColor.Gray.g900))
        }
    }

    // MARK: - Hint row

    @ViewBuilder
    private var hintRow: some View {
        if !store.isPlaying {
            Text("클립을 탭해 편집 · 길게 눌러서 끌어 이동")
                .font(ChalNaTypography.krBody(ChalNaTypography.Size.small))
                .foregroundColor(ChalNaColor.Gray.g500)
                .frame(maxWidth: .infinity, alignment: .center)
        }
    }

    // MARK: - Bottom bar

    @ViewBuilder
    private var bottomBar: some View {
        if store.isPlaying {
            EditToolbar(dimmed: true, adjustActive: currentAdjustActive, canSave: canSave)
                .padding(.bottom, 16)
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
            .padding(.bottom, 16)
        }
    }

    // MARK: - Adjust (조정 화면 진입)

    /// 회전 또는 줌/이동이 적용돼 있으면 툴바 점 표시.
    private var currentAdjustActive: Bool {
        guard let id = store.currentClip?.id else { return false }
        return session.rotation(for: id) != .r0 || session.transform(for: id) != .fit
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
