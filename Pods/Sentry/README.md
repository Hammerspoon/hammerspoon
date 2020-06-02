<p align="center">
    <a href="https://sentry.io" target="_blank" align="center">
        <img src="https://sentry-brand.storage.googleapis.com/sentry-logo-black.png" width="280">
    </a>
<br/>
    <h1>Official Sentry SDK for iOS / tvOS / macOS / watchOS <sup>(1)</sup>.</h1>
</p>

[![Travis](https://img.shields.io/travis/getsentry/sentry-cocoa.svg?maxAge=2592000)](https://travis-ci.com/getsentry/sentry-cocoa)
[![codebeat badge](https://codebeat.co/badges/07f0bc91-9102-4fd8-99a6-30b25dc98037)](https://codebeat.co/projects/github-com-getsentry-sentry-cocoa-master)
[![codecov.io](https://codecov.io/gh/getsentry/sentry-cocoa/branch/master/graph/badge.svg)](https://codecov.io/gh/getsentry/sentry-cocoa)
[![CocoaPods compadible](https://img.shields.io/cocoapods/v/Sentry.svg)](https://cocoapods.org/pods/Sentry)
[![Carthage compatible](https://img.shields.io/badge/Carthage-compatible-4BC51D.svg?style=flat)](https://github.com/Carthage/Carthage)
[![SwiftPM compatible](https://img.shields.io/badge/spm-compatible-brightgreen.svg?style=flat)](https://swift.org/package-manager)
![platforms](https://img.shields.io/cocoapods/p/Sentry.svg?style=flat)
[![Twitter](https://img.shields.io/badge/twitter-@getsentry-blue.svg?style=flat)](http://twitter.com/getsentry)

This SDK is written in Objective-C but also provides a nice Swift interface.

# Initialization

*Remember to call this as early in your application life cycle as possible*
Ideally in `applicationDidFinishLaunching` in `AppDelegate`

```swift
import Sentry

// ....

SentrySDK.start(options: [
    "dsn": "___PUBLIC_DSN___",
    "debug": true // Helpful to see what's going on
])
```

```objective-c
@import Sentry;

// ....

[SentrySDK startWithOptions:@{
    @"dsn": @"___PUBLIC_DSN___",
    @"debug": @(YES) // Helpful to see what's going on
}];
```

- [Documentation](https://docs.sentry.io/platforms/cocoa/)

<sup>(1)</sup>limited symbolication support
