#import "SentryDefines.h"
#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

/**
 * This class detects whether a framework belongs to the app or not. We differentiate between three
 * different types of frameworks.
 *
 * First, the main executable of the app, which's name can be retrieved by @c CFBundleExecutable. To
 * mark this framework as "in-app" the caller needs to pass in the @c CFBundleExecutable to
 * @c inAppIncludes.
 *
 * Next, there are private frameworks embedded in the application bundle. Both app supporting
 * frameworks as CocoaLumberJack, Sentry, RXSwift, etc., and frameworks written by the user fall
 * into this category. These frameworks can be both "in-app" or not. As we expect most frameworks of
 * this category to be supporting frameworks, we mark them not as "in-app". If a user wants such a
 * framework to be "in-app", they need to pass the name into @c inAppIncludes. For dynamic
 * frameworks, the location is usually in the bundle under
 * /Frameworks/FrameworkName.framework/FrameworkName. As for static frameworks, the location is the
 * same as the main executable; this class marks all static frameworks as "in-app". To remove static
 * frameworks from being "in-app", Sentry uses stack trace grouping rules on the server.
 *
 * Last, this class marks all public frameworks as not "in-app". Such frameworks are bound
 * dynamically and are usually located at /Library/Frameworks or ~/Library/Frameworks. For
 * simulators, the location can be something like
 * /Applications/Xcode.app/Contents/Developer/Platforms/iPhoneOS.platform/Library/Developer/CoreSimulator/Profiles/Runtimes/iOS.simruntime/Contents/Resources/RuntimeRoot/System/Library/...
 *
 */
@interface SentryInAppLogic : NSObject
SENTRY_NO_INIT

@property (nonnull, readonly) NSArray<NSString *> *inAppIncludes;

@property (nonnull, readonly) NSArray<NSString *> *inAppExcludes;

/**
 * Initializes @c SentryInAppLogic with @c inAppIncludes and @c inAppExcludes.
 *
 * To work properly for Apple applications the @c inAppIncludes should contain the
 * @c CFBundleExecutable, which is the name of the bundle’s executable file.
 *
 * @param inAppIncludes A list of string prefixes of framework names that belong to the app. This
 * option takes precedence over @c inAppExcludes.
 * @param inAppExcludes A list of string prefixes of framework names that do not belong to the app,
 * but rather to third-party packages. Modules considered not part of the app will be hidden from
 * stack traces by default.
 */
- (instancetype)initWithInAppIncludes:(NSArray<NSString *> *)inAppIncludes
                        inAppExcludes:(NSArray<NSString *> *)inAppExcludes;

/**
 * Determines if the framework belongs to the app by using @c inAppIncludes and @c inAppExcludes.
 * Before checking this method lowercases the strings and uses only the @c lastPathComponent of the
 * @c imagePath.
 *
 * @param imagePath the full path of the binary image.
 *
 * @return @c YES if the framework located at the @c imagePath starts with a prefix of
 * @c inAppIncludes. @c NO if the framework located at the @c imagePath doesn't start with a prefix
 * of
 * @c inAppIncludes or start with a prefix of @c inAppExcludes.
 */
- (BOOL)isInApp:(nullable NSString *)imagePath;

/**
 * Determines if the class belongs to the app by getting its framework and checking with
 * @c -[isInApp:]
 *
 * @param targetClass the class to check.
 *
 * @return @c YES if the @c targetClass belongs to a framework included in @c inAppIncludes.
 * @c NO if targetClass does not belong to a framework in @c inAppIncludes or belongs to a framework
 * in
 * @c inAppExcludes.
 */
- (BOOL)isClassInApp:(Class)targetClass;

+ (BOOL)isImageNameInApp:(NSString *)imageName inAppInclude:(NSString *)inAppInclude;

@end

NS_ASSUME_NONNULL_END
