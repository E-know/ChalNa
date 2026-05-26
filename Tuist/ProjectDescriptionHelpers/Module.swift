import ProjectDescription

public enum Module {
    public static let bundleIdPrefix = "ios.inho.ChalNa"
    public static let deploymentTargets: DeploymentTargets = .iOS("18.0")

    public static func framework(
        name: String,
        hasResources: Bool = false,
        isDynamic: Bool = false,
        dependencies: [TargetDependency] = []
    ) -> Target {
        var folders: [BuildableFolder] = [.folder(.relativeToManifest("Modules/\(name)/Sources"))]
        if hasResources {
            folders.append(.folder(.relativeToManifest("Modules/\(name)/Resources")))
        }
        return .target(
            name: name,
            destinations: .iOS,
            product: isDynamic ? .framework : .staticFramework,
            bundleId: "\(bundleIdPrefix).\(name)",
            deploymentTargets: deploymentTargets,
            buildableFolders: folders,
            dependencies: dependencies
        )
    }

    /// `Modules/<name>/Tests` 폴더를 사용하는 단위 테스트 타겟.
    /// 이름은 자동으로 `<name>Tests`. 의존성은 자기 모듈 + 명시한 추가 모듈.
    public static func unitTests(
        for moduleName: String,
        dependencies: [TargetDependency] = [],
        additionalBuildableFolders: [BuildableFolder] = []
    ) -> Target {
        return .target(
            name: "\(moduleName)Tests",
            destinations: .iOS,
            product: .unitTests,
            bundleId: "\(bundleIdPrefix).\(moduleName)Tests",
            deploymentTargets: deploymentTargets,
            buildableFolders: [.folder(.relativeToManifest("Modules/\(moduleName)/Tests"))] + additionalBuildableFolders,
            dependencies: [.target(name: moduleName)] + dependencies
        )
    }
}
