# 04 - MoE 模型（Mixture of Experts）详解

> 理解 MoE 架构 —— 如何用更少的计算获得更强的能力。

## 从 Dense 到 MoE：为什么需要 MoE？

### Dense 模型的困境

```
Dense Model 的问题：
参数越多 → 能力越强 → 但计算量也越大 → 手机跑不动

例如：
- 7B Dense 模型: 每次推理需要 7B 参数全部计算
- 70B Dense 模型: 每次推理需要 70B 参数全部计算 → iPhone 完全无法运行
```

### MoE 的核心思想

```
MoE 的解决方案：
虽然有很多参数，但每次只用其中一部分！

类比 iOS：
Dense = 一个 Massive ViewController，每次 viewDidLoad 都初始化所有 1000 个子视图
MoE   = 一个 UICollectionView，只加载屏幕上可见的 Cell（按需加载）

同样的"总容量"，MoE 的实际计算量小得多！
```

## MoE 架构详解

### 结构对比

```
Dense Model (每层):
┌──────────────────────────────────────┐
│  Self-Attention                      │
├──────────────────────────────────────┤
│  Feed-Forward Network (FFN)          │  ← 一个大的 FFN，所有 token 共用
│  [所有参数都参与计算]                  │
└──────────────────────────────────────┘

MoE Model (每层):
┌──────────────────────────────────────┐
│  Self-Attention                      │  ← 和 Dense 相同
├──────────────────────────────────────┤
│  Router (路由器)                      │  ← 决定每个 token 用哪些专家
│      │                               │
│      ├──▶ Expert 1 (FFN)  ✅ 被选中  │
│      ├──▶ Expert 2 (FFN)  ❌ 未选中  │
│      ├──▶ Expert 3 (FFN)  ✅ 被选中  │
│      ├──▶ Expert 4 (FFN)  ❌ 未选中  │
│      ├──▶ Expert 5 (FFN)  ❌ 未选中  │
│      ├──▶ Expert 6 (FFN)  ❌ 未选中  │
│      ├──▶ Expert 7 (FFN)  ❌ 未选中  │
│      └──▶ Expert 8 (FFN)  ❌ 未选中  │
│                                      │
│  每个 token 只激活 Top-K 个专家        │
│  (通常 K=2，即 8 选 2)                 │
└──────────────────────────────────────┘
```

### 用 iOS 代码类比

```swift
// Dense Model 的 FFN（伪代码）
class DenseFFN {
    let allParameters: [Float]  // 所有参数
    
    func forward(input: Tensor) -> Tensor {
        // 每次都使用全部参数计算
        return matmul(input, allParameters)
    }
}

// MoE Model 的 FFN（伪代码）
class MoEFFN {
    let experts: [Expert]  // 8 个专家
    let router: Router     // 路由器
    
    func forward(input: Tensor) -> Tensor {
        // 1. 路由器决定用哪些专家
        let (selectedExperts, weights) = router.route(input, topK: 2)
        
        // 2. 只计算被选中的专家
        var output = Tensor.zeros()
        for (expert, weight) in zip(selectedExperts, weights) {
            output += weight * expert.forward(input)
        }
        
        // 3. 加权合并结果
        return output
    }
}
```

## MoE 的关键概念

### 1. Router（路由器）

```
路由器的工作：
输入 token → Router → 输出: "用专家 1 和专家 3"

Router 本身也是学出来的，它学会了：
- "数学问题" → 选数学专家
- "代码问题" → 选代码专家  
- "中文问题" → 选中文专家

（实际上专家没有明确的"专业"标签，
  但训练后自然分化出不同专长）
```

### 2. Top-K 选择

```
Top-K = 2 的含义：
8 个专家中，每个 token 只用 2 个

计算量对比：
Dense 7B:  每个 token 计算 7B 参数
MoE 8x7B:  总参数 56B，但每个 token 只计算 ~14B (2x7B)

结果：MoE 用 Dense 模型 2 倍的计算量，获得 8 倍参数量的知识！
```

### 3. 共享专家 vs 独立专家

```
Mixtral 架构 (经典 MoE):
所有 8 个专家都是独立的，Router 选 Top-2

DeepSeek-V2 架构 (改进 MoE):
┌─────────────────────────────────────┐
│  共享专家 (Shared Expert)            │  ← 所有 token 都经过
├─────────────────────────────────────┤
│  路由专家 (Routed Experts)           │  ← 只选 Top-K 个
│  Expert 1 | Expert 2 | ... | Expert N│
└─────────────────────────────────────┘

共享专家处理通用能力，路由专家处理专业能力。
```

## MoE vs Dense 对比

| 维度 | Dense 3B | MoE 8x3B (Top-2) |
|------|----------|-------------------|
| **总参数量** | 3B | 24B |
| **激活参数量** | 3B | ~6B |
| **模型文件大小** | ~1.8GB (Q4) | ~14GB (Q4) |
| **每token计算量** | 3B | ~6B |
| **知识容量** | 一般 | 较大 |
| **推理速度** | 快 | 较慢（但比同知识量Dense快） |
| **内存占用** | 低 | 高（需加载所有专家） |

### MoE 在端侧的挑战

```
⚠️ MoE 的端侧困境：

1. 内存问题（最大挑战）
   - MoE 虽然每次只计算部分专家
   - 但所有专家参数都要加载到内存！
   - 例: Mixtral 8x7B 总参数 47B → 即使 Q4 也要 ~28GB → iPhone 无法承受

2. 当前可行的端侧 MoE 方案：
   - 小规模 MoE: 如 8x0.5B (总参数 4B，Q4 约 2.5GB)
   - 专家卸载: 只在内存放常用专家，其他放闪存（速度慢）
   - 等待更大内存的设备
```

## 端侧可用的 MoE 模型

| 模型 | 架构 | 总参数 | 激活参数 | Q4大小 | 可行性 |
|------|------|--------|---------|--------|--------|
| Qwen2.5-MoE-A2.7B | 14个专家选4 | ~14B | ~2.7B | ~8GB | iPad Pro 勉强 |
| DeepSeek-MoE 16B | 64个专家选6 | 16B | ~2.8B | ~9GB | iPad Pro 勉强 |
| Mixtral 8x7B | 8个专家选2 | 47B | ~13B | ~28GB | ❌ 不可行 |

> **现阶段结论**：MoE 在 iPhone 上的实际可行性有限，
> 但了解这个架构对理解 AI 发展方向非常有价值。
> 随着设备内存增长和优化技术进步，MoE 端侧部署前景广阔。

## MoE 的未来展望

```
趋势 1: 更小的 MoE
- 专门为端侧设计的小 MoE 模型 (如 4x1B)
- 用 MoE 架构获得比同大小 Dense 更好的效果

趋势 2: 专家卸载技术
- 常用专家放内存，冷门专家放闪存
- iPhone 的 NVMe 闪存速度很快，延迟可控

趋势 3: Apple 硬件升级
- iPhone 内存持续增大 (8GB → 12GB → 16GB)
- NPU 性能持续增强
- 未来运行中等 MoE 模型不是梦
```

## 下一步

理论够了，让我们动手！→ [05 - 端侧部署实践指南](05-on-device-deployment.md)
