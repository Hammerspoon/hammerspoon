import Foundation

extension FixedWidthInteger {
    
    @inlinable
    @discardableResult
    postfix static func ++ (lhs: inout Self) -> Self {
        defer { lhs += 1 }
        return lhs
    }
    
}
