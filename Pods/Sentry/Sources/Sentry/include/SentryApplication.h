#import "SentryDefines.h"
#import <Foundation/Foundation.h>

@protocol SentryApplication;

#if SENTRY_HAS_UIKIT
@class UIApplication;
@class UIScene;
@class UIWindow;
@class UIViewController;
@protocol UIApplicationDelegate;

#    import <UIKit/UIKit.h>
#endif

typedef NS_ENUM(NSInteger, UIApplicationState);

NS_ASSUME_NONNULL_BEGIN

/**
 * Protocol used to provide cross-platform access to the application.
 */
@protocol SentryApplication

// MARK: - Shared methods

- (BOOL)isActive;

// MARK: - UIKit-specific methods

#if SENTRY_HAS_UIKIT
/**
 * Returns the application state available at @c UIApplication.sharedApplication.applicationState
 */
@property (nonatomic, readonly) UIApplicationState applicationState;

/**
 * All windows connected to scenes.
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
#endif // SENTRY_HAS_UIKIT

@end

NS_ASSUME_NONNULL_END
