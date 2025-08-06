#import <Cocoa/Cocoa.h>
#import <ProExtension/ProExtension.h>
#import <ProExtensionHost/ProExtensionHost.h>

#import "CocoaAsyncSocket/GCDAsyncSocket.h"

NS_ASSUME_NONNULL_BEGIN

@interface CommandPostViewController : NSViewController <GCDAsyncSocketDelegate>
{
    dispatch_queue_t socketQueue;
    GCDAsyncSocket *listenSocket;
    NSMutableArray *connectedSockets;
}

@property id<FCPXHost>              host;
@property (readonly) NSString       *hostInfoString;
@property GCDAsyncSocket            *socket;

@end

NS_ASSUME_NONNULL_END
