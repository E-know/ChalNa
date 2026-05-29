import ComposableArchitecture
import Foundation
import AppCore
import AnalyticsService
import HomeFeature
import MediaPickerFeature
import TimelineFeature
import ExportFeature
import FilmDetailFeature
import Models
import SettingsFeature

/// 앱 루트 Reducer. Home 을 root 로 두고 mediaPicker / timeline / export 를 StackState 로 push.
@Reducer
public struct AppFeature {
    public init() {}

    @ObservableState
    public struct State {
        public var home = HomeFeature.State()
        public var path = StackState<Path.State>()

        public init() {}
    }

    public enum Action {
        case home(HomeFeature.Action)
        case path(StackActionOf<Path>)

        // AppRouter wrapper 가 트리거하는 navigation intent
        case routerPushedMediaPicker(source: MediaPickerSource)
        case routerPushedTimeline
        case routerPushedExport
        case routerPushedFilmDetail(filmID: UUID)
        case routerPopped
        case routerPoppedToRoot
        case routerPushedSettings
        case routerPushedLabelPosition(kind: LabelKind)
    }

    @Reducer
    public enum Path {
        case mediaPicker(MediaPickerFeature)
        case timeline(TimelineFeature)
        case export(ExportFeature)
        case filmDetail(FilmDetailFeature)
        case settings(SettingsFeature)
        case labelPosition(LabelPositionFeature)
    }

    @Dependency(\.analyticsTracker) var analyticsTracker

    public var body: some ReducerOf<Self> {
        Scope(state: \.home, action: \.home) {
            HomeFeature()
        }

        Reduce { state, action in
            switch action {
            case let .routerPushedMediaPicker(source):
                state.path.append(.mediaPicker(MediaPickerFeature.State(source: source)))
                let tag: MediaPickerSourceTag = switch source {
                case .photoLibrary: .photoLibrary
                case .devFixtures:  .devFixtures
                }
                analyticsTracker.log(.mediaPickerOpened(source: tag))
                return .none

            case .routerPushedTimeline:
                state.path.append(.timeline(TimelineFeature.State()))
                analyticsTracker.log(.timelineOpened)
                return .none

            case .routerPushedExport:
                state.path.append(.export(ExportFeature.State()))
                analyticsTracker.log(.exportScreenOpened)
                return .none

            case let .routerPushedFilmDetail(filmID):
                state.path.append(.filmDetail(FilmDetailFeature.State(filmID: filmID)))
                analyticsTracker.log(.filmDetailOpened(filmID: filmID))
                return .none

            case .routerPopped:
                _ = state.path.popLast()
                return .none

            case .routerPoppedToRoot:
                state.path.removeAll()
                return .none

            case .routerPushedSettings:
                state.path.append(.settings(SettingsFeature.State()))
                return .none

            case let .routerPushedLabelPosition(kind):
                state.path.append(.labelPosition(LabelPositionFeature.State(kind: kind)))
                return .none

            case .home, .path:
                return .none
            }
        }
        .forEach(\.path, action: \.path)
    }
}
