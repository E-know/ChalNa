import SwiftUI
import AVFoundation
import UIKit
import ComposableArchitecture
import DesignSystem
import PhotosService

/// 선택된 미디어(Live Photo paired video / 일반 영상)를 하단 바텀시트에서
/// 확대해 보여주고 탭으로 play/pause 하는 미리보기 시트.
struct MediaPreviewSheet: View {
    let asset: PhotoLibraryAsset
    let store: StoreOf<MediaPickerFeature>

    @State private var controller = PreviewPlaybackController()

    /// 시트가 떠 있는 동안 store에서 reactively 읽는 미디어 상태.
    private var media: MediaLoadState {
        store.media[asset.id] ?? MediaLoadState(kind: asset.kind)
    }

    var body: some View {
        ZStack {
            ChalNaColor.cream.ignoresSafeArea()

            VStack(alignment: .leading, spacing: 16) {
                metaRow
                stage
                hint
                Spacer(minLength: 0)
            }
            .padding(.horizontal, 24)
            .padding(.top, 24)
            .padding(.bottom, 24)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .presentationDetents([.medium, .large])
        .presentationDragIndicator(.visible)
        .presentationCornerRadius(ChalNaRadius.sheet)
        .onAppear { startIfPossible() }
        .onDisappear { controller.stop() }
        .onChange(of: media.videoURL) { _, _ in startIfPossible() }
    }

    // MARK: - Meta

    private var metaRow: some View {
        HStack(spacing: 8) {
            switch media.kind {
            case .livePhoto: ChalNaChip("LIVE", variant: .live)
            case .video:     ChalNaChip("VIDEO", variant: .video, icon: .film)
            case .image, .unknown: EmptyView()
            }

            if let duration = media.duration, duration > 0 {
                Text(String(format: "%.1f초", duration))
                    .font(ChalNaTypography.monoFallback(13, weight: .medium))
                    .foregroundColor(ChalNaColor.taupe)
            }

            Spacer()
        }
    }

    // MARK: - Video stage

    private var stage: some View {
        ZStack {
            ChalNaColor.ink

            if media.videoURL != nil {
                PreviewPlayerLayerView(player: controller.player)
                if !controller.isPlaying {
                    pausedOverlay
                }
            } else if media.videoFailed {
                failureContent
            } else {
                loadingContent
            }
        }
        .aspectRatio(stageAspectRatio, contentMode: .fit)
        .frame(maxWidth: .infinity, maxHeight: 380)
        .clipShape(RoundedRectangle(cornerRadius: ChalNaRadius.card, style: .continuous))
        .contentShape(Rectangle())
        .onTapGesture {
            guard media.videoURL != nil else { return }
            controller.toggle()
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(controller.isPlaying ? "재생 중. 탭하면 멈춰요" : "일시정지. 탭하면 재생돼요")
    }

    private var pausedOverlay: some View {
        Circle()
            .fill(Color.white.opacity(0.92))
            .frame(width: 64, height: 64)
            .overlay(ChalNaIcon(.play, size: 26).foregroundColor(ChalNaColor.ink).offset(x: 2))
    }

    private var failureContent: some View {
        VStack(spacing: 10) {
            thumbnailImage
            Text("영상을 불러오지 못했어요")
                .font(ChalNaTypography.krBody(13, weight: .medium))
                .foregroundColor(.white)
        }
        .padding(16)
    }

    private var loadingContent: some View {
        ZStack {
            thumbnailImage
            ProgressView().tint(ChalNaColor.coral)
        }
    }

    @ViewBuilder
    private var thumbnailImage: some View {
        if let data = media.thumbnail, let ui = UIImage(data: data) {
            Image(uiImage: ui).resizable().scaledToFit()
        } else {
            ChalNaColor.ivory.opacity(0.2)
        }
    }

    private var hint: some View {
        Text(media.videoURL != nil ? "영상을 탭하면 재생/일시정지돼요." : "원본 영상이 없는 미디어예요.")
            .font(ChalNaTypography.krBody(12))
            .foregroundColor(ChalNaColor.taupe)
    }

    // MARK: - Derived

    private var stageAspectRatio: CGFloat {
        if let size = media.displaySize, size.width > 0, size.height > 0 {
            return size.width / size.height
        }
        return 3.0 / 4.0
    }

    private func startIfPossible() {
        if let url = media.videoURL {
            controller.start(url: url)
        }
    }
}

// MARK: - Playback controller

/// 미리보기용 단일 AVPlayer 루프 재생 컨트롤러. GCD 미사용 — 종료 감지는 NotificationCenter만 사용.
@Observable
final class PreviewPlaybackController {
    let player = AVPlayer()
    private(set) var isPlaying = false

    private var endObserver: NSObjectProtocol?
    private var currentURL: URL?

    func start(url: URL) {
        if currentURL == url, player.currentItem != nil {
            player.play()
            isPlaying = true
            return
        }
        stop()
        currentURL = url

        let item = AVPlayerItem(url: url)
        player.replaceCurrentItem(with: item)
        player.seek(to: .zero)
        endObserver = NotificationCenter.default.addObserver(
            forName: .AVPlayerItemDidPlayToEndTime,
            object: item,
            queue: .main
        ) { [weak self] _ in
            self?.player.seek(to: .zero)
            self?.player.play()
        }
        player.play()
        isPlaying = true
    }

    func toggle() {
        if isPlaying {
            player.pause()
            isPlaying = false
        } else {
            player.play()
            isPlaying = true
        }
    }

    func stop() {
        player.pause()
        isPlaying = false
        if let endObserver {
            NotificationCenter.default.removeObserver(endObserver)
        }
        endObserver = nil
        player.replaceCurrentItem(with: nil)
        currentURL = nil
    }

    deinit {
        if let endObserver {
            NotificationCenter.default.removeObserver(endObserver)
        }
    }
}

// MARK: - AVPlayerLayer 래퍼 (TimelineFeature PlayerLayerView 의 로컬 미러)

private struct PreviewPlayerLayerView: UIViewRepresentable {
    let player: AVPlayer

    func makeUIView(context: Context) -> PreviewPlayerHostView {
        let view = PreviewPlayerHostView()
        view.playerLayer.player = player
        view.playerLayer.videoGravity = .resizeAspect
        view.backgroundColor = .clear
        return view
    }

    func updateUIView(_ uiView: PreviewPlayerHostView, context: Context) {
        if uiView.playerLayer.player !== player {
            uiView.playerLayer.player = player
        }
    }
}

private final class PreviewPlayerHostView: UIView {
    override static var layerClass: AnyClass { AVPlayerLayer.self }
    var playerLayer: AVPlayerLayer { layer as! AVPlayerLayer }
}

// MARK: - Preview

#Preview("MediaPreviewSheet — 영상 없음") {
    let asset = PhotoLibraryAsset(id: "p1", kind: .livePhoto, capturedAt: nil, pixelSize: .zero)
    var state = MediaPickerFeature.State(source: .photoLibrary)
    state.photoAssets = [asset]
    state.selectedAssetIDs = [asset.id]
    var loaded = MediaLoadState(kind: .livePhoto)
    loaded.videoFailed = true   // 캔버스엔 실제 영상 URL이 없으니 실패 상태로 시각 검증
    loaded.duration = 1.5
    state.media[asset.id] = loaded

    return Color.clear.sheet(isPresented: .constant(true)) {
        MediaPreviewSheet(
            asset: asset,
            store: Store(initialState: state) { MediaPickerFeature() }
        )
    }
}
