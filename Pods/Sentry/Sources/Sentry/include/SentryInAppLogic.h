#import "SentryDefines.h"
#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

/**
 * This class detects whether a framework belongs to the app or not. We differentiate between three
 * different types of frameworks.
 *
 * First, the main executable of the app, which's name can be retrieved by CFBundleExecutable. To
 * mark this framework as inApp the caller needs to pass in the CFBundleExecutable to InAppIncludes.
 *
 * Next, there are private frameworks embedded in the application bundle. Both app supporting
 * frameworks as CocoaLumberJack, Sentry, RXSwift, etc., and frameworks written by the user fall
 * into this category. These frameworks can be both inApp or not. As we expect most frameworks of
 * this category to be supporting frameworks, we mark them not as inApp. If a user wants such a
 * framework to be inApp, they need to pass the name into inAppInclude. For dynamic frameworks, the
 * location is usually in the bundle under /Frameworks/FrameworkName.framework/FrameworkName. As for
 * static frameworks, the location is the same as the main executable; this class marks all static
 * frameworks as inApp. To remove static frameworks from being inApp, Sentry uses stack trace
 * grouping rules on the server.
 *
 * Last, this class marks all public frameworks as not inApp. Such frameworks are bound dynamically
 * and are usually located at /Library/Frameworks or ~/Library/Frameworks. For simulators, the
 * location can be something like
 * /Applications/Xcode.app/Contents/Developer/Platforms/iPhoneOS.platform/Library/Developer/CoreSimulator/Profiles/Runtimes/iOS.simruntime/Contents/Resources/RuntimeRoot/System/Library/...
 *
 */
@interface SentryInAppLogic : NSObject
SENTRY_NO_INIT

/**
 * Initializes SentryInAppLogic with inAppIncludes and inAppExcludes.
 *
 * To work properly for Apple applications the inAppIncludes should contain the CFBundleExecutable,
 * which is the name of the bundle’s executable file.
 *
 * @param inAppIncludes A list of string prefixes of framework names that belong to the app. This
 * option takes precedence over inAppExcludes.
 * @param inAppExcludes A list of string prefixes of framework names that do not belong to the app,
 * but rather to third-party packages. Modules considered not part of the app will be hidden from
 * stack traces by default.
 */
- (instancetype)initWithInAppIncludes:(NSArray<NSString *> *)inAppIncludes
                        inAppExcludes:(NSArray<NSString *> *)inAppExcludes;

/**
 * Determines if the framework belongs to the app by using inAppIncludes and inAppExcludes. Before
 * checking this method lowercases the strings and uses only the lastPathComponent of the imagePath.
 *
 * @param imagePath the full path of the binary image.
 *
 * @return YES if the framework located at the imagePath starts with a prefix of inAppIncludes. NO
 * if the framework located at the imagePath doesn't start with a prefix of inAppIncludes or start
 * with a prefix of inAppExcludes.
 */
- (BOOL)isInApp:(nullable NSString *)imagePath;

@end

NS_ASSUME_NONNULL_END
