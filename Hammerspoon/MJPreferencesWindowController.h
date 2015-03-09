#import <Cocoa/Cocoa.h>

@interface MJPreferencesWindowController : NSWindowController

+ (instancetype) singleton;

@end

BOOL HSUploadCrashData(void);
void HSSetUploadCrashData(BOOL uploadCrashData);