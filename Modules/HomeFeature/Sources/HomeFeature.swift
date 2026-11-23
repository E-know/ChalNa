import AnalyticsService
import AppCore
import ComposableArchitecture
import Foundation

@Reducer
public struct HomeFeature {
    public init() {}

    @ObservableState
    public struct State: Equatable {
        public var films: [ArchivedFilm] = []
        public var isLoading = true
        public var readFailed = false
        public init() {}
    }

    public enum Action {
        case onAppear
        case task
        case filmsLoaded([ArchivedFilm])
        case readFailed
        case retryTapped
        case disappeared
        case newVlogButtonTapped
        case settingsButtonTapped
        case filmTapped(filmID: UUID)
        case delegate(Delegate)

        public enum Delegate: Equatable {
            case newVlogRequested
            case settingsRequested
            case filmDetailRequested(filmID: UUID)
        }
    }

    private enum CancelID { case library }
    @Dependency(\.analyticsTracker) var analyticsTracker
    @Dependency(\.filmReader) var filmReader

    public var body: some ReducerOf<Self> {
        Reduce { state, action in
            switch action {
            case .onAppear:
                analyticsTracker.log(.homeViewed)
                return .none
            case .task, .retryTapped:
                state.isLoading = state.films.isEmpty
                state.readFailed = false
                return .run { send in
                    do {
                        for try await films in filmReader.films() {
                            await send(.filmsLoaded(films))
                        }
                    } catch {
                        if !Task.isCancelled { await send(.readFailed) }
                    }
                }.cancellable(id: CancelID.library, cancelInFlight: true)
            case let .filmsLoaded(films):
                state.films = films
                state.isLoading = false
                state.readFailed = false
                return .none
            case .readFailed:
                state.isLoading = false
                state.readFailed = true
                return .none
            case .disappeared:
                return .cancel(id: CancelID.library)
            case .newVlogButtonTapped:
                analyticsTracker.log(.newVlogTapped)
                return .send(.delegate(.newVlogRequested))
            case .settingsButtonTapped:
                return .send(.delegate(.settingsRequested))
            case let .filmTapped(filmID):
                return .send(.delegate(.filmDetailRequested(filmID: filmID)))
            case .delegate:
                return .none
            }
        }
    }
}
