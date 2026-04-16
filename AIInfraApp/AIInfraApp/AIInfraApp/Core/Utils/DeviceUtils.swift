import Foundation

// MARK: - 内存监控工具

/// 获取当前 App 的内存使用情况
enum MemoryUtils {

    /// 获取当前已使用的物理内存（bytes）
    static var currentMemoryUsage: UInt64 {
        var info = mach_task_basic_info()
        var count = mach_msg_type_number_t(MemoryLayout<mach_task_basic_info>.size) / 4
        let result = withUnsafeMutablePointer(to: &info) {
            $0.withMemoryRebound(to: integer_t.self, capacity: Int(count)) {
                task_info(mach_task_self_, task_flavor_t(MACH_TASK_BASIC_INFO), $0, &count)
            }
        }
        guard result == KERN_SUCCESS else {
            return 0
        }
        return info.resident_size
    }

    /// 获取设备总物理内存（bytes）
    static var totalMemory: UInt64 {
        ProcessInfo.processInfo.physicalMemory
    }

    /// 获取可用内存（bytes，粗略估算）
    static var availableMemory: UInt64 {
        var vmStats = vm_statistics64()
        var infoCount = mach_msg_type_number_t(MemoryLayout<vm_statistics64>.stride / MemoryLayout<integer_t>.stride)
        let result = withUnsafeMutablePointer(to: &vmStats) {
            $0.withMemoryRebound(to: integer_t.self, capacity: Int(infoCount)) {
                host_statistics64(mach_host_self(), HOST_VM_INFO64, $0, &infoCount)
            }
        }
        guard result == KERN_SUCCESS else {
            return 0
        }
        let pageSize = UInt64(vm_kernel_page_size)
        return UInt64(vmStats.free_count) * pageSize
    }

    /// 格式化字节数为可读字符串
    static func formatBytes(_ bytes: UInt64) -> String {
        let formatter = ByteCountFormatter()
        formatter.countStyle = .memory
        return formatter.string(fromByteCount: Int64(bytes))
    }

    /// 格式化字节数为可读字符串（Int64 版本）
    static func formatBytes(_ bytes: Int64) -> String {
        let formatter = ByteCountFormatter()
        formatter.countStyle = .memory
        return formatter.string(fromByteCount: bytes)
    }
}

// MARK: - 设备温度监控

/// 设备热状态监控
@Observable
final class ThermalMonitor {
    var thermalState: ProcessInfo.ThermalState = .nominal
    var shouldThrottle: Bool { thermalState == .serious || thermalState == .critical }

    init() {
        thermalState = ProcessInfo.processInfo.thermalState
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(thermalStateChanged),
            name: ProcessInfo.thermalStateDidChangeNotification,
            object: nil
        )
    }

    @objc private func thermalStateChanged() {
        thermalState = ProcessInfo.processInfo.thermalState
    }

    var stateDescription: String {
        switch thermalState {
        case .nominal: return "正常"
        case .fair: return "微热"
        case .serious: return "较热"
        case .critical: return "过热"
        @unknown default: return "未知"
        }
    }
}

// MARK: - 计时工具

/// 简单的计时器，用于性能测量
struct StopWatch {
    private var startTime: CFAbsoluteTime = 0
    private var lapTime: CFAbsoluteTime = 0

    mutating func start() {
        startTime = CFAbsoluteTimeGetCurrent()
        lapTime = startTime
    }

    mutating func lap() -> TimeInterval {
        let now = CFAbsoluteTimeGetCurrent()
        let elapsed = now - lapTime
        lapTime = now
        return elapsed
    }

    func elapsed() -> TimeInterval {
        CFAbsoluteTimeGetCurrent() - startTime
    }
}
