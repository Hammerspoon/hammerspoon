//
//  MIKMIDIEvent.h
//  MIDI Files Testbed
//
//  Created by Jake Gundersen on 5/21/14.
//  Copyright (c) 2014 Mixed In Key. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <AudioToolbox/AudioToolbox.h>
#import "MIKMIDICompilerCompatibility.h"

/**
 *  Types of MIDI events. These values are used to determine which subclass to
 *  instantiate when creating a new MIDI event.
 *
 *  @note These are similar, but do not directly correspond to the values of MusicEventType
 */
typedef NS_ENUM(NSUInteger, MIKMIDIEventType)
{
    MIKMIDIEventTypeNULL = kMusicEventType_NULL,
	MIKMIDIEventTypeExtendedNote = kMusicEventType_ExtendedNote,
	MIKMIDIEventTypeExtendedTempo = kMusicEventType_ExtendedTempo,
	MIKMIDIEventTypeUser = kMusicEventType_User,
	MIKMIDIEventTypeMeta = kMusicEventType_Meta, /* See subtypes below */
	MIKMIDIEventTypeMIDINoteMessage = kMusicEventType_MIDINoteMessage,
	MIKMIDIEventTypeMIDIChannelMessage = kMusicEventType_MIDIChannelMessage, /* See subtypes below */
	MIKMIDIEventTypeMIDIRawData = kMusicEventType_MIDIRawData,
	MIKMIDIEventTypeParameter = kMusicEventType_Parameter,
	MIKMIDIEventTypeAUPreset = kMusicEventType_AUPreset,
	
	
	// Channel Message subtypes
	MIKMIDIEventTypeMIDIPolyphonicKeyPressureMessage,
	MIKMIDIEventTypeMIDIControlChangeMessage,
	MIKMIDIEventTypeMIDIProgramChangeMessage,
	MIKMIDIEventTypeMIDIChannelPressureMessage,
	MIKMIDIEventTypeMIDIPitchBendChangeMessage,
	
	
	// Meta subtypes
    MIKMIDIEventTypeMetaSequence,
    MIKMIDIEventTypeMetaText,
    MIKMIDIEventTypeMetaCopyright,
    MIKMIDIEventTypeMetaTrackSequenceName,
    MIKMIDIEventTypeMetaInstrumentName,
    MIKMIDIEventTypeMetaLyricText,
    MIKMIDIEventTypeMetaMarkerText,
    MIKMIDIEventTypeMetaCuePoint,
    MIKMIDIEventTypeMetaMIDIChannelPrefix,
    MIKMIDIEventTypeMetaEndOfTrack,
    MIKMIDIEventTypeMetaTempoSetting,
    MIKMIDIEventTypeMetaSMPTEOffset,
    MIKMIDIEventTypeMetaTimeSignature,
    MIKMIDIEventTypeMetaKeySignature,
    MIKMIDIEventTypeMetaSequenceSpecificEvent,
	
#if !TARGET_OS_IPHONE
	// Deprecated, and unsupported. Unavailable on iOS.
	MIKMIDIEventTypeExtendedControl = kMusicEventType_ExtendedControl,
#endif
};

typedef NS_ENUM(NSUInteger, MIKMIDIChannelEventType)
{
	MIKMIDIChannelEventTypePolyphonicKeyPressure        = 0xA0,
	MIKMIDIChannelEventTypeControlChange				= 0xB0,
	MIKMIDIChannelEventTypeProgramChange				= 0xC0,
	MIKMIDIChannelEventTypeChannelPressure				= 0xD0,
	MIKMIDIChannelEventTypePitchBendChange				= 0xE0,
};

NS_ASSUME_NONNULL_BEGIN

/**
 *  In MIKMIDI, MIDI events are objects. Specifically, they are instances of MIKMIDIEvent or one of its
 *  subclasses. MIKMIDIEvent's subclasses each represent a specific type of MIDI event, for example,
 *  note events will be instances of MIKMIDINoteEvent.
 *  MIKMIDIEvent includes properties for getting information and data common to all MIDI events.
 *  Its subclasses implement additional method and properties specific to messages of their associated type.
 *
 *  MIKMIDIEvent is also available in mutable variants, most useful for creating events to be sent out
 *  by your application.
 *
 *  To create a new event, typically, you should use +midiEventWithTimeStamp:eventType:data:(NSData *)data
 *
 *  Subclass MIKMIDIEvent
 *  -----------------------
 *
 *  Support for the various MIDI event types is provided by type-specific subclasses of MIKMIDIEvent.
 *  For example, note events are represented using MIKMIDINoteEvent.
 *
 *  To support a new event type, you should create a new subclass of MIKMIDIEvent (and please consider
 *  contributing it to the main MIKMIDI repository!). If you implement this subclass according to the rules
 *  explained below, it will automatically be used to represent MIDI events matching its MIDI event type.
 *
 *  To successfully subclass MIKMIDIEvent, you *must* override at least the following methods:
 *
 *  - `+supportsMIKMIDIEventType:` - Return YES when passed the MIKMIDIEventType value your subclass supports.
 *  - `+immutableCounterPartClass` - Return the subclass itself (eg. `return [MIKMIDINewTypeEvent class];`)
 *  - `+mutableCounterPartClass` - Return the mutable counterpart class (eg. `return [MIKMIDIMutableNewTypeEvent class;]`)
 *
 *  Optionally, override `-additionalEventDescription` to provide an additional, type-specific description string.
 *
 *  You must also implement `+load` and call `[MIKMIDIEvent registerSubclass:self]` to register your subclass with
 *  the MIKMIDIEvent machinery.
 *
 *  When creating a subclass of MIKMIDIEvent, you should also create a mutable variant which is itself
 *  a subclass of your type-specific MIKMIDIEvent subclass. The mutable subclass should override `+isMutable`
 *  and return YES.
 *
 *  If your subclass adds additional properties, beyond those supported by MIKMIDIEvent itself, those properties
 *  should only be settable on instances of the mutable variant class. The preferred way to accomplish this is to
 *  implement the setters on the *immutable*, base subclass. In their implementations, check to see if self is
 *  mutable, and if not, raise an exception. Use the following line of code:
 *
 *		if (![[self class] isMutable]) return MIKMIDI_RAISE_MUTATION_ATTEMPT_EXCEPTION;
 *
 *  For a straightforward example of a MIKMIDIEvent subclass, see MIKMIDINoteEvent.
 *
 */
@interface MIKMIDIEvent : NSObject <NSCopying>

/**
 *  Convenience method for creating a new MIKMIDIEvent instance from an NSData instance.
 *  For event types for which there is a specific MIKMIDIEvent subclass,
 *  an instance of the appropriate subclass will be returned.
 *
 *  The NSData argument is used in conjunction with the eventType to propertly discriminate
 *  between different kMusicEventType_Meta subtypes.
 *
 *  @param timeStamp A MusicTimeStamp value indicating the timestamp for the event.
 *  @param eventType A MusicEventType value indicating the type of the event.
 *  @param data An NSData instance containing the raw data for the event. May be nil for an empty event.
 *
 *  @return For supported event types, an initialized MIKMIDIEvent subclass. Otherwise, an instance
 *  of MIKMIDIEvent itself. nil if there is an error.
 *
 *  @see +mikEventTypeForMusicEventType:
 */
+ (nullable instancetype)midiEventWithTimeStamp:(MusicTimeStamp)timeStamp eventType:(MusicEventType)eventType data:(nullable NSData *)data;

/**
 *  Initializes a new MIKMIDIEvent subclass instance. This method may return an instance of a different class than the
 *  receiver.
 *
 *  @param timeStamp A MusicTimeStamp value indicating the timestamp for the event.
 *  @param eventType An MIKMIDIEventType value indicating the type of the event.
 *  @param data An NSData instance containing the raw data for the event. May be nil for an empty event.
 *
 *  @return For supported command types, an initialized MIKMIDIEvent subclass. Otherwise, an instance of
 *	MIKMIDICommand itself. nil if there is an error.
 */
- (nullable instancetype)initWithTimeStamp:(MusicTimeStamp)timeStamp midiEventType:(MIKMIDIEventType)eventType data:(nullable NSData *)data NS_DESIGNATED_INITIALIZER;

/**
 *  The MIDI event type.
 */
@property (nonatomic, readonly) MIKMIDIEventType eventType;

/**
 *  The timeStamp of the MIDI event. When used in a MusicSequence of type kMusicSequenceType_Beats
 *  a timeStamp of 1 equals one quarter note. See the MusicSequence Reference for more information.
 */
@property (nonatomic, readonly) MusicTimeStamp timeStamp;

/**
 *  The data representing the event. The actual type of stored data will vary by subclass.
 *  For example, in MIKMIDINoteEvent the data property's bytes are of type MIDINoteMessage.
 */
@property (nonatomic, readonly) NSData *data;

@end

/**
 *  Mutable subclass of MIKMIDIEvent. All MIKMIDIEvent subclasses have mutable variants.
 */
@interface MIKMutableMIDIEvent : MIKMIDIEvent

@property (nonatomic, readonly) MIKMIDIEventType eventType;
@property (nonatomic) MusicTimeStamp timeStamp;
@property (nonatomic, strong, readwrite, null_resettable) NSMutableData *data;

@end

NS_ASSUME_NONNULL_END

#pragma mark - MIKMIDICommand+MIKMIDIEventToCommands

#import "MIKMIDICommand.h"

@class MIKMIDIClock;

NS_ASSUME_NONNULL_BEGIN

@interface MIKMIDICommand (MIKMIDIEventToCommands)

+ (MIKArrayOf(MIKMIDICommand *) *)commandsFromMIDIEvent:(MIKMIDIEvent *)event clock:(nullable MIKMIDIClock *)clock;

@end

NS_ASSUME_NONNULL_END