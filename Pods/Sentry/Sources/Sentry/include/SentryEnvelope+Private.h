#import "SentryAttachment+Private.h"
#import "SentryEnvelope.h"
#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@interface
SentryEnvelopeItem (Private)

- (instancetype)initWithClientReport:(SentryClientReport *)clientReport;

@end

NS_ASSUME_NONNULL_END
