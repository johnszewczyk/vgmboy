import Foundation
import ScanSongKit

/// Keeps operation callbacks off the main actor until the UI is ready to
/// sample one. Scanner and link-maintenance workers can report much faster
/// than a window can render; retaining only the latest value prevents progress
/// delivery from becoming a second, unbounded operation queue.
final class LatestValueBuffer<Value: Sendable>: @unchecked Sendable {
    private let lock = NSLock()
    private var latest: Value?
    private var didFinish = false

    func publish(_ update: Value) {
        lock.lock()
        latest = update
        lock.unlock()
    }

    func finish() {
        lock.lock()
        didFinish = true
        lock.unlock()
    }

    func take() -> Value? {
        lock.lock()
        defer { lock.unlock() }
        let update = latest
        latest = nil
        return update
    }

    var isFinished: Bool {
        lock.lock()
        defer { lock.unlock() }
        return didFinish
    }
}

enum ScannerProgressDelivery {
    static let sampleIntervalNanoseconds: UInt64 = 250_000_000
}

enum ScannerOperationKind: String, Sendable {
    case scan = "Scan"
    case checkLinks = "Check Links"
    case removeLinks = "Remove Links"
    case addPath = "Add Path"
    case managePaths = "Update Paths"
    case catalog = "Catalog"
}

struct ScannerOperationProgress: Sendable {
    let operation: ScannerOperationKind
    let phase: String
    let processed: Int
    let total: Int?
    let failures: Int
    let detail: String?

    var fraction: Double? {
        guard let total, total > 0 else { return nil }
        if operation == .scan,
           !["planning", "inspection"].contains(phase) {
            return nil
        }
        return min(max(Double(processed) / Double(total), 0), 1)
    }

    var phaseLabel: String {
        switch phase {
        case "opening": return "Opening catalog"
        case "adding": return "Adding paths"
        case "updating": return "Updating paths"
        case "preparing": return "Preparing"
        case "discovery": return "Discovering sources"
        case "planning": return "Planning"
        case "archiveListing": return "Reading archive"
        case "materialization": return "Preparing archive members"
        case "inspection": return "Inspecting sources"
        case "persistence": return "Saving checkpoints"
        case "publication": return "Publishing catalog"
        case "cleanup": return "Cleaning up"
        case "maintenance": return "Checking catalog"
        default: return operation.rawValue
        }
    }
}

struct ScannerOperationTelemetry: Sendable {
    let operation: ScannerOperationKind
    let startedAt: Date
    let completedAt: Date
    let processed: Int
    let total: Int?
    let failures: Int
    let result: String

    static func durationText(seconds rawSeconds: TimeInterval) -> String {
        let seconds = max(0, Int(rawSeconds.rounded()))
        let hours = seconds / 3_600
        let minutes = (seconds % 3_600) / 60
        let remainder = seconds % 60
        return hours > 0
            ? String(format: "%02d:%02d:%02d", hours, minutes, remainder)
            : String(format: "%02d:%02d", minutes, remainder)
    }

    var durationText: String {
        Self.durationText(seconds: completedAt.timeIntervalSince(startedAt))
    }

    var completionTimeText: String {
        DateFormatter.localizedString(from: completedAt, dateStyle: .none, timeStyle: .short)
    }

    var statusText: String {
        "\(operation.rawValue) completed • \(durationText) @ \(completionTimeText) • \(result)"
    }
}
