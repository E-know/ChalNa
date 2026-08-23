import ComposableArchitecture
import Foundation
import AppCore
import AnalyticsService
import HomeFeature
import MediaPickerFeature
import TimelineFeature
import ExportFeature
import FilmDetailFeature
import PhotosService
import SettingsFeature

/// 앱 루트 Reducer. Home 을 root 로 두고 나머지 화면을 StackState 로 push.
/// 화면 전환은 각 자식 Feature 의 `delegate` 액션을 여기서 path 조작으로 해석한다.
/// pop 은 자식 리듀서의 `@Dependency(\.dismiss)` 가 처리하므로 여기엔 없다.
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
    }

    @Reducer
    public enum Path {
        case mediaPicker(MediaPickerFeature)
        case timeline(TimelineFeature)
        case export(ExportFeature)
        case filmDetail(FilmDetailFeature)
        case settings(SettingsFeature)
        case support(SupportFeature)
        case clipAdjust(ClipAdjustFeature)
        case language(LanguageFeature)
    }

    @Dependency(\.analyticsTracker) var analyticsTracker
    @Dependency(\.editSession) var editSession

    public var body: some ReducerOf<Self> {
        Scope(state: \.home, action: \.home) {
            HomeFeature()
        }

        Reduce { state, action in
            switch action {
            // MARK: Home delegate

            case let .home(.delegate(delegateAction)):
                switch delegateAction {
                case .newVlogRequested:
                    pushMediaPicker(state: &state)
                case .settingsRequested:
                    state.path.append(.settings(SettingsFeature.State()))
                case let .filmDetailRequested(filmID):
                    state.path.append(.filmDetail(FilmDetailFeature.State(filmID: filmID)))
                    analyticsTracker.log(.filmDetailOpened(filmID: filmID))
                }
                return .none

            // MARK: MediaPicker delegate

            case let .path(.element(id: _, action: .mediaPicker(.delegate(delegateAction)))):
                switch delegateAction {
                case let .selectionConfirmed(clips, title):
                    // push 전에 세션을 채워야 Timeline 이 onAppear 에서 동기화할 수 있다.
                    editSession.replace(clips: clips, title: title)
                    state.path.append(.timeline(TimelineFeature.State()))
                    analyticsTracker.log(.timelineOpened)
                }
                return .none

            // MARK: Timeline delegate

            case let .path(.element(id: _, action: .timeline(.delegate(delegateAction)))):
                switch delegateAction {
                case .exportRequested:
                    state.path.append(.export(ExportFeature.State()))
                    analyticsTracker.log(.exportScreenOpened)
                case let .clipAdjustRequested(clipID):
                    state.path.append(.clipAdjust(ClipAdjustFeature.State(clipID: clipID)))
                }
                return .none

            // MARK: Export delegate

            case let .path(.element(id: _, action: .export(.delegate(delegateAction)))):
                switch delegateAction {
                case .homeRequested:
                    state.path.removeAll()
                case .newFilmRequested:
                    editSession.clear()
                    state.path.removeAll()
                    pushMediaPicker(state: &state)
                }
                return .none

            // MARK: Settings delegate

            case let .path(.element(id: _, action: .settings(.delegate(delegateAction)))):
                switch delegateAction {
                case .languageRequested:
                    state.path.append(.language(LanguageFeature.State()))
                case .supportRequested:
                    state.path.append(.support(SupportFeature.State()))
                }
                return .none

            case .home, .path:
                return .none
            }
        }
        .forEach(\.path, action: \.path)
    }

    // MARK: - Helpers

    private func pushMediaPicker(state: inout State) {
        let source = mediaPickerSource
        state.path.append(.mediaPicker(MediaPickerFeature.State(source: source)))
        let tag: MediaPickerSourceTag = switch source {
        case .photoLibrary: .photoLibrary
        case .devFixtures:  .devFixtures
        }
        analyticsTracker.log(.mediaPickerOpened(source: tag))
    }

    private var mediaPickerSource: MediaPickerSource {
        switch AppMode.current {
        case .real:    .photoLibrary
        case .devMock: .devFixtures(BundledDevMediaSource())
        }
    }
}
