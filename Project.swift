import ProjectDescription
import ProjectDescriptionHelpers

let project = Project(
    name: "ChalNa",
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
            name: "AnalyticsService",
            dependencies: [
                .external(name: "ComposableArchitecture"),
                .external(name: "FirebaseAnalytics"),
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
                .target(name: "AnalyticsService"),
                .target(name: "Models"),
                .target(name: "DesignSystem"),
                .external(name: "ComposableArchitecture"),
            ]
        ),
        Module.framework(
            name: "MediaPickerFeature",
            dependencies: [
                .target(name: "AnalyticsService"),
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
                .target(name: "AnalyticsService"),
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
        Module.framework(
            name: "SettingsFeature",
            dependencies: [
                .target(name: "AppCore"),
                .target(name: "AnalyticsService"),
                .target(name: "Models"),
                .target(name: "DesignSystem"),
                .external(name: "ComposableArchitecture"),
            ]
        ),
        Module.framework(
            name: "FilmDetailFeature",
            dependencies: [
                .target(name: "AnalyticsService"),
                .target(name: "Models"),
                .target(name: "DesignSystem"),
                .target(name: "FileStorage"),
                .external(name: "ComposableArchitecture"),
            ]
        ),
        .target(
            name: "ChalNa",
            destinations: [.iPhone],
            product: .app,
            bundleId: Module.bundleIdPrefix,
            deploymentTargets: Module.deploymentTargets,
            infoPlist: .extendingDefault(
                with: [
                    // 수출 규정 준수: 표준 HTTPS(TLS) 외 독자 암호화를 쓰지 않으므로 면제 대상.
                    // 이 키가 있으면 App Store Connect 제출 시 암호화 질문을 매번 묻지 않는다.
                    "ITSAppUsesNonExemptEncryption": false,
                    "UILaunchScreen": [
                        "UIColorName": "",
                        "UIImageName": "",
                    ],
                    "NSPhotoLibraryUsageDescription": "Live Photo 내부의 영상을 불러와 Vlog로 이어 붙이기 위해 사진 보관함 접근이 필요해요.",
                    "NSPhotoLibraryAddUsageDescription": "완성한 Vlog를 사진 보관함에 저장하려면 권한이 필요해요.",
                    "UIUserInterfaceStyle": "Light",
                    "UIAppFonts": [
                        "KERISKEDU_Line.otf",
                    ],
                    "CFBundleDevelopmentRegion": "ko",
                    "CFBundleLocalizations": ["ko", "en", "ja"],
                ]
            ),
            buildableFolders: [
                "ChalNa/Sources",
                "ChalNa/Resources",
                "Modules/PhotosService/Resources",
            ],
            dependencies: [
                .target(name: "DesignSystem"),
                .target(name: "FileStorage"),
                .target(name: "Models"),
                .target(name: "CompositionService"),
                .target(name: "PhotosService"),
                .target(name: "AppCore"),
                .target(name: "AnalyticsService"),
                .target(name: "HomeFeature"),
                .target(name: "MediaPickerFeature"),
                .target(name: "ExportFeature"),
                .target(name: "TimelineFeature"),
                .target(name: "FilmDetailFeature"),
                .target(name: "SettingsFeature"),
                .external(name: "ComposableArchitecture"),
                .external(name: "FirebaseAnalytics"),
            ],
            // Firebase(GoogleUtilities 등) 가 staticFramework 로 통합되어 있어
            // ObjC 카테고리 메서드(`gul_dataByGzippingData:` 등) 가 링커의 dead-code-stripping
            // 으로 빠지면서 런타임에 unrecognized selector 가 발생. `-ObjC` 로 강제 로드.
            settings: .settings(base: ["OTHER_LDFLAGS": "$(inherited) -ObjC"])
        ),
        Module.unitTests(
            for: "AppCore",
            dependencies: [
                .target(name: "Models"),
                .external(name: "ComposableArchitecture"),
            ]
        ),
        Module.unitTests(
            for: "ExportFeature",
            dependencies: [
                .target(name: "AppCore"),
                .target(name: "Models"),
                .target(name: "CompositionService"),
                .target(name: "PhotosService"),
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
        Module.unitTests(
            for: "MediaPickerFeature",
            dependencies: [
                .target(name: "PhotosService"),
            ]
        ),
        Module.unitTests(
            for: "SettingsFeature",
            dependencies: [
                .target(name: "AppCore"),
                .target(name: "Models"),
                .external(name: "ComposableArchitecture"),
            ]
        ),
    ],
    schemes: [
        .scheme(
            name: "ChalNa Dev",
            shared: true,
            buildAction: .buildAction(targets: ["ChalNa"]),
            runAction: .runAction(
                configuration: .debug,
                executable: "ChalNa",
                arguments: .arguments(environmentVariables: [
                    "CHALNA_APP_MODE": "devMock",
                ])
            )
        ),
    ]
)
