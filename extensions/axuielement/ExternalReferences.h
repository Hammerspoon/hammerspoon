// AXTextMarker and AXTextMarkerRange support gleaned from HIServices framework disassembly and
// https://chromium.googlesource.com/chromium/src/+/ee5dac5d4335b5f4fc6bd99136d38e7a070a4559/content/browser/accessibility/browser_accessibility_cocoa.mm
typedef CFTypeRef AXTextMarkerRangeRef ;
typedef CFTypeRef AXTextMarkerRef ;

extern CFTypeID        AXTextMarkerGetTypeID(void) __attribute__((weak_import)) ;
extern AXTextMarkerRef AXTextMarkerCreate(CFAllocatorRef allocator, const char* bytes, CFIndex length) __attribute__((weak_import)) ;
extern CFIndex         AXTextMarkerGetLength(AXTextMarkerRef text_marker) __attribute__((weak_import)) ;
extern const char*     AXTextMarkerGetBytePtr(AXTextMarkerRef text_marker) __attribute__((weak_import)) ;

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
