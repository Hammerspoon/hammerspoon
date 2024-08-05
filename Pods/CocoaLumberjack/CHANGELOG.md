# [3.8.5 - Xcode 15.3 on Mar 8th, 2024](https://github.com/CocoaLumberjack/CocoaLumberjack/releases/tags/3.8.5)

### Public

- Fix build failure due to privacy manifest when using static linking with CocoaPods (#1408)
- Allow custom mapping of `DDLogFlag` to `os_log_type_t`, fix default mapping for `DDLogFlagWarn` (#1410)


# [3.8.4 - Xcode 15.2 on Feb 8th, 2024](https://github.com/CocoaLumberjack/CocoaLumberjack/releases/tags/3.8.4)

### Public

- Extend privacy manifest to fulfill validation criteria (#1403)
- Fix crash when fetching registered classes (#1406)


# [3.8.3 - Xcode 15.2 on Feb 5th, 2024](https://github.com/CocoaLumberjack/CocoaLumberjack/releases/tags/3.8.3)

### Public

- Add privacy manifest (#1403)
- Update doc from DDLogLevelWarn to DDLogLevelWarning to match library (#1383)
- Only cleanup files on configuration change if the manager is used by a file logger (#1398)
- Fix #1386 again by adding a missing return and adjusting the preprocessor conditionals
- Fix some C++ warnings

### Internal

- Update copyright for 2024 (#1400)
- Improve asserts (#1385)


# [3.8.2 - Xcode 15.0 on Oct 31st, 2023](https://github.com/CocoaLumberjack/CocoaLumberjack/releases/tag/3.8.2)

### Public

- App background-mode not correctly detected in app extensions (#1359)
- Fix DDFileLogger rollingFrequency and maximumFileSize not being honored (#1361)
- Fix potential crashes when using the new `DDLogMessageFormat` with messages that contain '%'
- Fix simulator issues when using dynamic registered logging on iOS 17 (#1386)
- Allow `DDFileLogger` to write in different file formats (#1380)

### Internal

- Generate Podspec (#1360)


# [3.8.1 - Xcode 14.3 on Aug 21st, 2023](https://github.com/CocoaLumberjack/CocoaLumberjack/releases/tag/3.8.1)

### Public

- Silence double conversion warnings for 32-bit watchOS (#1320)
- Enable ALLOW_TARGET_PLATFORM_SPECIALIZATION (#1321)
- Update to swift-log 1.5.2, implement metadata providers (#1329)
- Preserve `messageFormat` in `DDLogMessage` (#1347)

### Internal

- Update copyright for 2023


## [3.8.0 - Xcode 14.1 on Nov 2nd, 2022](https://github.com/CocoaLumberjack/CocoaLumberjack/releases/tag/3.8.0)

### Public

- Add support for Xcode 14 / Swift 5.7 - drop support for Swift < 5.5, iOS/tvOS < 11, macOS < 10.13, watchOS < 4 (#1316)
- Update README about swift-log usage (#1275)
- Use dispatch_walltime for scheduling log file rolling timer (#1309)

### Internal

- Add consistent newline to file endings (#1272)
- Fix error checking in DDFileLogger (#1274)
- Avoid using NSString format (#1280)
- Prevent logging to symlink files (#1314)


## [3.7.4 - Xcode 13.2 on Dec 16, 2021](https://github.com/CocoaLumberjack/CocoaLumberjack/releases/tag/3.7.4)

### Public

- Fix swift-tools-version in Package@swift-5.3.swift


## [3.7.3 - Xcode 13.2 on Dec 16, 2021](https://github.com/CocoaLumberjack/CocoaLumberjack/releases/tag/3.7.3)

### Public

- Fix "DDFileLogger: Failed to get offset" when setting maximumFileSize (#1234)
- Follow-up to add annotations to DDOSLogger (#1248)
- Fixed nullability conflict in DDDispatchQueueLogFormatter.h (#1252)
- Add Swift 5.5 support, fix archive build on Xcode 13 (#1253)
- Fix file access issue in Catalyst apps (#1257)
- Fix excluded archs in debug build when not mac catalyst (#1260)
- Bump Xcode last upgraded version to 13.2 (#1265)
- Don't log warnings for CLI apps in DDTTYLogger (#1269)


## [3.7.2 - Xcode 12.4 on Apr 9th, 2021](https://github.com/CocoaLumberjack/CocoaLumberjack/releases/tag/3.7.2)

### Public

- Re-introduce (and deprecate) `_tag` field to fix breakage in 3.7.1 (#1224)


## [3.7.1 - Xcode 12.4 on Apr 7th, 2021](https://github.com/CocoaLumberjack/CocoaLumberjack/releases/tag/3.7.1)

### Public

- Deprecate `tag` property of `DDLogMessage`, use `representedObject` instead. (#1177, #532)
- Add per-message synchronous logging control for messages logged via SwiftLog using `DDLogHandler` (#1209)
- Add TargetConditionals import for Xcode 12.5 (#1210)
- Prevent logging an error when archiving an already deleted file (#1212)
- Use inclusive words - denylist / allowlist (#1218)
- Add `DDAssertionFailure` macro for Objective-C (#1220)

### Internal

- Use setter to replace kvo for `NSFileLogger` (#1180)
- Use new API for `NSFileHandle` on supported platforms (#1181)
- Remove unnecessary checks in `DDFileLogger` (#1182)
- Add an assertion to avoid potential deadlock issues for `flushLog` (#1183)


## [3.7.0 - Xcode 12 on Oct 2nd, 2020](https://github.com/CocoaLumberjack/CocoaLumberjack/releases/tag/3.7.0)

### Public

- **Breaking change**: Dropped support for iOS 8 (#1153)
- Update SPM tools-version to 5.3 to enable Swift 5.3 support (#1148)
- Add backend for swift-log (#1164)
- Specify CocoaPods version to ensure `swift_version` attribute works (#1167)
- Simplify `DDLogFileManager` callbacks for archived log files (#1166)


## [3.6.2 - Xcode 11.6 on July 31st, 2020](https://github.com/CocoaLumberjack/CocoaLumberjack/releases/tag/3.6.2)

### Public
- Fix warnings when building with SPM bundled with Swift 5.2 / Xcode 11.4 (#1132)
- Added Swift name for DDQualityOfServiceName constants.
- Don't localize timestamps in `DDefaultFileLogFormatter` (#1151)
- Allow logging arbitrary objects via Swift log functions (#1146)

### Repository
- Switch from Travis to GitHub Actions (#1135, #1140, #1150, #1152)


## [3.6.1 - Xcode 11.3.1 on Jan 25th, 2020](https://github.com/CocoaLumberjack/CocoaLumberjack/releases/tag/3.6.1)

### Public
- Improve error handling during log file creation in DDFileLogger & DDLogFileManager (#1103 / #1111)
- Improve nullability annotations in public headers (#1111 / #1112 / #1119)
- Added support for thread QOS in DDLogMessage class (#1124)

### Internal
- Fix rolling timer being rescheduled rapidly due to leeway (#1106 / #1107)
- Fix -didArchiveLogFile: returning the file name instead of the file path (#1078)
- Fix setxattr() function usage (#1118)
- Fix NSDateFormatter thread safety (#1121)
- Fix -lt_dataForMessage: duplicated code (#1122)


## [3.6.0 - Xcode 11 on October 2nd, 2019](https://github.com/CocoaLumberjack/CocoaLumberjack/releases/tag/3.6.0)

### Public
- Swift Package Manager Support (#1083)
- New `willLogMessage:` and `didLogMessage:` methods on `DDFileLogger` which provide access to the current log file info.

### Internal
- Fix issue with log archiving in the simulator (#1098)
- Limit assertion to non-simulator build (#1100)


## [3.5.3 - Xcode 10.2 on Apr 24th, 2019](https://github.com/CocoaLumberjack/CocoaLumberjack/releases/tag/3.5.3)

### Public
- Additional compatibility with Swift 5 (backwards compatible with Swift 4) (#1043)
- Fix warning building with Xcode 10.2 (#1059)
- Set Xcode 10.2 and Swift 5.0 as a default (#1064)
- Fix format string crash (#1066)

### Internal
- Fix warning about syntax (#1054) (#1065)
- Remove banned APIs (#1056) (#1057)
- Add CLANG_WARN_QUOTED_INCLUDE_IN_FRAMEWORK_HEADER & fix warnings (#1059)
- Use LLONG_MAX instead of LONG_LONG_MAX (#1062)


## [3.5.2 - Xcode 10.1 on Mar 15th, 2019](https://github.com/CocoaLumberjack/CocoaLumberjack/releases/tag/3.5.2)

### Public
- Fix reusing of log files after rolling (#1042)
- Fix creation of too many log files (#1049)
- Preliminary compatibility with Swift 5 (backwards compatible with Swift 4) (#1044)
- core: loggers os logger variations have been added (#1039)

### Internal
- Sync internal queues to prevent cleaning up log files too soon in tests (#1053)
- DDLog checks for NULL values and for global queue dispatching has been added (#1045)


## [3.5.1 - Xcode 10 on Feb 4th, 2019](https://github.com/CocoaLumberjack/CocoaLumberjack/releases/tag/3.5.1)

### Public
- Fix high CPU usage because of empty fileAttributes and / or too high rollingFrequceny (#1028)


## [3.5.0 - Xcode 10 on Jan 25th, 2019](https://github.com/CocoaLumberjack/CocoaLumberjack/releases/tag/3.5.0)

### Public
- Added `logFileHeader` property to `DDLogFileManagerDefault`. Override to set header for each created file. #998
- `DDFileLogger` now accepts a `dispatch_queue_t` which it uses to run callbacks. If not provided, the default global queue is used. #1003
- Added opt-in buffering to `DDFileLogger`. Call `wrapWithBuffer` to create a file logger which buffers. #1001, #1012
- Add `DDAssert` and `DDAssertionFailure` functions for Swift #934
- Add `DD_LOG_LEVEL` define (which can be set in `GCC_PREPROCESSOR_DEFINITIONS`) for Swift to set default log level (enables stripping for strings that are not logged). #952
- Add `asyncLoggingEnabled` global variable to control asynchronous logging. #1019

### Internal
- Prevent memory access errors caused by a failed fetch #944
- Fix common warnings emitted by `-Wall`, `-Wconversion`, `-Wextra`, etc #943, #931
- Fixes issue that could cause log messages to become interleaved when there are multiple `DDFileLogger`s #985
- `DispatchQueueFormatter` knows about `com.apple.root.default-qos.overcommit` now #932
- Fix thread safety issues in `DDFileLogger`. Makes it a little harder to deadlock in some cases. #986, #1003, #946
- Fix availability checks and memory leak #996

### Repository
- Reduce podspec to two subspecs and remove customized modulemap #976
- Add danger support for PR checks #962 - fixes #956
- Merged framework targets + using `xcconfig` + deployment target `iOS 8` and `Mac OS 10.10` #959 e97da34
- Documentation update #955 e7414ae 0239196 #933
- Full links to Docs and other resources so they are resolved on external pages (i.e. https://cocoapods.org/pods/CocoaLumberjack) e9d6971
- Replace `OSAtomic` with `stdatomic` in `DDDispatchQueueLogFormatter` #957 #958
- Add Stale Bot + configuration #953
- Update to Xcode 10 and Swift 4.2 compiler #950
- Xcode 10 scheme changes #949
- Update incomplete BSD 3-Clause License #942
- Updated to CocoaPods 1.5.3 2d0590f
- Use Xcode 9.4 image for tests #939
- Xcode (schemes) version bumps #938
- Update demo and documentation about CustomLogLevels #1023


## [3.4.2 - Xcode 9.3 on Apr 17th, 2018](https://github.com/CocoaLumberjack/CocoaLumberjack/releases/tag/3.4.2)
- Update README.md #912
- Fixed typo in pull request template #913
- Fix `-Wimplicit-retain-self` warnings #915
- Update memory management in dynamic logging #916
- Xcode 9.3 support #921 #923 #926 #927
- Add extern "C" for Objective-C++ #922
- Add `flush` method to the `DDFileLogger` #928


## [3.4.1 - Xcode 9.1 on Jan 26th, 2018](https://github.com/CocoaLumberjack/CocoaLumberjack/releases/tag/3.4.1)
- Fix `DDLogFileManagerDefault` `-isLogFile` #909
- Fix locking the main thread #911


## [3.4.0 - Xcode 9.1 on Jan 3rd, 2018](https://github.com/CocoaLumberjack/CocoaLumberjack/releases/tag/3.4.0)
- Fix Travis CI #895
- Fix typos #896
- Fix schemes and link errors #897 #899 #903 #907


## [3.3.0 - Xcode 9 on Oct 3rd, 2017](https://github.com/CocoaLumberjack/CocoaLumberjack/releases/tag/3.3.0)
- Xcode 9 support and Swift 4 support #890 #893
- Replace `OSSpinLock` with `pthread_mutex` #889


## [3.2.1 - Xcode 9 beta on Aug 21st, 2017](https://github.com/CocoaLumberjack/CocoaLumberjack/releases/tag/3.2.1)
- Xcode 9 beta support #874 #873 #884 #883 #882
- Fixed some issues around deleting log files #868 #879
- update 'Use Log Level per Logger' doc #888
- Remove empty asset catalogs so that they don't show up in Open Quickly #877
- Fixed typo in pull request template #880


## [3.2.0 - Swift 3.0.0, Xcode 8.3 on May 3rd, 2017](https://github.com/CocoaLumberjack/CocoaLumberjack/releases/tag/3.2.0)
- Xcode 8.3 support #860 #853
- added a very basic `os_log` (unified logging) logger #850 #856
- Use `NSFileProtectionType` instead of `NSString` #866
- Optimized timestamp calculation in `DDTTYLogger` #851
- Updated docs #864
- Fix Travis #863
- Fixed nullability of `DDLogMessage.function` #849 `DDExtractFileNameWithoutExtension` #845
- Ignore `Carthage/Build` directory #862
- Updated schemes #859 #857


## [3.1.0 - Swift 3.0.1, Xcode 8.1 on Feb 22nd, 2017](https://github.com/CocoaLumberjack/CocoaLumberjack/releases/tag/3.1.0)
- Swift 3.0.1 and Xcode 8.1 support via #816
- Fix Carthage build and updated the podspec structure #819 #818 #784 #790 #782 #778 #815
- Fix CLIColor.h not included in umbrella header #781 #796 #813 #783
- Fix crash in `[DDLog log:level:flag:context:file:function:line:tag:format:]` #831 #830
- Code improvements:
  - using class properties #779
  - nullability #803 #809 #776
  - fix static analyzer issues #822 #828
  - optimized `USE_DISPATCH_CURRENT_QUEUE_LABEL` and `USE_DISPATCH_GET_CURRENT_QUEUE` macros #829
  - fixed dispatch_source_set_timer() usage #834
  - fixed misuse of non null parameter in `DDFileLogger fileAttributes` #835
  - store calendar in logger queue specifics for multi-thread safety #837
  - reenable default `init` method for `DDLogMessage` class #838
- Added option to not copy messages #832
- Added new hooks when adding loggers and formatters #836
- Ability to create new log files every day #736
- Skip messages in ASL logger which are filtered out by the formatter #786 #742
- Fixed #823 by adding a `hash` implementation for `DDFileLogger` - same as `isEqual`, it only considers the `filePath` 7ceed08
- Fix Travis CI build #807
- Updated docs #798 #808 #811 #810 #820


## [3.0.0 - Swift 3.0, Xcode 8 on Sep 21st, 2016](https://github.com/CocoaLumberjack/CocoaLumberjack/releases/tag/3.0.0)
- Swift 3.0 and Xcode 8 support via #769, fixes #771 and #772. Many thanks to @ffried @max-potapov @chrisdoc @BarakRL @devxoul and the others who contributed


## [2.4.0 - Swift 2.3 on Sep 19th, 2016](https://github.com/CocoaLumberjack/CocoaLumberjack/releases/tag/2.4.0)
- Swift 2.3 explicit so that the project compiles on Xcode 8 - #747 #773 fix #762 #763 #766
- CocoaPods 1.0.0 fully adopted - 0f5a793 637dfc1 70439fe #729
- Fix CLIColor.h not found for non-AppKit binaries w/o clang modules #745
- Retrieve the `DDLogLevel` of each logger associated to `DDLog` #753
- updated doc: #727 a9f54c9 #741, diagrams in 8bd128d
- Added CONTRIBUTING, ISSUE and PULL_REQUEST TEMPLATE and added a small Communication section to the Readme
- Fixed an issue with one demo #760


## [2.3.0 - Swift 2.2, Xcode7.3 on May 2nd, 2016](https://github.com/CocoaLumberjack/CocoaLumberjack/releases/tag/2.3.0)
- Updated to Swift 2.2 - #704
- replaced deprecated `__FUNCTION__`, `__FILE__`, `__LINE__` with newly added to Swift 2.2: `#function`, `#file`, `#line`
- Xcode 7.3 update - #692 #662
- simplify usage and integration of the static library target - #657
- DDLog usable via instances - #679
- Swift cleanup - #649
- Enable Application extension API only for tvOS - #701
- Added `appletvos` and `appletvsimulator` to `SUPPORTED_PLATFORMS` and set  `TVOS_DEPLOYMENT_TARGET` - #707
- fixed `OSSpinLock` init issue - #653
- Added check to prevent duplicate loggers - #682
- fixed typo in import - #693
- updated the docs - #646 #650 #656 #655 #661 #664 #667 #684 #724


## [2.2.0 - TVOS, Xcode7.1 on Oct 28th, 2015](https://github.com/CocoaLumberjack/CocoaLumberjack/releases/tag/2.2.0)
- added `tvOS` support (thanks [@sinoru](https://github.com/sinoru)) - [#634](https://github.com/CocoaLumberjack/CocoaLumberjack/pull/634) [#640](https://github.com/CocoaLumberjack/CocoaLumberjack/pull/640) [#630](https://github.com/CocoaLumberjack/CocoaLumberjack/pull/630) [#628](https://github.com/CocoaLumberjack/CocoaLumberjack/pull/628) [#618](https://github.com/CocoaLumberjack/CocoaLumberjack/pull/618) [#611](https://github.com/CocoaLumberjack/CocoaLumberjack/pull/611)
- Remove `(escaping)` from the Swift `@autoclosure` parameters - [#642](https://github.com/CocoaLumberjack/CocoaLumberjack/pull/642)


## [2.1.0 - Swift 2.0, WatchOS, Xcode7 on Oct 23rd, 2015](https://github.com/CocoaLumberjack/CocoaLumberjack/releases/tag/2.1.0)
- Fixed the version for the Carthage builds - see [#633](https://github.com/CocoaLumberjack/CocoaLumberjack/pull/633)
- Improved documentation


## [2.1.0 RC - Swift 2.0, WatchOS, Xcode7 on Oct 22nd, 2015](https://github.com/CocoaLumberjack/CocoaLumberjack/releases/tag/2.1.0-rc)
- Refactored the `NSDateFormatter` related code to fix a bunch of issues: [#621](https://github.com/CocoaLumberjack/CocoaLumberjack/pull/621)
- Fix Issue [#488](https://github.com/CocoaLumberjack/CocoaLumberjack/issues/488): Support `DDLog` without `AppKit Dependency` (`#define DD_CLI`): [#627](https://github.com/CocoaLumberjack/CocoaLumberjack/pull/627)
- Re-add `NS_DESIGNATED_INITIALIZER` [#619](https://github.com/CocoaLumberjack/CocoaLumberjack/pull/619)


## [2.1.0 Beta - Swift 2.0, WatchOS, Xcode7 on Oct 12th, 2015](https://github.com/CocoaLumberjack/CocoaLumberjack/releases/tag/2.1.0-beta)
- Updated the library to use Swift 2.0 and Xcode 7 [#617](https://github.com/CocoaLumberjack/CocoaLumberjack/pull/617) [#545](https://github.com/CocoaLumberjack/CocoaLumberjack/pull/545) [#534](https://github.com/CocoaLumberjack/CocoaLumberjack/pull/534)
- WatchOS support (2.0) [#583](https://github.com/CocoaLumberjack/CocoaLumberjack/pull/583) [#581](https://github.com/CocoaLumberjack/CocoaLumberjack/pull/581) [#579](https://github.com/CocoaLumberjack/CocoaLumberjack/pull/579)


## [2.0.3 Patch for 2.0.0 on Oct 13th, 2015](https://github.com/CocoaLumberjack/CocoaLumberjack/releases/tag/2.0.3)

- Compatibility with Xcode 6 that was broken by the 2.0.2 patch - [f042fd3](https://github.com/CocoaLumberjack/CocoaLumberjack/commit/f042fd3)


## [2.0.2 Patch for 2.0.0 on Oct 12th, 2015](https://github.com/CocoaLumberjack/CocoaLumberjack/releases/tag/2.0.2)

- Swift 1.2 fixes [#546](https://github.com/CocoaLumberjack/CocoaLumberjack/pull/546) [#578](https://github.com/CocoaLumberjack/CocoaLumberjack/pull/578) plus and update to Swift 2.0 [5627dff](https://github.com/CocoaLumberjack/CocoaLumberjack/commit/5627dff) imported from our swift_2.0 branch
- Make build work on `tvOS` [#597](https://github.com/CocoaLumberjack/CocoaLumberjack/pull/597)
- Make `CocoaLumberjackSwift-iOS` target depends on `CocoaLumberjack-iOS` [#575](https://github.com/CocoaLumberjack/CocoaLumberjack/pull/575)
- `APPLICATION_EXTENSION_API_ONLY` to `YES` for Extensions [#576](https://github.com/CocoaLumberjack/CocoaLumberjack/pull/576)
- Remove unnecessary `NS_DESIGNATED_INITIALIZER`s [#593](https://github.com/CocoaLumberjack/CocoaLumberjack/pull/593) fixes [#592](https://github.com/CocoaLumberjack/CocoaLumberjack/issues/592)
- Add ignore warning mark for `DDMakeColor` [#553](https://github.com/CocoaLumberjack/CocoaLumberjack/pull/553)
- Kill unused function warnings from `DDTTYLogger.h` [#613](https://github.com/CocoaLumberjack/CocoaLumberjack/pull/613)
- Flag unused parameters as being unused to silence strict warnings [#566](https://github.com/CocoaLumberjack/CocoaLumberjack/pull/566)
- Extend ignore unused warning pragma to cover all platforms [#559](https://github.com/CocoaLumberjack/CocoaLumberjack/pull/559)
- Removed images.xcassets from Mobile project [#580](https://github.com/CocoaLumberjack/CocoaLumberjack/pull/580)
- Silence the Xcode 7 upgrade check - [#595](https://github.com/CocoaLumberjack/CocoaLumberjack/pull/595)
- Fix import for when CL framework files are manually imported into project [#560](https://github.com/CocoaLumberjack/CocoaLumberjack/pull/560)
- Don't override defines in case they're already set at project level [#551](https://github.com/CocoaLumberjack/CocoaLumberjack/pull/551)
- log full filepath when failing to set attribute [#550](https://github.com/CocoaLumberjack/CocoaLumberjack/pull/550)
- Fix issue in standalone build with `DDLegacyMacros.h` [#552](https://github.com/CocoaLumberjack/CocoaLumberjack/pull/552)
- Update `CustomFormatters.md` with proper thread-safe blurb [#555](https://github.com/CocoaLumberjack/CocoaLumberjack/pull/555)
- typo in parameter's variable name fixed [#568](https://github.com/CocoaLumberjack/CocoaLumberjack/pull/568)
- Typo: minor fix [#571](https://github.com/CocoaLumberjack/CocoaLumberjack/pull/571)
- Surely we should be adding 1, not 0 for `OSAtomicAdd32` ? [#587](https://github.com/CocoaLumberjack/CocoaLumberjack/pull/587)
- `rollLogFileWithCompletionBlock` calls back on background queue instead of main queue [#589](https://github.com/CocoaLumberjack/CocoaLumberjack/pull/589)
- Removing extraneous `\` on line 55 [#600](https://github.com/CocoaLumberjack/CocoaLumberjack/pull/600)
- Updated `GettingStarted.md` to include `ddLogLevel` [#602](https://github.com/CocoaLumberjack/CocoaLumberjack/pull/602)
- Remove redundant check for `processorCount` availability [#604](https://github.com/CocoaLumberjack/CocoaLumberjack/pull/604)


## [2.0.1 Patch for 2.0.0 on Jun 25th, 2015](https://github.com/CocoaLumberjack/CocoaLumberjack/releases/tag/2.0.1)

- **Carthage support** [#521](https://github.com/CocoaLumberjack/CocoaLumberjack/pull/521) [#526](https://github.com/CocoaLumberjack/CocoaLumberjack/pull/526)
- fixed crash on `DDASLLogCapture` when `TIME` or `TIME_NSEC` is `NULL` [#484](https://github.com/CocoaLumberjack/CocoaLumberjack/pull/484)
- **Swift** fixes and improvements: [#483](https://github.com/CocoaLumberjack/CocoaLumberjack/pull/483) [#509](https://github.com/CocoaLumberjack/CocoaLumberjack/pull/509) [#518](https://github.com/CocoaLumberjack/CocoaLumberjack/pull/518) [#522](https://github.com/CocoaLumberjack/CocoaLumberjack/pull/522) [5eafceb](https://github.com/CocoaLumberjack/CocoaLumberjack/commit/5eafceb)
- Unit tests: [#500](https://github.com/CocoaLumberjack/CocoaLumberjack/pull/500) [#498](https://github.com/CocoaLumberjack/CocoaLumberjack/pull/498) [#499](https://github.com/CocoaLumberjack/CocoaLumberjack/pull/499)
- Fix [#478](https://github.com/CocoaLumberjack/CocoaLumberjack/issues/478) by reverting [#473](https://github.com/CocoaLumberjack/CocoaLumberjack/pull/473)
- Add `armv7s` to static library [#538](https://github.com/CocoaLumberjack/CocoaLumberjack/pull/538)
- Fix `NSLog` `threadid` mismatch with iOS 8+/OSX 10.10+ [#514](https://github.com/CocoaLumberjack/CocoaLumberjack/pull/514)
- Fixed the `LogV` macros so that avalist is no longer undefined [#511](https://github.com/CocoaLumberjack/CocoaLumberjack/pull/511)
- Using type safe `DDColor` alias instead of #define directive [#506](https://github.com/CocoaLumberjack/CocoaLumberjack/pull/506)
- Several fixes/tweaks to `DDASLLogCapture` [#512](https://github.com/CocoaLumberjack/CocoaLumberjack/pull/512)
- Prevent duplicate log entries when both `DDASLLogCapture` and `DDASLLogger` are used [#515](https://github.com/CocoaLumberjack/CocoaLumberjack/pull/515)
- Fix memory leaks in `DDTTYLogger`, add self annotations to blocks [#536](https://github.com/CocoaLumberjack/CocoaLumberjack/pull/536)
- Update older syntax to modern subscripting for array access [#482](https://github.com/CocoaLumberjack/CocoaLumberjack/pull/482)
- Remove execute permission on non-executable files [#517](https://github.com/CocoaLumberjack/CocoaLumberjack/pull/517)
- Change code samples to use `DDLogFlagWarning` [#520](https://github.com/CocoaLumberjack/CocoaLumberjack/pull/520)
- Fix seemingly obvious typo in the `toLogLevel` function [#508](https://github.com/CocoaLumberjack/CocoaLumberjack/pull/508)


## [CocoaLumberjack 2.0.0 on Mar 13th, 2015](https://github.com/CocoaLumberjack/CocoaLumberjack/releases/tag/2.0.0)

The library was strongly refactored, with a few goals in mind:
- Swift support - that we will release in a separate milestone, since CocoaPods 0.36.0 just got out
- Unit tests support
- reorganised things (on disk)
- better coding style

See [Migration from 1.x to 2.x](https://github.com/CocoaLumberjack/CocoaLumberjack#migrating-to-2x)


## [2.0.0-rc2 on Feb 20th, 2015](https://github.com/CocoaLumberjack/CocoaLumberjack/releases/tag/2.0.0-rc2)

- Bucket of Swift improvements - [#434](https://github.com/CocoaLumberjack/CocoaLumberjack/pull/434) [#437](https://github.com/CocoaLumberjack/CocoaLumberjack/pull/437) [#449](https://github.com/CocoaLumberjack/CocoaLumberjack/pull/449) [#440](https://github.com/CocoaLumberjack/CocoaLumberjack/issues/440)
- Fixed [#433](https://github.com/CocoaLumberjack/CocoaLumberjack/pull/433) (build issue due to dispatch_queue properties) - [#455](https://github.com/CocoaLumberjack/CocoaLumberjack/pull/455)
- Enable codesign for iOS device framework builds - [#444](https://github.com/CocoaLumberjack/CocoaLumberjack/pull/444)
- Declare `automaticallyAppendNewlineForCustomFormatters` properties as `nonatomic` - [#443](https://github.com/CocoaLumberjack/CocoaLumberjack/pull/443)
- Warning fixes & type standardization - [#419](https://github.com/CocoaLumberjack/CocoaLumberjack/pull/419)
- Legacy checks updated - [#424](https://github.com/CocoaLumberjack/CocoaLumberjack/pull/424)
- Documentation updates


## [2.0.0-rc on Dec 11th, 2014](https://github.com/CocoaLumberjack/CocoaLumberjack/releases/tag/2.0.0-rc)

- Fix `dispatch_queue_t` properties.
- Fix `registeredClasses` crashes at launch.


## [2.0.0-beta4 on Nov 7th, 2014](https://github.com/CocoaLumberjack/CocoaLumberjack/releases/tag/2.0.0-beta4)

- Major refactoring and clean up.
- Remove superfluous `log` from property names and use underscore for direct variable access.
- Preliminary Swift support through `CocoaLumberjack.swift`.
- Automatic 1.9.x legacy support when `DDLog.h` is imported instead of the new `CocoaLumberjack.h`.


## [2.0.0-beta3 on Oct 21st, 2014](https://github.com/CocoaLumberjack/CocoaLumberjack/releases/tag/2.0.0-beta3)

- Modernize flag variables to be `NS_OPTIONS`/`NS_ENUM`.
- Change the log flags and levels to `NSUInteger`.
- Fix warning when compiled with assertions blocked.
- Crash fixes.


## [2.0.0-beta2 on Sep 30th, 2014](https://github.com/CocoaLumberjack/CocoaLumberjack/releases/tag/2.0.0-beta2)

- Cleanup code.
- Match `NSLog` read UID functionality in `DDASLLogger`.
- Update framework and static libraries.


## [2.0.0 Beta on Aug 12th, 2014](https://github.com/CocoaLumberjack/CocoaLumberjack/releases/tag/2.0.0-beta)

See [Migrate from 1.x to 2.x](https://github.com/CocoaLumberjack/CocoaLumberjack#migrating-to-2x)


## [1.9.2 Updated patch release for 1.9.0 on Aug 11th, 2014](https://github.com/CocoaLumberjack/CocoaLumberjack/releases/tag/1.9.2)

- Fixed `NSCalendar components:fromDate:` crash - [#140](https://github.com/CocoaLumberjack/CocoaLumberjack/issues/140) [#307](https://github.com/CocoaLumberjack/CocoaLumberjack/pull/307) [#216](https://github.com/CocoaLumberjack/CocoaLumberjack/issues/216)
- New `DDAssert` macros - [#306](https://github.com/CocoaLumberjack/CocoaLumberjack/pull/306)
- Limit log growth by disk space only, not the number of files - [#195](https://github.com/CocoaLumberjack/CocoaLumberjack/issues/195) [#303](https://github.com/CocoaLumberjack/CocoaLumberjack/pull/303)
- Change the mechanism for adding new line character (i.e. '\n\) to log messages in some logger - [#308](https://github.com/CocoaLumberjack/CocoaLumberjack/issues/308) [#310](https://github.com/CocoaLumberjack/CocoaLumberjack/pull/310)
- Fixed deprecations - [#320](https://github.com/CocoaLumberjack/CocoaLumberjack/pull/320) [#312](https://github.com/CocoaLumberjack/CocoaLumberjack/pull/312) [#317](https://github.com/CocoaLumberjack/CocoaLumberjack/pull/317)
- `aslmsg` not freed and causing memory leak - [#314](https://github.com/CocoaLumberjack/CocoaLumberjack/pull/314)
- Fixed `CompressingLogFileManager` compression bug - [#315](https://github.com/CocoaLumberjack/CocoaLumberjack/pull/315)
- Remove unnecessary `NULL` check before `free()` - [#316](https://github.com/CocoaLumberjack/CocoaLumberjack/pull/316)


## [1.9.1 Patch release for 1.9.0 on Jun 30th, 2014](https://github.com/CocoaLumberjack/CocoaLumberjack/releases/tag/1.9.1)

- Fixed issues in rolling frequency - [#243](https://github.com/CocoaLumberjack/CocoaLumberjack/issues/243) [#295](https://github.com/CocoaLumberjack/CocoaLumberjack/pull/295) [@georgekola](https://github.com/georgekola)
- Fixed critical issue, `addLogger` method should use a full bit mask instead of `LOG_LEVEL_VERBOSE`, otherwise extended logs or extra flags are ignored [fe6824c](https://github.com/CocoaLumberjack/CocoaLumberjack/commit/fe6824c) [@robbiehanson](https://github.com/robbiehanson)
- Performance optimisation: use compiler macros to skip iOS version checks - [4656d3b](https://github.com/CocoaLumberjack/CocoaLumberjack/commit/4656d3b) [#298](https://github.com/CocoaLumberjack/CocoaLumberjack/pull/298) [#291](https://github.com/CocoaLumberjack/CocoaLumberjack/pull/291) [@robbiehanson](https://github.com/robbiehanson) [@liviur](https://github.com/liviur)
- Changed the `Build Active Architecture Only` to `NO` [#294](https://github.com/CocoaLumberjack/CocoaLumberjack/pull/294) [#293](https://github.com/CocoaLumberjack/CocoaLumberjack/issues/293)
- Optimisation by reusing `NSDateFormatter` instances [#296](https://github.com/CocoaLumberjack/CocoaLumberjack/pull/296) [#301](https://github.com/CocoaLumberjack/CocoaLumberjack/pull/301)


## [1.9.0 New ASL capture module, several File logger fixes on May 23rd, 2014](https://github.com/CocoaLumberjack/CocoaLumberjack/releases/tag/1.9.0)

- New ASL capture module [#242](https://github.com/CocoaLumberjack/CocoaLumberjack/pull/242) [#263](https://github.com/CocoaLumberjack/CocoaLumberjack/pull/263)
- Override default `NSFileProtection` handling [#285](https://github.com/CocoaLumberjack/CocoaLumberjack/pull/285)
- Replaced warnings when ARC was not enabled with errors [#284](https://github.com/CocoaLumberjack/CocoaLumberjack/pull/284)
- Fix for issue [#278](https://github.com/CocoaLumberjack/CocoaLumberjack/issues/278) where really large log files can keep growing [#280](https://github.com/CocoaLumberjack/CocoaLumberjack/pull/280)
- Fixed Xcode warnings [#279](https://github.com/CocoaLumberjack/CocoaLumberjack/pull/279)
- Update `calendarUnitFlags` with new iOS SDK values [#277](https://github.com/CocoaLumberjack/CocoaLumberjack/pull/277)
- Fix possible crash in `[NSCalendar components:fromDate:]` [#277](https://github.com/CocoaLumberjack/CocoaLumberjack/pull/277)
- Fix [#262](https://github.com/CocoaLumberjack/CocoaLumberjack/issues/262) inverted ifs when renaming log [#264](https://github.com/CocoaLumberjack/CocoaLumberjack/pull/264)
- Proper way of doing singletons (via `dispatch_once`) [#259](https://github.com/CocoaLumberjack/CocoaLumberjack/pull/259)
- Explicitly declare `DDFileLogger` and `DDDispatchQueueLogFormatter ` properties as atomic to avoid Xcode warnings [#258](https://github.com/CocoaLumberjack/CocoaLumberjack/pull/258)
- Set `NSFileProtectionKey` on the temporary file created during compression [#256](https://github.com/CocoaLumberjack/CocoaLumberjack/pull/256)
- Fix a rare crash in `CompressingLogFileManager` caused by an unchecked result from read [#255](https://github.com/CocoaLumberjack/CocoaLumberjack/pull/255)
- Add explicit casts for integer conversion [#253](https://github.com/CocoaLumberjack/CocoaLumberjack/pull/253)
- Replace use of `NSThread.detachNewThreadSelector` [#251](https://github.com/CocoaLumberjack/CocoaLumberjack/pull/251)
- Add a constructor override for `initWithLogsDirectory:` [#252](https://github.com/CocoaLumberjack/CocoaLumberjack/pull/252)
- Check and log the streamError whenever we fail to write during compression and log any failures when removing the original file or cleaning up the temporary file after compression failed [#250](https://github.com/CocoaLumberjack/CocoaLumberjack/pull/250)
- Following Apple's guidelines for iOS Static Libraries [#249](https://github.com/CocoaLumberjack/CocoaLumberjack/pull/249)
- Some extra warnings for the mobile framework xcode project [a2e5666](https://github.com/CocoaLumberjack/CocoaLumberjack/commit/a2e5666)
- Update `FineGrainedLoggingAppDelegate.m` [#244](https://github.com/CocoaLumberjack/CocoaLumberjack/pull/244)
- New `[DDLog log:message:]` primitive [7f8af2e](https://github.com/CocoaLumberjack/CocoaLumberjack/commit/7f8af2e)
- Fixed issue [#181](https://github.com/CocoaLumberjack/CocoaLumberjack/issues/181) when logging messages in iOS7 devices aren't properly retrieved by `asl_search` [#240](https://github.com/CocoaLumberjack/CocoaLumberjack/pull/240)
- Allow prevention of log file reuse [#238](https://github.com/CocoaLumberjack/CocoaLumberjack/pull/238)
- `DDTTYLogger`: Favour XcodeColors environment variable [#237](https://github.com/CocoaLumberjack/CocoaLumberjack/pull/237)
- `DDLog`: calling `atexit_b` in CLI applications, that use Foundation framework [#234](https://github.com/CocoaLumberjack/CocoaLumberjack/pull/234)


## [1.8.1 AllLoggers and bugfixes on Feb 14th, 2014](https://github.com/CocoaLumberjack/CocoaLumberjack/releases/tag/1.8.1)

- read access to all loggers - [#217](https://github.com/CocoaLumberjack/CocoaLumberjack/issues/217) [#219](https://github.com/CocoaLumberjack/CocoaLumberjack/pull/219)
- fixed bug with archived logs not being handled correctly on iOS simulator - [#218](https://github.com/CocoaLumberjack/CocoaLumberjack/pull/218)
- log the `strerror(errno)` value when `setxattr()` fails - [#211](https://github.com/CocoaLumberjack/CocoaLumberjack/pull/211)
- Add a check for an archived log before overwriting - [#214](https://github.com/CocoaLumberjack/CocoaLumberjack/pull/214)
- improved safety by using assertions instead of comments (`DDLog` in the core) - [#221](https://github.com/CocoaLumberjack/CocoaLumberjack/pull/221)
- added Lumberjack logo :)


## [1.8.0 Better CL support, custom logfile name format, bugfixes on Jan 21st, 2014](https://github.com/CocoaLumberjack/CocoaLumberjack/releases/tag/1.8.0)

- `DDFileLogger` custom logfile (name) format - [#208](https://github.com/CocoaLumberjack/CocoaLumberjack/pull/208)
- Security static analysis fix - [#202](https://github.com/CocoaLumberjack/CocoaLumberjack/pull/202)
- `DDFileLogger`: using `CFBundleIdentifier` as a log filename prefix on OSX and iOS - [#206](https://github.com/CocoaLumberjack/CocoaLumberjack/pull/206)
- Allow disabling of specific levels per-logger - [#204](https://github.com/CocoaLumberjack/CocoaLumberjack/pull/204)
- Improve support for OS X command line tools - [#194](https://github.com/CocoaLumberjack/CocoaLumberjack/pull/194)
- `DDFileLogger`: fixed crash that occurred in case if application name == nil - [#198](https://github.com/CocoaLumberjack/CocoaLumberjack/pull/198)
- `DDFileLogger`: fixed comment - [#199](https://github.com/CocoaLumberjack/CocoaLumberjack/pull/199)
- Fix Travis - [#205](https://github.com/CocoaLumberjack/CocoaLumberjack/pull/205)


## [1.7.0 New log file naming convention and CocoaLumberjack organisation on Dec 10th, 2013](https://github.com/CocoaLumberjack/CocoaLumberjack/releases/tag/1.7.0)

- new log file naming convention - [#191](https://github.com/CocoaLumberjack/CocoaLumberjack/pull/191)
- completed transition to **CocoaLumberjack** organisation - [#188](https://github.com/CocoaLumberjack/CocoaLumberjack/pull/188)


## [1.6.5.1 Patch release for Xcode 4.4+ compatibility on Dec 4th, 2013](https://github.com/CocoaLumberjack/CocoaLumberjack/releases/tag/1.6.5.1)

- fixed compatibility with Xcode 4.4+ [#187](https://github.com/CocoaLumberjack/CocoaLumberjack/pull/187)


## [1.6.5 File Logger refactoring, Multi Formatter, preffixed extension classes on Dec 3rd, 2013](https://github.com/CocoaLumberjack/CocoaLumberjack/releases/tag/1.6.5)

`DDFileLogger` refactoring and fixes (thanks [@dvor](https://github.com/dvor) and [@an0](https://github.com/an0)):
- Fixed [#63](https://github.com/CocoaLumberjack/CocoaLumberjack/issues/63) Loggers don't flush in Command Line Tool [#184](https://github.com/CocoaLumberjack/CocoaLumberjack/pull/184)
- Fixed [#52](https://github.com/CocoaLumberjack/CocoaLumberjack/issues/52) Force log rotation [#183](https://github.com/CocoaLumberjack/CocoaLumberjack/pull/183)
- Fixed [#55](https://github.com/CocoaLumberjack/CocoaLumberjack/issues/55) After deleting log file or log dir they aren't created again without relaunching the app [#183](https://github.com/CocoaLumberjack/CocoaLumberjack/pull/183)
- Fixed [#129](https://github.com/CocoaLumberjack/CocoaLumberjack/issues/129) [iOS] `DDFileLogger` causes crash when logging from background app [#183](https://github.com/CocoaLumberjack/CocoaLumberjack/pull/183)
- Fixed [#153](https://github.com/CocoaLumberjack/CocoaLumberjack/issues/153) Log file on iPhone only contains a single line [#177](https://github.com/CocoaLumberjack/CocoaLumberjack/pull/177)
- Fixed [#155](https://github.com/CocoaLumberjack/CocoaLumberjack/issues/155) How do I combine all my log levels into one file? [#177](https://github.com/CocoaLumberjack/CocoaLumberjack/pull/177)
- Fixed [#175](https://github.com/CocoaLumberjack/CocoaLumberjack/issues/175) `DFileLogger` `creationDate` bug on 64-bit iOS system [#177](https://github.com/CocoaLumberjack/CocoaLumberjack/pull/177)
- Allow customizing the naming convention for log files to use timestamps [#174](https://github.com/CocoaLumberjack/CocoaLumberjack/pull/174)

Other:
- Implemented multiple formatter (`DDMultiFormatter` - alows chaining of formatters) [#178](https://github.com/CocoaLumberjack/CocoaLumberjack/pull/178)
- Added DD prefix to extension classes (`ContextFilterLogFormatter` and `DispatchQueueLogFormatter`) [#178](https://github.com/CocoaLumberjack/CocoaLumberjack/pull/178)
- Updated code indentation: Tabs changed to spaces [#180](https://github.com/CocoaLumberjack/CocoaLumberjack/pull/180)
- Included `DDLog+LOGV.h` in Cocoapods sources [d253bd7](https://github.com/CocoaLumberjack/CocoaLumberjack/commit/d253bd7)
- other fixes/improvements


## [1.6.4 Fix compatibility with 3rd party frameworks on Nov 21st, 2013](https://github.com/CocoaLumberjack/CocoaLumberjack/releases/tag/1.6.4)

* "Fix" conflicts with 3rd party libraries using `CocoaLumberjack` [#172](https://github.com/CocoaLumberjack/CocoaLumberjack/pull/172)
* Ignore deprecated warning for `dispatch_get_current_queue` [#167](https://github.com/CocoaLumberjack/CocoaLumberjack/pull/167)
* Add new `DEBUG` log level support to included loggers [#166](https://github.com/CocoaLumberjack/CocoaLumberjack/pull/166)
* Method declarations that make it easier to extend/modify `DispatchQueueLogFormatter` [#164](https://github.com/CocoaLumberjack/CocoaLumberjack/pull/164)


## [1.6.3 New macros, updated podspec and bug fixes on Apr 2nd, 2013](https://github.com/CocoaLumberjack/CocoaLumberjack/releases/tag/1.6.3)

* Add `LOGV`-style macros [#161](https://github.com/CocoaLumberjack/CocoaLumberjack/pull/161)
* Fix getting queue's label [#159](https://github.com/CocoaLumberjack/CocoaLumberjack/pull/159)
* New log level `DEBUG` [#145](https://github.com/CocoaLumberjack/CocoaLumberjack/pull/145)
* Use `DISPATCH_CURRENT_QUEUE_LABEL` if available [#159](https://github.com/CocoaLumberjack/CocoaLumberjack/pull/159)
* Different `logLevel` per each logger [#151](https://github.com/CocoaLumberjack/CocoaLumberjack/pull/151)
* Created 2 subspecs, `Core` and `Extensions` [#152](https://github.com/CocoaLumberjack/CocoaLumberjack/pull/152)
* Updated observer for keypath using `NSStringFromSelector` + `@selector` [38e5da3](https://github.com/CocoaLumberjack/CocoaLumberjack/commit/38e5da3)
* Replaced `id` return type with `instancetype` [ebee454](https://github.com/CocoaLumberjack/CocoaLumberjack/commit/ebee454)
* Remove implicit conversion warnings [#149](https://github.com/CocoaLumberjack/CocoaLumberjack/pull/149)
* `DDTTYLogger`: Allow to set default color profiles for all contexts at once [#146](https://github.com/CocoaLumberjack/CocoaLumberjack/pull/146) [#158](https://github.com/CocoaLumberjack/CocoaLumberjack/pull/158)
* `DDTTYLogger`: By default apply `setForegroundColor:backgroundColor:forFlag:` to `LOG_CONTEXT_ALL` [#154](https://github.com/CocoaLumberjack/CocoaLumberjack/pull/154)
* `DispatchQueueLogFormatter`: Use modern Objective-C [#142](https://github.com/CocoaLumberjack/CocoaLumberjack/pull/142)
* `DispatchQueueLogFormatter`: Make sure to always use a `NSGregorianCalendar` for date formatter [#142](https://github.com/CocoaLumberjack/CocoaLumberjack/pull/142)
* Replaced explicit reference to class name in `logFileWithPath` factory method [#131](https://github.com/CocoaLumberjack/CocoaLumberjack/pull/131)
* Catch exceptions in `logMessage:` [#130](https://github.com/CocoaLumberjack/CocoaLumberjack/pull/130)
* Fix enum type conversion warnings [#124](https://github.com/CocoaLumberjack/CocoaLumberjack/pull/124)
* Add deployment target condition for workaround [#121](https://github.com/CocoaLumberjack/CocoaLumberjack/pull/121)
* Fix static analyzer warnings about `nil` values in dictionary [#122](https://github.com/CocoaLumberjack/CocoaLumberjack/pull/122)
* Fix `dispatch_get_current_queue` crash [#121](https://github.com/CocoaLumberjack/CocoaLumberjack/pull/121)
* Fixing colors in greyscale color-space not working [d019cfd](https://github.com/CocoaLumberjack/CocoaLumberjack/commit/d019cfd)
* Guard around `dispatch_resume()` being called with null pointer [#107](https://github.com/CocoaLumberjack/CocoaLumberjack/pull/107)
* `NULL` safety checks [#107](https://github.com/CocoaLumberjack/CocoaLumberjack/pull/107)


## [1.6.2 on Apr 2nd, 2013](https://github.com/CocoaLumberjack/CocoaLumberjack/releases/tag/1.6.2)

## [1.6.1 on Apr 2nd, 2013](https://github.com/CocoaLumberjack/CocoaLumberjack/releases/tag/1.6.1)

## [1.6 on Jul 3rd, 2012](https://github.com/CocoaLumberjack/CocoaLumberjack/releases/tag/1.6)

## [1.5.1 on Jul 3rd, 2012](https://github.com/CocoaLumberjack/CocoaLumberjack/releases/tag/1.5.1)

## [1.5 on Jul 3rd, 2012](https://github.com/CocoaLumberjack/CocoaLumberjack/releases/tag/1.5)

## [1.4.1 on Jul 3rd, 2012](https://github.com/CocoaLumberjack/CocoaLumberjack/releases/tag/1.4.1)

## [1.4 on Jul 3rd, 2012](https://github.com/CocoaLumberjack/CocoaLumberjack/releases/tag/1.4)

## [1.3.3 on Mar 30th, 2012](https://github.com/CocoaLumberjack/CocoaLumberjack/releases/tag/1.3.3)

## [1.3.2 on Dec 23rd, 2011](https://github.com/CocoaLumberjack/CocoaLumberjack/releases/tag/1.3.2)

## [1.3.1 on Dec 9th, 2011](https://github.com/CocoaLumberjack/CocoaLumberjack/releases/tag/1.3.1)

## [1.3 on Dec 9th, 2011](https://github.com/CocoaLumberjack/CocoaLumberjack/releases/tag/1.3)

## [1.2.3 on Dec 9th, 2011](https://github.com/CocoaLumberjack/CocoaLumberjack/releases/tag/1.2.3)

## [1.2.2 on Dec 9th, 2011](https://github.com/CocoaLumberjack/CocoaLumberjack/releases/tag/1.2.2)

## [1.2.1 on Oct 13th, 2011](https://github.com/CocoaLumberjack/CocoaLumberjack/releases/tag/1.2.1)

## [1.2 on Oct 13th, 2011](https://github.com/CocoaLumberjack/CocoaLumberjack/releases/tag/1.2)

## [1.1 on Oct 13th, 2011](https://github.com/CocoaLumberjack/CocoaLumberjack/releases/tag/1.1)

## [1.0 on Oct 13th, 2011](https://github.com/CocoaLumberjack/CocoaLumberjack/releases/tag/1.0)
