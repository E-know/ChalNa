import ComposableArchitecture
import Models
import AnalyticsService

@Reducer
public struct LabelPositionSettingsFeature {
    public init() {}

    @ObservableState
    public struct State: Equatable {
        public let kind: LabelKind
        @Shared(.appStorage("labelTimePosition")) public var timePosition = LabelPosition.center
        @Shared(.appStorage("labelDatePosition")) public var datePosition = LabelPosition.bottomCenter

        public init(kind: LabelKind) { self.kind = kind }

        /// 현재 kind 에 해당하는 선택값.
        public var selected: LabelPosition {
            kind == .time ? timePosition : datePosition
        }
    }

    public enum Action {
        case onAppear
        case backTapped
        case positionSelected(LabelPosition)
    }

    @Dependency(\.analyticsTracker) var analyticsTracker
    @Dependency(\.dismiss) var dismiss

    public var body: some ReducerOf<Self> {
        Reduce { state, action in
            switch action {
                case .onAppear:
                    return .none

                case .backTapped:
                    return .run { _ in await dismiss() }

                case let .positionSelected(position):
                    switch state.kind {
                        case .time: state.$timePosition.withLock { $0 = position }
                        case .date: state.$datePosition.withLock { $0 = position }
                    }
                    analyticsTracker.log(.labelPositionChanged(kind: state.kind.rawValue, position: position.rawValue))
                    return .none
            }
        }
    }
}
