// AXTextMarker and AXTextMarkerRange support gleaned from HIServices framework disassembly and
// https://chromium.googlesource.com/chromium/src/+/ee5dac5d4335b5f4fc6bd99136d38e7a070a4559/content/browser/accessibility/browser_accessibility_cocoa.mm

// FIXME: Remove this, #2982
// These are no longer needed as of macOS 12, but they are still necessary for building on macOS 11 until GitHub Actions adds macOS 12 build environments
#ifndef MAC_OS_VERSION_12_0
#warning Building with MAC_OS_X_VERSION_MAX_ALLOWED < MAC_OS_VERSION_12_0
    typedef CFTypeRef AXTextMarkerRangeRef ;
    typedef CFTypeRef AXTextMarkerRef ;
    extern CFTypeID        AXTextMarkerGetTypeID(void) __attribute__((weak_import)) ;
    extern AXTextMarkerRef AXTextMarkerCreate(CFAllocatorRef allocator, const char* bytes, CFIndex length) __attribute__((weak_import)) ;
    extern CFIndex         AXTextMarkerGetLength(AXTextMarkerRef text_marker) __attribute__((weak_import)) ;
    extern const char*     AXTextMarkerGetBytePtr(AXTextMarkerRef text_marker) __attribute__((weak_import)) ;
#endif

extern CFTypeID             AXTextMarkerRangeGetTypeID(void) __attribute__((weak_import)) ;
extern AXTextMarkerRangeRef AXTextMarkerRangeCreate(CFAllocatorRef allocator, AXTextMarkerRef start_marker, AXTextMarkerRef end_marker) __attribute__((weak_import)) ;
extern AXTextMarkerRef      AXTextMarkerRangeCopyStartMarker(AXTextMarkerRangeRef text_marker_range) __attribute__((weak_import)) ;
extern AXTextMarkerRef      AXTextMarkerRangeCopyEndMarker(AXTextMarkerRangeRef text_marker_range) __attribute__((weak_import)) ;


// In AppKit disassembly but not in header files
extern NSString *NSAccessibilityAttributedValueForStringAttributeParameterizedAttribute ;
extern NSString *NSAccessibilityScrollToShowDescendantParameterizedAttributeAction ;
extern NSString *NSAccessibilityIndexForChildUIElementParameterizedAttribute ;
extern NSString *NSAccessibilityResultsForSearchPredicateParameterizedAttribute ;
extern NSString *NSAccessibilityLoadSearchResultParameterizedAttribute ;
extern NSString *NSAccessibilityFocusRingManipulationParameterizedAttribute ;
extern NSString *NSAccessibilityReplaceRangeWithTextParameterizedAttribute ;
