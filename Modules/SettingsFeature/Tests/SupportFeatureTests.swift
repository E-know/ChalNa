import Testing
import ComposableArchitecture
import AppCore
@testable import SettingsFeature

@MainActor
struct SupportFeatureTests {
    @Test func emptyTextSendIsNoOp() async {
        let store = TestStore(initialState: SupportFeature.State()) { SupportFeature() }
        store.exhaustivity = .off
        await store.send(.sendTapped)
        #expect(store.state.isSending == false)
        #expect(store.state.alert == nil)
    }

    @Test func successFlowClearsTextAndShowsAlert() async {
        var initial = SupportFeature.State()
        initial.text = "버그를 발견했어요"
        let store = TestStore(initialState: initial) {
            SupportFeature()
        } withDependencies: {
            $0.feedbackClient.send = { _ in }   // 성공
        }
        store.exhaustivity = .off
        await store.send(.sendTapped)
        await store.receive(\.sendSucceeded)
        #expect(store.state.isSending == false)
        #expect(store.state.text == "")
        #expect(store.state.alert?.isSuccess == true)
    }

    @Test func failureFlowShowsErrorMessage() async {
        struct Boom: Error {}
        var initial = SupportFeature.State()
        initial.text = "전송 실패 케이스"
        let store = TestStore(initialState: initial) {
            SupportFeature()
        } withDependencies: {
            $0.feedbackClient.send = { _ in throw Boom() }
        }
        store.exhaustivity = .off
        await store.send(.sendTapped)
        await store.receive(\.sendFailed)
        #expect(store.state.isSending == false)
        #expect(store.state.alert?.isSuccess == false)
    }

    @Test func fiveConsecutiveOtherSelectionsShowRedeemSheet() async {
        let store = TestStore(initialState: SupportFeature.State()) { SupportFeature() }
        store.exhaustivity = .off

        await store.send(.categorySelected(.other))
        await store.send(.categorySelected(.other))
        await store.send(.categorySelected(.other))
        await store.send(.categorySelected(.other))
        await store.send(.categorySelected(.other))

        #expect(store.state.isRedeemPresented)
    }

    @Test func nonOtherSelectionResetsHiddenRedeemCounter() async {
        let store = TestStore(initialState: SupportFeature.State()) { SupportFeature() }
        store.exhaustivity = .off

        await store.send(.categorySelected(.other))
        await store.send(.categorySelected(.other))
        await store.send(.categorySelected(.bug))
        await store.send(.categorySelected(.other))
        await store.send(.categorySelected(.other))
        await store.send(.categorySelected(.other))

        #expect(!store.state.isRedeemPresented)
    }

    @Test func correctRedeemCodeUnlocksQuota() async {
        let redeemedCodes = LockIsolated<[String]>([])
        var initial = SupportFeature.State()
        initial.isRedeemPresented = true
        initial.redeemCode = "tobyisinho"
        let store = TestStore(initialState: initial) {
            SupportFeature()
        } withDependencies: {
            $0.exportQuotaClient.redeem = { code in
                redeemedCodes.withValue { $0.append(code) }
                return true
            }
        }
        store.exhaustivity = .off

        await store.send(.redeemSubmitted)

        #expect(redeemedCodes.value == ["tobyisinho"])
        #expect(!store.state.isRedeemPresented)
        #expect(store.state.alert?.message == "2026년까지 영상 생성 제한이 해제됐어요.")
    }
}
