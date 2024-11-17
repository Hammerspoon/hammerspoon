#import "SentryStacktrace.h"
#import "NSMutableDictionary+Sentry.h"
#import "SentryFrame.h"
#import "SentryLog.h"

NS_ASSUME_NONNULL_BEGIN

@implementation SentryStacktrace

- (instancetype)initWithFrames:(NSArray<SentryFrame *> *)frames
                     registers:(NSDictionary<NSString *, NSString *> *)registers
{
    self = [super init];
    if (self) {
        self.registers = registers;
        self.frames = frames;
    }
    return self;
}

/**
 * This function fixes duplicate frames and removes the first duplicate
 * https://github.com/kstenerud/KSCrash/blob/05cdc801cfc578d256f85de2e72ec7877cbe79f8/Source/KSCrash/Recording/Tools/KSStackCursor_MachineContext.c#L84
 */
- (void)fixDuplicateFrames
{
    if (self.frames.count < 2 || nil == self.registers) {
        return;
    }

    SentryFrame *lastFrame = self.frames.lastObject;
    SentryFrame *beforeLastFrame = [self.frames objectAtIndex:self.frames.count - 2];

    if ([lastFrame.symbolAddress isEqualToString:beforeLastFrame.symbolAddress] &&
        [self.registers[@"lr"] isEqualToString:beforeLastFrame.instructionAddress]) {
        NSMutableArray *copyFrames = self.frames.mutableCopy;
        [copyFrames removeObjectAtIndex:self.frames.count - 2];
        self.frames = copyFrames;
        SENTRY_LOG_DEBUG(@"Found duplicate frame, removing one with link register");
    }
}

- (NSDictionary<NSString *, id> *)serialize
{
    NSMutableDictionary *serializedData = [NSMutableDictionary new];

    NSMutableArray *frames = [NSMutableArray new];
    for (SentryFrame *frame in self.frames) {
        NSDictionary *serialized = [frame serialize];
        if (serialized.allKeys.count > 0) {
            [frames addObject:[frame serialize]];
        }
    }
    if (frames.count > 0) {
        [serializedData setValue:frames forKey:@"frames"];
    }
    // This is here because we wanted to be conform with the old json
    if (self.registers.count > 0) {
        [serializedData setValue:self.registers forKey:@"registers"];
    }

    [SentryDictionary setBoolValue:self.snapshot forKey:@"snapshot" intoDictionary:serializedData];
    return serializedData;
}

@end

NS_ASSUME_NONNULL_END
