import Foundation

extension NSLock {
    
    /// Executes the closure while acquiring the lock.
    ///
    /// - Parameter closure: The closure to run.
    ///
    /// - Returns:           The value the closure generated.
    func synchronized<T>(_ closure: () throws -> T) rethrows -> T {
        defer { self.unlock() }
        self.lock()
        return try closure()
    }
}
