// each item type must have a data category name mapped to it; see SentryDataCategoryMapper

static NSString *const SentryEnvelopeItemTypeEvent = @"event";
static NSString *const SentryEnvelopeItemTypeSession = @"session";
static NSString *const SentryEnvelopeItemTypeUserFeedback = @"user_report";
static NSString *const SentryEnvelopeItemTypeTransaction = @"transaction";
static NSString *const SentryEnvelopeItemTypeAttachment = @"attachment";
static NSString *const SentryEnvelopeItemTypeClientReport = @"client_report";
static NSString *const SentryEnvelopeItemTypeProfile = @"profile";
static NSString *const SentryEnvelopeItemTypeReplayVideo = @"replay_video";
static NSString *const SentryEnvelopeItemTypeStatsd = @"statsd";
static NSString *const SentryEnvelopeItemTypeProfileChunk = @"profile_chunk";
