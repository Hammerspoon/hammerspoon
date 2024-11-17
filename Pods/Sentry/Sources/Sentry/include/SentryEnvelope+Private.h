#import "SentryEnvelope.h"

NS_ASSUME_NONNULL_BEGIN

@class SentryReplayEvent;
@class SentryReplayRecording;
@class SentryClientReport;

@interface
SentryEnvelopeItem ()

- (instancetype)initWithClientReport:(SentryClientReport *)clientReport;

- (nullable instancetype)initWithReplayEvent:(SentryReplayEvent *)replayEvent
                             replayRecording:(SentryReplayRecording *)replayRecording
                                       video:(NSURL *)videoURL;

@end

NS_ASSUME_NONNULL_END
