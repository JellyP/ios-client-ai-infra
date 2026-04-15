// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "AIInfraApp",
    platforms: [
        .iOS(.v17)
    ],
    dependencies: [
        // llama.cpp Swift 绑定（端侧模型推理）
        // .package(url: "https://github.com/ggerganov/llama.cpp", branch: "master"),
    ],
    targets: [
        .executableTarget(
            name: "AIInfraApp",
            dependencies: [],
            path: "AIInfraApp"
        )
    ]
)
