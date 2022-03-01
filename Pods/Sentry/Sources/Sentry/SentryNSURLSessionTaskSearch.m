/**
 * Part of this code was copied from
 * https://github.com/AFNetworking/AFNetworking/blob/4eaec5b586ddd897ebeda896e332a62a9fdab818/AFNetworking/AFURLSessionManager.m#L349-L418
https://github.com/AFNetworking/AFNetworking/blob/4eaec5b586ddd897ebeda896e332a62a9fdab818/LICENSE
 * under the MIT license
 */

#import "SentryNSURLSessionTaskSearch.h"
#import <objc/runtime.h>

@implementation SentryNSURLSessionTaskSearch

/**
 * WARNING: This code can easily lead to bad behavior, like crashes or messing up HTTP requests. Be
 * careful when changing it.
 */
+ (NSArray<Class> *)urlSessionTaskClassesToTrack
{

    /**
     * In order to be able to track a network request, we need to know when it starts and when it
     * finishes. NSURLSessionTask has a `resume` method that starts the request, and the only way to
     * know when it finishes is to check the task `state`. Using KVO is not working,
     * It randomly crashs an app. We hade two issues open because of this, #1328 and #1448. Instead
     * we are swizzling `setState:`. From iOS 10 to 13, NSURLSessionTask does not implement
     * `setState:` and Apple uses a subclass returned by NSURLSession that implementes `setState:`.
     * We need to discover which class to swizzle.
     *
     * Apples intermediate classes for iOS does not call [super resume], so we can swizzle both
     * classes. This Apple approach may change in the future, we need to have enough tests to detect
     * it early.
     */

    // WARNING START
    // This code is bulletproof. Don't think you are smart and can improve it.
    // It is tested and matured since 2015 in AFNetworking, see
    // https://github.com/AFNetworking/AFNetworking/blob/4eaec5b586ddd897ebeda896e332a62a9fdab818/AFNetworking/AFURLSessionManager.m#L382-L403
    NSURLSessionConfiguration *configuration =
        [NSURLSessionConfiguration ephemeralSessionConfiguration];
    NSURLSession *session = [NSURLSession sessionWithConfiguration:configuration];
#pragma GCC diagnostic push
#pragma GCC diagnostic ignored "-Wnonnull"
    NSURLSessionDataTask *localDataTask = [session dataTaskWithURL:nil];
#pragma clang diagnostic pop
    Class currentClass = [localDataTask class];
    NSMutableArray *result = [[NSMutableArray alloc] init];

    SEL setStateSelector = NSSelectorFromString(@"setState:");

    while (class_getInstanceMethod(currentClass, setStateSelector)) {
        Class superClass = [currentClass superclass];
        IMP classResumeIMP
            = method_getImplementation(class_getInstanceMethod(currentClass, setStateSelector));
        IMP superclassResumeIMP
            = method_getImplementation(class_getInstanceMethod(superClass, setStateSelector));
        if (classResumeIMP != superclassResumeIMP) {
            [result addObject:currentClass];
        }
        currentClass = [currentClass superclass];
    }

    [localDataTask cancel];
    [session finishTasksAndInvalidate];
    // WARNING END
    return [result copy];
}

@end
