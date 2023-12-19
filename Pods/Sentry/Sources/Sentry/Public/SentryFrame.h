#import <Foundation/Foundation.h>

#import "SentrySerializable.h"

NS_ASSUME_NONNULL_BEGIN

NS_SWIFT_NAME(Frame)
@interface SentryFrame : NSObject <SentrySerializable>

/**
 * SymbolAddress of the frame
 */
@property (nonatomic, copy) NSString *_Nullable symbolAddress;

/**
 * Filename is used only for reporting JS frames
 */
@property (nonatomic, copy) NSString *_Nullable fileName;

/**
 * Function name of the frame
 */
@property (nonatomic, copy) NSString *_Nullable function;

/**
 * Module of the frame, mostly unused
 */
@property (nonatomic, copy) NSString *_Nullable module;

/**
 * Corresponding package
 */
@property (nonatomic, copy) NSString *_Nullable package;

/**
 * ImageAddress if the image related to the frame
 */
@property (nonatomic, copy) NSString *_Nullable imageAddress;

/**
 * Set the platform for the individual frame, will use platform of the event.
 * Mostly used for react native crashes.
 */
@property (nonatomic, copy) NSString *_Nullable platform;

/**
 * InstructionAddress of the frame hex format
 */
@property (nonatomic, copy) NSString *_Nullable instructionAddress;

/**
 * InstructionAddress of the frame
 */
@property (nonatomic) NSUInteger instruction;

/**
 * User for react native, will be ignored for cocoa frames
 */
@property (nonatomic, copy) NSNumber *_Nullable lineNumber;

/**
 * User for react native, will be ignored for cocoa frames
 */
@property (nonatomic, copy) NSNumber *_Nullable columnNumber;

/**
 * Determines if the Frame is inApp or not
 */
@property (nonatomic, copy) NSNumber *_Nullable inApp;

/**
 * Determines if the Frame is the base of an async continuation.
 */
@property (nonatomic, copy) NSNumber *_Nullable stackStart;

- (instancetype)init;
+ (instancetype)new NS_UNAVAILABLE;

@end

NS_ASSUME_NONNULL_END
