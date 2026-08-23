import Testing
import ComposableArchitecture
@testable import SettingsFeature

@MainActor
struct SettingsFeatureTests {
    @Test func onAppearIsNoOp() async {
        let store = TestStore(initialState: SettingsFeature.State()) { SettingsFeature() }
        await store.send(.onAppear)   // analytics(Noop) 로깅, 상태 불변
    }

    @Test func languageMenuTapEmitsDelegate() async {
        let store = TestStore(initialState: SettingsFeature.State()) { SettingsFeature() }
        await store.send(.languageMenuTapped)
        await store.receive(.delegate(.languageRequested))
    }

    @Test func supportMenuTapEmitsDelegate() async {
        let store = TestStore(initialState: SettingsFeature.State()) { SettingsFeature() }
        await store.send(.supportMenuTapped)
        await store.receive(.delegate(.supportRequested))
    }
}
