import Foundation

public struct PairHitFrame: Equatable, Sendable {
    public var key: String
    public var x: Double
    public var y: Double
    public var width: Double
    public var height: Double

    public init(key: String, x: Double, y: Double, width: Double, height: Double) {
        self.key = key
        self.x = x
        self.y = y
        self.width = width
        self.height = height
    }
}

public enum PairHitTesting {
    public static func nearestKey(x: Double, y: Double, frames: [PairHitFrame]) -> String? {
        var bestKey: String?
        var bestDistance = Double.infinity
        for frame in frames {
            let distance = distanceToRect(x: x, y: y, frame: frame)
            if distance < bestDistance {
                bestDistance = distance
                bestKey = frame.key
            }
        }
        return bestKey
    }

    private static func distanceToRect(x: Double, y: Double, frame: PairHitFrame) -> Double {
        let minX = frame.x
        let minY = frame.y
        let maxX = frame.x + frame.width
        let maxY = frame.y + frame.height
        let dx: Double
        if x < minX {
            dx = minX - x
        } else if x > maxX {
            dx = x - maxX
        } else {
            dx = 0
        }
        let dy: Double
        if y < minY {
            dy = minY - y
        } else if y > maxY {
            dy = y - maxY
        } else {
            dy = 0
        }
        return (dx * dx + dy * dy).squareRoot()
    }
}
