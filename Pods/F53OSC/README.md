# F53OSC

Hey neat, it's a nice open source OSC library for Objective-C.

From your friends at [Figure 53](https://figure53.com).

For convenience, we've included a few public domain source files from [CocoaAsyncSocket](https://github.com/robbiehanson/CocoaAsyncSocket).  But appropriate thanks, kudos, and curiosity about that code should be directed to [the source](https://github.com/robbiehanson/CocoaAsyncSocket).

## Usage Notes

- F53OSC must be compiled with ARC.
- You must link against `Security.framework` and `CFNetwork.framework`.
- F53OSC requires Xcode 10.3 or later and a minimum deployment target of macOS 10.9, iOS 8.4, or tvOS 9.0.

You can also use CocoaPods to include F53OSC into your project:

```
pod 'F53OSC', :git => 'https://github.com/Figure53/F53OSC.git'
```

## Demo

Included is a small demo app "F53OSC Monitor", which logs OSC messages sent to it via port 9999 and displays some basic stats about incoming traffic.
