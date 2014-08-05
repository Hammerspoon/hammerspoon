#import <Foundation/Foundation.h>

@protocol MJTabController <NSObject>

- (NSView*) view;
- (NSString*) title;
- (NSImage*) icon;
@property IBOutlet NSView* initialFirstResponder;

@end
