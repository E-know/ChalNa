import ComposableArchitecture
import AppCore
import Foundation
import Models

/// 클립의 확정된 구도는 편집 세션에 저장한다. 제스처 진행 중의 값은 화면이 관리한다.
@Reducer
public struct ClipAdjustFeature {
    public init() {}

    @ObservableState
    public struct State: Equatable {
        public let clipID: Clip.ID
        public init(clipID: Clip.ID) { self.clipID = clipID }
    }

    public enum Action: Equatable {
        case doneTapped
        case rotateTapped
        case resetTapped
        case framingChanged(ClipTransform)
    }

    @Dependency(\.dismiss) var dismiss
    @Dependency(\.editSession) var session

    public var body: some ReducerOf<Self> {
        Reduce { state, action in
            switch action {
            case .doneTapped:
                return .run { _ in await dismiss() }
            case .rotateTapped:
                session.cycleRotation(for: state.clipID)
                return .none
            case .resetTapped:
                session.resetTransform(for: state.clipID)
                return .none
            case .framingChanged(let framing):
                session.setTransform(framing.sanitized, for: state.clipID)
                return .none
            }
        }
    }
}
