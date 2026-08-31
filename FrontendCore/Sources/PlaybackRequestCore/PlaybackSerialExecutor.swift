import Foundation

/// Serializes commands sent to one shared playback session.
///
/// The executor is deliberately UI-neutral. It owns neither queue policy nor
/// decoder state; it only preserves the single-command-at-a-time contract
/// required by a VGMBoy playback session. Hosts may use `async` for
/// continuation-based work or `sync` from an already detached worker.
public final class PlaybackSerialExecutor: @unchecked Sendable {
    private let queue: DispatchQueue
    private let key = DispatchSpecificKey<Void>()

    public init(label: String, qos: DispatchQoS = .userInitiated) {
        queue = DispatchQueue(label: label, qos: qos)
        queue.setSpecific(key: key, value: ())
    }

    public func async(_ work: @escaping @Sendable () -> Void) {
        queue.async(execute: work)
    }

    public func sync<T>(_ work: () throws -> T) rethrows -> T {
        if DispatchQueue.getSpecific(key: key) != nil {
            return try work()
        }
        return try queue.sync(execute: work)
    }
}
