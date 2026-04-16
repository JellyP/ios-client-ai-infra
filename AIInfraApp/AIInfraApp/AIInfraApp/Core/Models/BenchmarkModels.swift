import Foundation

// MARK: - Benchmark 数据模型

/// Benchmark 测试用例
struct BenchmarkTestCase: Identifiable, Codable {
    let id: UUID
    let name: String
    let category: BenchmarkCategory
    let prompt: String
    let expectedMinQuality: Int

    init(id: UUID = UUID(), name: String, category: BenchmarkCategory, prompt: String, expectedMinQuality: Int = 0) {
        self.id = id
        self.name = name
        self.category = category
        self.prompt = prompt
        self.expectedMinQuality = expectedMinQuality
    }
}

/// Benchmark 分类
enum BenchmarkCategory: String, Codable, CaseIterable {
    case simple = "简单任务"
    case medium = "中等任务"
    case hard = "困难任务"
    case longContext = "长上下文"
    case chinese = "中文能力"
    case code = "代码能力"
    case math = "数学推理"
}

/// Benchmark 结果
struct BenchmarkResult: Identifiable, Codable {
    let id: UUID
    let testCaseId: UUID
    let testCaseName: String
    let modelName: String
    let providerType: AIModelProviderType
    let architectureType: ModelArchitectureType
    let metrics: GenerationMetrics
    let response: String
    let timestamp: Date

    init(
        id: UUID = UUID(),
        testCaseId: UUID,
        testCaseName: String,
        modelName: String,
        providerType: AIModelProviderType,
        architectureType: ModelArchitectureType,
        metrics: GenerationMetrics,
        response: String
    ) {
        self.id = id
        self.testCaseId = testCaseId
        self.testCaseName = testCaseName
        self.modelName = modelName
        self.providerType = providerType
        self.architectureType = architectureType
        self.metrics = metrics
        self.response = response
        self.timestamp = Date()
    }
}

/// Benchmark 对比报告
struct BenchmarkComparison {
    let testCase: BenchmarkTestCase
    let results: [BenchmarkResult]

    /// 按首 token 延迟排序
    var sortedByTTFT: [BenchmarkResult] {
        results.sorted { $0.metrics.timeToFirstToken < $1.metrics.timeToFirstToken }
    }

    /// 按生成速度排序
    var sortedByTPS: [BenchmarkResult] {
        results.sorted { $0.metrics.decodeTokensPerSecond > $1.metrics.decodeTokensPerSecond }
    }

    /// 按内存占用排序
    var sortedByMemory: [BenchmarkResult] {
        results.sorted { $0.metrics.peakMemoryUsage < $1.metrics.peakMemoryUsage }
    }
}

// MARK: - 预定义测试集

extension BenchmarkTestCase {
    /// 标准测试集
    static let standardTestSuite: [BenchmarkTestCase] = [
        // 简单任务
        BenchmarkTestCase(
            name: "基础问答",
            category: .simple,
            prompt: "1+1等于几？请直接回答数字。"
        ),
        BenchmarkTestCase(
            name: "简单翻译",
            category: .simple,
            prompt: "将以下英文翻译成中文：Hello, how are you today?"
        ),
        BenchmarkTestCase(
            name: "一句话介绍",
            category: .simple,
            prompt: "用一句话介绍什么是iOS开发。"
        ),

        // 中等任务
        BenchmarkTestCase(
            name: "代码生成",
            category: .medium,
            prompt: "用Swift写一个冒泡排序函数，对整数数组进行排序。只需要写函数代码。"
        ),
        BenchmarkTestCase(
            name: "概念解释",
            category: .medium,
            prompt: "用简单易懂的语言解释什么是ARC（自动引用计数），100字以内。"
        ),
        BenchmarkTestCase(
            name: "文本摘要",
            category: .medium,
            prompt: """
            请用3句话总结以下内容：
            SwiftUI是Apple推出的声明式UI框架，它使用Swift语言的力量，\
            提供了一种在所有Apple平台上构建用户界面的全新方式。\
            SwiftUI具有声明式语法，开发者只需描述界面应该呈现的样子和行为，\
            框架会自动处理布局和更新。它与Xcode深度集成，支持实时预览，\
            大大提升了开发效率。SwiftUI还内置了对动画、手势、辅助功能的支持。
            """
        ),

        // 困难任务
        BenchmarkTestCase(
            name: "架构设计",
            category: .hard,
            prompt: "设计一个iOS App的MVVM架构方案，包含网络层、数据持久层和UI层的职责划分，用200字描述。"
        ),

        // 中文能力
        BenchmarkTestCase(
            name: "中文理解",
            category: .chinese,
            prompt: "解释成语\"画蛇添足\"的含义，并举一个软件开发中的例子。"
        ),

        // 代码能力
        BenchmarkTestCase(
            name: "Swift代码",
            category: .code,
            prompt: "用Swift写一个简单的链表数据结构，包含插入和遍历方法。"
        ),

        // 数学推理
        BenchmarkTestCase(
            name: "简单推理",
            category: .math,
            prompt: "小明有5个苹果，给了小红2个，又买了3个。请问小明现在有几个苹果？请一步步推理。"
        ),
    ]
}
