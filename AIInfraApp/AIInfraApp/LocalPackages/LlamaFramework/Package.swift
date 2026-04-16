// swift-tools-version: 5.10

import PackageDescription

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
        .binaryTarget(
            name: "llama",
            url: "https://github.com/ggml-org/llama.cpp/releases/download/b8783/llama-b8783-xcframework.zip",
            checksum: "f492f3df80f38367692626ba1621c7762cb5864ac529c3e66b6877303b2dbb46"
        )
    ]
)
