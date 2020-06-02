#import <Foundation/Foundation.h>

@class SentryEvent;

NS_ASSUME_NONNULL_BEGIN

@interface SentryCrashReportConverter : NSObject

@property(nonatomic, strong) NSDictionary *userContext;

- (instancetype)initWithReport:(NSDictionary *)report;

- (SentryEvent *)convertReportToEvent;

@end

NS_ASSUME_NONNULL_END
