import Observation

/// 루트 NavigationStack의 라우트 열거형. Home은 루트에서 렌더하므로 스택에 push하지 않음.
public enum Route: Hashable {
    case mediaPicker
    case timeline
    case export
}

@Observable
public final class AppRouter {
    public var path: [Route]

    public init(path: [Route] = []) {
        self.path = path
    }

    public func push(_ route: Route) { path.append(route) }
    public func pop() { if !path.isEmpty { path.removeLast() } }
    public func popToRoot() { path.removeAll() }
}
