#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@interface SentryNSProcessInfoWrapper : NSObject

@property (nonatomic, readonly) NSString *processDirectoryPath;
@property (nullable, nonatomic, readonly) NSString *processPath;
@property (readonly) NSUInteger processorCount;
@property (readonly) NSProcessInfoThermalState thermalState;
@property (readonly) NSDictionary<NSString *, NSString *> *environment;
@property (readonly)
    BOOL isiOSAppOnMac API_AVAILABLE(macos(11.0), ios(14.0), watchos(7.0), tvos(14.0));
@property (readonly)
    BOOL isMacCatalystApp API_AVAILABLE(macos(10.15), ios(13.0), watchos(6.0), tvos(13.0));

#if defined(SENTRY_TEST) || defined(SENTRY_TEST_CI) || defined(DEBUG)
- (void)setProcessPath:(NSString *)path;
#endif // defined(SENTRY_TEST) || defined(SENTRY_TEST_CI) || defined(DEBUG)

@end

NS_ASSUME_NONNULL_END
