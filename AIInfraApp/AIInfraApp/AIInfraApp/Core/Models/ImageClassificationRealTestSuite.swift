import Foundation

// MARK: - 真实图片分类测试套件

/// 使用 CIFAR-10 真实图片进行分类测试
/// 图片通过 ImageDatasetManager 下载到本地，运行时加载图片 Data 送入多模态模型
struct RealImageTestCase {
    let category: String     // CIFAR-10 类别名 (如 "airplane")
    let imageIndex: Int      // 图片编号 (0-49)
    let groundTruthLabel: String  // 正确分类标签

    /// 本地图片路径
    var localPath: URL {
        ImageDatasetManager.localImagePath(category: category, index: imageIndex)
    }

    /// 加载图片 Data
    func loadImageData() -> Data? {
        ImageDatasetManager.shared.loadImageData(category: category, index: imageIndex)
    }
}

extension BenchmarkTestCase {

    /// 真实图片分类测试集（500 张 CIFAR-10 图片）
    /// 需要先通过 ImageDatasetManager 下载图片到本地
    static let realImageClassificationSuite: [BenchmarkTestCase] = {
        let systemPrompt = """
        You are an image classifier. Look at the image and classify it into one of these categories:
        airplane / automobile / bird / cat / deer / dog / frog / horse / ship / truck
        Output ONLY the category name, nothing else.
        """

        let categories: [(name: String, aliases: [String])] = [
            ("airplane", ["plane", "jet", "aircraft", "飞机"]),
            ("automobile", ["car", "vehicle", "sedan", "汽车"]),
            ("bird", ["birds", "鸟"]),
            ("cat", ["kitten", "feline", "猫"]),
            ("deer", ["fawn", "stag", "doe", "鹿"]),
            ("dog", ["puppy", "canine", "hound", "狗"]),
            ("frog", ["toad", "amphibian", "蛙", "青蛙"]),
            ("horse", ["stallion", "mare", "pony", "马"]),
            ("ship", ["boat", "vessel", "yacht", "船"]),
            ("truck", ["lorry", "pickup", "卡车"])
        ]

        var cases: [BenchmarkTestCase] = []

        for cat in categories {
            for i in 0..<ImageDatasetManager.imagesPerCategory {
                // 图片路径作为 testImageNames 传递（相对于 ImageDatasets 目录）
                let imagePath = "cifar10/\(cat.name)/\(String(format: "%04d.jpg", i))"

                cases.append(BenchmarkTestCase(
                    name: "Real-\(cat.name)-\(String(format: "%02d", i))",
                    category: .imageClassification,
                    prompt: systemPrompt,
                    qualityRules: [
                        QualityRule(
                            name: "Correct classification",
                            type: .exactClassification,
                            weight: 3,
                            params: [cat.name] + cat.aliases
                        ),
                        QualityRule(
                            name: "Concise output",
                            type: .lengthRange,
                            weight: 1,
                            params: ["1", "30"]
                        )
                    ],
                    testImageNames: [imagePath]
                ))
            }
        }

        return cases
    }()

    /// 真实图片分类测试集（中文 prompt 版本）
    static let realImageClassificationSuiteCN: [BenchmarkTestCase] = {
        let systemPrompt = """
        你是一个图片分类器。观察这张图片，将其分类为以下类别之一：
        airplane / automobile / bird / cat / deer / dog / frog / horse / ship / truck
        只输出英文类别名称，不要解释。
        """

        let categories: [(name: String, aliases: [String])] = [
            ("airplane", ["plane", "jet", "aircraft", "飞机"]),
            ("automobile", ["car", "vehicle", "sedan", "汽车"]),
            ("bird", ["birds", "鸟"]),
            ("cat", ["kitten", "feline", "猫"]),
            ("deer", ["fawn", "stag", "doe", "鹿"]),
            ("dog", ["puppy", "canine", "hound", "狗"]),
            ("frog", ["toad", "amphibian", "蛙", "青蛙"]),
            ("horse", ["stallion", "mare", "pony", "马"]),
            ("ship", ["boat", "vessel", "yacht", "船"]),
            ("truck", ["lorry", "pickup", "卡车"])
        ]

        var cases: [BenchmarkTestCase] = []

        for cat in categories {
            for i in 0..<ImageDatasetManager.imagesPerCategory {
                let imagePath = "cifar10/\(cat.name)/\(String(format: "%04d.jpg", i))"

                cases.append(BenchmarkTestCase(
                    name: "真实图片-\(cat.name)-\(String(format: "%02d", i))",
                    category: .imageClassification,
                    prompt: systemPrompt,
                    qualityRules: [
                        QualityRule(
                            name: "分类正确",
                            type: .exactClassification,
                            weight: 3,
                            params: [cat.name] + cat.aliases
                        ),
                        QualityRule(
                            name: "输出简洁",
                            type: .lengthRange,
                            weight: 1,
                            params: ["1", "30"]
                        )
                    ],
                    testImageNames: [imagePath]
                ))
            }
        }

        return cases
    }()
}
