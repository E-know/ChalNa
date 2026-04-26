import ProjectDescription
import ProjectDescriptionHelpers

let project = Project(
    name: "OneSecMovie",
    targets: [
        Module.framework(
            name: "DesignSystem",
            hasResources: true
        ),
        Module.framework(
            name: "Models",
            dependencies: [.target(name: "DesignSystem")]
        ),
        Module.framework(
            name: "CompositionService",
            dependencies: [.target(name: "Models")]
        ),
        Module.framework(
            name: "PhotosService",
            dependencies: [.target(name: "Models")]
        ),
        Module.framework(
            name: "AppCore",
            dependencies: [.target(name: "Models")]
        ),
        Module.framework(
            name: "HomeFeature",
            dependencies: [
                .target(name: "AppCore"),
                .target(name: "Models"),
                .target(name: "DesignSystem"),
            ]
        ),
        Module.framework(
            name: "MediaPickerFeature",
            dependencies: [
                .target(name: "AppCore"),
                .target(name: "Models"),
                .target(name: "DesignSystem"),
            ]
        ),
        .target(
            name: "OneSecMovie",
            destinations: .iOS,
            product: .app,
            bundleId: Module.bundleIdPrefix,
            deploymentTargets: Module.deploymentTargets,
            infoPlist: .extendingDefault(
                with: [
                    "UILaunchScreen": [
                        "UIColorName": "",
                        "UIImageName": "",
                    ],
                    "NSPhotoLibraryUsageDescription": "Live Photo 내부의 영상을 불러와 Vlog로 이어 붙이기 위해 사진 보관함 접근이 필요해요.",
                    "NSPhotoLibraryAddUsageDescription": "완성한 Vlog를 사진 보관함에 저장하려면 권한이 필요해요.",
                ]
            ),
            buildableFolders: [
                "OneSecMovie/Sources",
                "OneSecMovie/Resources",
            ],
            dependencies: [
                .target(name: "DesignSystem"),
                .target(name: "Models"),
                .target(name: "CompositionService"),
                .target(name: "PhotosService"),
                .target(name: "AppCore"),
                .target(name: "HomeFeature"),
                .target(name: "MediaPickerFeature"),
            ]
        ),
        .target(
            name: "OneSecMovieTests",
            destinations: .iOS,
            product: .unitTests,
            bundleId: "\(Module.bundleIdPrefix)Tests",
            deploymentTargets: Module.deploymentTargets,
            infoPlist: .default,
            buildableFolders: [
                "OneSecMovie/Tests"
            ],
            dependencies: [.target(name: "OneSecMovie")]
        ),
    ]
)
