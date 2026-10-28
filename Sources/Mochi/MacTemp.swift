import Foundation
import Darwin

/// Processor temperature (best effort). macOS has no clean public API:
/// 1) try `ioreg` for a real sensor value (throttled — it's a subprocess),
/// 2) else estimate from instantaneous CPU load (plausible warmth).
/// Used only while an egg is incubating (the shell displays it).
enum MacTemp {
    private static var lastSensor: Double?
    private static var lastSensorRead = Date.distantPast

    // MARK: - CPU load (Mach, instantaneous delta)

    private struct Ticks { var busy = 0.0; var total = 0.0 }

    private static func snapshot() -> Ticks? {
        var info = host_cpu_load_info_data_t()
        var count = mach_msg_type_number_t(
            MemoryLayout<host_cpu_load_info_data_t>.size / MemoryLayout<integer_t>.size)
        let kr = withUnsafeMutablePointer(to: &info) { ptr -> kern_return_t in
            ptr.withMemoryRebound(to: integer_t.self, capacity: Int(count)) {
                host_statistics64(mach_host_self(), HOST_CPU_LOAD_INFO, $0, &count)
            }
        }
        guard kr == KERN_SUCCESS else { return nil }
        let t = info.cpu_ticks
        let user = Double(t.0), sys = Double(t.1), idle = Double(t.2), nice = Double(t.3)
        return Ticks(busy: user + sys + nice, total: user + sys + idle + nice)
    }

    private static var prev: Ticks?
    static var lastLoad: Double = 20

    static func cpuLoadPercent() -> Double {
        guard let now = snapshot() else { return lastLoad }
        defer { prev = now }
        guard let before = prev, now.total > before.total else { return lastLoad }
        let dTotal = now.total - before.total
        let dBusy = now.busy - before.busy
        let load = dTotal > 0 ? max(0, min(100, 100 * dBusy / dTotal)) : 0
        lastLoad = load
        return load
    }

    // MARK: - ioreg sensor (throttled)

    private static func sensorCelsius() -> Double? {
        let p = Process()
        p.executableURL = URL(fileURLWithPath: "/usr/sbin/ioreg")
        p.arguments = ["-l", "-w", "0"]
        let pipe = Pipe()
        p.standardOutput = pipe
        p.standardError = Pipe()
        do {
            try p.run()
        } catch { return nil }
        _ = try? pipe.fileHandleForReading.readDataToEndOfFile()
        p.waitUntilExit()
        guard p.terminationStatus == 0,
              let out = String(data: pipe.fileHandleForReading.readDataToEndOfFile(), encoding: .utf8) else { return nil }
        // any key containing "Temperature" / "Die Temp" with a number
        let pattern = "\"[^\"]*[Tt]emperature[^\"]*\"\\s*=\\s*(\\d+)"
        guard let re = try? NSRegularExpression(pattern: pattern) else { return nil }
        let ns = out as NSString
        for m in re.matches(in: out, range: NSRange(location: 0, length: ns.length)) {
            if let n = Int(ns.substring(with: m.range(at: 1))) {
                if n > 15000, n < 115000 { return Double(n) / 1000 }   // milli-celsius
                if n >= 15, n < 115 { return Double(n) }              // celsius
            }
        }
        return nil
    }

    /// Current CPU temperature in °C (real sensor when ioreg has one,
    /// else a load-based estimate — "about").
    static func read() -> Double {
        let load = cpuLoadPercent()
        let now = Date()
        if now.timeIntervalSince(lastSensorRead) > 30 {
            lastSensorRead = now
            if let t = sensorCelsius() { lastSensor = t }
        }
        if let t = lastSensor { return t }
        return 32 + 0.45 * load   // idle ~32°C, full blast ~77°C
    }
}