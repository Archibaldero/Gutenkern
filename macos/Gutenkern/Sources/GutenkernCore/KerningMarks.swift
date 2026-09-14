import Foundation

public enum PairMark: Equatable, Sendable {
    case empty
    case done
}

public enum GroupMark: Equatable, Sendable {
    case empty
    case done
    case mixedDone
}

public struct KerningMarkState: Equatable, Sendable {
    public var done: Set<String>

    public init(done: Set<String> = []) {
        self.done = done
    }

    public func pairMark(_ key: String) -> PairMark {
        done.contains(key) ? .done : .empty
    }

    public func groupMark(keys: [String]) -> GroupMark {
        guard !keys.isEmpty else {
            return .empty
        }
        let doneCount = keys.reduce(into: 0) { count, key in
            if pairMark(key) == .done {
                count += 1
            }
        }
        if doneCount == keys.count {
            return .done
        }
        if doneCount > 0 {
            return .mixedDone
        }
        return .empty
    }
}

public enum KerningMarks {
    public static func toggleGroup(keys: [String], state: KerningMarkState) -> KerningMarkState {
        var next = state
        if state.groupMark(keys: keys) == .done {
            for key in keys {
                next.done.remove(key)
            }
        } else {
            next.done.formUnion(keys)
        }
        return next
    }

    public static func togglePair(key: String, state: KerningMarkState) -> KerningMarkState {
        var next = state
        if state.pairMark(key) == .done {
            next.done.remove(key)
        } else {
            next.done.insert(key)
        }
        return next
    }

    public static func markDone(keys: [String], state: KerningMarkState) -> KerningMarkState {
        var next = state
        next.done.formUnion(keys)
        return next
    }

    public static func prune(state: KerningMarkState, known: Set<String>) -> KerningMarkState {
        KerningMarkState(done: state.done.intersection(known))
    }
}
