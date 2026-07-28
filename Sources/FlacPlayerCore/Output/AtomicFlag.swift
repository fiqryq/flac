import Darwin

final class AtomicFlag {
    private var value = false
    private var lock = os_unfair_lock()

    func set() {
        os_unfair_lock_lock(&lock)
        value = true
        os_unfair_lock_unlock(&lock)
    }

    var isSet: Bool {
        os_unfair_lock_lock(&lock)
        defer { os_unfair_lock_unlock(&lock) }
        return value
    }
}
