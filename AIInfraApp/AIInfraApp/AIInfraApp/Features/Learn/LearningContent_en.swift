import SwiftUI

// MARK: - English Learning Content

let learningModulesEN: [LearningModule] = [

    // ── Chapter 1 ──
    LearningModule(
        order: 1,
        title: "AI Fundamentals",
        subtitle: "What are LLMs? Understanding AI from an iOS developer's perspective",
        icon: "brain.head.profile",
        color: .blue,
        difficulty: .beginner,
        content: """
        ## Understanding LLMs from an iOS Developer's Perspective

        A Large Language Model (LLM) is essentially a **massive probability prediction function**: given an input text (prompt), it calculates the probability of every possible next word and outputs the most likely one.

        > Think of an LLM as a super auto-complete engine trained on trillions of text tokens.

        ### Core Concepts Comparison

        | AI Concept | iOS Analogy | Description |
        |-----------|------------|-------------|
        | Model | `.mlmodel` / `.gguf` file | Contains trained weight parameters |
        | Parameters | Floating-point numbers inside the model | 1B = 1 billion parameters, each is a weight value |
        | Inference | `model.predict(input)` | The process of converting input to output |
        | Training | N/A (on-device only does inference) | Adjusting parameters using massive data, requires many GPUs |
        | Token | Smallest unit of text processing | Not equal to a character/word; English avg ~1.3 tokens/word |
        | Context Window | Max input length the model can process | 2048 tokens ≈ about 1500 English words |
        | Embedding | `[Float]` vector | Mapping text to numerical representation in high-dimensional space |

        ### Deep Dive into Tokens

        A token is the basic unit of text processing for the model. Different models use different tokenizers, producing different results:

        ```
        "Hello world"   → ["Hello", " world"]           → 2 tokens
        "你好世界"       → ["你好", "世界"]               → 2 tokens
        "iPhone 15 Pro" → ["i", "Phone", " 15", " Pro"] → 4 tokens
        "🎉"            → ["🎉"]                        → 1 token
        ```

        **Why isn't a token equal to a word?** Because the tokenizer uses BPE (Byte Pair Encoding), which merges common character combinations into single tokens. In English, "the" is one token, while rare words may be split into multiple tokens.

        **Token estimation formula** for English text:

        $$\\text{tokens} \\approx \\text{word count} \\times 1.3$$

        ### Model Size and Memory Relationship

        Each model parameter is a number that requires memory to store:

        - **FP16 (half-precision float)**: 2 bytes per parameter
        - **Q4 (4-bit quantization)**: ~0.5 bytes per parameter

        Memory estimation formula:

        $$\\text{Memory (GB)} = \\frac{\\text{Parameters (B)} \\times \\text{bytes per param}}{1024^3}$$

        Actual values:

        | Model Size | FP16 Memory | Q8 Memory | Q4 Memory | Recommended Device |
        |-----------|------------|----------|----------|-------------------|
        | 0.5B | 1 GB | 0.5 GB | ~400 MB | iPhone 13+ (4GB RAM) |
        | 1B | 2 GB | 1 GB | ~600 MB | iPhone 14+ (6GB RAM) |
        | 1.5B | 3 GB | 1.5 GB | ~1 GB | iPhone 15 (6GB RAM) |
        | 3B | 6 GB | 3 GB | ~2 GB | iPhone 15 Pro (8GB RAM) |
        | 7B | 14 GB | 7 GB | ~4 GB | Beyond iPhone capability |

        > **Key insight**: The bottleneck on iPhone is **RAM**, not compute power. The A17 Pro's Neural Engine and GPU are powerful enough, but iPhone 15 Pro only has 8GB RAM, with the system and other apps using about 3-4GB, leaving limited space for models.

        ### Prefill and Decode: Two-Phase Inference

        On-device inference consists of two fundamentally different phases:

        ```
        ┌─────────────────────────────────────────────────┐
        │  Prefill Phase (Read)       Decode Phase (Write) │
        │                                                  │
        │  "What's the weather"  →  "It" "is" "sunny"     │
        │  ─── Process all at once ─── Generate one by one │
        │  Parallel, fast              Sequential, slow     │
        │  ~100-500ms               Each token 40-100ms    │
        └─────────────────────────────────────────────────┘
        ```

        1. **Prefill (Prompt Processing)**:
           - Processes all input tokens in parallel at once
           - Speed measured in **tokens/s**, typically 100-500 t/s on-device
           - Perceived by user as **TTFT (Time To First Token)**
           - Longer input = slower Prefill

        2. **Decode (Token Generation)**:
           - Generates one token at a time, then adds it to context for the next
           - Fully sequential, cannot be parallelized
           - Speed measured in **tokens/s**, typically 10-25 t/s on-device
           - This is why you see text appearing character by character in chat interfaces

        ### Autoregressive Generation Process

        ```
        Input:  "What's the weather"
        Step 1: "What's the weather" → model predicts → "like" (highest probability)
        Step 2: "What's the weather like" → model predicts → "today"
        Step 3: "What's the weather like today" → model predicts → "?"
        Step 4: "What's the weather like today?" → model predicts → <EOS> (end)
        ```

        Each step requires a full forward pass computation — this is why generation speed is much slower than processing speed.
        """
    ),

    // ── Chapter 2 ──
    LearningModule(
        order: 2,
        title: "On-Device AI: Advantages & Challenges",
        subtitle: "Why run AI on iPhone? What are the limitations?",
        icon: "iphone.gen3",
        color: .purple,
        difficulty: .beginner,
        content: """
        ## Why Run AI on iPhone?

        ### On-Device vs Cloud Inference Architecture

        ```
        ┌── Cloud Inference ──────────────────────────────┐
        │  [User Input] → [Network] → [Cloud GPU Inference]│
        │              → [Network] → [Display Result]      │
        │  Latency: 500-2000ms  |  Cost: ~$0.01/request   │
        │  Privacy: Data passes through third-party servers│
        └──────────────────────────────────────────────────┘

        ┌── On-Device Inference ───────────────────────────┐
        │  [User Input] → [Local Model Inference] → [Result]│
        │  Latency: 100-500ms  |  Cost: $0                 │
        │  Privacy: Data never leaves the device            │
        └──────────────────────────────────────────────────┘
        ```

        ### Four Core Advantages

        **1. Privacy Protection — Zero Data Transmission**

        All inference runs locally on the device; user data never passes through any server. Critical for:
        - Health and medical data
        - Financial and payment information
        - Personal communications
        - Enterprise confidential documents
        - Children's data (COPPA compliance)

        **2. Low Latency — No Network Round-Trip**

        On-device TTFT is typically 100-500ms, while cloud API TTFT is usually 500-2000ms.

        Latency breakdown comparison:

        | Component | Cloud | On-Device |
        |-----------|-------|-----------|
        | DNS Resolution | 10-100ms | 0 |
        | TCP/TLS Handshake | 50-200ms | 0 |
        | Request Upload | 10-50ms | 0 |
        | Queue Wait | 0-5000ms | 0 |
        | Prefill Compute | 50-200ms | 100-500ms |
        | First Token Return | 10-50ms | 0 |
        | **Total TTFT** | **130-5600ms** | **100-500ms** |

        **3. Offline Availability — Works Anywhere**

        Subway, airplane, elevator, remote areas — as long as the device has power, the model runs. Ideal as a **graceful degradation** fallback for cloud services.

        **4. Zero Marginal Cost — Run as Many Times as You Want**

        Download the model once, no per-inference API fees. Huge cost advantage for high-frequency scenarios (input suggestions, real-time classification).

        For an app with 1M DAU, each user triggering 20 AI classifications per day:

        $$\\text{Cloud daily cost} = 1{,}000{,}000 \\times 20 \\times \\$0.001 = \\$20{,}000/\\text{day}$$

        $$\\text{On-device daily cost} = \\$0$$

        ### Five Real-World Limitations

        | Limitation | Manifestation | Quantitative Data | Mitigation |
        |-----------|---------------|-------------------|------------|
        | Model capability ceiling | Sub-3B models can't handle complex reasoning | MMLU: 0.5B~35%, 3B~55%, GPT-4~87% | Simple tasks on-device, complex tasks via cloud |
        | Memory pressure | Models consume large RAM | 3B Q4 ≈ 2GB, iPhone 15 Pro available ~4GB | Unload after inference, avoid keeping resident |
        | Heat & throttling | Sustained inference raises SoC temperature | 3-5 min continuous inference → serious thermal state | Monitor thermalState, pause when hot |
        | Storage usage | Each GGUF file is 0.4-3GB | 3 models ≈ 5GB storage | Let users selectively download, support deletion |
        | Language capability gap | Most small models prioritize English training data | Qwen best for Chinese, Llama weaker | Choose Qwen series for Chinese scenarios |

        ### On-Device vs Cloud: Decision Matrix

        ```
        Is your task suitable for on-device?
        ├── Needs offline use? → Yes → On-Device
        ├── Involves sensitive data? → Yes → On-Device
        ├── Call frequency > 100/day? → Yes → On-Device (save cost)
        ├── Needs complex reasoning (math/logic)? → Yes → Cloud
        ├── Needs to process long text (>2000 words)? → Yes → Cloud
        └── None of the above? → Check latency requirement
            ├── Latency < 200ms → On-Device
            └── Latency insensitive → Cloud (better quality)
        ```
        """
    ),

    // ── Chapter 3 ──
    LearningModule(
        order: 3,
        title: "Transformer Architecture Deep Dive",
        subtitle: "Understanding attention mechanisms, feed-forward networks, and positional encoding",
        icon: "text.alignleft",
        color: .green,
        difficulty: .intermediate,
        content: """
        ## Transformer: The Foundation of LLMs

        Nearly all modern LLMs (GPT, Llama, Qwen, Gemma, Phi) are based on the Transformer architecture (proposed in Google's 2017 "Attention is All You Need" paper).

        ### Overall Data Flow

        ```
        Input: "Hello world"
            ↓
        ┌─── Tokenizer ────────────────────────┐
        │  "Hello world" → [9906, 1917]         │
        └───────────────────────────────────────┘
            ↓
        ┌─── Embedding Layer ──────────────────┐
        │  token ID → high-dim vector (d=2048)  │
        │  [9906] → [0.12, -0.34, 0.78, ...]   │
        └───────────────────────────────────────┘
            ↓
        ┌─── Positional Encoding ──────────────┐
        │  Inject position info (model has no   │
        │  inherent notion of word order)       │
        │  RoPE / ALiBi / Absolute encoding     │
        └───────────────────────────────────────┘
            ↓
        ┌─── Transformer Block × N layers ─────┐
        │  ┌── Multi-Head Attention ──┐         │
        │  │  Q = X·W_Q               │         │
        │  │  K = X·W_K               │         │
        │  │  V = X·W_V               │         │
        │  │  Attention(Q,K,V)         │         │
        │  └──────────────────────────┘         │
        │           ↓ + Residual + LayerNorm    │
        │  ┌── Feed-Forward Network ──┐         │
        │  │  FFN(x) = W2·σ(W1·x)     │         │
        │  └──────────────────────────┘         │
        │           ↓ + Residual + LayerNorm    │
        └───────────────────────────────────────┘
            ↓  (Repeated N times, e.g. Qwen2.5-1.5B has 28 layers)
        ┌─── Output Head ──────────────────────┐
        │  Hidden state → probability over vocab│
        │  softmax → P("today")=0.35, ...       │
        └───────────────────────────────────────┘
            ↓
        ┌─── Sampling ─────────────────────────┐
        │  Select next token based on strategy  │
        │  → Selected "today" → output to user  │
        └───────────────────────────────────────┘
        ```

        ### Self-Attention Core Formula

        Attention is the heart of the Transformer. It lets each token "see" all other tokens in the sequence and compute their relevance:

        $$\\text{Attention}(Q, K, V) = \\text{softmax}\\left(\\frac{QK^T}{\\sqrt{d_k}}\\right)V$$

        Where:
        - $Q$ (Query): The current word's "question" vector — "What information am I looking for?"
        - $K$ (Key): Each word's "label" vector — "What information do I contain?"
        - $V$ (Value): Each word's "content" vector — "If selected, what do I provide?"
        - $d_k$: Key dimension; dividing by $\\sqrt{d_k}$ prevents dot products from becoming too large, which would cause softmax saturation
        - $\\text{softmax}$: Normalizes scores into a probability distribution (sums to 1)

        **Intuitive understanding**: Using an iOS analogy, Attention is like a **dynamic database query** — each word uses its own Query to search all words' Keys, finds the most relevant ones, then uses their Values to update its own representation.

        ### Multi-Head Attention

        To let the model attend to different types of relationships simultaneously (grammatical, semantic, positional), Transformer uses multiple attention "heads" in parallel:

        ```
        Head 1: Attends to grammatical relations (subject→verb)
        Head 2: Attends to coreference (pronoun→noun)
        Head 3: Attends to adjacent positions
        ...
        Head h: Attends to long-range dependencies
        ```

        Outputs from all heads are concatenated and linearly transformed:

        $$\\text{MultiHead}(Q,K,V) = \\text{Concat}(\\text{head}_1, ..., \\text{head}_h)W^O$$

        Common configuration: Qwen2.5-1.5B has 12 attention heads, each with dimension 128.

        ### Feed-Forward Network (FFN)

        The second sub-module in each Transformer layer is a two-layer fully connected network:

        $$\\text{FFN}(x) = W_2 \\cdot \\text{SiLU}(W_1 \\cdot x)$$

        FFN accounts for **approximately 2/3** of model parameters. It performs independent nonlinear transformations at each position — think of it as the "thinking and memory" component.

        ### Dense vs MoE Architecture Comparison

        | Feature | Dense | MoE (Mixture of Experts) |
        |---------|-------|--------------------------|
        | FFN Structure | 1 large FFN | N small FFNs (experts) + Router |
        | Per inference | All parameters participate | Router selects Top-K experts |
        | iOS Analogy | Load all ViewControllers | UICollectionView loads only visible Cells |
        | Total params | e.g. 3B | e.g. 26B (but only uses 4B each time) |
        | Memory needs | Proportional to param count | Must load all experts (high memory) |
        | Compute | Proportional to param count | Much less than total params |
        | On-device suitability | Good (memory controllable) | Limited (total params consume memory) |
        | Representative models | Llama, Qwen, Gemma 2 | DeepSeek, Mixtral, Gemma 4 |

        ### Key Model Parameters

        | Parameter | Meaning | Qwen2.5-1.5B | Llama 3.2-1B |
        |-----------|---------|---------------|---------------|
        | `n_layers` | Transformer layers | 28 | 16 |
        | `d_model` | Hidden dimension | 1536 | 2048 |
        | `n_heads` | Attention heads | 12 | 32 |
        | `d_ff` | FFN intermediate dim | 8960 | 8192 |
        | `vocab_size` | Vocabulary size | 151,936 | 128,256 |
        | `n_ctx` | Max context | 32,768 | 131,072 |
        """
    ),

    // ── Chapter 4 ──
    LearningModule(
        order: 4,
        title: "GGUF & Model Quantization",
        subtitle: "Quantization principles, GGUF format, choosing the right quantization level",
        icon: "archivebox.fill",
        color: .orange,
        difficulty: .intermediate,
        content: """
        ## GGUF Format & Quantization Technology

        ### What is GGUF?

        GGUF (GPT-Generated Unified Format) is the model file format defined by the llama.cpp project:

        ```
        ┌──────────────────────────────────────────┐
        │  GGUF File Structure                      │
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
        │  │  token_embd.weight: [Q4_K data...]  │ │
        │  │  blk.0.attn_q.weight: [Q4_K data...] │
        │  │  ...                                │ │
        │  │  output.weight: [Q6_K data...]      │ │
        │  └─────────────────────────────────────┘ │
        └──────────────────────────────────────────┘
        ```

        **GGUF advantage**: Single file containing model weights + tokenizer + config, ready to use out of the box.

        ### Quantization Principles

        Core idea: Use fewer bits to represent each parameter, sacrificing minimal precision for massive size and speed gains.

        **FP16 → INT4 quantization process**:

        Given weights `[0.12, -0.34, 0.78, -0.56, 0.23, -0.91, 0.45, -0.67]`

        ```
        1. Find range: min=-0.91, max=0.78
        2. Calculate scale: scale = (max-min) / (2^4-1) = 1.69/15 ≈ 0.113
        3. Quantize: q = round((x - min) / scale)
           0.12  → round((0.12+0.91)/0.113) = round(9.1) = 9
           -0.34 → round((-0.34+0.91)/0.113) = round(5.0) = 5
           ...
        4. Store: [9, 5, 15, 3, 10, 0, 12, 2] (each needs only 4 bits)
        ```

        Dequantization: $x \\approx q \\times \\text{scale} + \\text{min}$

        **Quantization error**: Quantization inevitably introduces error, proportional to quantization level:

        $$\\text{MSE} = \\frac{1}{n}\\sum_{i=1}^{n}(x_i - \\hat{x}_i)^2$$

        Where $x_i$ is the original value and $\\hat{x}_i$ is the dequantized value.

        ### Quantization Scheme Comparison

        GGUF supports multiple schemes. `K` indicates k-quant (mixed precision, using higher precision for important layers):

        | Scheme | Bits/param | Compression | Quality Loss | 1.5B File Size | Use Case |
        |--------|-----------|-------------|-------------|---------------|----------|
        | FP16 | 16 | 1× | 0% | 3.0 GB | Server/baseline |
        | Q8_0 | 8 | 2× | ~0.1% | 1.5 GB | iPad Pro |
        | Q6_K | 6 | 2.67× | ~0.3% | 1.13 GB | High-end devices |
        | Q5_K_M | 5 | 3.2× | ~0.5% | 0.94 GB | Quality-focused |
        | **Q4_K_M** | **4** | **4×** | **~1-2%** | **0.75 GB** | **Recommended** |
        | Q3_K_M | 3 | 5.3× | ~3-5% | 0.56 GB | Storage-limited |
        | Q2_K | 2 | 8× | ~8-15% | 0.38 GB | Not recommended |

        Compression ratio formula:

        $$\\text{Compression Ratio} = \\frac{16}{\\text{target bits}}$$

        > **Conclusion**: **Q4_K_M is the best balance for on-device deployment**. On MMLU benchmark, Q4_K_M drops only 1-2 percentage points compared to FP16, but reduces size to 1/4.

        ### Quantization Impact on Different Tasks

        Different tasks have different sensitivity to quantization:

        | Task Type | Q4 vs FP16 Difference | Reason |
        |----------|----------------------|--------|
        | Text classification | Almost none | Only needs to determine category, high error tolerance |
        | Simple Q&A | Almost none | Small answer space |
        | Translation | Slight decrease | Requires precise vocabulary selection |
        | Code generation | Noticeable decrease | High syntactic precision requirement |
        | Math reasoning | Significant decrease | Sensitive to numerical precision |
        | Creative writing | Almost none | No "correct answer" |
        """
    ),

    // ── Chapter 5 ──
    LearningModule(
        order: 5,
        title: "llama.cpp & iOS Integration",
        subtitle: "Complete guide to integrating llama.cpp into an iOS app",
        icon: "hammer.fill",
        color: .red,
        difficulty: .advanced,
        content: """
        ## llama.cpp: The On-Device Inference Engine

        llama.cpp is the most popular on-device LLM inference engine, implemented in pure C/C++, using Metal framework for Apple GPU acceleration.

        ### Technology Comparison

        | Solution | Model Support | iOS Performance | Integration Difficulty | Community |
        |----------|-------------|----------------|----------------------|-----------|
        | **llama.cpp** | Widest (GGUF format) | Metal GPU accelerated | Medium (C API) | Very active (GitHub 70k+ stars) |
        | CoreML | Requires conversion to mlmodel | Neural Engine optimal | High (complex conversion) | Apple official |
        | MLX | Swift native | Apple Silicon optimized | Low | Newer |
        | MNN | Limited | CPU primarily | Medium | Alibaba open source |

        ### iOS Integration Architecture

        ```
        ┌─── App Layer (Swift/SwiftUI) ──────────────────┐
        │  ChatView → LlamaOnDeviceProvider              │
        └────────────────────┬───────────────────────────┘
                             │ calls
        ┌─── Bridge Layer (Swift) ──────────────────────┐
        │  LlamaEngine.swift                             │
        │  - load() / unload()                           │
        │  - generate() (streaming)                      │
        │  - applyChatTemplate()                         │
        │  - UTF8StreamDecoder                           │
        └────────────────────┬───────────────────────────┘
                             │ C API calls
        ┌─── llama.cpp (C/C++) ─────────────────────────┐
        │  llama.xcframework (pre-built binary)          │
        │  - llama_model_load_from_file()                │
        │  - llama_init_from_model()                     │
        │  - llama_decode() / llama_sampler_sample()     │
        │  - Metal GPU backend                           │
        └────────────────────┬───────────────────────────┘
                             │
        ┌─── Hardware ──────────────────────────────────┐
        │  Apple A17 Pro: CPU + GPU + Neural Engine      │
        │  Metal API → GPU matrix operation acceleration │
        └────────────────────────────────────────────────┘
        ```

        ### SPM Integration

        llama.cpp provides a pre-built xcframework (~50MB) via SPM Binary Target:

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

        ### Complete Inference Flow

        ```swift
        import llama

        // 1. Initialize backend
        llama_backend_init()

        // 2. Load model file
        var params = llama_model_default_params()
        params.n_gpu_layers = 999  // Use GPU for all layers
        let model = llama_model_load_from_file(path, params)

        // 3. Create inference context
        var ctxParams = llama_context_default_params()
        ctxParams.n_ctx = 2048     // Context length
        ctxParams.n_batch = 512    // Batch size
        ctxParams.n_threads = 4    // CPU thread count
        let ctx = llama_init_from_model(model, ctxParams)

        // 4. Build sampling chain
        let sampler = llama_sampler_chain_init(defaultParams)
        llama_sampler_chain_add(sampler, llama_sampler_init_penalties(64, 1.1, 0, 0))
        llama_sampler_chain_add(sampler, llama_sampler_init_top_k(40))
        llama_sampler_chain_add(sampler, llama_sampler_init_top_p(0.9, 1))
        llama_sampler_chain_add(sampler, llama_sampler_init_temp(0.7))
        llama_sampler_chain_add(sampler, llama_sampler_init_dist(seed))

        // 5. Tokenize
        let tokens = llama_tokenize(vocab, text, len, &buf, maxTokens, true, true)

        // 6. Prefill (process input)
        let batch = llama_batch_get_one(tokens, count)
        llama_decode(ctx, batch)

        // 7. Decode (generate tokens one by one)
        while !finished {
            let token = llama_sampler_sample(sampler, ctx, -1)
            if llama_vocab_is_eog(vocab, token) { break }

            let bytes = llama_token_to_piece(vocab, token, &buf, 256, 0, true)
            let text = utf8Decoder.decode(bytes)  // UTF-8 stream decoding
            onToken(text)  // Callback to UI

            llama_decode(ctx, llama_batch_get_one(&token, 1))
        }

        // 8. Cleanup
        llama_sampler_free(sampler)
        llama_free(ctx)
        llama_model_free(model)
        llama_backend_free()
        ```

        ### Chat Template Details

        Different model families use different conversation formats. Using the correct template is essential:

        | Model | Format | Example |
        |-------|--------|---------|
        | Qwen | ChatML | `<\\|im_start\\|>user\\nHello<\\|im_end\\|>` |
        | Llama 3 | Llama3 | `<\\|start_header_id\\|>user<\\|end_header_id\\|>\\n\\nHello<\\|eot_id\\|>` |
        | Gemma 2 | Gemma | `<start_of_turn>user\\nHello<end_of_turn>` |
        | Gemma 4 | Gemma4 | `<\\|turn>user\\nHello<turn\\|>` |
        | Phi-3.5 | Phi | `<\\|user\\|>\\nHello<\\|end\\|>` |

        > **Important**: Using the wrong template will severely degrade model output quality or produce garbled text. This project auto-detects model family via `detectModelFamily()` and selects the correct template.
        """
    ),

    // ── Chapter 6 ──
    LearningModule(
        order: 6,
        title: "Sampling Strategies & Output Control",
        subtitle: "The math behind Temperature, Top-P, Top-K and their practical usage",
        icon: "slider.horizontal.3",
        color: .teal,
        difficulty: .intermediate,
        content: """
        ## The Mathematics of Sampling Strategies

        Each forward pass of the model outputs a **logits vector** — unnormalized scores for every token in the vocabulary. Sampling strategies determine how to convert logits into a final token selection.

        ### Softmax and Temperature

        The softmax function converts logits into a probability distribution:

        $$p_i = \\frac{e^{z_i / T}}{\\sum_{j=1}^{V} e^{z_j / T}}$$

        Where $z_i$ is the logit for token $i$, $T$ is the temperature parameter, and $V$ is the vocabulary size.

        **Temperature effects**:

        Given logits = [2.0, 1.0, 0.5] (for candidates "good", "the", "ah"):

        | Temp T | P("good") | P("the") | P("ah") | Effect |
        |--------|-----------|----------|---------|--------|
        | 0.1 | 99.9% | 0.1% | 0.0% | Nearly deterministic |
        | 0.5 | 84.0% | 11.6% | 4.4% | Conservative |
        | **0.7** | **72.7%** | **17.7%** | **9.6%** | **Recommended default** |
        | 1.0 | 59.3% | 21.8% | 18.9% | Original distribution |
        | 1.5 | 47.4% | 28.0% | 24.6% | More random |
        | 2.0 | 41.4% | 30.2% | 28.4% | Highly random |

        Lower temperature → sharper distribution → more deterministic output
        Higher temperature → flatter distribution → more random output

        ### Top-K Sampling

        Sample only from the K highest-probability candidates, setting all others to 0:

        ```
        Original:  [0.35, 0.25, 0.15, 0.10, 0.05, 0.04, 0.03, 0.02, 0.01]
        Top-K=3:   [0.47, 0.33, 0.20, 0,    0,    0,    0,    0,    0   ]
                    ↑ Re-normalized top 3
        ```

        | K Value | Effect | Use Case |
        |---------|--------|----------|
        | 1 | Greedy decoding, always picks max | Classification, extraction |
        | 20 | Conservative sampling | Code, math |
        | **40** | **Balanced** | **General recommended** |
        | 100 | More diverse | Creative writing |

        ### Top-P (Nucleus Sampling)

        Accumulate probabilities from highest to lowest until reaching P, then sample only from those:

        ```
        Sorted probs:     [0.35, 0.25, 0.15, 0.10, 0.05, ...]
        Cumulative:        [0.35, 0.60, 0.75, 0.85, 0.90, ...]
        Top-P=0.9:         [0.35, 0.25, 0.15, 0.10, 0.05]  ← Top 5
                            Rest truncated
        ```

        Top-P is smarter than Top-K — when the model is confident (probability concentrated), it automatically narrows the candidate set; when uncertain (probability spread), it automatically expands it.

        ### Repeat Penalty

        Reduces the probability of tokens that have already appeared:

        $$p'_i = \\frac{p_i}{\\text{penalty}} \\quad \\text{if token } i \\text{ appeared in last } n \\text{ tokens}$$

        - `penalty = 1.0`: No penalty
        - `penalty = 1.1`: Light penalty (recommended)
        - `penalty = 1.5`: Strong penalty

        > **Small on-device models especially need repeat penalty** because their vocabulary space is limited, making them prone to falling into repetition loops like "the the the the" or "I I I I".

        ### Sampling Chain Execution Order

        Samplers in llama.cpp execute sequentially:

        ```
        Raw logits
          ↓
        [Repeat Penalty] Penalize tokens seen in last 64 tokens
          ↓
        [Top-K = 40] Keep only top 40 candidates
          ↓
        [Top-P = 0.9] Truncate to cumulative 90% probability subset
          ↓
        [Temperature = 0.7] Adjust remaining candidates' distribution
          ↓
        [Random Sample] Randomly select one token based on adjusted probabilities
        ```

        > Order matters: filter first (Top-K/P), then adjust temperature — avoid temperature amplifying long-tail noise.

        ### Recommended Configurations by Scenario

        | Scenario | Temperature | Top-K | Top-P | Repeat Penalty |
        |----------|-------------|-------|-------|----------------|
        | Classification/Extraction | 0.0-0.1 | 1-10 | 0.5 | 1.0 |
        | Code generation | 0.1-0.3 | 20 | 0.9 | 1.0 |
        | Everyday conversation | 0.7 | 40 | 0.9 | 1.1 |
        | Creative writing | 0.9-1.2 | 80 | 0.95 | 1.2 |
        | Brainstorming | 1.0-1.5 | 100 | 1.0 | 1.3 |
        """
    ),

    // ── Chapter 7 ──
    LearningModule(
        order: 7,
        title: "Performance Optimization & Monitoring",
        subtitle: "Memory management, KV Cache, thermal monitoring, GPU acceleration",
        icon: "gauge.with.dots.needle.33percent",
        color: .indigo,
        difficulty: .advanced,
        content: """
        ## Performance Engineering for On-Device Inference

        ### Key Performance Metrics

        | Metric | Formula | Good Values (1-3B Q4) | How to Measure |
        |--------|---------|----------------------|----------------|
        | TTFT | Prefill time | < 500ms | First token output time - request send time |
        | Decode Speed | tokens / decode_time | > 10 t/s | Generated tokens / Decode phase total time |
        | Peak Memory | RSS peak | < 50% device RAM | `mach_task_basic_info.resident_size` |
        | Throughput | total_tokens / total_time | > 8 t/s | Total generated tokens / Total time (incl. Prefill) |

        ### KV Cache: The Key to Memory Consumption

        During Transformer inference, each layer needs to cache the Key and Value vectors for all previous tokens — this is the KV Cache. It's the **largest memory consumer** besides model weights during on-device inference.

        KV Cache memory formula:

        $$\\text{KV Cache (MB)} = 2 \\times n_{\\text{layers}} \\times n_{\\text{ctx}} \\times d_{\\text{model}} \\times 2 \\div 1024^2$$

        The factor 2 accounts for K and V each, and the trailing ×2 is 2 bytes per FP16 value.

        Actual values (FP16 KV Cache):

        | Model | Layers | Hidden Dim | n_ctx=2048 | n_ctx=4096 |
        |-------|--------|-----------|-----------|-----------|
        | Qwen2.5-0.5B | 24 | 896 | 168 MB | 336 MB |
        | Qwen2.5-1.5B | 28 | 1536 | 330 MB | 660 MB |
        | Llama 3.2-3B | 28 | 3072 | 660 MB | 1.3 GB |

        > **Best practice**: Use `n_ctx = 2048` for on-device. Don't increase unless you genuinely need long context — KV Cache grows **linearly** with context length.

        ### Total Memory Usage

        Total memory during inference = Model weights + KV Cache + Work buffers:

        $$\\text{Total Memory} \\approx \\text{Model Weights} + \\text{KV Cache} + \\text{Buffer (~100-200MB)}$$

        Example with Qwen2.5-1.5B Q4_K_M:

        ```
        Model weights: ~1.0 GB (Q4_K_M)
        KV Cache:      ~330 MB (n_ctx=2048, FP16)
        Work buffers:  ~150 MB
        ─────────────────
        Total:         ~1.5 GB

        iPhone 15 Pro available RAM ≈ 4 GB → 37.5% usage ✓ Safe
        ```

        ### Metal GPU Acceleration

        llama.cpp uses the Metal framework for matrix multiplication on iPhone GPU:

        ```swift
        var params = llama_model_default_params()
        params.n_gpu_layers = 999  // Run all layers on GPU
        ```

        - **GPU inference speed** is typically 2-5× faster than CPU-only
        - iPhone 15 Pro GPU has 6 cores supporting FP16 matrix operations
        - GPU memory is shared with system RAM (unified memory architecture) — no separate "VRAM", but competes with system for RAM

        ### Thermal State Monitoring

        Sustained inference raises chip temperature; iOS automatically throttles to protect hardware:

        ```swift
        switch ProcessInfo.processInfo.thermalState {
        case .nominal:   // < 35°C, full speed
            break
        case .fair:      // 35-40°C, slight throttling
            break        // Can continue, speed slightly reduced
        case .serious:   // 40-45°C, significant throttling
            // Recommend pausing or reducing generation speed
            reduceBatchSize()
        case .critical:  // > 45°C, severe throttling
            // Must stop inference
            engine.cancelGeneration()
        }
        ```

        **Real-world data** (iPhone 15 Pro, Qwen2.5-1.5B Q4):
        - Single conversation (<30s): Temperature barely changes
        - Continuous benchmarking (3 min): From nominal to fair
        - Heavy continuous inference (5+ min): May reach serious

        ### UTF-8 Stream Decoding

        Chinese characters are 3 bytes, emojis are 4 bytes in UTF-8. Token boundaries may split a multi-byte character:

        ```
        "你" = UTF-8 bytes: [0xE4, 0xBD, 0xA0]

        Token 1 output: [0xE4, 0xBD]     ← Incomplete "你"
        Token 2 output: [0xA0, 0xE5...]   ← Last byte of "你" + start of next char

        Direct String conversion → garbled text!
        ```

        **Solution**: Use `UTF8StreamDecoder` to accumulate bytes, only decode when a complete character is formed. This project implements this approach.
        """
    ),

    // ── Chapter 8 ──
    LearningModule(
        order: 8,
        title: "Model Evaluation & Selection",
        subtitle: "How to scientifically evaluate and choose the right on-device model",
        icon: "chart.bar.xaxis",
        color: .mint,
        difficulty: .advanced,
        content: """
        ## Scientific Evaluation of On-Device Models

        ### Three Levels of Evaluation

        ```
        ┌─── Level 3: Business Evaluation ──────┐
        │  Real user scenarios + human assessment │
        │  Most accurate, but most time-consuming │
        ├─── Level 2: Task Evaluation ──────────┤
        │  Standardized test cases + auto scoring │
        │  What this App's Benchmark tab provides │
        ├─── Level 1: Benchmark Scores ─────────┤
        │  MMLU / GSM8K / HumanEval etc.         │
        │  Quick but may differ from real results │
        └─────────────────────────────────────────┘
        ```

        ### Automatic Quality Scoring Method

        This App uses **rule matching + keyword checking** for automatic scoring, covering these dimensions:

        | Scoring Rule | Applicable Scenario | Example |
        |-------------|-------------------|---------|
        | Keyword match | Classification, translation | Does output contain "weather query"? |
        | JSON validity | Information extraction | Can the output be parsed by JSON parser? |
        | Format matching | Format compliance | Regex check for numbered format |
        | Answer correctness | Math reasoning | Does output contain "600ms"? |
        | Refusal detection | Safety boundary | Contains "sorry", "cannot" etc.? |
        | Length range | Summary, short answer | Is output length within reasonable range? |
        | Code detection | Code completion | Contains code blocks or key APIs? |

        Scoring formula:

        $$\\text{Total Score} = \\frac{\\sum_{i \\in \\text{passed}} w_i}{\\sum_{j=1}^{n} w_j} \\times 100$$

        Where $w_i$ is the weight of rule $i$.

        Score levels:
        - **Pass** (>= 80): Model output largely meets expectations
        - **Partial Pass** (40-79): Partially correct but has issues
        - **Fail** (< 40): Output quality insufficient

        ### Common Academic Benchmarks

        | Benchmark | Dimension | Questions | Small Model Typical Scores |
        |-----------|-----------|----------|---------------------------|
        | MMLU | 57 subjects | 14,042 | 0.5B:~35%, 3B:~55% |
        | GSM8K | Math reasoning | 1,319 | 0.5B:~10%, 3B:~40% |
        | HumanEval | Python code | 164 | 0.5B:~15%, 3B:~35% |
        | C-Eval | Chinese knowledge | 13,948 | 0.5B:~35%, 3B:~50% |
        | TruthfulQA | Factuality | 817 | 0.5B:~30%, 3B:~45% |
        | ARC-Challenge | Science reasoning | 1,172 | 0.5B:~30%, 3B:~45% |

        > **Note**: Academic benchmarks may differ significantly from real-world effectiveness. **Always test with your actual use cases.**

        ### On-Device Model Selection Decision Tree

        ```
        1. Determine your core task
        │
        ├── Classification/Intent → 0.5B sufficient → Qwen2.5-0.5B
        │
        ├── Chinese conversation/summary/translation → 1.5B best value → Qwen2.5-1.5B
        │
        ├── English-primary scenarios → 1B lightweight → Llama 3.2-1B
        │
        ├── Needs reasoning/chain-of-thought → 2B+ with thinking → Gemma 4 E2B
        │
        ├── Code assistance → 3B+ strong coding → Phi-3.5 Mini
        │
        └── Ultra-lightweight priority → 360M → SmolLM2-360M

        2. Confirm device compatibility
        │
        ├── iPhone 13/14 (4-6GB) → Max 1B Q4
        ├── iPhone 15 (6GB) → Max 2B Q4
        └── iPhone 15 Pro+ (8GB) → Max 3B Q4

        3. Quantization level
        │
        └── Almost all scenarios → Q4_K_M (best balance)
        ```

        ### Evaluation Best Practices

        1. **Collect real data**: Gather 20-50 real user inputs from your app
        2. **Label expected outputs**: Manually write "ideal responses" as references
        3. **Multi-model comparison**: Use this app's benchmark feature to run identical test cases
        4. **Comprehensive assessment**: Quality score + speed + memory, weigh all three
        5. **Online validation**: Start with small-scale A/B testing, then full rollout
        """
    ),

    // ── Chapter 9 ──
    LearningModule(
        order: 9,
        title: "On-Device LLM Application Scenarios",
        subtitle: "Beyond chat: what else can on-device LLMs do on mobile?",
        icon: "sparkles",
        color: .cyan,
        difficulty: .intermediate,
        content: """
        ## Real-World Application Scenarios for On-Device LLMs

        > Core principle: On-device models are best suited for **simple, high-frequency tasks that are latency-sensitive and privacy-critical**. Choosing the right scenario matters more than choosing a bigger model.

        ---

        ### 1. Intent Recognition & Text Classification

        The most suitable on-device scenario. A 0.5B model can achieve 90%+ accuracy.

        ```
        Input: "Set an alarm for 8am tomorrow"
        Output: "set_alarm"

        Input: "What's the temperature in Shanghai today"
        Output: "weather_query"

        Input: "This product is terrible, I want a refund!"
        Output: {"sentiment": "negative", "intent": "refund"}
        ```

        **Applications**: Smart customer service routing, search intent classification, spam filtering, sentiment analysis, content moderation

        **System Prompt template**:
        ```
        You are an intent classifier. Classify user input into one of these categories:
        [weather_query, set_alarm, play_music, navigation, chitchat]
        Output only the category name, no explanation.
        ```

        ---

        ### 2. Structured Information Extraction

        Extract JSON/structured data from natural language, replacing complex regex:

        ```
        Input: "John Smith, phone 555-0123, lives at 123 Main St, Springfield"
        Output: {
          "name": "John Smith",
          "phone": "555-0123",
          "address": "123 Main St, Springfield"
        }
        ```

        **Applications**: Business card OCR, shipping label parsing, log analysis, form auto-fill, extracting dates/locations from chat

        ---

        ### 3. Input Suggestion & Auto-Complete

        Leverage on-device model's low latency for real-time input scenarios:

        **Applications**: Search box suggestions, email quick replies, code completion (lightweight), keyboard candidate word ranking

        Key requirement: TTFT < 100ms, so use ultra-small models (0.5B) or keep models resident in memory.

        ---

        ### 4. Text Summarization & Rewriting

        ```
        Input: [A 500-word news article]
        Output: "Multiple tech companies announced large-scale on-device AI deployment plans for 2026."
        ```

        **Applications**: Notification preview summaries, email summaries, article TL;DR, tone rewriting (formal ↔ casual), grammar correction

        ---

        ### 5. Offline Translation

        On-device translation requires no network, ideal for travel and reading scenarios.

        **Applications**: Real-time subtitle translation, camera viewfinder translation (OCR + translation), document reading assistance

        Note: Translation quality for specialized terminology may not match Google Translate, but everyday short sentences work well. Qwen series recommended (strong bilingual training data).

        ---

        ### 6. Local RAG (Retrieval-Augmented Generation)

        Combine on-device LLM with local vector database for offline knowledge base Q&A:

        ```
        [User Question]
            ↓
        [Vector search local document store] → Find relevant passages
            ↓
        [LLM generates answer based on passages]
            ↓
        [User sees answer + source citations]
        ```

        **Applications**: Personal notes smart search, local PDF Q&A, in-app help documentation, offline FAQ system

        ---

        ### 7. Function Calling

        Let the model convert natural language into app-internal operations:

        ```
        Input: "Set screen brightness to 50%"
        Output: {"function": "setBrightness", "params": {"level": 0.5}}

        Input: "Open the most recent photo in my gallery"
        Output: {"function": "openPhoto", "params": {"filter": "recent", "count": 1}}
        ```

        **Applications**: Voice assistants, smart home control, in-app natural language navigation, automation workflows

        Implementation key: Define function list and parameter format in system prompt. 1.5B+ models needed for good format compliance.

        ---

        ### 8. Privacy-Sensitive Scenarios

        The **irreplaceable advantage** of on-device inference — data never leaves the device:

        **Applications**:
        - Health data analysis (symptom classification, medication reminders)
        - Financial data processing (bill classification, transaction summaries)
        - Children's content filtering (COPPA compliance)
        - Enterprise internal documents (regulatory requirements for data locality)
        - Encrypted communications (AI assistance within E2E encrypted chat)

        ---

        ### Scenario Selection Quick Reference

        | Scenario | Min Requirement | Key Metric | Recommended Model | Temperature |
        |----------|----------------|-----------|------------------|-------------|
        | Intent classification | 0.5B | Accuracy > 90% | Qwen2.5-0.5B | 0.0-0.1 |
        | Info extraction | 1B | JSON validity rate | Qwen2.5-1.5B | 0.0-0.1 |
        | Input suggestion | 0.5B | TTFT < 100ms | Qwen2.5-0.5B | 0.7 |
        | Text summary | 1.5B | Info retention | Qwen2.5-1.5B | 0.3-0.5 |
        | Offline translation | 1.5B | Terminology accuracy | Qwen2.5-1.5B | 0.1-0.3 |
        | Function Calling | 1.5B+ | Format compliance | Gemma 4 E2B | 0.0-0.1 |
        | Local RAG | 1.5B+ | Answer relevance | Qwen2.5-3B | 0.3-0.5 |
        | Code assistance | 3B+ | Code correctness | Phi-3.5 Mini | 0.1-0.3 |
        """
    ),

    // ── Chapter 10 ──
    LearningModule(
        order: 10,
        title: "MoE Models & Image Classification",
        subtitle: "How on-device MoE architecture enables efficient image recognition and classification",
        icon: "photo.badge.checkmark",
        color: .orange,
        difficulty: .advanced,
        content: """
        ## MoE Models in On-Device Image Classification

        ### Why Use MoE for Image Classification?

        Traditional image classification solutions (MobileNet, ResNet) are **specialized models** — one model for one task. MoE (Mixture of Experts) LLMs are **general-purpose models** that can handle text understanding, image classification, sentiment analysis, and more simultaneously.

        ```
        Traditional Approach (Multiple Specialized Models):
        ┌─────────────────────────────────────────────┐
        │  Image Classification: MobileNet (10MB)      │
        │  Text Classification: TextCNN (5MB)          │
        │  Sentiment Analysis: BERT-tiny (50MB)        │
        │  Translation: mBART (200MB)                  │
        │  Total: 4 models, ~265MB                     │
        └─────────────────────────────────────────────┘

        MoE Approach (One General-Purpose Model):
        ┌─────────────────────────────────────────────┐
        │  MoE Model (1 file, ~2GB)                    │
        │  ├── Image description classification  ✓     │
        │  ├── Text classification               ✓     │
        │  ├── Sentiment analysis                ✓     │
        │  └── Translation                       ✓     │
        │  Total: 1 model, multi-task reuse            │
        └─────────────────────────────────────────────┘
        ```

        ### MoE Architecture Recap

        The core idea of MoE is **sparse activation**: the model has many parameters (experts), but only activates a small subset for each inference.

        ```
        Input token
            ↓
        ┌─── Router ──────────────────────────┐
        │  Calculate relevance score for each   │
        │  expert, select Top-K most relevant   │
        │  (typically K=2, using only 2 experts)│
        └──────────────┬──────────────────────┘
                       ↓
        ┌─── Expert Pool ─────────────────────┐
        │  [Expert 1] [Expert 2] [Expert 3]... │
        │     ↓          ↓                     │
        │   Active     Active   Dormant...     │
        └──────────────┬──────────────────────┘
                       ↓
              Weighted merge output
        ```

        **iOS Analogy**: MoE is like a development team — designers, frontend devs, backend devs, QA engineers. Not everyone works on every task; the router (PM) picks the 2 most relevant people for each request.

        ### Complete On-Device Image Classification Pipeline

        Since on-device LLMs primarily accept text input, image classification requires a **vision-language bridge** pipeline:

        ```
        ┌─── Stage 1: Image Feature Extraction ───────┐
        │  Input: UIImage / CGImage                     │
        │  Tool: Apple Vision Framework / CoreML        │
        │  Output: Text description (Caption)           │
        │                                               │
        │  Option A: VNClassifyImageRequest (built-in)  │
        │            → "cat, indoor, sitting"           │
        │  Option B: CoreML image captioning model      │
        │            → "A cat sitting on a sofa"        │
        │  Option C: Predefined label matching          │
        │            → Direct Vision confidence ranking │
        └───────────────────┬───────────────────────────┘
                            ↓
        ┌─── Stage 2: LLM Smart Classification ────────┐
        │  Input: Image description text                │
        │  Tool: On-device MoE model (DeepSeek, Gemma4) │
        │                                               │
        │  System Prompt:                               │
        │  "You are an image classifier. Based on the   │
        │   description, classify into: airplane /      │
        │   automobile / bird / cat / deer / dog /      │
        │   frog / horse / ship / truck                 │
        │   Output only the category name."             │
        │                                               │
        │  User: "An orange cat curled up on a sofa"    │
        │  Model output: "cat"                          │
        └───────────────────┬───────────────────────────┘
                            ↓
        ┌─── Stage 3: Post-Processing & Confidence ────┐
        │  Parse model output, match to predefined      │
        │  categories. Combine with Vision confidence   │
        │  Output: Classification result + confidence   │
        └───────────────────────────────────────────────┘
        ```

        ### MoE Advantages in Classification Tasks

        **1. Expert Routing Enables "Task Adaptation"**

        When the input is an image description, the Router automatically selects experts best at understanding visual concepts:

        ```
        Input: "A silver airplane flying in blue sky with clouds"
        Router selects:
          → Expert #7 (object recognition)  weight: 0.6
          → Expert #12 (scene understanding) weight: 0.4

        Input: "Please translate this to Chinese"
        Router selects:
          → Expert #3 (language conversion)  weight: 0.7
          → Expert #9 (grammar)              weight: 0.3
        ```

        **2. Computational Efficiency**

        MoE models have many total parameters but use only a subset per inference:

        | Model | Total Params | Active Params | Speed (iPhone 15 Pro) |
        |-------|-------------|--------------|----------------------|
        | Dense 3B | 3B | 3B | ~12 t/s |
        | MoE 8×3B | 24B | 3B | ~10-12 t/s |
        | MoE 8×7B | 56B | 7B | Out of memory |

        MoE inference speed is close to the **active parameter count** equivalent Dense model, but total knowledge capacity far exceeds it.

        **3. Classification-Specific Optimizations**

        For classification tasks, use **very low temperature + limited output length**:

        ```swift
        let classificationConfig = GenerationConfig(
            maxTokens: 32,        // Classification output is very short
            temperature: 0.1,     // Near-greedy, most confident answer
            topP: 0.5,
            topK: 10,
            repeatPenalty: 1.0    // No repeat penalty needed for classification
        )
        ```

        ### Swift Code Examples

        #### Using Vision Framework for Image Description

        ```swift
        import Vision

        func classifyImage(_ image: CGImage) async -> [String] {
            let request = VNClassifyImageRequest()
            let handler = VNImageRequestHandler(cgImage: image)

            try? handler.perform([request])

            guard let results = request.results as? [VNClassificationObservation] else {
                return []
            }

            // Return labels with confidence > 30%
            return results
                .filter { $0.confidence > 0.3 }
                .prefix(5)
                .map { "\\($0.identifier): \\(String(format: "%.0f%%", $0.confidence * 100))" }
        }
        ```

        #### Combining with LLM for Smart Classification

        ```swift
        func classifyWithLLM(imageLabels: [String], provider: AIModelProvider) async -> String {
            let description = imageLabels.joined(separator: ", ")
            let prompt = \"\"\"
            You are an image classifier. Based on the following Vision labels, classify into:
            airplane / automobile / bird / cat / deer / dog / frog / horse / ship / truck
            Output only the category name.

            Labels: \\(description)
            \"\"\"

            let messages = [ChatMessage(role: .user, content: prompt)]
            let config = GenerationConfig(maxTokens: 32, temperature: 0.1)

            var result = ""
            let stream = provider.chat(messages: messages, config: config)
            for try await token in stream {
                result += token.text
            }
            return result.trimmingCharacters(in: .whitespacesAndNewlines)
        }
        ```

        ### Performance Metrics & Optimization Tips

        #### On-Device Image Classification Performance Targets

        | Metric | Target | Notes |
        |--------|--------|-------|
        | Classification Accuracy | > 85% | 10-class classification |
        | Per-Image Latency | < 500ms | Vision + LLM total |
        | Memory Usage | < 2GB | Model + KV Cache |
        | Throughput | > 5 images/sec | Batch processing scenarios |

        #### Optimization Strategies

        **1. Minimize System Prompt**
        - Shorter prompt → faster Prefill → lower latency
        - Classification prompts should be under 100 tokens

        **2. Limit Output Length**
        - `maxTokens = 32` is sufficient for category names
        - Prevents the model from "verbose" explanations

        **3. Keep Model Resident in Memory**
        - If classification is frequent, avoid load/unload cycles
        - Monitor memory pressure, only unload on `didReceiveMemoryWarning`

        **4. Batch Processing**
        - For photo album classification, don't load → classify → unload per image
        - Load once, classify all images, then unload

        ### Recommended On-Device MoE Models

        | Model | Total Params | Active Params | Use Case |
        |-------|-------------|--------------|----------|
        | Gemma 4 E2B | 2.3B | ~2B | Lightweight classification, iPhone 15+ |
        | DeepSeek MoE 16B | 16B | ~2.8B | High-accuracy classification (high memory) |
        | Mixtral 8×7B | 46.7B | ~12.9B | Server / iPad Pro only |

        > **Current Recommendation**: For iPhone on-device image classification, use **Gemma 4 E2B** or a comparable Dense model (e.g., Qwen2.5-1.5B). MoE's advantage is that **one model serves multiple tasks**, reducing total model count.

        ### Comparison with Traditional Approaches

        | Dimension | CoreML MobileNet | On-Device LLM Classification |
        |-----------|-----------------|------------------------------|
        | Accuracy | 90%+ (ImageNet) | 80-90% (depends on description quality) |
        | Latency | 10-50ms | 200-500ms |
        | Flexibility | Fixed categories | Any categories (just change prompt) |
        | Model Size | 10-30MB | 0.5-2GB |
        | Explainability | Low (probabilities) | High (can request reasoning) |
        | Multi-task | Needs multiple models | One model, many tasks |

        > **Best Practice**: For fixed categories requiring high speed, use CoreML. For flexible categories requiring context understanding, use LLM. Combine both: CoreML for coarse classification → LLM for fine-grained or confirmation.
        """
    ),
]
