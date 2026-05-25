import ComposableArchitecture
import Foundation
import AppCore
import HomeFeature
import MediaPickerFeature
import TimelineFeature
import ExportFeature

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
        case routerPopped
        case routerPoppedToRoot
    }

    @Reducer
    public enum Path {
        case mediaPicker(MediaPickerFeature)
        case timeline(TimelineFeature)
        case export(ExportFeature)
    }

    public var body: some ReducerOf<Self> {
        Scope(state: \.home, action: \.home) {
            HomeFeature()
        }

        Reduce { state, action in
            switch action {
            case let .routerPushedMediaPicker(source):
                state.path.append(.mediaPicker(MediaPickerFeature.State(source: source)))
                return .none

            case .routerPushedTimeline:
                state.path.append(.timeline(TimelineFeature.State()))
                return .none

            case .routerPushedExport:
                state.path.append(.export(ExportFeature.State()))
                return .none

            case .routerPopped:
                _ = state.path.popLast()
                return .none

            case .routerPoppedToRoot:
                state.path.removeAll()
                return .none

            case .home, .path:
                return .none
            }
        }
        .forEach(\.path, action: \.path)
    }
}
