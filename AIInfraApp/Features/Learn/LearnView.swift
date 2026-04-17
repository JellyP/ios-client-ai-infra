import SwiftUI
import Textual

// MARK: - 学习中心界面

/// 科普学习入口，引导开发者循序渐进地了解端侧 AI
struct LearnView: View {
    @EnvironmentObject private var lang: LanguageManager

    private var modules: [LearningModule] {
        lang.currentLanguage == .english ? learningModulesEN : learningModules
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 16) {
                    headerSection

                    ForEach(modules) { module in
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
            .navigationTitle(L10n.learnTitle)
            .navigationBarTitleDisplayMode(.large)
        }
    }

    // MARK: - Header

    private var headerSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(L10n.learnHeader)
                .font(.title2.weight(.bold))
            Text(L10n.learnSubheader)
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
                    Text("\(L10n.chapter)\(module.order)\(L10n.chapterSuffix)")
                        .font(.caption2.weight(.medium))
                        .foregroundStyle(module.color)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(module.color.opacity(0.1))
                        .clipShape(Capsule())

                    Text(module.difficulty.label)
                        .font(.caption2)
                        .foregroundStyle(module.difficulty.color)
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
            Text(L10n.quickReference)
                .font(.headline)
                .padding(.top, 8)

            VStack(spacing: 8) {
                referenceRow(icon: "memorychip", title: L10n.modelSizeEst, detail: L10n.modelSizeDetail)
                referenceRow(icon: "iphone", title: L10n.iphoneAdvice, detail: L10n.iphoneAdviceDetail)
                referenceRow(icon: "speedometer", title: L10n.speedRef, detail: L10n.speedRefDetail)
                referenceRow(icon: "lock.shield", title: L10n.privacyAdv, detail: L10n.privacyAdvDetail)
                referenceRow(icon: "battery.75percent", title: L10n.powerRef, detail: L10n.powerRefDetail)
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

        var label: String {
            switch self {
            case .beginner: return "入门"
            case .intermediate: return "进阶"
            case .advanced: return "高级"
            }
        }

        var color: Color {
            switch self {
            case .beginner: return .green
            case .intermediate: return .orange
            case .advanced: return .red
            }
        }
    }
}

// MARK: - 学习详情页（Markdown 渲染）

struct LearnDetailView: View {
    let module: LearningModule

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                // 头部
                HStack {
                    Text("\(L10n.chapter)\(module.order)\(L10n.chapterSuffix)")
                        .font(.caption.weight(.bold))
                        .foregroundStyle(module.color)
                    Text(module.difficulty.label)
                        .font(.caption)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(module.difficulty.color.opacity(0.15))
                        .foregroundStyle(module.difficulty.color)
                        .clipShape(Capsule())
                }

                Text(module.title)
                    .font(.largeTitle.weight(.bold))

                Text(module.subtitle)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)

                Divider()

                // Markdown 渲染内容
                StructuredText(markdown: module.content, syntaxExtensions: [.math])
                    .textual.structuredTextStyle(.gitHub)
                    .textual.textSelection(.enabled)
            }
            .padding()
        }
        .navigationBarTitleDisplayMode(.inline)
    }
}

// MARK: - 课程内容

let learningModules: [LearningModule] = [

    // ── 第1章 ──
    LearningModule(
        order: 1,
        title: "AI 基础入门",
        subtitle: "什么是大模型？用 iOS 开发者的视角理解 AI",
        icon: "brain.head.profile",
        color: .blue,
        difficulty: .beginner,
        content: """
        ## 用 iOS 开发者的视角理解大模型

        大语言模型（Large Language Model, LLM）本质上是一个**超大规模的概率预测函数**：给定一段输入文本（prompt），计算每个可能的下一个词的概率，选择概率最高的那个输出。

        > 你可以把 LLM 想象成一个训练了数万亿文本的超级自动补全引擎。

        ### 核心概念对照表

        | AI 概念 | iOS 类比 | 详细说明 |
        |---------|---------|---------|
        | 模型 (Model) | `.mlmodel` / `.gguf` 文件 | 包含训练好的权重参数 |
        | 参数 (Parameters) | 模型内部的浮点数 | 1B = 10 亿个参数，每个参数是一个权重值 |
        | 推理 (Inference) | `model.predict(input)` | 将输入转换为输出的计算过程 |
        | 训练 (Training) | 不适用（端侧只做推理） | 通过海量数据调整参数的过程，需要大量 GPU |
        | Token | 文本处理的最小单位 | 不等于字/词，中文平均 1.5 token/字 |
        | 上下文窗口 (Context) | 模型一次能处理的最大长度 | 2048 tokens ≈ 约 1300 中文字 |
        | Embedding | `[Float]` 向量 | 将文本映射到高维空间的数字表示 |

        ### Token 深入理解

        Token 是模型处理文本的基本单位。不同模型使用不同的分词器（Tokenizer），分词结果不同：

        ```
        "Hello world"   → ["Hello", " world"]           → 2 tokens
        "你好世界"       → ["你好", "世界"]               → 2 tokens
        "iPhone 15 Pro" → ["i", "Phone", " 15", " Pro"] → 4 tokens
        "🎉"            → ["🎉"]                        → 1 token
        ```

        **为什么 token 不等于字？** 因为分词器基于 BPE（Byte Pair Encoding）算法，它将常见的字符组合合并为一个 token。英文中 "the" 是一个 token，而罕见词可能被拆成多个。

        **token 计费公式**：估算中文文本的 token 数：

        $$\\text{tokens} \\approx \\text{中文字数} \\times 1.5$$

        ### 模型参数量与内存关系

        模型的每个参数都是一个数字，需要占用内存存储：

        - **FP16（半精度浮点）**：每个参数 2 字节
        - **Q4（4-bit 量化）**：每个参数约 0.5 字节

        内存估算公式：

        $$\\text{内存(GB)} = \\frac{\\text{参数量(B)} \\times \\text{每参数字节数}}{1024^3}$$

        实际数值：

        | 模型大小 | FP16 内存 | Q8 内存 | Q4 内存 | 推荐设备 |
        |---------|----------|--------|--------|---------|
        | 0.5B | 1 GB | 0.5 GB | ~400 MB | iPhone 13+ (4GB RAM) |
        | 1B | 2 GB | 1 GB | ~600 MB | iPhone 14+ (6GB RAM) |
        | 1.5B | 3 GB | 1.5 GB | ~1 GB | iPhone 15 (6GB RAM) |
        | 3B | 6 GB | 3 GB | ~2 GB | iPhone 15 Pro (8GB RAM) |
        | 7B | 14 GB | 7 GB | ~4 GB | 超出 iPhone 能力 |

        > **核心认知**：iPhone 的瓶颈是 **内存（RAM）**，不是算力。A17 Pro 的 Neural Engine 和 GPU 足够强大，但 iPhone 15 Pro 只有 8GB RAM，其中系统和其他 App 占用约 3-4GB，留给模型的空间有限。

        ### Prefill 与 Decode：两阶段推理

        端侧推理分为两个截然不同的阶段：

        ```
        ┌─────────────────────────────────────────────────┐
        │  Prefill 阶段（读）          Decode 阶段（写）   │
        │                                                 │
        │  "今天天气怎么样？"    →    "今" "天" "是" "晴"  │
        │  ─── 一次性处理 ───       ─── 逐个生成 ───      │
        │  并行，速度快               串行，速度慢          │
        │  ~100-500ms              每个 token 40-100ms    │
        └─────────────────────────────────────────────────┘
        ```

        1. **Prefill（预填充/Prompt Processing）**：
           - 一次性并行处理所有输入 token
           - 速度用 **tokens/s** 衡量，端侧通常 100-500 t/s
           - 用户感知为 **首字延迟（TTFT, Time To First Token）**
           - 输入越长，Prefill 越慢

        2. **Decode（解码/Token Generation）**：
           - 每次只生成一个 token，然后把它加入上下文，再生成下一个
           - 完全串行，无法并行
           - 速度用 **tokens/s** 衡量，端侧通常 10-25 t/s
           - 这就是为什么你看到聊天界面是一个字一个字蹦出来的

        ### 自回归生成过程

        ```
        输入:   "今天天气"
        Step 1: "今天天气" → 模型预测 → "怎" (概率最高)
        Step 2: "今天天气怎" → 模型预测 → "么" 
        Step 3: "今天天气怎么" → 模型预测 → "样"
        Step 4: "今天天气怎么样" → 模型预测 → "？"
        Step 5: "今天天气怎么样？" → 模型预测 → <EOS> (结束)
        ```

        每一步都需要完整的前向传播计算，这就是为什么生成速度比处理速度慢得多。
        """
    ),

    // ── 第2章 ──
    LearningModule(
        order: 2,
        title: "端侧模型的优势与挑战",
        subtitle: "为什么要在 iPhone 上跑 AI？有什么限制？",
        icon: "iphone.gen3",
        color: .purple,
        difficulty: .beginner,
        content: """
        ## 为什么要在 iPhone 上跑 AI？

        ### 端侧推理 vs 云端推理架构对比

        ```
        ┌── 云端推理 ──────────────────────────────────┐
        │  [用户输入] → [网络传输] → [云端 GPU 推理]    │
        │             → [网络传输] → [结果展示]         │
        │  延迟: 500-2000ms  |  费用: ~$0.01/次        │
        │  隐私: 数据经过第三方服务器                    │
        └──────────────────────────────────────────────┘

        ┌── 端侧推理 ──────────────────────────────────┐
        │  [用户输入] → [本地模型推理] → [结果展示]      │
        │  延迟: 100-500ms  |  费用: $0               │
        │  隐私: 数据全程不出设备                       │
        └──────────────────────────────────────────────┘
        ```

        ### 四大核心优势

        **1. 隐私保护 —— 数据零传输**

        所有推理都在设备本地完成，用户数据不经过任何服务器。这对以下场景至关重要：
        - 健康和医疗数据
        - 金融和支付信息
        - 个人通讯内容
        - 企业机密文档
        - 儿童相关数据（COPPA 合规）

        **2. 低延迟 —— 无网络往返**

        端侧推理的首字延迟（TTFT）通常在 100-500ms，而云端 API 的 TTFT 通常在 500-2000ms。

        延迟构成对比：

        | 环节 | 云端 | 端侧 |
        |------|------|------|
        | DNS 解析 | 10-100ms | 0 |
        | TCP/TLS 握手 | 50-200ms | 0 |
        | 请求上传 | 10-50ms | 0 |
        | 排队等待 | 0-5000ms | 0 |
        | Prefill 计算 | 50-200ms | 100-500ms |
        | 首字返回 | 10-50ms | 0 |
        | **总计 TTFT** | **130-5600ms** | **100-500ms** |

        **3. 离线可用 —— 任何环境都能工作**

        地铁、飞机、电梯、偏远地区——只要设备有电，模型就能运行。适合作为云端服务的**优雅降级方案**。

        **4. 零边际成本 —— 跑多少次都不花钱**

        模型下载一次到设备上，后续每次推理没有 API 费用。对于高频场景（输入联想、实时分类），成本优势巨大。

        假设一个 App 日活 100 万，每人每天触发 20 次 AI 分类：

        $$\\text{云端日费用} = 1{,}000{,}000 \\times 20 \\times \\$0.001 = \\$20{,}000/\\text{天}$$

        $$\\text{端侧日费用} = \\$0$$

        ### 五大现实限制

        | 限制 | 具体表现 | 量化数据 | 应对策略 |
        |-----|---------|---------|---------|
        | 模型能力上限 | 3B 以下模型无法处理复杂推理 | MMLU 评分: 0.5B~35%, 3B~55%, GPT-4~87% | 简单任务端侧，复杂任务走云端 |
        | 内存压力 | 模型占用大量 RAM | 3B Q4 ≈ 2GB，iPhone 15 Pro 可用 ~4GB | 推理完即卸载，避免常驻 |
        | 发热与降频 | 持续推理导致 SOC 温度升高 | 连续推理 3-5 分钟可达 serious 热状态 | 监控 thermalState，过热暂停 |
        | 存储占用 | 每个 GGUF 文件 0.4-3GB | 3 个模型 ≈ 5GB 存储空间 | 用户选择性下载，支持删除 |
        | 中文能力差异 | 多数小模型英文数据占比高 | Qwen 中文最好，Llama 中文较弱 | 中文场景优先选 Qwen 系列 |

        ### 端侧 vs 云端：决策矩阵

        ```
        你的任务适合端侧吗？
        ├── 需要离线使用？ → 是 → 端侧
        ├── 涉及敏感数据？ → 是 → 端侧
        ├── 调用频率 > 100次/天？ → 是 → 端侧（省成本）
        ├── 需要复杂推理（数学/逻辑）？ → 是 → 云端
        ├── 需要处理长文本（>2000字）？ → 是 → 云端
        └── 以上都不是？ → 看延迟要求
            ├── 延迟 < 200ms → 端侧
            └── 延迟不敏感 → 云端（质量更好）
        ```
        """
    ),

    // ── 第3章 ──
    LearningModule(
        order: 3,
        title: "Transformer 架构详解",
        subtitle: "深入理解注意力机制、前馈网络和位置编码",
        icon: "text.alignleft",
        color: .green,
        difficulty: .intermediate,
        content: """
        ## Transformer：大模型的基石

        几乎所有现代大模型（GPT、Llama、Qwen、Gemma、Phi）都基于 Transformer 架构（2017年 Google "Attention is All You Need" 论文提出）。

        ### 整体数据流

        ```
        输入: "今天天气"
            ↓
        ┌─── Tokenizer ───────────────────────┐
        │  "今天天气" → [512, 1038, 2847, 983] │
        └──────────────────────────────────────┘
            ↓
        ┌─── Embedding Layer ─────────────────┐
        │  token ID → 高维向量 (d_model=2048)  │
        │  [512] → [0.12, -0.34, 0.78, ...]   │
        └──────────────────────────────────────┘
            ↓
        ┌─── Positional Encoding ─────────────┐
        │  注入位置信息（模型本身不知道词序）    │
        │  RoPE / ALiBi / 绝对位置编码         │
        └──────────────────────────────────────┘
            ↓
        ┌─── Transformer Block × N 层 ────────┐
        │  ┌── Multi-Head Attention ──┐        │
        │  │  Q = X·W_Q               │        │
        │  │  K = X·W_K               │        │
        │  │  V = X·W_V               │        │
        │  │  Attention(Q,K,V)         │        │
        │  └──────────────────────────┘        │
        │           ↓ + 残差连接 + LayerNorm    │
        │  ┌── Feed-Forward Network ──┐        │
        │  │  FFN(x) = W2·σ(W1·x)     │        │
        │  └──────────────────────────┘        │
        │           ↓ + 残差连接 + LayerNorm    │
        └──────────────────────────────────────┘
            ↓  (重复 N 次，如 Qwen2.5-1.5B 有 28 层)
        ┌─── Output Head ─────────────────────┐
        │  隐藏状态 → 词表大小的概率分布        │
        │  softmax → P("怎")=0.35, P("好")=0.12│
        └──────────────────────────────────────┘
            ↓
        ┌─── Sampling ────────────────────────┐
        │  根据温度和采样策略选择下一个 token   │
        │  → 选中"怎" → 输出给用户             │
        └──────────────────────────────────────┘
        ```

        ### Self-Attention 核心公式

        Attention 是 Transformer 的核心。它让每个 token "看到"序列中所有其他 token，计算它们之间的相关性：

        $$\\text{Attention}(Q, K, V) = \\text{softmax}\\left(\\frac{QK^T}{\\sqrt{d_k}}\\right)V$$

        其中：
        - $Q$ (Query)：当前词的"提问"向量——"我想找什么信息？"
        - $K$ (Key)：每个词的"标签"向量——"我包含什么信息？"
        - $V$ (Value)：每个词的"内容"向量——"如果被选中，我提供什么？"
        - $d_k$：Key 的维度，除以 $\\sqrt{d_k}$ 防止点积过大导致 softmax 饱和
        - $\\text{softmax}$：将分数归一化为概率分布（和为 1）

        **直觉理解**：用 iOS 类比，Attention 就像一个**动态的数据库查询**——每个词用自己的 Query 去查询所有词的 Key，找到最相关的，然后用它们的 Value 来更新自己的表示。

        ### Multi-Head Attention

        为了让模型同时关注不同类型的关系（语法关系、语义关系、位置关系），Transformer 使用多个 Attention "头"并行运算：

        ```
        Head 1: 关注语法关系 (主语→谓语)
        Head 2: 关注指代关系 (代词→名词)
        Head 3: 关注相邻位置
        ...
        Head h: 关注长距离依赖
        ```

        各头的输出拼接后通过线性变换合并：

        $$\\text{MultiHead}(Q,K,V) = \\text{Concat}(\\text{head}_1, ..., \\text{head}_h)W^O$$

        常见配置：Qwen2.5-1.5B 有 12 个注意力头，每头维度 128。

        ### Feed-Forward Network (FFN)

        每个 Transformer 层的第二个子模块是一个两层全连接网络：

        $$\\text{FFN}(x) = W_2 \\cdot \\text{SiLU}(W_1 \\cdot x)$$

        FFN 占模型参数量的 **约 2/3**。它负责对每个位置独立地进行非线性变换，可以理解为"思考和记忆"的部分。

        ### Dense vs MoE 架构对比

        | 特性 | Dense | MoE (Mixture of Experts) |
        |------|-------|--------------------------|
        | FFN 结构 | 1 个大 FFN | N 个小 FFN（专家）+ Router |
        | 每次计算 | 全部参数参与 | Router 选择 Top-K 个专家 |
        | iOS 类比 | 加载所有 ViewController | UICollectionView 只加载可见 Cell |
        | 总参数量 | 如 3B | 如 26B（但每次只用 4B） |
        | 内存需求 | 与参数量成正比 | 需加载所有专家（内存大）|
        | 计算量 | 与参数量成正比 | 远小于总参数量 |
        | 端侧适用性 | 好（内存可控）| 受限（总参数占内存大）|
        | 代表模型 | Llama, Qwen, Gemma 2 | DeepSeek, Mixtral, Gemma 4 |

        ### 关键模型参数

        | 参数名 | 含义 | Qwen2.5-1.5B | Llama 3.2-1B |
        |--------|------|---------------|---------------|
        | `n_layers` | Transformer 层数 | 28 | 16 |
        | `d_model` | 隐藏层维度 | 1536 | 2048 |
        | `n_heads` | 注意力头数 | 12 | 32 |
        | `d_ff` | FFN 中间维度 | 8960 | 8192 |
        | `vocab_size` | 词表大小 | 151,936 | 128,256 |
        | `n_ctx` | 最大上下文 | 32,768 | 131,072 |
        """
    ),

    // ── 第4章 ──
    LearningModule(
        order: 4,
        title: "GGUF 与模型量化",
        subtitle: "理解量化原理、GGUF 格式、如何选择合适的量化级别",
        icon: "archivebox.fill",
        color: .orange,
        difficulty: .intermediate,
        content: """
        ## GGUF 格式与量化技术

        ### 什么是 GGUF？

        GGUF（GPT-Generated Unified Format）是 llama.cpp 项目定义的模型文件格式：

        ```
        ┌──────────────────────────────────────────┐
        │  GGUF 文件结构                            │
        │                                          │
        │  ┌── Header ───────────────────────────┐ │
        │  │  Magic: "GGUF"                      │ │
        │  │  Version: 3                         │ │
        │  │  Tensor count, Metadata count       │ │
        │  └─────────────────────────────────────┘ │
        │  ┌── Metadata ─────────────────────────┐ │
        │  │  architecture: "llama"              │ │
        │  │  context_length: 2048               │ │
        │  │  vocab_size: 151936                 │ │
        │  │  chat_template: "..."               │ │
        │  │  tokenizer.ggml.model: "gpt2"      │ │
        │  │  tokenizer.ggml.tokens: [...]       │ │
        │  └─────────────────────────────────────┘ │
        │  ┌── Tensor Data ──────────────────────┐ │
        │  │  token_embd.weight: [Q4_K 数据...]  │ │
        │  │  blk.0.attn_q.weight: [Q4_K 数据...] │
        │  │  blk.0.attn_k.weight: [Q4_K 数据...] │
        │  │  ...                                │ │
        │  │  output.weight: [Q6_K 数据...]      │ │
        │  └─────────────────────────────────────┘ │
        └──────────────────────────────────────────┘
        ```

        **GGUF 的优势**：单文件包含模型权重 + 分词器 + 配置，开箱即用。

        ### 量化原理

        量化的核心思想：用更少的 bit 表示每个参数，牺牲微小精度换取巨大的体积和速度收益。

        **FP16 → INT4 量化过程**：

        假设一组权重为 `[0.12, -0.34, 0.78, -0.56, 0.23, -0.91, 0.45, -0.67]`

        ```
        1. 找到范围: min=-0.91, max=0.78
        2. 计算缩放因子: scale = (max-min) / (2^4-1) = 1.69/15 ≈ 0.113
        3. 量化: q = round((x - min) / scale)
           0.12  → round((0.12+0.91)/0.113) = round(9.1) = 9
           -0.34 → round((-0.34+0.91)/0.113) = round(5.0) = 5
           ...
        4. 存储: [9, 5, 15, 3, 10, 0, 12, 2] (每个只需 4 bit)
        ```

        反量化时：$x \\approx q \\times \\text{scale} + \\text{min}$

        **量化误差**：量化必然引入误差，误差大小与量化级别有关：

        $$\\text{MSE} = \\frac{1}{n}\\sum_{i=1}^{n}(x_i - \\hat{x}_i)^2$$

        其中 $x_i$ 是原始值，$\\hat{x}_i$ 是量化后反量化的值。

        ### 量化方案对比

        GGUF 支持多种量化方案，`K` 表示 k-quant（混合精度量化，对重要层用更高精度）：

        | 方案 | 每参数 bit | 压缩比 | 质量损失 | 1.5B 文件大小 | 适用场景 |
        |------|----------|--------|---------|-------------|---------|
        | FP16 | 16 | 1× | 0% | 3.0 GB | 服务器/基准 |
        | Q8_0 | 8 | 2× | ~0.1% | 1.5 GB | iPad Pro |
        | Q6_K | 6 | 2.67× | ~0.3% | 1.13 GB | 高端设备 |
        | Q5_K_M | 5 | 3.2× | ~0.5% | 0.94 GB | 追求质量 |
        | **Q4_K_M** | **4** | **4×** | **~1-2%** | **0.75 GB** | **推荐首选** |
        | Q3_K_M | 3 | 5.3× | ~3-5% | 0.56 GB | 存储受限 |
        | Q2_K | 2 | 8× | ~8-15% | 0.38 GB | 不推荐 |

        压缩比计算：

        $$\\text{压缩比} = \\frac{16}{\\text{目标bit数}}$$

        > **结论**：**Q4_K_M 是端侧部署的最佳平衡点**。在 MMLU 基准上，Q4_K_M 相比 FP16 仅下降 1-2 个百分点，但体积缩小到 1/4。

        ### 量化对不同任务的影响

        不同任务对量化的敏感度不同：

        | 任务类型 | Q4 vs FP16 差异 | 原因 |
        |---------|---------------|------|
        | 文本分类 | 几乎无差别 | 只需判断类别，容错率高 |
        | 简单问答 | 几乎无差别 | 答案空间小 |
        | 翻译 | 轻微下降 | 需要精确的词汇选择 |
        | 代码生成 | 可感知下降 | 语法精确性要求高 |
        | 数学推理 | 明显下降 | 数值计算精度敏感 |
        | 创意写作 | 几乎无差别 | 无"标准答案" |
        """
    ),

    // ── 第5章 ──
    LearningModule(
        order: 5,
        title: "llama.cpp 与 iOS 集成",
        subtitle: "从零集成 llama.cpp 到 iOS App 的完整技术方案",
        icon: "hammer.fill",
        color: .red,
        difficulty: .advanced,
        content: """
        ## llama.cpp：端侧推理引擎

        llama.cpp 是目前最流行的端侧 LLM 推理引擎，纯 C/C++ 实现，通过 Metal 框架调用 Apple GPU。

        ### 技术方案对比

        | 方案 | 模型支持 | iOS 性能 | 集成难度 | 社区活跃度 |
        |------|---------|---------|---------|-----------|
        | **llama.cpp** | 最广泛（GGUF 格式）| Metal GPU 加速 | 中等（C API）| 极高（GitHub 70k+ star）|
        | CoreML | 需转换为 mlmodel | Neural Engine 最优 | 高（转换复杂）| Apple 官方 |
        | MLX | Swift 原生 | Apple Silicon 优化 | 低 | 较新 |
        | MNN | 有限 | CPU 为主 | 中等 | 阿里开源 |

        ### iOS 集成架构

        ```
        ┌─── App Layer (Swift/SwiftUI) ──────────────────┐
        │  ChatView → LlamaOnDeviceProvider              │
        └────────────────────┬───────────────────────────┘
                             │ 调用
        ┌─── Bridge Layer (Swift) ──────────────────────┐
        │  LlamaEngine.swift                             │
        │  - load() / unload()                           │
        │  - generate() (streaming)                      │
        │  - applyChatTemplate()                         │
        │  - UTF8StreamDecoder                           │
        └────────────────────┬───────────────────────────┘
                             │ C API 调用
        ┌─── llama.cpp (C/C++) ─────────────────────────┐
        │  llama.xcframework (预编译二进制)               │
        │  - llama_model_load_from_file()                │
        │  - llama_init_from_model()                     │
        │  - llama_decode() / llama_sampler_sample()     │
        │  - Metal GPU 后端                              │
        └────────────────────┬───────────────────────────┘
                             │
        ┌─── Hardware ──────────────────────────────────┐
        │  Apple A17 Pro: CPU + GPU + Neural Engine      │
        │  Metal API → GPU 矩阵运算加速                  │
        └────────────────────────────────────────────────┘
        ```

        ### SPM 集成方式

        llama.cpp 提供预编译的 xcframework（约 50MB），通过 SPM Binary Target 引入：

        ```swift
        // LocalPackages/LlamaFramework/Package.swift
        let package = Package(
            name: "LlamaFramework",
            platforms: [.iOS(.v17)],
            products: [
                .library(name: "llama", targets: ["llama"])
            ],
            targets: [
                .binaryTarget(
                    name: "llama",
                    url: "https://github.com/ggml-org/llama.cpp/releases/download/b8783/llama-b8783-xcframework.zip",
                    checksum: "..."
                )
            ]
        )
        ```

        ### 完整推理流程代码

        ```swift
        import llama

        // 1. 初始化后端
        llama_backend_init()

        // 2. 加载模型文件
        var params = llama_model_default_params()
        params.n_gpu_layers = 999  // 全部层使用 GPU
        let model = llama_model_load_from_file(path, params)

        // 3. 创建推理上下文
        var ctxParams = llama_context_default_params()
        ctxParams.n_ctx = 2048     // 上下文长度
        ctxParams.n_batch = 512    // 批处理大小
        ctxParams.n_threads = 4    // CPU 线程数
        let ctx = llama_init_from_model(model, ctxParams)

        // 4. 构建采样链
        let sampler = llama_sampler_chain_init(defaultParams)
        llama_sampler_chain_add(sampler, llama_sampler_init_penalties(64, 1.1, 0, 0))
        llama_sampler_chain_add(sampler, llama_sampler_init_top_k(40))
        llama_sampler_chain_add(sampler, llama_sampler_init_top_p(0.9, 1))
        llama_sampler_chain_add(sampler, llama_sampler_init_temp(0.7))
        llama_sampler_chain_add(sampler, llama_sampler_init_dist(seed))

        // 5. 分词
        let tokens = llama_tokenize(vocab, text, len, &buf, maxTokens, true, true)

        // 6. Prefill（处理输入）
        let batch = llama_batch_get_one(tokens, count)
        llama_decode(ctx, batch)

        // 7. Decode（逐 token 生成）
        while !finished {
            let token = llama_sampler_sample(sampler, ctx, -1)
            if llama_vocab_is_eog(vocab, token) { break }
            
            let bytes = llama_token_to_piece(vocab, token, &buf, 256, 0, true)
            let text = utf8Decoder.decode(bytes)  // UTF-8 流式解码
            onToken(text)  // 回调给 UI
            
            llama_decode(ctx, llama_batch_get_one(&token, 1))
        }

        // 8. 清理
        llama_sampler_free(sampler)
        llama_free(ctx)
        llama_model_free(model)
        llama_backend_free()
        ```

        ### Chat Template 详解

        不同模型系列使用不同的对话格式，必须正确应用才能获得好的输出：

        | 模型 | 格式名称 | 示例 |
        |-----|---------|------|
        | Qwen | ChatML | `<\\|im_start\\|>user\\n你好<\\|im_end\\|>` |
        | Llama 3 | Llama3 | `<\\|start_header_id\\|>user<\\|end_header_id\\|>\\n\\n你好<\\|eot_id\\|>` |
        | Gemma 2 | Gemma | `<start_of_turn>user\\n你好<end_of_turn>` |
        | Gemma 4 | Gemma4 | `<\\|turn>user\\n你好<turn\\|>` |
        | Phi-3.5 | Phi | `<\\|user\\|>\\n你好<\\|end\\|>` |

        > **重要**：使用错误的 template 会导致模型输出质量严重下降甚至乱码。本项目通过 `detectModelFamily()` 自动检测模型家族并选择正确的 template。
        """
    ),

    // ── 第6章 ──
    LearningModule(
        order: 6,
        title: "采样策略与输出控制",
        subtitle: "Temperature、Top-P、Top-K 的数学原理与实践",
        icon: "slider.horizontal.3",
        color: .teal,
        difficulty: .intermediate,
        content: """
        ## 采样策略的数学原理

        模型每次前向传播输出的是一个**logits 向量**——词表中每个 token 的未归一化分数。采样策略决定了如何从 logits 转换为最终选择的 token。

        ### Softmax 与 Temperature

        Softmax 函数将 logits 转换为概率分布：

        $$p_i = \\frac{e^{z_i / T}}{\\sum_{j=1}^{V} e^{z_j / T}}$$

        其中 $z_i$ 是第 $i$ 个 token 的 logit，$T$ 是温度参数，$V$ 是词表大小。

        **Temperature 的效果**：

        假设 logits = [2.0, 1.0, 0.5]（对应"好""的""啊"三个候选词）：

        | 温度 T | P("好") | P("的") | P("啊") | 效果 |
        |--------|---------|---------|---------|------|
        | 0.1 | 99.9% | 0.1% | 0.0% | 几乎确定性，总选最大 |
        | 0.5 | 84.0% | 11.6% | 4.4% | 较保守 |
        | **0.7** | **72.7%** | **17.7%** | **9.6%** | **推荐默认值** |
        | 1.0 | 59.3% | 21.8% | 18.9% | 原始分布 |
        | 1.5 | 47.4% | 28.0% | 24.6% | 较随机 |
        | 2.0 | 41.4% | 30.2% | 28.4% | 高度随机 |

        温度越低 → 分布越尖锐 → 输出越确定
        温度越高 → 分布越平坦 → 输出越随机

        ### Top-K 采样

        从概率最高的 K 个候选中采样，其余概率设为 0：

        ```
        原始分布:  [0.35, 0.25, 0.15, 0.10, 0.05, 0.04, 0.03, 0.02, 0.01]
        Top-K=3:   [0.47, 0.33, 0.20, 0,    0,    0,    0,    0,    0   ]
                    ↑ 重新归一化前 3 个
        ```

        | K 值 | 效果 | 适用场景 |
        |------|------|---------|
        | 1 | 贪心解码，永远选最大 | 分类、提取 |
        | 20 | 保守采样 | 代码、数学 |
        | **40** | **平衡** | **通用推荐** |
        | 100 | 更多样化 | 创意写作 |

        ### Top-P（核采样，Nucleus Sampling）

        从概率最高的词开始累加，直到累计概率达到 P，只从这些词中采样：

        ```
        排序后概率:  [0.35, 0.25, 0.15, 0.10, 0.05, ...]
        累计概率:    [0.35, 0.60, 0.75, 0.85, 0.90, ...]
        Top-P=0.9:  [0.35, 0.25, 0.15, 0.10, 0.05]  ← 前5个
                     其余截断
        ```

        Top-P 比 Top-K 更智能——当模型很确定时（概率集中），自动缩小候选范围；当模型不确定时（概率分散），自动扩大范围。

        ### Repeat Penalty（重复惩罚）

        对已出现过的 token 降低其再次被选中的概率：

        $$p'_i = \\frac{p_i}{\\text{penalty}} \\quad \\text{如果 token } i \\text{ 在最近 } n \\text{ 个 token 中出现过}$$

        - `penalty = 1.0`：无惩罚
        - `penalty = 1.1`：轻微惩罚（推荐）
        - `penalty = 1.5`：强力惩罚

        > **端侧小模型特别需要重复惩罚**，因为小模型的词汇空间有限，容易陷入"的的的的"或"I I I I"的重复循环。

        ### 采样链执行顺序

        llama.cpp 中采样器按顺序串行执行：

        ```
        原始 logits
          ↓
        [Repeat Penalty] 惩罚最近 64 个 token 中出现过的词
          ↓
        [Top-K = 40] 只保留概率最高的 40 个候选
          ↓
        [Top-P = 0.9] 从中截取累计概率 90% 的子集
          ↓
        [Temperature = 0.7] 调整剩余候选的概率分布
          ↓
        [Random Sample] 按调整后的概率随机选择一个 token
        ```

        > 顺序很重要：先过滤（Top-K/P）再调温度，避免温度放大长尾噪声。

        ### 场景推荐配置

        | 场景 | Temperature | Top-K | Top-P | Repeat Penalty |
        |------|-------------|-------|-------|----------------|
        | 分类/提取 | 0.0-0.1 | 1-10 | 0.5 | 1.0 |
        | 代码生成 | 0.1-0.3 | 20 | 0.9 | 1.0 |
        | 日常对话 | 0.7 | 40 | 0.9 | 1.1 |
        | 创意写作 | 0.9-1.2 | 80 | 0.95 | 1.2 |
        | 头脑风暴 | 1.0-1.5 | 100 | 1.0 | 1.3 |
        """
    ),

    // ── 第7章 ──
    LearningModule(
        order: 7,
        title: "性能优化与监控",
        subtitle: "内存管理、KV Cache、热状态监控、GPU 加速实践",
        icon: "gauge.with.dots.needle.33percent",
        color: .indigo,
        difficulty: .advanced,
        content: """
        ## 端侧推理的性能工程

        ### 关键性能指标

        | 指标 | 公式 | 优秀值 (1-3B Q4) | 测量方法 |
        |------|------|----------------|---------|
        | TTFT | Prefill 耗时 | < 500ms | 首个 token 输出时间 - 请求发送时间 |
        | Decode Speed | tokens / decode_time | > 10 t/s | 生成的 token 数 / Decode 阶段总时间 |
        | Peak Memory | RSS 峰值 | < 50% 设备 RAM | `mach_task_basic_info.resident_size` |
        | Throughput | total_tokens / total_time | > 8 t/s | 总生成 token / 总耗时（含 Prefill）|

        ### KV Cache：内存消耗的关键

        Transformer 推理时，每一层都需要缓存之前所有 token 的 Key 和 Value 向量，这就是 KV Cache。它是端侧推理中除模型权重外**最大的内存消耗**。

        KV Cache 内存计算公式：

        $$\\text{KV Cache (MB)} = 2 \\times n_{\\text{layers}} \\times n_{\\text{ctx}} \\times d_{\\text{model}} \\times 2 \\div 1024^2$$

        其中因子 2 表示 K 和 V 各一份，末尾 ×2 是 FP16 每个值 2 字节。

        实际数值（FP16 KV Cache）：

        | 模型 | 层数 | 隐藏维度 | n_ctx=2048 | n_ctx=4096 |
        |------|------|---------|-----------|-----------|
        | Qwen2.5-0.5B | 24 | 896 | 168 MB | 336 MB |
        | Qwen2.5-1.5B | 28 | 1536 | 330 MB | 660 MB |
        | Llama 3.2-3B | 28 | 3072 | 660 MB | 1.3 GB |

        > **实践建议**：端侧使用 `n_ctx = 2048`。除非确实需要长上下文，否则不要增加——KV Cache 与上下文长度**线性增长**。

        ### 总内存占用

        推理时的总内存 = 模型权重 + KV Cache + 工作缓冲区：

        $$\\text{总内存} \\approx \\text{模型权重} + \\text{KV Cache} + \\text{Buffer (约 100-200MB)}$$

        以 Qwen2.5-1.5B Q4_K_M 为例：

        ```
        模型权重:  ~1.0 GB (Q4_K_M)
        KV Cache:  ~330 MB (n_ctx=2048, FP16)
        工作缓冲:  ~150 MB
        ─────────────────
        总计:      ~1.5 GB
        
        iPhone 15 Pro 可用 RAM ≈ 4 GB → 占用 37.5% ✓ 安全
        ```

        ### Metal GPU 加速

        llama.cpp 通过 Metal 框架在 iPhone GPU 上运行矩阵乘法：

        ```swift
        var params = llama_model_default_params()
        params.n_gpu_layers = 999  // 所有层都在 GPU 运行
        ```

        - **GPU 推理速度**通常是纯 CPU 的 2-5 倍
        - iPhone 15 Pro 的 GPU 有 6 核，支持 FP16 矩阵运算
        - GPU 内存与系统 RAM 共享（统一内存架构），不存在"显存不够"的问题，但会和系统争 RAM

        ### 热状态监控

        持续推理导致芯片温度升高，iOS 会自动降频保护硬件：

        ```swift
        switch ProcessInfo.processInfo.thermalState {
        case .nominal:   // < 35°C，全速运行
            break
        case .fair:      // 35-40°C，轻微降频
            break        // 可以继续，速度略降
        case .serious:   // 40-45°C，明显降频
            // 建议暂停或降低生成速度
            reduceBatchSize()
        case .critical:  // > 45°C，严重降频
            // 必须停止推理
            engine.cancelGeneration()
        }
        ```

        **实测数据**（iPhone 15 Pro，Qwen2.5-1.5B Q4）：
        - 单次对话（<30s）：温度基本不变
        - 连续测评（3分钟）：从 nominal 升至 fair
        - 高强度连续推理（5分钟+）：可能达到 serious

        ### UTF-8 流式解码

        中文字符占 3 字节，Emoji 占 4 字节。token 边界可能切断一个多字节字符：

        ```
        "你" = UTF-8 字节: [0xE4, 0xBD, 0xA0]

        Token 1 输出: [0xE4, 0xBD]     ← 不完整的"你"
        Token 2 输出: [0xA0, 0xE5...]   ← "你"的最后一字节 + 下一个字的开头

        直接转 String → 乱码！
        ```

        **解决方案**：使用 `UTF8StreamDecoder` 累积字节，只在字符完整时才解码输出。本项目已实现此方案。
        """
    ),

    // ── 第8章 ──
    LearningModule(
        order: 8,
        title: "模型评测与选型",
        subtitle: "如何科学地评估和选择适合你场景的端侧模型",
        icon: "chart.bar.xaxis",
        color: .mint,
        difficulty: .advanced,
        content: """
        ## 端侧模型的科学评测

        ### 评测的三个层次

        ```
        ┌─── Level 3: 业务评测 ─────────────────┐
        │  真实用户场景 + 人工评估                 │
        │  最准确，但最耗时                       │
        ├─── Level 2: 任务评测 ─────────────────┤
        │  标准化测试用例 + 自动评分               │
        │  本 App「测评」Tab 提供的能力            │
        ├─── Level 1: 基准跑分 ─────────────────┤
        │  MMLU / GSM8K / HumanEval 等          │
        │  快速但与实际效果有差距                  │
        └────────────────────────────────────────┘
        ```

        ### 自动质量评分方法

        本 App 使用**规则匹配 + 关键词检查**的方式自动评分，覆盖以下评估维度：

        | 评分规则 | 适用场景 | 示例 |
        |---------|---------|------|
        | 关键词命中 | 分类、翻译 | 输出是否包含"查询天气" |
        | JSON 合法性 | 信息提取 | 输出能否被 JSON 解析器解析 |
        | 格式匹配 | 格式遵循 | 正则检查编号格式 |
        | 答案正确性 | 数学推理 | 输出是否包含"600ms" |
        | 拒绝检测 | 安全边界 | 是否包含"抱歉""无法"等拒绝词 |
        | 长度范围 | 摘要、简答 | 输出长度是否在合理区间 |
        | 代码检测 | 代码补全 | 是否包含代码块或关键 API |

        评分公式：

        $$\\text{总分} = \\frac{\\sum_{i \\in \\text{passed}} w_i}{\\sum_{j=1}^{n} w_j} \\times 100$$

        其中 $w_i$ 是第 $i$ 条规则的权重。

        评分等级：
        - **通过** (>= 80分)：模型输出基本符合预期
        - **部分通过** (40-79分)：有部分正确但存在问题
        - **未通过** (< 40分)：输出质量不达标

        ### 常见学术基准

        | 基准 | 测试维度 | 题数 | 小模型典型得分 |
        |-----|---------|-----|-------------|
        | MMLU | 57 学科知识 | 14,042 | 0.5B:~35%, 3B:~55% |
        | GSM8K | 小学数学推理 | 1,319 | 0.5B:~10%, 3B:~40% |
        | HumanEval | Python 代码 | 164 | 0.5B:~15%, 3B:~35% |
        | C-Eval | 中文知识 | 13,948 | 0.5B:~35%, 3B:~50% |
        | TruthfulQA | 事实/幻觉 | 817 | 0.5B:~30%, 3B:~45% |
        | ARC-Challenge | 科学推理 | 1,172 | 0.5B:~30%, 3B:~45% |

        > **注意**：学术跑分与实际业务效果可能有较大差距。**务必用你的真实场景测试**。

        ### 端侧模型选型决策树

        ```
        1. 确定你的核心任务
        │
        ├── 分类/意图识别 ──→ 0.5B 够用 ──→ Qwen2.5-0.5B
        │
        ├── 中文对话/摘要/翻译 ──→ 1.5B 性价比最高 ──→ Qwen2.5-1.5B
        │
        ├── 英文为主的场景 ──→ 1B 轻量 ──→ Llama 3.2-1B
        │
        ├── 需要推理/思考链 ──→ 2B+ 带 thinking ──→ Gemma 4 E2B
        │
        ├── 代码辅助 ──→ 3B+ 代码能力强 ──→ Phi-3.5 Mini
        │
        └── 极度追求轻量 ──→ 360M ──→ SmolLM2-360M
        
        2. 确认设备兼容性
        │
        ├── iPhone 13/14 (4-6GB) ──→ 最大 1B Q4
        ├── iPhone 15 (6GB) ──→ 最大 2B Q4
        └── iPhone 15 Pro+ (8GB) ──→ 最大 3B Q4
        
        3. 量化级别选择
        │
        └── 几乎所有场景 ──→ Q4_K_M（最佳平衡）
        ```

        ### 评测最佳实践

        1. **收集真实数据**：从你的 App 收集 20-50 条真实用户输入
        2. **标注预期输出**：人工写出"理想回复"作为参考
        3. **多模型对比**：用本 App 的测评功能跑相同用例
        4. **综合评估**：质量分 + 速度 + 内存，三者权衡
        5. **线上验证**：先小范围 A/B 测试，再全量上线
        """
    ),

    // ── 第9章 ──
    LearningModule(
        order: 9,
        title: "端侧模型应用场景大全",
        subtitle: "除了聊天，端侧 LLM 在客户端还能做什么？",
        icon: "sparkles",
        color: .cyan,
        difficulty: .intermediate,
        content: """
        ## 端侧 LLM 的真实应用场景

        > 核心原则：端侧模型适合 **简单、高频、对延迟和隐私敏感** 的任务。选对场景比选大模型更重要。

        ---

        ### 1. 意图识别与文本分类

        最适合端侧的场景。0.5B 模型就能达到 90%+ 准确率。

        ```
        输入: "帮我定个明天早上8点的闹钟"
        输出: "设置闹钟"

        输入: "今天上海多少度"
        输出: "查询天气"

        输入: "这个产品太难用了，退货！"
        输出: {"sentiment": "negative", "intent": "退货"}
        ```

        **应用**：智能客服路由、搜索意图分类、垃圾消息过滤、情感分析、内容审核

        **System Prompt 模板**：
        ```
        你是一个意图分类器。将用户输入分类为以下类别之一：
        [天气查询, 闹钟设置, 音乐播放, 导航, 闲聊]
        只输出类别名称，不要解释。
        ```

        ---

        ### 2. 结构化信息提取

        从自然语言中提取 JSON/结构化数据，替代复杂正则表达式：

        ```
        输入: "张三 13800138000 北京市朝阳区建国路88号"
        输出: {
          "name": "张三",
          "phone": "13800138000", 
          "address": "北京市朝阳区建国路88号"
        }
        ```

        **应用**：名片 OCR、快递单解析、日志分析、表单自动填充、聊天中提取日期/地点

        ---

        ### 3. 输入联想与自动补全

        利用端侧模型的低延迟特性，实现实时输入建议：

        **应用**：搜索框建议、邮件 quick reply、代码补全（轻量版）、输入法候选词排序

        关键要求：TTFT < 100ms，因此需要极小模型（0.5B）或模型常驻内存。

        ---

        ### 4. 文本摘要与改写

        ```
        输入: [一篇500字新闻]
        输出: "多家科技公司宣布2026年将大规模部署端侧AI模型。"
        ```

        **应用**：通知预览摘要、邮件摘要、文章 TL;DR、语气改写（正式 ↔ 口语）、语法纠错

        ---

        ### 5. 离线翻译

        端侧翻译不依赖网络，适合旅行和阅读场景。

        **应用**：实时字幕翻译、相机取景翻译（OCR+翻译）、文档阅读辅助

        注意：专业术语翻译质量不如 Google Translate，但日常短句足够。推荐 Qwen 系列（中英双语训练数据充足）。

        ---

        ### 6. 本地 RAG（检索增强生成）

        将端侧 LLM 与本地向量数据库结合，实现离线知识库问答：

        ```
        [用户问题]
            ↓
        [向量搜索本地文档库] → 找到相关段落
            ↓
        [LLM 基于段落生成回答]
            ↓
        [用户看到答案 + 来源引用]
        ```

        **应用**：个人笔记智能搜索、本地 PDF 问答、App 内帮助文档、离线 FAQ 系统

        ---

        ### 7. Function Calling（函数调用）

        让模型将自然语言转为 App 内部操作：

        ```
        输入: "把屏幕亮度调到50%"
        输出: {"function": "setBrightness", "params": {"level": 0.5}}

        输入: "打开相册里最近的照片"
        输出: {"function": "openPhoto", "params": {"filter": "recent", "count": 1}}
        ```

        **应用**：语音助手、智能家居控制、App 内自然语言导航、自动化工作流

        实现关键：在 system prompt 中定义函数列表和参数格式，1.5B+ 模型才能较好遵循。

        ---

        ### 8. 隐私敏感场景

        端侧推理的**不可替代优势**——数据完全不出设备：

        **应用**：
        - 健康数据分析（症状分类、用药提醒）
        - 金融数据处理（账单分类、交易摘要）
        - 儿童内容过滤（COPPA 合规）
        - 企业内部文档（合规要求数据不外传）
        - 通讯加密（端到端加密聊天中的 AI 辅助）

        ---

        ### 场景选型速查表

        | 场景 | 最低要求 | 关键指标 | 推荐模型 | Temperature |
        |------|---------|---------|---------|-------------|
        | 意图分类 | 0.5B | 准确率 > 90% | Qwen2.5-0.5B | 0.0-0.1 |
        | 信息提取 | 1B | JSON 合法率 | Qwen2.5-1.5B | 0.0-0.1 |
        | 输入联想 | 0.5B | TTFT < 100ms | Qwen2.5-0.5B | 0.7 |
        | 文本摘要 | 1.5B | 信息保留度 | Qwen2.5-1.5B | 0.3-0.5 |
        | 离线翻译 | 1.5B | 术语准确率 | Qwen2.5-1.5B | 0.1-0.3 |
        | Function Calling | 1.5B+ | 格式遵循率 | Gemma 4 E2B | 0.0-0.1 |
        | 本地 RAG | 1.5B+ | 回答相关性 | Qwen2.5-3B | 0.3-0.5 |
        | 代码辅助 | 3B+ | 代码正确率 | Phi-3.5 Mini | 0.1-0.3 |
        """
    ),
]

#Preview {
    LearnView()
}

#Preview {
    LearnView()
}
