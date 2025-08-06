#import "SentryDefines.h"

NS_ASSUME_NONNULL_BEGIN

@protocol SentryCurrentDateProvider;

@interface SentryDateUtil : NSObject
SENTRY_NO_INIT

- (instancetype)initWithCurrentDateProvider:(id<SentryCurrentDateProvider>)currentDateProvider;

- (BOOL)isInFuture:(NSDate *_Nullable)date;

+ (NSDate *_Nullable)getMaximumDate:(NSDate *_Nullable)first andOther:(NSDate *_Nullable)second;

+ (long)millisecondsSince1970:(NSDate *)date;

@end

NS_ASSUME_NONNULL_END
