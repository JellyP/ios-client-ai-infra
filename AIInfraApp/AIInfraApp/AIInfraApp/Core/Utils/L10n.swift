import Foundation

// MARK: - 多语言字符串

/// 集中管理所有 UI 字符串的中英文版本
@MainActor
enum L10n {
    private static var isEn: Bool { LanguageManager.shared.currentLanguage == .english }

    // MARK: - Tabs
    static var tabChat: String { isEn ? "Chat" : "对话" }
    static var tabBenchmark: String { isEn ? "Benchmark" : "测评" }
    static var tabModels: String { isEn ? "Models" : "模型" }
    static var tabLearn: String { isEn ? "Learn" : "学习" }

    // MARK: - ChatView
    static var chatTitle: String { isEn ? "AI Chat" : "AI 对话" }
    static var selectModel: String { isEn ? "Select Model" : "选择模型" }
    static var inputPlaceholder: String { isEn ? "Type a message..." : "输入消息..." }
    static var generating: String { isEn ? "Generating..." : "生成中..." }
    static var cancelled: String { isEn ? "Cancelled" : "已取消" }
    static var error: String { isEn ? "Error" : "错误" }
    static var selectModelStartChat: String { isEn ? "Select a model to start chatting" : "选择模型，开始对话" }
    static var compareHint: String { isEn ? "Compare response quality and speed across on-device models" : "你可以对比远程模型和端侧模型的回答质量与速度" }
    static var onDeviceModels: String { isEn ? "On-Device Models" : "端侧模型" }
    static var done: String { isEn ? "Done" : "完成" }
    static var close: String { isEn ? "Close" : "关闭" }
    static var downloaded: String { isEn ? "Downloaded" : "已下载" }
    static var notDownloaded: String { isEn ? "Not Downloaded" : "未下载" }
    static var viewReplyAndPrompt: String { isEn ? "View Reply & Prompt" : "查看回复与 Prompt" }
    static var newChat: String { isEn ? "New Chat" : "新对话" }
    static var conversation: String { isEn ? "Chat" : "对话" }
    static var messages: String { isEn ? " messages" : " 条消息" }
    static var noHistory: String { isEn ? "No chat history" : "暂无历史对话" }
    static var autoSaveHint: String { isEn ? "Conversations are saved automatically" : "对话结束后会自动保存" }
    static var chatHistory: String { isEn ? "Chat History" : "历史对话" }

    // MARK: - Metrics
    static var ttft: String { isEn ? "TTFT" : "首字延迟" }
    static var speed: String { isEn ? "Speed" : "生成速度" }
    static var totalTime: String { isEn ? "Total" : "总耗时" }
    static var genTokens: String { isEn ? "Tokens" : "生成Token" }
    static var memory: String { isEn ? "Memory" : "内存" }

    // MARK: - BenchmarkView
    static var benchmarkTitle: String { isEn ? "Benchmark" : "模型测评" }
    static var deviceInfo: String { isEn ? "Device Info" : "设备信息" }
    static var memoryLabel: String { isEn ? "Memory" : "内存" }
    static var usedLabel: String { isEn ? "Used" : "已用" }
    static var selectedModels: String { isEn ? "Selected models" : "已选模型" }
    static var selectedCases: String { isEn ? "Selected cases" : "已选用例" }
    static var selectModelsHeader: String { isEn ? "Select Models (tested in order)" : "选择对比模型（按选择顺序逐个测试）" }
    static var selectModelsFooter: String { isEn ? "Each model is unloaded after testing to avoid memory overflow." : "每个模型测完后会自动卸载再加载下一个，避免内存溢出。" }
    static var selectTestCases: String { isEn ? "Select Test Cases" : "选择测试用例" }
    static var selectAll: String { isEn ? "Select All" : "全选" }
    static var deselectAll: String { isEn ? "Deselect All" : "取消全选" }
    static var startBenchmark: String { isEn ? "Start Benchmark" : "开始测评" }
    static var testing: String { isEn ? "Testing..." : "测试中..." }
    static var overallComparison: String { isEn ? "Overall Comparison" : "综合对比" }
    static var perItemComparison: String { isEn ? "Per-Item Comparison" : "逐项对比" }
    static var detailedResults: String { isEn ? "Detailed Results" : "详细结果" }
    static var modelColumn: String { isEn ? "Model" : "模型" }
    static var speedColumn: String { isEn ? "Speed" : "速度" }
    static var ttftColumn: String { isEn ? "TTFT" : "首字" }
    static var totalColumn: String { isEn ? "Total" : "总耗时" }
    static var memoryColumn: String { isEn ? "Mem" : "内存" }
    static var qualityColumn: String { isEn ? "Quality" : "质量" }
    static var bestInDimension: String { isEn ? "= best in this dimension" : "= 该维度最优" }
    static var avgSpeed: String { isEn ? "Avg" : "平均" }
    static var avgTTFT: String { isEn ? "Avg TTFT" : "平均首字" }
    static var cases: String { isEn ? " cases" : " 个用例" }
    static var qualityLabel: String { isEn ? "Quality" : "质量" }
    static var score: String { isEn ? "pts" : "分" }
    static var loadingModel: String { isEn ? "Loading model..." : "正在加载模型..." }
    static var loadFailed: String { isEn ? "Load failed" : "加载失败" }
    static var unloadingModel: String { isEn ? "Unloading model..." : "正在卸载模型..." }
    static var benchmarkDone: String { isEn ? "Benchmark completed" : "测评完成" }

    // MARK: - BenchmarkResultDetail
    static var benchmarkDetail: String { isEn ? "Benchmark Detail" : "测评详情" }
    static var performanceMetrics: String { isEn ? "Performance Metrics" : "性能指标" }
    static var qualityScore: String { isEn ? "Quality Score" : "质量评分" }
    static var prompt: String { isEn ? "Prompt" : "Prompt" }
    static var modelReply: String { isEn ? "Model Reply" : "模型回复" }
    static var peakMemory: String { isEn ? "Peak Memory" : "峰值内存" }
    static var inputLength: String { isEn ? "Input Length" : "输入长度" }
    static var chars: String { isEn ? " chars" : " 字符" }

    // MARK: - QualityScore
    static var pass: String { isEn ? "Pass" : "通过" }
    static var partial: String { isEn ? "Partial" : "部分通过" }
    static var fail: String { isEn ? "Fail" : "未通过" }
    static var noRule: String { isEn ? "No Rule" : "无规则" }

    // MARK: - ModelListView
    static var modelLibrary: String { isEn ? "Model Library" : "模型库" }
    static var manage: String { isEn ? "Manage" : "管理" }
    static var modelStore: String { isEn ? "Model Store" : "模型商店" }
    static var modelStoreDesc: String { isEn ? "Browse and download GGUF models" : "浏览和下载 GGUF 模型到手机" }
    static var onDeviceHeader: String { isEn ? "On-Device Models" : "端侧模型" }
    static var onDeviceFooter: String { isEn ? "On-device models run locally without network. Download GGUF files from the Model Store first." : "端侧模型运行在设备本地，无需网络。需要先到「模型商店」下载 GGUF 模型文件。" }
    static var totalMemory: String { isEn ? "Total Memory" : "总内存" }
    static var usedMemory: String { isEn ? "Used" : "已使用" }
    static var runnableModels: String { isEn ? "Runnable Models" : "可运行模型" }
    static var limited: String { isEn ? "Limited" : "受限" }
    static var basicInfo: String { isEn ? "Basic Info" : "基本信息" }
    static var name: String { isEn ? "Name" : "名称" }
    static var architecture: String { isEn ? "Architecture" : "架构" }
    static var modelFamily: String { isEn ? "Family" : "模型家族" }
    static var paramCount: String { isEn ? "Parameters" : "参数量" }
    static var quantization: String { isEn ? "Quantization" : "量化" }
    static var contextLength: String { isEn ? "Context Length" : "上下文长度" }
    static var storageInfo: String { isEn ? "Storage" : "存储信息" }
    static var modelSize: String { isEn ? "Model Size" : "模型大小" }
    static var languages: String { isEn ? "Languages" : "支持语言" }
    static var summary: String { isEn ? "Summary" : "简介" }

    // MARK: - ModelDownloadStoreView
    static var downloadSource: String { isEn ? "Download Source" : "下载源" }
    static var downloadedModels: String { isEn ? "Downloaded Models" : "已下载模型" }
    static var storageUsed: String { isEn ? "Storage Used" : "占用空间" }
    static var storageNote: String { isEn ? "Model files are stored in app's local storage. Uninstalling the app will delete them." : "模型文件下载到 App 本地存储，卸载 App 会同时删除。" }
    static var recommendedFirst: String { isEn ? "Recommended First Download" : "推荐首次下载" }
    static var allModelsBySize: String { isEn ? "All Models (by size)" : "所有模型（按大小排序）" }
    static var downloading: String { isEn ? "Downloading" : "下载中" }
    static var paused: String { isEn ? "Paused" : "已暂停" }
    static var pauseBtn: String { isEn ? "Pause" : "暂停" }
    static var resumeBtn: String { isEn ? "Resume" : "继续" }
    static var cancelBtn: String { isEn ? "Cancel" : "取消" }
    static var deleteBtn: String { isEn ? "Delete" : "删除" }
    static var retryBtn: String { isEn ? "Retry" : "重试" }
    static var downloadFailed: String { isEn ? "Download failed" : "下载失败" }
    static func downloadBtn(_ size: String) -> String { isEn ? "Download (\(size))" : "下载 (\(size))" }

    // MARK: - LearnView
    static var learnTitle: String { isEn ? "Learn" : "学习中心" }
    static var learnHeader: String { isEn ? "Understanding On-Device AI from Scratch" : "从零开始理解端侧 AI" }
    static var learnSubheader: String { isEn ? "An AI learning path designed for iOS developers, explained with concepts you already know." : "专为 iOS 开发者设计的 AI 学习路线，用你熟悉的概念来理解大模型。" }
    static var quickReference: String { isEn ? "Quick Reference" : "速查参考" }
    static var modelSizeEst: String { isEn ? "Model Size Estimate" : "模型大小估算" }
    static var modelSizeDetail: String { isEn ? "1B params ≈ 2GB (FP16) ≈ 0.5GB (Q4)" : "1B 参数 ≈ 2GB (FP16) ≈ 0.5GB (Q4)" }
    static var iphoneAdvice: String { isEn ? "iPhone Advice" : "iPhone 建议" }
    static var iphoneAdviceDetail: String { isEn ? "8GB RAM → up to 3B (Q4) model" : "8GB RAM → 最大运行 3B (Q4) 模型" }
    static var speedRef: String { isEn ? "Speed Reference" : "速度参考" }
    static var speedRefDetail: String { isEn ? "On-device A17 Pro: 10-25 t/s (1-3B Q4)" : "端侧 A17 Pro: 10-25 t/s (1-3B Q4)" }
    static var privacyAdv: String { isEn ? "Privacy Advantage" : "隐私优势" }
    static var privacyAdvDetail: String { isEn ? "On-device inference: data never leaves the device" : "端侧推理：数据不出设备，零网络依赖" }
    static var powerRef: String { isEn ? "Power Reference" : "功耗参考" }
    static var powerRefDetail: String { isEn ? "1B model ~3-5W, 3B model ~6-8W continuous" : "1B 模型连续推理约 3-5W，3B 约 6-8W" }
    static var chapter: String { isEn ? "Ch." : "第" }
    static var chapterSuffix: String { isEn ? "" : "章" }
    static var beginner: String { isEn ? "Beginner" : "入门" }
    static var intermediate: String { isEn ? "Intermediate" : "进阶" }
    static var advanced: String { isEn ? "Advanced" : "高级" }
    static var languageSetting: String { isEn ? "Language" : "语言" }

    // MARK: - Download Mirror
    static var mirrorChina: String { isEn ? "China Mirror (hf-mirror.com)" : "国内镜像 (hf-mirror.com)" }
    static var mirrorOfficial: String { isEn ? "HuggingFace Official" : "HuggingFace 官方" }
    static var mirrorChinaDesc: String { isEn ? "Direct access in mainland China" : "中国大陆可直连，推荐" }
    static var mirrorOfficialDesc: String { isEn ? "Requires VPN in China" : "需要科学上网" }

    // MARK: - Thermal States
    static var thermalNominal: String { isEn ? "Normal" : "正常" }
    static var thermalFair: String { isEn ? "Warm" : "微热" }
    static var thermalSerious: String { isEn ? "Hot" : "较热" }
    static var thermalCritical: String { isEn ? "Critical" : "过热" }

    // MARK: - Model Provider
    static var onDeviceType: String { isEn ? "On-Device" : "端侧模型" }

    // MARK: - Errors
    static var modelNotDownloaded: String { isEn ? "Model not downloaded. Please download from the Model Store first." : "模型未下载，请到「模型商店」下载后使用" }
    static var modelLoadFailed: String { isEn ? "Failed to load model" : "模型加载失败" }
    static var modelNotLoaded: String { isEn ? "Model not loaded" : "模型未加载" }
    static var tokenizeFailed: String { isEn ? "Tokenization failed" : "文本分词失败" }
    static var samplerFailed: String { isEn ? "Sampler init failed" : "采样器初始化失败" }
    static var inferenceFailed: String { isEn ? "Inference failed" : "推理失败" }

    // MARK: - Model Tags
    static var tagRecommended: String { isEn ? "Recommended" : "推荐" }
    static var tagBestValue: String { isEn ? "Best Value" : "性价比" }
    static var tagLightweight: String { isEn ? "Lightweight" : "轻量" }
    static var tagPowerful: String { isEn ? "Powerful" : "强力" }
    static var tagChinese: String { isEn ? "Chinese" : "中文好" }
    static var tagEnglish: String { isEn ? "English" : "英文好" }
    static var tagCode: String { isEn ? "Code" : "代码" }
    static var tagReasoning: String { isEn ? "Reasoning" : "推理" }
    static var tagImageClassification: String { isEn ? "Image Classification" : "图片分类" }

    // MARK: - Benchmark Categories
    static var catIntent: String { isEn ? "Intent" : "意图识别" }
    static var catExtraction: String { isEn ? "Extraction" : "信息提取" }
    static var catSummary: String { isEn ? "Summary" : "文本摘要" }
    static var catTranslation: String { isEn ? "Translation" : "翻译" }
    static var catCode: String { isEn ? "Code" : "代码补全" }
    static var catSafety: String { isEn ? "Safety" : "安全边界" }
    static var catFormat: String { isEn ? "Format" : "格式遵循" }
    static var catReasoning: String { isEn ? "Reasoning" : "推理" }
    static var catLongCtx: String { isEn ? "Long Context" : "长文本" }
    static var catHallucination: String { isEn ? "Hallucination" : "幻觉测试" }
    static var catEdge: String { isEn ? "Edge Case" : "边界输入" }
    static var catMultiTurn: String { isEn ? "Multi-turn" : "多轮指令" }
    static var catImageClassification: String { isEn ? "Image Classification" : "图片分类" }

    // MARK: - Image Classification Benchmark
    static var imageClassificationHeader: String { isEn ? "Image Classification Test" : "图片分类测试" }
    static var imageClassificationFooter: String { isEn ? "500 text-described images across 10 CIFAR-10 categories. Tests model's ability to classify image descriptions." : "基于 CIFAR-10 的 10 个类别共 500 条图片文本描述，测试模型的图片描述分类能力。" }
    static var accuracy: String { isEn ? "Accuracy" : "准确率" }
    static var classificationSpeed: String { isEn ? "Speed" : "分类速度" }
    static var itemsPerSec: String { isEn ? "items/s" : "条/秒" }
    static var perCategoryAccuracy: String { isEn ? "Per-Category Accuracy" : "各类别准确率" }
    static var totalCases: String { isEn ? "Total" : "总计" }
    static var correct: String { isEn ? "Correct" : "正确" }
    static var incorrect: String { isEn ? "Incorrect" : "错误" }
    static var startImageClassification: String { isEn ? "Start Image Classification" : "开始图片分类测试" }
    static var imageClassifying: String { isEn ? "Classifying..." : "分类中..." }
    static var classificationResults: String { isEn ? "Classification Results" : "分类结果" }
    static var selectImageTestHint: String { isEn ? "Run 500 image description classification tasks" : "运行 500 条图片描述分类任务" }
    static var noEligibleModels: String { isEn ? "No models support image classification. Models ≥ 1.5B with MoE or strong instruction following are required." : "暂无支持图片分类的模型。需要 ≥ 1.5B 的 MoE 或强指令遵循模型。" }

    // MARK: - Real Image Dataset
    static var downloadTestImages: String { isEn ? "Download Test Images" : "下载测试图片" }
    static var downloadingImages: String { isEn ? "Downloading images..." : "正在下载图片..." }
    static var imagesDownloaded: String { isEn ? "images downloaded" : "张图片已下载" }
    static var testImagesReady: String { isEn ? "Test images ready" : "测试图片已就绪" }
    static var realImageTest: String { isEn ? "Real Image Test" : "真实图片测试" }
    static var realImageTestHint: String { isEn ? "Classify 500 real CIFAR-10 images with multimodal model" : "使用多模态模型识别 500 张 CIFAR-10 真实图片" }
    static var textDescriptionMode: String { isEn ? "Text Description Mode" : "文本描述模式" }
    static var realImageMode: String { isEn ? "Real Image Mode" : "真实图片模式" }
    static var deleteTestImages: String { isEn ? "Delete Test Images" : "删除测试图片" }
    static var needDownloadFirst: String { isEn ? "Please download test images first" : "请先下载测试图片" }
    static var needMultimodalModel: String { isEn ? "Requires multimodal model (with mmproj). Text models will use description mode." : "需要多模态模型（带 mmproj）。纯文本模型将使用文本描述模式。" }

    // MARK: - Image Chat
    static var imageAttached: String { isEn ? "[Image attached]" : "[已附带图片]" }
}
