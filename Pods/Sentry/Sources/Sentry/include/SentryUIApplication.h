#import "SentryDefines.h"

#if SENTRY_HAS_UIKIT

@class UIApplication;
@class UIScene;
@class UIWindow;
@class UIViewController;
@protocol UIApplicationDelegate;

typedef NS_ENUM(NSInteger, UIApplicationState);

NS_ASSUME_NONNULL_BEGIN

/**
 * A helper tool to retrieve informations from the application instance.
 */
@interface SentryUIApplication : NSObject

/**
 * Returns the application state available at @c NSApplication.sharedApplication.applicationState
 */
@property (nonatomic, readonly) UIApplicationState applicationState;

/**
 * All application open windows.
 */
@property (nonatomic, readonly, nullable) NSArray<UIWindow *> *windows;

/**
 * Retrieves the application delegate for given UIApplication
 */
- (nullable id<UIApplicationDelegate>)getApplicationDelegate:(UIApplication *)application;

/**
 * Retrieves connected scenes for given UIApplication
 */
- (NSArray<UIScene *> *)getApplicationConnectedScenes:(UIApplication *)application
    API_AVAILABLE(ios(13.0), tvos(13.0));

/**
 * Use @c [SentryUIApplication relevantViewControllers] and convert the
 * result to a string array with the class name of each view controller.
 */
- (nullable NSArray<NSString *> *)relevantViewControllersNames;

@end

NS_ASSUME_NONNULL_END

#endif // SENTRY_HAS_UIKIT
