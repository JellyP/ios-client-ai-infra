import Foundation

// MARK: - GGUF 模型注册表

/// 可供 App 内直接下载的 GGUF 模型目录
///
/// ## 什么是 GGUF？
///
/// GGUF (GPT-Generated Unified Format) 是 llama.cpp 项目定义的模型文件格式。
/// 用 iOS 类比：
/// - 原始模型 (PyTorch) = Xcode 工程源码（几十 GB）
/// - GGUF 文件 = 编译好的 .ipa（单文件、可直接运行）
///
/// GGUF 文件包含：
/// 1. 模型权重（量化后的参数）
/// 2. 分词器（Tokenizer）
/// 3. 模型配置（架构、上下文长度等）
/// 全部打包在一个 .gguf 文件里。
///
/// ## 量化级别说明
///
/// ```
/// Q2_K  → 2bit 量化, 最小但质量差     (不推荐)
/// Q3_K_M → 3bit 量化, 体积小          (勉强可用)
/// Q4_K_M → 4bit 量化, 最佳平衡点      (推荐 ✅)
/// Q5_K_M → 5bit 量化, 质量更好        (内存充足时用)
/// Q6_K  → 6bit 量化, 接近无损          (高端设备)
/// Q8_0  → 8bit 量化, 几乎无损          (iPad Pro)
/// F16   → 半精度, 无损                 (服务器用)
/// ```
struct GGUFModelCatalog {

    /// 所有可下载的模型
    static let allModels: [DownloadableModel] = [
        // ── Qwen 系列（中文最好）──
        DownloadableModel(
            id: "qwen2.5-0.5b-q4",
            displayName: "Qwen2.5 0.5B",
            family: "Qwen",
            parameterCount: "0.5B",
            quantization: "Q4_K_M",
            fileSizeBytes: 397_000_000,
            contextLength: 2048,
            downloadURL: "https://huggingface.co/Qwen/Qwen2.5-0.5B-Instruct-GGUF/resolve/main/qwen2.5-0.5b-instruct-q4_k_m.gguf",
            description: "超轻量，适合入门体验。中文能力不错，适合简单对话和文本分类。",
            tags: [.chinese, .lightweight, .recommended],
            architectureType: .dense,
            supportedLanguages: ["zh", "en"]
        ),
        DownloadableModel(
            id: "qwen2.5-1.5b-q4",
            displayName: "Qwen2.5 1.5B",
            family: "Qwen",
            parameterCount: "1.5B",
            quantization: "Q4_K_M",
            fileSizeBytes: 1_050_000_000,
            contextLength: 2048,
            downloadURL: "https://huggingface.co/Qwen/Qwen2.5-1.5B-Instruct-GGUF/resolve/main/qwen2.5-1.5b-instruct-q4_k_m.gguf",
            description: "中文能力最好的小模型，日常对话、翻译、摘要表现优秀。推荐首选。",
            tags: [.chinese, .recommended, .bestValue],
            architectureType: .dense,
            supportedLanguages: ["zh", "en"]
        ),
        DownloadableModel(
            id: "qwen2.5-3b-q4",
            displayName: "Qwen2.5 3B",
            family: "Qwen",
            parameterCount: "3B",
            quantization: "Q4_K_M",
            fileSizeBytes: 2_060_000_000,
            contextLength: 2048,
            downloadURL: "https://huggingface.co/Qwen/Qwen2.5-3B-Instruct-GGUF/resolve/main/qwen2.5-3b-instruct-q4_k_m.gguf",
            description: "Qwen 家族端侧最强，中文理解和生成能力出色。需要 iPhone 15 Pro+。",
            tags: [.chinese, .powerful],
            architectureType: .dense,
            supportedLanguages: ["zh", "en"]
        ),

        // ── Llama 系列（综合能力强）──
        DownloadableModel(
            id: "llama-3.2-1b-q4",
            displayName: "Llama 3.2 1B",
            family: "Llama",
            parameterCount: "1B",
            quantization: "Q4_K_M",
            fileSizeBytes: 750_000_000,
            contextLength: 2048,
            downloadURL: "https://huggingface.co/bartowski/Llama-3.2-1B-Instruct-GGUF/resolve/main/Llama-3.2-1B-Instruct-Q4_K_M.gguf",
            description: "Meta 出品，最轻量的 Llama 模型。英文能力好，中文一般。",
            tags: [.lightweight, .english],
            architectureType: .dense,
            supportedLanguages: ["en", "zh"]
        ),
        DownloadableModel(
            id: "llama-3.2-3b-q4",
            displayName: "Llama 3.2 3B",
            family: "Llama",
            parameterCount: "3B",
            quantization: "Q4_K_M",
            fileSizeBytes: 2_020_000_000,
            contextLength: 2048,
            downloadURL: "https://huggingface.co/bartowski/Llama-3.2-3B-Instruct-GGUF/resolve/main/Llama-3.2-3B-Instruct-Q4_K_M.gguf",
            description: "Llama 端侧旗舰，综合能力均衡。需要 iPhone 15 Pro+。",
            tags: [.powerful, .english],
            architectureType: .dense,
            supportedLanguages: ["en", "zh"]
        ),

        // ── Gemma 系列（Google 出品）──
        DownloadableModel(
            id: "gemma-2-2b-q4",
            displayName: "Gemma 2 2B",
            family: "Gemma",
            parameterCount: "2B",
            quantization: "Q4_K_M",
            fileSizeBytes: 1_570_000_000,
            contextLength: 2048,
            downloadURL: "https://huggingface.co/bartowski/gemma-2-2b-it-GGUF/resolve/main/gemma-2-2b-it-Q4_K_M.gguf",
            description: "Google 出品，训练数据质量高，均衡之选。",
            tags: [.recommended, .english],
            architectureType: .dense,
            supportedLanguages: ["en", "zh"]
        ),

        // ── Phi 系列（微软出品，推理能力强）──
        DownloadableModel(
            id: "phi-3.5-mini-q4",
            displayName: "Phi-3.5 Mini",
            family: "Phi",
            parameterCount: "3.8B",
            quantization: "Q4_K_M",
            fileSizeBytes: 2_320_000_000,
            contextLength: 4096,
            downloadURL: "https://huggingface.co/bartowski/Phi-3.5-mini-instruct-GGUF/resolve/main/Phi-3.5-mini-instruct-Q4_K_M.gguf",
            description: "微软出品，推理和代码能力在同级别中最强。上下文 4K。",
            tags: [.powerful, .code, .reasoning],
            architectureType: .dense,
            supportedLanguages: ["en", "zh"]
        ),

        // ── SmolLM 系列（HuggingFace 出品，超轻量）──
        DownloadableModel(
            id: "smollm2-360m-q8",
            displayName: "SmolLM2 360M",
            family: "SmolLM",
            parameterCount: "360M",
            quantization: "Q8_0",
            fileSizeBytes: 386_000_000,
            contextLength: 2048,
            downloadURL: "https://huggingface.co/HuggingFaceTB/SmolLM2-360M-Instruct-GGUF/resolve/main/smollm2-360m-instruct-q8_0.gguf",
            description: "极度轻量的模型（360M 参数），几乎所有 iPhone 都能跑。适合体验端侧推理的感觉。",
            tags: [.lightweight, .english, .recommended],
            architectureType: .dense,
            supportedLanguages: ["en"]
        ),
    ]

    /// 按标签筛选
    static func models(with tag: ModelTag) -> [DownloadableModel] {
        allModels.filter { $0.tags.contains(tag) }
    }

    /// 推荐首次下载的模型
    static var recommendedForFirstTime: [DownloadableModel] {
        allModels.filter { $0.tags.contains(.recommended) }
    }

    /// 按模型大小排序（小到大）
    static var sortedBySize: [DownloadableModel] {
        allModels.sorted { $0.fileSizeBytes < $1.fileSizeBytes }
    }
}

// MARK: - 可下载模型数据

/// 可下载的 GGUF 模型信息
struct DownloadableModel: Identifiable, Codable {
    let id: String
    let displayName: String
    let family: String
    let parameterCount: String
    let quantization: String
    let fileSizeBytes: Int64
    let contextLength: Int
    let downloadURL: String
    let description: String
    let tags: [ModelTag]
    let architectureType: ModelArchitectureType
    let supportedLanguages: [String]

    /// 格式化的文件大小
    var formattedSize: String {
        MemoryUtils.formatBytes(fileSizeBytes)
    }

    /// 模型文件名
    var fileName: String {
        URL(string: downloadURL)?.lastPathComponent ?? "\(id).gguf"
    }
}

/// 模型标签
enum ModelTag: String, Codable, CaseIterable {
    case recommended = "推荐"
    case bestValue = "性价比"
    case lightweight = "轻量"
    case powerful = "强力"
    case chinese = "中文好"
    case english = "英文好"
    case code = "代码"
    case reasoning = "推理"
}
