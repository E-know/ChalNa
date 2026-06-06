import SwiftUI
import SwiftData
import AVKit
import AVFoundation
import ComposableArchitecture
import AppCore
import Models
import DesignSystem
import FileStorage

/// 라이브러리 필름 1개의 메타 정보 + 재생/공유/삭제 액션 화면.
public struct FilmDetailView: View {
    @Environment(AppRouter.self) private var router
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
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
                .chalNaHeaderBar(scrollProgress: scrollProgress)
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
        ChalNaNavigationBar(titleKey: "필름 정보") {
            ChalNaHeaderBackButton { router.pop() }
        } trailing: {
            EmptyView()
        }
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

                metaGrid(for: film)

                actionButtons(canPlayOrShare: isPlayable)
                    .padding(.top, 8)
            }
            .padding(.horizontal, 24)
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
                VideoPlayerCover(url: url) {
                    store.send(.playerPresentedChanged(false))
                }
                .ignoresSafeArea()
                .presentationDragIndicator(.visible)
            }
        }
        .sheet(
            isPresented: $store.isShareSheetPresented.sending(\.shareSheetPresentedChanged)
        ) {
            if let url = movieURL {
                ShareSheet(activityItems: [url])
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

    // MARK: - Poster hero (9:16 고정 크기, 가운데 정렬, 단일 길이 배지)

    /// 9:16 출력 비율을 살린 세로 포스터. 세로 ScrollView 안에서는 높이 제안이 무한이라
    /// aspectRatio(.fit)가 폭을 역산해 레이아웃이 화면 밖으로 부풀어 깨진다. 그래서 높이
    /// 300pt 기준 9:16 고정 크기로 두고 가로 가운데 정렬해 한 화면에 메타/액션이 함께 보이게 한다.
    private func posterHero(for film: Film, isPlayable: Bool) -> some View {
        let posterHeight: CGFloat = 300
        return ZStack(alignment: .bottomTrailing) {
            posterThumbnail(for: film, isPlayable: isPlayable)

            durationBadge(for: film)
                .padding(12)
        }
        .frame(width: posterHeight * 9 / 16, height: posterHeight)
        .chalNaShadow(ChalNaShadow.md)
        .frame(maxWidth: .infinity)
    }

    private func posterThumbnail(for film: Film, isPlayable: Bool) -> some View {
        ZStack {
            if let data = film.thumbnailData, let image = UIImage(data: data) {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFill()
            } else {
                ThumbnailPreset.jejuOrange.view()
            }

            // 파일이 사라진 필름은 포스터를 어둡게 덮어 재생 불가 상태를 즉시 알린다.
            if !isPlayable {
                ChalNaColor.Gray.g900.opacity(0.45)
                ChalNaIcon(.film, size: 40)
                    .foregroundColor(Color.white.opacity(0.85))
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .clipShape(RoundedRectangle(cornerRadius: ChalNaRadius.card, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: ChalNaRadius.card, style: .continuous)
                .strokeBorder(ChalNaColor.Gray.g100, lineWidth: 1)
        )
    }

    private func durationBadge(for film: Film) -> some View {
        Text(Self.durationLabel(film.totalDurationSeconds))
            .font(ChalNaTypography.mono(12, weight: .semibold))
            .foregroundColor(Color.white)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(
                Capsule(style: .continuous)
                    .fill(ChalNaColor.Gray.g900.opacity(0.85))
            )
            .accessibilityLabel("총 길이 \(Self.durationLabel(film.totalDurationSeconds))")
    }

    // MARK: - Title + date

    private func titleBlock(for film: Film) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(film.title)
                .font(ChalNaTypography.title(ChalNaTypography.Size.h1, weight: .bold))
                .foregroundColor(ChalNaColor.Gray.g900)
                .lineLimit(3)

            Text(film.createdAt, format: .dateTime.year().month().day().weekday())
                .font(ChalNaTypography.krBody(ChalNaTypography.Size.small))
                .foregroundColor(ChalNaColor.Gray.g500)
                .lineLimit(2)
        }
    }

    // MARK: - Meta grid (클립 / Live / Video — 길이는 포스터 배지로 이동)

    private func metaGrid(for film: Film) -> some View {
        let videoCount = max(film.clipCount - film.liveCount, 0)
        let columns = [
            GridItem(.flexible(), spacing: 12),
            GridItem(.flexible(), spacing: 12),
            GridItem(.flexible(), spacing: 12)
        ]
        return LazyVGrid(columns: columns, spacing: 12) {
            metaCell(label: String(localized: "클립"), value: "\(film.clipCount)")
            metaCell(label: String(localized: "Live"), value: "\(film.liveCount)")
            metaCell(label: String(localized: "Video"), value: "\(videoCount)")
        }
    }

    private func metaCell(label: String, value: String) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(label)
                .font(ChalNaTypography.krBody(ChalNaTypography.Size.small))
                .foregroundColor(ChalNaColor.Gray.g500)
            Text(value)
                .font(ChalNaTypography.title(ChalNaTypography.Size.h2, weight: .bold))
                .foregroundColor(ChalNaColor.Gray.g900)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: ChalNaRadius.card, style: .continuous)
                .fill(Color.white)
        )
        .overlay(
            RoundedRectangle(cornerRadius: ChalNaRadius.card, style: .continuous)
                .strokeBorder(ChalNaColor.Gray.g100, lineWidth: 1)
        )
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(label) \(value)")
    }

    private var missingFileNotice: some View {
        HStack(alignment: .top, spacing: 12) {
            ChalNaIcon(.film, size: 20)
                .foregroundColor(ChalNaColor.Gray.g500)
            VStack(alignment: .leading, spacing: 4) {
                Text("영상 파일을 찾을 수 없어요")
                    .font(ChalNaTypography.krBody(ChalNaTypography.Size.body, weight: .semibold))
                    .foregroundColor(ChalNaColor.Gray.g900)
                Text("앱을 다시 설치하셨거나 파일이 삭제되었어요. 재생과 공유는 불가능하고, 라이브러리에서 항목을 정리할 수 있어요.")
                    .font(ChalNaTypography.krBody(ChalNaTypography.Size.small))
                    .foregroundColor(ChalNaColor.Gray.g500)
                    .lineSpacing(2)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: ChalNaRadius.card, style: .continuous)
                .fill(ChalNaColor.Gray.g50)
        )
    }

    private func actionButtons(canPlayOrShare: Bool) -> some View {
        VStack(spacing: 12) {
            HStack(spacing: 8) {
                Button {
                    store.send(.playTapped)
                } label: {
                    HStack(spacing: 8) {
                        ChalNaIcon(.play, size: 18)
                        Text("재생")
                    }
                }
                .buttonStyle(.chalNa(.filled, size: .lg, fillWidth: true))
                .disabled(!canPlayOrShare)
                .accessibilityLabel(canPlayOrShare ? "재생" : "재생 (파일 없음)")

                Button {
                    store.send(.shareTapped)
                } label: {
                    HStack(spacing: 8) {
                        ChalNaIcon(.share, size: 18)
                        Text("공유")
                    }
                }
                .buttonStyle(.chalNa(.standardOutlined, size: .lg, fillWidth: true))
                .disabled(!canPlayOrShare)
                .accessibilityLabel(canPlayOrShare ? "공유" : "공유 (파일 없음)")
            }

            // 파괴적 액션: 면형 위계로 1차 CTA(재생)와 경쟁하지 않도록 danger 텍스트 버튼으로 분리.
            // .chalNa(.text)는 coral 고정이라 danger 색을 못 살리므로, 커스텀 라벨 + contentShape 로
            // 48pt 전체 탭 영역을 보장한다(코드베이스 표준 패턴).
            Button {
                store.send(.deleteTapped)
            } label: {
                HStack(spacing: 8) {
                    ChalNaIcon(.trash, size: 16)
                    Text("필름 삭제")
                }
                .font(ChalNaTypography.krBody(ChalNaTypography.Size.body2, weight: .semibold))
                .foregroundColor(ChalNaColor.danger)
                .frame(maxWidth: .infinity, minHeight: 48)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel("필름 삭제")
        }
    }

    // MARK: - Missing film fallback

    private var missingFilmState: some View {
        VStack(alignment: .center, spacing: 12) {
            Spacer()
            Text("필름을 찾을 수 없어요")
                .font(ChalNaTypography.title(ChalNaTypography.Size.h2, weight: .semibold))
                .foregroundColor(ChalNaColor.Gray.g900)
            Text("이미 삭제되었거나 다른 기기에서 동기화 중일 수 있어요.")
                .font(ChalNaTypography.krBody(ChalNaTypography.Size.body))
                .foregroundColor(ChalNaColor.Gray.g500)
                .multilineTextAlignment(.center)
            Button("홈으로") { router.pop() }
                .buttonStyle(.chalNa(.outlined, size: .md))
                .padding(.top, 8)
            Spacer()
        }
        .frame(maxWidth: .infinity)
        .padding(.horizontal, 24)
    }

    // MARK: - Delete pipeline

    private func performDelete(film: Film) {
        FilmStorage.deleteMovie(filename: film.movieFilename)
        modelContext.delete(film)
        try? modelContext.save()
        store.send(.deleteConfirmed)
        router.pop()
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
