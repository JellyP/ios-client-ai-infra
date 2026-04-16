import SwiftUI

// MARK: - 学习中心界面

/// 科普学习入口，引导开发者循序渐进地了解端侧 AI
struct LearnView: View {

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 16) {
                    headerSection

                    ForEach(learningModules) { module in
                        NavigationLink {
                            LearnDetailView(module: module)
                        } label: {
                            moduleCard(module)
                        }
                        .buttonStyle(.plain)
                    }

                    quickReferenceSection
                }
                .padding()
            }
            .navigationTitle("学习中心")
            .navigationBarTitleDisplayMode(.large)
        }
    }

    // MARK: - Header

    private var headerSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("从零开始理解端侧 AI")
                .font(.title2.weight(.bold))
            Text("专为 iOS 开发者设计的 AI 学习路线，用你熟悉的概念来理解大模型。")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.bottom, 8)
    }

    // MARK: - 模块卡片

    private func moduleCard(_ module: LearningModule) -> some View {
        HStack(spacing: 16) {
            ZStack {
                RoundedRectangle(cornerRadius: 12)
                    .fill(module.color.opacity(0.15))
                    .frame(width: 56, height: 56)
                Image(systemName: module.icon)
                    .font(.title2)
                    .foregroundStyle(module.color)
            }

            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text("第\(module.order)章")
                        .font(.caption2.weight(.medium))
                        .foregroundStyle(module.color)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(module.color.opacity(0.1))
                        .clipShape(Capsule())

                    if module.difficulty == .beginner {
                        Text("入门")
                            .font(.caption2)
                            .foregroundStyle(.green)
                    } else if module.difficulty == .intermediate {
                        Text("进阶")
                            .font(.caption2)
                            .foregroundStyle(.orange)
                    }
                }

                Text(module.title)
                    .font(.headline)
                    .foregroundStyle(.primary)

                Text(module.subtitle)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
            }

            Spacer()

            Image(systemName: "chevron.right")
                .font(.caption)
                .foregroundStyle(.tertiary)
        }
        .padding()
        .background(Color(.systemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .shadow(color: .black.opacity(0.05), radius: 8, y: 2)
    }

    // MARK: - 速查参考

    private var quickReferenceSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("速查参考")
                .font(.headline)
                .padding(.top, 8)

            VStack(spacing: 8) {
                referenceRow(
                    icon: "memorychip",
                    title: "模型大小估算",
                    detail: "1B 参数 ≈ 2GB (FP16) ≈ 0.5GB (Q4)"
                )
                referenceRow(
                    icon: "iphone",
                    title: "iPhone 建议",
                    detail: "8GB RAM → 最大运行 3B (Q4) 模型"
                )
                referenceRow(
                    icon: "speedometer",
                    title: "速度参考",
                    detail: "端侧 5-30 t/s | 远程 30-100 t/s"
                )
                referenceRow(
                    icon: "lock.shield",
                    title: "隐私优势",
                    detail: "端侧推理：数据不出设备"
                )
            }
        }
    }

    private func referenceRow(icon: String, title: String, detail: String) -> some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.body)
                .foregroundStyle(.blue)
                .frame(width: 28)
            VStack(alignment: .leading) {
                Text(title)
                    .font(.subheadline.weight(.medium))
                Text(detail)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer()
        }
        .padding(12)
        .background(Color(.systemGray6))
        .clipShape(RoundedRectangle(cornerRadius: 10))
    }
}

// MARK: - 学习模块数据

struct LearningModule: Identifiable {
    let id = UUID()
    let order: Int
    let title: String
    let subtitle: String
    let icon: String
    let color: Color
    let difficulty: Difficulty
    let content: String

    enum Difficulty {
        case beginner, intermediate, advanced
    }
}

let learningModules: [LearningModule] = [
    LearningModule(
        order: 1,
        title: "AI 基础入门",
        subtitle: "什么是大模型？用 iOS 开发者的视角理解 AI",
        icon: "brain.head.profile",
        color: .blue,
        difficulty: .beginner,
        content: """
        ## 用 iOS 开发者的视角理解大模型

        大模型本质上是一个超级复杂的映射函数：给定输入文本，输出最可能的下一个词。

        ### 关键概念
        - **模型 (Model)**: 类似 .mlmodel 文件，存储学到的知识
        - **参数 (Parameters)**: 模型中的数字，代表学到的知识
        - **推理 (Inference)**: 给模型输入让它产生输出
        - **Token**: 文本处理的最小单位
        - **量化 (Quantization)**: 类似图片压缩，缩小模型体积

        ### iPhone 内存限制
        - iPhone 15 Pro: 8GB RAM → 可运行 1-3B 量化模型
        - 端侧模型的关键限制是内存，不是算力
        """
    ),
    LearningModule(
        order: 2,
        title: "模型分类",
        subtitle: "外部模型 vs 端侧模型，各有什么优劣？",
        icon: "arrow.triangle.branch",
        color: .purple,
        difficulty: .beginner,
        content: """
        ## 外部模型 vs 端侧模型

        ### 外部模型 (Remote)
        通过 API 调用云端服务器上的大模型
        - ✅ 能力强，无设备限制
        - ❌ 需要网络，有成本，隐私风险

        ### 端侧模型 (On-Device)
        直接在 iPhone 上运行的小模型
        - ✅ 离线可用，隐私安全，低延迟
        - ❌ 能力有限，占用存储

        ### 混合方案（推荐）
        - 简单任务 → 端侧模型
        - 复杂任务 → 外部模型
        - 无网络时 → 端侧兜底
        """
    ),
    LearningModule(
        order: 3,
        title: "纯文本模型 (Dense)",
        subtitle: "理解最基础的 Transformer 架构",
        icon: "text.alignleft",
        color: .green,
        difficulty: .intermediate,
        content: """
        ## Dense Model

        Dense 模型是最基础的模型架构，每次推理所有参数都参与计算。

        ### Transformer 数据流
        1. **Tokenize** - 文本分词
        2. **Embedding** - 向量化
        3. **Transformer Layers** - 多层处理（Self-Attention + FFN）
        4. **Output** - 输出下一个 token 的概率

        ### 端侧推荐模型
        - Qwen2.5-1.5B: 中文最好
        - Llama 3.2 1B: 最轻量
        - Gemma 2 2B: 均衡之选
        """
    ),
    LearningModule(
        order: 4,
        title: "MoE 混合专家模型",
        subtitle: "如何用更少的计算获得更强的能力？",
        icon: "person.3.fill",
        color: .orange,
        difficulty: .intermediate,
        content: """
        ## MoE (Mixture of Experts)

        MoE 的核心思想：虽然有很多参数，但每次只用其中一部分！

        ### 类比
        Dense = 每次初始化所有 1000 个子视图
        MoE = UICollectionView 只加载可见的 Cell

        ### 关键组件
        - **Router**: 决定每个 token 用哪些专家
        - **Experts**: 多个并行的 FFN
        - **Top-K**: 每次只激活 K 个专家

        ### 端侧挑战
        MoE 虽然计算量小，但需要加载所有专家到内存，
        这是在 iPhone 上的最大障碍。
        """
    ),
    LearningModule(
        order: 5,
        title: "端侧部署实战",
        subtitle: "从下载模型到在 iPhone 上运行的完整流程",
        icon: "hammer.fill",
        color: .red,
        difficulty: .advanced,
        content: """
        ## 部署实战

        ### 方案选择
        1. **llama.cpp** - 推荐入门，支持广泛
        2. **CoreML** - Apple 原生，性能好
        3. **MLX** - Apple Silicon 优化

        ### 步骤
        1. 选择合适大小的模型
        2. 获取 GGUF 格式的量化版本
        3. 集成 llama.cpp 到 iOS 项目
        4. 实现加载、推理、流式输出
        5. 性能优化和监控

        ### 关键优化
        - 使用 mmap 内存映射
        - 控制上下文长度
        - Metal GPU 加速
        - 热状态监控
        """
    ),
]

// MARK: - 学习详情页

struct LearnDetailView: View {
    let module: LearningModule

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                // 头部
                HStack {
                    Text("第\(module.order)章")
                        .font(.caption.weight(.bold))
                        .foregroundStyle(module.color)
                    Text(difficultyText)
                        .font(.caption)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(difficultyColor.opacity(0.15))
                        .foregroundStyle(difficultyColor)
                        .clipShape(Capsule())
                }

                Text(module.title)
                    .font(.largeTitle.weight(.bold))

                Text(module.subtitle)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)

                Divider()

                // 内容
                Text(module.content)
                    .font(.body)
                    .lineSpacing(6)
            }
            .padding()
        }
        .navigationBarTitleDisplayMode(.inline)
    }

    private var difficultyText: String {
        switch module.difficulty {
        case .beginner: return "入门"
        case .intermediate: return "进阶"
        case .advanced: return "高级"
        }
    }

    private var difficultyColor: Color {
        switch module.difficulty {
        case .beginner: return .green
        case .intermediate: return .orange
        case .advanced: return .red
        }
    }
}

#Preview {
    LearnView()
}
