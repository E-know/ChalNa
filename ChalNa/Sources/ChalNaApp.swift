import AnalyticsService
import AppCore
import ComposableArchitecture
import CompositionService
import DesignSystem
import FilmLibrary
import FirebaseCore
import Models
import PhotosService
import SwiftData
import SwiftUI

@main
struct ChalNaApp: App {
    private let library: Result<ModelContainer, Error>
    private let languageStore: AppLanguageStore

    init() {
        let languages = AppLanguageStore()
        languageStore = languages
        let library = Result { try ModelContainer(for: Film.self) }
        self.library = library

        if AppMode.current == .real, !AppMode.isShowcase,
           Bundle.main.url(forResource: "GoogleService-Info", withExtension: "plist") != nil {
            FirebaseApp.configure()
        }
        let tracker: any AnalyticsTracker = FirebaseApp.app() == nil ? NoopAnalyticsTracker() : FirebaseAnalyticsTracker()
        let photos = PhotoLibraryClient.liveValue
        prepareDependencies {
            $0.analyticsTracker = tracker
            $0.appLanguageWriter = languages
            $0.filmComposer = AVFoundationCompositionService()
            $0.photoWriter = photos
            $0.filmVideo = FilmVideoClient(
                availability: photos.videoAvailability,
                loadPlayerItem: photos.loadPlayerItem,
                loadShareURL: photos.loadShareURL,
                changes: photos.photoLibraryChanges,
                requestAccess: { _ = await photos.requestAuthorization() }
            )
            #if DEBUG
            if AppMode.current == .devMock,
               ProcessInfo.processInfo.environment["CHALNA_UI_TEST_ISOLATE_EXPORT_QUOTA"] == "1" {
                let ledger = LockIsolated(ExportQuotaLedger())
                $0.exportQuotaClient = ExportQuotaClient(
                    isUnlocked: { ledger.value.isUnlocked(at: Date()) },
                    checkExport: { ledger.value.checkExport(now: Date()) },
                    reserveExport: { ledger.withValue { $0.reserveExport(now: Date()) } },
                    redeem: { code in ledger.withValue { $0.redeem(code: code, now: Date()) } }
                )
            }
            #endif
            if case let .success(container) = library {
                let archive = SwiftDataFilmArchive(container: container)
                $0.filmArchive = archive
                $0.filmRemoval = archive
                $0.filmReader = archive
            }
        }
        Task.detached(priority: .utility) {
            try? SwiftDataFilmArchive.removeLegacyMovieFiles()
        }
        RemovedSettingsCleanup.run()
    }

    var body: some Scene {
        WindowGroup {
            switch library {
            case let .success(container):
                ContentView()
                    .font(ChalNaTypography.body)
                    .environment(languageStore)
                    .modelContainer(container)
            case let .failure(error):
                ContentUnavailableView {
                    Text("필름 보관함을 열 수 없어요")
                } description: {
                    Text(verbatim: error.localizedDescription)
                }
                .chalNaScreen()
            }
        }
    }
}
