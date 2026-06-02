import SwiftUI
import Models
import SwiftData
import ComposableArchitecture
import FirebaseCore
import AnalyticsService
import AppCore

@main
struct ChalNaApp: App {
    init() {
        // GoogleService-Info.plist 가 번들에 포함돼 있어야 한다.
        // plist 부재 시 Firebase 초기화를 건너뛰고 Noop tracker 로 fallback.
        let firebaseConfigured: Bool
        if Bundle.main.url(forResource: "GoogleService-Info", withExtension: "plist") != nil {
            FirebaseApp.configure()
            firebaseConfigured = FirebaseApp.app() != nil
        } else {
            firebaseConfigured = false
        }

        // TCA dependency liveValue 를 전역 override.
        let tracker: any AnalyticsTracker = firebaseConfigured
            ? FirebaseAnalyticsTracker()
            : NoopAnalyticsTracker()
        prepareDependencies {
            $0.analyticsTracker = tracker
        }

        // 저장된 앱 언어를 첫 페인트 전에 적용(스위즐 설치).
        AppLanguageStore.applyStoredLanguageAtLaunch()
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
        }
        .modelContainer(for: Film.self)
    }
}
