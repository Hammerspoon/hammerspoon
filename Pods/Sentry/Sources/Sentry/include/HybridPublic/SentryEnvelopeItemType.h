// each item type must have a data category name mapped to it; see SentryDataCategoryMapper

// While these envelope item types might look similar to the data categories, they are not
// identical, and have slight differences. Just open them side by side and you'll see the
// differences.
static NSString *const SentryEnvelopeItemTypeEvent = @"event";
static NSString *const SentryEnvelopeItemTypeSession = @"session";
#if !SDK_V9
static NSString *const SentryEnvelopeItemTypeUserFeedback = @"user_report";
#endif // !SDK_V9
static NSString *const SentryEnvelopeItemTypeFeedback = @"feedback";
static NSString *const SentryEnvelopeItemTypeTransaction = @"transaction";
static NSString *const SentryEnvelopeItemTypeAttachment = @"attachment";
static NSString *const SentryEnvelopeItemTypeClientReport = @"client_report";
static NSString *const SentryEnvelopeItemTypeProfile = @"profile";
static NSString *const SentryEnvelopeItemTypeReplayVideo = @"replay_video";
static NSString *const SentryEnvelopeItemTypeStatsd = @"statsd";
static NSString *const SentryEnvelopeItemTypeProfileChunk = @"profile_chunk";
