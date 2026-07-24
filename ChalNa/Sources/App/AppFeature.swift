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
import OnboardingFeature
import SubscriptionService

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
        /// 하드 페이월 게이트. 구독(체험 포함) 비활성 시 온보딩/페이월 오버레이 표시.
        @Presents public var onboarding: OnboardingFeature.State?
        @Shared(.appStorage("hasSeenOnboarding")) public var hasSeenOnboarding = false

        public init() {}
    }

    public enum Action {
        case home(HomeFeature.Action)
        case path(StackActionOf<Path>)
        case task
        case gateResolved(subscribed: Bool)
        case onboarding(PresentationAction<OnboardingFeature.Action>)
    }

    @Reducer
    public enum Path {
        case mediaPicker(MediaPickerFeature)
        case timeline(TimelineFeature)
        case export(ExportFeature)
        case filmDetail(FilmDetailFeature)
        case settings(SettingsFeature)
        case labelSettings(LabelSettingsFeature)
        case labelPosition(LabelPositionSettingsFeature)
        case support(SupportFeature)
        case clipAdjust(ClipAdjustFeature)
        case language(LanguageFeature)
    }

    @Dependency(\.analyticsTracker) var analyticsTracker
    @Dependency(\.editSession) var editSession
    @Dependency(\.subscriptionClient) var subscriptionClient

    private enum CancelID { case transactionObserver, gate }

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
                case .labelSettingsRequested:
                    state.path.append(.labelSettings(LabelSettingsFeature.State()))
                case .languageRequested:
                    state.path.append(.language(LanguageFeature.State()))
                case .supportRequested:
                    state.path.append(.support(SupportFeature.State()))
                }
                return .none

            case let .path(.element(id: _, action: .labelSettings(.delegate(delegateAction)))):
                switch delegateAction {
                case let .positionRequested(kind):
                    state.path.append(.labelPosition(LabelPositionSettingsFeature.State(kind: kind)))
                }
                return .none

            // MARK: Onboarding gate

            case .task:
                // devMock 은 게이트 스킵 (UITests·fixture 플로우 보호). 강제 표시는 env 로.
                let forced = ProcessInfo.processInfo.environment["CHALNA_FORCE_ONBOARDING"] == "1"
                let shouldGate = AppMode.current == .real || forced
                return .merge(
                    // 갱신/환불 트랜잭션 finish (앱 수명 동안 유지되는 옵저버).
                    .run { _ in await subscriptionClient.observeTransactionUpdates() }
                        .cancellable(id: CancelID.transactionObserver, cancelInFlight: true),
                    shouldGate
                        ? .run { send in
                            let subscribed = await subscriptionClient.isSubscribed()
                            await send(.gateResolved(subscribed: subscribed))
                        }
                        .cancellable(id: CancelID.gate, cancelInFlight: true)
                        : .none
                )

            case let .gateResolved(subscribed):
                guard !subscribed, state.onboarding == nil else { return .none }
                state.onboarding = OnboardingFeature.State(
                    mode: state.hasSeenOnboarding ? .paywallOnly : .full
                )
                return .none

            case .onboarding(.presented(.delegate(.completed))):
                state.onboarding = nil
                return .none

            case .onboarding:
                return .none

            case .home, .path:
                return .none
            }
        }
        .forEach(\.path, action: \.path)
        .ifLet(\.$onboarding, action: \.onboarding) {
            OnboardingFeature()
        }
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
