//
//  Base64.swift
//  Hammertime
//
//  Created by Chris Jones on 20/12/2023.
//  Copyright © 2023 Hammerspoon. All rights reserved.
//

import Foundation

extension String {
    func splitByLength(every length:Int) -> [Substring] {
        guard length > 0 && length < count else { return [suffix(from:startIndex)] }
        return (0 ... (count - 1) / length).map { dropFirst($0 * length).prefix(length) }
    }
}

@objc public class Base64 : NSObject {
    /// Encode bytes to a Base64 string
    /// - Parameter data: Some input bytes as a Data
    /// - Returns: String
    @objc public func encode(data: Data) -> String {
        return data.base64EncodedString()
    }

    /// Encode bytes to a Base64 string, split into lines of specified width
    /// - Parameters:
    ///   - data: Some input bytes as a Data
    ///   - width: How wide the lines should be
    /// - Returns: String
    @objc public func encode(data: Data, width: Int) -> String {
        let string = self.encode(data: data)
        let lines = string.splitByLength(every: width)
        return lines.joined(separator: "\n")
    }

    /// Decode a Base64 string to bytes
    /// - Parameter input: A Base64 encoded string
    /// - Returns: Output bytes as a Data
    @objc public func decode(input: String) -> Data {
        if let encoded = input.data(using: .utf8) {
            if let data = Data(base64Encoded: encoded, options: .ignoreUnknownCharacters) {
                return data
            }
        }
        NSException.raise(.invalidArgumentException, format: "Unable to decode input", arguments: getVaList([""]))
        return Data() // Never hit
    }
}
