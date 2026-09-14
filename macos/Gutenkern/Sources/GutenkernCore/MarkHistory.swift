import Foundation

public final class MarkHistory {
    private var undoStack: [KerningMarkState] = []
    private var redoStack: [KerningMarkState] = []
    private var coalescing = false
    private var coalesced = false

    public init() {}

    public var canUndo: Bool { !undoStack.isEmpty }
    public var canRedo: Bool { !redoStack.isEmpty }

    public func record(from previous: KerningMarkState, to next: KerningMarkState) {
        guard previous != next else {
            return
        }
        if coalescing {
            if !coalesced {
                undoStack.append(previous)
                redoStack.removeAll()
                coalesced = true
            }
            return
        }
        undoStack.append(previous)
        redoStack.removeAll()
    }

    public func beginCoalescing() {
        coalescing = true
        coalesced = false
    }

    public func endCoalescing() {
        coalescing = false
        coalesced = false
    }

    public func undo(current: KerningMarkState) -> KerningMarkState? {
        guard let previous = undoStack.popLast() else {
            return nil
        }
        redoStack.append(current)
        return previous
    }

    public func redo(current: KerningMarkState) -> KerningMarkState? {
        guard let next = redoStack.popLast() else {
            return nil
        }
        undoStack.append(current)
        return next
    }
}
