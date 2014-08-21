#import <Cocoa/Cocoa.h>

@interface MJLinkTextField : NSTextField
@end

void MJLinkTextFieldAddLink(MJLinkTextField* self, NSString* link, NSRange r);
