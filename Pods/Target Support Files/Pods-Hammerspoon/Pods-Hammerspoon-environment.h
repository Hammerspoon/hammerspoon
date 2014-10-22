
// To check if a library is compiled with CocoaPods you
// can use the `COCOAPODS` macro definition which is
// defined in the xcconfigs so it is available in
// headers also when they are imported in the client
// project.


// lua
#define COCOAPODS_POD_AVAILABLE_lua
#define COCOAPODS_VERSION_MAJOR_lua 5
#define COCOAPODS_VERSION_MINOR_lua 2
#define COCOAPODS_VERSION_PATCH_lua 3

// Release build configuration
#ifdef RELEASE

  // Sparkle
  #define COCOAPODS_POD_AVAILABLE_Sparkle
  #define COCOAPODS_VERSION_MAJOR_Sparkle 1
  #define COCOAPODS_VERSION_MINOR_Sparkle 8
  #define COCOAPODS_VERSION_PATCH_Sparkle 0

#endif
