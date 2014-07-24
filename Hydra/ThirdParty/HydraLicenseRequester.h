#import <Cocoa/Cocoa.h>

@protocol HydraLicenseRequesterDelegate <NSObject>

- (BOOL) tryLicense:(NSString*)license forEmail:(NSString*)email;
- (void) closed;

@end

@interface HydraLicenseRequester : NSWindowController

- (void) request;

@property id<HydraLicenseRequesterDelegate> delegate;

@end
