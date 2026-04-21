// swift-tools-version: 5.10

import PackageDescription

// MARK: - llama.cpp xcframework 配置
//
// 含 mtmd 多模态支持，基于 llama.cpp b8854
// 本地编译: ./scripts/build-llama-xcframework.sh
//

let package = Package(
    name: "LlamaFramework",
    platforms: [
        .iOS(.v17),
        .macOS(.v14)
    ],
    products: [
        .library(
            name: "llama",
            targets: ["llama"]
        )
    ],
    targets: [
        // 本地编译版本（含 mtmd 多模态支持）
        .binaryTarget(
            name: "llama",
            path: "llama.xcframework"
        )

        // 远程版本（上传到 GitHub Release 后使用）
        // .binaryTarget(
        //     name: "llama",
        //     url: "https://github.com/JellyP/ios-client-ai-infra/releases/download/v1.0.0-llama/llama-mtmd-b8854-xcframework.zip",
        //     checksum: "fc9c74fe5861c55f0f732748ac4619f98a33d8c5948af47ff27eaabfe2ba7e9b"
        // )
    ]
)
