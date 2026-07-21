import ComposableArchitecture
import AnalyticsService

/// 설정 최상위 메뉴. 현재는 '라벨' 항목 1개. 향후 다른 메뉴를 여기에 추가.
@Reducer
public struct SettingsFeature {
    public init() {}

    @ObservableState
    public struct State: Equatable {
        public init() {}
    }

    public enum Action: Equatable {
        case onAppear
        case backTapped
        case labelMenuTapped
        case languageMenuTapped
        case supportMenuTapped
        case delegate(Delegate)

        /// 부모(AppFeature)가 화면 전환으로 해석하는 네비게이션 인텐트.
        public enum Delegate: Equatable {
            case labelSettingsRequested
            case languageRequested
            case supportRequested
        }
    }

    @Dependency(\.analyticsTracker) var analyticsTracker
    @Dependency(\.dismiss) var dismiss

    public var body: some ReducerOf<Self> {
        Reduce { _, action in
            switch action {
            case .onAppear:
                analyticsTracker.log(.settingsOpened)
                return .none
            case .backTapped:
                return .run { _ in await dismiss() }
            case .labelMenuTapped:
                return .send(.delegate(.labelSettingsRequested))
            case .languageMenuTapped:
                return .send(.delegate(.languageRequested))
            case .supportMenuTapped:
                return .send(.delegate(.supportRequested))
            case .delegate:
                return .none
            }
        }
    }
}
