import ComposableArchitecture

public protocol AppLanguageWriting: Sendable {
    @MainActor func set(_ newValue: AppLanguage)
}

private enum AppLanguageWriterKey: TestDependencyKey {
    struct PreviewWriter: AppLanguageWriting {
        func set(_ newValue: AppLanguage) {}
    }
    static let testValue: any AppLanguageWriting = PreviewWriter()
}

public extension DependencyValues {
    var appLanguageWriter: any AppLanguageWriting {
        get { self[AppLanguageWriterKey.self] }
        set { self[AppLanguageWriterKey.self] = newValue }
    }
}
