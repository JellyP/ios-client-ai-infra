# iOS On-Device AI Infra

**[中文版](README_zh.md)**

An educational iOS application for learning and experimenting with on-device large language model (LLM) inference. Built with SwiftUI and llama.cpp, this project helps iOS developers understand, deploy, and benchmark on-device AI models without requiring prior AI/ML experience.

## Features

- **On-Device LLM Chat** -- Interactive chat with models running entirely on iPhone. Supports Qwen, Llama, Gemma 4, Phi, and SmolLM families.
- **Model Download Store** -- Browse, download, and manage GGUF model files directly in the app. Includes China mirror support (hf-mirror.com) for users in mainland China.
- **Performance Benchmarking** -- Run standardized test suites across multiple models with automated quality scoring. Compare speed, latency, memory usage, and output quality side by side.
- **Learning Center** -- 9-chapter interactive guide covering Transformer architecture, quantization, sampling strategies, llama.cpp integration, performance optimization, and more. All content rendered as Markdown with LaTeX math formula support.
- **Markdown Rendering** -- Model responses and learning content rendered with full Markdown support including code syntax highlighting, tables, and LaTeX math via the Textual library.
- **Chat History** -- Conversations are automatically saved and can be resumed. Useful for comparing how different models respond to the same prompts.
- **Bilingual Interface** -- Full Chinese and English support with in-app language switching.

## Supported Models

| Model | Parameters | Quantization | File Size | Strengths |
|-------|-----------|-------------|-----------|-----------|
| Qwen2.5 0.5B | 0.5B | Q4_K_M | ~400 MB | Ultra-lightweight, decent Chinese |
| Qwen2.5 1.5B | 1.5B | Q4_K_M | ~1 GB | Best Chinese at this size |
| Qwen2.5 3B | 3B | Q4_K_M | ~2 GB | Strong Chinese comprehension |
| Llama 3.2 1B | 1B | Q4_K_M | ~750 MB | Good English, lightweight |
| Llama 3.2 3B | 3B | Q4_K_M | ~2 GB | Balanced general ability |
| Gemma 2 2B | 2B | Q4_K_M | ~1.6 GB | High training data quality |
| Gemma 4 E2B | 2.3B | Q4_K_M | ~3.1 GB | Built-in chain-of-thought reasoning |
| Phi-3.5 Mini | 3.8B | Q4_K_M | ~2.3 GB | Strong reasoning and code |
| SmolLM2 360M | 360M | Q8_0 | ~386 MB | Runs on any iPhone |

## Requirements

- **iOS 18.0+**
- **Xcode 16.0+** (with Swift 5.9+)
- **Recommended device**: iPhone 15 Pro or newer (8GB RAM, A17 Pro chip)
- Minimum for lightweight models (0.5-1B): iPhone 13 or newer

## Getting Started

1. **Clone the repository**

   ```bash
   git clone https://github.com/user/ios-client-ai-infra.git
   cd ios-client-ai-infra
   ```

2. **Open the Xcode project**

   ```
   open AIInfraApp/AIInfraApp/AIInfraApp.xcodeproj
   ```

3. **Build and run** on a physical device (recommended) or simulator

4. **Download a model** -- Go to the "Models" tab, enter the Model Store, and download a model. Qwen2.5 0.5B is recommended for first-time users.

5. **Start chatting** -- Switch to the "Chat" tab, select your downloaded model, and start a conversation.

## Architecture

```
AIInfraApp/
├── Core/
│   ├── Protocols/
│   │   └── AIModelProvider.swift       # Unified provider protocol
│   ├── Models/
│   │   ├── ChatModels.swift            # Chat messages, sessions, configs
│   │   └── BenchmarkModels.swift       # Test cases, quality scoring rules
│   └── Utils/
│       ├── LanguageManager.swift       # In-app language switching
│       ├── L10n.swift                  # Localized UI strings
│       ├── ChatHistoryStore.swift      # JSON-based chat persistence
│       ├── APIKeyStore.swift           # Download mirror settings
│       └── DeviceUtils.swift           # Memory, thermal monitoring
├── Features/
│   ├── Chat/ChatView.swift             # Chat interface with Markdown
│   ├── Benchmark/BenchmarkView.swift   # Benchmark with quality scoring
│   ├── ModelManager/                   # Model list, download store
│   └── Learn/                          # 9-chapter learning center
├── Providers/
│   └── OnDeviceProvider/
│       ├── LlamaEngine.swift           # llama.cpp Swift bridge
│       ├── LlamaOnDeviceProvider.swift # On-device provider implementation
│       ├── GGUFModelCatalog.swift      # Model download registry
│       └── ModelDownloadManager.swift  # Download/pause/resume manager
└── LocalPackages/
    └── LlamaFramework/                # llama.cpp xcframework (SPM binary)
```

### Key Design Decisions

- **Protocol-driven architecture**: All model providers conform to `AIModelProvider`, making it easy to add new model backends.
- **llama.cpp via SPM binary target**: Pre-compiled xcframework avoids building C++ from source. Metal GPU acceleration enabled by default.
- **UTF-8 stream decoding**: Custom `UTF8StreamDecoder` handles multi-byte character boundaries at token edges, preventing garbled Chinese/emoji output.
- **Per-model chat templates**: Automatic model family detection (`detectModelFamily()`) applies the correct prompt format (ChatML for Qwen, Llama3 format for Llama, etc.).

## Benchmark Quality Scoring

The benchmark system includes automated quality evaluation using 8 rule types:

| Rule Type | Description |
|-----------|-------------|
| `containsAny` | Output contains at least one expected keyword |
| `containsAll` | Output contains all expected keywords |
| `notContains` | Output does not contain forbidden terms |
| `validJSON` | Output is valid JSON with required fields |
| `matchesRegex` | Output matches a regular expression pattern |
| `lengthRange` | Output length within expected range |
| `exactAnswer` | Output contains the correct answer |
| `containsCodeBlock` | Output includes code content |

Each test case has weighted scoring rules. Results are displayed as Pass (>=80) / Partial (40-79) / Fail (<40).

## License

MIT
