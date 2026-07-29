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
import UIKit

/// Timeline에서 "저장"을 누르면 진입. AVFoundationCompositionService 를 구동해 mp4 를 만든다.
public struct ExportView: View {
    @Environment(EditSession.self) private var session
    @Environment(\.modelContext) private var modelContext

    @Bindable var store: StoreOf<ExportFeature>

    public init(store: StoreOf<ExportFeature> = Store(initialState: ExportFeature.State()) { ExportFeature() }) {
        self.store = store
    }

    public var body: some View {
        VStack(spacing: 0) {
            header

            VStack(spacing: 0) {
                Spacer(minLength: 12)

                cover
                    .padding(.horizontal, 20)

                Spacer(minLength: 12)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .chalNaScreen()
        .safeAreaInset(edge: .bottom) { bottomCTAs }
        .chalNaToast(message: store.saveToast) { store.send(.toastDismissed) }
        .onAppear {
            guard store.phase == .idle else { return }
            store.send(.startExport(clips: session.clips, rotations: session.rotations, transforms: session.transforms, clipLabels: session.labels))
        }
        .onDisappear {
            UIApplication.shared.isIdleTimerDisabled = false
            store.send(.viewDisappeared)
        }
        // 영상 합성 중에는 화면 자동 잠금(idle timer)을 막아 작업이 중단되지 않게 한다.
        .onChange(of: store.phase) { _, newPhase in
            UIApplication.shared.isIdleTimerDisabled = (newPhase == .exporting)
        }
        .onChange(of: store.exportedURL) { _, newURL in
            if let newURL, !store.didAddToLibrary {
                addCompletedFilmToLibrary(at: newURL)
                store.send(.markAddedToLibrary)
            }
        }
        .fullScreenCover(
            isPresented: $store.isPlayerPresented.sending(\.playerPresentedChanged)
        ) {
            if let url = store.exportedURL {
                ZStack(alignment: .topTrailing) {
                    ChalNaColor.canvas.ignoresSafeArea()

                    ExportVideoPlayerCover(url: url) {
                        store.send(.playerPresentedChanged(false))
                    }
                    .ignoresSafeArea()

                    Button {
                        store.send(.playerPresentedChanged(false))
                    } label: {
                        ChalNaIcon(.close, size: 18, weight: .semibold)
                            .foregroundColor(ChalNaColor.textPrimary)
                            .frame(width: 44, height: 44)
                            .background(Circle().fill(ChalNaColor.surfaceRaised.opacity(0.8)))
                            .overlay(Circle().strokeBorder(ChalNaColor.border, lineWidth: 1))
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
        // ExportPhase.title/.tag 는 String(localized:) 로 이미 해석된 String 이다
        // (ExportFeature.swift:256,264). 다시 감싸면 이중 조회가 된다.
        ChalNaNavBar(
            verbatimTitle: store.phase.title,
            caption: store.phase.tag,
            showsDivider: true
        )
    }

    // MARK: - Cover

    /// 9:16 커버. 진행률·완료 배지를 **커버 위에** 얹어 시선을 한 곳에 모은다.
    /// (기존에는 커버와 statusBlock 이 분리돼 시선이 두 곳으로 갈렸다)
    @ViewBuilder
    private var cover: some View {
        if let clip = session.clips.first {
            let canPlay = store.phase == .done && store.exportedURL != nil

            VStack(alignment: .leading, spacing: 12) {
                ChalNaCanvas { box in
                    clip.thumbnailView(contentMode: .fill)
                        .frame(width: box.width, height: box.height)
                } overlay: { _ in
                    coverOverlay(canPlay: canPlay)
                }
                // 이 두 modifier 는 여기서 상한으로만 작동한다. `cover` 는 header + safeAreaInset
                // 사이의 이미 제한된 높이 예산 안에 있고, `ChalNaCanvas` 내부 GeometryReader 가
                // 그 높이를 그대로 받아 9:16 을 맞추기 때문이다(넓은 기기에서는 maxWidth 300 이 폭을 제한).
                // 높이가 무제약인 컨텍스트(예: ScrollView) 에 이 조합을 그대로 옮기면
                // aspectRatio(.fit) 가 무한 높이로 폭을 역산해 깨진다 — Task 19 FilmDetailView 가
                // 그 사례(240×643 로 잘못 렌더링)이므로 그대로 복사하지 말 것.
                .frame(maxWidth: 300)
                .aspectRatio(9.0 / 16.0, contentMode: .fit)
                .frame(maxWidth: .infinity)
                .contentShape(Rectangle())
                .onTapGesture {
                    guard canPlay else { return }
                    store.send(.playerPresentedChanged(true))
                }
                .accessibilityAddTraits(canPlay ? .isButton : [])
                .accessibilityLabel(canPlay ? "완성된 영상 재생" : "")

                VStack(alignment: .leading, spacing: 4) {
                    Text(verbatim: session.title.isEmpty ? SampleData.filmTitle : session.title)
                        .font(ChalNaTypography.title)
                        .foregroundColor(ChalNaColor.textPrimary)
                        .lineLimit(1)
                    Text(verbatim: metaLine)
                        .font(ChalNaTypography.mono())
                        .foregroundColor(ChalNaColor.textSecondary)
                    Text(statusLine)
                        .font(ChalNaTypography.label)
                        .foregroundColor(ChalNaColor.textSecondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .frame(maxWidth: 300, alignment: .leading)
                .frame(maxWidth: .infinity, alignment: .center)
            }
        } else {
            Text("내보낼 클립이 없어요")
                .font(ChalNaTypography.headline)
                .foregroundColor(ChalNaColor.textSecondary)
        }
    }

    /// 커버 위 오버레이: 진행 중이면 하단 진행률 바 + 퍼센트, 완료면 재생 버튼 + DONE 태그.
    @ViewBuilder
    private func coverOverlay(canPlay: Bool) -> some View {
        ZStack {
            if canPlay {
                playOverlay
            }

            VStack(spacing: 0) {
                HStack {
                    Spacer()
                    if store.phase == .done {
                        ChalNaTag("DONE", variant: .accent, icon: .check)
                    }
                }
                .padding(12)

                Spacer()

                if store.phase != .done {
                    VStack(spacing: 6) {
                        HStack {
                            Text(verbatim: "\(Int(store.progress * 100))%")
                                .font(ChalNaTypography.mono(.footnote, weight: .semibold))
                                .foregroundColor(ChalNaColor.textPrimary)
                            Spacer()
                        }
                        ChalNaProgressBar(
                            progress: store.progress,
                            tint: store.phase == .failed ? ChalNaColor.danger : ChalNaColor.accent
                        )
                    }
                    .padding(12)
                    .background(ChalNaColor.scrim)
                }
            }
        }
    }

    private var playOverlay: some View {
        ZStack {
            ChalNaColor.scrim.opacity(0.4)
            Circle()
                .fill(ChalNaColor.surfaceRaised.opacity(0.9))
                .frame(width: 64, height: 64)
                .overlay(Circle().strokeBorder(ChalNaColor.border, lineWidth: 1))
                .overlay(
                    ChalNaIcon(.play, size: 26, weight: .semibold)
                        .foregroundColor(ChalNaColor.textPrimary)
                )
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
        Group {
            switch store.phase {
            case .idle, .exporting:
                HStack(spacing: 8) {
                    ChalNaIcon(.film, size: 14)
                    Text("잠깐만 기다려주세요")
                }
                .font(ChalNaTypography.label)
                .foregroundColor(ChalNaColor.textSecondary)
                .frame(maxWidth: .infinity)
                .frame(minHeight: 52)

            case .done:
                completedCTAs

            case .failed:
                failedCTAs
            }
        }
        .padding(.horizontal, 20)
        .padding(.top, 12)
        .padding(.bottom, 12)
        .background(ChalNaColor.bg.ignoresSafeArea(edges: .bottom))
        .overlay(alignment: .top) {
            Rectangle().fill(ChalNaColor.border).frame(height: 1)
        }
    }

    /// 주 액션 2개(저장·공유)를 면형/선형으로, 보조 2개는 ghost 텍스트로 내려
    /// 위계를 분리한다. 기존에는 4개가 2×2 로 동등해 무엇이 주인지 불명확했다.
    private var completedCTAs: some View {
        VStack(spacing: 8) {
            if let url = store.exportedURL {
                HStack(spacing: 10) {
                    Button {
                        store.send(.saveToPhotoLibraryTapped)
                    } label: {
                        HStack(spacing: 6) {
                            if store.isSaving {
                                ProgressView().controlSize(.small).tint(ChalNaColor.onAccent)
                            } else {
                                ChalNaIcon(.download, size: 16, weight: .semibold)
                            }
                            Text(store.isSaving ? LocalizedStringKey("저장 중…") : LocalizedStringKey("저장하기"))
                        }
                        .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.chalNa(.primary, size: .lg, fillWidth: true))
                    .disabled(store.isSaving)

                    ShareLink(item: url) {
                        HStack(spacing: 6) {
                            ChalNaIcon(.share, size: 16, weight: .semibold)
                            Text("공유")
                        }
                        .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.chalNa(.secondary, size: .lg, fillWidth: true))
                }
            }

            HStack(spacing: 4) {
                Button("다른 영상 만들기") { store.send(.startAnotherTapped) }
                    .buttonStyle(.chalNa(.ghost, size: .md, fillWidth: true))
                Button {
                    store.send(.homeTapped)
                } label: {
                    HStack(spacing: 4) {
                        Text("홈으로")
                        ChalNaIcon(.chevronRight, size: 13, weight: .semibold)
                    }
                    .frame(maxWidth: .infinity)
                }
                .buttonStyle(.chalNa(.ghost, size: .md, fillWidth: true))
            }
        }
    }

    private var failedCTAs: some View {
        VStack(spacing: 8) {
            Button {
                store.send(.retryTapped(clips: session.clips,
                                        rotations: session.rotations,
                                        transforms: session.transforms,
                                        clipLabels: session.labels))
            } label: {
                Text("다시 시도").frame(maxWidth: .infinity)
            }
            .buttonStyle(.chalNa(.primary, size: .lg, fillWidth: true))

            Button("편집으로 돌아가기") { store.send(.backToEditTapped) }
                .buttonStyle(.chalNa(.ghost, size: .md, fillWidth: true))
        }
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
    .environment(session)
    .modelContainer(for: Film.self, inMemory: true)
}
