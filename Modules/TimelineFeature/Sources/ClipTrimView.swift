import AppCore
import AVFoundation
import DesignSystem
import Models
import SwiftUI

struct ClipTrimView: View {
    @Environment(\.verticalSizeClass) private var verticalSizeClass

    let clip: Clip
    let onCommit: (ClosedRange<TimeInterval>, Data?) -> Void
    let onCancel: () -> Void

    @State private var draft: Clip
    @State private var player = AVPlayer()
    @State private var item: AVPlayerItem?
    @State private var thumbnails = Array<CGImage?>(repeating: nil, count: TrimFilmstrip.frameCount)
    private let fallbackThumbnail: CGImage?
    @State private var aspect: CGFloat = 9.0 / 16
    @State private var ready = false
    @State private var failed = false
    @State private var playing = false
    @State private var saving = false
    @State private var playTask: Task<Void, Never>?

    init(clip: Clip, onCommit: @escaping (ClosedRange<TimeInterval>, Data?) -> Void, onCancel: @escaping () -> Void) {
        self.clip = clip
        self.onCommit = onCommit
        self.onCancel = onCancel
        fallbackThumbnail = clip.thumbnailData.flatMap { UIImage(data: $0)?.cgImage }
        _draft = State(initialValue: clip)
    }

    var body: some View {
        Group {
            if failed {
                Text("동영상을 불러올 수 없어요.").multilineTextAlignment(.center)
            } else if let item {
                let layout = verticalSizeClass == .compact
                    ? AnyLayout(HStackLayout(spacing: 24))
                    : AnyLayout(VStackLayout(spacing: 16))
                layout {
                    preview
                    controls
                }
                .padding(.vertical, 16)
                .onReceive(item.publisher(for: \.status).receive(on: DispatchQueue.main)) { status in
                    ready = status == .readyToPlay
                    if status == .failed { stop(); failed = true }
                }
                .onReceive(NotificationCenter.default.publisher(for: .AVPlayerItemDidPlayToEndTime, object: item)) { _ in
                    playing = false
                }
                .onReceive(NotificationCenter.default.publisher(for: .AVPlayerItemFailedToPlayToEndTime, object: item)) { _ in
                    stop()
                    failed = true
                }
            } else {
                ProgressView()
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(.horizontal, 24)
        .foregroundStyle(ChalNaColor.textPrimary)
        .chalNaScreen()
        .navigationTitle("동영상 자르기")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("취소", systemImage: "xmark") {
                    saving = false
                    stop()
                    onCancel()
                }
                .accessibilityIdentifier("trim.cancel")
            }
            ToolbarItem(placement: donePlacement) {
                Button("완료", systemImage: "checkmark") { saving = true }
                    .tint(ChalNaColor.accent)
                    .disabled(!ready || failed || saving)
                    .accessibilityIdentifier("trim.done")
            }
        }
        .task { await prepare() }
        .task(id: saving) { if saving { await commit() } }
        .onDisappear {
            saving = false
            stop()
            player.currentItem?.cancelPendingSeeks()
            player.replaceCurrentItem(with: nil)
        }
    }

    private var donePlacement: ToolbarItemPlacement {
        if #available(iOS 27.0, *) { return .topBarPinnedTrailing }
        return .confirmationAction
    }

    private var preview: some View {
        PlayerLayerView(player: player)
            .aspectRatio(aspect, contentMode: .fit)
            .background(ChalNaColor.canvas)
            .clipShape(RoundedRectangle(cornerRadius: ChalNaRadius.xs))
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .accessibilityHidden(true)
    }

    private var controls: some View {
        VStack(spacing: 16) {
            HStack(spacing: 12) {
                Button { togglePlayback() } label: {
                    ChalNaIcon(playing ? .pause : .play, size: 16, weight: .semibold)
                        .foregroundStyle(ChalNaColor.onAccent)
                        .frame(width: 44, height: 44)
                        .background(ChalNaColor.accentFill, in: Circle())
                }
                .buttonStyle(.plain)
                .accessibilityLabel(playing ? Text("일시정지") : Text("선택 구간 재생"))
                .accessibilityIdentifier("trim.play")
                Text("선택 길이").font(ChalNaTypography.label).foregroundStyle(ChalNaColor.textSecondary)
                Spacer(minLength: 4)
                Text(verbatim: timelineClock(draft.duration)).font(ChalNaTypography.title).monospacedDigit()
                    .accessibilityIdentifier("trim.duration")
            }
            TrimFilmstrip(range: draft.trimRange, duration: draft.sourceDuration, thumbnails: thumbnails, fallbackThumbnail: fallbackThumbnail) { edge, time in
                switch edge {
                case .start: draft.setTrimStart(time)
                case .end: draft.setTrimEnd(time)
                }
                stop()
                item?.forwardPlaybackEndTime = .invalid
                showBoundary(edge)
            }
        }
        .padding(.bottom, 8)
        .disabled(!ready || saving)
    }

    private func prepare() async {
        guard let url = clip.videoURL, clip.sourceDuration.isFinite, clip.sourceDuration > 0 else { failed = true; return }
        do {
            let asset = AVURLAsset(url: url)
            guard try await asset.load(.isPlayable), let track = try await asset.loadTracks(withMediaType: .video).first else {
                throw CocoaError(.fileReadCorruptFile)
            }
            let size = try await track.load(.naturalSize)
            let transformed = size.applying(try await track.load(.preferredTransform))
            try Task.checkCancellation()
            if transformed.height != 0 { aspect = abs(transformed.width / transformed.height) }
            let newItem = AVPlayerItem(asset: asset)
            item = newItem
            player.replaceCurrentItem(with: newItem)
            showBoundary(.start)
            let generator = AVAssetImageGenerator(asset: asset)
            generator.appliesPreferredTrackTransform = true
            generator.maximumSize = CGSize(width: 144, height: 144)
            let count = TrimFilmstrip.frameCount
            // Bound the allowed seek error to one tile, so neighboring tiles represent different moments.
            let tolerance = cmTime(clip.sourceDuration / Double(count * 2))
            generator.requestedTimeToleranceBefore = tolerance
            generator.requestedTimeToleranceAfter = tolerance
            for index in 0..<count {
                let time = clip.sourceDuration * (Double(index) + 0.5) / Double(count)
                let result = try? await generator.image(at: cmTime(time))
                try Task.checkCancellation()
                thumbnails[index] = result?.image
            }
        } catch {
            if !Task.isCancelled { stop(); failed = true }
        }
    }

    private func togglePlayback() {
        guard !playing else { stop(); return }
        guard let item else { return }
        item.forwardPlaybackEndTime = cmTime(draft.trimRange.upperBound)
        playing = true
        playTask = Task { @MainActor in
            let positioned = await player.seek(to: cmTime(draft.trimRange.lowerBound), toleranceBefore: .zero, toleranceAfter: .zero)
            guard !Task.isCancelled else { return }
            if positioned { player.playWithFilmAudio() } else { playing = false }
        }
    }

    private func stop() {
        playTask?.cancel()
        playTask = nil
        player.pause()
        playing = false
    }

    private func showBoundary(_ edge: TrimFilmstrip.Edge) {
        let range = draft.trimRange
        // The upper bound is exclusive. Seek just inside it so the preview shows the last kept frame.
        let time = edge == .start ? range.lowerBound : max(range.lowerBound, range.upperBound - 1.0 / 600)
        player.seek(to: cmTime(time), toleranceBefore: .zero, toleranceAfter: .zero)
    }

    private func commit() async {
        stop()
        let range = draft.trimRange
        guard range.lowerBound != clip.trimRange.lowerBound, let asset = item?.asset else {
            onCommit(range, nil)
            return
        }
        let generator = AVAssetImageGenerator(asset: asset)
        generator.appliesPreferredTrackTransform = true
        generator.maximumSize = CGSize(width: 480, height: 620)
        generator.requestedTimeToleranceBefore = .zero
        generator.requestedTimeToleranceAfter = .zero
        let start = cmTime(range.lowerBound)
        var image = try? await generator.image(at: start).image
        guard saving, !Task.isCancelled else { return }
        if image == nil {
            // A variable-frame-rate source can lack a decodable sample exactly at the boundary.
            generator.requestedTimeToleranceAfter = cmTime(max(0, range.upperBound - range.lowerBound - 1.0 / 600))
            image = try? await generator.image(at: start).image
        }
        guard saving, !Task.isCancelled, !failed else { return }
        let jpeg = image.flatMap { UIImage(cgImage: $0).jpegData(compressionQuality: 0.8) }
        onCommit(range, jpeg)
    }

    private func cmTime(_ seconds: TimeInterval) -> CMTime {
        CMTime(seconds: seconds, preferredTimescale: 600)
    }
}
