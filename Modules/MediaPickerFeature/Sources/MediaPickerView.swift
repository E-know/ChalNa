import SwiftUI
import AppCore
import Models
import DesignSystem
import PhotosUI
import Photos
import AVFoundation
import UniformTypeIdentifiers
import OSLog

private let mediaLogger = Logger(subsystem: "ios.inho.OneSecMovie", category: "MediaPicker")

/// PhotosPicker 결과의 미디어 종류. Live Photo와 일반 영상은
/// 둘 다 "움직이는 클립"으로 다뤄지지만, UI에서는 분리해서 표시한다.
fileprivate enum MediaKind {
    case video
    case livePhoto
    case image
    case unknown

    var hasMotion: Bool { self == .video || self == .livePhoto }
}

/// Live Photo + 영상을 여러 장 선택하고 Timeline으로 넘기는 화면.
/// 선택 시 (a) 썸네일 JPEG Data와 (b) 실제 비디오 파일 URL을 병렬로 로드한다.
/// Live Photo는 PhotosPicker의 Transferable에서 paired video가 안 나올 수 있어
/// `PHAssetResourceManager`로 paired video 리소스를 꺼내는 fallback을 둔다.
public struct MediaPickerView: View {
    @Environment(AppRouter.self) private var router
    @Environment(EditSession.self) private var session

    @State private var selectedItems: [PhotosPickerItem] = []
    @State private var media: [PhotosPickerItem: MediaLoadState] = [:]
    @State private var isResolving = false
    @State private var scrollProgress: Double = 0
    @State private var titleInput: String = ""
    @FocusState private var isTitleFocused: Bool
    // PhotosPicker가 PHAsset localIdentifier(itemIdentifier)를 채워 주려면
    // photoLibrary 파라미터로 동일한 라이브러리를 명시해야 한다 (iOS 17+).
    @State private var photoLibrary = PHPhotoLibrary.shared()

    public init() {}

    public var body: some View {
        VStack(spacing: 0) {
            header.momentsHeaderBar(scrollProgress: scrollProgress)
                .zIndex(1)

            ScrollView {
                VStack(alignment: .leading, spacing: MomentsSpacing.lg) {
                    intro
                        .padding(.horizontal, MomentsSpacing.lg)
                        .padding(.top, MomentsSpacing.lg)
                        .trackScrollOffset(in: "media-picker-scroll")

                    titleField
                        .padding(.horizontal, MomentsSpacing.lg)

                    pickerLauncher
                        .padding(.horizontal, MomentsSpacing.lg)

                    selectionGrid
                        .padding(.horizontal, MomentsSpacing.lg)
                        .padding(.top, MomentsSpacing.sm)
                }
                .padding(.bottom, MomentsSpacing.xxxl)
            }
            .coordinateSpace(name: "media-picker-scroll")
            .scrollDismissesKeyboard(.interactively)
            .onPreferenceChange(ScrollOffsetPreferenceKey.self) { offset in
                let p = max(0, min(1, offset / 8))
                if abs(p - scrollProgress) > 0.01 {
                    withAnimation(.easeInOut(duration: 0.15)) { scrollProgress = p }
                }
            }
        }
        .momentsScreen()
        .safeAreaInset(edge: .bottom) {
            bottomBar
                .padding(.horizontal, MomentsSpacing.md)
                .padding(.bottom, MomentsSpacing.md)
        }
        .toolbar {
            ToolbarItemGroup(placement: .keyboard) {
                Spacer()
                Button("완료") { isTitleFocused = false }
                    .foregroundColor(MomentsColor.coral)
            }
        }
        .onChange(of: selectedItems) { _, newItems in
            // 항목 선택 시점에 Photos 권한을 lazy 요청 — Live Photo paired video 추출에 필수.
            if newItems.contains(where: { media[$0] == nil }) {
                Task { _ = await Self.ensurePhotoAuthorization() }
            }
            syncMedia(for: newItems)
        }
    }

    // MARK: - Header

    private var header: some View {
        HStack {
            Button {
                router.pop()
            } label: {
                HStack(spacing: 2) {
                    MomentsIcon(.chevronLeft, size: 14)
                    Text("뒤로").font(MomentsTypography.krBody(14, weight: .medium))
                }
                .foregroundColor(MomentsColor.taupe)
            }
            .buttonStyle(.plain)

            Spacer()

            VStack(spacing: 2) {
                Text("미디어 선택")
                    .font(MomentsTypography.krSemibold(15))
                    .foregroundColor(MomentsColor.ink)
                Text("LIVE · VIDEO")
                    .tagLabel(color: MomentsColor.coral)
            }

            Spacer()

            Button {
                confirmSelection()
            } label: {
                if isResolving {
                    ProgressView().controlSize(.small).tint(MomentsColor.coral)
                } else {
                    Text("다음")
                        .font(MomentsTypography.krSemibold(14))
                        .foregroundColor(canProceed ? MomentsColor.coral : MomentsColor.taupe.opacity(0.5))
                }
            }
            .buttonStyle(.plain)
            .disabled(!canProceed || isResolving)
        }
    }

    // MARK: - Intro

    private var intro: some View {
        VStack(alignment: .leading, spacing: MomentsSpacing.xs) {
            Text("PICK · YOUR MOMENTS")
                .tagLabel()
            (Text("여행의 순간을\n")
                .font(MomentsTypography.displayKR(26))
             + Text("천천히 골라보세요.")
                .font(MomentsTypography.krBody(22, weight: .medium)))
                .foregroundColor(MomentsColor.ink)
                .lineSpacing(2)
            Text("Live Photo와 짧은 영상을 불러올 수 있어요. Live Photo는 내부의 영상 부분을 사용합니다.")
                .font(MomentsTypography.krBody(13))
                .foregroundColor(MomentsColor.taupe)
                .padding(.top, MomentsSpacing.xxs)
        }
    }

    // MARK: - Title field

    private var titleField: some View {
        VStack(alignment: .leading, spacing: MomentsSpacing.xs) {
            Text("TITLE · 이번 필름의 제목")
                .tagLabel()

            TextField(
                "",
                text: $titleInput,
                prompt: Text("예: 제주도, 우리의 봄")
                    .font(MomentsTypography.krBody(15))
                    .foregroundColor(MomentsColor.taupe.opacity(0.6))
            )
            .font(MomentsTypography.krBody(16, weight: .medium))
            .foregroundColor(MomentsColor.ink)
            .submitLabel(.done)
            .focused($isTitleFocused)
            .padding(.horizontal, MomentsSpacing.md)
            .padding(.vertical, MomentsSpacing.sm + 2)
            .background(
                RoundedRectangle(cornerRadius: MomentsRadius.card, style: .continuous)
                    .fill(Color.white)
            )
            .overlay(
                RoundedRectangle(cornerRadius: MomentsRadius.card, style: .continuous)
                    .strokeBorder(
                        isTitleFocused
                            ? MomentsColor.coral.opacity(0.55)
                            : MomentsColor.taupe.opacity(0.18),
                        lineWidth: 1
                    )
            )
            .animation(.easeInOut(duration: 0.15), value: isTitleFocused)

            Text("비워두면 나중에 자동으로 채워져요.")
                .font(MomentsTypography.krBody(12))
                .foregroundColor(MomentsColor.taupe)
        }
    }

    // MARK: - Picker launcher

    private var pickerLauncher: some View {
        PhotosPicker(
            selection: $selectedItems,
            maxSelectionCount: 0,
            selectionBehavior: .ordered,
            matching: .any(of: [.livePhotos, .videos]),
            photoLibrary: photoLibrary
        ) {
            HStack(spacing: MomentsSpacing.sm) {
                MomentsIcon(.plus, size: 18)
                    .foregroundColor(MomentsColor.coral)
                VStack(alignment: .leading, spacing: 2) {
                    Text(selectedItems.isEmpty ? "사진 보관함 열기" : "선택 다시 고르기")
                        .font(MomentsTypography.krSemibold(15))
                        .foregroundColor(MomentsColor.ink)
                    Text(selectedItems.isEmpty ? "Live Photo · Video 자유롭게"
                                               : "\(selectedItems.count)장 선택됨")
                        .font(MomentsTypography.krBody(12))
                        .foregroundColor(MomentsColor.taupe)
                }
                Spacer()
                MomentsIcon(.chevronRight, size: 14)
                    .foregroundColor(MomentsColor.taupe)
            }
            .padding(MomentsSpacing.md)
            .background(
                RoundedRectangle(cornerRadius: MomentsRadius.card, style: .continuous)
                    .fill(Color.white)
            )
            .overlay(
                RoundedRectangle(cornerRadius: MomentsRadius.card, style: .continuous)
                    .strokeBorder(MomentsColor.coral.opacity(0.5),
                                  style: .init(lineWidth: 1.2, dash: selectedItems.isEmpty ? [5, 3] : []))
            )
        }
    }

    // MARK: - Selection grid / empty

    @ViewBuilder
    private var selectionGrid: some View {
        if selectedItems.isEmpty {
            VStack(alignment: .leading, spacing: MomentsSpacing.sm) {
                Text("SELECTED · 0")
                    .tagLabel()
                HandNoteRow("사진을 추가해 필름을 시작해보세요 ✦",
                            tone: .muted, size: 17, alignment: .leading)
                    .padding(.vertical, MomentsSpacing.lg)
            }
        } else {
            VStack(alignment: .leading, spacing: MomentsSpacing.sm) {
                HStack(spacing: MomentsSpacing.xs) {
                    Text("SELECTED · \(selectedItems.count)")
                        .tagLabel()
                    Spacer()
                    if liveCount > 0 {
                        MomentsChip("\(liveCount) LIVE", variant: .live)
                    }
                    if videoCount > 0 {
                        MomentsChip("\(videoCount) VIDEO", variant: .video, icon: .film)
                    }
                }
                LazyVGrid(
                    columns: Array(repeating: GridItem(.flexible(), spacing: MomentsSpacing.sm), count: 3),
                    spacing: MomentsSpacing.sm
                ) {
                    ForEach(Array(selectedItems.enumerated()), id: \.offset) { idx, item in
                        ClipThumbCard(
                            state: .normal,
                            rotationDegrees: rotation(for: idx),
                            size: CGSize(width: 84, height: 108)
                        ) {
                            thumbnailContent(for: item)
                        }
                        .frame(maxWidth: .infinity)
                    }
                }
                .padding(.vertical, MomentsSpacing.sm)
            }
        }
    }

    @ViewBuilder
    private func thumbnailContent(for item: PhotosPickerItem) -> some View {
        let state = media[item] ?? MediaLoadState()
        ZStack {
            if let data = state.thumbnail, let ui = UIImage(data: data) {
                Image(uiImage: ui).resizable().scaledToFill()
            } else if state.thumbnailFailed {
                failedPlaceholder
            } else {
                MomentsColor.ivory
                ProgressView()
                    .tint(MomentsColor.coral)
            }

            // 좌상단: 미디어 종류 칩 (LIVE / VIDEO)
            kindChip(for: state.kind)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                .padding(4)

            // 일반 영상에만 중앙 재생 동그라미. Live Photo는 칩으로만 구분.
            if state.kind == .video {
                Circle()
                    .fill(Color.white.opacity(0.92))
                    .frame(width: 22, height: 22)
                    .overlay(MomentsIcon(.play, size: 9).foregroundColor(MomentsColor.ink).offset(x: 1))
            }

            if state.videoFailed && state.thumbnail != nil {
                // 동영상 추출 실패 표식 (모서리 작은 배지).
                Text("영상 X")
                    .font(MomentsTypography.monoFallback(8, weight: .bold))
                    .foregroundColor(.white)
                    .padding(.horizontal, 5).padding(.vertical, 2)
                    .background(Capsule().fill(MomentsColor.taupe.opacity(0.9)))
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottomLeading)
                    .padding(4)
            }
        }
    }

    @ViewBuilder
    private func kindChip(for kind: MediaKind) -> some View {
        switch kind {
        case .livePhoto:
            MomentsChip("LIVE", variant: .live)
                .scaleEffect(0.78, anchor: .topLeading)
        case .video:
            MomentsChip("VIDEO", variant: .video, icon: .film)
                .scaleEffect(0.78, anchor: .topLeading)
        case .image, .unknown:
            EmptyView()
        }
    }

    private var failedPlaceholder: some View {
        ZStack {
            MomentsColor.ivory
            MomentsIcon(.close, size: 14).foregroundColor(MomentsColor.taupe)
        }
    }

    // MARK: - Bottom bar

    @ViewBuilder
    private var bottomBar: some View {
        if #available(iOS 26.0, *) {
            liquidGlassBottomBar
        } else {
            momentsBottomBar
        }
    }

    @available(iOS 26.0, *)
    private var liquidGlassBottomBar: some View {
        GlassEffectContainer(spacing: MomentsSpacing.xs) {
            HStack(spacing: MomentsSpacing.xs) {
                Button {
                    router.pop()
                } label: {
                    Text("취소")
                        .foregroundStyle(MomentsColor.ink)
                        .frame(maxWidth: .infinity, minHeight: MomentsSpacing.minimumHitTarget)
                }
                .buttonStyle(.glass)
                .frame(maxWidth: .infinity)

                Button {
                    confirmSelection()
                } label: {
                    confirmBottomLabel
                        .foregroundStyle(MomentsColor.ink)
                        .frame(maxWidth: .infinity, minHeight: MomentsSpacing.minimumHitTarget)
                }
                .buttonStyle(.glassProminent)
                .tint(MomentsColor.coral)
                .frame(maxWidth: .infinity)
                .disabled(!canProceed || isResolving)
                .opacity(canProceed ? 1 : 0.5)
            }
        }
    }

    private var momentsBottomBar: some View {
        HStack(spacing: MomentsSpacing.xs) {
            Button("취소") { router.pop() }
                .buttonStyle(.momentsOutline)
                .frame(maxWidth: .infinity)

            Button {
                confirmSelection()
            } label: {
                confirmBottomLabel
            }
            .buttonStyle(.momentsCoral)
            .frame(maxWidth: .infinity)
            .disabled(!canProceed || isResolving)
            .opacity(canProceed ? 1 : 0.5)
        }
    }

    private var confirmBottomLabel: some View {
        HStack(spacing: 6) {
            if isResolving {
                ProgressView().controlSize(.small).tint(MomentsColor.ink)
            } else {
                MomentsIcon(.check, size: 14)
            }
            Text(selectedItems.isEmpty ? "선택 후 다음" : "Timeline으로 (\(selectedItems.count))")
        }
    }

    // MARK: - Derived

    private var canProceed: Bool {
        !selectedItems.isEmpty
    }

    private var liveCount: Int {
        selectedItems.reduce(into: 0) { acc, item in
            if media[item]?.kind == .livePhoto { acc += 1 }
        }
    }

    private var videoCount: Int {
        selectedItems.reduce(into: 0) { acc, item in
            if media[item]?.kind == .video { acc += 1 }
        }
    }

    // MARK: - Load pipeline

    private func syncMedia(for newItems: [PhotosPickerItem]) {
        let retained = Set(newItems)
        media = media.filter { retained.contains($0.key) }

        for item in newItems where media[item] == nil {
            let initialKind = Self.classify(item)
            media[item] = MediaLoadState(kind: initialKind)

            Task {
                async let thumbnail: Data? = Self.loadThumbnail(for: item, kind: initialKind)
                async let videoURLTask: URL? = Self.loadVideoURL(for: item, kind: initialKind)
                async let capturedAt: Date? = Self.loadCapturedAt(for: item)

                // duration·displaySize 는 videoURL 이 결정된 뒤에야 읽을 수 있어 직렬 의존.
                let url = await videoURLTask
                async let durTask: TimeInterval? = Self.loadVideoDuration(from: url)
                async let sizeTask: CGSize? = Self.loadDisplaySize(from: url)
                let (thumb, captured, dur, size) = await (thumbnail, capturedAt, durTask, sizeTask)

                await MainActor.run {
                    guard var state = media[item] else { return }
                    state.thumbnail = thumb
                    state.thumbnailFailed = (thumb == nil)
                    state.videoURL = url
                    state.videoFailed = (url == nil)
                    state.duration = dur
                    state.capturedAt = captured
                    state.displaySize = size
                    media[item] = state
                }
            }
        }
    }

    // MARK: - Capture date (EXIF / PHAsset.creationDate)

    /// Live Photo / 영상의 실제 촬영 일자를 PHAsset.creationDate 에서 가져온다.
    /// PHAsset.creationDate 는 사진 import 시 EXIF DateTimeOriginal 로 채워지므로
    /// "EXIF 촬영 시각" 과 사실상 동일하다.
    private static func loadCapturedAt(for item: PhotosPickerItem) async -> Date? {
        guard await ensurePhotoAuthorization() else { return nil }
        guard let localID = item.itemIdentifier else { return nil }
        let fetch = PHAsset.fetchAssets(withLocalIdentifiers: [localID], options: nil)
        return fetch.firstObject?.creationDate
    }

    // MARK: - Video duration

    /// 영상 파일의 실제 재생 길이(초). Live Photo paired video / 일반 영상 모두 동일 경로.
    /// 권한·코덱 등으로 실패 시 nil → 호출 측에서 fallback 길이를 적용.
    private static func loadVideoDuration(from url: URL?) async -> TimeInterval? {
        guard let url else { return nil }
        let asset = AVURLAsset(url: url)
        do {
            let cm = try await asset.load(.duration)
            let seconds = CMTimeGetSeconds(cm)
            return seconds.isFinite && seconds > 0 ? seconds : nil
        } catch {
            return nil
        }
    }

    // MARK: - Display size

    /// 비디오 트랙의 `naturalSize`에 `preferredTransform`을 적용한 표시상 사이즈.
    /// 세로 영상(rotation 90°)이면 width < height 형태로 정규화돼 나온다.
    /// 합성 시 출력 캔버스 결정과 가운데 정렬에 쓰인다.
    private static func loadDisplaySize(from url: URL?) async -> CGSize? {
        guard let url else { return nil }
        let asset = AVURLAsset(url: url)
        guard let track = (try? await asset.loadTracks(withMediaType: .video))?.first else {
            return nil
        }
        let natural = (try? await track.load(.naturalSize)) ?? .zero
        let transform = (try? await track.load(.preferredTransform)) ?? .identity
        let display = natural.applying(transform)
        let w = abs(display.width)
        let h = abs(display.height)
        guard w > 0, h > 0 else { return nil }
        return CGSize(width: w, height: h)
    }

    // MARK: - Classification

    fileprivate static func classify(_ item: PhotosPickerItem) -> MediaKind {
        let types = item.supportedContentTypes
        // livePhoto는 .image와 .movie 양쪽에 conform될 수 있으므로 가장 먼저 검사.
        if types.contains(where: { $0.conforms(to: .livePhoto) }) { return .livePhoto }
        if types.contains(where: { $0.conforms(to: .movie) || $0.conforms(to: .audiovisualContent) }) { return .video }
        if types.contains(where: { $0.conforms(to: .image) }) { return .image }
        return .unknown
    }

    // MARK: - Thumbnail

    private static func loadThumbnail(for item: PhotosPickerItem, kind: MediaKind) async -> Data? {
        // PhotosPicker의 기본 Data는 Live Photo의 경우 스틸 JPEG을 준다. 썸네일로는 그대로 OK.
        if let data = try? await item.loadTransferable(type: Data.self) {
            if let ui = UIImage(data: data), let jpeg = ui.jpegData(compressionQuality: 0.75) {
                return jpeg
            }
            // 동영상의 경우 Data는 영상 원본이므로 AVAssetImageGenerator로 프레임 추출.
            if kind == .video {
                if let thumb = await videoThumbnailData(from: data) {
                    return thumb
                }
            }
        }
        return nil
    }

    private static func videoThumbnailData(from videoData: Data) async -> Data? {
        let tmp = FileManager.default.temporaryDirectory
            .appendingPathComponent("thumb-\(UUID().uuidString).mov")
        do {
            try videoData.write(to: tmp)
        } catch {
            return nil
        }
        defer { try? FileManager.default.removeItem(at: tmp) }

        let asset = AVURLAsset(url: tmp)
        let gen = AVAssetImageGenerator(asset: asset)
        gen.appliesPreferredTrackTransform = true
        gen.maximumSize = CGSize(width: 480, height: 480)
        do {
            let cgImage = try await gen.image(at: .zero).image
            return UIImage(cgImage: cgImage).jpegData(compressionQuality: 0.75)
        } catch {
            return nil
        }
    }

    // MARK: - Video URL

    private static func loadVideoURL(for item: PhotosPickerItem, kind: MediaKind) async -> URL? {
        // Live Photo: VideoPayload(.movie)로는 paired video를 얻을 수 없으니 곧장 PHAsset 경로로.
        if kind == .livePhoto {
            return await loadViaPHAsset(item: item)
        }

        // 일반 영상: 빠른 경로로 VideoPayload 시도, 실패 시 PHAsset fallback.
        do {
            if let payload = try await item.loadTransferable(type: VideoPayload.self) {
                return payload.url
            }
        } catch {
            mediaLogger.error("VideoPayload transfer failed: \(error.localizedDescription, privacy: .public)")
        }
        return await loadViaPHAsset(item: item)
    }

    /// `PHAsset.fetchAssets` + `PHAssetResourceManager`로 paired video / 원본 영상을 temp 파일로 내림.
    /// Photo Library 권한이 필요함 — 없으면 `ensurePhotoAuthorization`이 시스템 프롬프트를 띄움.
    private static func loadViaPHAsset(item: PhotosPickerItem) async -> URL? {
        mediaLogger.debug("loadViaPHAsset start, hasItemID=\(item.itemIdentifier != nil, privacy: .public)")
        guard await ensurePhotoAuthorization() else {
            mediaLogger.error("Photo library authorization not granted")
            return nil
        }
        guard let localID = item.itemIdentifier else {
            mediaLogger.error("PhotosPickerItem.itemIdentifier was nil — PhotosPicker(photoLibrary:) 누락 여부 점검 필요")
            return nil
        }
        let fetch = PHAsset.fetchAssets(withLocalIdentifiers: [localID], options: nil)
        guard let asset = fetch.firstObject else {
            mediaLogger.error("PHAsset fetch missed for given identifier")
            return nil
        }

        // 우선순위: Live Photo paired video → 원본 영상.
        let resources = PHAssetResource.assetResources(for: asset)
        let preferredTypes: [PHAssetResourceType] = [
            .pairedVideo, .fullSizePairedVideo,
            .video, .fullSizeVideo
        ]
        guard let resource = preferredTypes
                .lazy.compactMap({ type in resources.first(where: { $0.type == type }) })
                .first
        else {
            mediaLogger.warning("No paired/full video resource on asset")
            return nil
        }

        let destURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("paired-\(UUID().uuidString).mov")
        try? FileManager.default.removeItem(at: destURL)

        do {
            try await writePHAssetResource(resource, to: destURL)
            return destURL
        } catch {
            mediaLogger.error("PHAssetResource writeData failed: \(error.localizedDescription, privacy: .public)")
            return nil
        }
    }

    /// iCloud 미디어도 네트워크로 당겨 로컬에 저장.
    private static func writePHAssetResource(_ resource: PHAssetResource, to url: URL) async throws {
        try await withCheckedThrowingContinuation { (cont: CheckedContinuation<Void, Error>) in
            let options = PHAssetResourceRequestOptions()
            options.isNetworkAccessAllowed = true
            PHAssetResourceManager.default().writeData(for: resource, toFile: url, options: options) { error in
                if let error { cont.resume(throwing: error) } else { cont.resume() }
            }
        }
    }

    /// PhotoLibrary 권한을 보장. 이미 있으면 즉시 true. notDetermined이면 시스템 프롬프트.
    /// denied/restricted면 false — 이후 PHAsset fetch/resource write가 실패한다.
    private static func ensurePhotoAuthorization() async -> Bool {
        let status = PHPhotoLibrary.authorizationStatus(for: .readWrite)
        switch status {
        case .authorized, .limited:
            return true
        case .notDetermined:
            let newStatus = await PHPhotoLibrary.requestAuthorization(for: .readWrite)
            return newStatus == .authorized || newStatus == .limited
        default:
            return false
        }
    }

    // MARK: - Confirm

    private func confirmSelection() {
        guard canProceed, !isResolving else { return }
        isResolving = true

        let items = selectedItems

        Task {
            // 아직 로딩 중인 항목이 있으면 잠깐 대기. 무한 대기는 피함.
            for _ in 0..<10 where items.contains(where: { !(media[$0]?.isFullyLoaded ?? false) }) {
                try? await Task.sleep(nanoseconds: 200_000_000)
            }
            let latest = await MainActor.run { self.media }

            let presetPool: [ThumbnailPreset] = [
                .jejuSea, .jejuOrange, .hallasan, .seoulSun,
                .field, .forest, .sunset, .cafe
            ]
            // EXIF 시각이 안 잡힌 항목의 fallback (권한 거부 등 예외 케이스).
            let fallback = Date()

            let clips: [Clip] = items.enumerated().map { idx, item in
                let state = latest[item] ?? MediaLoadState()
                let kind: ClipKind = (state.kind == .video) ? .video : .live
                return Clip(
                    kind: kind,
                    capturedAt: state.capturedAt ?? fallback.addingTimeInterval(TimeInterval(idx) * 60),
                    duration: state.duration ?? 3.0,
                    preset: presetPool[idx % presetPool.count],
                    thumbnailData: state.thumbnail,
                    videoURL: state.videoURL,
                    locationNote: nil,
                    displaySize: state.displaySize
                )
            }

            // 촬영일 오름차순(오래된 것 먼저 → 최신)으로 정렬해 Timeline에 넘긴다.
            // export 시 클립 순서가 그대로 mp4에 반영되므로, 결과 영상도 시간순으로 흐른다.
            let orderedClips = clips.sorted { $0.capturedAt < $1.capturedAt }

            await MainActor.run {
                isResolving = false
                guard !orderedClips.isEmpty else { return }
                let trimmed = titleInput.trimmingCharacters(in: .whitespacesAndNewlines)
                session.replace(clips: orderedClips, title: trimmed)
                router.push(.timeline)
            }
        }
    }

    private func rotation(for index: Int) -> Double {
        switch index % 4 {
        case 0: return -1.2
        case 1: return 0.8
        case 2: return -0.3
        default: return 1.2
        }
    }
}

// MARK: - State & payload

private struct MediaLoadState {
    var kind: MediaKind = .unknown
    var thumbnail: Data? = nil
    var videoURL: URL? = nil
    var duration: TimeInterval? = nil
    var capturedAt: Date? = nil
    var displaySize: CGSize? = nil
    var thumbnailFailed: Bool = false
    var videoFailed: Bool = false

    var isFullyLoaded: Bool {
        (thumbnail != nil || thumbnailFailed) && (videoURL != nil || videoFailed)
    }
}

/// `FileRepresentation`을 통해 PhotosPicker에서 동영상 파일 URL을 temp 디렉터리로 복사받는 전송 타입.
private struct VideoPayload: Transferable {
    let url: URL

    static var transferRepresentation: some TransferRepresentation {
        FileRepresentation(contentType: .movie) { payload in
            SentTransferredFile(payload.url)
        } importing: { received in
            let dest = FileManager.default.temporaryDirectory
                .appendingPathComponent("movie-\(UUID().uuidString).mov")
            try? FileManager.default.removeItem(at: dest)
            try FileManager.default.copyItem(at: received.file, to: dest)
            return VideoPayload(url: dest)
        }
    }
}

#Preview("MediaPicker — empty") {
    MediaPickerView()
        .environment(AppRouter())
        .environment(EditSession())
}
