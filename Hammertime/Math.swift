//
//  Math.swift
//  Hammertime
//
//  Created by Chris Jones on 20/12/2023.
//  Copyright © 2023 Hammerspoon. All rights reserved.
//

import Foundation

@objc public class Math : NSObject {
    func validateDoubleRange(start: Double, end: Double) -> Bool {
        return start <= end
    }

    func validateFloatRange(start: Float, end: Float) -> Bool {
        return start <= end
    }

    func validateIntRange(start: Int, end: Int) -> Bool {
        return start <= end
    }

    /// Returns a random Double between 0 and 1 (inclusive)
    /// - Returns: Double
    @objc public func randomDouble() -> Double {
        return self.randomDoubleInRange(start: 0, end: 1)
    }

    /// Returns a random Doubld within the supplied range (inclusive)
    /// - Parameters:
    ///   - start: Lower bound of the range
    ///   - end: Upper bound of the range
    /// - Returns: Double
    /// - Throws: `NSException` if start > end
    @objc public func randomDoubleInRange(start: Double, end: Double) -> Double {
        if (!self.validateDoubleRange(start: start, end: end)) {
            NSException.raise(.rangeException, format: "start must be <= end", arguments: getVaList([""]))
        }
        return Double.random(in: start...end)
    }

    /// Returns a random Float between 0 and 1 (inclusive)
    /// - Returns: Float
    @objc public func randomFloat() -> Float {
        return self.randomFloatInRange(start: 0, end: 1)
    }
    
    /// Returns a random Float within the supplied range (inclusive)
    /// - Parameters:
    ///   - start: Lower bound of the range
    ///   - end: Upper bound of the range
    /// - Returns: Float
    /// - Throws: `NSException` if start > end
    @objc public func randomFloatInRange(start: Float, end: Float) -> Float {
        if (!self.validateFloatRange(start: start, end: end)) {
            NSException.raise(.rangeException, format: "start must be <= end", arguments: getVaList([""]))
        }
        return Float.random(in: start...end)
    }
    
    /// Returns a random Int within the supplied range (inclusive)
    /// - Parameters:
    ///   - start: Lower bound of the range
    ///   - end: Upper bound of the range
    /// - Returns: Int
    /// - Throws: `NSException` if start > end
    @objc public func randomIntInRange(start: Int, end: Int) -> Int {
        if (!self.validateIntRange(start: start, end: end)) {
            NSException.raise(.rangeException, format: "start must be <= end", arguments: getVaList([""]))
        }
        return Int.random(in: start...end)
    }
}
