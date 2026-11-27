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
        @Presents public var quotaAlert: AlertState<Never>?

        public init() {}
    }

    public enum Action {
        case home(HomeFeature.Action)
        case path(StackActionOf<Path>)
        case settings(PresentationAction<SettingsFeature.Action>)
        case quotaAlert(PresentationAction<Never>)
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
    @Dependency(\.exportQuotaClient) var exportQuotaClient
    @Dependency(\.filmOutputResolution) var filmOutputResolution

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
                    guard canStartFilm(state: &state) else { return .none }
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
                    state.path.append(.export(ExportFeature.State(resolution: filmOutputResolution.get())))
                    analyticsTracker.log(.exportScreenOpened)
                case let .clipAdjustRequested(clipID):
                    state.path.append(.clipAdjust(ClipAdjustFeature.State(clipID: clipID)))
                }
                return .none

            // MARK: Export delegate

            case let .path(.element(id: id, action: .export(.delegate(delegateAction)))):
                let temporaryMovie: URL? = if case let .export(export)? = state.path[id: id] {
                    export.exportedURL
                } else { nil }
                switch delegateAction {
                case .homeRequested:
                    state.path.removeAll()
                case .newFilmRequested:
                    guard canStartFilm(state: &state) else { return .none }
                    editSession.clear()
                    state.path.removeAll()
                    pushMediaPicker(state: &state)
                }
                guard let temporaryMovie else { return .none }
                return .run { _ in try? FileManager.default.removeItem(at: temporaryMovie) }

            case .home, .path, .settings, .quotaAlert:
                return .none
            }
        }
        .forEach(\.path, action: \.path)
        .ifLet(\.$settings, action: \.settings) { SettingsFeature() }
        .ifLet(\.$quotaAlert, action: \.quotaAlert)
    }

    // MARK: - Helpers

    private func canStartFilm(state: inout State) -> Bool {
        guard case let .blocked(reason) = exportQuotaClient.checkExport() else { return true }
        analyticsTracker.log(.exportQuotaBlocked(reason: reason.rawValue, stage: "film_entry"))
        state.quotaAlert = AlertState {
            TextState("필름 생성 한도에 도달했어요")
        } actions: {
            ButtonState(role: .cancel) { TextState("확인") }
        } message: {
            TextState(verbatim: reason.message)
        }
        return false
    }

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
