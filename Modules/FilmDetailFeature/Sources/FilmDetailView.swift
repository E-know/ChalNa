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
        HStack(alignment: .center, spacing: 8) {
            Button {
                router.pop()
            } label: {
                ChalNaIcon(.chevronLeft, size: 24)
                    .foregroundColor(ChalNaColor.ink)
            }
            .buttonStyle(.chalNaHeaderAction)
            .accessibilityLabel("뒤로")

            Text("필름 정보")
                .font(ChalNaTypography.title(ChalNaTypography.Size.h2, weight: .semibold))
                .foregroundColor(ChalNaColor.ink)

            Spacer()
        }
    }

    // MARK: - Content

    @ViewBuilder
    private func content(for film: Film) -> some View {
        let movieURL = film.movieURL

        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                thumbnailCard(for: film)

                titleSection(for: film)

                metaGrid(for: film)

                if movieURL == nil {
                    missingFileNotice
                        .onAppear { store.send(.missingFileNoticed) }
                }

                actionButtons(canPlayOrShare: movieURL != nil)
                    .padding(.top, 8)
            }
            .padding(.horizontal, 24)
            .padding(.top, 16)
            .padding(.bottom, 48)
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

    private func thumbnailCard(for film: Film) -> some View {
        ZStack {
            if let data = film.thumbnailData, let image = UIImage(data: data) {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFill()
            } else {
                ThumbnailPreset.jejuOrange.view()
            }
        }
        .aspectRatio(16.0 / 9.0, contentMode: .fit)
        .frame(maxWidth: .infinity)
        .clipShape(RoundedRectangle(cornerRadius: ChalNaRadius.card, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: ChalNaRadius.card, style: .continuous)
                .strokeBorder(ChalNaColor.Gray.g100, lineWidth: 1)
        )
    }

    private func titleSection(for film: Film) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(film.title)
                .font(ChalNaTypography.title(ChalNaTypography.Size.h1, weight: .bold))
                .foregroundColor(ChalNaColor.ink)
                .lineLimit(2)

            Text(Self.dateFormatter.string(from: film.createdAt))
                .font(ChalNaTypography.krBody(ChalNaTypography.Size.body))
                .foregroundColor(ChalNaColor.taupe)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func metaGrid(for film: Film) -> some View {
        let videoCount = max(film.clipCount - film.liveCount, 0)
        let columns = [GridItem(.flexible(), spacing: 12), GridItem(.flexible(), spacing: 12)]
        return LazyVGrid(columns: columns, spacing: 12) {
            metaCell(label: "총 길이", value: Self.durationLabel(film.totalDurationSeconds))
            metaCell(label: "클립", value: "\(film.clipCount)")
            metaCell(label: "Live", value: "\(film.liveCount)")
            metaCell(label: "Video", value: "\(videoCount)")
        }
    }

    private func metaCell(label: String, value: String) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(label)
                .font(ChalNaTypography.krBody(ChalNaTypography.Size.small))
                .foregroundColor(ChalNaColor.taupe)
            Text(value)
                .font(ChalNaTypography.title(ChalNaTypography.Size.h2, weight: .bold))
                .foregroundColor(ChalNaColor.ink)
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
    }

    private var missingFileNotice: some View {
        HStack(alignment: .top, spacing: 12) {
            ChalNaIcon(.film, size: 20)
                .foregroundColor(ChalNaColor.taupe)
            VStack(alignment: .leading, spacing: 4) {
                Text("영상 파일을 찾을 수 없어요")
                    .font(ChalNaTypography.krBody(ChalNaTypography.Size.body, weight: .semibold))
                    .foregroundColor(ChalNaColor.ink)
                Text("앱을 다시 설치하셨거나 파일이 삭제되었어요. 재생과 공유는 불가능하고, 라이브러리에서 항목을 정리할 수 있어요.")
                    .font(ChalNaTypography.krBody(ChalNaTypography.Size.small))
                    .foregroundColor(ChalNaColor.taupe)
                    .lineSpacing(2)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: ChalNaRadius.card, style: .continuous)
                .fill(ChalNaColor.ivory)
        )
    }

    private func actionButtons(canPlayOrShare: Bool) -> some View {
        VStack(spacing: 12) {
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
            .opacity(canPlayOrShare ? 1 : 0.5)

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
            .opacity(canPlayOrShare ? 1 : 0.5)

            Button {
                store.send(.deleteTapped)
            } label: {
                HStack(spacing: 8) {
                    ChalNaIcon(.trash, size: 16)
                    Text("필름 삭제")
                }
            }
            .buttonStyle(.chalNaText)
        }
    }

    // MARK: - Missing film fallback

    private var missingFilmState: some View {
        VStack(alignment: .center, spacing: 12) {
            Spacer()
            Text("필름을 찾을 수 없어요")
                .font(ChalNaTypography.title(ChalNaTypography.Size.h2, weight: .semibold))
                .foregroundColor(ChalNaColor.ink)
            Text("이미 삭제되었거나 다른 기기에서 동기화 중일 수 있어요.")
                .font(ChalNaTypography.krBody(ChalNaTypography.Size.body))
                .foregroundColor(ChalNaColor.taupe)
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

    private static let dateFormatter: DateFormatter = {
        let f = DateFormatter()
        f.locale = Locale(identifier: "ko_KR")
        f.dateFormat = "yyyy년 M월 d일 EEEE"
        return f
    }()

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
