//
//  Crashlytics.h
//  Crashlytics
//
//  Copyright (c) 2015 Crashlytics, Inc. All rights reserved.
//

#import <Foundation/Foundation.h>

#import <Fabric/FABAttributes.h>
#import "CLSLogging.h"
#import "CLSReport.h"
#import "CLSStackFrame.h"

#define CLS_DEPRECATED(x)  __attribute__ ((deprecated(x)))

FAB_START_NONNULL

@protocol CrashlyticsDelegate;

@interface Crashlytics : NSObject

@property (nonatomic, readonly, copy) NSString *apiKey;
@property (nonatomic, readonly, copy) NSString *version;
@property (nonatomic, assign)         BOOL      debugMode;

/**
 *
 * The delegate can be used to influence decisions on reporting and behavior, as well as reacting
 * to previous crashes.
 *
 * Make certain that the delegate is setup before starting Crashlytics with startWithAPIKey:... or
 * via +[Fabric with:...]. Failure to do will result in missing any delegate callbacks that occur
 * synchronously during start.
 *
 **/
@property (nonatomic, assign)         id <CrashlyticsDelegate> FAB_NULLABLE delegate;

/**
 *
 * The recommended way to install Crashlytics into your application is to place a call
 * to +startWithAPIKey: in your -application:didFinishLaunchingWithOptions:/-applicationDidFinishLaunching:
 * method.
 *
 * Note: Starting with 3.0, the submission process has been significantly improved. The delay parameter
 * is no longer required to throttle submissions on launch, performance will be great without it.
 *
 **/
+ (Crashlytics *)startWithAPIKey:(NSString *)apiKey;
+ (Crashlytics *)startWithAPIKey:(NSString *)apiKey afterDelay:(NSTimeInterval)delay CLS_DEPRECATED("Crashlytics no longer needs or uses the delay parameter.  Please use +startWithAPIKey: instead.");

/**
 *
 * If you need the functionality provided by the CrashlyticsDelegate protocol, you can use
 * these convenience methods to activate the framework and set the delegate in one call.
 *
 **/
+ (Crashlytics *)startWithAPIKey:(NSString *)apiKey delegate:(id<CrashlyticsDelegate> FAB_NULLABLE)delegate;
+ (Crashlytics *)startWithAPIKey:(NSString *)apiKey delegate:(id<CrashlyticsDelegate> FAB_NULLABLE)delegate afterDelay:(NSTimeInterval)delay CLS_DEPRECATED("Crashlytics no longer needs or uses the delay parameter.  Please use +startWithAPIKey:delegate: instead.");

/**
 *
 * Access the singleton Crashlytics instance.
 *
 **/
+ (Crashlytics *)sharedInstance;

/**
 *
 * The easiest ways to cause a crash - great for testing!
 *
 **/
- (void)crash;
- (void)throwException;

/**
 *
 * Many of our customers have requested the ability to tie crashes to specific end-users of their
 * application in order to facilitate responses to support requests or permit the ability to reach
 * out for more information. We allow you to specify up to three separate values for display within
 * the Crashlytics UI - but please be mindful of your end-user's privacy.
 *
 * We recommend specifying a user identifier - an arbitrary string that ties an end-user to a record
 * in your system. This could be a database id, hash, or other value that is meaningless to a
 * third-party observer but can be indexed and queried by you.
 *
 * Optionally, you may also specify the end-user's name or username, as well as email address if you
 * do not have a system that works well with obscured identifiers.
 *
 * Pursuant to our EULA, this data is transferred securely throughout our system and we will not
 * disseminate end-user data unless required to by law. That said, if you choose to provide end-user
 * contact information, we strongly recommend that you disclose this in your application's privacy
 * policy. Data privacy is of our utmost concern.
 *
 **/
- (void)setUserIdentifier:(NSString * FAB_NULLABLE)identifier;
- (void)setUserName:(NSString * FAB_NULLABLE)name;
- (void)setUserEmail:(NSString * FAB_NULLABLE)email;

+ (void)setUserIdentifier:(NSString * FAB_NULLABLE)identifier CLS_DEPRECATED("Please access this method via +sharedInstance");
+ (void)setUserName:(NSString * FAB_NULLABLE)name CLS_DEPRECATED("Please access this method via +sharedInstance");
+ (void)setUserEmail:(NSString * FAB_NULLABLE)email CLS_DEPRECATED("Please access this method via +sharedInstance");

/**
 *
 * Set a value for a key to be associated with your crash data. When setting an object value, the object
 * is converted to a string. This is typically done by calling -[NSObject description].
 *
 **/
- (void)setObjectValue:(id FAB_NULLABLE)value forKey:(NSString *)key;
- (void)setIntValue:(int)value forKey:(NSString *)key;
- (void)setBoolValue:(BOOL)value forKey:(NSString *)key;
- (void)setFloatValue:(float)value forKey:(NSString *)key;

+ (void)setObjectValue:(id FAB_NULLABLE)value forKey:(NSString *)key CLS_DEPRECATED("Please access this method via +sharedInstance");
+ (void)setIntValue:(int)value forKey:(NSString *)key CLS_DEPRECATED("Please access this method via +sharedInstance");
+ (void)setBoolValue:(BOOL)value forKey:(NSString *)key CLS_DEPRECATED("Please access this method via +sharedInstance");
+ (void)setFloatValue:(float)value forKey:(NSString *)key CLS_DEPRECATED("Please access this method via +sharedInstance");

/**
 *
 * This method can be used to record a single exception structure in a report. This is particularly useful
 * when your code interacts with non-native languages like Lua, C#, or Javascript. This call can be
 # expensive and should only be used shortly before process termination. This API is not intended be to used
 * to log NSException objects. All safely-reportable NSExceptions are automatically captured by
 * Crashlytics.
 *
 * The frameArray argument should contain only CLSStackFrame instances.
 *
 **/
- (void)recordCustomExceptionName:(NSString *)name reason:(NSString * FAB_NULLABLE)reason frameArray:(NSArray *)frameArray;



/**
 * In Beta. Sign up at http://answers.io/labs to get on the list!
 *
 * @brief Log an event to be sent to Answers.
 * @param eventName The event name as it will be shown in the dashboard.
 * @discussion Example usage:
 * @code [CrashlyticsKit logEvent:@"Tweet Viewed"];
 *
 */
- (void)logEvent:(NSString *)eventName;

/**
 * In Beta. Sign up at http://answers.io/labs to get on the list!
 *
 * @brief Log an event to be sent to Answers, optionally providing a dictionary of attributes. Attribute keys
 *        must be <code>NSString</code> and and values must be <code>NSNumber</code> or <code>NSString</code>.
 * @param eventName  The event name as it will be shown in the dashboard.
 * @param attributes An NSDictionary with keys of type <code>NSString</code>, and values of type <code>NSNumber</code>
 *                   or <code>NSString</code>. There may be at most 20 attributes for a particular event.
 * @discussion How we treat <code>NSNumber</code>:
 *             We will provide information about the distribution of values over time.
 *
 *             How we treat <code>NSStrings</code>:
 *             NSStrings are used as categorical data, allowing comparison across different category values.
 *             Strings are limited to a maximum length of 100 characters, attributes over this length will be
 *             truncated.
 *
 *             When tracking the Tweet views to better understand user engagement, sending the tweet's length
 *             and the type of media present in the tweet allows you to track how tweet length and the type of media influence
 *             engagement.
 *             Example usage:
 * @code [CrashlyticsKit logEvent:@"Tweet Viewed" attributes:@{
 *       @"Media Type": @"Image",
 *       @"Length": @120
 * }];
 */
- (void)logEvent:(NSString *)eventName attributes:(NSDictionary * FAB_NULLABLE) attributes;

+ (void)logEvent:(NSString *)eventName CLS_DEPRECATED("Please refer to -logEvent:");
+ (void)logEvent:(NSString *)eventName attributes:(NSDictionary * FAB_NULLABLE) attributes CLS_DEPRECATED("Please refer to -logEvent:attributes:");
@end

/**
 *
 * The CrashlyticsDelegate protocol provides a mechanism for your application to take
 * action on events that occur in the Crashlytics crash reporting system.  You can make
 * use of these calls by assigning an object to the Crashlytics' delegate property directly,
 * or through the convenience +startWithAPIKey:delegate: method.
 *
 **/
@protocol CrashlyticsDelegate <NSObject>
@optional

/**
 *
 * Called once a Crashlytics instance has determined that the last execution of the
 * application ended in a crash.  This is called some time after the crash reporting
 * process has begun.  If you have specified a delay in one of the
 * startWithAPIKey:... calls, this will take at least that long to be invoked.
 *
 **/
- (void)crashlyticsDidDetectCrashDuringPreviousExecution:(Crashlytics *)crashlytics CLS_DEPRECATED("Please refer to -crashlyticsDidDetectReportForLastExecution:");

/**
 *
 * Just like crashlyticsDidDetectCrashDuringPreviousExecution this delegate method is
 * called once a Crashlytics instance has determined that the last execution of the
 * application ended in a crash. A CLSCrashReport is passed back that contains data about
 * the last crash report that was generated. See the CLSCrashReport protocol for method details.
 * This method is called after crashlyticsDidDetectCrashDuringPreviousExecution.
 *
 **/
- (void)crashlytics:(Crashlytics *)crashlytics didDetectCrashDuringPreviousExecution:(id <CLSCrashReport>)crash CLS_DEPRECATED("Please refer to -crashlyticsDidDetectReportForLastExecution:");

/**
 *
 * Called when a Crashlytics instance has determined that the last execution of the
 * application ended in a crash.  This is called synchronously on Crashlytics
 * initialization. Your delegate must invoke the completionHandler, but does not need to do so 
 * synchronously, or even on the main thread. Invoking completionHandler with NO will cause the
 * detected report to be deleted and not submitted to Crashlytics. This is useful for
 * implementing permission prompts, or other more-complex forms of logic around submitting crashes.
 *
 * Failure to invoke the completionHandler will prevent submissions from being reported. Watch out.
 * 
 * Just implementing this delegate method will disable all forms of synchronous report submission. This can
 * impact the reliability of reporting crashes very early in application launch.
 *
 **/

- (void)crashlyticsDidDetectReportForLastExecution:(CLSReport *)report completionHandler:(void (^)(BOOL submit))completionHandler;

/**
 *
 * If your app is running on an OS that supports it (OS X 10.9+, iOS 7.0+), Crashlytics will submit
 * most reports using out-of-process background networking operations. This results in a significant
 * improvement in reliability of reporting, as well as power and performance wins for your users.
 * If you don't want this functionality, you can disable by returning NO from this method.
 *
 * Note: background submission is not supported for extensions on iOS or OS X.
 *
 **/
- (BOOL)crashlyticsCanUseBackgroundSessions:(Crashlytics *)crashlytics;

@end

/**
 *  `CrashlyticsKit` can be used as a parameter to `[Fabric with:@[CrashlyticsKit]];` in Objective-C. In Swift, use Crashlytics.sharedInstance()
 */
#define CrashlyticsKit [Crashlytics sharedInstance]

FAB_END_NONNULL
