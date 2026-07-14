import ComposableArchitecture
import Foundation
import Models
import AppCore
import CompositionService
import PhotosService
import AnalyticsService

/// Timeline → Export 화면 Reducer. 진행률/완료/실패 phase 와 사진 보관함 저장 phase 를 함께 관리.
@Reducer
public struct ExportFeature {
    public init() {}

    // MARK: - State

    @ObservableState
    public struct State: Equatable {
        public var phase: ExportPhase
        public var progress: Double
        public var exportedURL: URL?
        public var errorMessage: String?
        public var isSaving: Bool
        public var saveToast: String?
        /// 같은 export 가 두 번 라이브러리에 추가되는 걸 방지.
        public var didAddToLibrary: Bool
        public var isPlayerPresented: Bool

        // 라벨 설정(설정 화면과 동일 키 공유). 익스포트 시 LabelSettings로 조립.
        @Shared(.appStorage("labelTimeEnabled")) public var timeEnabled = true
        @Shared(.appStorage("labelTimePosition")) public var timePosition = LabelPosition.center
        @Shared(.appStorage("labelDateEnabled")) public var dateEnabled = true
        @Shared(.appStorage("labelDatePosition")) public var datePosition = LabelPosition.bottomCenter
        @Shared(.appStorage("labelTimeOpacity")) public var timeOpacity = 0.5
        @Shared(.appStorage("labelDateOpacity")) public var dateOpacity = 1.0

        public init(
            phase: ExportPhase = .idle,
            progress: Double = 0,
            exportedURL: URL? = nil,
            errorMessage: String? = nil,
            isSaving: Bool = false,
            saveToast: String? = nil,
            didAddToLibrary: Bool = false,
            isPlayerPresented: Bool = false
        ) {
            self.phase = phase
            self.progress = progress
            self.exportedURL = exportedURL
            self.errorMessage = errorMessage
            self.isSaving = isSaving
            self.saveToast = saveToast
            self.didAddToLibrary = didAddToLibrary
            self.isPlayerPresented = isPlayerPresented
        }
    }

    public enum ExportPhase: Sendable, Equatable {
        case idle
        case exporting
        case done
        case failed
    }

    // MARK: - Action

    public enum Action {
        case startExport(clips: [Clip], rotations: [Clip.ID: ClipRotation], transforms: [Clip.ID: ClipTransform], clipLabels: [Clip.ID: ClipLabel])
        case exportProgress(Double)
        case exportCompleted(URL)
        case exportFailed(String)

        case retryTapped(clips: [Clip], rotations: [Clip.ID: ClipRotation], transforms: [Clip.ID: ClipTransform], clipLabels: [Clip.ID: ClipLabel])

        case saveToPhotoLibraryTapped
        case saveCompleted(PhotoSaveResult)
        case toastDismissed

        case markAddedToLibrary

        case playerPresentedChanged(Bool)

        // Navigation intents
        case viewDisappeared
        case backToEditTapped
        case startAnotherTapped
        case homeTapped
        case delegate(Delegate)

        /// 부모(AppFeature)가 화면 전환으로 해석하는 네비게이션 인텐트.
        public enum Delegate: Equatable {
            /// 홈으로 — 부모가 popToRoot.
            case homeRequested
            /// 다른 영상 만들기 — 부모가 세션 초기화 후 popToRoot + MediaPicker push.
            case newFilmRequested
        }
    }

    // MARK: - Dependencies

    @Dependency(\.compositionClient) var compositionClient
    @Dependency(\.photoLibraryClient) var photoLibraryClient
    @Dependency(\.analyticsTracker) var analyticsTracker
    @Dependency(\.exportQuotaClient) var exportQuotaClient
    @Dependency(\.dismiss) var dismiss

    private enum CancelID { case exportStream }

    // MARK: - Reducer

    public var body: some ReducerOf<Self> {
        Reduce { state, action in
            switch action {
            case let .startExport(clips, rotations, transforms, clipLabels):
                guard !clips.isEmpty else { return .none }
                switch exportQuotaClient.reserveExport() {
                case .allowed:
                    break
                case let .blocked(reason):
                    state.phase = .failed
                    state.progress = 0
                    state.errorMessage = reason.message
                    state.exportedURL = nil
                    state.didAddToLibrary = false
                    analyticsTracker.log(.exportFailed(reason: "quota_\(reason)"))
                    return .none
                }
                state.phase = .exporting
                state.progress = 0
                state.errorMessage = nil
                state.exportedURL = nil
                state.didAddToLibrary = false
                analyticsTracker.log(.exportStarted(clipCount: clips.count))
                let labelSettings = LabelSettings(
                    timeEnabled: state.timeEnabled,
                    timePosition: state.timePosition,
                    timeOpacity: state.timeOpacity,
                    dateEnabled: state.dateEnabled,
                    datePosition: state.datePosition,
                    dateOpacity: state.dateOpacity
                )
                return .run { send in
                    for await event in compositionClient.export(clips, rotations, transforms, labelSettings, clipLabels) {
                        switch event {
                        case let .progress(p):
                            await send(.exportProgress(p))
                        case let .completed(url):
                            await send(.exportCompleted(url))
                        case let .failed(msg):
                            await send(.exportFailed(msg))
                        }
                    }
                }
                .cancellable(id: CancelID.exportStream, cancelInFlight: true)

            case let .exportProgress(p):
                state.progress = p
                if state.phase != .exporting {
                    state.phase = .exporting
                }
                return .none

            case let .exportCompleted(url):
                state.progress = 1.0
                state.exportedURL = url
                state.phase = .done
                analyticsTracker.log(.exportCompleted(durationMs: nil))
                // 완성되면 자동으로 사진 보관함에 저장. 중복 추가는 `didAddToLibrary` 가드.
                if !state.didAddToLibrary {
                    return .send(.saveToPhotoLibraryTapped)
                }
                return .none

            case let .exportFailed(msg):
                state.errorMessage = msg
                state.phase = .failed
                analyticsTracker.log(.exportFailed(reason: msg))
                return .none

            case let .retryTapped(clips, rotations, transforms, clipLabels):
                return .send(.startExport(clips: clips, rotations: rotations, transforms: transforms, clipLabels: clipLabels))

            case .saveToPhotoLibraryTapped:
                guard let url = state.exportedURL,
                      !state.isSaving,
                      !state.didAddToLibrary else { return .none }
                state.isSaving = true
                return .run { send in
                    let result = await photoLibraryClient.saveVideoToPhotoLibrary(url)
                    await send(.saveCompleted(result))
                }

            case let .saveCompleted(result):
                state.isSaving = false
                switch result {
                case .ok:
                    state.didAddToLibrary = true
                    state.saveToast = String(localized: "사진 앱에 저장됐어요 ✦")
                    analyticsTracker.log(.vlogSavedToLibrary)
                case .denied:
                    state.saveToast = String(localized: "사진 보관함 접근 권한이 필요해요")
                    analyticsTracker.log(.vlogSaveFailed(reason: "denied"))
                case let .failed(msg):
                    state.saveToast = String(localized: "저장 실패 — \(msg)")
                    analyticsTracker.log(.vlogSaveFailed(reason: msg))
                }
                return .none

            case .toastDismissed:
                state.saveToast = nil
                return .none

            case .markAddedToLibrary:
                state.didAddToLibrary = true
                return .none

            case let .playerPresentedChanged(isPresented):
                state.isPlayerPresented = isPresented
                return .none

            case .viewDisappeared:
                // pop 완료 후 뒷정리 전용 — 여기서 dismiss 를 부르면 안 된다(이미 스택에서 빠진 상태).
                state.isPlayerPresented = false
                return .cancel(id: CancelID.exportStream)

            case .backToEditTapped:
                state.isPlayerPresented = false
                return .concatenate(
                    .cancel(id: CancelID.exportStream),
                    .run { _ in await dismiss() }
                )

            case .startAnotherTapped:
                state.isPlayerPresented = false
                return .concatenate(
                    .cancel(id: CancelID.exportStream),
                    .send(.delegate(.newFilmRequested))
                )

            case .homeTapped:
                state.isPlayerPresented = false
                return .concatenate(
                    .cancel(id: CancelID.exportStream),
                    .send(.delegate(.homeRequested))
                )

            case .delegate:
                return .none
            }
        }
    }
}

// MARK: - View helpers

public extension ExportFeature.ExportPhase {
    var title: String {
        switch self {
        case .idle, .exporting: return String(localized: "저장 중")
        case .done:             return String(localized: "완성")
        case .failed:           return String(localized: "저장 실패")
        }
    }

    var tag: String {
        switch self {
        case .idle, .exporting: return "EXPORTING"
        case .done:             return "DONE"
        case .failed:           return "FAILED"
        }
    }
}
