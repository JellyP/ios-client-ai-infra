# 04 - MoE 模型：路由与专家的稀疏激活

> 理解 MoE（Mixture of Experts，混合专家）架构。为什么 DeepSeek、Mixtral、Qwen-MoE 都走这条路？为什么它可能是端侧 AI 的未来？

## 读这篇你能收获什么

- 搞懂 MoE 跟 Dense 的**本质区别**（不是表面的"专家"）
- 看懂 Router 路由器的**工作机制和训练策略**
- 理解**为什么 MoE 总参数大但速度不慢**
- 掌握 MoE 在端侧的**核心挑战和解决方案**
- 了解 MoE 处理多模态的**天然优势**

---

## 一、从 Dense 走向 MoE：为什么要走这条路？

### 1.0 预备知识：FLOPs 是什么？

本章会反复用到 **FLOPs** 这个术语，先花 2 分钟把它讲清楚。

#### FLOPs 是"计算量"的单位

```
FLOPs = Floating Point Operations（浮点运算次数）
      = 做了多少次浮点数的加减乘除

字面拆解:
  Floating Point = 浮点数（小数，如 0.123、-3.14）
  Operations     = 运算（+、-、×、÷）
  
所以 FLOPs 就是衡量"算这件事需要多少次运算"
```

#### ⚠️ FLOPs vs FLOPS（一字之差，含义完全不同）

| 写法 | 全称 | 含义 | 用途 |
|---|---|---|---|
| **FLOPs**（小写 s） | Floating Point Operations | **总运算次数** | 衡量"需要算多少" |
| **FLOPS**（大写 S） | Floating Point Operations **Per Second** | **每秒运算次数** | 衡量"硬件多快" |

```
FLOPs 是"工作量"   (要做多少)
FLOPS 是"算力"     (多快能做完)

时间 = FLOPs / FLOPS = 工作量 / 算力
```

#### 最简单的 FLOPs 例子

```
加法: 3.5 + 2.1 = 5.6       → 1 FLOP
乘法: 3.5 × 2.1 = 7.35      → 1 FLOP

点积: [1,2,3] · [4,5,6]
    = 1×4 + 2×5 + 3×6       → 3 次乘法 + 2 次加法 = 5 FLOPs
    
矩阵乘法 M×K × K×N:
    FLOPs ≈ 2 × M × K × N
    (每个输出元素是 K 次乘法 + K-1 次加法 ≈ 2K 次运算)
```

#### 大模型的 FLOPs 经验公式

```
业界常用公式:
  每个 token 的 FLOPs ≈ 2 × 参数量

为什么乘 2？
  每个参数参与"1 次乘法 + 1 次加法"
  (矩阵乘法的每次内积都是这样)

举例:
  Dense 3B:    每 token ≈ 6 GFLOPs
  Dense 7B:    每 token ≈ 14 GFLOPs
  Dense 70B:   每 token ≈ 140 GFLOPs
  Dense 405B:  每 token ≈ 810 GFLOPs
```

#### 数量级单位速查

```
FLOPs:     1                  = 1
KFLOPs:    1,000              = 10³   Kilo  (千)
MFLOPs:    1,000,000          = 10⁶   Mega  (百万)
GFLOPs:    1,000,000,000      = 10⁹   Giga  (十亿)
TFLOPs:    10¹²               = 万亿
PFLOPs:    10¹⁵               = 千万亿
```

#### 硬件 FLOPS 参考（每秒）

```
iPhone 15 Pro (A17 Pro):
  GPU: ~2 TFLOPS (FP16)
  ANE: ~35 TOPS (INT8)  ← Neural Engine

iPhone 16 Pro (A18 Pro):
  GPU: ~4 TFLOPS (FP16)

NVIDIA RTX 4090:       ~1000 TFLOPS (FP16)
NVIDIA H100:           ~2000 TFLOPS (FP16)
```

#### ⚡ 关键认知：FLOPs ≠ 实际速度

这是一个容易被忽视但**极其重要**的认知：**FLOPs 高不代表真的慢**。

```
大模型推理的真实瓶颈: 内存带宽，不是算力

推理一个 token 发生了什么:
  1. 从内存读参数到 GPU 寄存器       ← 耗时 90%
  2. 做 FLOPs 计算                    ← 耗时 10%

计算 iPhone 理论速度 vs 实际速度（以 Dense 7B 为例）:

算力视角:
  iPhone 15 Pro GPU: 2 TFLOPS = 2000 GFLOPS/s
  算 1 个 token: 14 GFLOPs
  理论速度: 2000 / 14 ≈ 143 tokens/秒 ❌ 达不到

带宽视角:
  iPhone 15 Pro 内存带宽: ~50 GB/s
  读 1 次模型: 7 GB（Q4 量化后更小）
  理论速度: 50 / 7 ≈ 7 tokens/秒 ✅ 实际观察到

→ 实际速度受内存带宽限制，不是算力
→ 这也是为什么量化（减小文件 = 减少读取量）能加速
→ 跟前面 01 文档讲的"端侧 AI 瓶颈是内存不是算力"完全对应
```

**iOS 类比**：就像 CPU 快但硬盘慢——CPU 大部分时间在等硬盘读数据：

```swift
let cpu = ProcessorWith100GHz()      // 极快
let disk = SlowHDD()                 // 极慢

for i in 0..<1_000_000 {
    let data = disk.read(i)          // 99% 时间卡在这 ← 瓶颈
    let result = cpu.process(data)   // 算得飞快，但得等数据
}
// 最终速度由硬盘决定，不是 CPU
```

**这个认知对理解后面的 MoE 内容至关重要**：MoE 会"增加 FLOPs"但"不增加内存读取"，所以速度反而没变慢。

---

### 1.1 Dense 的"规模困境"

```
神经网络的经验法则 (Scaling Laws):
  参数越多 → 能力越强 → 训练/推理成本都变大

具体例子:
  Llama 3.2 3B   → 3B 参数，每 token 计算 3B FLOPs
  Llama 3 70B    → 70B 参数，每 token 计算 70B FLOPs  (计算量 23×)
  Llama 3.1 405B → 405B 参数，每 token 计算 405B FLOPs (计算量 135×)

iPhone 能扛的是 3B
云端服务器能扛的是 70B-400B
GPT-4 级别需要数千张 A100
```

**问题**：能力提升跟计算量是**线性关系**。想要更强，就得付更多算力。

### 1.2 MoE 的核心 insight

**观察**：人脑大约有 860 亿个神经元，但你此刻读这句话时，并不是所有神经元都在激活。

**思路**：模型也不应该每次都让所有参数都参与。**根据当前 token 的特性，动态选出一小部分"专家"去计算。**

```
Dense 模型:
  70B 参数 → 每 token 用 70B → 慢死，但知识多
  
MoE 模型:
  "总共 70B 参数，但每 token 只用 10B"
  → 速度接近 Dense 10B
  → 但知识容量接近 Dense 70B
  
本质: 用稀疏激活换计算量，不牺牲知识容量
```

这就是 MoE 的核心卖点：**Total Parameters ≫ Active Parameters**。

### 1.3 iOS 心智模型

```
Dense Model 像 UIViewController.viewDidLoad:
  每次都加载所有子视图、所有约束、所有数据绑定
  哪怕你这个页面 99% 的东西用户看不到
  
MoE Model 像 UICollectionView + diffable data source:
  只加载屏幕可见的 Cell
  其他 Cell 存在 dataSource 里，需要时再拉
  → 用同样的内存容量承载了更多内容
```

---

## 二、MoE 的架构：到底改动了什么？

### 2.1 只替换 FFN，保留其他

回顾上一篇，Transformer 每层有两大块：

```
标准 Transformer Block:
  ┌─────────────────────────┐
  │  RMSNorm                 │
  │  Self-Attention          │  ← MoE 不动这里
  │  Residual (+)            │
  │  RMSNorm                 │
  │  Feed Forward Network    │  ← MoE 替换这里
  │  Residual (+)            │
  └─────────────────────────┘
```

**MoE 只把 FFN 替换成"多个专家 + 路由器"**，其他不变。

### 2.2 为什么偏偏替换 FFN？

```
一个 3B Dense 模型的参数分布:
  Embedding:        5%
  Self-Attention:   25%
  FFN:              65%  ← 大头！
  其他:             5%

FFN 占 60-70% 参数，拆分它能最大化"稀疏激活"的收益。

而 Self-Attention 不能拆，因为：
  - Attention 本质是 token 之间的"交流"，没办法说"今天这批 token 只跟其中一半交流"
  - Attention 的参数量相对小
```

### 2.3 MoE FFN 的结构

```
Dense FFN:
  ┌─────────────────────────────┐
  │  Input (2048 维)              │
  │        ↓                     │
  │  Linear 2048 → 8960          │
  │        ↓                     │
  │  SwiGLU                     │
  │        ↓                     │
  │  Linear 8960 → 2048          │
  │        ↓                     │
  │  Output (2048 维)             │
  └─────────────────────────────┘
  参数量: ~37M per layer

MoE FFN (8 专家, Top-2):
  ┌─────────────────────────────────────────┐
  │  Input (2048 维)                          │
  │        ↓                                 │
  │  ┌──────────────┐                        │
  │  │  Router      │  ← 一个小神经网络       │
  │  │  2048 → 8    │    输出 8 个分数       │
  │  └──────────────┘                        │
  │        ↓                                 │
  │  选 Top-2 (比如 Expert 3 和 Expert 7)    │
  │        ↓                                 │
  │  ┌──────────────────────────────────┐    │
  │  │  Expert 0 (FFN)  [未激活]         │    │
  │  │  Expert 1 (FFN)  [未激活]         │    │
  │  │  Expert 2 (FFN)  [未激活]         │    │
  │  │  Expert 3 (FFN)  [激活, 权重 0.6] │    │
  │  │  Expert 4 (FFN)  [未激活]         │    │
  │  │  Expert 5 (FFN)  [未激活]         │    │
  │  │  Expert 6 (FFN)  [未激活]         │    │
  │  │  Expert 7 (FFN)  [激活, 权重 0.4] │    │
  │  └──────────────────────────────────┘    │
  │        ↓                                 │
  │  输出 = 0.6 × Expert3(x) + 0.4 × Expert7(x) │
  │        ↓                                 │
  │  Output (2048 维)                         │
  └─────────────────────────────────────────┘
  参数量: ~296M per layer (8 × 37M)
  但每 token 只用: ~74M (2 × 37M)
```

### 2.4 替换的具体细节：从 Dense FFN 到 MoE FFN

前面给了结构图，但一个关键问题还没回答：

> **怎么从一个"普通 FFN"替换成"8 个专家 + 路由器"？这个替换到底怎么做的？**

这节把替换的每个工程细节讲透。

#### 2.4.1 关键认知：每个专家就是一个"完整的迷你 FFN"

这是最容易误解的地方。很多人以为 MoE 是"把一个大 FFN 切成 8 片"，其实**不是**：

```
❌ 错误理解: 把 Dense FFN 的 8960 维"切成 8 份"，每片 1120 维
            → 这不是 MoE，这只是"参数分组"

✅ 正确理解: 用 8 个"完整的小型 FFN"代替原来那个大 FFN
            每个小 FFN 内部结构跟原版一模一样
            只是维度缩小了
```

#### 2.4.2 替换时的具体维度变化

看 Mixtral 8×7B 的真实替换方案：

```
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
替换前：Dense 7B 模型的 FFN（每层 1 个大 FFN）
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
  W_up:   [4096, 14336]  ← 扩展到 14336
  W_gate: [4096, 14336]
  W_down: [14336, 4096]  ← 压回 4096
  
  参数量: 3 × 4096 × 14336 ≈ 176M
  
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
替换后：MoE 8×7B 的每层（8 个小专家 + 1 个 Router）
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
Router:
  W_router: [4096, 8]     ← 极小，只算选哪个专家
  参数量: 32K

Expert 0 (完整小 FFN):
  W_up:   [4096, 14336]  ← 注意！维度跟 Dense FFN 一样
  W_gate: [4096, 14336]
  W_down: [14336, 4096]
  参数量: 176M
  
Expert 1: 同样结构 = 176M
Expert 2: 同样结构 = 176M
...
Expert 7: 同样结构 = 176M

总参数: 8 × 176M + 32K ≈ 1.4B
```

**关键观察**：

- **每个专家的内部结构跟原 Dense FFN 完全一样**（W_up, W_gate, W_down 三矩阵）
- **每个专家的中间维度也一样**（还是 14336）
- **变化是"有 8 份"而不是"每份变小"**

所以名字 "Mixtral 8×7B" 的含义：
- **8** = 8 个专家
- **×7B** = 每个专家大概 7B 参数
- **但每次只激活 2 个** → 实际计算量 ≈ 14B

#### 2.4.3 有些模型是"切小"的（DeepSeek 风格）

Mixtral 的"专家跟原 FFN 同维度"策略不是唯一选择。**DeepSeek-MoE 采用了"切小但更多"的策略**：

```
DeepSeek-MoE 16B 的做法:

传统 Mixtral 风格:
  8 个专家 × 每个 14336 维 → 总容量巨大，但激活粒度粗

DeepSeek 风格 (细粒度专家):
  64 个专家 × 每个 1792 维 (= 14336 / 8)   ← 每个专家"变窄" 8 倍
  每 token 激活 6 个专家 (不是 2 个)
  
  总容量: 64 × 1792 = 114688 维（跟 Mixtral 8×14336 类似）
  但激活组合数: C(64, 6) = 7470 万种 ← 组合爆炸
```

**两种替换策略对比**：

| | Mixtral 风格 | DeepSeek 风格 |
|---|---|---|
| 专家数量 | 少（8 个） | 多（64 个） |
| 每个专家大小 | 大（跟原 FFN 一样） | 小（切成 1/8） |
| Top-K | Top-2 | Top-6 或 Top-8 |
| 激活组合 | C(8,2) = 28 | C(64,6) = 7470 万 |
| 专业分化 | 粗粒度 | 细粒度 |
| 训练难度 | 低 | 高（负载均衡更难） |

#### 2.4.4 替换后的完整计算流程

看一下**同一个 token 走过 MoE FFN 的完整过程**：

```
输入: token 向量 x (4096 维)
          │
          ▼
┌────────────────────────────────────────────────┐
│  Step 1: Router 选专家                          │
│                                                 │
│    logits = x · W_router       [4096, 8]       │
│    → [0.1, 0.02, 0.3, 0.5, 0.01, 0.04, 0.02, 0.01] │
│                                                 │
│    Top-2 选出:                                   │
│    Expert 3 (权重 0.5) 和 Expert 2 (权重 0.3)    │
│                                                 │
│    重新归一化权重:                               │
│    weight_3 = 0.5 / (0.5+0.3) = 0.625           │
│    weight_2 = 0.3 / (0.5+0.3) = 0.375           │
└────────────────┬───────────────────────────────┘
                 ▼
┌────────────────────────────────────────────────┐
│  Step 2: 只运行选中的 2 个专家                   │
│                                                 │
│   Expert 3:                                     │
│     up_3   = x · W_up_3     [4096, 14336]      │
│     gate_3 = x · W_gate_3   [4096, 14336]      │
│     hidden_3 = SiLU(gate_3) × up_3              │
│     out_3   = hidden_3 · W_down_3  [14336, 4096]│
│                                                 │
│   Expert 2:                                     │
│     同上，用 Expert 2 的权重计算                 │
│     得到 out_2                                  │
│                                                 │
│   (Expert 0, 1, 4-7: 完全不参与计算，省算力)     │
└────────────────┬───────────────────────────────┘
                 ▼
┌────────────────────────────────────────────────┐
│  Step 3: 加权合并两个专家的输出                   │
│                                                 │
│   final = 0.625 × out_3 + 0.375 × out_2        │
│                                                 │
│   → 回到 4096 维，跟 Dense FFN 的输出形状完全一样 │
└────────────────┬───────────────────────────────┘
                 ▼
            Output: 4096 维
            (给下一层 Attention 用，跟 Dense 无缝接上)
```

**为什么这个替换能"无缝"？**

因为 MoE FFN 的**输入输出形状跟 Dense FFN 完全相同**——都是 4096 维进、4096 维出。对外部（Attention 层、残差连接）来说，看不出任何区别。

#### 2.4.5 完整的 Swift 心智模型

```swift
// Dense FFN（原版）
class DenseFFN {
    let W_up: [[Float]]      // [4096, 14336]
    let W_gate: [[Float]]    // [4096, 14336]
    let W_down: [[Float]]    // [14336, 4096]
    
    func forward(x: [Float]) -> [Float] {
        let up = matmul(x, W_up)
        let gate = silu(matmul(x, W_gate))
        let hidden = elementwise_mul(up, gate)
        return matmul(hidden, W_down)
    }
}

// ↓↓↓ 替换后 ↓↓↓

// MoE FFN（替换后）
class MoEFFN {
    let router: Router
    let experts: [DenseFFN]   // ⭐ 核心：每个专家就是一个完整的 DenseFFN！
    let numExperts = 8
    let topK = 2
    
    func forward(x: [Float]) -> [Float] {
        // Step 1: Router 选专家
        let (selectedExpertIds, weights) = router.route(x: x, topK: topK)
        
        // Step 2: 只调用选中的专家（稀疏激活！）
        var outputs: [[Float]] = []
        for expertId in selectedExpertIds {
            let expertOutput = experts[expertId].forward(x: x)  // 调用小 DenseFFN
            outputs.append(expertOutput)
        }
        
        // Step 3: 加权合并
        var final = [Float](repeating: 0, count: 4096)
        for (output, weight) in zip(outputs, weights) {
            for i in 0..<4096 {
                final[i] += weight * output[i]
            }
        }
        return final
    }
}

// Router (超级简单)
class Router {
    let W: [[Float]]  // [4096, 8]
    
    func route(x: [Float], topK: Int) -> (expertIds: [Int], weights: [Float]) {
        let logits = matmul(x, W)           // [8]
        let probs = softmax(logits)
        
        // 选 Top-K
        let sorted = probs.enumerated().sorted { $0.element > $1.element }
        let topKItems = sorted.prefix(topK)
        
        // 重新归一化
        let sum = topKItems.reduce(0) { $0 + $1.element }
        let ids = topKItems.map { $0.offset }
        let weights = topKItems.map { $0.element / sum }
        
        return (ids, weights)
    }
}
```

**关键代码解读**：

```swift
let experts: [DenseFFN]   // 核心思想就这一行！
```

MoE 其实就是把**一个 DenseFFN 替换成 "8 个 DenseFFN 组成的数组 + 一个 Router"**。结构上是"封装"关系，不是"切分"关系。

#### 2.4.6 替换可行性分析：为什么数学上成立？

最后一个疑问：**为什么这样替换不会破坏模型？**

Dense FFN 的本质功能是：
```
f(x) = Linear(SiLU(Gate(x)) × Up(x))
```

MoE FFN 把它替换成：
```
f(x) = Σ w_i × expert_i(x)    (只在选中的专家上求和)
     = w_3 × f_3(x) + w_2 × f_2(x)
```

**这仍然是一个"从 x 映射到输出"的函数**，只是具体计算方式变了。关键性质**全部保留**：

| 性质 | Dense FFN | MoE FFN |
|---|---|---|
| 输入输出形状 | 4096 → 4096 | 4096 → 4096 ✅ |
| 可微分（能训练） | ✅ | ✅ |
| 非线性 | SwiGLU 提供 | 每个专家里的 SwiGLU 提供 ✅ |
| 残差连接兼容 | ✅ | ✅ |
| 位置无关（每 token 独立） | ✅ | ✅ |

所以 MoE FFN 可以**直接替换 Dense FFN**，不用改 Attention、不用改残差、不用改位置编码。这种"即插即用"的特性是 MoE 能快速普及的关键。

#### 2.4.7 一张图总结替换思路

```
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
Dense 模型                     MoE 模型
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

  Attention (保留不变)  ─────▶ Attention (保留不变)
        ↓                          ↓
    Add + Norm                 Add + Norm
        ↓                          ↓
  ┌────────────┐            ┌──────────────┐
  │            │            │   Router     │  ← 新增
  │  Dense FFN │   替换为   ├──────────────┤
  │  (1 个大的)│  ────────▶ │  Expert 0    │
  │            │            │  Expert 1    │  ← 把 1 个大 FFN
  │            │            │  Expert 2    │     变成 N 个完整小 FFN
  │            │            │  ...         │
  │            │            │  Expert N-1  │
  └────────────┘            └──────────────┘
        ↓                          ↓
    Add + Norm                 Add + Norm
        ↓                          ↓
  下一层 Attention            下一层 Attention
```

**核心三句话总结**：

1. **不是"拆分"，是"复制+增加"**：把一个 FFN 替换成 N 个同结构的 FFN + 一个 Router
2. **输入输出接口完全不变**：对其他组件（Attention、残差、LayerNorm）完全透明
3. **每次只选 K 个专家跑**：稀疏激活的本质——总参数大，但激活参数少

---

## 三、Router 路由器：MoE 的大脑

### 3.1 Router 长什么样？

**超级简单**：就是一个线性层 + softmax。

```swift
// 完整的 Router 实现
class Router {
    let weights: [[Float]]  // [2048, n_experts]，比如 [2048, 8]
    
    func route(tokenEmbedding: [Float], topK: Int = 2) -> [(expertId: Int, weight: Float)] {
        // 1. 线性变换得到每个专家的分数
        let scores: [Float] = matmul(tokenEmbedding, weights)  // 8 维
        
        // 2. Softmax 归一化成概率
        let probs = softmax(scores)
        // probs = [0.05, 0.02, 0.08, 0.60, 0.03, 0.05, 0.02, 0.15]
        
        // 3. 取 Top-K
        let sorted = probs.enumerated().sorted { $0.element > $1.element }
        let topK = sorted.prefix(topK)
        // topK = [(3, 0.60), (7, 0.15)]
        
        // 4. 重新归一化（让选中的专家权重加起来 = 1）
        let sum = topK.reduce(0) { $0 + $1.element }
        return topK.map { (expertId: $0.offset, weight: $0.element / sum) }
        // 最终: [(3, 0.80), (7, 0.20)]
    }
}
```

### 3.2 Router 怎么"学会"选专家？

这是 MoE 最神奇的地方。**你不需要手动告诉 Router 哪个专家擅长什么**。它是**训练出来的**。

```
训练流程:
  1. 初始化时，Router 是随机的，专家分化也随机
  2. 训练样本过来（比如一道数学题）
  3. Router 随便选了两个专家（比如 Expert 1 和 Expert 5）
  4. 计算损失（模型回答对不对）
  5. 反向传播更新参数，包括:
     - Expert 1 和 Expert 5 的参数（它们刚处理过这题）
     - Router 的参数（它选了这两个专家）
  6. 下次遇到类似的题，Router 会更倾向于选 Expert 1 和 Expert 5
     而 Expert 1 和 Expert 5 因为多次处理数学题，也更擅长数学
  
  → 自然形成"专业化"
```

### 3.3 专家真的"专业"吗？

这是个有争议的问题。研究发现：

**真正会发生的专业化**：

- 有些专家偏向**代码**
- 有些专家偏向**中文** vs **英文**
- 有些专家偏向**数学/数字**
- 有些专家偏向**对话逻辑**

**不会发生的专业化**：

- 没有专家叫"历史专家"/"地理专家"
- 专家不按"学科"分，而按**token 特征**分
- 专家可能出现"一般专家"（什么都处理一点）

### 3.4 负载均衡：MoE 训练的最大挑战

这是 MoE 训练里**最重要但也最抽象**的工程问题。很多人看完还是不明白。我们用最通俗的方式，从"问题本身"到"解决方案原理"，用具体例子彻底讲透。

#### 3.4.1 问题：为什么会"负载不均衡"？

要理解为什么会不均衡，先看 MoE 训练的初始状态：

```
训练刚开始时:
  Router 的参数是随机初始化的
  → 它"乱选"专家
  → 刚好给某几个专家分了多一点 token

第 1 个 token:   Router 偶然多选了 Expert 3  
第 10 个 token:  Router 又偶然多选了 Expert 3
第 100 个 token: Expert 3 已经处理了不成比例的 token

导致:
  Expert 3 被训练得更好（见得多学得多）
  其他专家被训练得差（见得少学不会）
```

#### 3.4.2 恶性循环：富者越富，穷者越穷

关键问题是：**训练越多的专家，下次 Router 越倾向于选它**。

```
时间线:

Epoch 1:
  Expert 3 处理了 15% 的 token  (随机偏差)
  Expert 3 的能力 > 其他专家 (因为多训练了)
  
Epoch 2:
  Router 学会: "选 Expert 3 损失更小" (因为它表现好)
  Expert 3 处理了 30% 的 token
  能力进一步提升
  
Epoch 3:
  Router: "Expert 3 真的很好，几乎总选它"
  Expert 3 处理了 60% 的 token
  其他 7 个专家几乎完全不被训练

Epoch 10:
  Expert 3: 处理 80%+ token，能力超强
  Expert 0-2, 4-7: 几乎没训练过，跟初始化差不多
  → MoE 退化成了一个"Expert 3 + 7 个废物"的模型
  → 等于变成了 Dense 1 × 7B，还浪费了 7 × 7B 的内存
```

#### 3.4.3 具体例子：一个 batch 的不均衡

用具体数字看看"不均衡"长什么样。

**先搞懂 `1000 × 2 / 8 = 250` 这个公式**

公式里每个数字都有明确含义：

| 数字 | 含义 |
|---|---|
| `1000` | batch 里的 **token 数**（这里举例用小数字，真实训练是百万级） |
| `× 2` | **Top-K=2**，每个 token 会同时选 **2 个**专家，所以贡献 2 次"被选中" |
| `/ 8` | 一共有 **8 个专家**，总分配量平均分给它们 |
| `= 250` | 理想情况下，每个专家应该处理的 token 数 |

拆成两步看更清楚：

```
Step 1: 算总分配次数
  总分配 = token 数 × Top-K
         = 1000 × 2
         = 2000 次"专家分配"

Step 2: 平均分给每个专家
  每个专家理论处理量 = 总分配 / 专家数
                    = 2000 / 8
                    = 250
```

**不同 Top-K 的对比：**

| 路由策略 | 公式 | 每个专家处理量 |
|---|---|---|
| Top-1 | 1000 × 1 / 8 | 125 |
| **Top-2**（常见） | 1000 × 2 / 8 | **250** |
| Top-4（DeepSeek-V3） | 1000 × 4 / 8 | 500 |

**澄清：batch / token / epoch 的关系**

客户端同学常会把 "batch" 理解成"一轮训练"，其实不是：

| 概念 | 含义 | 数量级 |
|---|---|---|
| **Token** | 最小处理单元（一个字 / 词片段） | 一个序列包含几百~几千个 |
| **Sequence**（样本） | 一段完整文本，比如一篇文章 | 几百~几千个 token |
| **Batch**（批次） | **一次前向传播同时处理的样本集合** | 几十~几千个 sequence |
| **Step**（一步） | 一次 `forward + backward + 参数更新` | **处理 1 个 batch** |
| **Epoch**（一轮） | 整个训练集完整过一遍 | 包含 N 个 step |

所以：

- **batch ≠ 一轮训练**，batch 只是"一次 step 里同时喂给模型的数据"
- **一个 batch 里通常有百万级 token**，例如 `batch_size=512, seq_len=2048 → 约 100 万 token`
- **负载均衡是在"一个 batch 内"统计的**：这 100 万 token 选 Top-2 专家 → 产生 200 万次分配 → 理想平均每个专家 25 万次

文档里用 "1000 个 token" 只是为了**举例好算**，真实训练场景数字要乘以 1000 倍以上，但公式完全一样。

**回到例子：**

```
假设一个 batch 有 1000 个 token，8 个专家，Top-2:
  理论上每个专家应该处理约 1000 × 2 / 8 = 250 个 token

平衡的情况（理想）:
  Expert 0: 245 tokens  ✅
  Expert 1: 253 tokens  ✅
  Expert 2: 258 tokens  ✅
  Expert 3: 241 tokens  ✅
  Expert 4: 249 tokens  ✅
  Expert 5: 252 tokens  ✅
  Expert 6: 251 tokens  ✅
  Expert 7: 251 tokens  ✅
  → 每个专家都得到训练

不平衡的情况（灾难）:
  Expert 0: 50 tokens   ❌ 训练不足
  Expert 1: 30 tokens   ❌
  Expert 2: 20 tokens   ❌
  Expert 3: 800 tokens  ⚠️ 过度训练
  Expert 4: 40 tokens   ❌
  Expert 5: 30 tokens   ❌
  Expert 6: 20 tokens   ❌
  Expert 7: 10 tokens   ❌
  → Expert 3 成了"总代表"，其他专家废了
```

#### 3.4.4 解决方案：加一个"惩罚项"

解决思路**非常直接**：**在训练损失里加一个"惩罚项"，只要负载不均衡就扣分**。

**类比：公司 OKR 考核**

```
原本只考核: "业务指标"（主损失）
  → 结果老板只奖励业绩最好的一个团队
  → 其他团队得不到资源，能力跟不上

增加 OKR: "团队协作" = "各部门均衡发展"（辅助损失）
  → 如果某团队被分配的活过多/过少，扣这一项
  → 老板必须让所有团队都有活干
  → 公司整体能力更强
```

这就是 **Auxiliary Loss（辅助损失）** 的核心思想。

#### 3.4.5 辅助损失怎么算？—— 用"方差"衡量不均衡

数学上怎么定义"不均衡"？**方差**是最直觉的选择：

```
方差 = 各专家负载 与 平均负载 的偏差平方和

举例:
  8 个专家，平均负载 = 250

平衡情况（负载都接近 250）:
  偏差: 245-250=-5, 253-250=3, ...
  方差: (-5)² + 3² + ... ≈ 很小（比如 100）
  
不平衡情况（800 和 10 差距大）:
  偏差: 50-250=-200, 800-250=550, 10-250=-240, ...
  方差: (-200)² + 550² + ... ≈ 巨大（比如 500000）
  
方差越大 = 越不均衡 → 惩罚越多
```

**总损失公式**：

```
总损失 = 主损失（任务损失） + α × 辅助损失（方差）

其中 α 是权重系数，通常 0.01
```

#### 3.4.6 完整的 Swift 实现

```swift
// 训练一个 batch 时的完整损失计算
func trainingLoss(
    predictions: [Float],      // 模型输出
    targets: [Float],           // 期望输出
    routerDecisions: [[Int]]    // 每个 token 被路由到哪些专家
) -> Float {
    
    // ========== 主损失：模型预测准不准 ==========
    let mainLoss = crossEntropy(predictions, targets)
    
    // ========== 辅助损失：专家负载均不均衡 ==========
    
    // Step 1: 统计每个专家被选中的次数
    let numExperts = 8
    var expertCount = [Int](repeating: 0, count: numExperts)
    for tokenDecision in routerDecisions {
        for expertId in tokenDecision {
            expertCount[expertId] += 1
        }
    }
    
    // Step 2: 计算平均负载
    let totalAssignments = expertCount.reduce(0, +)
    let avgLoad = Float(totalAssignments) / Float(numExperts)
    
    // Step 3: 计算方差（不均衡度）
    var variance: Float = 0
    for count in expertCount {
        let diff = Float(count) - avgLoad
        variance += diff * diff
    }
    variance /= Float(numExperts)  // 取平均方差
    
    // Step 4: 总损失 = 主损失 + 权重 × 辅助损失
    let alpha: Float = 0.01  // 辅助损失的权重
    return mainLoss + alpha * variance
}
```

#### 3.4.7 训练过程可视化

看一下加了辅助损失后，训练过程会如何自动修正：

```
Epoch 1 (Router 初始化随机):
  Expert 负载: [120, 140, 100, 450, 110, 130, 120, 30]
  平均:        262.5 (不应该有这么多偏差)
  方差:        大
  主损失:      3.2
  辅助损失:    2.8 × α
  总损失:      5.2  ← 惩罚了不均衡
                    ↓ 反向传播
                    Router 的参数被更新
                    向"减少方差"的方向调整

Epoch 2:
  Expert 负载: [150, 180, 200, 400, 150, 170, 180, 70]
  方差:        变小了
  总损失:      3.8  ← 下降了

Epoch 3:
  Expert 负载: [230, 240, 260, 280, 250, 255, 245, 240]
  方差:        小
  总损失:      1.5

Epoch 10:
  Expert 负载: [249, 251, 253, 248, 252, 250, 249, 248]
  几乎完美均衡 ✅
```

**关键观察**：Router 其实**不知道**"要均衡分配"这件事，它只是**被损失函数推着**朝"不扣分"的方向走。因为不均衡会扣分，所以它自然学会了均衡分配。

#### 3.4.8 α 系数的调优艺术

辅助损失的权重 α 不是随便定的，这是 MoE 训练的**核心超参**：

```
α 太小 (比如 0.001):
  辅助损失几乎不起作用
  → 专家仍然会不均衡
  → MoE 退化

α 适中 (比如 0.01-0.02):  ← 常见选择
  惩罚力度适中
  → 专家均衡分配
  → 主任务不受干扰

α 太大 (比如 0.1):
  负载均衡"压过"了主任务
  → Router 过度追求"每个专家都用"
  → 破坏了"专家专业化"
  → 模型整体质量下降
```

**主流模型的 α 值**：

| 模型 | α 值 | 说明 |
|---|---|---|
| Switch Transformer | 0.01 | 经典值 |
| Mixtral | 0.02 | 略大，更强调均衡 |
| DeepSeek-MoE | 0.0001 | 极小，但搭配其他机制 |
| Qwen-MoE | 0.001 | 小，有互补技术 |

#### 3.4.9 现代 MoE 的升级方案

基础辅助损失（3.4.5~3.4.8 讲的）虽然有效，但有 **3 个已知缺点**：

| 缺点 | 说明 |
|---|---|
| **① 方差是软约束** | 只要总方差小就行，不保证每个专家都被用 —— 可能出现「3 个专家均衡，5 个废」仍然方差不大的情况 |
| **② 训练 / 推理不一致** | 训练时靠 loss 约束，**推理时没有 loss**，如果 Router 学得不够稳，推理时仍可能集中选某几个专家 |
| **③ α 难调** | α 太小 → 不平衡；太大 → 干扰主任务学习。不同模型规模、不同阶段的最佳 α 都不一样 |

为了解决这些问题，现代 MoE 引入了更聪明的机制。下面详细讲 **4 种主流方案**。

---

##### 方案 1：Expert Choice —— 反转路由方向

**核心思想：把"token 选专家"反过来，改成"专家选 token"。**

传统路由叫 **Token Choice**（token 来挑专家），新方案叫 **Expert Choice**（专家来挑 token）。

**对比图示：**

```
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
传统 Token Choice:
  每个 token 算出 8 个专家的得分 → 选 Top-2
  
  Token A → scores=[0.1, 0.9, 0.05, 0.8, ...] → 选 [1, 3]
  Token B → scores=[0.2, 0.85, 0.1, 0.7, ...] → 选 [1, 3]
  Token C → scores=[0.15, 0.9, 0.08, 0.75, ...] → 选 [1, 3]
  
  问题：所有 token 都挤去专家 1 和 3，完全不均衡！
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

新 Expert Choice:
  先算所有 token × 所有专家的 "亲和度矩阵"（1000 × 8）
  然后每个专家从这 1000 个 token 里挑它最喜欢的 Top-K 个
  
  Expert 0 挑走 [token 5, 17, 23, ...] 共 250 个
  Expert 1 挑走 [token 1, 8, 19, ...] 共 250 个
  Expert 2 挑走 [token 3, 12, 31, ...] 共 250 个
  ...
  
  天然保证：每个专家都处理正好 K 个 token！
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
```

**具体计算步骤：**

```
假设 batch 有 N=1000 个 token，E=8 个专家，每个专家容量 K=250

Step 1: 算亲和度矩阵 S ∈ R^(N × E)
  S[i][j] = token_i 和 expert_j 的匹配得分

Step 2: 对每一列（每个专家）独立做 Top-K
  Expert j 选出 S[:, j] 里得分最高的 K 个 token

Step 3: 每个 token 可能被 0 个、1 个、多个专家同时选中
  → 被选中次数 = 该 token 实际参与的专家数（自适应）
  → 热门 token 可能过 3~4 个专家
  → 冷门 token 可能过 0 个（被 residual 直接带过去）
```

**优缺点：**

| 维度 | 评价 |
|---|---|
| ✅ **完美均衡** | 每个专家处理量严格等于 K，不需要辅助损失 |
| ✅ **自适应计算量** | 难的 token 多调专家，简单 token 少调，智能分配算力 |
| ❌ **推理不友好** | 需要看到整个 batch 才能决定路由，**自回归解码时每次只有 1 个 token** → Expert Choice 退化 |
| ❌ **因果性问题** | 专家挑 token 时可能"偷看"未来 token 的信息，需要额外处理 |

**代表工作：** Google 2022 年的 `Expert Choice Routing` 论文，但主要用于**训练**或**双向编码器**（如 T5 MoE），**纯解码器模型（GPT 系）里用得少**。

---

##### 方案 2：Router 加噪声（Noisy Top-K）

**核心思想：在 Router 输出上加随机扰动，强制探索。**

**问题背景：**

```
训练初期，所有专家都是随机初始化的，能力差不多。
Router 也是随机初始化，但某一次 forward 时偶然偏向了 Expert 3。
→ Expert 3 被选中 → 得到梯度 → 变强一点点
→ Router 发现 Expert 3 变强 → 更倾向选它
→ 正反馈循环，其他专家永远没机会
```

这就是所谓的 **Winner-Takes-All**（赢家通吃）问题。

**解决方法：** 给 Router 的 logits 加噪声，破坏正反馈。

```python
# 传统 Router
logits = x @ W_router              # shape: (batch, num_experts)
top_k_experts = topk(logits, k=2)

# Noisy Top-K Router（Switch Transformer 采用）
noise = randn_like(logits) * softplus(x @ W_noise)  # 可学习的噪声幅度
logits_noisy = logits + noise
top_k_experts = topk(logits_noisy, k=2)
```

**关键设计：**

| 点 | 说明 |
|---|---|
| **可学习的噪声幅度** | `W_noise` 是另一个可训练矩阵，模型自己决定"这个位置需要多少噪声" |
| **softplus 保证正值** | 噪声幅度不能为负（否则反向放大 logits） |
| **只在训练时加** | 推理时关闭噪声（类似 Dropout 的 `eval()` 模式） |

**效果类比：强化学习的 ε-贪心**

```
无噪声 Router = 纯贪心：每次都选当前最优 → 容易局部最优
有噪声 Router = ε-贪心：偶尔尝试"次优选项" → 发现其他专家也能用
                  ↓
                 训练完成后，Router 学到的是"平均意义上最优"
                 而不是"随机初始化决定的最优"
```

**代表工作：** Switch Transformer（2021，Google）、GShard。

---

##### 方案 3：DeepSeek-V3 的无辅助损失策略（Bias-Based Routing）

**这是 2024 年末最前沿的方案，彻底抛弃辅助损失。**

**核心思想：给每个专家加一个"动态偏置"，根据最近被选次数自动调整。**

```python
# 传统：用 loss 惩罚不均衡（间接调整）
loss_total = loss_lm + α * loss_aux

# DeepSeek-V3：直接给 Router logits 加偏置（直接调整）
# 伪代码
for each_batch:
    logits = x @ W_router
    biased_logits = logits + bias  # bias shape: (num_experts,)
    selected = topk(biased_logits, k=2)
    
    # 更新 bias：冷门专家 bias 加，热门专家 bias 减
    for expert_j in range(num_experts):
        if load[expert_j] > target_load:
            bias[j] -= γ    # 降低它被选概率
        else:
            bias[j] += γ    # 提高它被选概率
```

**关键点：**

| 点 | 说明 |
|---|---|
| **bias 不参与反向传播** | 它是一个**统计量更新**（类似 BatchNorm 的 running_mean），不走梯度 |
| **γ 是调整速率** | DeepSeek-V3 用 `γ ≈ 0.001`，平滑调整 |
| **完全不加 loss** | 主损失就是交叉熵，没有任何辅助项 |
| **训练推理一致** | 训练时 bias 收敛到稳定值，推理时直接用这个值 |

**类比：城管调整商铺摊位**

```
城管每天巡视，看到:
  - 商铺 3 顾客爆满 → 把它的招牌拆小一点（bias 减）
  - 商铺 7 几乎没人 → 给它加个大灯牌（bias 加）
  
这是"强制干预"，不是"通过扣钱激励"（辅助损失）。
效果更直接、更可控。
```

**为什么这个方案强？**

```
辅助损失的问题：
  - loss 告诉 Router "应该均衡"，但 Router 可能在"语义质量"和"均衡"间纠结
  - 间接，有信息损失

Bias 路由的优势：
  - Router 专注学"哪个专家语义上最合适"
  - 均衡问题由 bias 独立负责，正交解耦
  - 两个目标不再互相干扰
```

**代表工作：** DeepSeek-V3（2024.12，671B 总参数，37B 激活）—— 这是目前最强的开源 MoE 之一，验证了该方案的有效性。

---

##### 方案 4：Fine-Grained Experts + Shared Experts（DeepSeek-MoE 风格）

**这是架构层面的优化，跟路由算法是正交的。**

**传统 MoE：** 少量大专家（如 Mixtral 8×7B 的 8 个专家）

**Fine-Grained MoE：** 很多小专家 + 几个共享专家

```
对比（保持总参数一致）:

传统方案：8 个专家，每个 7B，Top-2
  → 激活 2 × 7B = 14B

Fine-Grained：64 个专家（每个 0.875B）+ 2 个共享专家（0.875B 每个）
  → 每次从 64 个里选 Top-6 + 始终激活 2 个共享 = 8 × 0.875B = 7B
```

**好处：**

| 机制 | 作用 |
|---|---|
| **细粒度专家** | 专家分工更精细，每个专家学更窄的"技能" |
| **共享专家（Shared Experts）** | 始终激活，学"通用知识"，让路由专家专注"特殊知识" |
| **更灵活的组合** | Top-K 可以取更多个（比如 Top-6）而不显著增加算力 |

**类比：**

```
传统 MoE = 8 个全能工程师，每次派 2 个上
Fine-Grained = 64 个专科医生 + 2 个全科医生
             每次全科必到 + 派 6 个专科
             → 覆盖更全面，诊断更精准
```

**代表工作：** DeepSeek-MoE（2024）、Qwen2-MoE。

---

##### 四种方案对比

| 方案 | 核心机制 | 代表模型 | 是否仍需辅助损失 |
|---|---|---|---|
| **Expert Choice** | 专家挑 token | Google T5-MoE | 否（天然均衡） |
| **Noisy Top-K** | Router 加噪声 | Switch Transformer、GShard | 是（配合使用） |
| **Bias-Based** | 动态偏置项 | DeepSeek-V3 | **否**（完全取代） |
| **Fine-Grained + Shared** | 小专家 + 共享专家 | DeepSeek-MoE、Qwen2-MoE | 是（仍用，但 α 可以很小） |

**一句话选型：**

- 训练**小/中等规模 MoE** → Noisy Top-K + 辅助损失（成熟稳定）
- 训练**超大规模开源 MoE** → Bias-Based 路由 + Fine-Grained 专家（DeepSeek-V3 路线，SOTA）
- **双向编码器 MoE**（不是 GPT 系） → Expert Choice（完美均衡）

#### 3.4.10 一句话总结

> **负载均衡损失 = 一个额外的"惩罚项"，只要专家分配不均衡就扣分。**
>
> **它不直接告诉 Router "该怎么选"，而是通过损失函数让 Router "自然学会" 均衡分配——因为不均衡会被扣分，模型被迫往均衡方向优化。**
>
> **数学上用"方差"度量不均衡，α ≈ 0.01 是最常见的权重设置。**

#### 客户端视角

```
这块知识对客户端用户意味着什么？

1. 你用的 MoE 模型质量好不好，跟"训练时的负载均衡"直接相关
   - 训练得不好的 MoE：某几个专家极强，其他废物
   - 训练得好的 MoE：所有专家都有用，能力更全面

2. 为什么 Mixtral、DeepSeek 这些开源 MoE 普遍质量好
   → 因为他们在辅助损失上调参调得好

3. 测评 MoE 时可以关注"专家利用率"
   - 让模型跑一段文本，统计每层 Router 的选择分布
   - 如果某个专家被选中频率 >> 平均值 → 训练有问题
```

### 3.5 Expert Capacity：另一个实战 trick

另一个问题：如果某个专家被选的 token 太多，超出它的"容量"怎么办？

```
一个 batch 有 128 个 token
8 个专家，Top-2
理论上每个专家平均处理: 128 × 2 / 8 = 32 个 token

Expert Capacity = 1.25 × 32 = 40

如果 Router 给 Expert 3 选了 50 个 token:
  → 超出容量 10 个
  → 这 10 个 token 被 "drop"（跳过 MoE 层，用 residual 带过去）
```

### 3.6 每层独立：MoE 的"多层路由"真相

前面讲 Router 时给人的印象可能是"整个模型只有一个 Router"。但实际上——**每一层都有自己独立的 Router 和专家池**。

这是客户端同学最容易误解的地方。把它讲清楚。

#### 3.6.1 核心事实：28 层 MoE 就有 28 个 Router

```
Mixtral 8×7B 的真实结构 (32 层):

Layer 0:  Attention → Router_0 → 选专家 → FFN 计算
Layer 1:  Attention → Router_1 → 选专家 → FFN 计算  ← 独立！
Layer 2:  Attention → Router_2 → 选专家 → FFN 计算  ← 独立！
...
Layer 31: Attention → Router_31 → 选专家 → FFN 计算

每一层都有:
  ✅ 独立的 Router (参数不同)
  ✅ 独立的 8 个专家 (参数不同)
  ✅ 独立做路由决策
  ✅ 独立执行 FFN 计算
```

所以严格来说，Mixtral 8×7B **不是 8 个专家**，而是 **32 层 × 8 个 = 256 个专家**。"8" 只是每层的专家数。

#### 3.6.2 为什么每层都要重新做路由？

##### 原因 1：token 的"含义"每层都在变

回顾 03 文档的 Self-Attention 原理：

```
进入 Layer 0 时的 "苹果":  含义模糊（水果 or 公司？）
经过 Layer 0 处理:         融合上下文 → 偏向"公司"
进入 Layer 1 时的 "苹果":  已经是"苹果公司"
经过 Layer 1 处理:         进一步融合 → "苹果公司发布 iPhone"
进入 Layer 2 时的 "苹果":  更抽象的语义
...

每一层的 token 向量都在不断"变化"
→ 不同层的 token 需要不同的专家
→ 每层必须独立做路由决策
```

##### 原因 2：不同层的专家有不同的专业度

研究发现 MoE 不同层的专家会自动分化：

```
浅层 (Layer 0-5):
  Expert 处理: 标点、常用词、代码关键字、特殊符号
  
中层 (Layer 10-20):
  Expert 处理: 语法关系、主谓宾、修饰关系
  
深层 (Layer 25-31):
  Expert 处理: 因果推理、抽象概念、数学逻辑、跨长距离关联
```

每层的专家专注于"该层应该关注的抽象层次"。自然需要每层独立 Router。

#### 3.6.3 一个 token 走过 MoE 28 层的完整过程

用 Mixtral 处理 "你好" 这个 token 为例：

```
输入 token 向量 x_0
   │
   ▼
┌─ Layer 0 ────────────────────────────────────┐
│  Self-Attention (参数固定)                     │
│  Router_0(x) → 选 Layer0_Expert 3, 5         │  ← Router_0 专属本层
│  FFN: 0.7 × Expert_0.3(x) + 0.3 × Expert_0.5(x) │
│  输出 x_1                                      │
└──────────────────────────────────────────────┘
   │
   ▼
┌─ Layer 1 ────────────────────────────────────┐
│  Router_1(x) → 选 Layer1_Expert 2, 7         │  ← Router_1 选的不一样
│  FFN: 0.6 × Expert_1.2(x) + 0.4 × Expert_1.7(x) │
│  输出 x_2                                      │
└──────────────────────────────────────────────┘
   │
   ▼
┌─ Layer 2 ────────────────────────────────────┐
│  Router_2(x) → 选 Layer2_Expert 0, 6         │  ← 每层独立选！
│  ...                                          │
└──────────────────────────────────────────────┘
   │
   ▼
   ... 共 32 层 ...
   │
   ▼
输出: 最终 hidden state

总计:
  Router 被调用: 32 次 (每层 1 次)
  专家被激活:    32 × 2 = 64 次 (每层 Top-2)
  每层选的专家完全独立，可能完全不同
```

**注意命名**：

```
"Expert 0.3" = Layer 0 的第 3 号专家
"Expert 0.5" = Layer 0 的第 5 号专家
"Expert 1.3" = Layer 1 的第 3 号专家 (跟 Expert 0.3 完全不同！)
```

#### 3.6.4 Swift 心智模型

```swift
// MoE 模型的完整结构
class MoETransformer {
    // ⭐ 核心：每层都是独立的！
    let layers: [TransformerLayer]  // 32 层
    
    func forward(input: [Float]) -> [Float] {
        var x = input
        for layer in layers {  // 每层独立走一遍
            x = layer.forward(x)  // 每层都重新做 Attention + Router + 专家计算
        }
        return x
    }
}

class TransformerLayer {
    let attention: SelfAttention
    let moeFFN: MoEFFN   // ⭐ 每层有自己的 MoEFFN 实例
    
    func forward(x: [Float]) -> [Float] {
        let a = attention.forward(x)
        let out = moeFFN.forward(a)  // ⭐ 每层的 MoEFFN 独立做路由
        return out
    }
}

class MoEFFN {
    let router: Router           // ← 这一层专属的 Router
    let experts: [DenseFFN]      // ← 这一层专属的 8 个专家
    
    func forward(x: [Float]) -> [Float] {
        // 每次调用都要:
        let (ids, weights) = router.route(x: x, topK: 2)  // 重新路由
        
        var outputs: [[Float]] = []
        for id in ids {
            outputs.append(experts[id].forward(x: x))  // 重新计算选中的专家
        }
        return weightedSum(outputs, weights)
    }
}

// 注意:
// - 32 层 = 32 个独立的 MoEFFN 实例
// - 每个 MoEFFN 有自己独立的 Router (参数不共享)
// - 每个 MoEFFN 有自己独立的 8 个 Expert (参数不共享)
// - 总共 32 × 8 = 256 个不同的专家
```

#### 3.6.5 真实参数构成：Mixtral 8×7B 的完整账本

```
Mixtral 8×7B (32 层):

每层:
  Attention:       ~1 B 参数 (不是 MoE)
  Router:          4096 × 8 = 32K 参数 (极小)
  8 个专家:        8 × 176M = 1.4 B 参数
  层小计:          ~2.4 B 参数

总计 (32 层):
  Attention 总和:     32 × 1B = 32B
  Router 总和:         32 × 32K = 1M   ← 极少，可忽略
  专家总和:            32 × 1.4B = ~45B  ← 真正的"知识存储"
  Embedding + Output: ~1B
  
  总参数:              ~47B  ✅ 对上 Mixtral 8×7B 的命名

专家总数:
  32 层 × 8 专家 = 256 个独立专家
```

#### 3.6.6 推理时的完整开销

```
Mixtral 8×7B 生成 1 个 token 的开销:

每层开销:
  Attention:      ~2 GFLOPs     (1B 参数 × 2)
  Router:         ~0 GFLOPs     (32K 参数 × 2，极小)
  FFN (Top-2):    ~1.4 GFLOPs   (2 个专家 × 176M × 2)
  层小计:         ~3.4 GFLOPs

32 层总开销:
  3.4 GFLOPs × 32 = ~110 GFLOPs / token

注意:
  Router 在每层被调用，但因为参数极少 (32K/层)
  Router 的总开销 < 模型 FLOPs 的 0.1%
  → Router 的"每层都算"不是性能瓶颈
  → 真正的开销在 FFN 上 (即使只选 Top-2)
```

#### 3.6.7 一个重要现象：每层选的专家可能截然不同

这是 MoE 灵活性的关键来源：

```
一个 token "你好" 走过 Mixtral 32 层时，每层的选择可能是:

Layer 0:  选 Expert 3, 5   ← 可能是"处理问候语"的专家
Layer 1:  选 Expert 1, 4   
Layer 2:  选 Expert 0, 7
Layer 3:  选 Expert 2, 6
Layer 4:  选 Expert 3, 5   ← 巧合又选到了相同的专家
Layer 5:  选 Expert 1, 2
...
Layer 31: 选 Expert 2, 4

每层的选择完全独立！
```

这种独立性让 MoE 能做到：

- **浅层 Router** 学会"基于词汇特征选专家"
- **中层 Router** 学会"基于语法特征选专家"
- **深层 Router** 学会"基于语义特征选专家"
- 不同层的 Router 学会**不同抽象层次**的分工规则

#### 3.6.8 一句话总结

> **MoE 的每一层都有独立的 Router 和专家池，每一层都要重新做路由决策。**
>
> **"Mixtral 8×7B" 里的"8"是每层的专家数，实际全模型有 32 层 × 8 = 256 个不同的专家。**
>
> **这种"每层独立路由"是 MoE 灵活性的核心——浅层处理表面特征，深层处理抽象概念，各司其职。**

##### 客户端速记

```
常见误解 vs 真实情况:

❌ 误解: "整个模型只有一个 Router"
✅ 真实: 每层一个 Router，共 N 个 (N = 层数)

❌ 误解: "Mixtral 8×7B 共 8 个专家"
✅ 真实: 每层 8 个 × N 层 = 8N 个专家

❌ 误解: "专家在整个推理过程中保持激活"
✅ 真实: 每层重新选，一个 token 可能激活完全不同的专家组合

❌ 误解: "Router 计算量大"
✅ 真实: Router 极小 (32K 参数/层)，开销可忽略
```

---

## 四、计算量分析：MoE 到底省在哪里？

回顾 1.0 节讲的关键认知：**大模型推理的瓶颈是内存带宽，不是算力**。理解了这一点，MoE 的妙处才能真正体会到。

### 4.0 先澄清一个核心反直觉：MoE **不省参数**！

这是 MoE 最容易误解的地方。当你看到 Mixtral 8×7B 总参数 47B，比 Dense 7B 大 7 倍，你可能会问：

> "参数更多了，怎么还说 MoE '省'？"

**答案**：MoE 省的不是"总参数"，而是"每次推理所需的计算量"。你必须把**容量**和**计算量**分开看。

#### 核心概念：参数的"双重身份"

```
参数有两种"身份":

身份 1: 存储身份 (静态)
  参数存在文件里/内存里
  → 占存储、占 RAM
  → 这是"总参数量"

身份 2: 计算身份 (动态)
  每次推理时，参数是否参与矩阵乘法
  → 占 FLOPs、占内存读取带宽
  → 这是"激活参数量"

Dense 模型:  总参数 = 激活参数 (所有参数都要算)
MoE 模型:    总参数 ≫ 激活参数 (只算部分专家)
```

#### 一张表看清"省" vs "不省"

对比 Dense 7B 和 Mixtral 8×7B：

| 指标 | Dense 7B | Mixtral 8×7B | 变化 | MoE 省了吗？ |
|---|---|---|---|---|
| **总参数**（文件大小） | 7B | 47B | ⬆️ 涨 7 倍 | ❌ 不省，反而更大 |
| **激活参数**（每 token 用到的） | 7B | ~13B | ⬆️ 涨 ~2 倍 | ❌ 也涨了 |
| **存储空间 (Q4)** | 4 GB | 28 GB | ⬆️ | ❌ 不省 |
| **内存占用** | 4 GB | 28 GB | ⬆️ | ❌ 不省 |
| **每 token 计算量** | 14 GFLOPs | 26 GFLOPs | ⬆️ 涨 2 倍 | ❌ 也涨了 |
| **推理速度** | 基准 | 差不多 | ➡️ 持平 | - |
| **模型能力** | 7B 水平 | **接近 47B 水平** | ⬆️⬆️ | ✅ **大幅提升** |

**看明白了吗？** MoE 跟 Dense 7B 比，**各种"资源消耗"都涨了**。但它带来的"能力"是 Dense 47B 级别的。

#### 正确的比较方式：同能力比，MoE 才赢

要评估 MoE 的"省"，必须**跟能力相当的 Dense 模型对比**：

要达到"Mixtral 47B"的能力，你有两个选择：

**路线 A：用 Dense 47B**

```
Dense 47B:
  总参数:    47B
  激活参数:  47B  (每 token 都要全算)
  存储:     ~100 GB (FP16) / 28 GB (Q4)
  每 token: 94 GFLOPs ← 计算量巨大
  推理:     慢 (每次吃 94 GB 内存读取)
```

**路线 B：用 MoE 8×7B**

```
Mixtral 8×7B:
  总参数:    47B  (跟 Dense 47B 一样！)
  激活参数:  ~13B  (只激活 2/8 专家)
  存储:     ~100 GB (FP16) / 28 GB (Q4)  ← 存储一样
  每 token: 26 GFLOPs ← 计算量少 4 倍
  推理:     快 (每次只吃 26 GB 内存读取)
```

**同能力对比结果**：

| | Dense 47B | MoE 8×7B | 省了啥？ |
|---|---|---|---|
| 能力 | 基准 | 接近 | ➡️ 近似 |
| 内存占用 | 100 GB | 100 GB | ❌ 没省 |
| **计算量** | 94 GFLOPs | 26 GFLOPs | ✅ **省 4 倍** |
| **推理速度** | 基准 | **快 4 倍** | ✅ **快了** |
| 电费 / 云服务成本 | 基准 | 1/4 | ✅ **省 4 倍** |

**终于明白了**：
- **同等内存下**，MoE 比 Dense **快 4 倍**
- **同等速度下**，MoE 比 Dense **知识多 4 倍**
- **但**：MoE 的**内存占用跟 Dense 同级**，对内存敏感场景（iPhone）**不省**

#### 用 iOS 的类比彻底理解

```swift
// Dense 模型：一个小书架
struct DenseModel {
    let books: [Book]  // 100 本书（参数）
    
    func answer(question: String) -> Answer {
        // 每次都要翻完所有 100 本书
        return books.compactMap { $0.search(question) }.merge()
    }
}
// 书多 → 知识多，但每次查询都很慢

// MoE 模型：一个大图书馆，有 8 个分区
struct MoEModel {
    let sections: [[Book]]  // 8 个分区 × 每区 100 本 = 800 本（参数）
    let librarian: Router   // 图书管理员
    
    func answer(question: String) -> Answer {
        // 管理员告诉你: "这个问题去 3 号和 7 号分区找"
        let relevant = librarian.recommend(question)  // [3, 7]
        
        // 只翻 2 个分区的 200 本书（不是 800 本！）
        return relevant.flatMap { sections[$0].search(question) }.merge()
    }
}
// 知识量: 8 倍 (800 本)
// 查询速度: 跟 "翻 2 个分区" 差不多
// 占的空间: 800 本书的书架 (没省！)
```

#### 为什么不能用完就丢掉其他专家？

你可能会想：**"既然本轮不用的专家占内存，用完删掉行不行？"**

**不行**，因为：

```
原因 1: 下一个 token 可能需要不同的专家
  生成"你好"时:     Router 选 Expert 3, 7
  生成"，今天"时:   Router 选 Expert 1, 4, 2, 6 ← 完全不同！
  
  每个 token 都可能激活不同组合 → 所有专家必须随时待命

原因 2: 按需加载来不及
  从硬盘读 6B 参数 ≈ 几百毫秒
  推理一个 token ≈ 50 毫秒
  → 还没读完，token 就该生成完了
```

所以**所有专家必须全部装在内存里**，这就是 MoE "不省内存" 的根本原因。

### 4.0.1 精确计算：MoE "省算力" 到底省多少？

前面说 "MoE 比 Dense 47B 快 4 倍"，这个 "4 倍" 是怎么来的？精确地说它适用于哪个场景？这一节把数字都拆开讲清楚，避免被笼统说法误导。

#### K/N：MoE 节省算力的核心公式

MoE 的 "算力节省倍数"有一个简洁的数学关系：

```
单看 FFN 的算力比例:

Dense 模型 FFN 算力 = 单专家算力 × 总专家数 = f × N
MoE 模型 FFN 算力   = 单专家算力 × 激活数  = f × K

MoE / Dense = (f × K) / (f × N) = K / N
```

所以 MoE 在 **FFN 部分**相对 Dense 的算力比例就是 **K/N**（激活专家数 / 总专家数）：

```
Mixtral 8×7B (Top-2 of 8):    K/N = 2/8 = 1/4
Qwen2-MoE (Top-4 of 60):      K/N = 4/60 ≈ 1/15
DeepSeek-MoE (Top-6 of 64):   K/N = 6/64 ≈ 1/11
DeepSeek-V3 (Top-8 of 256):   K/N = 8/256 = 1/32
Phi-3.5-MoE (Top-2 of 16):    K/N = 2/16 = 1/8
```

**规律**：Top-K 越小、总专家数 N 越大，FFN 算力节省越多。这就是为什么 DeepSeek 系列用"细粒度 + 多专家"的设计。

#### ⚠️ 但要区分："FFN 算力" vs "全模型算力"

这是一个容易被忽视的细节。**K/N 只适用于 FFN 部分**，因为 Attention 不是 MoE，每次都要全部算：

```
一层的总算力 = Attention 算力 + FFN 算力

Attention 部分（不是 MoE）:
  每 token 都算，跟 Dense 一样

FFN 部分:
  Dense: 全部算
  MoE:   只算 Top-K 个专家
```

#### 具体例子：Mixtral 8×7B vs Dense 47B

把数字都摆出来：

```
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
Dense 47B 的每 token 算力
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
每层:
  Attention:        ~1B 参数 × 2 = 2 GFLOPs
  FFN (1.4B 参数):  1.4B × 2 = 2.8 GFLOPs
  每层总:           4.8 GFLOPs

32 层总算力: 4.8 × 32 = 154 GFLOPs/token

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
Mixtral 8×7B 的每 token 算力
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
每层:
  Attention:         ~1B × 2 = 2 GFLOPs   (跟 Dense 一样)
  FFN (Top-2 of 8):  2 × 176M × 2 = 704 MFLOPs = 0.7 GFLOPs
  Router:            极小，忽略
  每层总:            2.7 GFLOPs

32 层总算力: 2.7 × 32 = 86 GFLOPs/token
```

**两种维度的比例**：

| 维度 | Dense 47B | Mixtral 8×7B | 比例 |
|---|---|---|---|
| **仅 FFN 算力** | 90 GFLOPs | 22.5 GFLOPs | **1/4** ⭐ |
| **全模型算力** | 154 GFLOPs | 86 GFLOPs | **~1/2** ⭐ |

**看清楚了吗？**

- **"1/4"** 是指**仅看 FFN 部分**的算力（由 K/N = 2/8 决定）
- **"1/2"** 是**全模型**的实际比例（因为 Attention 分摊，收益被稀释）

#### 为什么全模型没有省 4 倍？

```
Dense 47B 的算力分布:
  Attention: 2 GFLOPs/层 (占 42%)
  FFN:       2.8 GFLOPs/层 (占 58%)
  
Mixtral 的算力分布:
  Attention: 2 GFLOPs/层 (占 74%)  ← Attention 占比反超！
  FFN:       0.7 GFLOPs/层 (占 26%)
  
MoE 省了 FFN 部分（省 4 倍）
但 Attention 还是照算
→ 全模型的节省被"稀释"到 ~1/2
```

**这是 MoE 的一个结构限制**：随着 K/N 变得越来越小，FFN 算力趋于 0，但 Attention 永远在。所以即使极端的 MoE（Top-2 of 256），全模型算力也不可能比 Dense 小 100 倍。

#### 不同 MoE 的节省倍数全表

| 模型 | N | K | K/N（FFN 比例） | 全模型算力比例 |
|---|---|---|---|---|
| **Dense 47B** | - | - | 1 | 1（基准） |
| **Mixtral 8×7B** | 8 | 2 | **1/4** | ~1/2 |
| **Phi-3.5-MoE** | 16 | 2 | 1/8 | ~1/3 |
| **DeepSeek-MoE 16B** | 64 | 6 | 1/11 | ~1/4 |
| **Qwen2-MoE 14B** | 60 | 4 | 1/15 | ~1/5 |
| **DeepSeek-V3 671B** | 256 | 8 | **1/32** | ~1/6 |

**观察**：

- 单看 FFN，MoE 的节省倍数 = N/K
- 全模型算下来，节省约 N/K 的 1/2
- Top-K 越小、N 越大，算力节省越明显（但训练难度也指数级上升）

#### 一句话总结 4.0.1

> **MoE 的算力节省倍数 = K/N（激活专家数 / 总专家数）。**
>
> **Mixtral 8×7B 的 "1/4" 来自 Top-2 of 8；看 FFN 部分精确是 1/4，看全模型约为 1/2（被 Attention 分摊）。**
>
> **相同能力下，越细粒度的 MoE（大 N、小 K）越省算力，但训练越难，内存也不省。**

#### 客户端速查

```
读到 "MoE 比 Dense 省 X 倍" 时，先问清楚:
  省的是 "FFN 算力" 还是 "全模型算力"？
  FFN 部分节省 = N/K
  全模型节省 ≈ (N/K) × 0.5

对比场景也要看清楚:
  vs "同总参数 Dense"    → 计算量省 ~N/K（巨大）
  vs "同激活参数 Dense"  → 计算量约相同（但知识容量多 N/K 倍）
  vs "同能力 Dense"      → 算力省 ~N/K 倍，内存占用相同
```

### 4.1 直观对比

```
假设一个 token 要处理:

Dense 7B 模型:
  Attention: 1B 参数参与
  FFN:       5B 参数参与
  总计:      ~7B 参数参与 / 每 token ~14 GFLOPs
             (每 token 的 FLOPs ≈ 2 × 参数量，见 1.0)

MoE 8×7B 模型 (Top-2):
  Attention: 1B 参数参与（跟 Dense 一样）
  FFN:       5B × 2 = 10B 参数参与（选中的 2 个专家）
  总计:      ~11B 参数参与 / 每 token ~22 GFLOPs

但 MoE 模型的"总知识量" = 总参数:
  Attention: 1B × 1    = 1B
  FFN:       5B × 8    = 40B
  总参数:    ~41-47B（跟 Mixtral 8×7B 对得上）
  
对比:
  Dense 需要 47B 总参数才能获得 47B 的知识 → 每 token 算 47B 参数
  MoE 只需要 11B 的激活参数           → 就能调用 47B 的知识容量
  
  → MoE 的计算效率 ≈ Dense 的 4×
```

#### ⚡ 但为什么实际速度接近 Dense 11B 而不是"慢 2 倍"？

这里就体现了 **FLOPs ≠ 速度** 的核心认知：

```
Dense 11B:
  每 token FLOPs:  22 GFLOPs
  每 token 读内存: 11 GB  ← 带宽瓶颈

MoE 8×7B (Top-2):
  每 token FLOPs:  22 GFLOPs  (跟 Dense 11B 一样)
  每 token 读内存: 11 GB      (只读激活的 2 个专家)
  
→ FLOPs 相同、内存读取量相同 → 速度近似相同
→ 但 MoE 的总知识量是 Dense 11B 的 4 倍！
```

**这就是 MoE 的魔法**：用"跟 Dense 相当的速度"获得"4 倍于 Dense 的知识容量"。

### 4.2 但是！内存不省

**这是 MoE 在端侧最大的痛点**：

```
计算时 只用 2 个专家
       ↓
但是这 8 个专家都必须在内存里！
       ↓
因为下一个 token 可能需要不同的 2 个专家
       ↓
内存占用 = Dense 8×7B = 巨大无比
```

```
Mixtral 8×7B (Q4 量化):
  计算量: 等同 Dense 14B       ← 速度像中等模型
  内存:   约 28 GB              ← 内存需求像超大模型
  
iPhone 完全跑不动（最多 8GB RAM）
```

---

## 五、MoE 的架构变种

### 5.1 Mixtral 风格（经典 MoE）

```
8 个独立专家，Top-2 激活
每个专家结构完全相同
路由器决定选哪 2 个
```

简单直接，是入门 MoE 的参考实现。

### 5.2 DeepSeek-MoE 风格（共享专家 + 细粒度专家）

DeepSeek 团队在 2024 年提出了两个关键改进：

```
DeepSeek-MoE v1:
  ┌─────────────────────────────────┐
  │  共享专家 (Shared Expert) × 1     │  ← 每个 token 都过这里
  │  处理"通用知识"                   │     (类似 Dense 的 FFN)
  ├─────────────────────────────────┤
  │  路由专家 (Routed Experts) × 64   │  ← 每个 token 选 Top-6
  │  处理"专门知识"                   │
  └─────────────────────────────────┘

改进 1: 共享专家
  → 所有 token 都需要的"通用能力"放在共享专家里
  → 路由专家专注于学"特化知识"
  → 避免每个路由专家都重复学通用知识

改进 2: 专家数量更多、更小
  → Mixtral: 8 个大专家
  → DeepSeek: 64 个小专家
  → 每个 token 选 6 个小的（不是 2 个大的）
  → 组合数爆炸：C(64,6) = 74,974,368 种可能
  → 更精细的专业分工
```

### 5.3 Qwen-MoE 风格

类似 DeepSeek，有共享专家 + 细粒度路由专家：

```
Qwen2.5-MoE-A14B:
  共享专家: 1 个
  路由专家: 64 个
  每 token Top-8
  总参数: ~14B
  激活参数: ~2.7B
```

### 5.4 GPT-4 (传言)

虽然 OpenAI 没公开，但业内广泛认为 GPT-4 也是 MoE：

```
传言的 GPT-4:
  8 或 16 个专家
  总参数: ~1.8T
  激活参数: ~280B
```

---

## 六、MoE 处理多模态的天然优势

回顾 06 文档提到的：MoE 处理图片时，Router 可以把视觉 token 路由给**视觉专家**。

### 6.1 为什么 Dense 处理多模态不那么"爽"？

```
Dense 3B 处理一张图片:
  ↓
图片被 CLIP 编码为 576 个视觉 token
  ↓
这 576 个视觉 token 和文本 token 一起喂给 Dense
  ↓
Dense 的 3B 参数要"同时理解"视觉和文本
  ↓
视觉能力和语言能力在同一套参数里竞争容量
```

### 6.2 MoE 的"自动分化"

```
MoE 8×3B 处理一张图片:
  ↓
视觉 token:    Router 学会选"视觉专长"的专家（比如 Expert 1, 5）
文本 token:    Router 学会选"语言专长"的专家（比如 Expert 3, 7）
分类 prompt:  Router 学会选"逻辑判断"的专家（比如 Expert 2, 6）
  ↓
每类任务都用**独立**的参数，不互相挤压
```

**这就是 Google Gemini、OpenAI GPT-4V 等多模态模型都采用 MoE 架构的原因**。

---

## 七、MoE 在端侧的挑战与曙光

### 7.1 三大挑战

```
挑战 1: 内存墙（最致命）
  所有专家必须加载到内存
  Mixtral 8×7B 需要 28 GB，iPhone 最多 8GB
  
挑战 2: 随机访问模式
  不同 token 激活不同专家
  → 内存访问模式不规则
  → Metal/ANE 难以充分优化
  
挑战 3: 工具链不成熟
  llama.cpp 对 MoE 支持在 2024 年才完善
  CoreML 对 MoE 支持更晚
  量化方案针对 Dense 优化，MoE 量化质量损失更大
```

### 7.2 端侧 MoE 的三条出路

**出路 1: 小型 MoE**

为端侧专门设计的小 MoE：

```
示例：
  OLMoE 1.3B   → 64 专家 × 20M，Top-8，激活 ~156M
  Phi-3.5-MoE  → 16 专家 × 3.8B，Top-2，激活 ~6.6B
  
针对端侧的小 MoE 特点:
  - 总参数 1-10B（可装下）
  - 激活参数 200M-2B（速度快）
  - 针对手机内存限制设计
```

**出路 2: Expert Offloading（专家卸载）**

把"冷门"专家放到闪存，内存只保留"热门"专家：

```
策略:
  1. 运行时统计每个专家被使用的频率
  2. Top 4 常用专家: 常驻内存 (~8 GB)
  3. 其余专家: 放在闪存（App Documents 目录）
  4. 遇到 cold expert 时，按需从闪存加载

性能:
  - iPhone NVMe 读速: ~2 GB/s
  - 加载一个 Q4 专家 (~500MB) 需要 ~250ms
  - 首次使用该专家会变慢，但之后可以 warm up

实现难度高，目前主要是学术项目
```

**出路 3: 设备升级**

```
趋势:
  iPhone 15 Pro:  8 GB RAM
  iPhone 16 Pro:  8 GB RAM（但带宽更高）
  未来 iPhone 17: 预期 12 GB RAM ← 可以跑更大 MoE
  iPad Pro M4:    16 GB RAM ← 已经可以跑 Mixtral 小尺寸
  Mac Studio:     192 GB RAM ← 随便跑
  
Apple Silicon 的 UMA（统一内存架构）对 MoE 天然友好:
  - CPU/GPU 共享同一块内存
  - 不需要在 GPU 显存和系统内存之间来回拷
  - Mac Studio 完全能跑 Mixtral 8×7B
```

---

## 八、当前端侧可用的 MoE 模型

### 8.1 按可行性排序

| 模型 | 总参数 | 激活参数 | Q4 文件大小 | 内存需求 | iPhone 可行性 |
|---|---|---|---|---|---|
| **OLMoE 1.3B** | 7B | 1.3B | ~4 GB | ~5 GB | ⚠️ iPhone 15 Pro 极限 |
| **Qwen2.5-MoE-A2.7B** | 14B | 2.7B | ~8 GB | ~10 GB | ❌ iPad Pro only |
| **DeepSeek-MoE 16B** | 16B | 2.8B | ~9 GB | ~11 GB | ❌ iPad Pro only |
| **Phi-3.5-MoE** | 42B | 6.6B | ~24 GB | ~28 GB | ❌ Mac only |
| **Mixtral 8×7B** | 47B | 13B | ~28 GB | ~32 GB | ❌ Mac only |

### 8.2 现实结论

**2025 年，MoE 在 iPhone 上的可行性还很有限。**

```
iPhone 端侧推理的实用选择:

首选: Dense 1-3B 量化模型
  - Qwen2.5 1.5B  (~1GB Q4)
  - Llama 3.2 3B  (~1.8GB Q4)
  - Phi-3 mini    (~2.2GB Q4)

高端: Dense 7B 量化（仅限 iPad Pro）
  - Qwen2.5 7B    (~4.5GB Q4)

MoE: 目前只适合
  - iPad Pro M4 以上
  - Mac Studio
  - 未来 RAM 更大的 iPhone
```

---

## 九、展望未来：为什么 MoE 是方向？

### 9.1 行业趋势

```
2023: Mixtral 8×7B 证明 MoE 可行
2024: DeepSeek-V3 (671B MoE) 达到 GPT-4 水平
      Qwen-MoE 系列大规模开源
      GPT-4 被实锤是 MoE 架构
2025: 端侧小型 MoE 开始出现 (OLMoE、Phi-3.5-MoE)

趋势明确:
  → 未来所有超大模型都会是 MoE
  → 随着端侧内存增大，MoE 会逐步下沉
```

### 9.2 为什么 Apple 会重视 MoE？

```
Apple Intelligence 当前架构（推测）:
  云端: Private Cloud Compute 跑大 MoE
  端侧: 3.18B Dense 模型
  
未来可能的方向:
  iPhone 17+ (更大内存): 小 MoE
  iPad Pro: 中等 MoE
  Mac Studio: 大 MoE
  
统一内存架构（UMA）是 MoE 的天然友军
```

### 9.3 客户端同学的应对

```
当前阶段 (2025):
  - 端侧主力是 Dense 1-3B
  - MoE 暂时停留在服务器
  - 学习 MoE 架构，理解原理

中期 (2-3 年):
  - 端侧 MoE 开始普及
  - 需要升级推理引擎支持
  - 需要重新设计内存管理

长期 (5+ 年):
  - MoE 可能成为主流
  - Apple Silicon 会有专门的 MoE 加速
```

---

## 十、这一篇的核心收获

1. **MoE = Dense 的 FFN 换成"路由器 + 多个专家"**，Attention 和其他结构不变
2. **稀疏激活**是 MoE 的核心：总参数大，但每 token 只算其中一小部分
3. **Router 是训练出来的**，不是手动指定，自然形成专业化
4. **负载均衡**是 MoE 训练的最大技术挑战，靠 auxiliary loss 解决
5. **MoE 不省内存**，所有专家都要加载到 RAM，这是端侧最大障碍
6. **DeepSeek 的细粒度 MoE + 共享专家** 是 2024 年的最佳实践
7. **MoE 处理多模态有天然优势**，Router 自动为视觉 token 选视觉专家
8. **iPhone 暂时跑不动 MoE**，iPad Pro M4 可以，Mac Studio 随便跑

---

## 下一步

理论到这里就够了，下一篇动手实战 → [05 - 端侧部署实践：从下载模型到跑起来的全流程](05-on-device-deployment.md)
