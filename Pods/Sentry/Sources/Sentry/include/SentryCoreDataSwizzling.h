
#import "SentryDefines.h"
#import <CoreData/CoreData.h>
#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@class SentryCoreDataTracker;

@interface SentryCoreDataSwizzling : NSObject
SENTRY_NO_INIT

@property (class, readonly, nonatomic) SentryCoreDataSwizzling *sharedInstance;

@property (nonatomic, readonly, nullable) SentryCoreDataTracker *coreDataTracker;

- (void)startWithTracker:(SentryCoreDataTracker *)coreDataTracker;

- (void)stop;

@end

NS_ASSUME_NONNULL_END
