#import "SentryDataCategoryMapper.h"
#import "SentryDataCategory.h"
#import "SentryEnvelopeItemType.h"

// While these data categories names might look similar to the envelope item types, they are not
// identical, and have slight differences. Just open them side by side and you'll see the
// differences.
NSString *const kSentryDataCategoryNameAll = @"";
NSString *const kSentryDataCategoryNameDefault = @"default";
NSString *const kSentryDataCategoryNameError = @"error";
NSString *const kSentryDataCategoryNameSession = @"session";
NSString *const kSentryDataCategoryNameTransaction = @"transaction";
NSString *const kSentryDataCategoryNameAttachment = @"attachment";
#if !SDK_V9
NSString *const kSentryDataCategoryNameUserFeedback = @"user_report";
#endif // !SSDK_v9
NSString *const kSentryDataCategoryNameProfile = @"profile";
NSString *const kSentryDataCategoryNameProfileChunk = @"profile_chunk_ui";
NSString *const kSentryDataCategoryNameReplay = @"replay";
NSString *const kSentryDataCategoryNameMetricBucket = @"metric_bucket";
NSString *const kSentryDataCategoryNameSpan = @"span";
NSString *const kSentryDataCategoryNameFeedback = @"feedback";
NSString *const kSentryDataCategoryNameUnknown = @"unknown";

NS_ASSUME_NONNULL_BEGIN

SentryDataCategory
sentryDataCategoryForEnvelopItemType(NSString *itemType)
{
    if ([itemType isEqualToString:SentryEnvelopeItemTypeEvent]) {
        return kSentryDataCategoryError;
    }
    if ([itemType isEqualToString:SentryEnvelopeItemTypeSession]) {
        return kSentryDataCategorySession;
    }
    if ([itemType isEqualToString:SentryEnvelopeItemTypeTransaction]) {
        return kSentryDataCategoryTransaction;
    }
    if ([itemType isEqualToString:SentryEnvelopeItemTypeAttachment]) {
        return kSentryDataCategoryAttachment;
    }
    if ([itemType isEqualToString:SentryEnvelopeItemTypeProfile]) {
        return kSentryDataCategoryProfile;
    }
    if ([itemType isEqualToString:SentryEnvelopeItemTypeProfileChunk]) {
        return kSentryDataCategoryProfileChunk;
    }
    if ([itemType isEqualToString:SentryEnvelopeItemTypeReplayVideo]) {
        return kSentryDataCategoryReplay;
    }
    if ([itemType isEqualToString:SentryEnvelopeItemTypeFeedback]) {
        return kSentryDataCategoryFeedback;
    }
    // The envelope item type used for metrics is statsd whereas the client report category for
    // discarded events is metric_bucket.
    if ([itemType isEqualToString:SentryEnvelopeItemTypeStatsd]) {
        return kSentryDataCategoryMetricBucket;
    }

    return kSentryDataCategoryDefault;
}

SentryDataCategory
sentryDataCategoryForNSUInteger(NSUInteger value)
{
    if (value < 0 || value > kSentryDataCategoryUnknown) {
        return kSentryDataCategoryUnknown;
    }

    return (SentryDataCategory)value;
}

SentryDataCategory
sentryDataCategoryForString(NSString *value)
{
    if ([value isEqualToString:kSentryDataCategoryNameAll]) {
        return kSentryDataCategoryAll;
    }
    if ([value isEqualToString:kSentryDataCategoryNameDefault]) {
        return kSentryDataCategoryDefault;
    }
    if ([value isEqualToString:kSentryDataCategoryNameError]) {
        return kSentryDataCategoryError;
    }
    if ([value isEqualToString:kSentryDataCategoryNameSession]) {
        return kSentryDataCategorySession;
    }
    if ([value isEqualToString:kSentryDataCategoryNameTransaction]) {
        return kSentryDataCategoryTransaction;
    }
    if ([value isEqualToString:kSentryDataCategoryNameAttachment]) {
        return kSentryDataCategoryAttachment;
    }
#if !SDK_V9
    if ([value isEqualToString:kSentryDataCategoryNameUserFeedback]) {
        return kSentryDataCategoryUserFeedback;
    }
#endif // !SDK_V9
    if ([value isEqualToString:kSentryDataCategoryNameProfile]) {
        return kSentryDataCategoryProfile;
    }
    if ([value isEqualToString:kSentryDataCategoryNameProfileChunk]) {
        return kSentryDataCategoryProfileChunk;
    }
    if ([value isEqualToString:kSentryDataCategoryNameReplay]) {
        return kSentryDataCategoryReplay;
    }
    if ([value isEqualToString:kSentryDataCategoryNameMetricBucket]) {
        return kSentryDataCategoryMetricBucket;
    }
    if ([value isEqualToString:kSentryDataCategoryNameSpan]) {
        return kSentryDataCategorySpan;
    }
    if ([value isEqualToString:kSentryDataCategoryNameFeedback]) {
        return kSentryDataCategoryFeedback;
    }

    return kSentryDataCategoryUnknown;
}

NSString *
nameForSentryDataCategory(SentryDataCategory category)
{
    switch (category) {
    case kSentryDataCategoryAll:
        return kSentryDataCategoryNameAll;

    case kSentryDataCategoryDefault:
        return kSentryDataCategoryNameDefault;
    case kSentryDataCategoryError:
        return kSentryDataCategoryNameError;
    case kSentryDataCategorySession:
        return kSentryDataCategoryNameSession;
    case kSentryDataCategoryTransaction:
        return kSentryDataCategoryNameTransaction;
    case kSentryDataCategoryAttachment:
        return kSentryDataCategoryNameAttachment;
#if !SDK_V9
    case kSentryDataCategoryUserFeedback:
        return kSentryDataCategoryNameUserFeedback;
#endif // !SDK_V9
    case kSentryDataCategoryProfile:
        return kSentryDataCategoryNameProfile;
    case kSentryDataCategoryProfileChunk:
        return kSentryDataCategoryNameProfileChunk;
    case kSentryDataCategoryMetricBucket:
        return kSentryDataCategoryNameMetricBucket;
    case kSentryDataCategoryReplay:
        return kSentryDataCategoryNameReplay;
    case kSentryDataCategorySpan:
        return kSentryDataCategoryNameSpan;
    case kSentryDataCategoryFeedback:
        return kSentryDataCategoryNameFeedback;

    default: // !!!: fall-through!
    case kSentryDataCategoryUnknown:
        return kSentryDataCategoryNameUnknown;
    }
}

NS_ASSUME_NONNULL_END
