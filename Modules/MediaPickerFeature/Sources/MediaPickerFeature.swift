import ComposableArchitecture
import Foundation
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
        public var photoAuthorizationStatus: PhotoLibraryAccess
        public var photoAssets: [PhotoLibraryAsset] = []
        public var assetThumbnails: [String: Data] = [:]
        public var media: [String: MediaLoadState] = [:]
        public var selectedAssetIDs: [String] = []
        public var isPhotoPermissionAlertPresented: Bool = false
        public var isSystemPhotoPickerPresented: Bool = false
        public var isPreparingPickedMedia: Bool { preparingPickedMediaProgress != nil }
        public var preparingPickedMediaProgress: PreparingPickedMediaProgress?

        // Dev fixtures
        public var devAssets: [DevMediaAsset] = []
        public var selectedDevAssetIDs: [DevMediaAsset.ID] = []
        public var devErrorMessage: String?

        // 공통
        public var titleInput: String = ""
        public var isResolving: Bool = false

        /// 미리보기 시트로 띄울 선택된 미디어. nil 이면 시트가 닫혀 있음.
        public var previewAsset: PhotoLibraryAsset?

        public init(
            source: MediaPickerSource = .photoLibrary,
            photoAuthorizationStatus: PhotoLibraryAccess = .notDetermined
        ) {
            self.source = source
            self.photoAuthorizationStatus = photoAuthorizationStatus
        }
    }

    // MARK: - Action

    public enum Action {
        // Lifecycle
        case task
        case titleChanged(String)

        // Header / navigation

        // Permission / library launcher
        case photoLauncherTapped
        case authorizationStatusUpdated(PhotoLibraryAccess)
        case permissionRequestCompleted(PhotoLibraryAccess)
        case permissionAlertConfirmTapped
        case permissionAlertDismissed
        case permissionAlertPresentedChanged(Bool)
        case openSystemPhotoPicker
        case systemPhotoPickerPresentedChanged(Bool)

        // Library data
        case systemPickerFinished([any PickedMediaLoading])
        case pickedMediaTransferProgress(importID: UUID, index: Int, fraction: Double)
        case pickedMediaLoaded(importID: UUID, index: Int, media: PickedMedia)
        case cancelPreparingPickedMedia
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
    @Dependency(\.uuid) var uuid

    private enum CancelID: Hashable {
        case importing(UUID)
    }

    private static let concurrentImports = 3

    // MARK: - Reducer

    public var body: some ReducerOf<Self> {
        Reduce { state, action in
            switch action {
            case .task:
                switch state.source {
                case .devFixtures(let source):
                    return .run { send in
                        let assets = await source.availableAssets()
                        await send(.devAssetsLoaded(assets))
                    }
                case .photoLibrary:
                    state.photoAuthorizationStatus = photoLibraryClient.authorizationStatus()
                    return .none
                }

            case let .titleChanged(title):
                state.titleInput = title
                return .none

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

            case let .systemPickerFinished(results):
                state.isSystemPhotoPickerPresented = false
                guard !results.isEmpty, !state.isPreparingPickedMedia else { return .none }
                let importID = uuid()
                state.preparingPickedMediaProgress = .init(id: importID, total: results.count)
                return .run { send in
                    await withTaskGroup(of: (Int, PickedMedia).self) { group in
                        for (index, result) in results.enumerated() {
                            if index >= Self.concurrentImports, let (index, item) = await group.next() {
                                await send(.pickedMediaLoaded(importID: importID, index: index, media: item))
                            }
                            guard !Task.isCancelled else { return }
                            group.addTask {
                                let (updates, progress) = AsyncStream<Double>.makeStream(bufferingPolicy: .bufferingNewest(1))
                                async let reportProgress: Void = {
                                    for await fraction in updates {
                                        await send(.pickedMediaTransferProgress(importID: importID, index: index, fraction: fraction))
                                    }
                                }()
                                let picked = await result.load(progress: { progress.yield($0) }) ?? PickedMedia(
                                    id: result.id, kind: .unknown,
                                    thumbnailData: nil, videoURL: nil, capturedAt: nil,
                                    duration: nil, displaySize: nil
                                )
                                progress.finish()
                                await reportProgress
                                return (index, picked)
                            }
                        }
                        for await (index, picked) in group {
                            await send(.pickedMediaLoaded(importID: importID, index: index, media: picked))
                        }
                    }
                }
                .cancellable(id: CancelID.importing(importID))

            case let .pickedMediaTransferProgress(importID, index, fraction):
                guard var progress = state.preparingPickedMediaProgress, progress.id == importID,
                      progress.completed[index] == nil, fraction.isFinite else { return .none }
                progress.transfers[index] = max(progress.transfers[index] ?? 0, min(fraction, 0.99))
                state.preparingPickedMediaProgress = progress
                return .none

            case let .pickedMediaLoaded(importID, index, item):
                guard var progress = state.preparingPickedMediaProgress, progress.id == importID else { return .none }
                progress.transfers[index] = nil
                progress.completed[index] = item
                if progress.done == progress.total {
                    storePickedMedia(progress.orderedMedia, in: &state)
                    state.preparingPickedMediaProgress = nil
                } else {
                    state.preparingPickedMediaProgress = progress
                }
                return .none

            case .cancelPreparingPickedMedia:
                guard let progress = state.preparingPickedMediaProgress else { return .none }
                storePickedMedia(progress.orderedMedia.filter { $0.thumbnailData != nil && $0.videoURL != nil }, in: &state)
                state.preparingPickedMediaProgress = nil
                return .cancel(id: CancelID.importing(progress.id))

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

    private func storePickedMedia(_ media: [PickedMedia], in state: inout State) {
        for item in media {
            // 재선택한 원본을 읽지 못해도 이미 준비된 동일 클립은 그대로 사용할 수 있다.
            if state.media[item.id]?.isReadyForTimeline == true,
               item.thumbnailData == nil || item.videoURL == nil { continue }
            let asset = PhotoLibraryAsset(
                id: item.id, kind: item.kind, capturedAt: item.capturedAt,
                pixelSize: item.displaySize ?? .zero
            )
            if let index = state.photoAssets.firstIndex(where: { $0.id == item.id }) {
                state.photoAssets[index] = asset
            } else {
                state.photoAssets.append(asset)
            }
            if !state.selectedAssetIDs.contains(item.id) {
                state.selectedAssetIDs.append(item.id)
            }
            state.assetThumbnails[item.id] = item.thumbnailData

            var loaded = MediaLoadState(kind: item.kind, thumbnail: item.thumbnailData)
            loaded.thumbnailFailed = (item.thumbnailData == nil)
            loaded.videoURL = item.videoURL
            loaded.videoFailed = (item.videoURL == nil)
            loaded.duration = item.duration
            loaded.capturedAt = item.capturedAt
            loaded.displaySize = item.displaySize
            state.media[item.id] = loaded
        }
    }

    // MARK: - Confirm helpers

    private func confirmPhotoLibrary(state: inout State) -> Effect<Action> {
        let ids = state.selectedAssetIDs
        guard state.canProceed else { return .none }

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
                duration: s.duration,
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

/// 한 번의 사진 가져오기에서 준비된 결과와 진행률을 원래 선택 위치로 기록한다.
public struct PreparingPickedMediaProgress: Equatable, Sendable {
    let id: UUID
    public let total: Int
    var completed: [Int: PickedMedia] = [:]
    var transfers: [Int: Double] = [:]

    public var done: Int { completed.count }
    public var fractionCompleted: Double {
        (Double(done) + transfers.values.reduce(0, +)) / Double(total)
    }

    func thumbnail(at index: Int) -> Data? {
        completed[index]?.thumbnailData
    }

    var orderedMedia: [PickedMedia] {
        completed.sorted { $0.key < $1.key }.map(\.value)
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

extension MediaPickerFeature.State {
    var selectedCount: Int {
        switch source {
        case .photoLibrary: return selectedAssetIDs.count
        case .devFixtures: return selectedDevAssetIDs.count
        }
    }

    var selectedAssets: [PhotoLibraryAsset] {
        let byID = Dictionary(uniqueKeysWithValues: photoAssets.map { ($0.id, $0) })
        return selectedAssetIDs.compactMap { byID[$0] }
    }

    var liveCount: Int { selectedAssetIDs.filter { media[$0]?.kind == .livePhoto }.count }
    var videoCount: Int { selectedAssetIDs.filter { media[$0]?.kind == .video }.count }

    var hasUnavailableMedia: Bool {
        selectedAssetIDs.contains { media[$0]?.didFailTimelinePreparation == true }
    }

    var canProceed: Bool {
        switch source {
        case .photoLibrary:
            return !selectedAssetIDs.isEmpty && selectedAssetIDs.allSatisfy { media[$0]?.isReadyForTimeline == true }
        case .devFixtures:
            return !selectedDevAssetIDs.isEmpty
        }
    }
}
