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
            descriptionEN: "Ultra-lightweight, great for getting started. Good Chinese capability, suitable for simple chat and text classification.",
            tags: [.chinese, .lightweight, .recommended],
            architectureType: .dense,
            supportedLanguages: ["zh", "en"],
            supportsImageClassification: false,  // 0.5B 太小，分类能力不足
            mmprojDownloadURL: nil,
            mmprojFileSize: nil
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
            descriptionEN: "Best small model for Chinese. Excellent at daily conversation, translation, and summarization. Top recommendation.",
            tags: [.chinese, .recommended, .bestValue, .imageClassification],
            architectureType: .dense,
            supportedLanguages: ["zh", "en"],
            supportsImageClassification: true,  // 1.5B 指令遵循强，支持分类
            mmprojDownloadURL: nil,
            mmprojFileSize: nil
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
            descriptionEN: "Strongest on-device Qwen model. Outstanding Chinese comprehension and generation. Requires iPhone 15 Pro+.",
            tags: [.chinese, .powerful, .imageClassification],
            architectureType: .dense,
            supportedLanguages: ["zh", "en"],
            supportsImageClassification: true,  // 3B 能力强，支持分类
            mmprojDownloadURL: nil,
            mmprojFileSize: nil
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
            descriptionEN: "By Meta. Lightest Llama model. Strong English, limited Chinese.",
            tags: [.lightweight, .english],
            architectureType: .dense,
            supportedLanguages: ["en", "zh"],
            supportsImageClassification: false,  // 1B 分类能力有限
            mmprojDownloadURL: nil,
            mmprojFileSize: nil
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
            descriptionEN: "Llama's on-device flagship. Well-balanced overall capability. Requires iPhone 15 Pro+.",
            tags: [.powerful, .english, .imageClassification],
            architectureType: .dense,
            supportedLanguages: ["en", "zh"],
            supportsImageClassification: true,  // 3B 能力强，支持分类
            mmprojDownloadURL: nil,
            mmprojFileSize: nil
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
            descriptionEN: "By Google. High-quality training data, a balanced choice.",
            tags: [.recommended, .english, .imageClassification],
            architectureType: .dense,
            supportedLanguages: ["en", "zh"],
            supportsImageClassification: true,  // 2B 训练质量高，支持分类
            mmprojDownloadURL: nil,
            mmprojFileSize: nil
        ),

        // ── Gemma 4 系列（Google 最新，支持思考链推理）──
        DownloadableModel(
            id: "gemma-4-e2b-q4",
            displayName: "Gemma 4 E2B",
            family: "Gemma",
            parameterCount: "2.3B",
            quantization: "Q4_K_M",
            fileSizeBytes: 3_110_000_000,
            contextLength: 4096,
            downloadURL: "https://huggingface.co/unsloth/gemma-4-E2B-it-GGUF/resolve/main/gemma-4-E2B-it-Q4_K_M.gguf",
            description: "Google 最新 Gemma 4 系列，内置思考链推理，多语言支持 140+。需要 iPhone 15 Pro+。",
            descriptionEN: "Google's latest Gemma 4 with built-in chain-of-thought reasoning. Supports 140+ languages. Requires iPhone 15 Pro+.",
            tags: [.recommended, .reasoning, .chinese, .imageClassification],
            architectureType: .dense,
            supportedLanguages: ["en", "zh", "ja", "ko", "fr", "de"],
            supportsImageClassification: true,  // 2.3B + 思考链，分类能力强
            mmprojDownloadURL: nil,
            mmprojFileSize: nil
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
            descriptionEN: "By Microsoft. Best reasoning and code capability in its class. 4K context.",
            tags: [.powerful, .code, .reasoning, .imageClassification],
            architectureType: .dense,
            supportedLanguages: ["en", "zh"],
            supportsImageClassification: true,  // 3.8B 推理强，支持分类
            mmprojDownloadURL: nil,
            mmprojFileSize: nil
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
            descriptionEN: "Extremely lightweight (360M params). Runs on almost any iPhone. Great for experiencing on-device inference.",
            tags: [.lightweight, .english, .recommended],
            architectureType: .dense,
            supportedLanguages: ["en"],
            supportsImageClassification: false,  // 360M 太小，分类能力不足
            mmprojDownloadURL: nil,
            mmprojFileSize: nil
        ),

        // ── 多模态模型（支持图片输入）──
        // 需要自编译含 mtmd 的 xcframework 才能使用多模态功能
        // 运行 ./scripts/build-llama-xcframework.sh 编译

        DownloadableModel(
            id: "smolvlm-500m-q8",
            displayName: "SmolVLM 500M (Vision)",
            family: "SmolVLM",
            parameterCount: "500M",
            quantization: "Q8_0",
            fileSizeBytes: 437_000_000,
            contextLength: 4096,
            downloadURL: "https://huggingface.co/ggml-org/SmolVLM-500M-Instruct-GGUF/resolve/main/SmolVLM-500M-Instruct-Q8_0.gguf",
            description: "HuggingFace 出品的超轻量多模态模型，支持图片输入。适合端侧图片分类和描述。需要同时下载 mmproj 文件。",
            descriptionEN: "Ultra-lightweight multimodal model by HuggingFace. Supports image input for on-device image classification and captioning. Requires mmproj file.",
            tags: [.lightweight, .imageClassification],
            architectureType: .dense,
            supportedLanguages: ["en"],
            supportsImageClassification: true,
            mmprojDownloadURL: "https://huggingface.co/ggml-org/SmolVLM-500M-Instruct-GGUF/resolve/main/mmproj-SmolVLM-500M-Instruct-Q8_0.gguf",
            mmprojFileSize: 109_000_000
        ),
        DownloadableModel(
            id: "internvl3-1b-q8",
            displayName: "InternVL3 1B (Vision)",
            family: "InternVL",
            parameterCount: "1B",
            quantization: "Q8_0",
            fileSizeBytes: 675_000_000,
            contextLength: 4096,
            downloadURL: "https://huggingface.co/ggml-org/InternVL3-1B-Instruct-GGUF/resolve/main/InternVL3-1B-Instruct-Q8_0.gguf",
            description: "上海 AI Lab 出品的多模态模型，1B 参数即可理解图片内容。中英文均支持。需要同时下载 mmproj 文件。",
            descriptionEN: "Multimodal model by Shanghai AI Lab. 1B params with image understanding. Supports Chinese and English. Requires mmproj file.",
            tags: [.chinese, .imageClassification],
            architectureType: .dense,
            supportedLanguages: ["zh", "en"],
            supportsImageClassification: true,
            mmprojDownloadURL: "https://huggingface.co/ggml-org/InternVL3-1B-Instruct-GGUF/resolve/main/mmproj-InternVL3-1B-Instruct-Q8_0.gguf",
            mmprojFileSize: 333_000_000
        ),
        DownloadableModel(
            id: "gemma4-e2b-vision-q4",
            displayName: "Gemma 4 E2B (Vision)",
            family: "Gemma",
            parameterCount: "2.3B",
            quantization: "Q4_K_M",
            fileSizeBytes: 3_110_000_000,
            contextLength: 2048,
            downloadURL: "https://huggingface.co/unsloth/gemma-4-E2B-it-GGUF/resolve/main/gemma-4-E2B-it-Q4_K_M.gguf",
            description: "Google Gemma 4 多模态版本(Q4量化)，支持图片输入。需要 iPhone 15 Pro+（8GB RAM），建议关闭其他 App 后使用。",
            descriptionEN: "Google Gemma 4 multimodal (Q4 quantized) with image input. Requires iPhone 15 Pro+ (8GB RAM). Close other apps before use.",
            tags: [.reasoning, .imageClassification],
            architectureType: .dense,
            supportedLanguages: ["en", "zh", "ja", "ko", "fr", "de"],
            supportsImageClassification: true,
            mmprojDownloadURL: "https://huggingface.co/ggml-org/gemma-4-E2B-it-GGUF/resolve/main/mmproj-gemma-4-E2B-it-Q8_0.gguf",
            mmprojFileSize: 557_000_000
        ),

        // ── Qwen Vision 系列（中文多模态最佳）──
        DownloadableModel(
            id: "qwen2-vl-2b-q4",
            displayName: "Qwen2-VL 2B (Vision)",
            family: "Qwen",
            parameterCount: "2B",
            quantization: "Q4_K_M",
            fileSizeBytes: 986_000_000,
            contextLength: 4096,
            downloadURL: "https://huggingface.co/ggml-org/Qwen2-VL-2B-Instruct-GGUF/resolve/main/Qwen2-VL-2B-Instruct-Q4_K_M.gguf",
            description: "阿里千问视觉模型，2B 参数支持图片理解。中文图片分类最佳选择。",
            descriptionEN: "Alibaba Qwen Vision model, 2B params with image understanding. Best choice for Chinese image classification.",
            tags: [.chinese, .imageClassification, .recommended],
            architectureType: .dense,
            supportedLanguages: ["zh", "en"],
            supportsImageClassification: true,
            mmprojDownloadURL: "https://huggingface.co/ggml-org/Qwen2-VL-2B-Instruct-GGUF/resolve/main/mmproj-Qwen2-VL-2B-Instruct-Q8_0.gguf",
            mmprojFileSize: 710_000_000
        ),
        DownloadableModel(
            id: "qwen2.5-vl-3b-q4",
            displayName: "Qwen2.5-VL 3B (Vision)",
            family: "Qwen",
            parameterCount: "3B",
            quantization: "Q4_K_M",
            fileSizeBytes: 1_930_000_000,
            contextLength: 4096,
            downloadURL: "https://huggingface.co/ggml-org/Qwen2.5-VL-3B-Instruct-GGUF/resolve/main/Qwen2.5-VL-3B-Instruct-Q4_K_M.gguf",
            description: "千问最新视觉模型，3B 参数，图片理解能力更强。需要 iPhone 15 Pro+（8GB RAM）。",
            descriptionEN: "Latest Qwen Vision model, 3B params with stronger image understanding. Requires iPhone 15 Pro+ (8GB RAM).",
            tags: [.chinese, .powerful, .imageClassification],
            architectureType: .dense,
            supportedLanguages: ["zh", "en"],
            supportsImageClassification: true,
            mmprojDownloadURL: "https://huggingface.co/ggml-org/Qwen2.5-VL-3B-Instruct-GGUF/resolve/main/mmproj-Qwen2.5-VL-3B-Instruct-Q8_0.gguf",
            mmprojFileSize: 845_000_000
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
    let descriptionEN: String
    let tags: [ModelTag]
    let architectureType: ModelArchitectureType
    let supportedLanguages: [String]
    /// 是否支持图片分类测试（MoE 模型或 >= 1.5B 的强指令遵循模型）
    let supportsImageClassification: Bool
    /// 多模态投影文件下载 URL（nil 表示纯文本模型，无视觉能力）
    let mmprojDownloadURL: String?
    /// 多模态投影文件大小（bytes）
    let mmprojFileSize: Int64?

    /// 是否为多模态模型（有 mmproj 文件）
    var isMultimodal: Bool { mmprojDownloadURL != nil }

    /// mmproj 文件名
    var mmprojFileName: String? {
        guard let url = mmprojDownloadURL else { return nil }
        return URL(string: url)?.lastPathComponent
    }

    /// mmproj 的实际下载 URL（支持镜像）
    var effectiveMmprojDownloadURL: String? {
        guard let url = mmprojDownloadURL else { return nil }
        let mirror = APIKeyStore.downloadMirror
        switch mirror {
        case .huggingface:
            return url
        case .hfMirror:
            return url.replacingOccurrences(
                of: "https://huggingface.co",
                with: "https://hf-mirror.com"
            )
        }
    }

    /// 本地化描述
    @MainActor var localizedDescription: String {
        LanguageManager.shared.currentLanguage == .english ? descriptionEN : description
    }

    /// 格式化的文件大小
    var formattedSize: String {
        MemoryUtils.formatBytes(fileSizeBytes)
    }

    /// 模型文件名
    var fileName: String {
        URL(string: downloadURL)?.lastPathComponent ?? "\(id).gguf"
    }

    /// 根据当前镜像设置返回实际下载 URL
    var effectiveDownloadURL: String {
        let mirror = APIKeyStore.downloadMirror
        switch mirror {
        case .huggingface:
            return downloadURL
        case .hfMirror:
            return downloadURL.replacingOccurrences(
                of: "https://huggingface.co",
                with: "https://hf-mirror.com"
            )
        }
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
    case imageClassification = "图片分类"

    @MainActor var localizedName: String {
        switch self {
        case .recommended: return L10n.tagRecommended
        case .bestValue: return L10n.tagBestValue
        case .lightweight: return L10n.tagLightweight
        case .powerful: return L10n.tagPowerful
        case .chinese: return L10n.tagChinese
        case .english: return L10n.tagEnglish
        case .code: return L10n.tagCode
        case .reasoning: return L10n.tagReasoning
        case .imageClassification: return L10n.tagImageClassification
        }
    }
}
