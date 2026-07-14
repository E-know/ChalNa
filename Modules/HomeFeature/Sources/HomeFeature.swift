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
        case filmTapped(filmID: UUID)
        case delegate(Delegate)

        /// 부모(AppFeature)가 화면 전환으로 해석하는 네비게이션 인텐트.
        public enum Delegate: Equatable {
            case newVlogRequested
            case settingsRequested
            case filmDetailRequested(filmID: UUID)
        }
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
                return .send(.delegate(.newVlogRequested))

            case .settingsButtonTapped:
                return .send(.delegate(.settingsRequested))

            case let .filmTapped(filmID):
                return .send(.delegate(.filmDetailRequested(filmID: filmID)))

            case .delegate:
                return .none
            }
        }
    }
}
