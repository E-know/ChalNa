import ComposableArchitecture
import AnalyticsService
import AppCore

/// 문의·신고 화면. 자유 텍스트 + 분류를 텔레그램 봇으로 전송.
@Reducer
public struct SupportFeature {
    public init() {}

    @ObservableState
    public struct State: Equatable {
        public var text = ""
        public var category: FeedbackCategory = .bug
        public var isSending = false
        /// nil 이면 알림 숨김. 성공 시 확인을 누르면 화면을 pop 한다(isSuccess 로 구분).
        public var alert: AlertInfo?
        public var otherCategoryTapCount = 0
        public var isRedeemPresented = false
        public var redeemCode = ""
        public var redeemError: String?
        public init() {}
    }

    /// 전송 결과 알림. isSuccess 면 확인 시 pop, 실패면 머무른다(재시도 가능).
    public struct AlertInfo: Equatable {
        public let message: String
        public let isSuccess: Bool
    }

    public enum Action {
        case textChanged(String)
        case categorySelected(FeedbackCategory)
        case sendTapped
        case sendSucceeded
        case sendFailed(reason: String)
        case alertDismissed
        case redeemPresentedChanged(Bool)
        case redeemCodeChanged(String)
        case redeemSubmitted
    }

    @Dependency(\.feedbackClient) var feedbackClient
    @Dependency(\.analyticsTracker) var analyticsTracker
    @Dependency(\.exportQuotaClient) var exportQuotaClient

    public var body: some ReducerOf<Self> {
        Reduce { state, action in
            switch action {
            case let .textChanged(value):
                state.text = value
                return .none

            case let .categorySelected(category):
                state.category = category
                if category == .other {
                    state.otherCategoryTapCount += 1
                    if state.otherCategoryTapCount >= 5 {
                        state.otherCategoryTapCount = 0
                        state.redeemCode = ""
                        state.redeemError = nil
                        state.isRedeemPresented = true
                    }
                } else {
                    state.otherCategoryTapCount = 0
                }
                return .none

            case .sendTapped:
                let trimmed = state.text.trimmingCharacters(in: .whitespacesAndNewlines)
                guard !trimmed.isEmpty, !state.isSending else { return .none }
                state.isSending = true
                let category = state.category
                return .run { send in
                    let report = FeedbackReport.current(text: trimmed, category: category)
                    do {
                        try await feedbackClient.send(report)
                        await send(.sendSucceeded)
                    } catch {
                        await send(.sendFailed(reason: error.localizedDescription))
                    }
                }

            case .sendSucceeded:
                analyticsTracker.log(.feedbackSubmitted(category: state.category.rawValue))
                state.isSending = false
                state.text = ""
                state.alert = AlertInfo(message: String(localized: "소중한 의견 감사합니다. 잘 전달했어요."), isSuccess: true)
                return .none

            case let .sendFailed(reason):
                analyticsTracker.log(.feedbackSendFailed(reason: reason))
                state.isSending = false
                state.alert = AlertInfo(message: reason, isSuccess: false)
                return .none

            case .alertDismissed:
                state.alert = nil
                return .none

            case let .redeemPresentedChanged(isPresented):
                state.isRedeemPresented = isPresented
                if !isPresented {
                    state.redeemCode = ""
                    state.redeemError = nil
                }
                return .none

            case let .redeemCodeChanged(code):
                state.redeemCode = code
                state.redeemError = nil
                return .none

            case .redeemSubmitted:
                let code = state.redeemCode.trimmingCharacters(in: .whitespacesAndNewlines)
                guard !code.isEmpty else {
                    state.redeemError = String(localized: "리딤 코드를 입력해 주세요.")
                    return .none
                }
                guard exportQuotaClient.redeem(code) else {
                    state.redeemError = String(localized: "리딤 코드가 맞지 않아요.")
                    return .none
                }
                state.isRedeemPresented = false
                state.redeemCode = ""
                state.redeemError = nil
                state.alert = AlertInfo(message: String(localized: "2026년까지 영상 생성 제한이 해제됐어요."), isSuccess: false)
                return .none
            }
        }
    }
}
