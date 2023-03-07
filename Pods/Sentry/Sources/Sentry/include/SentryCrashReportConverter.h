#import <Foundation/Foundation.h>

@class SentryEvent, SentryInAppLogic;

NS_ASSUME_NONNULL_BEGIN

@interface SentryCrashReportConverter : NSObject

@property (nonatomic, strong) NSDictionary *userContext;

- (instancetype)initWithReport:(NSDictionary *)report inAppLogic:(SentryInAppLogic *)inAppLogic;

/**
 * Converts the report to an SentryEvent.
 *
 * @return The converted event or nil if an error occurred during the conversion.
 */
- (SentryEvent *_Nullable)convertReportToEvent;

@end

NS_ASSUME_NONNULL_END
