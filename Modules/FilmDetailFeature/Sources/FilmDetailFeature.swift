import AnalyticsService
import AppCore
import ComposableArchitecture
import Foundation

@Reducer
public struct FilmDetailFeature {
    public init() {}

    @ObservableState
    public struct State: Equatable {
        public let filmID: UUID
        public var film: ArchivedFilm?
        public var isLoading = true
        public var loadError: String?
        public var isPlayerPresented = false
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
        case playerPresentedChanged(Bool)
        case deleteAlertPresentedChanged(Bool)
        case deleteConfirmed
        case deleted
        case deleteFailed(String)
    }

    @Dependency(\.analyticsTracker) var analyticsTracker
    @Dependency(\.filmReader) var reader
    @Dependency(\.filmRemoval) var removal
    @Dependency(\.dismiss) var dismiss

    private enum CancelID { case library }

    public var body: some ReducerOf<Self> {
        Reduce { state, action in
            switch action {
            case .task:
                state.loadError = nil
                if state.film == nil { state.isLoading = true }
                return .run { [id = state.filmID] send in
                    do {
                        for try await films in reader.films() {
                            await send(.filmChanged(films.first { $0.id == id }))
                        }
                    } catch {
                        if !Task.isCancelled { await send(.readFailed(error.localizedDescription)) }
                    }
                }
                .cancellable(id: CancelID.library, cancelInFlight: true)
            case let .filmChanged(film):
                state.film = film
                state.isLoading = false
                return .none
            case let .readFailed(message):
                state.isLoading = false
                state.loadError = message
                return .none
            case .backTapped:
                return .run { _ in await dismiss() }
            case let .playerPresentedChanged(presented):
                state.isPlayerPresented = presented
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
}
