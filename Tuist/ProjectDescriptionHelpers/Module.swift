import ProjectDescription

public enum Module {
    public static let bundleIdPrefix = "ios.inho.OneSecMovie"
    public static let deploymentTargets: DeploymentTargets = .iOS("18.0")

    public static func framework(
        name: String,
        hasResources: Bool = false,
        dependencies: [TargetDependency] = []
    ) -> Target {
        var folders: [BuildableFolder] = [.folder(.relativeToManifest("Modules/\(name)/Sources"))]
        if hasResources {
            folders.append(.folder(.relativeToManifest("Modules/\(name)/Resources")))
        }
        return .target(
            name: name,
            destinations: .iOS,
            product: .staticFramework,
            bundleId: "\(bundleIdPrefix).\(name)",
            deploymentTargets: deploymentTargets,
            buildableFolders: folders,
            dependencies: dependencies
        )
    }
}
