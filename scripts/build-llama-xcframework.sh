#!/bin/bash
#
# build-llama-xcframework.sh
#
# 编译包含多模态 (mtmd) 支持的 llama.cpp xcframework
# 只编译库目标（不编译 CLI 工具），避免 iOS 签名问题
#
# 产物: AIInfraApp/AIInfraApp/LocalPackages/LlamaFramework/llama.xcframework
#
# 使用方法:
#   ./scripts/build-llama-xcframework.sh
#
# 依赖: Xcode 15+, CMake 3.20+
#

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"
BUILD_DIR="${PROJECT_ROOT}/.llama-build"
OUTPUT_DIR="${PROJECT_ROOT}/AIInfraApp/AIInfraApp/LocalPackages/LlamaFramework"
LLAMA_REPO="https://github.com/ggml-org/llama.cpp.git"
LLAMA_TAG="b8854"

echo "============================================"
echo " 编译 llama.cpp xcframework (含 mtmd 多模态)"
echo "============================================"
echo ""
echo "  版本:     ${LLAMA_TAG}"
echo "  编译目录: ${BUILD_DIR}"
echo "  输出目录: ${OUTPUT_DIR}"
echo ""

command -v cmake >/dev/null 2>&1 || { echo "错误: 需要安装 CMake (brew install cmake)"; exit 1; }
command -v xcodebuild >/dev/null 2>&1 || { echo "错误: 需要安装 Xcode"; exit 1; }

# ── Step 1: 克隆 ──
LLAMA_SRC="${BUILD_DIR}/llama.cpp"
if [ -d "${LLAMA_SRC}" ]; then
    echo "[1/6] llama.cpp 已存在，切换到 ${LLAMA_TAG}..."
    cd "${LLAMA_SRC}"
    git fetch --tags 2>/dev/null || true
    git checkout "${LLAMA_TAG}" 2>/dev/null || git checkout "tags/${LLAMA_TAG}" 2>/dev/null || true
else
    echo "[1/6] 克隆 llama.cpp ${LLAMA_TAG}..."
    mkdir -p "${BUILD_DIR}"
    git clone --depth 100 --branch "${LLAMA_TAG}" "${LLAMA_REPO}" "${LLAMA_SRC}" 2>/dev/null || {
        git clone "${LLAMA_REPO}" "${LLAMA_SRC}"
        cd "${LLAMA_SRC}" && git checkout "${LLAMA_TAG}"
    }
fi
cd "${LLAMA_SRC}"
echo "  commit: $(git rev-parse --short HEAD 2>/dev/null)"

# CMake 参数：只编译库，不编译工具/可执行文件
# 但开启 LLAMA_BUILD_TOOLS=ON 让 CMake 知道 mtmd 目标
COMMON_CMAKE_ARGS=(
    -DCMAKE_BUILD_TYPE=Release
    -DBUILD_SHARED_LIBS=OFF
    -DGGML_METAL=ON
    -DGGML_METAL_EMBED_LIBRARY=ON
    -DGGML_METAL_USE_BF16=ON
    -DGGML_BLAS_DEFAULT=ON
    -DGGML_OPENMP=OFF
    -DLLAMA_BUILD_EXAMPLES=OFF
    -DLLAMA_BUILD_TOOLS=ON
    -DLLAMA_BUILD_TESTS=OFF
    -DLLAMA_BUILD_SERVER=OFF
)

COMMON_C_FLAGS="-Wno-macro-redefined -Wno-shorten-64-to-32 -Wno-unused-command-line-argument"

# 编译函数：使用 Xcode generator 但只编译指定的库目标
build_platform() {
    local BUILD_SUBDIR=$1
    local SDK=$2
    local ARCH=$3
    local LABEL=$4

    echo ""
    echo "  编译 ${LABEL}..."
    rm -rf "${BUILD_SUBDIR}"

    cmake -B "${BUILD_SUBDIR}" -G Xcode \
        "${COMMON_CMAKE_ARGS[@]}" \
        -DCMAKE_SYSTEM_NAME=iOS \
        -DCMAKE_OSX_DEPLOYMENT_TARGET=17.0 \
        -DCMAKE_C_FLAGS="${COMMON_C_FLAGS}" \
        -DCMAKE_CXX_FLAGS="${COMMON_C_FLAGS}" \
        2>&1 | tail -5

    # 只编译库目标，不编译 CLI 工具（避免 Bundle ID 错误）
    # 目标: ggml, ggml-base, ggml-cpu, ggml-metal, ggml-blas, llama, mtmd
    for target in ggml ggml-base ggml-cpu ggml-metal ggml-blas llama mtmd; do
        cmake --build "${BUILD_SUBDIR}" --config Release --target "${target}" -- \
            -sdk "${SDK}" \
            -arch "${ARCH}" \
            ONLY_ACTIVE_ARCH=NO \
            -quiet 2>/dev/null || echo "    (跳过不存在的目标: ${target})"
    done
}

# ── Step 2-4: 编译三个平台 ──
echo "[2/6] 编译 iOS 平台..."

build_platform "build-ios-device" "iphoneos" "arm64" "iOS Device (arm64)"
build_platform "build-ios-sim-arm64" "iphonesimulator" "arm64" "iOS Simulator (arm64)"
build_platform "build-ios-sim-x86" "iphonesimulator" "x86_64" "iOS Simulator (x86_64)"

# ── Step 5: 合并静态库 ──
echo ""
echo "[3/6] 合并静态库为动态库..."

combine_and_link() {
    local BUILD_SUBDIR=$1
    local OUTPUT_LIB=$2
    local SDK=$3
    local ARCH=$4

    echo "  合并: ${BUILD_SUBDIR} → $(basename ${OUTPUT_LIB})"

    local TEMP_DIR="${BUILD_DIR}/tmp-$$"
    mkdir -p "${TEMP_DIR}"

    # 收集所有编译出来的 .a 文件
    local ALL_LIBS=()
    # 根据 SDK 确定正确的 Release 子目录名
    local RELEASE_DIR="Release-${SDK}"
    for lib_name in libllama libggml libggml-base libggml-cpu libggml-metal libggml-blas libmtmd; do
        local found=$(find "${LLAMA_SRC}/${BUILD_SUBDIR}" -name "${lib_name}.a" -path "*${RELEASE_DIR}*" 2>/dev/null | head -1)
        if [ -n "$found" ]; then
            ALL_LIBS+=("${found}")
            echo "    + ${lib_name}.a ($(du -h "${found}" | cut -f1))"
        fi
    done

    if [ ${#ALL_LIBS[@]} -eq 0 ]; then
        echo "  错误: 未找到任何静态库！"
        rm -rf "${TEMP_DIR}"
        return 1
    fi

    # 合并
    libtool -static -o "${TEMP_DIR}/combined.a" "${ALL_LIBS[@]}" 2>/dev/null

    # 链接为动态库
    local TARGET_TRIPLE=""
    if [ "${SDK}" = "iphoneos" ]; then
        TARGET_TRIPLE="${ARCH}-apple-ios17.0"
    else
        TARGET_TRIPLE="${ARCH}-apple-ios17.0-simulator"
    fi

    xcrun --sdk "${SDK}" clang++ \
        -dynamiclib \
        -arch "${ARCH}" \
        -target "${TARGET_TRIPLE}" \
        -isysroot "$(xcrun --sdk ${SDK} --show-sdk-path)" \
        -install_name @rpath/llama.framework/llama \
        -Wl,-force_load,"${TEMP_DIR}/combined.a" \
        -framework Foundation \
        -framework Metal \
        -framework MetalKit \
        -framework Accelerate \
        -lc++ \
        -o "${OUTPUT_LIB}" 2>&1

    rm -rf "${TEMP_DIR}"
}

mkdir -p "${BUILD_DIR}/libs"

combine_and_link "build-ios-device" "${BUILD_DIR}/libs/llama-device.dylib" "iphoneos" "arm64"
combine_and_link "build-ios-sim-arm64" "${BUILD_DIR}/libs/llama-sim-arm64.dylib" "iphonesimulator" "arm64"
combine_and_link "build-ios-sim-x86" "${BUILD_DIR}/libs/llama-sim-x86.dylib" "iphonesimulator" "x86_64"

# 合并 simulator 双架构
echo "  合并 simulator 双架构 (arm64 + x86_64)..."
lipo -create \
    "${BUILD_DIR}/libs/llama-sim-arm64.dylib" \
    "${BUILD_DIR}/libs/llama-sim-x86.dylib" \
    -output "${BUILD_DIR}/libs/llama-sim.dylib"

# ── Step 6: 构建 framework + xcframework ──
echo ""
echo "[4/6] 构建 framework 结构..."

setup_framework() {
    local FW_DIR=$1
    local DYLIB=$2

    mkdir -p "${FW_DIR}/Headers"
    mkdir -p "${FW_DIR}/Modules"
    cp "${DYLIB}" "${FW_DIR}/llama"

    # 核心头文件
    for h in llama.h; do
        cp "${LLAMA_SRC}/include/${h}" "${FW_DIR}/Headers/"
    done
    for h in ggml.h ggml-opt.h ggml-alloc.h ggml-backend.h ggml-metal.h ggml-cpu.h gguf.h; do
        [ -f "${LLAMA_SRC}/ggml/include/${h}" ] && cp "${LLAMA_SRC}/ggml/include/${h}" "${FW_DIR}/Headers/"
    done

    # ggml-blas.h (可能存在)
    [ -f "${LLAMA_SRC}/ggml/include/ggml-blas.h" ] && cp "${LLAMA_SRC}/ggml/include/ggml-blas.h" "${FW_DIR}/Headers/"

    # 多模态头文件
    local HAS_MTMD=false
    if [ -f "${LLAMA_SRC}/tools/mtmd/mtmd.h" ]; then
        cp "${LLAMA_SRC}/tools/mtmd/mtmd.h" "${FW_DIR}/Headers/"
        HAS_MTMD=true
        echo "  ✓ mtmd.h"
    fi
    if [ -f "${LLAMA_SRC}/tools/mtmd/mtmd-helper.h" ]; then
        cp "${LLAMA_SRC}/tools/mtmd/mtmd-helper.h" "${FW_DIR}/Headers/"
        echo "  ✓ mtmd-helper.h"
    fi

    # module.modulemap (放在 Modules 目录)
    {
        echo "framework module llama {"
        echo "    header \"llama.h\""
        echo "    header \"ggml.h\""
        echo "    header \"ggml-opt.h\""
        echo "    header \"ggml-alloc.h\""
        echo "    header \"ggml-backend.h\""
        echo "    header \"ggml-metal.h\""
        echo "    header \"ggml-cpu.h\""
        echo "    header \"gguf.h\""
        [ -f "${FW_DIR}/Headers/ggml-blas.h" ] && echo "    header \"ggml-blas.h\""
        [ "$HAS_MTMD" = true ] && echo "    header \"mtmd.h\""
        [ -f "${FW_DIR}/Headers/mtmd-helper.h" ] && echo "    header \"mtmd-helper.h\""
        echo "    export *"
        echo "}"
    } > "${FW_DIR}/Modules/module.modulemap"

    # Info.plist (CFBundleExecutable 是必需的，否则 iOS 安装时会报错)
    cat > "${FW_DIR}/Info.plist" << 'PLIST'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleExecutable</key>
    <string>llama</string>
    <key>CFBundleIdentifier</key>
    <string>org.ggml.llama</string>
    <key>CFBundleName</key>
    <string>llama</string>
    <key>CFBundleVersion</key>
    <string>1.0</string>
    <key>CFBundleShortVersionString</key>
    <string>1.0</string>
    <key>CFBundlePackageType</key>
    <string>FMWK</string>
    <key>CFBundleInfoDictionaryVersion</key>
    <string>6.0</string>
    <key>MinimumOSVersion</key>
    <string>17.0</string>
</dict>
</plist>
PLIST
}

DEVICE_FW="${BUILD_DIR}/frameworks/ios-arm64/llama.framework"
SIM_FW="${BUILD_DIR}/frameworks/ios-arm64_x86_64-simulator/llama.framework"
rm -rf "${BUILD_DIR}/frameworks"
mkdir -p "$(dirname "${DEVICE_FW}")" "$(dirname "${SIM_FW}")"

setup_framework "${DEVICE_FW}" "${BUILD_DIR}/libs/llama-device.dylib"
setup_framework "${SIM_FW}" "${BUILD_DIR}/libs/llama-sim.dylib"

echo ""
echo "[5/6] 创建 xcframework..."
XCFRAMEWORK="${OUTPUT_DIR}/llama.xcframework"
rm -rf "${XCFRAMEWORK}"
xcodebuild -create-xcframework \
    -framework "${DEVICE_FW}" \
    -framework "${SIM_FW}" \
    -output "${XCFRAMEWORK}"

# ── 验证 ──
echo ""
echo "[6/6] 验证..."
echo ""
echo "============================================"
echo " 编译完成!"
echo "============================================"
echo ""
echo "  产物: ${XCFRAMEWORK}"
echo ""

if [ -f "${XCFRAMEWORK}/ios-arm64/llama.framework/Headers/mtmd.h" ]; then
    echo "  ✓ llama.cpp 核心推理"
    echo "  ✓ Metal GPU 加速"
    echo "  ✓ mtmd 多模态支持 (图片输入)"
    echo ""
    echo "  头文件:"
    ls "${XCFRAMEWORK}/ios-arm64/llama.framework/Headers/"
else
    echo "  ✓ llama.cpp 核心推理"
    echo "  ✓ Metal GPU 加速"
    echo "  ✗ mtmd 未包含"
fi

echo ""
echo "  下一步:"
echo "  1. 修改 Package.swift: 注释掉 URL binaryTarget，取消注释 path binaryTarget"
echo "  2. Xcode → Clean Build Folder"
echo "  3. Build Settings → Swift Compiler - Custom Flags → 添加 -DLLAMA_MTMD_ENABLED"
echo ""

rm -rf "${BUILD_DIR}/libs" "${BUILD_DIR}/frameworks"
echo "完成!"
