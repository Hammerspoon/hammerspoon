#import <Foundation/Foundation.h>

@interface PHPathWatcher : NSObject

+ (PHPathWatcher*) watcherFor:(NSString*)path handler:(void(^)())handler;

@end

@interface PHPathWatcher ()

@property FSEventStreamRef stream;
@property (copy) void(^handler)();

@end

@implementation PHPathWatcher

void fsEventsCallback(ConstFSEventStreamRef streamRef, void *clientCallBackInfo, size_t numEvents, void *eventPaths, const FSEventStreamEventFlags eventFlags[], const FSEventStreamEventId eventIds[])
{
    PHPathWatcher* watcher = (__bridge PHPathWatcher*)clientCallBackInfo;
    [watcher fileChanged];
}

- (void) dealloc {
    if (self.stream) {
        FSEventStreamStop(self.stream);
        FSEventStreamInvalidate(self.stream);
        FSEventStreamRelease(self.stream);
    }
}

+ (PHPathWatcher*) watcherFor:(NSString*)path handler:(void(^)())handler {
    PHPathWatcher* watcher = [[PHPathWatcher alloc] init];
    watcher.handler = handler;
    [watcher setup:path];
    return watcher;
}

- (void) setup:(NSString*)path {
    FSEventStreamContext context;
    context.info = (__bridge void*)self;
    context.version = 0;
    context.retain = NULL;
    context.release = NULL;
    context.copyDescription = NULL;
    self.stream = FSEventStreamCreate(NULL,
                                      fsEventsCallback,
                                      &context,
                                      (__bridge CFArrayRef)@[[path stringByStandardizingPath]],
                                      kFSEventStreamEventIdSinceNow,
                                      0.4,
                                      kFSEventStreamCreateFlagWatchRoot | kFSEventStreamCreateFlagNoDefer | kFSEventStreamCreateFlagFileEvents);
    FSEventStreamScheduleWithRunLoop(self.stream, CFRunLoopGetCurrent(), kCFRunLoopDefaultMode);
    FSEventStreamStart(self.stream);
}

- (void) fileChanged {
    self.handler();
}

@end
