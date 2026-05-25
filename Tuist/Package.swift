// swift-tools-version: 6.0
import PackageDescription

#if TUIST
    import struct ProjectDescription.PackageSettings

    // Firebase 제품은 Apple 권장에 따라 staticFramework 로 통일.
    // (FirebaseAnalytics 는 내부적으로 GoogleAppMeasurement ObjC binary 를 끌고 옴.)
    let packageSettings = PackageSettings(
        productTypes: [
            "FirebaseAnalytics": .staticFramework,
            "FirebaseCore": .staticFramework,
            "FirebaseCoreInternal": .staticFramework,
            "FirebaseInstallations": .staticFramework,
            "GoogleUtilities": .staticFramework,
            "GoogleAppMeasurement": .staticFramework,
            "nanopb": .staticFramework,
            "Promises": .staticFramework,
        ]
    )
#endif

let package = Package(
    name: "Moments",
    dependencies: [
        .package(
            url: "https://github.com/pointfreeco/swift-composable-architecture",
            from: "1.18.0"
        ),
        .package(
            url: "https://github.com/firebase/firebase-ios-sdk",
            exact: "12.13.0"
        ),
    ]
)
