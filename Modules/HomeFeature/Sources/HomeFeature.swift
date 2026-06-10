import ComposableArchitecture
import Foundation
import AnalyticsService

/// 홈 화면의 Reducer. 가장 단순한 Feature 라 TCA 패턴 검증 용도로 먼저 마이그레이션.
/// Note: SwiftData `@Query films` 는 TCA State 에 두지 않고 View 에 그대로 둔다
/// (TCA + SwiftData 공식 권장 패턴).
@Reducer
public struct HomeFeature {
    public init() {}

    @ObservableState
    public struct State: Equatable {
        public init() {}
    }

    public enum Action {
        case onAppear
        case newVlogButtonTapped
        case settingsButtonTapped
    }

    @Dependency(\.analyticsTracker) var analyticsTracker

    public var body: some ReducerOf<Self> {
        Reduce { state, action in
            switch action {
            case .onAppear:
                analyticsTracker.log(.homeViewed)
                return .none

            case .newVlogButtonTapped:
                analyticsTracker.log(.newVlogTapped)
                // 부모(현재는 RootView, 추후 AppFeature) 가 navigation 처리.
                return .none

            case .settingsButtonTapped:
                // 향후 설정 화면 진입.
                return .none
            }
        }
    }
}
