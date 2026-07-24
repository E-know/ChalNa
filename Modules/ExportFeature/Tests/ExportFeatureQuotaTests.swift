import Foundation
import Testing
import ComposableArchitecture
import Models
import PhotosService
import CompositionService
import AppCore
import SubscriptionService
@testable import ExportFeature

@MainActor
struct ExportFeatureQuotaTests {
    @Test func allowedExportReservesQuotaAndStartsExport() async {
        let didReserve = LockIsolated(false)
        let clip = exportableClip()
        let output = URL(fileURLWithPath: "/tmp/chalna-export.mp4")
        let store = TestStore(initialState: ExportFeature.State()) {
            ExportFeature()
        } withDependencies: {
            $0.subscriptionClient.isSubscribedCached = { false }
            $0.exportQuotaClient.reserveExport = {
                didReserve.setValue(true)
                return .allowed
            }
            $0.compositionClient.export = { _, _, _, _, _ in
                AsyncStream { continuation in
                    continuation.yield(.completed(output))
                    continuation.finish()
                }
            }
            $0.photoLibraryClient.saveVideoToPhotoLibrary = { _ in .ok }
        }
        store.exhaustivity = .off

        await store.send(.startExport(clips: [clip], rotations: [:], transforms: [:], clipLabels: [:]))
        await store.receive(\.exportCompleted)

        #expect(didReserve.value)
        #expect(store.state.phase == .done)
    }

    @Test func blockedExportDoesNotStartComposition() async {
        let didStartComposition = LockIsolated(false)
        let clip = exportableClip()
        let store = TestStore(initialState: ExportFeature.State()) {
            ExportFeature()
        } withDependencies: {
            $0.subscriptionClient.isSubscribedCached = { false }
            $0.exportQuotaClient.reserveExport = { .blocked(.dailyLimit) }
            $0.compositionClient.export = { _, _, _, _, _ in
                didStartComposition.setValue(true)
                return AsyncStream { $0.finish() }
            }
        }
        store.exhaustivity = .off

        await store.send(.startExport(clips: [clip], rotations: [:], transforms: [:], clipLabels: [:]))

        #expect(!didStartComposition.value)
        #expect(store.state.phase == .failed)
        #expect(store.state.errorMessage == ExportQuotaBlockReason.dailyLimit.message)
    }

    @Test func subscribedUserBypassesQuota() async {
        let clip = exportableClip()
        let output = URL(fileURLWithPath: "/tmp/chalna-export.mp4")
        let store = TestStore(initialState: ExportFeature.State()) {
            ExportFeature()
        } withDependencies: {
            $0.subscriptionClient.isSubscribedCached = { true }
            // 쿼터가 소진돼 있어도 구독자는 통과해야 한다.
            $0.exportQuotaClient.reserveExport = { .blocked(.dailyLimit) }
            $0.compositionClient.export = { _, _, _, _, _ in
                AsyncStream { continuation in
                    continuation.yield(.completed(output))
                    continuation.finish()
                }
            }
            $0.photoLibraryClient.saveVideoToPhotoLibrary = { _ in .ok }
        }
        store.exhaustivity = .off

        await store.send(.startExport(clips: [clip], rotations: [:], transforms: [:], clipLabels: [:]))
        await store.receive(\.exportCompleted)
        #expect(store.state.phase == .done)
    }

    private func exportableClip() -> Clip {
        Clip(
            kind: .video,
            capturedAt: Date(timeIntervalSince1970: 1_780_000_000),
            duration: 1,
            preset: .jejuSea,
            videoURL: URL(fileURLWithPath: "/tmp/source.mp4")
        )
    }
}
