import AppCore
import AVFoundation
import AVKit
import ComposableArchitecture
import DesignSystem
import Models
import SwiftUI
import UIKit

public struct FilmDetailView: View {
    @Bindable var store: StoreOf<FilmDetailFeature>
    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.openURL) private var openURL

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
        .onChange(of: scenePhase) { _, phase in
            if phase == .active { store.send(.videoAvailabilityChanged) }
        }
        .alert("필름을 삭제할까요?", isPresented: $store.isDeleteAlertPresented.sending(\.deleteAlertPresentedChanged)) {
            Button("삭제", role: .destructive) { store.send(.deleteConfirmed) }
            Button("취소", role: .cancel) {}
        } message: {
            if store.film?.appMovieURL != nil {
                Text("앱에 보관한 필름을 삭제해요. 사진 앱에 저장한 영상은 유지돼요.")
            } else {
                Text("홈에서 필름 기록을 삭제해요. 사진 앱에 저장한 영상은 그대로예요.")
            }
        }
        .fullScreenCover(isPresented: Binding(
            get: { store.playerItem != nil },
            set: { if !$0 { store.send(.playerDismissed) } }
        )) {
            if let item = store.playerItem {
                NavigationStack {
                    VideoPlayerCover(item: item) { store.send(.playerDismissed) }
                        .ignoresSafeArea()
                        .navigationBarTitleDisplayMode(.inline)
                        .toolbar {
                            ToolbarItem(placement: .cancellationAction) {
                                Button("닫기", systemImage: "xmark") { store.send(.playerDismissed) }
                            }
                        }
                }
                .dynamicTypeSize(...DynamicTypeSize.accessibility1)
            }
        }
        .sheet(isPresented: Binding(
            get: { store.shareURL != nil },
            set: { if !$0, let url = store.shareURL { store.send(.shareDismissed(url)) } }
        )) {
            if let url = store.shareURL {
                VideoShareSheet(url: url) { store.send(.shareDismissed(url)) }
            }
        }
    }

    private func content(for film: ArchivedFilm) -> some View {
        GeometryReader { proxy in
            let split = ChalNaLayout.isSplit(proxy.size)
            let playable = film.appMovieURL != nil || store.videoAvailability == .available
            ScrollView {
                if split {
                    HStack(spacing: 30) {
                        poster(film, width: min(proxy.size.width * 0.42, max(80, proxy.size.height - 24) * 9 / 16), playable: playable)
                            .frame(maxWidth: .infinity)
                        information(film, playable: playable)
                            .frame(width: proxy.size.width * 0.42)
                    }
                } else {
                    let posterHeight = playable ? proxy.size.height - 178 : proxy.size.height * 0.55
                    VStack(alignment: .leading, spacing: 24) {
                        poster(film, width: min(max(1, proxy.size.width - 48), max(100, posterHeight) * 9 / 16), playable: playable)
                            .frame(maxWidth: .infinity)
                        information(film, playable: playable)
                    }
                }
            }
            .padding(.horizontal, 24)
            .padding(.vertical, 10)
        }
    }

    @ViewBuilder
    private func poster(_ film: ArchivedFilm, width: CGFloat, playable: Bool) -> some View {
        let cover = ZStack {
            if let data = film.thumbnailData, let image = UIImage(data: data) {
                Image(uiImage: image).resizable().scaledToFill()
            } else { ThumbnailPreset.jejuOrange.view() }
        }
        .frame(width: width, height: width * 16 / 9)
        .clipped()
        .clipShape(RoundedRectangle(cornerRadius: ChalNaRadius.sm))

        if playable && !store.isLoadingVideo {
            Button { store.send(.videoTapped(.play)) } label: {
                cover.overlay {
                    ChalNaIcon(.play, size: 22).foregroundStyle(ChalNaColor.textPrimary)
                        .frame(width: 54, height: 54)
                        .background(ChalNaColor.bg, in: Circle())
                }
            }
            .buttonStyle(.plain)
            .accessibilityLabel("완성된 영상 재생")
        } else {
            cover.accessibilityHidden(true)
        }
    }

    private func information(_ film: ArchivedFilm, playable: Bool) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(verbatim: film.title).font(ChalNaTypography.display).lineLimit(3)
            Text(verbatim: film.metaLabel)
                .font(ChalNaTypography.label)
                .foregroundStyle(ChalNaColor.textSecondary)
            if playable {
                HStack(spacing: 8) {
                    Button("다시 보기") { store.send(.videoTapped(.play)) }
                        .buttonStyle(.chalNa(.primary, size: .lg, fillWidth: true))
                    Group {
                        if let url = film.appMovieURL {
                            ShareLink(item: url) { Text("공유하기") }
                        } else {
                            Button("공유하기") { store.send(.videoTapped(.share)) }
                        }
                    }
                    .buttonStyle(.chalNa(.secondary, size: .lg, fillWidth: true))
                }
                .disabled(store.isLoadingVideo)
                .padding(.top, 12)
                if store.isLoadingVideo {
                    ProgressView("사진 앱에서 영상을 불러오는 중이에요")
                        .font(ChalNaTypography.label)
                }
                if store.videoLoadFailed {
                    ChalNaNotice(title: "영상을 불러오지 못했어요", message: "네트워크 연결을 확인하고 다시 시도해 주세요.")
                }
            } else {
                videoUnavailable
            }
            if let error = store.deleteError {
                Text(verbatim: error).font(ChalNaTypography.label).foregroundStyle(ChalNaColor.danger)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    @ViewBuilder
    private var videoUnavailable: some View {
        switch store.videoAvailability {
        case .missing:
            ChalNaNotice(title: "사진 앱에서 영상이 삭제되어 재생할 수 없어요", message: "필름 기록은 홈에 남아 있어요.")
            deleteButton
        case .authorizationRequired, .accessRequired:
            ChalNaNotice(title: "사진 보관함 접근 권한이 필요해요",
                         message: "사진 앱에 저장된 영상을 보려면 접근 권한을 허용해 주세요.")
            if store.videoAvailability == .authorizationRequired {
                Button("사진 접근 허용") { store.send(.photoAccessTapped) }
                    .buttonStyle(.chalNa(.secondary, size: .md))
                    .disabled(store.isRequestingPhotoAccess)
            } else {
                Button("앱 설정 열기") {
                    if let url = URL(string: UIApplication.openSettingsURLString) { openURL(url) }
                }
                .buttonStyle(.chalNa(.secondary, size: .md))
            }
        case nil:
            ChalNaNotice(title: "사진 앱에 연결된 영상이 없어요", message: "필름 기록은 홈에 남아 있어요.")
            deleteButton
        case .available:
            EmptyView()
        }
    }

    private var deleteButton: some View {
        Button("필름 삭제", role: .destructive) { store.send(.deleteAlertPresentedChanged(true)) }
            .buttonStyle(.chalNa(.ghost, size: .md, destructive: true))
    }
}

private struct VideoPlayerCover: UIViewControllerRepresentable {
    let item: AVPlayerItem
    let onDismiss: () -> Void

    func makeUIViewController(context: Context) -> AVPlayerViewController {
        let player = AVPlayer(playerItem: item)
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

private struct VideoShareSheet: UIViewControllerRepresentable {
    let url: URL
    let onDismiss: () -> Void

    func makeUIViewController(context: Context) -> UIActivityViewController {
        let controller = UIActivityViewController(activityItems: [url], applicationActivities: nil)
        controller.completionWithItemsHandler = { _, _, _, _ in onDismiss() }
        return controller
    }

    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}
