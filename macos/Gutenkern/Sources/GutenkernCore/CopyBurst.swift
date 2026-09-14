import Foundation

public struct CopyBurst: Equatable, Sendable {
    public static let window: TimeInterval = 1

    public private(set) var keys: [String] = []
    private var lastTime: Date?

    public init() {}

    public mutating func reset() {
        keys = []
        lastTime = nil
    }

    @discardableResult
    public mutating func add(key: String, at time: Date) -> [String] {
        if let lastTime, time.timeIntervalSince(lastTime) >= Self.window {
            keys = []
        }
        if !keys.contains(key) {
            keys.append(key)
        }
        lastTime = time
        return keys
    }
}
