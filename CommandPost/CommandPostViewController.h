#import <Cocoa/Cocoa.h>
#import <ProExtension/ProExtension.h>
#import <ProExtensionHost/ProExtensionHost.h>

#import "CocoaAsyncSocket/GCDAsyncSocket.h"

NS_ASSUME_NONNULL_BEGIN

@interface CommandPostViewController : NSViewController

@property id<FCPXHost>              host;
@property (readonly) NSString       * hostInfoString;

@end

NS_ASSUME_NONNULL_END
