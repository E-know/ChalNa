import SwiftUI
import ComposableArchitecture
import AppCore
import Models
import DesignSystem

public struct TimelineView: View {
    @Environment(EditSession.self) private var session
    @Environment(\.verticalSizeClass) private var verticalSizeClass
    @Bindable var store: StoreOf<TimelineFeature>
    @State private var playback = ClipPlaybackController()

    public init(store: StoreOf<TimelineFeature> = Store(initialState: TimelineFeature.State()) { TimelineFeature() }) {
        self.store = store
    }

    public var body: some View {
        GeometryReader { proxy in
            let compactLandscape = verticalSizeClass == .compact && proxy.size.width > proxy.size.height
            let split = ChalNaLayout.isSplit(proxy.size) || compactLandscape
            let grid = !split && proxy.size.width >= 600
            VStack(spacing: 12) {
                if split {
                    HStack(spacing: compactLandscape ? 16 : 48) {
                        VStack(spacing: 12) {
                            HStack {
                                Text("미리보기").font(ChalNaTypography.headline)
                                Spacer()
                                Text(verbatim: "\(store.currentClip == nil ? 0 : store.currentIndex + 1) / \(store.clips.count)")
                                    .font(ChalNaTypography.label).foregroundStyle(ChalNaColor.textSecondary)
                            }
                            preview
                        }
                        .frame(maxWidth: .infinity)
                        sequence(.list)
                            .frame(maxWidth: .infinity)
                    }
                } else if grid {
                    VStack(spacing: 38) {
                        preview.frame(height: max(120, proxy.size.height * 0.44 - 52))
                        sequence(.grid)
                    }
                } else {
                    preview
                    sequence(.strip)
                }
            }
            .padding(.horizontal, compactLandscape ? 16 : split ? 32 : 24)
            .padding(.top, 6)
            .padding(.bottom, 8)
            .foregroundStyle(ChalNaColor.textPrimary)
        }
        .chalNaScreen()
        .navigationTitle(Text(verbatim: store.title.isEmpty ? "ChalNa" : store.title))
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button("필름 만들기", systemImage: "film") { store.send(.saveTapped) }
                    .disabled(store.clips.isEmpty || store.isPlaying)
                    .accessibilityIdentifier("timeline.export")
            }
        }
        .onAppear {
            if !session.clips.isEmpty { store.send(.syncFromSession(clips: session.clips, title: session.title)) }
            playback.onElapsed = { elapsed in store.send(.playheadElapsedUpdated(elapsed)) }
            playback.onClipEnd = {
                guard store.isPlaying else { return }
                store.send(.currentClipEnded)
                if !store.isPlaying { playback.seekToStart() }
            }
            playback.load(clip: store.currentClip)
        }
        .onChange(of: store.isPlaying) { _, playing in
            if playing { playback.play() } else { playback.pause() }
        }
        .onChange(of: store.currentClip) { _, _ in
            playback.load(clip: store.currentClip)
            if store.isPlaying { playback.play() }
        }
        .onDisappear {
            playback.pause()
            playback.onElapsed = nil
            playback.onClipEnd = nil
            if store.isPlaying { store.send(.playbackInterrupted) }
        }
        .alert($store.scope(\.deleteAlert, action: \.deleteAlert))
        .fullScreenCover(item: Binding(get: { store.trimEditorClip }, set: { clip in
            if clip == nil { store.send(.trimDismissed) }
        })) { clip in
            NavigationStack {
                ClipTrimView(
                    clip: clip,
                    onCommit: { store.send(.trimCommitted($0, thumbnail: $1)) },
                    onCancel: { store.send(.trimDismissed) }
                )
            }
            .dynamicTypeSize(...DynamicTypeSize.accessibility1)
        }
        .fullScreenCover(item: Binding(get: { store.labelEditorClip }, set: { clip in
            if clip == nil { store.send(.labelDismissed) }
        })) { clip in
            NavigationStack {
                LabelEditorView(
                    clip: clip, rotation: session.rotation(for: clip.id), transform: session.transform(for: clip.id),
                    initialLabel: session.label(for: clip.id),
                    onCommit: { store.send(.labelCommitted($0)) }, onCancel: { store.send(.labelDismissed) }
                )
            }
            .dynamicTypeSize(...DynamicTypeSize.accessibility1)
        }
    }

    private var preview: some View {
        VStack(spacing: 8) {
            PreviewPanel(store: store, playback: playback)
            TransportControls(store: store)
        }
        .frame(maxWidth: .infinity)
    }

    private func sequence(_ layout: FilmStripLayout) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("클립 순서").font(ChalNaTypography.headline)
                Spacer()
                Text("길게 눌러 이동").font(ChalNaTypography.caption).foregroundStyle(ChalNaColor.textSecondary)
            }
            FilmStripCollectionView(store: store, session: session, layout: layout) { index in
                if index == store.currentIndex { playback.seekToStart() }
                store.send(.clipTapped(index: index))
            }
            .frame(height: layout == .strip ? 74 : nil)
            .clipped()
            if layout != .strip {
                Text("선택한 클립 편집")
                    .font(ChalNaTypography.label)
                    .padding(.vertical, 5)
            }
            EditToolbar(
                adjustActive: store.currentClip.map { session.rotation(for: $0.id) != .r0 || session.transform(for: $0.id) != .fill } ?? false,
                canTrim: store.currentClip?.canTrim == true,
                trimActive: store.currentClip.map { $0.trimRange != 0...$0.sourceDuration } ?? false,
                labelActive: store.currentClip.map { session.label(for: $0.id).isVisible } ?? false,
                onAdjust: { store.send(.adjustCurrentTapped) },
                onTrim: { store.send(.trimTapped) },
                onLabel: { store.send(.labelTapped) },
                onDelete: { store.send(.deleteCurrentRequested) }
            )
            .fixedSize(horizontal: false, vertical: true)
            .layoutPriority(1)
            .disabled(!store.canEditCurrentClip)
            .opacity(store.canEditCurrentClip ? 1 : 0.45)
        }
    }
}

#Preview {
    TimelineView().environment(EditSession(title: SampleData.filmTitle, clips: SampleData.jejuTimeline))
}
