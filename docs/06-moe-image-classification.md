# 06 - MoE 模型图片识别与分类：iOS 开发者完全指南

> 用 iOS 开发者熟悉的概念，深入理解端侧 MoE 模型如何"看懂"一张图片。

## 先回答一个问题：大模型怎么"看"图片？

作为 iOS 开发者，你一定用过 `UIImage`。但大模型不认识 `UIImage`，它只认识 **token**（数字序列）。

那问题来了：一张猫的照片，怎么变成模型能理解的数字？

```
┌─────────────────────────────────────────────────────────┐
│  你看到的                    模型看到的                    │
│                                                         │
│  🐱 一张猫的照片    →    [0.12, -0.34, 0.78, 0.56, ...] │
│  (RGB 像素)              (数千个浮点数 = "视觉 token")     │
│                                                         │
│  就像 iOS 里:                                            │
│  UIImage → CGImage → CVPixelBuffer → [Float]            │
└─────────────────────────────────────────────────────────┘
```

这个"像素 → 数字"的转换过程，就是**视觉编码器（Vision Encoder）**干的事。

---

## 端侧图片识别的完整流程

### 整体架构

```
一张图片从拍摄到被分类，经过这 4 步：

Step 1: 图片预处理
┌────────────────────────────────────┐
│  UIImage (任意大小)                  │
│       ↓ 缩放                       │
│  384×384 RGB (标准化)               │
│       ↓ 归一化                      │
│  [Float] 像素数组                   │
│  (384 × 384 × 3 = 442,368 个浮点数) │
└──────────────────┬─────────────────┘
                   ↓
Step 2: 视觉编码（mmproj / CLIP）
┌────────────────────────────────────┐
│  CLIP 视觉编码器                    │
│  (类似 CNN 卷积网络)                │
│       ↓                            │
│  576 个 "视觉 token"               │
│  每个 token 是一个 2048 维向量       │
│                                    │
│  类比: 把图片"翻译"成模型能读的语言   │
└──────────────────┬─────────────────┘
                   ↓
Step 3: 语言模型理解
┌────────────────────────────────────┐
│  [视觉token] + [文本token]          │
│  = 图片内容 + "请分类为猫/狗/鸟..."  │
│       ↓                            │
│  MoE / Dense 语言模型推理           │
│  Router 选择视觉理解专家            │
│       ↓                            │
│  输出: "cat"                        │
└──────────────────┬─────────────────┘
                   ↓
Step 4: 后处理
┌────────────────────────────────────┐
│  解析模型输出文本                    │
│  匹配预定义类别                     │
│  返回分类结果 + 置信度               │
└────────────────────────────────────┘
```

### 用 iOS 代码类比每一步

```swift
// Apple Vision 的图片识别（传统方案）：
let image = UIImage(named: "cat.jpg")!               // Step 1: 加载图片
let features = VNClassifyImageRequest()                // Step 2: 特征提取
let handler = VNImageRequestHandler(cgImage: image.cgImage!)
try handler.perform([features])                        // Step 3: 推理
let result = features.results?.first?.identifier       // Step 4: 获取结果
// 输出: "tabby_cat" — 从 1000 个固定类别中选一个

// 多模态大模型的图片识别（本项目实现）：
let imageData = image.jpegData(compressionQuality: 0.85)!  // Step 1: 图片转 JPEG
let bitmap = mtmd_helper_bitmap_init_from_buf(ctx, ptr, len) // Step 2: CLIP 视觉编码
let chunks = mtmd_tokenize(ctx, prompt, &bitmap, 1)        // Step 3: 图片+文本分词
mtmd_helper_eval_chunks(ctx, lctx, chunks, ...)            // Step 4: 视觉 token 注入 LLM
let token = llama_sampler_sample(sampler, lctx, -1)        // Step 5: 生成回答
// 输出: "这是一只橘色虎斑猫" — 自由文本，任意问题
```

**关键区别**：
- Apple Vision 的"特征提取"和"推理"是一步完成的黑盒，只能输出预定义类别
- 大模型把"视觉编码"和"语言理解"分成两步，中间通过**视觉 token**连接，可以回答任意问题

---

## 大模型 vs CoreML：图片是怎么被"认识"的？

这是理解两种方案最核心的差异。

### CoreML/Vision 的识别原理（传统 CNN）

```
CoreML MobileNet 怎么认识一张猫的照片：

Step 1: 卷积层提取边缘、纹理
┌─────────────────────────────────────────┐
│  输入: 224×224×3 RGB 像素                 │
│       ↓                                  │
│  Conv Layer 1: 检测边缘（横线、竖线、曲线） │
│  Conv Layer 2: 检测纹理（毛发、条纹）       │
│  Conv Layer 3: 检测部件（耳朵、眼睛、鼻子） │
│  Conv Layer 4: 检测整体（猫脸、猫身）       │
│       ↓                                  │
│  全局平均池化 → 1×1×1280 特征向量          │
└─────────────────────┬───────────────────┘
                      ↓
Step 2: 全连接层分类
┌─────────────────────────────────────────┐
│  1280 维特征 → 1000 维输出                │
│  每一维对应一个 ImageNet 类别              │
│       ↓                                  │
│  softmax → [猫: 0.87, 狗: 0.05, ...]     │
│       ↓                                  │
│  输出: "Egyptian_cat" (置信度 87%)         │
└─────────────────────────────────────────┘

特点：
✓ 极快 (5-8ms)
✓ 一次前向传播就出结果
✗ 只能输出 1000 个固定类别之一
✗ 不理解"为什么是猫"——只知道概率
✗ 想加新类别？重新训练整个模型
```

### 大模型的识别原理（Vision Transformer + LLM）

```
多模态大模型怎么认识一张猫的照片：

Step 1: CLIP 视觉编码器 (mmproj) — "看"图片
┌─────────────────────────────────────────────┐
│  输入: 384×384×3 JPEG 图片字节               │
│       ↓ stb_image 解码                      │
│  切割成 14×14 像素的 patches                 │
│  384÷14 = 27×27 = 729 个 patches            │
│       ↓                                     │
│  Vision Transformer (ViT)                    │
│  每个 patch → 一个向量 (embedding)            │
│  patches 之间做 self-attention               │
│  "左上角的 patch 是耳朵，和右边的 patch 连接"  │
│       ↓                                     │
│  Projection Layer                            │
│  把视觉向量映射到语言模型的维度空间             │
│       ↓                                     │
│  输出: 576 个"视觉 token"                    │
│  每个 token 是一个 2048/4096 维向量           │
│                                             │
│  类比 iOS:                                   │
│  像把一张图片 OCR 成了 576 个"视觉单词"        │
│  这些"单词"不是文字，而是数字向量              │
│  但语言模型能像理解文字一样理解它们             │
└─────────────────────┬───────────────────────┘
                      ↓
Step 2: 语言模型 — "理解"图片
┌─────────────────────────────────────────────┐
│  输入序列: [视觉token×576] + [文本token]      │
│                                             │
│  "图片说的是":                                │
│  [0.12,-0.34,...] [0.56,0.78,...] ...        │
│  ← 576 个视觉 token (CLIP 编码的图片内容)     │
│                                             │
│  "请描述这张图片":                             │
│  [1234] [5678] [9012] ...                   │
│  ← 文本 token (用户的提问)                    │
│                                             │
│  Transformer 层处理:                          │
│  视觉 token 和文本 token 做 cross-attention   │
│  模型"看到"图片的同时"听到"用户的问题           │
│       ↓                                     │
│  自回归生成: 逐字输出回答                      │
│  "这" → "是" → "一" → "只" → "橘" → "色" ... │
└─────────────────────────────────────────────┘

特点：
✓ 理解图片内容的语义，不只是分类
✓ 可以回答关于图片的任意问题
✓ 改 prompt 就能做不同任务（分类、描述、OCR）
✓ 支持中英文自由回答
✗ 较慢 (500ms-5s)
✗ 内存占用大 (500MB-4GB)
```

### 在端侧模型中，输入图片的完整数据流

下面是我们 App 中的实际代码执行路径：

```
用户在对话页选择一张照片
          ↓
┌─── ChatView.swift ───────────────────────────┐
│  PhotosPicker → UIImage → 缩放到 384×384      │
│  → jpegData(compressionQuality: 0.85)         │
│  → 存入 ChatMessage.imageData                 │
└──────────────────┬────────────────────────────┘
                   ↓
┌─── LlamaOnDeviceProvider.swift ──────────────┐
│  检测 hasImages && isMultimodalLoaded          │
│  → 走多模态路径: engine.generateWithImages()   │
└──────────────────┬────────────────────────────┘
                   ↓
┌─── LlamaEngine.swift (generateWithImages) ───┐
│                                               │
│  1. mtmd_helper_bitmap_init_from_buf()        │
│     JPEG 字节 → stb_image 解码 → RGB bitmap   │
│     (mtmd 内部自动处理格式转换和缩放)            │
│                                               │
│  2. prompt 中插入 <__media__> 标记             │
│     "<__media__>\n请描述这张图片"               │
│     → applyChatTemplate() 格式化               │
│                                               │
│  3. mtmd_tokenize()                           │
│     文本 + bitmap → 分词为 chunks:             │
│     [文本chunk1] [图片chunk] [文本chunk2]       │
│                                               │
│  4. mtmd_helper_eval_chunks()  ← 核心！        │
│     自动处理所有 chunks:                        │
│     ├─ 文本 chunk → llama_decode()             │
│     └─ 图片 chunk →                           │
│        ├─ CLIP 编码 (CPU, 1-3秒)              │
│        ├─ 构建 embedding batch                 │
│        │  (tokens=nil, embd=视觉向量指针)       │
│        ├─ 设置 position encoding               │
│        ├─ 处理 non-causal attention            │
│        └─ llama_decode() 注入视觉 token        │
│                                               │
│  5. llama_sampler_sample() 逐 token 生成      │
│     → UTF8StreamDecoder 解码                   │
│     → onToken 回调给 UI                       │
└───────────────────────────────────────────────┘
```

### 两种方案在端侧的关键差异

| 维度 | CoreML (MobileNet) | 大模型 (mtmd + LLM) |
|------|-------------------|-------------------|
| **输入格式** | CVPixelBuffer (固定 224×224) | JPEG/PNG 字节流 (任意大小) |
| **图片预处理** | 开发者手动缩放+归一化 | mtmd 内部自动处理 |
| **特征提取** | CNN 卷积层 (硬件加速) | Vision Transformer + CLIP |
| **推理方式** | 一次前向传播 → 概率分布 | 自回归逐 token 生成 |
| **输出格式** | 固定类别标签 + 置信度 | 自由文本（任意内容） |
| **硬件利用** | Neural Engine (专用芯片) | Metal GPU (通用计算) |
| **CLIP 编码** | 不需要 | CPU 上 1-3 秒 |
| **能否追问** | ❌ 不能 | ✅ "图里的猫是什么品种？" |
| **能否改任务** | ❌ 重新训练 | ✅ 改 prompt 即可 |

这是新手最常见的困惑：为什么多模态模型需要下载**两个** GGUF 文件？

```
传统文本模型（1 个文件）：
┌──────────────────────────┐
│  model.gguf               │
│  包含: 语言理解能力         │
│  输入: 文本 → 输出: 文本   │
└──────────────────────────┘

多模态模型（2 个文件）：
┌──────────────────────────┐     ┌──────────────────────────┐
│  model.gguf               │     │  mmproj.gguf              │
│  包含: 语言理解能力         │     │  包含: 视觉编码能力        │
│  接收: token → 输出: token │     │  接收: 像素 → 输出: token  │
└──────────┬───────────────┘     └──────────┬───────────────┘
           │                                │
           └────────── 合作推理 ──────────────┘

类比 iOS：
model.gguf  = ViewController (负责逻辑处理)
mmproj.gguf = UIImageView (负责图片理解)
两者配合才能完成图片识别
```

### mmproj 的内部结构

mmproj（Multimodal Projector）本质是一个 **CLIP 视觉编码器**：

```
mmproj 内部：
┌──────────────────────────────────────────┐
│  Patch Embedding                          │
│  把图片切成 14×14 的小块 (patches)         │
│  384÷14 = 27×27 = 729 个 patches          │
│                                           │
│  类比: 把 UICollectionView 切成 729 个 Cell │
├──────────────────────────────────────────┤
│  Vision Transformer (ViT)                 │
│  对每个 patch 做 self-attention            │
│  让每个 patch 知道其他 patch 的信息         │
│                                           │
│  类比: Cell 之间通过 delegate 通信          │
├──────────────────────────────────────────┤
│  Projection Layer                         │
│  把视觉特征映射到语言模型的维度空间          │
│  视觉空间 → 文本空间                       │
│                                           │
│  类比: 视觉数据转换为文本模型能读的 DTO      │
└──────────────────────────────────────────┘
```

---

## MoE 在图片识别中的角色

### 关键问题：MoE 的"专家"怎么处理图片？

当一张图片被送入 MoE 模型时，**Router（路由器）会为视觉 token 选择最擅长视觉理解的专家**：

```
普通文本输入:
"什么是 Swift？"
  → Router 选择: 专家 #3 (编程) + 专家 #7 (知识)

图片输入（经过 mmproj 编码后的视觉 token）:
[视觉token: 一只猫的特征]
  → Router 选择: 专家 #1 (物体识别) + 专家 #5 (场景理解)

"请分类这张图片"（文本 token）
  → Router 选择: 专家 #2 (分类逻辑) + 专家 #6 (格式输出)
```

**重点理解**：MoE 的 Router 是训练出来的。在处理图片任务时，它自动学会了把视觉 token 路由给"视觉专长"的专家。这不是程序员手动指定的，而是模型在海量图文数据上训练后自然形成的。

### iOS 类比：MoE 像一个高效团队

```swift
// 想象你的 App 团队有 8 个工程师（8 个专家）
// 每个人有不同的专长，但没有明确的 title

class MoETeam {
    let engineers = [Engineer](count: 8)  // 8 个专家
    let pm = ProjectManager()              // Router (PM 分配任务)
    
    func handleTask(_ task: Task) -> Result {
        // PM 根据任务类型，选 2 个最合适的人
        let assigned = pm.assign(task, topK: 2)
        // assigned 可能是:
        // - UI 类任务 → 选 engineer[0] + engineer[3]
        // - 网络类任务 → 选 engineer[2] + engineer[5]
        // - 图片类任务 → 选 engineer[1] + engineer[4]
        
        return assigned.map { $0.work(on: task) }
            .weightedMerge()  // 加权合并结果
    }
}
```

### 为什么 MoE 比 Dense 更适合多模态？

```
Dense 模型处理图片：
┌─────────────────────────────────┐
│  所有 3B 参数都用来处理            │
│  不管是文字还是图片，同一套参数     │
│  → 参数利用效率低                  │
│  → 文字能力和视觉能力互相挤占      │
└─────────────────────────────────┘

MoE 模型处理图片：
┌─────────────────────────────────┐
│  Router 自动选择视觉专长专家       │
│  文字任务用文字专家，图片用视觉专家  │
│  → 每类任务都有专门的参数          │
│  → 总知识量大，但计算量小           │
│  → "专业的事交给专业的人"          │
└─────────────────────────────────┘
```

---

## Apple 自带方案 vs MoE 大模型方案：全面对比

### 方案概览

iOS 上处理图片有**三种主要方案**：

```
方案 A: Apple Vision Framework（系统自带）
  UIImage → VNClassifyImageRequest → "cat" (置信度 0.92)
  
方案 B: CoreML 自定义模型（传统 ML）
  UIImage → MobileNetV3.mlmodel → "tabby cat" (top-5 概率)
  
方案 C: 多模态大模型（本项目实现）
  UIImage → mmproj → MoE LLM → "这是一只橘色虎斑猫，它正蜷缩在..."
```

### 详细对比表

| 维度 | Apple Vision | CoreML (MobileNet) | MoE 多模态大模型 |
|------|-------------|-------------------|----------------|
| **模型大小** | 系统内置 (0MB) | 14MB (MobileNetV3) | 500MB-3GB |
| **额外文件** | 无 | .mlmodel 文件 | .gguf + mmproj.gguf |
| **推理速度** | 5-20ms | 5-8ms (MobileNetV3) | 200-2000ms |
| **首次延迟** | 几乎无 | 模型加载 ~100ms | 模型加载 3-10秒 |
| **内存占用** | ~50MB | ~100MB (运行时) | 500MB-2GB |
| **ImageNet 精度** | ~85% top-1 | 75.2% (V3) / 76.1% (ResNet50) | 60-80% (取决于模型) |
| **分类数量** | ~1000 类 (固定) | 自定义 (需重新训练) | 任意类 (改 prompt 即可) |
| **零样本能力** | ❌ 不支持 | ❌ 不支持 | ✅ 支持 |
| **可解释性** | 低 (只有概率) | 低 (只有概率) | 高 (可解释推理过程) |
| **中文支持** | 标签为英文 | 取决于训练数据 | ✅ 原生支持 |
| **网络依赖** | 无 | 无 | 无（端侧推理） |
| **iOS 版本** | iOS 13+ | iOS 11+ | iOS 17+ |
| **GPU 利用** | Neural Engine | Neural Engine + GPU | Metal GPU |
| **电池影响** | 极低 | 极低 | 较高 (~2-5%/次推理) |
| **热状态影响** | 无 | 无 | 持续推理会触发降频 |

### 核心差异解析

#### 1. 固定类别 vs 开放类别（最大区别）

```swift
// Apple Vision: 只能识别预定义的 ~1000 个类别
let request = VNClassifyImageRequest()
// 输出: "tabby_cat" — 只能从固定列表中选

// 如果你想分类"奶茶品牌"或"建筑风格"？
// → 不行！必须重新训练模型

// ─────────────────────────────────────

// MoE 大模型: 改 prompt 就能分类任何东西
let prompt1 = "分类为: 猫/狗/鸟"           // → "猫"
let prompt2 = "分类为: 英短/美短/布偶/橘猫"  // → "橘猫"
let prompt3 = "这是什么品种的猫？"           // → "这看起来是一只橘色虎斑猫"
let prompt4 = "这张照片的情绪是什么？"       // → "温馨，猫咪看起来很安详"

// 同一个模型，改 prompt 就能做完全不同的任务！
// 这就是"零样本学习 (Zero-Shot Learning)"的威力
```

#### 2. 速度 vs 灵活性（关键权衡）

```
                    快 ←────────────→ 慢
                    │                 │
Apple Vision  ★★★★★│                 │
CoreML        ★★★★ │                 │
MoE 大模型          │          ★★★★★ │ 灵活性
                    │                 │
                    固定 ←───────────→ 灵活
                    │                 │
Apple Vision  ★     │                 │
CoreML        ★★   │                 │
MoE 大模型          │          ★★★★★ │

结论：没有"最好"的方案，只有"最合适"的方案
```

#### 3. 精度对比（基于实际基准测试数据）

```
ImageNet top-1 准确率:

MobileNetV3 (CoreML):
  ┃████████████████████████████████████████████░  75.2%
  ┃ 14MB, 5-8ms/张, 参数量 5.4M

ResNet50 (CoreML):
  ┃█████████████████████████████████████████████  76.1%
  ┃ 98MB, 120-150ms/张, 参数量 25.6M

SqueezeNet (CoreML):
  ┃██████████████████████████████████░░░░░░░░░░  60.0%
  ┃ 2.95MB, <5ms/张, 参数量 1.24M (极致轻量)

Apple Intelligence 端侧模型:
  ┃██████████████████████████████████████░░░░░░  64.4% (MMLU)
  ┃ 3.18B 参数, 2-bit 量化, ViTDet-L 视觉编码器

SmolVLM 256M (多模态):
  ┃███████████████████████████████░░░░░░░░░░░░░  ~65%
  ┃ <1GB 内存, 比 80B 模型某些任务上更强

InternVL3 1B (多模态):
  ┃████████████████████████████████░░░░░░░░░░░░  ~70%
  ┃ 合理的平衡点

Gemma 4 E2B (多模态):
  ┃████████████████████████████████████░░░░░░░░  ~75%
  ┃ 思考链推理提升准确率

LLaVA-1.5 7B (多模态):
  ┃████████████████████████████████████████████░  90.9% (Science QA)
  ┃ 太大，无法在 iPhone 上运行，仅供参考
```

**关键数据来源**: Apple Foundation Models 2025 技术报告、MobileNet/ResNet 论文基准、LLaVA 论文基准。

注意：不同基准测试的精度不可直接比较（ImageNet vs Science QA vs MMLU），上图仅供趋势参考。

#### 4. 场景推荐

```
┌─ 你的需求是什么？
│
├─ 固定几个类别，要求极速响应？
│  → Apple Vision / CoreML
│  例: 相机实时物体检测、照片自动分类
│
├─ 类别经常变化，不想重新训练？
│  → MoE 大模型 (改 prompt)
│  例: 电商商品分类、用户上传内容审核
│
├─ 需要理解图片内容并用自然语言回答？
│  → 只能用多模态大模型
│  例: "这张图里有什么？" "图中的文字是什么？"
│
├─ 隐私敏感，数据不能出设备？
│  → 三者都可以（端侧推理）
│
├─ 需要同时支持中英文？
│  → MoE 大模型天然支持
│  Apple Vision 标签为英文，需要自己翻译
│
└─ 综合多种任务（分类+描述+翻译）？
   → MoE 大模型（一个模型干所有事）
```

---

## 实际代码对比

### 方案 A: Apple Vision Framework

```swift
import Vision

func classifyWithVision(_ image: CGImage) async -> String {
    let request = VNClassifyImageRequest()
    let handler = VNImageRequestHandler(cgImage: image)
    
    try? handler.perform([request])
    
    guard let results = request.results as? [VNClassificationObservation],
          let top = results.first else { return "unknown" }
    
    return "\(top.identifier) (\(Int(top.confidence * 100))%)"
    // 输出: "tabby_cat (92%)"
    // 耗时: ~15ms
    // 内存: ~50MB
}
```

### 方案 B: CoreML MobileNet

```swift
import CoreML

func classifyWithCoreML(_ image: CGImage) async throws -> String {
    let model = try MobileNetV2(configuration: .init())
    let input = try MobileNetV2Input(imageWith: image)
    
    let output = try model.prediction(input: input)
    return "\(output.classLabel) (\(output.classLabelProbs[output.classLabel] ?? 0))"
    // 输出: "Egyptian_cat (0.87)"
    // 耗时: ~30ms
    // 内存: ~100MB
}
```

### 方案 C: 多模态大模型（本项目实际实现）

```swift
// 本项目的真实代码路径 (LlamaEngine.generateWithImages)

func classifyWithMultimodalLLM(_ imageData: Data, provider: AIModelProvider) async -> String {
    // prompt 中不需要描述图片内容——模型直接"看"图片
    let prompt = "What do you see in this image?"
    
    // 图片数据直接附带在消息中
    let message = ChatMessage(
        role: .user,
        content: prompt,
        imageData: [imageData]  // ← JPEG 字节，不需要任何预处理
    )
    
    var result = ""
    let stream = provider.chat(messages: [message], config: .default)
    
    for try await token in stream {
        result += token.text
    }
    
    return result
    // 输出: "The image shows an orange tabby cat curled up on a sofa..."
    // 耗时: 3-10s (含 CLIP 编码 + LLM 生成)
    // 内存: 1-4GB (取决于模型大小)
    //
    // 内部执行流程:
    // 1. imageData → mtmd_helper_bitmap_init_from_buf() (stb_image 解码)
    // 2. prompt 插入 <__media__> 标记
    // 3. mtmd_tokenize() → [文本chunk, 图片chunk, 文本chunk]
    // 4. mtmd_helper_eval_chunks() → CLIP 编码 + embedding 注入
    // 5. llama_sampler_sample() → 逐 token 生成回答
}
```

**注意**：和之前版本不同，我们**不再通过 CoreML/Vision 获取图片描述再转给文本模型**。
图片 JPEG 字节直接通过 mtmd API 送入模型的视觉编码器（CLIP），模型真正"看到"了图片像素。
```

---

## MoE 模型的独特优势

### 1. 稀疏激活 = 高效多任务

```
MoE 的核心优势用一句话概括：
"用小模型的速度，获得大模型的能力"

具体到图片任务：
┌─────────────────────────────────────────┐
│  MoE 8×3B 模型 (总参数 24B，激活 6B)     │
│                                          │
│  处理图片时:                              │
│    Router → 选视觉专家 #1 + #5           │
│    只计算 6B 参数 → 速度接近 Dense 3B     │
│    但视觉知识来自 24B 参数池 → 精度更高   │
│                                          │
│  处理文本时:                              │
│    Router → 选语言专家 #2 + #7           │
│    同样只计算 6B → 速度不变               │
│    语言知识来自另一组专家 → 不影响视觉     │
│                                          │
│  结论: 视觉和语言能力不互相挤占！          │
└─────────────────────────────────────────┘
```

### 2. 零样本分类 (Zero-Shot)

```
传统方案添加新分类类别：
1. 收集新类别的训练图片（几百到几千张）
2. 标注数据
3. 重新训练/微调模型
4. 验证效果
5. 部署新模型到 App
→ 耗时: 天 ~ 周

MoE 大模型添加新分类类别：
1. 修改 prompt 字符串
→ 耗时: 10 秒

let prompt = "分类为: 猫/狗/鸟/兔子/仓鼠"  // 加了兔子和仓鼠！
// 不需要任何训练数据，不需要重新部署
```

### 3. 可解释性

```swift
// Apple Vision 的输出:
// "cat" (confidence: 0.92)
// 为什么是猫？不知道。

// MoE 大模型的输出 (如果你在 prompt 中要求):
// "这张图片展示了一只橘色虎斑猫。判断依据：
//  1. 图中有四条腿的小型动物
//  2. 有尖耳朵和胡须
//  3. 毛发呈橘色带深色条纹
//  4. 体型和姿态符合家猫特征
//  分类: cat"
```

### 4. 一个模型多种任务

```
Apple Vision + CoreML 方案：
  图片分类 → MobileNet.mlmodel (25MB)
  文字识别 → 系统 OCR
  物体检测 → YOLO.mlmodel (20MB)
  图片描述 → 需要第三方 API
  总计: 3 个模型 + 1 个 API

MoE 多模态方案：
  图片分类 → 改 prompt ✅
  文字识别 → 改 prompt ✅
  物体检测 → 改 prompt ✅
  图片描述 → 改 prompt ✅
  总计: 1 个模型，0 个 API
```

---

## Apple Intelligence 的视觉方案（iOS 18+）

Apple 在 2025 年发布的 Apple Intelligence 也采用了多模态架构，了解它有助于理解行业方向：

```
Apple Intelligence 端侧视觉架构：
┌───────────────────────────────────────────────┐
│  视觉编码器: ViTDet-L (300M 参数)              │
│  → Register-Window 机制                        │
│  → 固定输出 144 个 image token                  │
│  → 支持多分辨率: 224/672/1344 像素               │
├───────────────────────────────────────────────┤
│  语言模型: 3.18B 参数                           │
│  → 2-bit 量化感知训练                           │
│  → KV-cache 共享                               │
│  → 投机解码 (48.77M draft model 加速)           │
├───────────────────────────────────────────────┤
│  能力:                                          │
│  ✓ 图片中文字识别 (15 种语言)                    │
│  ✓ 手写字/表格/图表/数学公式理解                  │
│  ✓ 多图推理                                     │
│  ✓ 视觉定位 (点/边框)                           │
└───────────────────────────────────────────────┘

对比我们的端侧方案:
Apple Intelligence → 不开放给第三方 App 自由调用
我们的 llama.cpp 方案 → 完全自主可控，模型可替换

Apple 证明了: 3B 端侧多模态模型是可行的！
我们的方案是同一技术方向的开源实现。
```

---

## 在 iPhone 上的现实限制

研究数据显示，在 iPhone 上运行多模态大模型需要注意以下限制：

### 热状态管理

```
iPhone 15 Pro 持续多模态推理的热状态变化：

推理次数:  1    5    10   20   50
温度状态:  ✅    ✅    ⚠️   🔶   🔴
          正常  正常  微热  较热  降频

关键数据:
- 连续推理 2-3 次后开始升温
- 热状态进入"Hot"后，性能下降约 44%
- 建议: 每次分类间隔 1-2 秒让芯片散热
- 批量分类 500 张图时，预计总耗时包含散热等待

解决方案:
1. 监控 ProcessInfo.processInfo.thermalState
2. thermal == .serious 时暂停推理
3. 图片缩小到 384×384 以下减少计算量
```

### 电池消耗

```
每次多模态推理的电池消耗 (iPhone 15 Pro):

MobileNet 分类:     █ ~0.01%/次 (几乎无影响)
SmolVLM 500M:       ████ ~1-2%/次
InternVL3 1B:       ██████ ~2-3%/次
Gemma 4 E2B:        ████████ ~3-5%/次

500 张图片完整测试预计消耗:
- MobileNet: ~5% 电量
- SmolVLM 500M: ~15-20% 电量
- Gemma 4 E2B: ~30-50% 电量

建议: 充电状态下运行大规模图片分类测试
```

---

## 端侧可用的多模态模型

| 模型 | 参数量 | 模型+mmproj 大小 | 运行时内存 | 适用设备 | 推理速度 |
|------|--------|----------------|----------|---------|---------|
| SmolVLM 256M | 256M | ~300MB | ~500MB | iPhone 13+ (4GB) | ~100ms |
| SmolVLM 500M | 500M | ~500MB | ~800MB | iPhone 13+ (4GB) | ~150ms |
| InternVL3 1B | 1B | ~1GB | ~1.5GB | iPhone 14+ (6GB) | ~300ms |
| Qwen2-VL 2B | 2B | ~2GB | ~2.5GB | iPhone 15 (6GB) | ~500ms |
| Gemma 4 E2B | 2.3B | ~3.7GB | ~4GB | iPhone 15 Pro (8GB) | ~600ms |
| Qwen2.5-VL 3B | 3B | ~3GB | ~3.5GB | iPhone 15 Pro (8GB) | ~700ms |

> **推荐**: 入门用 **SmolVLM 500M**（快、小），追求精度用 **Gemma 4 E2B** 或 **Qwen2.5-VL 3B**。

### 对比 CoreML 传统方案

| 模型 | 类型 | 大小 | 速度 | 精度 | 零样本 |
|------|------|------|------|------|--------|
| SqueezeNet | CNN | 2.95MB | <5ms | 60% | ❌ |
| MobileNetV3 | CNN | 14MB | 5-8ms | 75.2% | ❌ |
| ResNet50 | CNN | 98MB | 120ms | 76.1% | ❌ |
| SmolVLM 256M | 多模态 LLM | ~300MB | ~100ms | ~65% | ✅ |
| InternVL3 1B | 多模态 LLM | ~1GB | ~300ms | ~70% | ✅ |
| Gemma 4 E2B | 多模态 LLM | ~3.7GB | ~600ms | ~75% | ✅ |

---

## 性能优化建议

### 针对图片分类场景的优化

```swift
// 1. 使用极低温度（分类任务不需要创造性）
let config = GenerationConfig(
    maxTokens: 32,        // 分类结果只需几个字
    temperature: 0.1,     // 接近确定性输出
    topK: 10,
    topP: 0.5,
    repeatPenalty: 1.0    // 分类不需要惩罚重复
)

// 2. 精简 prompt（减少 Prefill 时间）
// ❌ 长 prompt:
"你是一个专业的图像分类人工智能助手。请仔细观察下面的图片，
 并根据图片中显示的主要物体，将其分类为以下类别之一..."

// ✅ 短 prompt:
"分类为: cat/dog/bird/fish\n只输出类别名。"

// 3. 缩小图片尺寸（减少视觉编码时间）
// CIFAR-10 是 32×32，非常快
// 实际使用建议不超过 384×384
// 更大的图片 ≠ 更准确，因为 mmproj 会自行缩放

// 4. 批量处理时不要反复加载/卸载模型
// ❌ 每张图: load → classify → unload
// ✅ 批量: load → classify 500张 → unload
```

---

## 总结：何时用哪个方案？

| 场景 | 推荐方案 | 原因 |
|------|---------|------|
| 相册自动分类 (固定类别) | Apple Vision | 极速 5ms、免费、0 依赖 |
| 实时相机物体检测 | CoreML + YOLO | 帧率要求高 (30fps+) |
| 电商商品分类 (类别常变) | MoE 大模型 | 零样本，改 prompt 即可 |
| 图片内容审核 | MoE 大模型 | 理解语义，不只看像素 |
| 图片问答 / 描述 | MoE 大模型 | 唯一能生成自然语言的方案 |
| OCR + 理解 | MoE 大模型 或 Apple Vision | 简单 OCR 用 Vision，理解含义用 LLM |
| 隐私敏感图片分析 | 三者皆可 | 都是端侧推理，数据不出设备 |
| 预算为 0 | Apple Vision | 系统自带，完全免费 |
| 需要处理 500+ 张/分钟 | CoreML MobileNet | 5ms/张，高吞吐 |
| 需要自然语言解释分类原因 | MoE 大模型 | 唯一支持的方案 |

> **最佳实践**: 组合使用！Apple Vision 做**快速粗筛**（5ms），MoE 大模型做**精细判断**（500ms）。就像 App 架构中的缓存策略——先查 L1 缓存（快），未命中再查 L2（慢但全）。

---

## 附录：完整基准数据

| 指标 | Apple Vision | MobileNetV3 | ResNet50 | SmolVLM 256M | InternVL3 1B | Gemma 4 E2B | LLaVA-1.5 7B |
|------|-------------|-------------|----------|-------------|-------------|-------------|-------------|
| 参数量 | 不公开 | 5.4M | 25.6M | 256M | 1B | 2.3B | 7B |
| 模型大小 | 0 (内置) | 14MB | 98MB | ~300MB | ~1GB | ~3.7GB | ~3.5GB (Q4) |
| 推理延迟 | <20ms | 5-8ms | 120ms | ~100ms | ~300ms | ~600ms | 200-500ms |
| 运行时内存 | ~50MB | ~100MB | ~300MB | ~500MB | ~1.5GB | ~4GB | 4-8GB |
| 精度参考 | ~85% | 75.2% | 76.1% | ~65% | ~70% | ~75% | 90.9% (SQA) |
| 零样本 | ❌ | ❌ | ❌ | ✅ | ✅ | ✅ | ✅ |
| 可解释性 | ❌ | ❌ | ❌ | ✅ | ✅ | ✅ | ✅ |
| 电池/次 | ~0.01% | ~0.01% | ~0.05% | ~1% | ~2% | ~4% | 不适用 |
| iPhone 可行性 | ✅ 全系列 | ✅ 全系列 | ✅ 全系列 | ✅ 13+ | ✅ 14+ | ⚠️ 15 Pro | ❌ 过大 |

*数据来源: Apple Foundation Models 2025 技术报告、MobileNet/ResNet 论文、LLaVA 论文、SmolVLM 论文*

---

## 下一步

- 在 App「测评」Tab 中体验真实图片分类
- 下载多模态模型（SmolVLM / InternVL3）尝试图片输入
- 对比不同模型在相同图片集上的准确率和速度
