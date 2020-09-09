#import "SentryAsynchronousOperation.h"

NS_ASSUME_NONNULL_BEGIN

@interface
SentryAsynchronousOperation ()

@property (nonatomic, getter=isCancelled, readwrite) BOOL cancelled;
@property (nonatomic, getter=isFinished, readwrite) BOOL finished;
@property (nonatomic, getter=isExecuting, readwrite) BOOL executing;

@end

@implementation SentryAsynchronousOperation

@synthesize cancelled = _cancelled;
@synthesize finished = _finished;
@synthesize executing = _executing;

- (id)init
{
    self = [super init];
    if (self) {
        _finished = NO;
        _executing = NO;
        _cancelled = NO;
    }
    return self;
}

- (void)start
{
    if ([self isCancelled]) {
        self.finished = YES;
        return;
    }

    self.executing = YES;

    [self main];
}

- (void)cancel
{
    self.executing = NO;
    self.finished = YES;
    self.cancelled = YES;
}

- (void)completeOperation
{
    self.executing = NO;
    self.finished = YES;
}

#pragma mark - NSOperation methods

- (BOOL)isAsynchronous
{
    return YES;
}

- (BOOL)isExecuting
{
    @synchronized(self) {
        return _executing;
    }
}

- (BOOL)isFinished
{
    @synchronized(self) {
        return _finished;
    }
}

- (BOOL)isCancelled
{
    @synchronized(self) {
        return _cancelled;
    }
}

- (void)setCancelled:(BOOL)cancelled
{
    if (_cancelled != cancelled) {
        [self willChangeValueForKey:@"isCancelled"];
        @synchronized(self) {
            _cancelled = cancelled;
        }
        [self didChangeValueForKey:@"isCancelled"];
    }
}

- (void)setExecuting:(BOOL)executing
{
    if (_executing != executing) {
        [self willChangeValueForKey:@"isExecuting"];
        @synchronized(self) {
            _executing = executing;
        }
        [self didChangeValueForKey:@"isExecuting"];
    }
}

- (void)setFinished:(BOOL)finished
{
    [self willChangeValueForKey:@"isFinished"];
    @synchronized(self) {
        if (_finished != finished) {
            _finished = finished;
        }
    }
    [self didChangeValueForKey:@"isFinished"];
}

@end

NS_ASSUME_NONNULL_END
