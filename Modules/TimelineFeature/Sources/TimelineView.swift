import SwiftUI
import ComposableArchitecture
import AppCore
import Models
import DesignSystem

/// 타임라인 편집 화면. TCA store 기반.
public struct TimelineView: View {
    @Environment(AppRouter.self) private var router
    @Environment(EditSession.self) private var session

    @Bindable var store: StoreOf<TimelineFeature>
    @State private var playback = ClipPlaybackController()
    @State private var didWireController = false

    public init(store: StoreOf<TimelineFeature> = Store(initialState: TimelineFeature.State()) { TimelineFeature() }) {
        self.store = store
    }

    public var body: some View {
        VStack(spacing: 0) {
            header.chalNaHeaderBar(scrollProgress: 1)

            preview
                .padding(.horizontal, 16)
                .padding(.top, 16)

            dateSticker
                .padding(.top, 16)

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

            if store.isPlaying {
                TransportControls(
                    isPlaying: true,
                    onPrev: { store.send(.previousTapped) },
                    onToggle: { store.send(.togglePlay) },
                    onNext: { store.send(.nextTapped) }
                )
                .padding(.top, 16)
            }

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
        HStack {
            Button {
                store.send(.dismissTapped)
                router.pop()
            } label: {
                HStack(spacing: 2) {
                    ChalNaIcon(.chevronLeft, size: 14)
                    Text("뒤로").font(ChalNaTypography.krBody(14, weight: .medium))
                }
                .foregroundColor(ChalNaColor.taupe)
            }
            .buttonStyle(.chalNaHeaderAction)
            .accessibilityLabel("뒤로")

            Spacer()

            VStack(spacing: 2) {
                HStack(spacing: 6) {
                    if store.isPlaying { PulseDot() }
                    Text(headerTitle)
                        .font(ChalNaTypography.krSemibold(15))
                        .foregroundColor(ChalNaColor.ink)
                }
                Text(headerSubtitle)
                    .tagLabel(color: store.isPlaying ? ChalNaColor.coral : ChalNaColor.taupe)
            }

            Spacer()

            // 헤더 좌우 균형용 빈 영역 (뒤로 버튼과 같은 크기)
            HStack(spacing: 2) {
                ChalNaIcon(.chevronLeft, size: 14)
                Text("뒤로").font(ChalNaTypography.krBody(14, weight: .medium))
            }
            .opacity(0)
            .accessibilityHidden(true)
            .allowsHitTesting(false)
        }
    }

    private var canSave: Bool { !store.clips.isEmpty }

    private var headerTitle: String {
        store.isPlaying ? "재생 중" : "편집"
    }

    private var headerSubtitle: String {
        store.isPlaying ? "PLAYING" : store.title
    }

    // MARK: - Preview

    private var preview: some View {
        PreviewPanel(store: store, playback: playback, onTogglePlay: { store.send(.togglePlay) })
    }

    // MARK: - Date sticker

    @ViewBuilder
    private var dateSticker: some View {
        if let clip = store.currentClip {
            HStack(spacing: 4) {
                ChalNaIcon(.calendar, size: 12)
                    .foregroundColor(ChalNaColor.taupe)
                Text(dateStickerText(for: clip))
                    .font(ChalNaTypography.monoFallback(ChalNaTypography.Size.small, weight: .medium))
                    .foregroundColor(ChalNaColor.taupe)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background(Capsule(style: .continuous).fill(ChalNaColor.ivory))
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
        store.isPlaying ? ChalNaColor.coral : ChalNaColor.taupe
    }

    @ViewBuilder
    private var labelRight: some View {
        if store.isPlaying {
            Text("\(store.playheadLabel) / \(store.totalClockLabel)").tagLabel()
        } else {
            (Text("총 ").tagLabel(color: ChalNaColor.taupe)
             + Text(store.totalDurationLabel)
                .font(ChalNaTypography.krBody(13, weight: .medium))
                .foregroundColor(ChalNaColor.ink))
        }
    }

    // MARK: - Hint row

    @ViewBuilder
    private var hintRow: some View {
        if !store.isPlaying {
            Text("클립을 탭해 편집 · 길게 눌러서 끌어 이동")
                .font(ChalNaTypography.krBody(ChalNaTypography.Size.small))
                .foregroundColor(ChalNaColor.taupe)
                .frame(maxWidth: .infinity, alignment: .center)
        }
    }

    // MARK: - Bottom bar

    @ViewBuilder
    private var bottomBar: some View {
        if store.isPlaying {
            EditToolbar(dimmed: true, rotationActive: currentRotationActive, canSave: canSave)
                .padding(.bottom, 16)
        } else {
            EditToolbar(
                rotationActive: currentRotationActive,
                canSave: canSave,
                onRotate: { rotateCurrentClip() },
                onDelete: { store.send(.deleteCurrentRequested) },
                onSave: {
                    store.send(.saveTapped)
                    router.push(.export)
                }
            )
            .padding(.bottom, 16)
        }
    }

    // MARK: - Rotation (session 환경 객체 사용)

    private var currentRotationActive: Bool {
        guard let id = store.currentClip?.id else { return false }
        return session.rotation(for: id) != .r0
    }

    private func rotateCurrentClip() {
        guard let id = store.currentClip?.id else { return }
        session.cycleRotation(for: id)
        store.send(.rotateCurrentTapped)
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
    }
}

// MARK: - Pulse dot (header)

private struct PulseDot: View {
    var body: some View {
        Circle()
            .fill(ChalNaColor.coral)
            .frame(width: 6, height: 6)
            .overlay(Circle().stroke(ChalNaColor.coral.opacity(0.3), lineWidth: 3).padding(-3))
    }
}

// MARK: - Previews

#Preview("Idle") {
    TimelineView()
        .environment(AppRouter())
        .environment(EditSession())
}

#Preview("Playing") {
    TimelineView(
        store: Store(initialState: TimelineFeature.State(currentIndex: 3, playbackState: .playing, playheadSeconds: 35)) {
            TimelineFeature()
        }
    )
    .environment(AppRouter())
    .environment(EditSession())
}
