import SwiftUI
import Models
import SwiftData

@main
struct OneSecMovieApp: App {
    var body: some Scene {
        WindowGroup {
            ContentView()
        }
        .modelContainer(for: Film.self)
    }
}
