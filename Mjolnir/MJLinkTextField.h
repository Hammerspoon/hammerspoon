#import <Cocoa/Cocoa.h>

@interface MJLinkTextField : NSTextField

- (void) addLink:(NSString*)link inRange:(NSRange)r;

@end
