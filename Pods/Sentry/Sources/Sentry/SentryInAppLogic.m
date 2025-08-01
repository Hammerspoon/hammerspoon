#import "SentryInAppLogic.h"
#import "SentryLogC.h"
#import <objc/runtime.h>

NS_ASSUME_NONNULL_BEGIN

@interface SentryInAppLogic ()

@property (nonnull, readonly) NSArray<NSString *> *inAppExcludes;

@end

@implementation SentryInAppLogic

- (instancetype)initWithInAppIncludes:(NSArray<NSString *> *)inAppIncludes
                        inAppExcludes:(NSArray<NSString *> *)inAppExcludes
{
    if (self = [super init]) {
        NSMutableArray<NSString *> *includes =
            [[NSMutableArray alloc] initWithCapacity:inAppIncludes.count];
        for (NSString *include in inAppIncludes) {
            [includes addObject:include.lowercaseString];
        }
        _inAppIncludes = includes;

        NSMutableArray<NSString *> *excludes =
            [[NSMutableArray alloc] initWithCapacity:inAppExcludes.count];
        for (NSString *exclude in inAppExcludes) {
            [excludes addObject:exclude.lowercaseString];
        }
        _inAppExcludes = excludes;
    }

    return self;
}

- (BOOL)isInApp:(nullable NSString *)imageName
{
    if (nil == imageName) {
        return NO;
    }

    NSString *imageNameLastPathComponent = imageName.lastPathComponent.lowercaseString;

    for (NSString *inAppInclude in self.inAppIncludes) {
        if ([SentryInAppLogic isImageNameLastPathComponentInApp:imageNameLastPathComponent
                                                   inAppInclude:inAppInclude])

            return YES;
    }

    for (NSString *inAppExclude in self.inAppExcludes) {
        if ([imageNameLastPathComponent hasPrefix:inAppExclude])
            return NO;
    }

    return NO;
}

- (BOOL)isClassInApp:(Class)targetClass
{
    const char *imageName = class_getImageName(targetClass);
    if (imageName == nil)
        return NO;

    NSString *classImageName = [NSString stringWithCString:imageName encoding:NSUTF8StringEncoding];
    return [self isInApp:classImageName];
}

+ (BOOL)isImageNameInApp:(NSString *)imageName inAppInclude:(NSString *)inAppInclude
{
    return [SentryInAppLogic
        isImageNameLastPathComponentInApp:imageName.lastPathComponent.lowercaseString
                             inAppInclude:inAppInclude.lowercaseString];
}

+ (BOOL)isImageNameLastPathComponentInApp:(NSString *)imageNameLastPathComponent
                             inAppInclude:(NSString *)inAppInclude
{
    return [imageNameLastPathComponent hasPrefix:inAppInclude];
}

@end

NS_ASSUME_NONNULL_END
