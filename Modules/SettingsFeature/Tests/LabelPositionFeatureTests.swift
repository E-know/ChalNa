import Testing
import ComposableArchitecture
import Models
@testable import SettingsFeature

@MainActor
struct LabelPositionFeatureTests {
    @Test func selectingPositionUpdatesTimeShared() async {
        let store = TestStore(initialState: LabelPositionFeature.State(kind: .time)) {
            LabelPositionFeature()
        }
        store.exhaustivity = .off
        await store.send(.positionSelected(.topRight))
        #expect(store.state.timePosition == .topRight)
        #expect(store.state.selected == .topRight)
    }

    @Test func selectingPositionUpdatesDateShared() async {
        let store = TestStore(initialState: LabelPositionFeature.State(kind: .date)) {
            LabelPositionFeature()
        }
        store.exhaustivity = .off
        await store.send(.positionSelected(.topLeft))
        #expect(store.state.datePosition == .topLeft)
        #expect(store.state.selected == .topLeft)
    }
}
