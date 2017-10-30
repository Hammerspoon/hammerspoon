//
//  MIKMIDIMetadataEvent.h
//  MIDI Files Testbed
//
//  Created by Jake Gundersen on 5/22/14.
//  Copyright (c) 2014 Mixed In Key. All rights reserved.
//

#import "MIKMIDIEvent.h"
#import "MIKMIDICompilerCompatibility.h"

static const NSUInteger MIKMIDIEventMetadataStartOffset = 8;

/**
 *  Subtypes of MIKMIDIMetaEvent. You should use the corresponding meta subtypes in MIKMIDIEventType when
 *  initializing an event with -initWithTimeStamp:midiEventType:data: or similar methods.
 *
 *  The reason for a separate enum here, even though there is a 1 to 1 correspondence with values in 
 *  MIKMIDIEventType is that these values are dictated by the MIDI standard, and overlap values defined
 *  for MusicEventType. Having these separately defined allows us to effectively "flatten" MIKMIDIEventType
 *  to treat meta event subtypes as first class event types.
 */
typedef NS_ENUM(UInt8, MIKMIDIMetaEventType)
{
	MIKMIDIMetaEventTypeSequenceNumber          = 0x00,
	MIKMIDIMetaEventTypeTextEvent               = 0x01,
	MIKMIDIMetaEventTypeCopyrightNotice         = 0x02,
	MIKMIDIMetaEventTypeTrackSequenceName       = 0x03,
	MIKMIDIMetaEventTypeInstrumentName          = 0x04,
	MIKMIDIMetaEventTypeLyricText               = 0x05,
	MIKMIDIMetaEventTypeMarkerText              = 0x06,
	MIKMIDIMetaEventTypeCuePoint                = 0x07,
	MIKMIDIMetaEventTypeMIDIChannelPrefix       = 0x20,
	MIKMIDIMetaEventTypeEndOfTrack              = 0x2F,
	MIKMIDIMetaEventTypeTempoSetting            = 0x51,
	MIKMIDIMetaEventTypeSMPTEOffset             = 0x54,
	MIKMIDIMetaEventTypeTimeSignature           = 0x58,
	MIKMIDIMetaEventTypeKeySignature            = 0x59,
	MIKMIDIMetaEventTypeSequencerSpecificEvent  = 0x7F,
	MIKMIDIMetaEventTypeInvalid					= 0x66,
};

// For legacy compatibility. Should use MIKMIDIMetaEventType in new code.
typedef MIKMIDIMetaEventType MIKMIDIMetaEventTypeType;

NS_ASSUME_NONNULL_BEGIN

/**
 *  A MIDI meta event.
 */
@interface MIKMIDIMetaEvent : MIKMIDIEvent

/**
 *  Can be used to get the high-level MIKMIDIEventType for an MIKMIDIMetaEventType.
 *  Most users of MIKMIDI should not need to use this.
 *
 *  @param subtype An MIKMIDIMetaEventType value.
 *
 *  @return The corresponding MIKMIDIEventType value. MIKMIDIEventTypeNULL if subtype is invalid or unknown.
 */
+ (MIKMIDIEventType)eventTypeForMetaSubtype:(MIKMIDIMetaEventType)subtype;

/**
 *  Can be used to get the meta event subtype MIKMIDIMetaEventType for an MIKMIDIEventType.
 *  Most users of MIKMIDI should not need to use this.
 *
 *  @param eventType An MIKMIDIEventType value.
 *
 *  @return The corresponding MIKMIDIMetaEventType value. MIKMIDIMetaEventTypeInvalid if eventType is invalid or unknown.
 */
+ (MIKMIDIMetaEventType)metaSubtypeForEventType:(MIKMIDIEventType)eventType;

/**
 *  Initializes a new MIKMIDIMetaEvent subclass with the specified data and metadataType.
 *
 *  @param metaData     An NSData containing the metadata for the event.
 *  @param type The type of metadata. The appropriate subclass of MIKMIDIMetaEvent will be returned depending
 *  on this value. If this value is invalid or unknown, a plain MIKMIDIMetaEvent instance will be returned.
 *  @param timeStamp    The MusicTimeStamp timestamp for the event.
 *
 *  @return An initialized instance of MIKMIDIMetaEvent or one of its subclasses. 
 */
- (instancetype)initWithMetaData:(NSData *)metaData metadataType:(MIKMIDIMetaEventType)type timeStamp:(MusicTimeStamp)timeStamp;

/**
 *  The type of metadata. See MIDIMetaEvent for more information.
 */
@property (nonatomic, readonly) MIKMIDIMetaEventType metadataType;

/**
 *  The length of the metadata. See MIDIMetaEvent for more information.
 */
@property (nonatomic, readonly) UInt32 metadataLength;

/**
 *  The metadata for the event.
 */
@property (nonatomic, strong, readonly) NSData *metaData;

@end

/**
 *  The mutable counterpart of MIKMIDIMetaEvent.
 */
@interface MIKMutableMIDIMetaEvent : MIKMIDIMetaEvent

@property (nonatomic, readwrite) MusicTimeStamp timeStamp;
@property (nonatomic, readwrite) MIKMIDIMetaEventType metadataType;
@property (nonatomic, strong, readwrite, null_resettable) NSData *metaData;

@end

NS_ASSUME_NONNULL_END