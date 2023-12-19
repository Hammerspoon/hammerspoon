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
     * finishes. @c NSURLSessionTask has a @c resume method that starts the request, and the only
     * way to know when it finishes is to check the task @c state. Using KVO is not working, It
     * randomly crashes an app. We had two issues open because of this, #1328 and #1448. Instead we
     * are swizzling @c setState:. From iOS 10 to 13, @c NSURLSessionTask does not implement
     * @c setState: and Apple uses a subclass returned by NSURLSession that implements @c setState:
     * . We need to discover which class to swizzle.
     *
     * Apple's intermediate classes for iOS does not call @c [super @c resume], so we can swizzle
     * both classes. This Apple approach may change in the future, we need to have enough tests to
     * detect it early.
     */

    // WARNING START
    // This code is bulletproof. Don't think you are smart and can improve it.
    // It is tested and matured since 2015 in AFNetworking, see
    // https://github.com/AFNetworking/AFNetworking/blob/4eaec5b586ddd897ebeda896e332a62a9fdab818/AFNetworking/AFURLSessionManager.m#L382-L403
    NSURLSessionConfiguration *configuration =
        [NSURLSessionConfiguration ephemeralSessionConfiguration];
    NSURLSession *session = [NSURLSession sessionWithConfiguration:configuration];

    // We dont use `localDataTask` as a task, we just need to know its class,
    // thats why the URL parameter is a empty url that points nowhere.
    // AFNetwork uses nil as parameter, but according to documentation this a nonnull parameter,
    // and when bridged to swift, the nil parameters causes an exception.
    NSURLSessionDataTask *localDataTask = [session dataTaskWithURL:[NSURL URLWithString:@""]];

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
