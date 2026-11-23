import AppCore
import AVFoundation
import AVKit
import ComposableArchitecture
import DesignSystem
import Models
import SwiftUI

public struct FilmDetailView: View {
    @Bindable var store: StoreOf<FilmDetailFeature>

    public init(store: StoreOf<FilmDetailFeature>) {
        self.store = store
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            if let film = store.film { content(for: film) }
            else if store.isLoading {
                ProgressView().frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if let error = store.loadError {
                ChalNaEmptyState(icon: .film, title: "필름을 불러오지 못했어요",
                                 message: "\(error)", actionTitle: "다시 시도") { store.send(.task) }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                ChalNaEmptyState(icon: .film, title: "필름을 찾을 수 없어요",
                                 message: "라이브러리에서 다시 확인해 주세요.", actionTitle: "홈으로") {
                    store.send(.backTapped)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .foregroundStyle(ChalNaColor.textPrimary)
        .chalNaScreen()
        .navigationTitle("필름 상세")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            if let film = store.film {
                ToolbarItem(placement: .topBarTrailing) {
                    Menu("필름 관리", systemImage: "ellipsis.circle") {
                        Section("필름 정보") {
                            Text(film.createdAt, format: .dateTime.year().month().day())
                            Text("Live Photo \(film.liveCount)개 · 동영상 \(max(0, film.clipCount - film.liveCount))개")
                        }
                        Button("필름 삭제", role: .destructive) { store.send(.deleteAlertPresentedChanged(true)) }
                    }
                    .disabled(store.isDeleting)
                }
            }
        }
        .task { await store.send(.task).finish() }
        .alert("필름을 삭제할까요?", isPresented: $store.isDeleteAlertPresented.sending(\.deleteAlertPresentedChanged)) {
            Button("삭제", role: .destructive) { store.send(.deleteConfirmed) }
            Button("취소", role: .cancel) {}
        } message: { Text("앱에 보관한 필름을 삭제해요. 사진 앱에 저장한 영상은 유지돼요.") }
        .fullScreenCover(isPresented: $store.isPlayerPresented.sending(\.playerPresentedChanged)) {
            if let url = store.film?.movieURL {
                NavigationStack {
                    VideoPlayerCover(url: url) { store.send(.playerPresentedChanged(false)) }
                        .ignoresSafeArea()
                        .navigationBarTitleDisplayMode(.inline)
                        .toolbar {
                            ToolbarItem(placement: .cancellationAction) {
                                Button("닫기", systemImage: "xmark") { store.send(.playerPresentedChanged(false)) }
                            }
                        }
                }
                .dynamicTypeSize(...DynamicTypeSize.accessibility1)
            }
        }
    }

    private func content(for film: ArchivedFilm) -> some View {
        GeometryReader { proxy in
            let split = ChalNaLayout.isSplit(proxy.size)
            let url = film.movieURL
            ScrollView {
                if split {
                    HStack(spacing: 30) {
                        poster(film, width: min(proxy.size.width * 0.42, max(80, proxy.size.height - 24) * 9 / 16), playable: url != nil)
                            .frame(maxWidth: .infinity)
                        information(film, url: url)
                            .frame(width: proxy.size.width * 0.42)
                    }
                } else {
                    VStack(alignment: .leading, spacing: 24) {
                        poster(film, width: min(max(1, proxy.size.width - 48), max(100, proxy.size.height - 178) * 9 / 16), playable: url != nil)
                            .frame(maxWidth: .infinity)
                        information(film, url: url)
                    }
                }
            }
            .padding(.horizontal, 24)
            .padding(.vertical, 10)
        }
    }

    private func poster(_ film: ArchivedFilm, width: CGFloat, playable: Bool) -> some View {
        Button { store.send(.playerPresentedChanged(true)) } label: {
            ZStack {
                if let data = film.thumbnailData, let image = UIImage(data: data) {
                    Image(uiImage: image).resizable().scaledToFill()
                } else { ThumbnailPreset.jejuOrange.view() }
            }
            .frame(width: width, height: width * 16 / 9)
            .clipped()
            .clipShape(RoundedRectangle(cornerRadius: ChalNaRadius.sm))
            .overlay {
                if playable {
                    ChalNaIcon(.play, size: 22).foregroundStyle(ChalNaColor.textPrimary)
                        .frame(width: 54, height: 54)
                        .background(ChalNaColor.bg, in: Circle())
                }
            }
        }
        .buttonStyle(.plain).disabled(!playable)
        .accessibilityLabel("완성된 영상 재생")
    }

    private func information(_ film: ArchivedFilm, url: URL?) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(verbatim: film.title).font(ChalNaTypography.display).lineLimit(3)
            Text(verbatim: film.metaLabel)
                .font(ChalNaTypography.label)
                .foregroundStyle(ChalNaColor.textSecondary)
            if let url {
                HStack(spacing: 8) {
                    Button("다시 보기") { store.send(.playerPresentedChanged(true)) }
                        .buttonStyle(.chalNa(.primary, size: .lg, fillWidth: true))
                    ShareLink(item: url) { Text("공유하기").frame(maxWidth: .infinity) }
                        .buttonStyle(.chalNa(.secondary, size: .lg, fillWidth: true))
                }
                .padding(.top, 12)
            } else {
                ChalNaNotice(icon: .film, title: "영상 파일을 찾을 수 없어요",
                              message: "영상 파일이 없어 재생하거나 공유할 수 없어요.")
                Button("필름 삭제", role: .destructive) { store.send(.deleteAlertPresentedChanged(true)) }
                    .buttonStyle(.chalNa(.ghost, size: .md, destructive: true))
            }
            if let error = store.deleteError {
                Text(verbatim: error).font(ChalNaTypography.label).foregroundStyle(ChalNaColor.danger)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}
private struct VideoPlayerCover: UIViewControllerRepresentable {
    let url: URL
    let onDismiss: () -> Void

    func makeUIViewController(context: Context) -> AVPlayerViewController {
        let player = AVPlayer(url: url)
        let controller = AVPlayerViewController()
        controller.player = player
        controller.allowsPictureInPicturePlayback = true
        controller.delegate = context.coordinator
        player.playWithFilmAudio()
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
