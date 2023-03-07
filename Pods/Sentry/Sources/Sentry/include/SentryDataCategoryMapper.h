#import "SentryDataCategory.h"
#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

FOUNDATION_EXPORT NSString *const kSentryDataCategoryNameAll;
FOUNDATION_EXPORT NSString *const kSentryDataCategoryNameDefault;
FOUNDATION_EXPORT NSString *const kSentryDataCategoryNameError;
FOUNDATION_EXPORT NSString *const kSentryDataCategoryNameSession;
FOUNDATION_EXPORT NSString *const kSentryDataCategoryNameTransaction;
FOUNDATION_EXPORT NSString *const kSentryDataCategoryNameAttachment;
FOUNDATION_EXPORT NSString *const kSentryDataCategoryNameUserFeedback;
FOUNDATION_EXPORT NSString *const kSentryDataCategoryNameProfile;
FOUNDATION_EXPORT NSString *const kSentryDataCategoryNameUnknown;

SentryDataCategory sentryDataCategoryForNSUInteger(NSUInteger value);

SentryDataCategory sentryDataCategoryForString(NSString *value);

SentryDataCategory sentryDataCategoryForEnvelopItemType(NSString *itemType);

NSString *nameForSentryDataCategory(SentryDataCategory category);

NS_ASSUME_NONNULL_END
