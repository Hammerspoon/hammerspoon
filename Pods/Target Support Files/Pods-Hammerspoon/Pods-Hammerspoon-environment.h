
// To check if a library is compiled with CocoaPods you
// can use the `COCOAPODS` macro definition which is
// defined in the xcconfigs so it is available in
// headers also when they are imported in the client
// project.


// ASCIImage
#define COCOAPODS_POD_AVAILABLE_ASCIImage
#define COCOAPODS_VERSION_MAJOR_ASCIImage 1
#define COCOAPODS_VERSION_MINOR_ASCIImage 0
#define COCOAPODS_VERSION_PATCH_ASCIImage 0

// CocoaAsyncSocket
#define COCOAPODS_POD_AVAILABLE_CocoaAsyncSocket
#define COCOAPODS_VERSION_MAJOR_CocoaAsyncSocket 7
#define COCOAPODS_VERSION_MINOR_CocoaAsyncSocket 4
#define COCOAPODS_VERSION_PATCH_CocoaAsyncSocket 2

// CocoaHTTPServer
#define COCOAPODS_POD_AVAILABLE_CocoaHTTPServer
#define COCOAPODS_VERSION_MAJOR_CocoaHTTPServer 2
#define COCOAPODS_VERSION_MINOR_CocoaHTTPServer 3
#define COCOAPODS_VERSION_PATCH_CocoaHTTPServer 0

// CocoaLumberjack
#define COCOAPODS_POD_AVAILABLE_CocoaLumberjack
#define COCOAPODS_VERSION_MAJOR_CocoaLumberjack 2
#define COCOAPODS_VERSION_MINOR_CocoaLumberjack 0
#define COCOAPODS_VERSION_PATCH_CocoaLumberjack 1

// CocoaLumberjack/Core
#define COCOAPODS_POD_AVAILABLE_CocoaLumberjack_Core
#define COCOAPODS_VERSION_MAJOR_CocoaLumberjack_Core 2
#define COCOAPODS_VERSION_MINOR_CocoaLumberjack_Core 0
#define COCOAPODS_VERSION_PATCH_CocoaLumberjack_Core 1

// CocoaLumberjack/Default
#define COCOAPODS_POD_AVAILABLE_CocoaLumberjack_Default
#define COCOAPODS_VERSION_MAJOR_CocoaLumberjack_Default 2
#define COCOAPODS_VERSION_MINOR_CocoaLumberjack_Default 0
#define COCOAPODS_VERSION_PATCH_CocoaLumberjack_Default 1

// CocoaLumberjack/Extensions
#define COCOAPODS_POD_AVAILABLE_CocoaLumberjack_Extensions
#define COCOAPODS_VERSION_MAJOR_CocoaLumberjack_Extensions 2
#define COCOAPODS_VERSION_MINOR_CocoaLumberjack_Extensions 0
#define COCOAPODS_VERSION_PATCH_CocoaLumberjack_Extensions 1

// Release build configuration
#ifdef RELEASE

  // Sparkle
  #define COCOAPODS_POD_AVAILABLE_Sparkle
  #define COCOAPODS_VERSION_MAJOR_Sparkle 1
  #define COCOAPODS_VERSION_MINOR_Sparkle 10
  #define COCOAPODS_VERSION_PATCH_Sparkle 0

#endif
