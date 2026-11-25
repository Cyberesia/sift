import Foundation

#if canImport(Darwin)
import Darwin
#endif

/// Decides how hard Sift may work right now.
///
/// While the window is in front, scans run at user priority. Once Sift is only in the menu bar it behaves
/// like a backup or antivirus agent: efficiency cores, pauses while the Mac is hot, on Low Power Mode,
/// or under memory pressure, and resumes on its own.
public final class ResourceGovernor: @unchecked Sendable {
    public static let shared = ResourceGovernor()

    public enum Mode: String, Sendable {
        /// The person is looking at Sift.
        case foreground
        /// Window closed or another app in front.
        case background
    }

    public enum Hold: String, Sendable, Equatable {
        case thermal = "The Mac is warm"
        case lowPower = "Low Power Mode is on"
        case memory = "Memory is tight"
    }

    private let lock = NSLock()
    private var _mode: Mode = .foreground
    private var memoryPressure: DispatchSource.MemoryPressureEvent = .normal
    private var pressureSource: DispatchSourceMemoryPressure?

    /// RAM on this Mac.
    public let physicalMemory: UInt64

    init(physicalMemory: UInt64 = ProcessInfo.processInfo.physicalMemory) {
        self.physicalMemory = physicalMemory
        #if os(macOS)
        let source = DispatchSource.makeMemoryPressureSource(eventMask: [.normal, .warning, .critical], queue: .global(qos: .utility))
        source.setEventHandler { [weak self] in
            guard let self else { return }
            let event = source.data
            self.lock.lock()
            self.memoryPressure = event
            self.lock.unlock()
        }
        source.resume()
        pressureSource = source
        #endif
    }

    private var _pinned: Mode?

    public var mode: Mode {
        get { lock.lock(); defer { lock.unlock() }; return _pinned ?? _mode }
        set { lock.lock(); _mode = newValue; lock.unlock() }
    }

    /// Holds a mode regardless of window focus (a screen recording), or nil to follow the window again.
    public var pinnedMode: Mode? {
        get { lock.lock(); defer { lock.unlock() }; return _pinned }
        set { lock.lock(); _pinned = newValue; lock.unlock() }
    }

    // MARK: - Priorities

    /// Directory walks: quick while watched, gentle in the background.
    public var scanPriority: TaskPriority { mode == .foreground ? .userInitiated : .utility }

    /// Vision, CLIP, document reading, previews. Never `.userInitiated`: a click must always win.
    public var analysisPriority: TaskPriority { mode == .foreground ? .utility : .background }

    /// Pause between files when nobody is looking, so the fans stay quiet on a 2 TB catalog.
    public var interItemDelay: Duration { mode == .foreground ? .zero : .milliseconds(40) }

    // MARK: - Holds

    /// Why work should wait right now, or nil.
    public var currentHold: Hold? {
        let info = ProcessInfo.processInfo
        switch info.thermalState {
        case .serious, .critical: return .thermal
        default: break
        }
        lock.lock()
        let pressure = memoryPressure
        let currentMode = _pinned ?? _mode
        lock.unlock()
        if pressure.contains(.critical) { return .memory }
        if currentMode == .background {
            if info.isLowPowerModeEnabled { return .lowPower }
            if pressure.contains(.warning) { return .memory }
        }
        return nil
    }

    /// Sleeps while a hold applies. Cancellation ends the wait.
    public func waitWhileHeld(onHold: (@Sendable (Hold) -> Void)? = nil) async throws {
        var announced = false
        while let hold = currentHold {
            if !announced { onHold?(hold); announced = true }
            try await Task.sleep(for: .seconds(2))
        }
    }

    // MARK: - Memory budget

    /// Memory that can be handed out without paging: free, inactive, purgeable and speculative pages.
    public var availableMemory: UInt64 {
        #if os(macOS)
        var stats = vm_statistics64()
        var count = mach_msg_type_number_t(MemoryLayout<vm_statistics64_data_t>.size / MemoryLayout<integer_t>.size)
        let result = withUnsafeMutablePointer(to: &stats) {
            $0.withMemoryRebound(to: integer_t.self, capacity: Int(count)) {
                host_statistics64(mach_host_self(), HOST_VM_INFO64, $0, &count)
            }
        }
        guard result == KERN_SUCCESS else { return physicalMemory / 4 }
        let pageSize = UInt64(getpagesize())
        let pages = UInt64(stats.free_count) + UInt64(stats.inactive_count)
            + UInt64(stats.purgeable_count) + UInt64(stats.speculative_count)
        return pages * pageSize
        #else
        return physicalMemory / 4
        #endif
    }

    /// The most a single file read may cost.
    ///
    /// Scanning holds only metadata (about 1 KB per file, whatever its size), so a 500-file batch is
    /// well under a megabyte even when every file is a 4 GB video. What can be large is a reader that
    /// loads content: a huge TIFF, a PDF, a spreadsheet's XML. Those are admitted against this budget:
    /// 5 % of RAM, never more than half of what is free now, between 64 MB and 1 GB.
    public var perFileReadBudget: UInt64 {
        Self.readBudget(physical: physicalMemory, available: availableMemory)
    }

    static func readBudget(physical: UInt64, available: UInt64) -> UInt64 {
        let floor: UInt64 = 64 << 20
        let ceiling: UInt64 = 1 << 30
        let share = physical / 20
        let headroom = available / 2
        return min(ceiling, max(floor, min(share, headroom)))
    }

    /// Bytes a reader is expected to hold in memory for this file. Videos and audio are streamed in
    /// small pieces and photos are decoded at a capped size, so their file size is not their cost.
    public static func estimatedReadCost(kind: MediaKind, fileSize: Int64?, fileExtension: String) -> UInt64 {
        let size = UInt64(max(0, fileSize ?? 0))
        switch kind {
        case .video, .audio:
            return 32 << 20
        case .image:
            // ImageIO maps the file and decodes a downsampled copy. Raw and layered formats decode larger.
            let heavy = ["tif", "tiff", "psd", "psb", "dng", "cr2", "nef", "arw", "raw"].contains(fileExtension.lowercased())
            return heavy ? size : min(size, 96 << 20)
        case .document:
            switch fileExtension.lowercased() {
            case "txt", "md", "mdx", "csv", "rtf":
                return min(size, 200_000) // readers stop at 200 KB
            case "pdf":
                return min(size, 256 << 20) // PDFKit maps pages; only the first two are read
            default:
                return min(size, 4 << 20) // Office XML is streamed through unzip and capped at 180 KB
            }
        }
    }

    /// True when the file can be read without risking the Mac's memory.
    public func admitsRead(kind: MediaKind, fileSize: Int64?, fileExtension: String) -> Bool {
        Self.estimatedReadCost(kind: kind, fileSize: fileSize, fileExtension: fileExtension) <= perFileReadBudget
    }
}
