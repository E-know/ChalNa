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

/// 앱 루트 Reducer. Home 의 편집 흐름은 StackState, 설정은 독립된 화면으로 관리한다.
/// 화면 전환은 각 자식 Feature 의 `delegate` 액션을 여기서 해석한다.
/// 시스템 뒤로 가기는 NavigationStack의 path 바인딩, 작업 완료에 따른 pop은 자식 리듀서가 처리한다.
@Reducer
public struct AppFeature {
    public init() {}

    @ObservableState
    public struct State {
        public var home = HomeFeature.State()
        public var path = StackState<Path.State>()
        @Presents public var settings: SettingsFeature.State?

        public init() {}
    }

    public enum Action {
        case home(HomeFeature.Action)
        case path(StackActionOf<Path>)
        case settings(PresentationAction<SettingsFeature.Action>)
    }

    @Reducer
    public enum Path {
        case mediaPicker(MediaPickerFeature)
        case timeline(TimelineFeature)
        case export(ExportFeature)
        case filmDetail(FilmDetailFeature)
        case clipAdjust(ClipAdjustFeature)
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
                    state.settings = SettingsFeature.State()
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
                    state.path.append(.timeline(TimelineFeature.State(title: editSession.title, clips: editSession.clips)))
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

            case .home, .path, .settings:
                return .none
            }
        }
        .forEach(\.path, action: \.path)
        .ifLet(\.$settings, action: \.settings) { SettingsFeature() }
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
