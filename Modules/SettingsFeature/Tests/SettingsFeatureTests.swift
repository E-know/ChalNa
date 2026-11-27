import Testing
import ComposableArchitecture
import AppCore
import Models
@testable import SettingsFeature

@MainActor
struct SettingsFeatureTests {
    @Test func onAppearLoadsTheSavedResolution() async {
        let store = TestStore(initialState: SettingsFeature.State()) { SettingsFeature() } withDependencies: {
            $0.filmOutputResolution.get = { .hd }
        }

        await store.send(.onAppear) {
            $0.outputResolution = .hd
        }
    }

    @Test func selectingResolutionSavesItAndKeepsTheCurrentDetail() async {
        let selections = LockIsolated<[FilmOutputResolution]>([])
        var initial = SettingsFeature.State()
        initial.selectedSection = .support
        let store = TestStore(initialState: initial) { SettingsFeature() } withDependencies: {
            $0.filmOutputResolution.set = { resolution in
                selections.withValue { $0.append(resolution) }
            }
        }

        await store.send(.outputResolutionSelected(.fourK)) {
            $0.outputResolution = .fourK
        }
        #expect(selections.value == [.fourK])
    }

    @Test func storageModeDefaultsToPhotosOnly() async {
        let store = TestStore(initialState: SettingsFeature.State()) { SettingsFeature() } withDependencies: {
            $0.filmOutputResolution.get = { .fullHD }
        }
        await store.send(.onAppear)
        #expect(store.state.filmStorageMode == .photosOnly)
    }

    @Test func changingStorageModePersistsAndLoadsTheSelection() async {
        let saved = LockIsolated(FilmStorageMode.photosOnly)
        let preference = FilmStoragePreference(
            load: { saved.value },
            save: { mode in saved.setValue(mode) }
        )
        let store = TestStore(initialState: SettingsFeature.State()) { SettingsFeature() } withDependencies: {
            $0.filmStoragePreference = preference
        }

        await store.send(.filmStorageModeSelected(.appAndPhotos)) {
            $0.filmStorageMode = .appAndPhotos
        }
        #expect(saved.value == .appAndPhotos)

        let reopened = TestStore(initialState: SettingsFeature.State()) { SettingsFeature() } withDependencies: {
            $0.filmStoragePreference = preference
            $0.filmOutputResolution.get = { .fullHD }
        }
        await reopened.send(.onAppear) {
            $0.filmStorageMode = .appAndPhotos
        }
        await reopened.send(.filmStorageModeSelected(.photosOnly)) {
            $0.filmStorageMode = .photosOnly
        }
        #expect(saved.value == .photosOnly)
    }

    @Test func switchingSectionsKeepsTheSupportDraft() async {
        let store = TestStore(initialState: SettingsFeature.State()) { SettingsFeature() }
        await store.send(.sectionSelected(.support)) {
            $0.selectedSection = .support
        }
        await store.send(.support(.textChanged("제안 초안"))) {
            $0.support.text = "제안 초안"
        }
        await store.send(.sectionSelected(.language)) {
            $0.selectedSection = .language
        }
        await store.send(.sectionSelected(.support)) {
            $0.selectedSection = .support
        }
        #expect(store.state.support.text == "제안 초안")
    }

    @Test func acknowledgingSentFeedbackClearsOnlyTheDetail() async {
        var initial = SettingsFeature.State()
        initial.selectedSection = .support
        initial.support.alert = SupportFeature.AlertInfo(message: "전송했어요", isSuccess: true)
        let store = TestStore(initialState: initial) { SettingsFeature() }

        await store.send(.support(.alertDismissed)) {
            $0.support.alert = nil
        }
        await store.receive(\.support.delegate.finished) {
            $0.selectedSection = nil
        }
    }
}
