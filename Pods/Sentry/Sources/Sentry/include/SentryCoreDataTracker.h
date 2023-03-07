
#import "SentryCoreDataSwizzling.h"
#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

static NSString *const SENTRY_COREDATA_FETCH_OPERATION = @"db.sql.query";
static NSString *const SENTRY_COREDATA_SAVE_OPERATION = @"db.sql.transaction";

@interface SentryCoreDataTracker : NSObject <SentryCoreDataMiddleware>

@end

NS_ASSUME_NONNULL_END
