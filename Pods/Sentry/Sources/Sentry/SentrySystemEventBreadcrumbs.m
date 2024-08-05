#import "SentrySystemEventBreadcrumbs.h"
#import "SentryBreadcrumb.h"
#import "SentryBreadcrumbDelegate.h"
#import "SentryDefines.h"
#import "SentryDependencyContainer.h"
#import "SentryLog.h"
#import "SentryNSNotificationCenterWrapper.h"
#import "SentrySwift.h"

#if TARGET_OS_IOS && SENTRY_HAS_UIKIT

#    import <UIKit/UIKit.h>

@interface
SentrySystemEventBreadcrumbs ()
@property (nonatomic, weak) id<SentryBreadcrumbDelegate> delegate;
@property (nonatomic, strong) SentryFileManager *fileManager;
@property (nonatomic, strong) SentryNSNotificationCenterWrapper *notificationCenterWrapper;
@end

@implementation SentrySystemEventBreadcrumbs

- (instancetype)initWithFileManager:(SentryFileManager *)fileManager
       andNotificationCenterWrapper:(SentryNSNotificationCenterWrapper *)notificationCenterWrapper
{
    if (self = [super init]) {
        _fileManager = fileManager;
        _notificationCenterWrapper = notificationCenterWrapper;
    }
    return self;
}

- (void)startWithDelegate:(id<SentryBreadcrumbDelegate>)delegate
{
    UIDevice *currentDevice = [UIDevice currentDevice];
    [self startWithDelegate:delegate currentDevice:currentDevice];
}

- (void)stop
{
    // Remove the observers with the most specific detail possible, see
    // https://developer.apple.com/documentation/foundation/nsnotificationcenter/1413994-removeobserver
    [self.notificationCenterWrapper removeObserver:self name:UIKeyboardDidShowNotification];
    [self.notificationCenterWrapper removeObserver:self name:UIKeyboardDidHideNotification];
    [self.notificationCenterWrapper removeObserver:self
                                              name:UIApplicationUserDidTakeScreenshotNotification];
    [self.notificationCenterWrapper removeObserver:self
                                              name:UIDeviceBatteryLevelDidChangeNotification];
    [self.notificationCenterWrapper removeObserver:self
                                              name:UIDeviceBatteryStateDidChangeNotification];
    [self.notificationCenterWrapper removeObserver:self
                                              name:UIDeviceOrientationDidChangeNotification];
    [self.notificationCenterWrapper removeObserver:self
                                              name:UIDeviceOrientationDidChangeNotification];
}

- (void)dealloc
{
    // In dealloc it's safe to unsubscribe for all, see
    // https://developer.apple.com/documentation/foundation/nsnotificationcenter/1413994-removeobserver
    [self.notificationCenterWrapper removeObserver:self];
}

/**
 * Only used for testing, call startWithDelegate instead.
 */
- (void)startWithDelegate:(id<SentryBreadcrumbDelegate>)delegate
            currentDevice:(nullable UIDevice *)currentDevice
{
    _delegate = delegate;
    if (currentDevice != nil) {
        [self initBatteryObserver:currentDevice];
        [self initOrientationObserver:currentDevice];
    } else {
        SENTRY_LOG_DEBUG(@"currentDevice is null, it won't be able to record breadcrumbs for "
                         @"device battery and orientation.");
    }
    [self initKeyboardVisibilityObserver];
    [self initScreenshotObserver];
    [self initTimezoneObserver];
}

- (void)initBatteryObserver:(UIDevice *)currentDevice
{
    if (currentDevice.batteryMonitoringEnabled == NO) {
        currentDevice.batteryMonitoringEnabled = YES;
    }

    // Posted when the battery level changes.
    [self.notificationCenterWrapper addObserver:self
                                       selector:@selector(batteryStateChanged:)
                                           name:UIDeviceBatteryLevelDidChangeNotification
                                         object:currentDevice];

    // Posted when battery state changes.
    [self.notificationCenterWrapper addObserver:self
                                       selector:@selector(batteryStateChanged:)
                                           name:UIDeviceBatteryStateDidChangeNotification
                                         object:currentDevice];
}

- (void)batteryStateChanged:(NSNotification *)notification
{
    // Notifications for battery level change are sent no more frequently than once per minute
    UIDevice *currentDevice = notification.object;
    // The object of an NSNotification may be nil.
    if (currentDevice == nil) {
        SENTRY_LOG_DEBUG(
            @"UIDevice of NSNotification was nil. Won't create battery changed breadcrumb.");
        return;
    }

    NSDictionary<NSString *, id> *batteryData = [self getBatteryStatus:notification.object];

    SentryBreadcrumb *crumb = [[SentryBreadcrumb alloc] initWithLevel:kSentryLevelInfo
                                                             category:@"device.event"];
    crumb.type = @"system";
    crumb.data = batteryData;
    [_delegate addBreadcrumb:crumb];
}

- (NSDictionary<NSString *, id> *)getBatteryStatus:(UIDevice *)currentDevice
{
    // borrowed and adapted from
    // https://github.com/apache/cordova-plugin-battery-status/blob/master/src/ios/CDVBattery.m
    UIDeviceBatteryState currentState = [currentDevice batteryState];

    BOOL isPlugged = NO; // UIDeviceBatteryStateUnknown or UIDeviceBatteryStateUnplugged
    if ((currentState == UIDeviceBatteryStateCharging)
        || (currentState == UIDeviceBatteryStateFull)) {
        isPlugged = YES;
    }
    float currentLevel = [currentDevice batteryLevel];
    NSMutableDictionary<NSString *, id> *batteryData =
        [NSMutableDictionary dictionaryWithCapacity:3];

    // W3C spec says level must be null if it is unknown
    if ((currentState != UIDeviceBatteryStateUnknown) && (currentLevel != -1.0)) {
        float w3cLevel = (currentLevel * 100);
        batteryData[@"level"] = @(w3cLevel);
    } else {
        SENTRY_LOG_DEBUG(@"batteryLevel is unknown.");
    }

    batteryData[@"plugged"] = @(isPlugged);
    batteryData[@"action"] = @"BATTERY_STATE_CHANGE";

    return batteryData;
}

- (void)initOrientationObserver:(UIDevice *)currentDevice
{
    if (currentDevice.isGeneratingDeviceOrientationNotifications == NO) {
        [currentDevice beginGeneratingDeviceOrientationNotifications];
    }

    // Posted when the orientation of the device changes.
    [self.notificationCenterWrapper addObserver:self
                                       selector:@selector(orientationChanged:)
                                           name:UIDeviceOrientationDidChangeNotification
                                         object:currentDevice];
}

- (void)orientationChanged:(NSNotification *)notification
{
    UIDevice *currentDevice = notification.object;
    SentryBreadcrumb *crumb = [[SentryBreadcrumb alloc] initWithLevel:kSentryLevelInfo
                                                             category:@"device.orientation"];

    UIDeviceOrientation currentOrientation = currentDevice.orientation;

    // Ignore changes in device orientation if unknown, face up, or face down.
    if (!UIDeviceOrientationIsValidInterfaceOrientation(currentOrientation)) {
        SENTRY_LOG_DEBUG(@"currentOrientation is unknown.");
        return;
    }

    if (UIDeviceOrientationIsLandscape(currentOrientation)) {
        crumb.data = @{ @"position" : @"landscape" };
    } else {
        crumb.data = @{ @"position" : @"portrait" };
    }
    crumb.type = @"navigation";
    [_delegate addBreadcrumb:crumb];
}

- (void)initKeyboardVisibilityObserver
{
    // Posted immediately after the display of the keyboard.
    [self.notificationCenterWrapper addObserver:self
                                       selector:@selector(systemEventTriggered:)
                                           name:UIKeyboardDidShowNotification];

    // Posted immediately after the dismissal of the keyboard.
    [self.notificationCenterWrapper addObserver:self
                                       selector:@selector(systemEventTriggered:)
                                           name:UIKeyboardDidHideNotification];
}

- (void)systemEventTriggered:(NSNotification *)notification
{
    SentryBreadcrumb *crumb = [[SentryBreadcrumb alloc] initWithLevel:kSentryLevelInfo
                                                             category:@"device.event"];
    crumb.type = @"system";
    crumb.data = @{ @"action" : notification.name };
    [_delegate addBreadcrumb:crumb];
}

- (void)initScreenshotObserver
{
    // it's only about the action, but not the SS itself
    [self.notificationCenterWrapper addObserver:self
                                       selector:@selector(systemEventTriggered:)
                                           name:UIApplicationUserDidTakeScreenshotNotification];
}

- (void)initTimezoneObserver
{
    // Detect if the stored timezone is different from the current one;
    // if so, then we also send a breadcrumb
    NSNumber *_Nullable storedTimezoneOffset = [self.fileManager readTimezoneOffset];

    if (storedTimezoneOffset == nil) {
        [self updateStoredTimezone];
    } else if (storedTimezoneOffset.doubleValue
        != SentryDependencyContainer.sharedInstance.dateProvider.timezoneOffset) {
        [self timezoneEventTriggered:storedTimezoneOffset];
    }

    // Posted when the timezone of the device changed
    [self.notificationCenterWrapper addObserver:self
                                       selector:@selector(timezoneEventTriggered)
                                           name:NSSystemTimeZoneDidChangeNotification];
}

- (void)timezoneEventTriggered
{
    [self timezoneEventTriggered:nil];
}

- (void)timezoneEventTriggered:(NSNumber *)storedTimezoneOffset
{
    if (storedTimezoneOffset == nil) {
        storedTimezoneOffset = [self.fileManager readTimezoneOffset];
    }

    SentryBreadcrumb *crumb = [[SentryBreadcrumb alloc] initWithLevel:kSentryLevelInfo
                                                             category:@"device.event"];

    NSInteger offset = SentryDependencyContainer.sharedInstance.dateProvider.timezoneOffset;

    crumb.type = @"system";

    NSMutableDictionary *dataDict =
        [@{ @"action" : @"TIMEZONE_CHANGE", @"current_seconds_from_gmt" : @(offset) } mutableCopy];

    if (storedTimezoneOffset != nil) {
        dataDict[@"previous_seconds_from_gmt"] = storedTimezoneOffset;
    }

    crumb.data = dataDict;
    [_delegate addBreadcrumb:crumb];

    [self updateStoredTimezone];
}

- (void)updateStoredTimezone
{
    [self.fileManager
        storeTimezoneOffset:SentryDependencyContainer.sharedInstance.dateProvider.timezoneOffset];
}

@end

#endif // TARGET_OS_IOS && SENTRY_HAS_UIKIT
