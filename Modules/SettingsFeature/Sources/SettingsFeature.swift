import ComposableArchitecture
import AnalyticsService

/// 설정 최상위 메뉴. 현재는 '언어'·'문의·신고' 2개. 향후 다른 메뉴를 여기에 추가.
/// (영상 라벨은 설정 대상이 아니다 — 우측 하단·75% 로 고정, `LabelLayout` 참고.)
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
        case languageMenuTapped
        case supportMenuTapped
        case delegate(Delegate)

        /// 부모(AppFeature)가 화면 전환으로 해석하는 네비게이션 인텐트.
        public enum Delegate: Equatable {
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
