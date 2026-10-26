import Foundation
import Darwin

public struct SystemStats {
    public let cpuPercent: Int
    public let ramUsedGB: Double
    public let ramTotalGB: Double
    public let ramPercent: Int
}

public class SystemStatsService {
    public static let shared = SystemStatsService()
    
    private var previousCPULoad: host_cpu_load_info?
    
    public init() {}
    
    public func getStats() -> SystemStats {
        let cpu = getCPULoad()
        let mem = getMemoryUsage()
        return SystemStats(
            cpuPercent: cpu,
            ramUsedGB: mem.usedGB,
            ramTotalGB: mem.totalGB,
            ramPercent: mem.percent
        )
    }
    
    private func getCPULoad() -> Int {
        var load = host_cpu_load_info()
        var count = mach_msg_type_number_t(MemoryLayout<host_cpu_load_info>.size / MemoryLayout<integer_t>.size)
        let kerr = withUnsafeMutablePointer(to: &load) {
            $0.withMemoryRebound(to: integer_t.self, capacity: Int(count)) {
                host_statistics(mach_host_self(), HOST_CPU_LOAD_INFO, $0, &count)
            }
        }
        
        guard kerr == KERN_SUCCESS else { return 5 }
        defer { previousCPULoad = load }
        
        guard let prev = previousCPULoad else { return 10 }
        
        let user = Double(load.cpu_ticks.0 - prev.cpu_ticks.0)
        let sys = Double(load.cpu_ticks.1 - prev.cpu_ticks.1)
        let idle = Double(load.cpu_ticks.2 - prev.cpu_ticks.2)
        let nice = Double(load.cpu_ticks.3 - prev.cpu_ticks.3)
        
        let total = user + sys + idle + nice
        guard total > 0 else { return 5 }
        
        let used = user + sys + nice
        return Int(min(100, max(0, (used / total) * 100)))
    }
    
    private func getMemoryUsage() -> (usedGB: Double, totalGB: Double, percent: Int) {
        var stats = vm_statistics64()
        var count = mach_msg_type_number_t(MemoryLayout<vm_statistics64>.size / MemoryLayout<integer_t>.size)
        let kerr = withUnsafeMutablePointer(to: &stats) {
            $0.withMemoryRebound(to: integer_t.self, capacity: Int(count)) {
                host_statistics64(mach_host_self(), HOST_VM_INFO64, $0, &count)
            }
        }
        
        let totalBytes = ProcessInfo.processInfo.physicalMemory
        let totalGB = Double(totalBytes) / (1024 * 1024 * 1024)
        
        if kerr == KERN_SUCCESS {
            let pageSize = UInt64(vm_kernel_page_size)
            let active = UInt64(stats.active_count) * pageSize
            let wired = UInt64(stats.wire_count) * pageSize
            let compressed = UInt64(stats.compressor_page_count) * pageSize
            let usedBytes = active + wired + compressed
            let usedGB = Double(usedBytes) / (1024 * 1024 * 1024)
            let pct = Int((Double(usedBytes) / Double(totalBytes)) * 100)
            return (usedGB, totalGB, min(100, max(0, pct)))
        }
        return (0, totalGB, 0)
    }
}

