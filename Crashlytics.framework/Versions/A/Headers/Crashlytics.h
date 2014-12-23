//
//  Crashlytics.h
//  Crashlytics
//
//  Copyright 2013 Crashlytics, Inc. All rights reserved.
//

#import <Foundation/Foundation.h>

/**
 *
 * The CLS_LOG macro provides as easy way to gather more information in your log messages that are
 * sent with your crash data. CLS_LOG prepends your custom log message with the function name and
 * line number where the macro was used. If your app was built with the DEBUG preprocessor macro
 * defined CLS_LOG uses the CLSNSLog function which forwards your log message to NSLog and CLSLog.
 * If the DEBUG preprocessor macro is not defined CLS_LOG uses CLSLog only.
 *
 * Example output:
 * -[AppDelegate login:] line 134 $ login start
 *
 * If you would like to change this macro, create a new header file, unset our define and then define
 * your own version. Make sure this new header file is imported after the Crashlytics header file.
 *
 * #undef CLS_LOG
 * #define CLS_LOG(__FORMAT__, ...) CLSNSLog...
 *
 **/
#ifdef DEBUG
#define CLS_LOG(__FORMAT__, ...) CLSNSLog((@"%s line %d $ " __FORMAT__), __PRETTY_FUNCTION__, __LINE__, ##__VA_ARGS__)
#else
#define CLS_LOG(__FORMAT__, ...) CLSLog((@"%s line %d $ " __FORMAT__), __PRETTY_FUNCTION__, __LINE__, ##__VA_ARGS__)
#endif

/**
 *
 * Add logging that will be sent with your crash data. This logging will not show up in the system.log
 * and will only be visible in your Crashlytics dashboard.
 *
 **/
OBJC_EXTERN void CLSLog(NSString *format, ...) NS_FORMAT_FUNCTION(1,2);
OBJC_EXTERN void CLSLogv(NSString *format, va_list args) NS_FORMAT_FUNCTION(1,0);

/**
 *
 * Add logging that will be sent with your crash data. This logging will show up in the system.log
 * and your Crashlytics dashboard. It is not recommended for Release builds.
 *
 **/
OBJC_EXTERN void CLSNSLog(NSString *format, ...) NS_FORMAT_FUNCTION(1,2);
OBJC_EXTERN void CLSNSLogv(NSString *format, va_list args) NS_FORMAT_FUNCTION(1,0);


@protocol CrashlyticsDelegate;

@interface Crashlytics : NSObject

@property (nonatomic, readonly, copy) NSString *apiKey;
@property (nonatomic, readonly, copy) NSString *version;
@property (nonatomic, assign)         BOOL      debugMode;

@property (nonatomic, assign)         NSObject <CrashlyticsDelegate> *delegate;

/**
 *
 * The recommended way to install Crashlytics into your application is to place a call
 * to +startWithAPIKey: in your -application:didFinishLaunchingWithOptions: method.
 *
 * This delay defaults to 1 second in order to generally give the application time to
 * fully finish launching.
 *
 **/
+ (Crashlytics *)startWithAPIKey:(NSString *)apiKey;
+ (Crashlytics *)startWithAPIKey:(NSString *)apiKey afterDelay:(NSTimeInterval)delay;

/**
 *
 * If you need the functionality provided by the CrashlyticsDelegate protocol, you can use
 * these convenience methods to activate the framework and set the delegate in one call.
 *
 **/
+ (Crashlytics *)startWithAPIKey:(NSString *)apiKey delegate:(NSObject <CrashlyticsDelegate> *)delegate;
+ (Crashlytics *)startWithAPIKey:(NSString *)apiKey delegate:(NSObject <CrashlyticsDelegate> *)delegate afterDelay:(NSTimeInterval)delay;

/**
 *
 * Access the singleton Crashlytics instance.
 *
 **/
+ (Crashlytics *)sharedInstance;

/**
 *
 * The easiest way to cause a crash - great for testing!
 *
 **/
- (void)crash;

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
- (void)setUserIdentifier:(NSString *)identifier;
- (void)setUserName:(NSString *)name;
- (void)setUserEmail:(NSString *)email;

+ (void)setUserIdentifier:(NSString *)identifier;
+ (void)setUserName:(NSString *)name;
+ (void)setUserEmail:(NSString *)email;

/**
 *
 * Set a value for a key to be associated with your crash data.
 *
 **/
- (void)setObjectValue:(id)value forKey:(NSString *)key;
- (void)setIntValue:(int)value forKey:(NSString *)key;
- (void)setBoolValue:(BOOL)value forKey:(NSString *)key;
- (void)setFloatValue:(float)value forKey:(NSString *)key;

+ (void)setObjectValue:(id)value forKey:(NSString *)key;
+ (void)setIntValue:(int)value forKey:(NSString *)key;
+ (void)setBoolValue:(BOOL)value forKey:(NSString *)key;
+ (void)setFloatValue:(float)value forKey:(NSString *)key;

@end

/**
 * The CLSCrashReport protocol exposes methods that you can call on crash report objects passed
 * to delegate methods. If you want these values or the entire object to stay in memory retain
 * them or copy them.
 **/
@protocol CLSCrashReport <NSObject>
@required

/**
 * Returns the session identifier for the crash report.
 **/
@property (nonatomic, readonly) NSString *identifier;

/**
 * Returns the custom key value data for the crash report.
 **/
@property (nonatomic, readonly) NSDictionary *customKeys;

/**
 * Returns the CFBundleVersion of the application that crashed.
 **/
@property (nonatomic, readonly) NSString *bundleVersion;

/**
 * Returns the CFBundleShortVersionString of the application that crashed.
 **/
@property (nonatomic, readonly) NSString *bundleShortVersionString;

/**
 * Returns the date that the application crashed at.
 **/
@property (nonatomic, readonly) NSDate *crashedOnDate;

/**
 * Returns the os version that the application crashed on.
 **/
@property (nonatomic, readonly) NSString *OSVersion;

/**
 * Returns the os build version that the application crashed on.
 **/
@property (nonatomic, readonly) NSString *OSBuildVersion;

@end

/**
 *
 * The CrashlyticsDelegate protocol provides a mechanism for your application to take
 * action on events that occur in the Crashlytics crash reporting system.  You can make
 * use of these calls by assigning an object to the Crashlytics' delegate property directly,
 * or through the convenience startWithAPIKey:delegate:... methods.
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
- (void)crashlyticsDidDetectCrashDuringPreviousExecution:(Crashlytics *)crashlytics;

/**
 *
 * Just like crashlyticsDidDetectCrashDuringPreviousExecution this delegate method is
 * called once a Crashlytics instance has determined that the last execution of the
 * application ended in a crash. A CLSCrashReport is passed back that contains data about
 * the last crash report that was generated. See the CLSCrashReport protocol for method details.
 * This method is called after crashlyticsDidDetectCrashDuringPreviousExecution.
 *
 **/
- (void)crashlytics:(Crashlytics *)crashlytics didDetectCrashDuringPreviousExecution:(id <CLSCrashReport>)crash;

@end
