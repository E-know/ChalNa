import ComposableArchitecture
import Models
import AnalyticsService

@Reducer
public struct LabelSettingsFeature {
    public init() {}

    @ObservableState
    public struct State: Equatable {
        @Shared(.appStorage("labelTimeEnabled")) public var timeEnabled = true
        @Shared(.appStorage("labelTimePosition")) public var timePosition = LabelPosition.center
        @Shared(.appStorage("labelTimeOpacity")) public var timeOpacity = 0.5
        @Shared(.appStorage("labelDateEnabled")) public var dateEnabled = true
        @Shared(.appStorage("labelDatePosition")) public var datePosition = LabelPosition.bottomCenter
        @Shared(.appStorage("labelDateOpacity")) public var dateOpacity = 1.0
        public init() {}
    }

    public enum Action {
        case backTapped
        case timeToggled(Bool)
        case dateToggled(Bool)
        case timePositionRowTapped
        case datePositionRowTapped
        case timeOpacityChanged(Double)
        case dateOpacityChanged(Double)
        case delegate(Delegate)

        /// 부모(AppFeature)가 화면 전환으로 해석하는 네비게이션 인텐트.
        public enum Delegate: Equatable {
            case positionRequested(LabelKind)
        }
    }

    @Dependency(\.analyticsTracker) var analyticsTracker
    @Dependency(\.dismiss) var dismiss

    public var body: some ReducerOf<Self> {
        Reduce { state, action in
            switch action {
            case .backTapped:
                return .run { _ in await dismiss() }
            case let .timeToggled(on):
                state.$timeEnabled.withLock { $0 = on }
                analyticsTracker.log(.labelToggled(kind: LabelKind.time.rawValue, on: on))
                return .none
            case let .dateToggled(on):
                state.$dateEnabled.withLock { $0 = on }
                analyticsTracker.log(.labelToggled(kind: LabelKind.date.rawValue, on: on))
                return .none
            case .timePositionRowTapped:
                return .send(.delegate(.positionRequested(.time)))
            case .datePositionRowTapped:
                return .send(.delegate(.positionRequested(.date)))
            case let .timeOpacityChanged(value):
                state.$timeOpacity.withLock { $0 = value }
                return .none
            case let .dateOpacityChanged(value):
                state.$dateOpacity.withLock { $0 = value }
                return .none
            case .delegate:
                return .none
            }
        }
    }
}
