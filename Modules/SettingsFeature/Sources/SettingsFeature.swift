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

    public enum Action {
        case onAppear
        case labelMenuTapped     // View 가 router.push(.labelSettings)
        case supportMenuTapped   // View 가 router.push(.support)
    }

    @Dependency(\.analyticsTracker) var analyticsTracker

    public var body: some ReducerOf<Self> {
        Reduce { _, action in
            switch action {
            case .onAppear:
                analyticsTracker.log(.settingsOpened)
                return .none
            case .labelMenuTapped:
                return .none
            case .supportMenuTapped:
                return .none
            }
        }
    }
}
