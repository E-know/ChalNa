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
    @Test func positionRowTapsAreNoOp() async {
        let store = TestStore(initialState: LabelSettingsFeature.State()) { LabelSettingsFeature() }
        store.exhaustivity = .off
        await store.send(.timePositionRowTapped)
        await store.send(.datePositionRowTapped)
    }
}
