import AnalyticsService
import AppCore
import ComposableArchitecture
import Foundation
import Models

@Reducer
public struct ExportFeature {
    public init() {}

    public enum ExportPhase: Equatable, Sendable {
        case idle, exporting, done, failed
        case limited(ExportQuotaBlockReason)
    }

    public enum SaveStatus: Equatable, Sendable {
        case idle, saving, saved, denied
        case failed(String)

        var allowsRetry: Bool {
            switch self {
            case .idle, .failed, .denied: true
            case .saving, .saved: false
            }
        }
    }

    @ObservableState
    public struct State: Equatable {
        public var phase: ExportPhase
        public var progress: Double
        public var exportedURL: URL?
        public var errorMessage: String?
        public var archiveStatus: SaveStatus = .idle
        public var photoStatus: SaveStatus = .idle
        public var entry: FilmArchiveEntry?
        public var cover: Data?
        public var isPlayerPresented = false
        public var quotaUnlocked = false

        public init(phase: ExportPhase = .idle, progress: Double = 0, exportedURL: URL? = nil) {
            self.phase = phase
            self.progress = progress
            self.exportedURL = exportedURL
        }
    }

    public enum Action {
        case confirmationAppeared
        case startExport(clips: [Clip], rotations: [Clip.ID: ClipRotation], transforms: [Clip.ID: ClipTransform], clipLabels: [Clip.ID: ClipLabel], title: String = "")
        case exportProgress(Double)
        case exportCompleted(URL)
        case exportFailed(String)
        case archiveRequested
        case archiveCompleted(TaskResult<Data?>)
        case saveToPhotoLibraryTapped
        case saveCompleted(FilmPhotoSaveResult)
        case playerPresentedChanged(Bool)
        case backToEditTapped
        case startAnotherTapped
        case homeTapped
        case delegate(Delegate)

        public enum Delegate: Equatable {
            case homeRequested
            case newFilmRequested
        }
    }

    @Dependency(\.filmComposer) var composer
    @Dependency(\.photoWriter) var photoWriter
    @Dependency(\.analyticsTracker) var analyticsTracker
    @Dependency(\.exportQuotaClient) var exportQuotaClient
    @Dependency(\.filmArchive) var filmArchive
    @Dependency(\.uuid) var uuid
    @Dependency(\.date.now) var now
    @Dependency(\.dismiss) var dismiss

    public var body: some ReducerOf<Self> {
        Reduce { state, action in
            switch action {
            case .confirmationAppeared:
                state.quotaUnlocked = exportQuotaClient.isUnlocked()
                return .none

            case let .startExport(clips, rotations, transforms, clipLabels, title):
                guard state.phase == .idle, !clips.isEmpty else { return .none }
                if case let .blocked(reason) = exportQuotaClient.reserveExport() {
                    state.phase = .limited(reason)
                    state.errorMessage = reason.message
                    analyticsTracker.log(.exportFailed(reason: "quota_\(reason)"))
                    return .none
                }
                state.entry = FilmArchiveEntry(
                    id: uuid(), title: title.isEmpty ? "ChalNa" : title, createdAt: now,
                    thumbnail: clips.first?.thumbnailData, clipCount: clips.count,
                    liveCount: clips.filter { $0.kind == .live }.count,
                    duration: clips.reduce(0) { $0 + $1.duration }
                )
                state.phase = .exporting
                analyticsTracker.log(.exportStarted(clipCount: clips.count))
                return .run { send in
                    for await event in composer.export(clips: clips, rotations: rotations, transforms: transforms, clipLabels: clipLabels) {
                        switch event {
                        case let .progress(p): await send(.exportProgress(p))
                        case let .completed(url): await send(.exportCompleted(url))
                        case let .failed(message): await send(.exportFailed(message))
                        }
                    }
                }

            case let .exportProgress(progress):
                guard state.phase == .exporting else { return .none }
                state.progress = progress
                return .none

            case let .exportCompleted(url):
                guard state.phase == .exporting else { return .none }
                state.progress = 1
                state.phase = .done
                state.exportedURL = url
                analyticsTracker.log(.exportCompleted(durationMs: nil))
                let archive = startArchive(state: &state)
                let photo = startPhotoSave(state: &state)
                return .merge(archive, photo)

            case let .exportFailed(message):
                guard state.phase == .exporting else { return .none }
                state.phase = .failed
                state.errorMessage = message
                analyticsTracker.log(.exportFailed(reason: message))
                return .none

            case .archiveRequested:
                return startArchive(state: &state)

            case let .archiveCompleted(result):
                guard state.archiveStatus == .saving else { return .none }
                switch result {
                case let .success(cover):
                    state.cover = cover
                    state.archiveStatus = .saved
                case let .failure(error):
                    state.archiveStatus = .failed(error.localizedDescription)
                }
                return .none

            case .saveToPhotoLibraryTapped:
                return startPhotoSave(state: &state)

            case let .saveCompleted(result):
                guard state.photoStatus == .saving else { return .none }
                switch result {
                case .ok:
                    state.photoStatus = .saved
                    analyticsTracker.log(.vlogSavedToLibrary)
                case .denied:
                    state.photoStatus = .denied
                    analyticsTracker.log(.vlogSaveFailed(reason: "denied"))
                case let .failed(message):
                    state.photoStatus = .failed(message)
                    analyticsTracker.log(.vlogSaveFailed(reason: message))
                }
                return .none

            case let .playerPresentedChanged(value):
                state.isPlayerPresented = value
                return .none
            case .backToEditTapped:
                return .run { _ in await dismiss() }
            case .startAnotherTapped:
                guard state.archiveStatus != .saving else { return .none }
                return .send(.delegate(.newFilmRequested))
            case .homeTapped:
                guard state.archiveStatus != .saving else { return .none }
                return .send(.delegate(.homeRequested))
            case .delegate:
                return .none
            }
        }
    }

    private func startArchive(state: inout State) -> Effect<Action> {
        guard let url = state.exportedURL, let entry = state.entry, state.archiveStatus.allowsRetry else { return .none }
        state.archiveStatus = .saving
        return .run { send in
            await send(.archiveCompleted(TaskResult { try await filmArchive.archive(entry, movie: url) }))
        }
    }

    private func startPhotoSave(state: inout State) -> Effect<Action> {
        guard let url = state.exportedURL, state.photoStatus.allowsRetry else { return .none }
        state.photoStatus = .saving
        return .run { send in
            await send(.saveCompleted(photoWriter.saveVideo(at: url)))
        }
    }
}
