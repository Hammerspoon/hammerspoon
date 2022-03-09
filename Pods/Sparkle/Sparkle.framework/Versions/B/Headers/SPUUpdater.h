//
//  SPUUpdater.h
//  Sparkle
//
//  Created by Andy Matuschak on 1/4/06.
//  Copyright 2006 Andy Matuschak. All rights reserved.
//

#if __has_feature(modules)
#if __has_warning("-Watimport-in-framework-header")
#pragma clang diagnostic ignored "-Watimport-in-framework-header"
#endif
@import Foundation;
#else
#import <Foundation/Foundation.h>
#endif
#import <Sparkle/SUExport.h>
#import <Sparkle/SPUUserDriver.h>

NS_ASSUME_NONNULL_BEGIN

@class SUAppcastItem, SUAppcast;

@protocol SPUUpdaterDelegate;

/**
 The main API in Sparkle for controlling the update mechanism.

 This class is used to configure the update parameters as well as manually and automatically schedule and control checks for updates.
 
 For convenience, you can create a standard or nib instantiable updater by using `SPUStandardUpdaterController`.
 
 Prefer to set initial properties in your bundle's Info.plist as described in [Customizing Sparkle](https://sparkle-project.org/documentation/customization/).
 
 Otherwise only if you need dynamic behavior (eg. for user preferences) should you set properties on the updater such as:
 - `automaticallyChecksForUpdates`
 - `updateCheckInterval`
 - `automaticallyDownloadsUpdates`
 - `feedURL`
 
 Please view the documentation on each of these properties for more detail if you are to configure them dynamically.
 */
SU_EXPORT @interface SPUUpdater : NSObject

/**
 Initializes a new `SPUUpdater` instance
 
 This creates an updater, but to start it and schedule update checks `-startUpdater:` needs to be invoked first.
 
 Related: See `SPUStandardUpdaterController` which wraps a `SPUUpdater` instance and is suitable for instantiating inside of nib files.
 
 @param hostBundle The bundle that should be targetted for updating.
 @param applicationBundle The application bundle that should be waited for termination and relaunched (unless overridden). Usually this can be the same as hostBundle. This may differ when updating a plug-in or other non-application bundle.
 @param userDriver The user driver that Sparkle uses for user update interaction.
 @param delegate The delegate for `SPUUpdater`.
 */
- (instancetype)initWithHostBundle:(NSBundle *)hostBundle applicationBundle:(NSBundle *)applicationBundle userDriver:(id <SPUUserDriver>)userDriver delegate:(nullable id<SPUUpdaterDelegate>)delegate;

/**
 Use `-initWithHostBundle:applicationBundle:userDriver:delegate:` or `SPUStandardUpdaterController` standard adapter instead.
 
 If you want to drop an updater into a nib, use `SPUStandardUpdaterController`.
 */
- (instancetype)init NS_UNAVAILABLE;

/**
 Starts the updater.

 This method first checks if Sparkle is configured properly. A valid feed URL should be set before this method is invoked.

 If the configuration is valid, an update cycle is started in the next main runloop cycle.
 During this cycle, a permission prompt may be brought up (if needed) for checking if the user wants automatic update checking.
 Otherwise if automatic update checks are enabled, a scheduled update alert may be brought up if enough time has elapsed since the last check.
 See `automaticallyChecksForUpdates` for more information.

 After starting the updater and before the next runloop cycle, one of `-checkForUpdates`, `-checkForUpdatesInBackground`, or `-checkForUpdateInformation` can be invoked.
 This may be useful if you want to check for updates immediately or without showing a potential permission prompt.
 
 If the updater cannot be started (i.e, due to a configuration issue in the application), you may want to fall back appropriately.
 For example, the standard updater controller (`SPUStandardUpdaterController`) alerts the user that the app is misconfigured and to contact the developer.

 This must be called on the main thread.

 @param error The error that is populated if this method fails. Pass NULL if not interested in the error information.
 @return YES if the updater started otherwise NO with a populated error
 */
- (BOOL)startUpdater:(NSError * __autoreleasing *)error;

/**
 Checks for updates, and displays progress while doing so if needed.
 
 This is meant for users initiating a new update check or checking the current update progress.
 
 If an update hasn't started, the user may be shown that a new check for updates is occurring.
 If an update has already been downloaded or begun installing from a previous session, the user may be presented to install that update.
 If the user is already being presented with an update, that update will be shown to the user in active focus.
 
 This will find updates that the user has previously opted into skipping.
 
 See `canCheckForUpdates` property which can determine when this method may be invoked.
 */
- (void)checkForUpdates;

/**
 Checks for updates, but does not display any UI unless an update is found.
 
 You usually do not need to call this method directly. If `automaticallyChecksForUpdates` is @c YES,
 Sparkle calls this method automatically according to its update schedule using the `updateCheckInterval`
 and the `lastUpdateCheckDate`.
 
 This is meant for programmatically initating a check for updates.
 That is, it will display no UI unless it finds an update, in which case it proceeds as usual.
 This will not find updates that the user has opted into skipping.
 
 Note if there is no resumable update found, and automated updating is turned on,
 the update will be downloaded in the background without disrupting the user.
 
 This method does not do anything if there is a `sessionInProgress`.
 */
- (void)checkForUpdatesInBackground;

/**
 Begins a "probing" check for updates which will not actually offer to
 update to that version.
 
 However, the delegate methods
 `-[SPUUpdaterDelegate updater:didFindValidUpdate:]` and
 `-[SPUUpdaterDelegate updaterDidNotFindUpdate:]` will be called,
 so you can use that information in your UI.
 
 `-[SPUUpdaterDelegate updater:didFinishUpdateCycleForUpdateCheck:error:]` will be called when
 this probing check is completed.
 
 Updates that have been skipped by the user will not be found.
 
 This method does not do anything if there is a `sessionInProgress`.
 */
- (void)checkForUpdateInformation;

/**
 A property indicating whether or not updates can be checked by the user.
 
 An update check can be made by the user when an update session isn't in progress, or when an update or its progress is being shown to the user.
 A user cannot check for updates when data (such as the feed or an update) is still being downloaded automatically in the background.
 
 This property is suitable to use for menu item validation for seeing if `-checkForUpdates` can be invoked.
 
 This property is also KVO-compliant.
 
 Note this property does not reflect whether or not an update session is in progress. Please see `sessionInProgress` property instead.
 */
@property (nonatomic, readonly) BOOL canCheckForUpdates;

/**
 A property indicating whether or not an update session is in progress.
 
 An update session is in progress when the appcast is being downloaded, an update is being downloaded,
 an update is being shown, update permission is being requested, or the installer is being started.
 
 An active session is when Sparkle's fired scheduler is running.
 
 Note an update session may not be running even though Sparkle's installer (ran as a separate process) may be running,
 or even though the update has been downloaded but the installation has been deferred. In both of these cases, a new update session
 may be activated with the update resumed at a later point (automatically or manually).
 
 See also:
 - `canCheckForUpdates` property which is more suited for menu item validation and deciding if the user can initiate update checks.
 -  `-[SPUUpdaterDelegate updater:didFinishUpdateCycleForUpdateCheck:error:]` which lets the updater delegate know when an update cycle and session finishes.
 */
@property (nonatomic, readonly) BOOL sessionInProgress;

/**
 A property indicating whether or not to check for updates automatically.
 
 By default, Sparkle asks users on second launch for permission if they want automatic update checks enabled
 and sets this property based on their response. If `SUEnableAutomaticChecks` is set in the Info.plist,
 this permission request is not performed however.
 
 Setting this property will persist in the host bundle's user defaults.
 Only set this property if you need dynamic behavior (e.g. user preferences).
 
 The update schedule cycle will be reset in a short delay after the property's new value is set.
 This is to allow reverting this property without kicking off a schedule change immediately
 */
@property (nonatomic) BOOL automaticallyChecksForUpdates;

/**
 A property indicating the current automatic update check interval in seconds.
 
 Setting this property will persist in the host bundle's user defaults.
 For this reason, only set this property if you need dynamic behavior (eg user preferences).
 Otherwise prefer to set SUScheduledCheckInterval directly in your Info.plist.
 
 The update schedule cycle will be reset in a short delay after the property's new value is set.
 This is to allow reverting this property without kicking off a schedule change immediately
 */
@property (nonatomic) NSTimeInterval updateCheckInterval;

/**
 A property indicating whether or not updates can be automatically downloaded in the background.
 
 By default, updates are not automatically downloaded.
 
 Note that the developer can disallow automatic downloading of updates from being enabled.
 In this case, this property will return NO regardless of how this property is set.
 
 Setting this property will persist in the host bundle's user defaults.
 For this reason, only set this property if you need dynamic behavior (eg user preferences).
 Otherwise prefer to set SUAutomaticallyUpdate directly in your Info.plist.
 */
@property (nonatomic) BOOL automaticallyDownloadsUpdates;

/**
 The URL of the appcast used to download update information.
 
 If the updater's delegate implements `-[SPUUpdaterDelegate feedURLStringForUpdater:]`, this will return that feed URL.
 Otherwise if the feed URL has been set before, the feed URL returned will be retrieved from the host bundle's user defaults.
 Otherwise the feed URL in the host bundle's Info.plist will be returned.
 If no feed URL can be retrieved, returns nil.
 
 This property must be called on the main thread; calls from background threads will return nil.
 */
@property (nonatomic, readonly, nullable) NSURL *feedURL;

/**
 Set the URL of the appcast used to download update information. Using this method is discouraged.
 
 Setting this property will persist in the host bundle's user defaults.
 To avoid this, you should consider implementing
 `-[SPUUpdaterDelegate feedURLStringForUpdater:]` instead of using this method.
 
 Passing nil will remove any feed URL that has been set in the host bundle's user defaults.
 If you do not need to alternate between multiple feeds, set the SUFeedURL in your Info.plist instead of invoking this method.
 
 For beta updates, you may consider migrating to `-[SPUUpdaterDelegate allowedChannelsForUpdater:]` in the future.
 
 This method must be called on the main thread; calls from background threads will have no effect.
 */
- (void)setFeedURL:(nullable NSURL *)feedURL;

/**
 The host bundle that is being updated.
 */
@property (nonatomic, readonly) NSBundle *hostBundle;

/**
 The user agent used when checking for updates.
 
 By default the user agent string returned is in the format:
 $(BundleDisplayName)/$(BundleDisplayVersion) Sparkle/$(SparkleDisplayVersion)
 
 BundleDisplayVersion is derived from the main application's Info.plist's CFBundleShortVersionString.
 
 Note if Sparkle is being used to update another application, the bundle information retrieved is from the main application performing the updating.
 
 This default implementation can be overrided.
 */
@property (nonatomic, copy) NSString *userAgentString;

/**
 The HTTP headers used when checking for updates, downloading release notes, and downloading updates.
 
 The keys of this dictionary are HTTP header fields and values are corresponding values.
 */
@property (nonatomic, copy, nullable) NSDictionary<NSString *, NSString *> *httpHeaders;

/**
 A property indicating whether or not the user's system profile information is sent when checking for updates.

 Setting this property will persist in the host bundle's user defaults.
 */
@property (nonatomic) BOOL sendsSystemProfile;

/**
 The date of the last update check or nil if no check has been performed yet.
 
 For testing purposes, the last update check is stored in the `SULastCheckTime` key in the host bundle's user defaults.
 For example, `defaults delete my-bundle-id SULastCheckTime` can be invoked to clear the last update check time and test
 if update checks are automatically scheduled.
 */
@property (nonatomic, readonly, copy, nullable) NSDate *lastUpdateCheckDate;

/**
 Appropriately schedules or cancels the update checking timer according to the preferences for time interval and automatic checks.

 If you change the `updateCheckInterval` or `automaticallyChecksForUpdates` properties, the update cycle will be reset automatically after a short delay.
 The update cycle is also started automatically after the updater is started. In all these cases, this method should not be called directly.
 
 This call does not change the date of the next check, but only the internal timer.
 */
- (void)resetUpdateCycle;


/**
 The system profile information that is sent when checking for updates.
 */
@property (nonatomic, readonly, copy) NSArray<NSDictionary<NSString *, NSString *> *> *systemProfileArray;

@end

NS_ASSUME_NONNULL_END
