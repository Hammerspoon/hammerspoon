<p align="center" >
  <img src="LumberjackLogo.png" title="Lumberjack logo" float=left>
</p>

CocoaLumberjack
===============
[![Build Status](https://travis-ci.org/CocoaLumberjack/CocoaLumberjack.svg?branch=master)](https://travis-ci.org/CocoaLumberjack/CocoaLumberjack)
[![Pod Version](http://img.shields.io/cocoapods/v/CocoaLumberjack.svg?style=flat)](http://cocoadocs.org/docsets/CocoaLumberjack/)
[![Carthage compatible](https://img.shields.io/badge/Carthage-compatible-4BC51D.svg?style=flat)](https://github.com/Carthage/Carthage)
[![Pod Platform](http://img.shields.io/cocoapods/p/CocoaLumberjack.svg?style=flat)](http://cocoadocs.org/docsets/CocoaLumberjack/)
[![Pod License](http://img.shields.io/cocoapods/l/CocoaLumberjack.svg?style=flat)](http://opensource.org/licenses/BSD-3-Clause)
[![Reference Status](https://www.versioneye.com/objective-c/cocoalumberjack/reference_badge.svg?style=flat)](https://www.versioneye.com/objective-c/cocoalumberjack/references)

**CocoaLumberjack** is a fast & simple, yet powerful & flexible logging framework for Mac and iOS.

### How to get started
- install via [CocoaPods](http://cocoapods.org)

##### Swift version via CocoaPods
```ruby
platform :ios, '8.0'
pod 'CocoaLumberjack/Swift'
use_frameworks!
```
Note: `Swift` is a subspec which will include all the Obj-C code plus the Swift one, so this is sufficient. 
For more details about how to use Swift with Lumberjack, see [this converation](https://github.com/CocoaLumberjack/CocoaLumberjack/issues/405).

##### Swift Usage

If you installed using CocoaPods or manually:
```swift
import CocoaLumberjack
```

```swift
DDLog.addLogger(DDTTYLogger.sharedInstance()) // TTY = Xcode console
DDLog.addLogger(DDASLLogger.sharedInstance()) // ASL = Apple System Logs

let fileLogger: DDFileLogger = DDFileLogger() // File Logger
fileLogger.rollingFrequency = 60*60*24  // 24 hours
fileLogger.logFileManager.maximumNumberOfLogFiles = 7
DDLog.addLogger(fileLogger)

...

DDLogVerbose("Verbose");
DDLogDebug("Debug");
DDLogInfo("Info");
DDLogWarn("Warn");
DDLogError("Error");
```

##### Obj-C version via CocoaPods

```ruby
platform :ios, '7.0'
pod 'CocoaLumberjack'
```

##### Objc-C usage
If you're using Lumberjack as a framework, you can `@import CocoaLumberjack`.

Otherwise, `#import <CocoaLumberjack/CocoaLumberjack.h>`

```objc
[DDLog addLogger:[DDTTYLogger sharedInstance]]; // TTY = Xcode console
[DDLog addLogger:[DDASLLogger sharedInstance]]; // ASL = Apple System Logs

DDFileLogger *fileLogger = [[DDFileLogger alloc] init]; // File Logger
fileLogger.rollingFrequency = 60 * 60 * 24; // 24 hour rolling
fileLogger.logFileManager.maximumNumberOfLogFiles = 7;
[DDLog addLogger:fileLogger];

...

DDLogVerbose(@"Verbose");
DDLogDebug(@"Debug");
DDLogInfo(@"Info");
DDLogWarn(@"Warn");
DDLogError(@"Error");
```

##### Installation with Carthage (iOS 8+)

[Carthage](https://github.com/Carthage/Carthage) is a lightweight dependency manager for Swift and Objective-C. It leverages CocoaTouch modules and is less invasive than CocoaPods.

To install with Carthage, follow the instruction on [Carthage](https://github.com/Carthage/Carthage)

Cartfile
```
github "CocoaLumberjack/CocoaLumberjack"
```

- or [install manually](Documentation/GettingStarted.md#manual-installation)
- read the [Getting started](Documentation/GettingStarted.md) guide, check out the [FAQ](Documentation/FAQ.md) section or the other [docs](Documentation/)
- if you find issues or want to suggest improvements, create an issue or a pull request
- for all kinds of questions involving CocoaLumberjack, use the [Google group](http://groups.google.com/group/cocoalumberjack) or StackOverflow (use [#lumberjack](http://stackoverflow.com/questions/tagged/lumberjack)).

### CocoaLumberjack 2

#### Migrating to 2.x

* Replace `DDLog.h` imports by `#import <CocoaLumberjack/CocoaLumberjack.h>`.

Advanced users, third party libraries:

* Replace all `DDLogC` macros for regular `DDLog` macros.
* Replace log level (`LOG_LEVEL_*`) macros with `DDLogLevel` enum values
* Replace log flag (`LOG_FLAG_*`) macros with `DDLogFlag` enum values
* Replace `DDLogMessage` ivars and method calls to the new ivars and methods
  * `logMsg` with `_message`
  * `logLevel` with `_level`
  * `logFlag` with `_flag`
  * `logContext` with `_context`
  * `lineNumber` with `_line` (type changed from `int` to `NSUInteger`)
  * `file` with `_file` (`filename` contains just the file name, without the extension and the full path)
  * `timestamp` with `_timestamp`
  * `methodName` with `function`
* Replace `DDAbstractLogger` `formatter` to `logFormatter`
* `YSSingleFileLogger` ivars are no longer accesible, use the methods instead
* Replace `[DDLog addLogger:withLogLevel:]` with `[DDLog addLogger:withLevel:]`

#### Forcing 1.x

If an included library requires it, you can force CocoaLumberjack 1.x by setting the version before the conflicting library:

```ruby
pod 'CocoaLumberjack', '~> 1.9'
pod 'ConflictingLibrary'
```

### Features

#### Lumberjack is Fast & Simple, yet Powerful & Flexible.

It is similar in concept to other popular logging frameworks such as log4j, yet is designed specifically for Objective-C, and takes advantage of features such as multi-threading, grand central dispatch (if available), lockless atomic operations, and the dynamic nature of the Objective-C runtime.

#### Lumberjack is Fast

In most cases it is an order of magnitude faster than NSLog.

#### Lumberjack is Simple

It takes as little as a single line of code to configure lumberjack when your application launches. Then simply replace your NSLog statements with DDLog statements and that's about it. (And the DDLog macros have the exact same format and syntax as NSLog, so it's super easy.)

#### Lumberjack is Powerful:

One log statement can be sent to multiple loggers, meaning you can log to a file and the console simultaneously. Want more? Create your own loggers (it's easy) and send your log statements over the network. Or to a database or distributed file system. The sky is the limit.

#### Lumberjack is Flexible:

Configure your logging however you want. Change log levels per file (perfect for debugging). Change log levels per logger (verbose console, but concise log file). Change log levels per xcode configuration (verbose debug, but concise release). Have your log statements compiled out of the release build. Customize the number of log levels for your application. Add your own fine-grained logging. Dynamically change log levels during runtime. Choose how & when you want your log files to be rolled. Upload your log files to a central server. Compress archived log files to save disk space...

### This framework is for you if:

-   You're looking for a way to track down that impossible-to-reproduce bug that keeps popping up in the field.
-   You're frustrated with the super short console log on the iPhone.
-   You're looking to take your application to the next level in terms of support and stability.
-   You're looking for an enterprise level logging solution for your application (Mac or iPhone).

### Documentation

- **[Get started using Lumberjack](Documentation/GettingStarted.md)**<br/>
- [Different log levels for Debug and Release builds](Documentation/XcodeTricks.md)<br/>
- [Different log levels for each logger](Documentation/PerLoggerLogLevels.md)<br/>
- [Use colors in the Xcode debugging console](Documentation/XcodeColors.md)<br/>
- [Write your own custom formatters](Documentation/CustomFormatters.md)<br/>
- [FAQ](Documentation/FAQ.md)<br/>
- [Analysis of performance with benchmarks](Documentation/Performance.md)<br/>
- [Common issues you may encounter and their solutions](Documentation/ProblemSolution.md)<br/>
- [AppCode support](Documentation/AppCode-support.md)
- **[Full Lumberjack documentation](Documentation/)**<br/>

### Requirements 
The current version of Lumberjack requires:
- Xcode 7.1 or later
- iOS 5 or later
- OS X 10.7 or later
- WatchOS 2 or later
- TVOS 9 or later

#### Backwards compability
- for Xcode 7.0 or earlier, use the 2.1.0 version
- for Xcode 6 or earlier, use the 2.0.x version
- for OS X < 10.7 support, use the 1.6.0 version

### Author
- [Robbie Hanson](https://github.com/robbiehanson)
- Love the project? Wanna buy me a coffee? (or a beer :D) [![donation](http://www.paypal.com/en_US/i/btn/btn_donate_SM.gif)](https://www.paypal.com/cgi-bin/webscr?cmd=_s-xclick&hosted_button_id=UZRA26JPJB3DA)

### Collaborators
- [Ernesto Rivera](https://github.com/rivera-ernesto)
- [Dmitry Vorobyov](https://github.com/dvor)
- [Bogdan Poplauschi](https://github.com/bpoplauschi)

### License
- CocoaLumberjack is available under the BSD license. See the [LICENSE file](https://github.com/CocoaLumberjack/CocoaLumberjack/blob/master/LICENSE.txt).
