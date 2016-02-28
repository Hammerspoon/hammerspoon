// Software License Agreement (BSD License)
//
// Copyright (c) 2014-2015, Deusty, LLC
// All rights reserved.
//
// Redistribution and use of this software in source and binary forms,
// with or without modification, are permitted provided that the following conditions are met:
//
// * Redistributions of source code must retain the above copyright notice,
//   this list of conditions and the following disclaimer.
//
// * Neither the name of Deusty nor the names of its contributors may be used
//   to endorse or promote products derived from this software without specific
//   prior written permission of Deusty, LLC.

import Foundation

extension DDLogFlag {
    public static func fromLogLevel(logLevel: DDLogLevel) -> DDLogFlag {
        return DDLogFlag(rawValue: logLevel.rawValue)
    }
	
	public init(_ logLevel: DDLogLevel) {
        self = DDLogFlag(rawValue: logLevel.rawValue)
	}
    
    ///returns the log level, or the lowest equivalant.
    public func toLogLevel() -> DDLogLevel {
        if let ourValid = DDLogLevel(rawValue: self.rawValue) {
            return ourValid
        } else {
            let logFlag:DDLogFlag = self
            
            if logFlag.contains(.Verbose) {
                return .Verbose
            } else if logFlag.contains(.Debug) {
                return .Debug
            } else if logFlag.contains(.Info) {
                return .Info
            } else if logFlag.contains(.Warning) {
                return .Warning
            } else if logFlag.contains(.Error) {
                return .Error
            } else {
                return .Off
            }
        }
    }
}

public var defaultDebugLevel = DDLogLevel.Verbose

public func resetDefaultDebugLevel() {
    defaultDebugLevel = DDLogLevel.Verbose
}

public func SwiftLogMacro(isAsynchronous: Bool, level: DDLogLevel, flag flg: DDLogFlag, context: Int = 0, file: StaticString = __FILE__, function: StaticString = __FUNCTION__, line: UInt = __LINE__, tag: AnyObject? = nil, @autoclosure string: () -> String) {
    if level.rawValue & flg.rawValue != 0 {
        // Tell the DDLogMessage constructor to copy the C strings that get passed to it.
        // Using string interpolation to prevent integer overflow warning when using StaticString.stringValue
        let logMessage = DDLogMessage(message: string(), level: level, flag: flg, context: context, file: "\(file)", function: "\(function)", line: line, tag: tag, options: [.CopyFile, .CopyFunction], timestamp: nil)
        DDLog.log(isAsynchronous, message: logMessage)
    }
}

public func DDLogDebug(@autoclosure logText: () -> String, level: DDLogLevel = defaultDebugLevel, context: Int = 0, file: StaticString = __FILE__, function: StaticString = __FUNCTION__, line: UInt = __LINE__, tag: AnyObject? = nil, asynchronous async: Bool = true) {
    SwiftLogMacro(async, level: level, flag: .Debug, context: context, file: file, function: function, line: line, tag: tag, string: logText)
}

public func DDLogInfo(@autoclosure logText: () -> String, level: DDLogLevel = defaultDebugLevel, context: Int = 0, file: StaticString = __FILE__, function: StaticString = __FUNCTION__, line: UInt = __LINE__, tag: AnyObject? = nil, asynchronous async: Bool = true) {
    SwiftLogMacro(async, level: level, flag: .Info, context: context, file: file, function: function, line: line, tag: tag, string: logText)
}

public func DDLogWarn(@autoclosure logText: () -> String, level: DDLogLevel = defaultDebugLevel, context: Int = 0, file: StaticString = __FILE__, function: StaticString = __FUNCTION__, line: UInt = __LINE__, tag: AnyObject? = nil, asynchronous async: Bool = true) {
    SwiftLogMacro(async, level: level, flag: .Warning, context: context, file: file, function: function, line: line, tag: tag, string: logText)
}

public func DDLogVerbose(@autoclosure logText: () -> String, level: DDLogLevel = defaultDebugLevel, context: Int = 0, file: StaticString = __FILE__, function: StaticString = __FUNCTION__, line: UInt = __LINE__, tag: AnyObject? = nil, asynchronous async: Bool = true) {
    SwiftLogMacro(async, level: level, flag: .Verbose, context: context, file: file, function: function, line: line, tag: tag, string: logText)
}

public func DDLogError(@autoclosure logText: () -> String, level: DDLogLevel = defaultDebugLevel, context: Int = 0, file: StaticString = __FILE__, function: StaticString = __FUNCTION__, line: UInt = __LINE__, tag: AnyObject? = nil, asynchronous async: Bool = false) {
    SwiftLogMacro(async, level: level, flag: .Error, context: context, file: file, function: function, line: line, tag: tag, string: logText)
}

/// Analogous to the C preprocessor macro `THIS_FILE`.
public func CurrentFileName(fileName: StaticString = __FILE__) -> String {
    // Using string interpolation to prevent integer overflow warning when using StaticString.stringValue
    // This double-casting to NSString is necessary as changes to how Swift handles NSPathUtilities requres the string to be an NSString
    return (("\(fileName)" as NSString).lastPathComponent as NSString).stringByDeletingPathExtension
}
