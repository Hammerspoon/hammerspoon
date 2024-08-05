#import "SentryStatsdClient.h"
#import "SentryClient+Private.h"
#import "SentryEnvelope.h"
#import "SentryEnvelopeItemHeader.h"
#import "SentryEnvelopeItemType.h"
#import "SentrySwift.h"

NS_ASSUME_NONNULL_BEGIN

@interface
SentryStatsdClient ()

@property (nonatomic, strong) SentryClient *client;

@end

@implementation SentryStatsdClient

- (instancetype)initWithClient:(SentryClient *)client
{
    if (self = [super init]) {
        self.client = client;
    }

    return self;
}

- (void)captureStatsdEncodedData:(NSData *)statsdEncodedData
{
    if (statsdEncodedData.length == 0) {
        return;
    }

    SentryEnvelopeItemHeader *header =
        [[SentryEnvelopeItemHeader alloc] initWithType:SentryEnvelopeItemTypeStatsd
                                                length:statsdEncodedData.length
                                           contentType:@"application/octet-stream"];

    SentryEnvelopeItem *item = [[SentryEnvelopeItem alloc] initWithHeader:header
                                                                     data:statsdEncodedData];

    SentryEnvelopeHeader *envelopeHeader =
        [[SentryEnvelopeHeader alloc] initWithId:[[SentryId alloc] init]];
    NSArray *items = @[ item ];
    SentryEnvelope *envelope = [[SentryEnvelope alloc] initWithHeader:envelopeHeader items:items];

    [self.client captureEnvelope:envelope];
}

@end

NS_ASSUME_NONNULL_END
