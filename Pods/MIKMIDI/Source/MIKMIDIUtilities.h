//
//  MIKMIDIUtilities.h
//  MIDI Testbed
//
//  Created by Andrew Madsen on 3/7/13.
//  Copyright (c) 2013 Mixed In Key. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <CoreMIDI/CoreMIDI.h>
#import "MIKMIDIMappableResponder.h"
#import "MIKMIDICommand.h"
#import "MIKMIDICompilerCompatibility.h"
#include <mach/mach_time.h>

NS_ASSUME_NONNULL_BEGIN

NSString * _Nullable MIKStringPropertyFromMIDIObject(MIDIObjectRef object, CFStringRef propertyID, NSError *__autoreleasing*error);
BOOL MIKSetStringPropertyOnMIDIObject(MIDIObjectRef object, CFStringRef propertyID, NSString *string, NSError *__autoreleasing*error);

SInt32 MIKIntegerPropertyFromMIDIObject(MIDIObjectRef object, CFStringRef propertyID, NSError *__autoreleasing*error);
BOOL MIKSetIntegerPropertyFromMIDIObject(MIDIObjectRef object, CFStringRef propertyID, SInt32 integerValue, NSError *__autoreleasing*error);

MIDIObjectType MIKMIDIObjectTypeOfObject(MIDIObjectRef object, NSError *__autoreleasing*error);

NSString *MIKMIDIMappingAttributeStringForInteractionType(MIKMIDIResponderType type);
MIKMIDIResponderType MIKMIDIMappingInteractionTypeForAttributeString(NSString *string);

NSInteger MIKMIDIStandardLengthOfMessageForCommandType(MIKMIDICommandType commandType);

MIDIPacket MIKMIDIPacketCreate(MIDITimeStamp timeStamp, UInt16 length, MIKArrayOf(NSNumber *) *data /*max length 256*/);

// Subclasses of MIKMIDICommand and MIKMIDIEvent can and should use this macro to raise an exception
// when the setter for a public property is called on an immutable object.
#define MIKMIDI_RAISE_MUTATION_ATTEMPT_EXCEPTION ([NSException raise:NSInternalInconsistencyException format:@"Attempt to mutate immutable %@", NSStringFromClass([self class])])

// A prettier way to get the mac_absolute_time() when working with MIDITimeStamps.
MIDITimeStamp MIKMIDIGetCurrentTimeStamp();

/**
 *  Returns whether a given MIDI note number corresponds to a "black key" on a piano.
 *
 *  @param noteNumber The MIDI note number for the note. Between 0 and 127.
 *
 *  @return YES if the passed in note number is a flat / sharp note, NO otherwise.
 */
BOOL MIKMIDINoteIsBlackKey(NSInteger noteNumber);

/**
 *  Returns the note letter of the passed in MIDI note number as a string.
 *  Notes that correspond to a "black key" on the piano will always be presented as sharp.
 *
 *  @param noteNumber The MIDI note number for the note. Between 0 and 127.
 *
 *  @return A string containing the human readable MIDI note letter for the MIDI note.
 *  e.g. C for MIDI note number 60.
 *
 *  @see MIKMIDINoteLetterAndOctaveForMIDINote()
 */
NSString *MIKMIDINoteLetterForMIDINoteNumber(UInt8 noteNumber);

/**
 *  The note letter and octave of the passed in MIDI note.
 *  0 is considered to be the first octave, so the note C0 is equal to MIDI note 0.
 *
 *  @param noteNumber The MIDI note number you would like the note letter for.
 *  Between 0 and 127. e.g. C for MIDI note number 60.
 *
 *  @return A string representing the note letter and octave of the MIDI note.
 *
 *  @see MIKMIDINoteLetterForMIDINoteNumber()
 */
NSString *MIKMIDINoteLetterAndOctaveForMIDINote(UInt8 noteNumber);

NS_ASSUME_NONNULL_END