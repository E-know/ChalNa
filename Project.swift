import ProjectDescription
import ProjectDescriptionHelpers

let project = Project(
    name: "OneSecMovie",
    targets: [
        Module.framework(
            name: "DesignSystem",
            hasResources: true,
            isDynamic: true
        ),
        Module.framework(
            name: "FileStorage"
        ),
        Module.framework(
            name: "Models",
            dependencies: [.target(name: "FileStorage")]
        ),
        Module.framework(
            name: "CompositionService",
            dependencies: [
                .target(name: "Models"),
                .external(name: "ComposableArchitecture"),
            ]
        ),
        Module.framework(
            name: "PhotosService",
            hasResources: true,
            dependencies: [
                .target(name: "Models"),
                .external(name: "ComposableArchitecture"),
            ]
        ),
        Module.framework(
            name: "AppCore",
            dependencies: [
                .target(name: "Models"),
                .external(name: "ComposableArchitecture"),
            ]
        ),
        Module.framework(
            name: "HomeFeature",
            dependencies: [
                .target(name: "AppCore"),
                .target(name: "Models"),
                .target(name: "DesignSystem"),
                .external(name: "ComposableArchitecture"),
            ]
        ),
        Module.framework(
            name: "MediaPickerFeature",
            dependencies: [
                .target(name: "AppCore"),
                .target(name: "Models"),
                .target(name: "DesignSystem"),
                .target(name: "PhotosService"),
                .external(name: "ComposableArchitecture"),
            ]
        ),
        Module.framework(
            name: "ExportFeature",
            dependencies: [
                .target(name: "AppCore"),
                .target(name: "Models"),
                .target(name: "DesignSystem"),
                .target(name: "CompositionService"),
                .target(name: "FileStorage"),
                .target(name: "PhotosService"),
                .external(name: "ComposableArchitecture"),
            ]
        ),
        Module.framework(
            name: "TimelineFeature",
            dependencies: [
                .target(name: "AppCore"),
                .target(name: "Models"),
                .target(name: "DesignSystem"),
                .external(name: "ComposableArchitecture"),
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
                    "UIUserInterfaceStyle": "Light",
                ]
            ),
            buildableFolders: [
                "OneSecMovie/Sources",
                "OneSecMovie/Resources",
                "Modules/PhotosService/Resources",
            ],
            dependencies: [
                .target(name: "DesignSystem"),
                .target(name: "FileStorage"),
                .target(name: "Models"),
                .target(name: "CompositionService"),
                .target(name: "PhotosService"),
                .target(name: "AppCore"),
                .target(name: "HomeFeature"),
                .target(name: "MediaPickerFeature"),
                .target(name: "ExportFeature"),
                .target(name: "TimelineFeature"),
                .external(name: "ComposableArchitecture"),
            ]
        ),
        Module.unitTests(
            for: "AppCore",
            dependencies: [
                .target(name: "Models"),
                .external(name: "ComposableArchitecture"),
            ]
        ),
        Module.unitTests(
            for: "CompositionService",
            dependencies: [.target(name: "Models")]
        ),
        Module.unitTests(
            for: "PhotosService",
            dependencies: [
                .target(name: "CompositionService"),
                .target(name: "Models"),
            ],
            additionalBuildableFolders: [
                .folder(.relativeToManifest("Modules/PhotosService/Resources")),
            ]
        ),
        Module.unitTests(
            for: "TimelineFeature",
            dependencies: [
                .target(name: "Models"),
                .target(name: "CompositionService"),
                .external(name: "ComposableArchitecture"),
            ]
        ),
    ],
    schemes: [
        .scheme(
            name: "OneSecMovie Dev",
            shared: true,
            buildAction: .buildAction(targets: ["OneSecMovie"]),
            runAction: .runAction(
                configuration: .debug,
                executable: "OneSecMovie",
                arguments: .arguments(environmentVariables: [
                    "MOMENTS_APP_MODE": "devMock",
                ])
            )
        ),
    ]
)
