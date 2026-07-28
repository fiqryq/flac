import Darwin

final class AtomicFloat {
    private var value: Float
    private var lock = os_unfair_lock()

    init(_ value: Float) {
        self.value = value
    }

    func set(_ newValue: Float) {
        os_unfair_lock_lock(&lock)
        value = newValue
        os_unfair_lock_unlock(&lock)
    }

    func get() -> Float {
        os_unfair_lock_lock(&lock)
        defer { os_unfair_lock_unlock(&lock) }
        return value
    }

    func accumulateMax(_ candidate: Float) {
        os_unfair_lock_lock(&lock)
        if candidate > value { value = candidate }
        os_unfair_lock_unlock(&lock)
    }

    func getAndReset(to resetValue: Float = 0) -> Float {
        os_unfair_lock_lock(&lock)
        defer { os_unfair_lock_unlock(&lock) }
        let result = value
        value = resetValue
        return result
    }
}
