//
//  MIKMIDIEvent_SubclassMethods.h
//  MIDI Files Testbed
//
//  Created by Jake Gundersen on 5/21/14.
//  Copyright (c) 2014 Mixed In Key. All rights reserved.
//

#import "MIKMIDIEvent.h"
#import "MIKMIDICompilerCompatibility.h"

NS_ASSUME_NONNULL_BEGIN

@interface MIKMIDIEvent ()

/**
 *  Registers a subclass of MIKMIDIEvent. Registered subclasses will be instantiated and returned
 *  by +[MIKMIDIEvent ] for events they support.
 *
 *  Typically this method should be called in the subclass's +load method.
 *
 *  @note If two subclasses support the same event type, as determined by calling +supportsMIDIEvent:
 *  which one is used is undefined.
 *
 *  @param subclass A subclass of MIKMIDIEvent.
 */
+ (void)registerSubclass:(Class)subclass;

/**
 *  Subclasses of MIKMIDIEvent must override this method, and return the MIKMIDIEventType
 *  values they support. MIKMIDIEvent uses this method to determine which
 *  subclass to use to represent a particular MIDI Event type.
 *
 *  Note that the older +supportsMIDIEventType: by default simply calls through to this method.
 *
 *  @return An NSArray of NSNumber instances containing MIKMIDIEventType values.
 */
+ (MIKArrayOf(NSNumber *) *)supportedMIDIEventTypes;

/**
 *  The immutable counterpart class of the receiver.
 *
 *  @return A class object for the immutable counterpart class of the receiver, or self
 *  if the receiver is the immutable class in the pair.
 */
+ (Class)immutableCounterpartClass;

/**
 *  The mutable counterpart class of the receiver.
 *
 *  @return A class object for the mutable counterpart class of the receiver, or self
 *  if the receiver is the mutable class in the pair.
 */
+ (Class)mutableCounterpartClass;

/**
 *  Mutable subclasses of MIKMIDIEvent must override this method and return YES.
 *  MIKMIDIEvent itself implements this and returns NO, so *immutable* subclasses need
 *  not override this method.
 *
 *  @return YES if the receiver is a mutable MIKMIDIEvent subclass, NO otherwise.
 */
+ (BOOL)isMutable;

/**
 *  Subclasses of MIKMIDIEvent can override this to provide initial "blank" data including any
 *  necessary fixed bytes for their class. For example, MIKMIDIChannelEvent subclasses return
 *  data with the first nibble set to the appropriate status/subtype for their class.
 *
 *  Overriding this method can also be used to ensure that the internal data for an empty event
 *  meets the required minimum length.
 *
 *  @return An NSData instance containing properly-sized blank/empty state data required by the receiver.
 *  Must NOT be nil (empty data is OK).
 */
+ (NSData *)initialData;

/**
 *  This is the property used internally by MIKMIDIEvent to store the raw data for
 *  a MIDI packet. It is essentially the mutable backing store for MIKMIDIEvent's
 *  data property. Subclasses may set it. When mutating it, subclasses should manually
 *  call -will/didChangeValueForKey for the internalData key path.
 */
@property (nonatomic, strong /* mutableCopy*/, readwrite) NSMutableData *internalData;

@property (nonatomic, readwrite) MusicTimeStamp timeStamp;

@property (nonatomic, readwrite) MIKMIDIEventType eventType;

/**
 *  Additional description string to be appended to basic description provided by
 *  -[MIKMIDIEvent description]. Subclasses of MIKMIDIEvent can override this
 *  to provide a additional description information.
 *
 *  @return A string to be appended to MIKMIDIEvent's basic description.
 */

- (NSString *)additionalEventDescription;

// Deprecated

/**
 *  @deprecated This method has been replaced by +supportedMIDIEventTypes
 *  and by default simply calls through to that method. Subclasses
 *  no longer need implement this.
 *
 *  @param type An MIKMIDIEventType value.
 *
 *  @return YES if the subclass supports type, NO otherwise.
 */
+ (BOOL)supportsMIKMIDIEventType:(MIKMIDIEventType)type DEPRECATED_ATTRIBUTE;

@end

NS_ASSUME_NONNULL_END