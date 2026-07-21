import ComposableArchitecture
import Foundation
import Photos
import Models
import PhotosService
import AnalyticsService

/// 사진 보관함에서 Live Photo / 영상을 선택해 Timeline 으로 넘기는 화면의 Reducer.
@Reducer
public struct MediaPickerFeature {
    public init() {}

    // MARK: - State

    @ObservableState
    public struct State {
        public let source: MediaPickerSource

        // 권한 + 사진 라이브러리
        public var photoAuthorizationStatus: PHAuthorizationStatus
        public var photoAssets: [PhotoLibraryAsset] = []
        public var assetThumbnails: [String: Data] = [:]
        public var media: [String: MediaLoadState] = [:]
        public var selectedAssetIDs: [String] = []
        public var isPhotoLibraryLoading: Bool = false
        public var isPhotoPermissionAlertPresented: Bool = false
        public var isSystemPhotoPickerPresented: Bool = false
        /// PHPicker가 닫히고 PickedMediaLoader가 비동기 추출을 끝낼 때까지의 짧은 공백 구간을 채우는 오버레이용.
        public var isPreparingPickedMedia: Bool = false
        /// 사진 추출 진행 카운트 (완료, 전체). 오버레이가 떠 있는 동안에만 non-nil.
        public var preparingPickedMediaProgress: PreparingPickedMediaProgress?

        // Dev fixtures
        public var devAssets: [DevMediaAsset] = []
        public var selectedDevAssetIDs: [DevMediaAsset.ID] = []
        public var devErrorMessage: String?

        // 공통
        public var titleInput: String = ""
        public var scrollProgress: Double = 0
        public var isResolving: Bool = false

        /// 미리보기 시트로 띄울 선택된 미디어. nil 이면 시트가 닫혀 있음.
        public var previewAsset: PhotoLibraryAsset?

        public init(
            source: MediaPickerSource = .photoLibrary,
            photoAuthorizationStatus: PHAuthorizationStatus = PHPhotoLibrary.authorizationStatus(for: .readWrite)
        ) {
            self.source = source
            self.photoAuthorizationStatus = photoAuthorizationStatus
        }
    }

    // MARK: - Action

    public enum Action {
        // Lifecycle
        case task
        case scrollProgressChanged(Double)
        case titleChanged(String)

        // Header / navigation
        case dismissTapped

        // Permission / library launcher
        case photoLauncherTapped
        case authorizationStatusUpdated(PHAuthorizationStatus)
        case permissionRequestCompleted(PHAuthorizationStatus)
        case permissionAlertConfirmTapped
        case permissionAlertDismissed
        case permissionAlertPresentedChanged(Bool)
        case openSystemPhotoPicker
        case systemPhotoPickerPresentedChanged(Bool)

        // Library data
        case pickedMediaLoadingStarted(total: Int)
        case pickedMediaProgressUpdated(done: Int)
        case photosPickedFromSystemPicker(media: [PickedMedia])
        case photoAssetTapped(PhotoLibraryAsset)

        // Preview
        case previewRequested(PhotoLibraryAsset)
        case previewDismissed

        // Media pipeline
        case startSyncingMedia(ids: [String])
        case mediaLoaded(id: String, MediaLoaded)

        // Dev fixtures
        case devAssetsLoaded([DevMediaAsset])
        case devAssetTapped(DevMediaAsset.ID)

        // Primary action
        case primaryActionTapped
        case devResolveCompleted(Result<[Clip], MediaPickerError>)

        case delegate(Delegate)

        /// 부모(AppFeature)가 화면 전환으로 해석하는 네비게이션 인텐트.
        public enum Delegate {
            /// 선택 확정 — 부모가 EditSession 에 싣고 Timeline 으로 push.
            case selectionConfirmed(clips: [Clip], title: String)
        }
    }

    public struct MediaLoaded: Equatable {
        public let thumbnail: Data?
        public let videoURL: URL?
        public let duration: TimeInterval?
        public let capturedAt: Date?
        public let displaySize: CGSize?

        public init(thumbnail: Data?, videoURL: URL?, duration: TimeInterval?, capturedAt: Date?, displaySize: CGSize?) {
            self.thumbnail = thumbnail
            self.videoURL = videoURL
            self.duration = duration
            self.capturedAt = capturedAt
            self.displaySize = displaySize
        }
    }

    public struct MediaPickerError: Error, Equatable {
        public let message: String
        public init(_ message: String) { self.message = message }
    }

    // MARK: - Dependencies

    @Dependency(\.photoLibraryClient) var photoLibraryClient
    @Dependency(\.analyticsTracker) var analyticsTracker
    @Dependency(\.dismiss) var dismiss

    // MARK: - Reducer

    public var body: some ReducerOf<Self> {
        Reduce { state, action in
            switch action {
            case .task:
                let currentStatus = photoLibraryClient.authorizationStatus()
                state.photoAuthorizationStatus = currentStatus
                switch state.source {
                case .devFixtures(let source):
                    return .run { send in
                        let assets = await source.availableAssets()
                        await send(.devAssetsLoaded(assets))
                    }
                case .photoLibrary:
                    return .none
                }

            case let .scrollProgressChanged(progress):
                let clamped = max(0, min(1, progress))
                guard abs(clamped - state.scrollProgress) > 0.01 else { return .none }
                state.scrollProgress = clamped
                return .none

            case let .titleChanged(title):
                state.titleInput = title
                return .none

            case .dismissTapped:
                return .run { _ in await dismiss() }

            case .photoLauncherTapped:
                let current = photoLibraryClient.authorizationStatus()
                state.photoAuthorizationStatus = current
                switch current {
                case .authorized, .limited:
                    return .send(.openSystemPhotoPicker)
                case .notDetermined:
                    return .run { send in
                        let status = await photoLibraryClient.requestAuthorization()
                        await send(.permissionRequestCompleted(status))
                    }
                default:
                    state.isPhotoPermissionAlertPresented = true
                    return .none
                }

            case let .authorizationStatusUpdated(status):
                state.photoAuthorizationStatus = status
                return .none

            case let .permissionRequestCompleted(status):
                state.photoAuthorizationStatus = status
                if status == .authorized || status == .limited {
                    return .send(.openSystemPhotoPicker)
                }
                state.isPhotoPermissionAlertPresented = true
                return .none

            case .permissionAlertConfirmTapped:
                state.isPhotoPermissionAlertPresented = false
                return .none

            case .permissionAlertDismissed:
                state.isPhotoPermissionAlertPresented = false
                return .none

            case let .permissionAlertPresentedChanged(value):
                state.isPhotoPermissionAlertPresented = value
                return .none

            case .openSystemPhotoPicker:
                state.isSystemPhotoPickerPresented = true
                return .none

            case let .systemPhotoPickerPresentedChanged(value):
                state.isSystemPhotoPickerPresented = value
                return .none

            case let .pickedMediaLoadingStarted(total):
                state.isPreparingPickedMedia = true
                state.preparingPickedMediaProgress = .init(done: 0, total: max(total, 0))
                return .none

            case let .pickedMediaProgressUpdated(done):
                if var progress = state.preparingPickedMediaProgress {
                    progress.done = min(max(done, 0), progress.total)
                    state.preparingPickedMediaProgress = progress
                }
                return .none

            case let .photosPickedFromSystemPicker(media):
                state.isSystemPhotoPickerPresented = false
                state.isPhotoLibraryLoading = false
                state.isPreparingPickedMedia = false
                state.preparingPickedMediaProgress = nil
                guard !media.isEmpty else { return .none }

                for item in media {
                    let asset = PhotoLibraryAsset(
                        id: item.id,
                        kind: item.kind,
                        capturedAt: item.capturedAt,
                        pixelSize: item.displaySize ?? .zero
                    )
                    if !state.photoAssets.contains(where: { $0.id == item.id }) {
                        state.photoAssets.append(asset)
                    }
                    if !state.selectedAssetIDs.contains(item.id) {
                        state.selectedAssetIDs.append(item.id)
                    }
                    if let thumb = item.thumbnailData {
                        state.assetThumbnails[item.id] = thumb
                    }

                    // picker 단계에서 이미 모든 데이터를 꺼냈으므로 비동기 로딩 없이 즉시 ready 상태.
                    var loaded = MediaLoadState(
                        kind: item.kind,
                        thumbnail: item.thumbnailData,
                        isLoading: false
                    )
                    loaded.thumbnailFailed = (item.thumbnailData == nil)
                    loaded.videoURL = item.videoURL
                    loaded.videoFailed = (item.videoURL == nil)
                    loaded.duration = item.duration
                    loaded.capturedAt = item.capturedAt
                    loaded.displaySize = item.displaySize
                    state.media[item.id] = loaded
                }
                return .none

            case let .photoAssetTapped(asset):
                if let idx = state.selectedAssetIDs.firstIndex(of: asset.id) {
                    state.selectedAssetIDs.remove(at: idx)
                    state.photoAssets.removeAll { $0.id == asset.id }
                    state.media[asset.id] = nil
                    state.assetThumbnails[asset.id] = nil
                } else {
                    state.selectedAssetIDs.append(asset.id)
                }
                guard !state.selectedAssetIDs.isEmpty else { return .none }
                return .send(.startSyncingMedia(ids: state.selectedAssetIDs))

            case let .previewRequested(asset):
                state.previewAsset = asset
                return .none

            case .previewDismissed:
                state.previewAsset = nil
                return .none

            case let .startSyncingMedia(ids):
                let retained = Set(ids)
                state.media = state.media.filter { retained.contains($0.key) }

                let toLoad: [(id: String, kind: PhotoLibraryAssetKind)] = ids.compactMap { id in
                    guard state.media[id] == nil else { return nil }
                    let kind = state.photoAssets.first(where: { $0.id == id })?.kind ?? .unknown
                    state.media[id] = MediaLoadState(kind: kind, thumbnail: state.assetThumbnails[id], isLoading: true)
                    return (id, kind)
                }

                guard !toLoad.isEmpty else { return .none }

                return .run { send in
                    await withTaskGroup(of: Void.self) { group in
                        for entry in toLoad {
                            group.addTask {
                                async let thumbnailTask: Data? = photoLibraryClient.loadThumbnail(entry.id)
                                async let videoURLTask: URL? = photoLibraryClient.loadVideoURL(entry.id, entry.kind)
                                async let capturedAtTask: Date? = photoLibraryClient.loadCapturedAt(entry.id)
                                let url = await videoURLTask
                                let duration: TimeInterval? = if let url { await photoLibraryClient.loadVideoDuration(url) } else { nil }
                                let size: CGSize? = if let url { await photoLibraryClient.loadDisplaySize(url) } else { nil }
                                let (thumbnail, capturedAt) = await (thumbnailTask, capturedAtTask)
                                let payload = MediaLoaded(
                                    thumbnail: thumbnail,
                                    videoURL: url,
                                    duration: duration,
                                    capturedAt: capturedAt,
                                    displaySize: size
                                )
                                await send(.mediaLoaded(id: entry.id, payload))
                            }
                        }
                    }
                }

            case let .mediaLoaded(id, payload):
                guard var ms = state.media[id] else { return .none }
                ms.thumbnail = payload.thumbnail ?? state.assetThumbnails[id]
                if let t = payload.thumbnail {
                    state.assetThumbnails[id] = t
                }
                ms.thumbnailFailed = (ms.thumbnail == nil)
                ms.videoURL = payload.videoURL
                ms.videoFailed = (payload.videoURL == nil)
                ms.duration = payload.duration
                ms.capturedAt = payload.capturedAt
                ms.displaySize = payload.displaySize
                ms.isLoading = false
                state.media[id] = ms
                return .none

            case let .devAssetsLoaded(assets):
                state.devAssets = assets
                return .none

            case let .devAssetTapped(id):
                state.devErrorMessage = nil
                if let idx = state.selectedDevAssetIDs.firstIndex(of: id) {
                    state.selectedDevAssetIDs.remove(at: idx)
                } else {
                    state.selectedDevAssetIDs.append(id)
                }
                return .none

            case .primaryActionTapped:
                guard !state.isResolving else { return .none }
                switch state.source {
                case .photoLibrary:
                    return confirmPhotoLibrary(state: &state)
                case .devFixtures(let mediaSource):
                    return confirmDevFixtures(state: &state, source: mediaSource)
                }

            case let .devResolveCompleted(.success(clips)):
                state.isResolving = false
                guard !clips.isEmpty else { return .none }
                let ordered = clips.sorted { $0.capturedAt < $1.capturedAt }
                let trimmed = state.titleInput.trimmingCharacters(in: .whitespacesAndNewlines)
                analyticsTracker.log(.clipsConfirmed(count: ordered.count))
                return .send(.delegate(.selectionConfirmed(clips: ordered, title: trimmed)))

            case let .devResolveCompleted(.failure(error)):
                state.isResolving = false
                state.devErrorMessage = error.message
                return .none

            case .delegate:
                return .none
            }
        }
    }

    // MARK: - Confirm helpers

    private func confirmPhotoLibrary(state: inout State) -> Effect<Action> {
        let ids = state.selectedAssetIDs
        guard !ids.isEmpty else { return .none }
        guard ids.allSatisfy({ state.media[$0]?.isReadyForTimeline == true }) else { return .none }

        let presetPool: [ThumbnailPreset] = [
            .jejuSea, .jejuOrange, .hallasan, .seoulSun,
            .field, .forest, .sunset, .cafe,
        ]
        let fallback = Date()
        let mediaSnapshot = state.media

        let clips: [Clip] = ids.enumerated().map { idx, id in
            let s = mediaSnapshot[id] ?? MediaLoadState()
            let kind: ClipKind = (s.kind == .video) ? .video : .live
            return Clip(
                kind: kind,
                capturedAt: s.capturedAt ?? fallback.addingTimeInterval(TimeInterval(idx) * 60),
                duration: s.duration ?? 3.0,
                preset: presetPool[idx % presetPool.count],
                thumbnailData: s.thumbnail,
                videoURL: s.videoURL,
                locationNote: nil,
                displaySize: s.displaySize
            )
        }
        let ordered = clips.sorted { $0.capturedAt < $1.capturedAt }
        let trimmed = state.titleInput.trimmingCharacters(in: .whitespacesAndNewlines)
        analyticsTracker.log(.clipsConfirmed(count: ordered.count))
        return .send(.delegate(.selectionConfirmed(clips: ordered, title: trimmed)))
    }

    private func confirmDevFixtures(state: inout State, source: any DevMediaSourcing) -> Effect<Action> {
        state.isResolving = true
        state.devErrorMessage = nil
        let ids = state.selectedDevAssetIDs
        return .run { send in
            do {
                let clips = try await source.resolve(assetIDs: ids)
                await send(.devResolveCompleted(.success(clips)))
            } catch {
                await send(.devResolveCompleted(.failure(MediaPickerError(error.localizedDescription))))
            }
        }
    }
}

// MARK: - Supporting types (View 와 공유)

public enum MediaPickerSource: Sendable {
    case photoLibrary
    case devFixtures(any DevMediaSourcing)
}

/// PHPicker 결과 추출 진행 상태 (완료 개수 / 전체 개수). 오버레이 카운트 표시용.
public struct PreparingPickedMediaProgress: Equatable, Sendable {
    public var done: Int
    public var total: Int

    public init(done: Int, total: Int) {
        self.done = done
        self.total = total
    }
}

public struct MediaLoadState: Equatable {
    public var kind: PhotoLibraryAssetKind = .unknown
    public var thumbnail: Data? = nil
    public var videoURL: URL? = nil
    public var duration: TimeInterval? = nil
    public var capturedAt: Date? = nil
    public var displaySize: CGSize? = nil
    public var isLoading: Bool = false
    public var thumbnailFailed: Bool = false
    public var videoFailed: Bool = false

    public init(
        kind: PhotoLibraryAssetKind = .unknown,
        thumbnail: Data? = nil,
        isLoading: Bool = false
    ) {
        self.kind = kind
        self.thumbnail = thumbnail
        self.isLoading = isLoading
    }

    public var isFullyLoaded: Bool {
        !isLoading && (thumbnail != nil || thumbnailFailed) && (videoURL != nil || videoFailed)
    }

    public var isReadyForTimeline: Bool {
        !isLoading && thumbnail != nil && (!kind.hasMotion || videoURL != nil)
    }

    public var didFailTimelinePreparation: Bool {
        !isLoading && (thumbnail == nil || (kind.hasMotion && videoURL == nil))
    }
}
