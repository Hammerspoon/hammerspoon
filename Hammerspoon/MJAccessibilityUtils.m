#import "MJAccessibilityUtils.h"

extern Boolean AXIsProcessTrustedWithOptions(CFDictionaryRef options) __attribute__((weak_import));
extern CFStringRef kAXTrustedCheckOptionPrompt __attribute__((weak_import));


BOOL MJAccessibilityIsEnabled(void) {
    if (AXIsProcessTrustedWithOptions != NULL)
        return AXIsProcessTrustedWithOptions(NULL);
    else
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wdeprecated-declarations"
        return AXAPIEnabled();
#pragma clang diagnostic pop
}

void MJAccessibilityOpenPanel(void) {
    if (AXIsProcessTrustedWithOptions != NULL) {
        AXIsProcessTrustedWithOptions((__bridge CFDictionaryRef)@{(__bridge id)kAXTrustedCheckOptionPrompt: @YES});
    }
    else {
        static NSString* script = @"tell application \"System Preferences\"\nactivate\nset current pane to pane \"com.apple.preference.universalaccess\"\nend tell";
        [[[NSAppleScript alloc] initWithSource:script] executeAndReturnError:nil];
    }
}
