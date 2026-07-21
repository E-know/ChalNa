import ComposableArchitecture
import Foundation
import AnalyticsService

/// 라이브러리 1개 필름의 상세 정보 화면 Reducer.
/// 실제 `Film` 데이터는 View 단의 `@Query`/`fetch` 로 얻고,
/// 이 Reducer 는 모달/시트/알럿 토글과 분석 로깅만 책임진다.
@Reducer
public struct FilmDetailFeature {
    public init() {}

    @ObservableState
    public struct State: Equatable {
        public let filmID: UUID
        public var isPlayerPresented: Bool = false
        public var isShareSheetPresented: Bool = false
        public var isDeleteAlertPresented: Bool = false

        public init(filmID: UUID) {
            self.filmID = filmID
        }
    }

    public enum Action: Equatable {
        case onAppear
        case missingFileNoticed

        case backTapped

        case playTapped
        case playerPresentedChanged(Bool)

        case shareTapped
        case shareSheetPresentedChanged(Bool)

        case deleteTapped
        case deleteAlertPresentedChanged(Bool)
        // 사용자가 알럿에서 "삭제" 를 눌렀을 때.
        // 실제 SwiftData / 디스크 정리는 View 가 modelContext 로 직접 수행한다.
        case deleteConfirmed
    }

    @Dependency(\.analyticsTracker) var analyticsTracker
    @Dependency(\.dismiss) var dismiss

    public var body: some ReducerOf<Self> {
        Reduce { state, action in
            switch action {
            case .onAppear:
                return .none

            case .missingFileNoticed:
                return .none

            case .backTapped:
                return .run { _ in await dismiss() }

            case .playTapped:
                state.isPlayerPresented = true
                return .none

            case let .playerPresentedChanged(value):
                state.isPlayerPresented = value
                return .none

            case .shareTapped:
                state.isShareSheetPresented = true
                return .none

            case let .shareSheetPresentedChanged(value):
                state.isShareSheetPresented = value
                return .none

            case .deleteTapped:
                state.isDeleteAlertPresented = true
                return .none

            case let .deleteAlertPresentedChanged(value):
                state.isDeleteAlertPresented = value
                return .none

            case .deleteConfirmed:
                state.isDeleteAlertPresented = false
                analyticsTracker.log(.filmDeleted(filmID: state.filmID))
                return .run { _ in await dismiss() }
            }
        }
    }
}
