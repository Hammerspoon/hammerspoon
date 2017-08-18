#import <Cocoa/Cocoa.h>

@interface MJPreferencesWindowController : NSWindowController

+ (instancetype) singleton;

@end

BOOL HSUploadCrashData(void);
void HSSetUploadCrashData(BOOL uploadCrashData);

//
// Enable & Disable Preferences Dark Mode:
//
BOOL PreferencesDarkModeEnabled(void);
void PreferencesDarkModeSetEnabled(BOOL enabled);
