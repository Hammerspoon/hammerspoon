#import <Foundation/Foundation.h>

#if TARGET_OS_OSX

@interface SentryCrashExceptionApplicationHelper : NSObject
+ (void)reportException:(NSException *)exception;
+ (void)_crashOnException:(NSException *)exception;
@end
#endif
