import ProjectDescription

let project = Project(
    name: "OneSecMovie",
    targets: [
        .target(
            name: "OneSecMovie",
            destinations: .iOS,
            product: .app,
            bundleId: "ios.inho.OneSecMovie",
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
            dependencies: []
        ),
        .target(
            name: "OneSecMovieTests",
            destinations: .iOS,
            product: .unitTests,
            bundleId: "ios.inho.OneSecMovieTests",
            infoPlist: .default,
            buildableFolders: [
                "OneSecMovie/Tests"
            ],
            dependencies: [.target(name: "OneSecMovie")]
        ),
    ]
)
