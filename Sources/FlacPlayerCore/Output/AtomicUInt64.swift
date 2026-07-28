import Darwin

final class AtomicUInt64 {
    private var value: UInt64
    private var lock = os_unfair_lock()

    init(_ value: UInt64) {
        self.value = value
    }

    func set(_ newValue: UInt64) {
        os_unfair_lock_lock(&lock)
        value = newValue
        os_unfair_lock_unlock(&lock)
    }

    func add(_ delta: UInt64) {
        os_unfair_lock_lock(&lock)
        value += delta
        os_unfair_lock_unlock(&lock)
    }

    func get() -> UInt64 {
        os_unfair_lock_lock(&lock)
        defer { os_unfair_lock_unlock(&lock) }
        return value
    }
}
