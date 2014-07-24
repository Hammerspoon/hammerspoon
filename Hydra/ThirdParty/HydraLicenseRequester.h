#import <Cocoa/Cocoa.h>

@protocol HydraLicenseRequesterDelegate <NSObject>

- (BOOL) tryingLicense:(NSString*)license forEmail:(NSString*)email;

@end

@interface HydraLicenseRequester : NSWindowController

- (void) request;

@property id<HydraLicenseRequesterDelegate> delegate;

@end
