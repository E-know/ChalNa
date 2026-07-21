import Testing
import ComposableArchitecture
import Models
@testable import SettingsFeature

@MainActor
struct LabelSettingsFeatureTests {
    @Test func togglingTimeUpdatesShared() async {
        let store = TestStore(initialState: LabelSettingsFeature.State()) { LabelSettingsFeature() }
        store.exhaustivity = .off
        await store.send(.timeToggled(false))
        #expect(store.state.timeEnabled == false)
    }
    @Test func togglingDateUpdatesShared() async {
        let store = TestStore(initialState: LabelSettingsFeature.State()) { LabelSettingsFeature() }
        store.exhaustivity = .off
        await store.send(.dateToggled(false))
        #expect(store.state.dateEnabled == false)
    }
    @Test func timeOpacityUpdatesShared() async {
        let store = TestStore(initialState: LabelSettingsFeature.State()) { LabelSettingsFeature() }
        store.exhaustivity = .off
        await store.send(.timeOpacityChanged(0.3))
        #expect(store.state.timeOpacity == 0.3)
    }
    @Test func dateOpacityUpdatesShared() async {
        let store = TestStore(initialState: LabelSettingsFeature.State()) { LabelSettingsFeature() }
        store.exhaustivity = .off
        await store.send(.dateOpacityChanged(0.2))
        #expect(store.state.dateOpacity == 0.2)
    }
    @Test func positionRowTapsEmitDelegates() async {
        let store = TestStore(initialState: LabelSettingsFeature.State()) { LabelSettingsFeature() }
        store.exhaustivity = .off
        await store.send(.timePositionRowTapped)
        await store.receive(\.delegate)   // .positionRequested(.time) — 화면 전환은 부모가 해석
        await store.send(.datePositionRowTapped)
        await store.receive(\.delegate)   // .positionRequested(.date)
    }
}
