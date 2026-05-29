import Testing
import ComposableArchitecture
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
}
