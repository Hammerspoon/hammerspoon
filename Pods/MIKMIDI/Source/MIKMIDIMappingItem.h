//
//  MIKMIDIMappingItem.h
//  MIKMIDI
//
//  Created by Andrew Madsen on 5/20/15.
//  Copyright (c) 2015 Mixed In Key. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "MIKMIDIMappableResponder.h"
#import "MIKMIDICommand.h"
#import "MIKMIDICompilerCompatibility.h"

@class MIKMIDIMapping;

NS_ASSUME_NONNULL_BEGIN

/**
 *  MIKMIDIMappingItem contains information about a mapping between a physical MIDI control,
 *  and a single command supported by a particular MIDI responder object.
 *
 *  MIKMIDIMappingItem specifies the command type, and MIDI channel for the commands sent by the
 *  mapped physical control along with the control's interaction type (e.g. knob, turntable, button, etc.).
 *  It also specifies the (software) MIDI responder to which incoming commands from the mapped control
 *  should be routed.
 *
 */
@interface MIKMIDIMappingItem : NSObject <NSCopying>

/**
 *  Creates and initializes a new MIKMIDIMappingItem instance.
 *
 *  @param MIDIResponderIdentifier The identifier for the MIDI responder object being mapped.
 *  @param commandIdentifier       The identifer for the command to be mapped.
 *
 *  @return An initialized MIKMIDIMappingItem instance.
 */
- (instancetype)initWithMIDIResponderIdentifier:(NSString *)MIDIResponderIdentifier andCommandIdentifier:(NSString *)commandIdentifier;

/**
 *  Returns an NSString instance containing an XML representation of the receiver.
 *  The XML document returned by this method can be written to disk.
 *
 *  @return An NSString containing an XML representation of the receiver, or nil if an error occurred.
 *
 *  @see -writeToFileAtURL:error:
 */
- (nullable NSString *)XMLStringRepresentation;

// Properties

/**
 *  The MIDI identifier for the (software) responder object being mapped. This is the same value as returned by calling -MIDIIdentifier
 *  on the responder to be mapped.
 *
 *  This value can be used to retrieve the MIDI responder to which this mapping refers at runtime using
 *  -[NS/UIApplication MIDIResponderWithIdentifier].
 */
@property (nonatomic, readonly) NSString *MIDIResponderIdentifier;

/**
 *  The identifier for the command mapped by this mapping item. This will be one of the identifier's returned
 *  by the mapped responder's -commandIdentifiers method.
 */
@property (nonatomic, readonly) NSString *commandIdentifier;

/**
 *  The interaction type for the physical control mapped by this item. This can be used to determine
 *  how to interpret the incoming MIDI messages mapped by this item.
 */
@property (nonatomic) MIKMIDIResponderType interactionType;

/**
 *  If YES, value decreases as slider/knob goes left->right or top->bottom.
 *  This property is currently only relevant for knobs and sliders, and has no meaning for buttons or other responder types.
 */
@property (nonatomic, getter = isFlipped) BOOL flipped;

/**
 *  The MIDI channel upon which commands are sent by the control mapped by this item.
 */
@property (nonatomic) NSInteger channel;

/**
 *  The MIDI command type of commands sent by the control mapped by this item.
 */
@property (nonatomic) MIKMIDICommandType commandType;

/**
 *  The control number of the control mapped by this item.
 *  This is either the note number (for Note On/Off commands) or controller number (for control change commands).
 */
@property (nonatomic) NSUInteger controlNumber;

/**
 *  Optional additional key value pairs, which will be saved as attributes in this item's XML representation. Keys and values must be NSStrings.
 */
@property (nonatomic, copy, nullable) NSDictionary *additionalAttributes;

/**
 *  The MIDI Mapping the receiver belongs to. May be nil if the mappping item hasn't been added to a mapping yet,
 *  or its mapping has been deallocated.
 */
@property (nonatomic, weak, readonly, nullable) MIKMIDIMapping *mapping;

@end

NS_ASSUME_NONNULL_END