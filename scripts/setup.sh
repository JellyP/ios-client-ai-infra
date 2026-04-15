#!/bin/bash

# iOS Client AI Infra - 环境初始化脚本
# 用法: ./scripts/setup.sh

set -e

echo "=================================="
echo "  iOS Client AI Infra 环境初始化"
echo "=================================="

# 检查 Xcode
if ! command -v xcodebuild &> /dev/null; then
    echo "❌ 未检测到 Xcode，请先安装 Xcode 16+"
    exit 1
fi

XCODE_VERSION=$(xcodebuild -version | head -n 1)
echo "✅ $XCODE_VERSION"

# 检查 Swift
SWIFT_VERSION=$(swift --version 2>&1 | head -n 1)
echo "✅ $SWIFT_VERSION"

# 创建模型存储目录
MODEL_DIR="$HOME/Documents/AIInfraModels"
mkdir -p "$MODEL_DIR"
echo "✅ 模型存储目录: $MODEL_DIR"

# 检查是否安装了 huggingface-cli（可选）
if command -v huggingface-cli &> /dev/null; then
    echo "✅ huggingface-cli 已安装"
else
    echo "⚠️  huggingface-cli 未安装（可选，用于下载模型）"
    echo "   安装命令: pip install huggingface_hub"
fi

echo ""
echo "=================================="
echo "  初始化完成！"
echo "=================================="
echo ""
echo "下一步："
echo "1. 阅读文档: docs/01-ai-basics.md"
echo "2. 用 Xcode 打开项目（或使用 SPM）"
echo "3. 选择目标设备运行 Demo"
echo ""
echo "下载模型（可选）："
echo "  huggingface-cli download Qwen/Qwen2.5-1.5B-Instruct-GGUF \\"
echo "      qwen2.5-1.5b-instruct-q4_k_m.gguf \\"
echo "      --local-dir $MODEL_DIR"
