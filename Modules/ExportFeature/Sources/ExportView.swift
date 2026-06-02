import SwiftUI
import ComposableArchitecture
import FileStorage
import AppCore
import CompositionService
import Models
import DesignSystem
import SwiftData
import Photos
import AVKit
import AVFoundation

/// Timeline에서 "저장"을 누르면 진입. AVFoundationCompositionService 를 구동해 mp4 를 만든다.
public struct ExportView: View {
    @Environment(AppRouter.self) private var router
    @Environment(EditSession.self) private var session
    @Environment(\.modelContext) private var modelContext

    @Bindable var store: StoreOf<ExportFeature>

    public init(store: StoreOf<ExportFeature> = Store(initialState: ExportFeature.State()) { ExportFeature() }) {
        self.store = store
    }

    public var body: some View {
        VStack(spacing: 0) {
            header.chalNaHeaderBar(scrollProgress: 1)

            GeometryReader { proxy in
                VStack(spacing: 0) {
                    cover(width: coverWidth(forAvailableHeight: proxy.size.height))
                        .padding(.top, 16)
                        .padding(.horizontal, 32)

                    statusBlock
                        .padding(.horizontal, 24)
                        .padding(.top, 32)

                    Spacer(minLength: 16)

                    bottomCTAs
                        .padding(.horizontal, 16)
                        .padding(.bottom, 24)
                }
                .frame(width: proxy.size.width, height: proxy.size.height)
            }
        }
        .chalNaScreen()
        .onAppear {
            guard store.phase == .idle else { return }
            store.send(.startExport(clips: session.clips, rotations: session.rotations, clipLabels: session.labels))
        }
        .onDisappear {
            store.send(.dismissTapped)
        }
        .onChange(of: store.exportedURL) { _, newURL in
            if let newURL, !store.didAddToLibrary {
                addCompletedFilmToLibrary(at: newURL)
                store.send(.markAddedToLibrary)
            }
        }
        .overlay(alignment: .bottom) {
            if let toast = store.saveToast {
                Text(toast)
                    .font(ChalNaTypography.krBody(13, weight: .medium))
                    .foregroundColor(.white)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 8)
                    .background(Capsule().fill(ChalNaColor.ink.opacity(0.9)))
                    .padding(.bottom, 64)
                    .transition(.opacity.combined(with: .move(edge: .bottom)))
                    .task(id: toast) {
                        try? await Task.sleep(nanoseconds: 2_200_000_000)
                        store.send(.toastDismissed)
                    }
            }
        }
        .animation(.easeInOut(duration: 0.2), value: store.saveToast)
        .fullScreenCover(
            isPresented: $store.isPlayerPresented.sending(\.playerPresentedChanged)
        ) {
            if let url = store.exportedURL {
                ZStack(alignment: .topTrailing) {
                    Color.black.ignoresSafeArea()

                    ExportVideoPlayerCover(url: url) {
                        store.send(.playerPresentedChanged(false))
                    }
                    .ignoresSafeArea()

                    Button {
                        store.send(.playerPresentedChanged(false))
                    } label: {
                        ChalNaIcon(.close, size: 18)
                            .foregroundColor(.white)
                            .frame(width: 36, height: 36)
                            .background(Circle().fill(Color.black.opacity(0.5)))
                            .overlay(Circle().strokeBorder(Color.white.opacity(0.25), lineWidth: 1))
                    }
                    .padding(.top, 12)
                    .padding(.trailing, 16)
                    .accessibilityLabel("재생 닫기")
                }
            }
        }
    }

    // MARK: - Film library

    private func addCompletedFilmToLibrary(at sourceURL: URL) {
        let clips = session.clips
        let filmID = UUID()
        let movieFilename: String?
        do {
            movieFilename = try FilmStorage.importMovie(from: sourceURL, filmID: filmID)
        } catch {
            movieFilename = nil
        }

        let liveCount = clips.filter { $0.kind == .live }.count
        let totalDuration = clips.reduce(0) { $0 + $1.duration }
        let title = session.title.isEmpty ? "ChalNa" : session.title
        let thumbnail = clips.first?.thumbnailData

        let film = Film(
            id: filmID,
            title: title,
            createdAt: .now,
            movieFilename: movieFilename,
            thumbnailData: thumbnail,
            clipCount: clips.count,
            liveCount: liveCount,
            totalDurationSeconds: totalDuration
        )
        modelContext.insert(film)
        try? modelContext.save()
    }

    // MARK: - Header

    private var header: some View {
        VStack(spacing: 2) {
            Text(store.phase.title)
                .font(ChalNaTypography.krSemibold(15))
                .foregroundColor(ChalNaColor.ink)
            Text(store.phase.tag)
                .tagLabel(color: tagColor)
        }
        .frame(maxWidth: .infinity)
    }

    private var tagColor: Color {
        switch store.phase {
        case .idle, .exporting: return ChalNaColor.coral
        case .done:             return ChalNaColor.sage
        case .failed:           return ChalNaColor.taupe
        }
    }

    // MARK: - Cover

    private func coverWidth(forAvailableHeight available: CGFloat) -> CGFloat {
        let reservedHeight: CGFloat = switch store.phase {
        case .idle, .exporting: 210
        case .done:             300
        case .failed:           290
        }
        let envelope = max(available - reservedHeight, 200)
        let widthFromHeight = (envelope - 60) * 16 / 9
        return min(max(widthFromHeight, 240), 360)
    }

    @ViewBuilder
    private func cover(width: CGFloat) -> some View {
        if let clip = session.clips.first {
            let canPlay = store.phase == .done && store.exportedURL != nil
            VStack(alignment: .leading, spacing: 12) {
                ZStack(alignment: .topTrailing) {
                    Button {
                        guard canPlay else { return }
                        store.send(.playerPresentedChanged(true))
                    } label: {
                        clip.thumbnailView()
                            .frame(width: width, height: width * 9 / 16)
                            .clipShape(RoundedRectangle(cornerRadius: ChalNaRadius.card, style: .continuous))
                            .overlay(
                                RoundedRectangle(cornerRadius: ChalNaRadius.card, style: .continuous)
                                    .strokeBorder(ChalNaColor.Gray.g100, lineWidth: 0.5)
                            )
                            .overlay {
                                if canPlay {
                                    playOverlay
                                }
                            }
                    }
                    .buttonStyle(.plain)
                    .disabled(!canPlay)
                    .accessibilityLabel(canPlay ? "완성된 영상 재생" : "")
                    .accessibilityAddTraits(canPlay ? .isButton : [])

                    if store.phase == .done {
                        ChalNaChip("DONE", variant: .selected, icon: .check)
                            .padding(12)
                            .allowsHitTesting(false)
                    }
                }

                VStack(alignment: .leading, spacing: 4) {
                    Text(session.title.isEmpty ? SampleData.filmTitle : session.title)
                        .font(ChalNaTypography.title(ChalNaTypography.Size.h2, weight: .semibold))
                        .foregroundColor(ChalNaColor.ink)
                        .lineLimit(1)
                    Text(metaLine)
                        .font(ChalNaTypography.monoFallback(ChalNaTypography.Size.caption))
                        .foregroundColor(ChalNaColor.taupe)
                }
            }
            .frame(width: width)
            .frame(maxWidth: .infinity)
        } else {
            Text("내보낼 클립이 없어요")
                .font(ChalNaTypography.krBody(ChalNaTypography.Size.body, weight: .semibold))
                .foregroundColor(ChalNaColor.taupe)
        }
    }

    private var metaLine: String {
        let count = session.clips.count
        let videos = session.clips.filter { $0.videoURL != nil }.count
        let total = session.clips.reduce(0) { $0 + $1.duration }
        let m = Int(total) / 60
        let s = Int(total) % 60
        return String(format: "%d CLIPS · %d VIDEO · %02d:%02d", count, videos, m, s)
    }

    // MARK: - Status

    @ViewBuilder
    private var statusBlock: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text(statusLabelLeft).tagLabel(color: tagColor)
                Spacer()
                if store.phase != .failed {
                    Text("\(Int(store.progress * 100))%")
                        .font(ChalNaTypography.monoFallback(12, weight: .semibold))
                        .foregroundColor(ChalNaColor.ink)
                }
            }

            GeometryReader { proxy in
                ZStack(alignment: .leading) {
                    Capsule()
                        .fill(ChalNaColor.ivory)
                        .frame(height: 6)
                    Capsule()
                        .fill(store.phase == .failed ? ChalNaColor.taupe : ChalNaColor.coral)
                        .frame(width: max(0, proxy.size.width * store.progress), height: 6)
                }
            }
            .frame(height: 6)
            .accessibilityElement(children: .ignore)
            .accessibilityLabel("내보내기 진행률")
            .accessibilityValue(String(localized: "\(Int(store.progress * 100))퍼센트"))

            Text(statusLine)
                .font(ChalNaTypography.krBody(13))
                .foregroundColor(ChalNaColor.taupe)
        }
    }

    private var statusLabelLeft: String {
        switch store.phase {
        case .idle, .exporting: return String(localized: "EXPORT · IN PROGRESS")
        case .done:             return String(localized: "EXPORT · COMPLETE")
        case .failed:           return String(localized: "EXPORT · FAILED")
        }
    }

    private var statusLine: String {
        switch store.phase {
        case .idle, .exporting:
            return String(localized: "Vlog를 엮는 중… Live Photo의 영상 부분을 자동으로 추출해 이어 붙여요.")
        case .done:
            return String(localized: "필름이 완성되었어요. 공유하거나 사진 보관함에 저장할 수 있어요.")
        case .failed:
            return store.errorMessage ?? String(localized: "저장 중 문제가 발생했어요.")
        }
    }

    // MARK: - CTAs

    @ViewBuilder
    private var bottomCTAs: some View {
        switch store.phase {
        case .idle, .exporting:
            HStack(spacing: 8) {
                ChalNaIcon(.film, size: 14).foregroundColor(ChalNaColor.taupe)
                Text("잠깐만 기다려주세요")
                    .font(ChalNaTypography.krBody(ChalNaTypography.Size.body))
                    .foregroundColor(ChalNaColor.taupe)
            }
            .frame(maxWidth: .infinity, alignment: .center)
        case .done:
            completedCTAs
        case .failed:
            failedCTAs
        }
    }

    @ViewBuilder
    private var completedCTAs: some View {
        if #available(iOS 26.0, *) {
            liquidGlassCompletedCTAs
        } else {
            paperCompletedCTAs
        }
    }

    private var paperCompletedCTAs: some View {
        VStack(spacing: 12) {
            if let url = store.exportedURL {
                HStack(spacing: 12) {
                    ShareLink(item: url) {
                        HStack(spacing: 6) {
                            ChalNaIcon(.share, size: 14)
                            Text("공유하기")
                        }
                        .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.chalNaOutline)
                    .frame(maxWidth: .infinity)

                    Button {
                        store.send(.saveToPhotoLibraryTapped)
                    } label: {
                        HStack(spacing: 6) {
                            if store.isSaving {
                                ProgressView().controlSize(.small).tint(ChalNaColor.ink)
                            } else {
                                ChalNaIcon(.download, size: 14)
                            }
                            Text(store.isSaving ? "저장 중…" : "저장하기")
                        }
                        .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.chalNaCoral)
                    .frame(maxWidth: .infinity)
                    .disabled(store.isSaving)
                }
            }

            HStack(spacing: 12) {
                Button("다른 영상 만들기") { startAnotherFilm() }
                    .buttonStyle(.chalNaOutline)
                    .frame(maxWidth: .infinity)

                Button("홈으로 →") {
                    store.send(.homeTapped)
                    router.popToRoot()
                }
                .buttonStyle(.chalNaText)
                .frame(maxWidth: .infinity)
            }
        }
    }

    @available(iOS 26.0, *)
    private var liquidGlassCompletedCTAs: some View {
        GlassEffectContainer(spacing: 12) {
            VStack(spacing: 12) {
                if let url = store.exportedURL {
                    HStack(spacing: 12) {
                        ShareLink(item: url) {
                            HStack(spacing: 6) {
                                ChalNaIcon(.share, size: 14)
                                Text("공유하기")
                            }
                            .foregroundStyle(ChalNaColor.ink)
                            .frame(maxWidth: .infinity, minHeight: 44)
                        }
                        .buttonStyle(.glass)
                        .frame(maxWidth: .infinity)

                        Button {
                            store.send(.saveToPhotoLibraryTapped)
                        } label: {
                            HStack(spacing: 6) {
                                if store.isSaving {
                                    ProgressView().controlSize(.small).tint(ChalNaColor.ink)
                                } else {
                                    ChalNaIcon(.download, size: 14)
                                }
                                Text(store.isSaving ? "저장 중…" : "저장하기")
                            }
                            .foregroundStyle(ChalNaColor.ink)
                            .frame(maxWidth: .infinity, minHeight: 44)
                        }
                        .buttonStyle(.glassProminent)
                        .tint(ChalNaColor.coral)
                        .frame(maxWidth: .infinity)
                        .disabled(store.isSaving)
                    }
                }

                HStack(spacing: 12) {
                    Button {
                        startAnotherFilm()
                    } label: {
                        Text("다른 영상 만들기")
                            .foregroundStyle(ChalNaColor.ink)
                            .frame(maxWidth: .infinity, minHeight: 44)
                    }
                    .buttonStyle(.glass)
                    .frame(maxWidth: .infinity)

                    Button {
                        store.send(.homeTapped)
                        router.popToRoot()
                    } label: {
                        Text("홈으로 →")
                            .foregroundStyle(ChalNaColor.ink)
                            .frame(maxWidth: .infinity, minHeight: 44)
                    }
                    .buttonStyle(.glass)
                    .frame(maxWidth: .infinity)
                }
            }
        }
    }

    @ViewBuilder
    private var failedCTAs: some View {
        if #available(iOS 26.0, *) {
            liquidGlassFailedCTAs
        } else {
            paperFailedCTAs
        }
    }

    private var paperFailedCTAs: some View {
        VStack(spacing: 12) {
            Button {
                store.send(.retryTapped(clips: session.clips, rotations: session.rotations, clipLabels: session.labels))
            } label: {
                HStack(spacing: 8) {
                    ChalNaIcon(.plus, size: 14)
                    Text("다시 시도")
                }
                .frame(maxWidth: .infinity)
            }
            .buttonStyle(.chalNaCoral)

            Button("편집으로 돌아가기") { router.pop() }
                .buttonStyle(.chalNaOutline)
                .frame(maxWidth: .infinity)
        }
    }

    @available(iOS 26.0, *)
    private var liquidGlassFailedCTAs: some View {
        GlassEffectContainer(spacing: 12) {
            VStack(spacing: 12) {
                Button {
                    store.send(.retryTapped(clips: session.clips, rotations: session.rotations, clipLabels: session.labels))
                } label: {
                    HStack(spacing: 8) {
                        ChalNaIcon(.plus, size: 14)
                        Text("다시 시도")
                    }
                    .foregroundStyle(ChalNaColor.ink)
                    .frame(maxWidth: .infinity, minHeight: 44)
                }
                .buttonStyle(.glassProminent)
                .tint(ChalNaColor.coral)

                Button {
                    router.pop()
                } label: {
                    Text("편집으로 돌아가기")
                        .foregroundStyle(ChalNaColor.ink)
                        .frame(maxWidth: .infinity, minHeight: 44)
                }
                .buttonStyle(.glass)
                .frame(maxWidth: .infinity)
            }
        }
    }

    private func startAnotherFilm() {
        store.send(.startAnotherTapped)
        session.clear()
        router.popToRoot()
        router.push(.mediaPicker)
    }

    // MARK: - Play overlay

    private var playOverlay: some View {
        ZStack {
            Color.black.opacity(0.18)
            Circle()
                .fill(.ultraThinMaterial)
                .frame(width: 64, height: 64)
                .overlay(
                    Circle().strokeBorder(Color.white.opacity(0.55), lineWidth: 1)
                )
                .overlay(
                    ChalNaIcon(.play, size: 28)
                        .foregroundColor(ChalNaColor.ink)
                        .offset(x: 2)
                )
                .shadow(color: Color.black.opacity(0.18), radius: 8, x: 0, y: 4)
        }
        .clipShape(RoundedRectangle(cornerRadius: ChalNaRadius.card, style: .continuous))
    }
}

// MARK: - Video player bridge

private struct ExportVideoPlayerCover: UIViewControllerRepresentable {
    let url: URL
    let onDismiss: () -> Void

    func makeUIViewController(context: Context) -> AVPlayerViewController {
        // 무음 스위치가 켜져 있어도 영상 사운드가 재생되도록 playback 카테고리로 활성화.
        let session = AVAudioSession.sharedInstance()
        try? session.setCategory(.playback, mode: .moviePlayback, options: [])
        try? session.setActive(true)

        let player = AVPlayer(url: url)
        let controller = AVPlayerViewController()
        controller.player = player
        controller.allowsPictureInPicturePlayback = true
        controller.delegate = context.coordinator
        player.play()
        return controller
    }

    func updateUIViewController(_ uiViewController: AVPlayerViewController, context: Context) {}

    func makeCoordinator() -> Coordinator { Coordinator(onDismiss: onDismiss) }

    final class Coordinator: NSObject, AVPlayerViewControllerDelegate {
        let onDismiss: () -> Void
        init(onDismiss: @escaping () -> Void) { self.onDismiss = onDismiss }

        func playerViewController(_ playerViewController: AVPlayerViewController, willEndFullScreenPresentationWithAnimationCoordinator coordinator: any UIViewControllerTransitionCoordinator) {
            coordinator.animate(alongsideTransition: nil) { [weak self] _ in
                self?.onDismiss()
            }
        }
    }
}

#Preview("Exporting") {
    let session = EditSession(title: SampleData.filmTitle, clips: SampleData.jejuTimeline)
    return ExportView(
        store: Store(initialState: ExportFeature.State(phase: .exporting, progress: 0.5)) {
            ExportFeature()
        }
    )
    .environment(AppRouter())
    .environment(session)
    .modelContainer(for: Film.self, inMemory: true)
}

#Preview("Done") {
    let session = EditSession(title: SampleData.filmTitle, clips: SampleData.jejuTimeline)
    return ExportView(
        store: Store(initialState: ExportFeature.State(
            phase: .done,
            progress: 1.0,
            exportedURL: URL(fileURLWithPath: "/tmp/preview.mp4")
        )) {
            ExportFeature()
        }
    )
    .environment(AppRouter())
    .environment(session)
    .modelContainer(for: Film.self, inMemory: true)
}
