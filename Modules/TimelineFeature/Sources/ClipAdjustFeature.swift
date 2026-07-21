import ComposableArchitecture
import Foundation
import Models

/// 클립 1개의 프레이밍(줌/이동/회전)을 편집하는 풀스크린 화면 Reducer.
/// 실제 편집 상태는 `EditSession`(환경)에 직접 쓴다 — 회전/라벨과 동일한 패턴.
/// 이 Reducer 는 라우트 식별(`clipID`)을 들고, pop 은 dismiss 의존성으로 처리.
@Reducer
public struct ClipAdjustFeature {
    public init() {}

    @ObservableState
    public struct State: Equatable {
        public let clipID: Clip.ID
        public init(clipID: Clip.ID) { self.clipID = clipID }
    }

    public enum Action: Equatable {
        case backTapped
        case doneTapped
    }

    @Dependency(\.dismiss) var dismiss

    public var body: some ReducerOf<Self> {
        Reduce { _, action in
            switch action {
            case .backTapped, .doneTapped:
                return .run { _ in await dismiss() }
            }
        }
    }
}
