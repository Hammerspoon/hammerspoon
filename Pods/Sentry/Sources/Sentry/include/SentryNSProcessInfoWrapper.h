#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@interface SentryNSProcessInfoWrapper : NSObject

@property (nonatomic, readonly) NSString *processDirectoryPath;
@property (nullable, nonatomic, readonly) NSString *processPath;
@property (readonly) NSUInteger processorCount;
@property (readonly) NSProcessInfoThermalState thermalState;
@property (readonly) NSDictionary<NSString *, NSString *> *environment;

#if defined(SENTRY_TEST) || defined(SENTRY_TEST_CI) || defined(DEBUG)
- (void)setProcessPath:(NSString *)path;
#endif // defined(SENTRY_TEST) || defined(SENTRY_TEST_CI) || defined(DEBUG)

@end

NS_ASSUME_NONNULL_END
