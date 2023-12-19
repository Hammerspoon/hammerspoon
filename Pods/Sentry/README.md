<p align="center">
  <a href="https://sentry.io/?utm_source=github&utm_medium=logo" target="_blank">
    <img src="https://sentry-brand.storage.googleapis.com/sentry-wordmark-dark-280x84.png" alt="Sentry" width="280" height="84">
  </a>
<br/>
    <h1>Official Sentry SDK for iOS / tvOS / macOS / watchOS <sup>(1)</sup>.</h1>
</p>

_Bad software is everywhere, and we're tired of it. Sentry is on a mission to help developers write better software faster, so we can get back to enjoying technology. If you want to join us [<kbd>**Check out our open positions**</kbd>](https://sentry.io/careers/)_

[![Build](https://img.shields.io/github/actions/workflow/status/getsentry/sentry-cocoa/build.yml?branch=main)](https://github.com/getsentry/sentry-cocoa/actions/workflows/build.yml?query=branch%3Amain)
[![codebeat badge](https://codebeat.co/badges/07f0bc91-9102-4fd8-99a6-30b25dc98037)](https://codebeat.co/projects/github-com-getsentry-sentry-cocoa-master)
[![codecov.io](https://codecov.io/gh/getsentry/sentry-cocoa/branch/master/graph/badge.svg)](https://codecov.io/gh/getsentry/sentry-cocoa)
[![CocoaPods compadible](https://img.shields.io/cocoapods/v/Sentry.svg)](https://cocoapods.org/pods/Sentry)
[![Carthage compatible](https://img.shields.io/badge/Carthage-compatible-4BC51D.svg?style=flat)](https://github.com/Carthage/Carthage)
[![SwiftPM compatible](https://img.shields.io/badge/spm-compatible-brightgreen.svg?style=flat)](https://swift.org/package-manager)
![platforms](https://img.shields.io/cocoapods/p/Sentry.svg?style=flat)
[![Swift Package Index](https://img.shields.io/endpoint?url=https%3A%2F%2Fswiftpackageindex.com%2Fapi%2Fpackages%2Fgetsentry%2Fsentry-cocoa%2Fbadge%3Ftype%3Dswift-versions)](https://swiftpackageindex.com/getsentry/sentry-cocoa)
[![Discord Chat](https://img.shields.io/discord/621778831602221064?logo=discord&logoColor=ffffff&color=7389D8)](https://discord.gg/PXa5Apfe7K)  

This SDK is written in Objective-C but also provides a nice Swift interface.

**Where is the master branch?**

We renamed the default branch from `master` to `main`.

# Initialization

*Remember to call this as early in your application life cycle as possible*
Ideally in `applicationDidFinishLaunching` in `AppDelegate`

```swift
import Sentry

// ....

SentrySDK.start { options in
    options.dsn = "___PUBLIC_DSN___"
    options.debug = true // Helpful to see what's going on
}    
```

```objc
@import Sentry;

// ....

[SentrySDK startWithConfigureOptions:^(SentryOptions *options) {
    options.dsn = @"___PUBLIC_DSN___";
    options.debug = @YES; // Helpful to see what's going on
}];

```

For more information checkout the [docs](https://docs.sentry.io/platforms/apple).

<sup>(1)</sup>limited symbolication support and no crash handling.

# Blog posts

[Mobile Vitals - Four Metrics Every Mobile Developer Should Care About](https://blog.sentry.io/2021/08/23/mobile-vitals-four-metrics-every-mobile-developer-should-care-about/).

[How to use Sentry Attachments with Mobile Applications](https://blog.sentry.io/2021/02/03/how-to-use-sentry-attachments-with-mobile-applications/?utm_source=github&utm_medium=readme&utm_campaign=sentry-cocoa).

[Close the Loop with User Feedback](https://blog.sentry.io/2021/02/16/close-the-loop-with-user-feedback/?utm_source=github&utm_medium=readme&utm_campaign=sentry-cocoa).

[A Sanity Listicle for Mobile Developers](https://blog.sentry.io/2021/03/30/a-sanity-listicle-for-mobile-developers/?utm_source=github&utm_medium=readme&utm_campaign=sentry-cocoa).

# Resources

* [![Documentation](https://img.shields.io/badge/documentation-sentry.io-green.svg)](https://docs.sentry.io/platforms/apple/)
* [![Discussions](https://img.shields.io/github/discussions/getsentry/sentry-cocoa.svg)](https://github.com/getsentry/sentry-cocoa/discussions)
* [![Discord Chat](https://img.shields.io/discord/621778831602221064?logo=discord&logoColor=ffffff&color=7389D8)](https://discord.gg/PXa5Apfe7K)  
* [![Stack Overflow](https://img.shields.io/badge/stack%20overflow-sentry-green.svg)](http://stackoverflow.com/questions/tagged/sentry)
* [![Code of Conduct](https://img.shields.io/badge/code%20of%20conduct-sentry-green.svg)](https://github.com/getsentry/.github/blob/master/CODE_OF_CONDUCT.md)
* [![Twitter Follow](https://img.shields.io/twitter/follow/getsentry?label=getsentry&style=social)](https://twitter.com/intent/follow?screen_name=getsentry)
