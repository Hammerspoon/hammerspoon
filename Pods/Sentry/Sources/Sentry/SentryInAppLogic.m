#import "SentryInAppLogic.h"
#import <Foundation/Foundation.h>
#import <objc/runtime.h>

NS_ASSUME_NONNULL_BEGIN

@implementation SentryInAppLogic

- (instancetype)initWithInAppIncludes:(NSArray<NSString *> *)inAppIncludes
                        inAppExcludes:(NSArray<NSString *> *)inAppExcludes
{
    if (self = [super init]) {
        _inAppIncludes = inAppIncludes;
        _inAppExcludes = inAppExcludes;
    }

    return self;
}

- (BOOL)isInApp:(nullable NSString *)imageName
{
    if (nil == imageName) {
        return NO;
    }

    for (NSString *inAppInclude in self.inAppIncludes) {
        if ([SentryInAppLogic isImageNameInApp:imageName inAppInclude:inAppInclude])
            return YES;
    }

    for (NSString *inAppExlude in self.inAppExcludes) {
        if ([imageName.lastPathComponent.lowercaseString hasPrefix:inAppExlude.lowercaseString])
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
    return [imageName.lastPathComponent.lowercaseString hasPrefix:inAppInclude.lowercaseString];
}

@end

NS_ASSUME_NONNULL_END
