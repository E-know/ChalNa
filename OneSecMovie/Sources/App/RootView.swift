import SwiftUI
import AppCore
import DesignSystem

/// 앱 루트. Home을 루트로 삼고 MediaPicker / Timeline / Export를 push.
public struct RootView: View {
    @State private var router = AppRouter()
    @State private var session = EditSession()

    public init() {}

    public var body: some View {
        NavigationStack(path: $router.path) {
            HomeView()
                .toolbar(.hidden, for: .navigationBar)
                .momentsSwipeBack()
                .navigationDestination(for: Route.self) { route in
                    destination(for: route)
                        .toolbar(.hidden, for: .navigationBar)
                        .navigationBarBackButtonHidden(true)
                        .momentsSwipeBack()
                }
        }
        .environment(router)
        .environment(session)
    }

    @ViewBuilder
    private func destination(for route: Route) -> some View {
        switch route {
        case .mediaPicker: MediaPickerView()
        case .timeline:    TimelineView()
        case .export:      ExportView()
        }
    }
}

#Preview {
    RootView()
}
