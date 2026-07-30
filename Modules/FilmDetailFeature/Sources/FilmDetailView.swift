import SwiftUI
import SwiftData
import AVKit
import AVFoundation
import ComposableArchitecture
import Models
import DesignSystem
import FileStorage

/// 라이브러리 필름 1개의 메타 정보 + 재생/공유/삭제 액션 화면.
public struct FilmDetailView: View {
    @Environment(\.modelContext) private var modelContext

    @Bindable var store: StoreOf<FilmDetailFeature>

    @Query private var films: [Film]
    @State private var scrollProgress: Double = 0

    public init(store: StoreOf<FilmDetailFeature>) {
        self.store = store
        let id = store.filmID
        _films = Query(filter: #Predicate<Film> { $0.id == id })
    }

    public var body: some View {
        VStack(spacing: 0) {
            header
                .zIndex(1)

            if let film = films.first {
                content(for: film)
            } else {
                missingFilmState
            }
        }
        .chalNaScreen()
        .onAppear { store.send(.onAppear) }
    }

    // MARK: - Header

    private var header: some View {
        ChalNaNavBar(
            title: "필름 정보",
            leading: .back { store.send(.backTapped) }
        )
        .chalNaScrollHairline(progress: scrollProgress)
    }

    // MARK: - Content

    @ViewBuilder
    private func content(for film: Film) -> some View {
        let movieURL = film.movieURL
        let isPlayable = movieURL != nil

        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                // 파일이 없으면 안내를 가장 먼저 노출해 아래 비활성 버튼의 이유를 먼저 설명한다.
                if !isPlayable {
                    missingFileNotice
                        .onAppear { store.send(.missingFileNoticed) }
                }

                posterHero(for: film, isPlayable: isPlayable)
                    .trackScrollOffset(in: "film-detail-scroll")

                titleBlock(for: film)

                metaTags(for: film)

                actionButtons(canPlayOrShare: isPlayable)
                    .padding(.top, 8)
            }
            .padding(.horizontal, 20)
            .padding(.top, 12)
            .padding(.bottom, 32)
        }
        .coordinateSpace(name: "film-detail-scroll")
        .onPreferenceChange(ScrollOffsetPreferenceKey.self) { offset in
            withAnimation(.easeInOut(duration: 0.15)) {
                scrollProgress = offset / 8
            }
        }
        .sheet(
            isPresented: $store.isPlayerPresented.sending(\.playerPresentedChanged)
        ) {
            if let url = movieURL {
                ZStack {
                    ChalNaColor.canvas.ignoresSafeArea()
                    VideoPlayerCover(url: url) {
                        store.send(.playerPresentedChanged(false))
                    }
                }
                .presentationDragIndicator(.visible)
                .presentationBackground(ChalNaColor.canvas)
                // RootView 의 전역 Dynamic Type 상한(.dynamicTypeSize(...accessibility1))은
                // sheet 경계를 넘어 전달되지 않는다(실측 확인) — 여기서 다시 건다.
                .dynamicTypeSize(...DynamicTypeSize.accessibility1)
            }
        }
        .sheet(
            isPresented: $store.isShareSheetPresented.sending(\.shareSheetPresentedChanged)
        ) {
            if let url = movieURL {
                ShareSheet(activityItems: [url])
                    // RootView 의 전역 Dynamic Type 상한(.dynamicTypeSize(...accessibility1))은
                    // sheet 경계를 넘어 전달되지 않는다(실측 확인) — 여기서 다시 건다.
                    .dynamicTypeSize(...DynamicTypeSize.accessibility1)
            }
        }
        .alert(
            "필름을 삭제할까요?",
            isPresented: $store.isDeleteAlertPresented.sending(\.deleteAlertPresentedChanged)
        ) {
            Button("삭제", role: .destructive) {
                performDelete(film: film)
            }
            Button("취소", role: .cancel) {
                store.send(.deleteAlertPresentedChanged(false))
            }
        } message: {
            Text("이 필름과 영상 파일이 모두 사라져요. 되돌릴 수 없어요.")
        }
    }

    // MARK: - Poster hero (9:16, 폭 상한 240pt)

    /// 9:16 출력 비율 포스터.
    ///
    /// ScrollView 안에서는 높이 제안이 무한이라 `aspectRatio(.fit)` 이 폭을 역산해
    /// 레이아웃이 부풀 수 있다(실측: `.frame(maxWidth: 240).aspectRatio(9/16, contentMode: .fit)`
    /// 조합이 240×643pt로 부풀어 아래 태그/버튼이 화면 밖으로 밀려남 — SwiftUI 의
    /// `aspectRatio`가 ScrollView 안에서 자주 보이는 알려진 결함).
    /// 폭 상한(240)에서 높이를 직접 산술로 고정해 이 불안정성을 우회한다.
    /// (기존에는 이걸 300pt 고정으로 우회했다)
    private func posterHero(for film: Film, isPlayable: Bool) -> some View {
        let width: CGFloat = 240
        return ZStack(alignment: .bottomTrailing) {
            posterThumbnail(for: film, isPlayable: isPlayable)
            durationBadge(for: film).padding(12)
        }
        .frame(width: width, height: width * 16 / 9)
        .frame(maxWidth: .infinity)
    }

    private func posterThumbnail(for film: Film, isPlayable: Bool) -> some View {
        ZStack {
            ChalNaColor.canvas

            if let data = film.thumbnailData, let image = UIImage(data: data) {
                Image(uiImage: image).resizable().scaledToFill()
            } else {
                ThumbnailPreset.jejuOrange.view()
            }

            // 파일이 사라진 필름은 포스터를 덮어 재생 불가 상태를 즉시 알린다.
            if !isPlayable {
                ChalNaColor.scrim
                ChalNaIcon(.film, size: 40, weight: .light)
                    .foregroundColor(ChalNaColor.textSecondary)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .clipShape(RoundedRectangle(cornerRadius: ChalNaRadius.md, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: ChalNaRadius.md, style: .continuous)
                .strokeBorder(ChalNaColor.border, lineWidth: 1)
        )
    }

    private func durationBadge(for film: Film) -> some View {
        ChalNaTag(Self.durationLabel(film.totalDurationSeconds), variant: .neutral)
            .accessibilityLabel(Text(verbatim: "총 길이 \(Self.durationLabel(film.totalDurationSeconds))"))
    }

    // MARK: - Title + date

    private func titleBlock(for film: Film) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(verbatim: film.title)
                .font(ChalNaTypography.display)
                .foregroundColor(ChalNaColor.textPrimary)
                .lineLimit(3)

            Text(film.createdAt, format: .dateTime.year().month().day().weekday())
                .font(ChalNaTypography.label)
                .foregroundColor(ChalNaColor.textSecondary)
                .lineLimit(2)
        }
    }

    // MARK: - Meta tags (클립 / Live / Video — 길이는 포스터 배지로 이동)

    /// 클립 / Live / Video 를 태그 한 줄로. 카드 3개는 정보량 대비 과했고,
    /// 그 공간을 포스터에 돌려준다.
    private func metaTags(for film: Film) -> some View {
        let videoCount = max(film.clipCount - film.liveCount, 0)
        return HStack(spacing: 8) {
            ChalNaTag("\(String(localized: "클립")) \(film.clipCount)", variant: .neutral)
            ChalNaTag("\(String(localized: "Live")) \(film.liveCount)", variant: .live)
            ChalNaTag("\(String(localized: "Video")) \(videoCount)", variant: .video, icon: .video)
            Spacer(minLength: 0)
        }
    }

    private var missingFileNotice: some View {
        ChalNaNotice(
            icon: .film,
            title: "영상 파일을 찾을 수 없어요",
            message: "앱을 다시 설치하셨거나 파일이 삭제되었어요. 재생과 공유는 불가능하고, 라이브러리에서 항목을 정리할 수 있어요."
        )
    }

    private func actionButtons(canPlayOrShare: Bool) -> some View {
        VStack(spacing: 10) {
            HStack(spacing: 10) {
                Button {
                    store.send(.playTapped)
                } label: {
                    HStack(spacing: 8) {
                        ChalNaIcon(.play, size: 16, weight: .semibold)
                        Text("재생")
                    }
                }
                .buttonStyle(.chalNa(.primary, size: .lg, fillWidth: true))
                .disabled(!canPlayOrShare)
                .accessibilityLabel("재생")
                .accessibilityHint(canPlayOrShare ? "" : "영상 파일을 찾을 수 없어요")

                Button {
                    store.send(.shareTapped)
                } label: {
                    HStack(spacing: 8) {
                        ChalNaIcon(.share, size: 16, weight: .semibold)
                        Text("공유")
                    }
                }
                .buttonStyle(.chalNa(.secondary, size: .lg, fillWidth: true))
                .disabled(!canPlayOrShare)
                .accessibilityLabel("공유")
                .accessibilityHint(canPlayOrShare ? "" : "영상 파일을 찾을 수 없어요")
            }

            // 파괴적 액션은 ghost + destructive 로 1차 CTA 와 위계를 분리한다.
            // (기존에는 .chalNa(.text) 가 coral 고정이라 커스텀 라벨로 우회했다)
            Button {
                store.send(.deleteTapped)
            } label: {
                HStack(spacing: 8) {
                    ChalNaIcon(.trash, size: 16, weight: .semibold)
                    Text("필름 삭제")
                }
                .frame(maxWidth: .infinity)
            }
            .buttonStyle(.chalNa(.ghost, size: .lg, fillWidth: true, destructive: true))
            .accessibilityLabel("필름 삭제")
        }
    }

    // MARK: - Missing film fallback

    private var missingFilmState: some View {
        ChalNaEmptyState(
            icon: .film,
            title: "필름을 찾을 수 없어요",
            message: "이미 삭제되었거나 다른 기기에서 동기화 중일 수 있어요.",
            actionTitle: "홈으로"
        ) {
            store.send(.backTapped)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // MARK: - Delete pipeline

    private func performDelete(film: Film) {
        FilmStorage.deleteMovie(filename: film.movieFilename)
        modelContext.delete(film)
        try? modelContext.save()
        store.send(.deleteConfirmed)   // reducer 가 dismiss 처리
    }

    // MARK: - Formatters

    private static func durationLabel(_ seconds: Double) -> String {
        let total = Int(seconds.rounded())
        return String(format: "%02d:%02d", total / 60, total % 60)
    }
}

// MARK: - UIKit Bridges

private struct VideoPlayerCover: UIViewControllerRepresentable {
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

private struct ShareSheet: UIViewControllerRepresentable {
    let activityItems: [Any]

    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: activityItems, applicationActivities: nil)
    }

    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}
