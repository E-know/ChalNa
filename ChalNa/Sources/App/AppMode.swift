import Foundation

enum AppMode {
    case real
    case devMock

    static var current: AppMode {
        #if DEBUG
        if ProcessInfo.processInfo.environment["CHALNA_APP_MODE"] == "devMock" {
            return .devMock
        }
        #endif
        return .real
    }
}
