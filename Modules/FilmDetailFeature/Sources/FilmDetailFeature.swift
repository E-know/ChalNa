import AnalyticsService
import AppCore
import AVFoundation
import ComposableArchitecture
import Foundation
import Models

@Reducer
public struct FilmDetailFeature {
    public init() {}

    public enum VideoAction: Equatable {
        case play, share
    }

    @ObservableState
    public struct State: Equatable {
        public let filmID: UUID
        public var film: ArchivedFilm?
        public var isLoading = true
        public var loadError: String?
        public var videoAvailability: PhotoVideoAvailability?
        public var isRequestingPhotoAccess = false
        public var isLoadingVideo = false
        public var videoLoadFailed = false
        public var playerItem: AVPlayerItem?
        public var shareURL: URL?
        public var isDeleteAlertPresented = false
        public var isDeleting = false
        public var deleteError: String?

        public init(filmID: UUID) { self.filmID = filmID }
    }

    public enum Action: Equatable {
        case task
        case filmChanged(ArchivedFilm?)
        case readFailed(String)
        case backTapped
        case videoAvailabilityChanged
        case photoAccessTapped
        case photoAccessCompleted
        case videoTapped(VideoAction)
        case playerItemLoaded(assetID: String, item: AVPlayerItem?)
        case shareURLLoaded(assetID: String, url: URL?)
        case playerDismissed
        case shareDismissed(URL)
        case deleteAlertPresentedChanged(Bool)
        case deleteConfirmed
        case deleted
        case deleteFailed(String)
    }

    @Dependency(\.analyticsTracker) var analyticsTracker
    @Dependency(\.filmReader) var reader
    @Dependency(\.filmRemoval) var removal
    @Dependency(\.filmVideo) var video
    @Dependency(\.dismiss) var dismiss

    private enum CancelID { case library, photoChanges, videoLoad }

    public var body: some ReducerOf<Self> {
        Reduce { state, action in
            switch action {
            case .task:
                state.loadError = nil
                if state.film == nil { state.isLoading = true }
                return .merge(
                    .run { [id = state.filmID] send in
                        do {
                            for try await films in reader.films() {
                                await send(.filmChanged(films.first { $0.id == id }))
                            }
                        } catch {
                            if !Task.isCancelled { await send(.readFailed(error.localizedDescription)) }
                        }
                    }
                    .cancellable(id: CancelID.library, cancelInFlight: true),
                    .run { send in
                        for await _ in video.changes() {
                            await send(.videoAvailabilityChanged)
                        }
                    }
                    .cancellable(id: CancelID.photoChanges, cancelInFlight: true)
                )
            case let .filmChanged(film):
                let changedSource = state.film?.appMovieURL != film?.appMovieURL
                    || (film?.appMovieURL == nil && state.film?.photoAssetIdentifier != film?.photoAssetIdentifier)
                state.film = film
                state.isLoading = false
                refreshVideoAvailability(state: &state)
                guard changedSource else { return .none }
                state.isLoadingVideo = false
                state.videoLoadFailed = false
                state.playerItem = nil
                return .cancel(id: CancelID.videoLoad)
            case let .readFailed(message):
                state.isLoading = false
                state.loadError = message
                return .none
            case .backTapped:
                return .run { _ in await dismiss() }
            case .videoAvailabilityChanged:
                refreshVideoAvailability(state: &state)
                return .none
            case .photoAccessTapped:
                refreshVideoAvailability(state: &state)
                guard state.videoAvailability == .authorizationRequired, !state.isRequestingPhotoAccess else { return .none }
                state.isRequestingPhotoAccess = true
                return .run { send in
                    await video.requestAccess()
                    await send(.photoAccessCompleted)
                }
            case .photoAccessCompleted:
                state.isRequestingPhotoAccess = false
                refreshVideoAvailability(state: &state)
                return .none
            case let .videoTapped(action):
                guard !state.isLoadingVideo, state.playerItem == nil, state.shareURL == nil,
                      let film = state.film else { return .none }
                if let url = film.appMovieURL {
                    if action == .play { state.playerItem = AVPlayerItem(url: url) }
                    return .none
                }
                guard let assetID = film.photoAssetIdentifier else { return .none }
                refreshVideoAvailability(state: &state)
                guard state.videoAvailability == .available else { return .none }
                state.isLoadingVideo = true
                state.videoLoadFailed = false
                return .run { send in
                    switch action {
                    case .play:
                        let item = await video.loadPlayerItem(assetID)
                        await send(.playerItemLoaded(assetID: assetID, item: item))
                    case .share:
                        let url = await video.loadShareURL(assetID)
                        await MainActor.run {
                            if Task.isCancelled {
                                if let url { try? FileManager.default.removeItem(at: url) }
                            } else {
                                send(.shareURLLoaded(assetID: assetID, url: url))
                            }
                        }
                    }
                }
                .cancellable(id: CancelID.videoLoad, cancelInFlight: true)
            case let .playerItemLoaded(assetID, item):
                guard finishLoadingVideo(assetID: assetID, state: &state) else { return .none }
                state.playerItem = item
                state.videoLoadFailed = item == nil
                return .none
            case let .shareURLLoaded(assetID, url):
                guard finishLoadingVideo(assetID: assetID, state: &state) else {
                    if let url { try? FileManager.default.removeItem(at: url) }
                    return .none
                }
                state.shareURL = url
                state.videoLoadFailed = url == nil
                return .none
            case .playerDismissed:
                state.playerItem = nil
                return .none
            case let .shareDismissed(url):
                guard state.shareURL == url else { return .none }
                state.shareURL = nil
                try? FileManager.default.removeItem(at: url)
                return .none
            case let .deleteAlertPresentedChanged(presented):
                state.isDeleteAlertPresented = presented
                return .none
            case .deleteConfirmed:
                guard !state.isDeleting else { return .none }
                state.isDeleting = true
                state.isDeleteAlertPresented = false
                state.deleteError = nil
                return .run { [id = state.filmID] send in
                    do {
                        try await removal.remove(id: id)
                        await send(.deleted)
                    } catch { await send(.deleteFailed(error.localizedDescription)) }
                }
            case .deleted:
                state.isDeleting = false
                analyticsTracker.log(.filmDeleted(filmID: state.filmID))
                return .run { _ in await dismiss() }
            case let .deleteFailed(message):
                state.isDeleting = false
                state.deleteError = message
                return .none
            }
        }
    }

    private func refreshVideoAvailability(state: inout State) {
        guard state.film?.appMovieURL == nil, let assetID = state.film?.photoAssetIdentifier else {
            state.videoAvailability = nil
            return
        }
        state.videoAvailability = video.availability(assetID)
        if state.videoAvailability != .available {
            state.playerItem = nil
            state.videoLoadFailed = false
        }
    }

    private func finishLoadingVideo(assetID: String, state: inout State) -> Bool {
        guard state.film?.appMovieURL == nil, state.film?.photoAssetIdentifier == assetID else { return false }
        state.isLoadingVideo = false
        refreshVideoAvailability(state: &state)
        return state.videoAvailability == .available
    }
}
