import SwiftUI
import Models
import SwiftData

@main
struct MomentsApp: App {
    var body: some Scene {
        WindowGroup {
            ContentView()
        }
        .modelContainer(for: Film.self)
    }
}
