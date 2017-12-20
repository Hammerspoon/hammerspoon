//
//  MIKMIDIMappableResponder.h
//  MIKMIDI
//
//  Created by Andrew Madsen on 5/20/15.
//  Copyright (c) 2015 Mixed In Key. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "MIKMIDIResponder.h"
#import "MIKMIDICompilerCompatibility.h"

/**
 *  Bit-mask constants used to specify MIDI responder types for mapping.
 *  Multiple responder types can be specified by ORing them together.
 *  @see -[MIKMIDIMappableResponder MIDIResponderTypeForCommandIdentifier:]
 */
typedef NS_OPTIONS(NSUInteger, MIKMIDIResponderType){
	/**
	 *  Responder does not have a type. Cannot be mapped.
	 */
	MIKMIDIResponderTypeNone = 0,
	
	/**
	 *  Type for a MIDI responder that can handle messages from a hardware absolute
	 *  knob or slider. That is, one that sends control change messages with an absolute value
	 *  depending on its position.
	 */
	MIKMIDIResponderTypeAbsoluteSliderOrKnob = 1 << 0,
	
	/**
	 *  Type for a MIDI responder that can handle messages from a hardware relative
	 *  knob. That is, a knob that sends a message for each "tick", and whose value
	 *  depends on the direction (and possibly velocity) of the knob, rather than its
	 *  absolute position.
	 */
	MIKMIDIResponderTypeRelativeKnob = 1 << 1,
	
	/**
	 *  Type for a MIDI responder that can handle messages from a hardware turntable-like
	 *  jog wheel. These are relative knobs, but typically have *much* higher resolution than
	 *  a small relative knob. They may also have a touch/pressure sensitive top to detect when
	 *  the user is touching, but not turning the wheel.
	 */
	MIKMIDIResponderTypeTurntableKnob = 1 << 2,
	
	/**
	 *  Type for a MIDI responder that can handle messages from a hardware relative knob that
	 *  sends messages to simulate an absolute knob. Relative knobs on (at least) Native Instruments
	 *  controllers can be configured to send messages like an absolute knob. This can pose the problem
	 *  of the knob continuing to turn past its limits (0 and 127) without additional messages being sent.
	 *  These knobs can and will be mapped as a regular absolute knob for responders that include MIKMIDIResponderTypeAbsoluteSliderOrKnob
	 *  but *not* MIKMIDIResponderTypeRelativeAbsoluteKnob in the type returned by -MIDIResponderTypeForCommandIdentifier:
	 */
	MIKMIDIResponderTypeRelativeAbsoluteKnob = 1 << 3,
	
	/**
	 *  Type for a MIDI responder that can handle messages from a hardware button that sends a message when
	 *  pressed down, and another message when released.
	 */
	MIKMIDIResponderTypePressReleaseButton = 1 << 4,
	
	/**
	 *  Type for a MIDI responder that can handle messages from a hardware button that only sends a single
	 *  message when pressed down, without sending a corresponding message upon release.
	 */
	MIKMIDIResponderTypePressButton = 1 << 5,
	
	/**
	 *  Convenience type for a responder that can handle messages from any type of knob.
	 */
	MIKMIDIResponderTypeKnob = (MIKMIDIResponderTypeAbsoluteSliderOrKnob | MIKMIDIResponderTypeRelativeKnob | \
								MIKMIDIResponderTypeTurntableKnob | MIKMIDIResponderTypeRelativeAbsoluteKnob),
	
	/**
	 *  Convenience type for a responder that can handle messages from any type of button.
	 */
	MIKMIDIResponderTypeButton = (MIKMIDIResponderTypePressButton | MIKMIDIResponderTypePressReleaseButton),
	
	/**
	 *  Convenience type for a responder that can handle messages from any kind of control.
	 */
	MIKMIDIResponderTypeAll = NSUIntegerMax,
};

NS_ASSUME_NONNULL_BEGIN

/**
 *  This protocol defines methods that that must be implemented by MIDI responder objects to be mapped
 *  using MIKMIDIMappingGenerator, and to whom MIDI messages will selectively be routed using a MIDI mapping
 *  during normal operation.
 */
@protocol MIKMIDIMappableResponder <MIKMIDIResponder>

@required
/**
 *  The list of identifiers for all commands supported by the receiver.
 *
 *  A MIDI responder may want to handle incoming MIDI message from more than one control. For example, a view displaying
 *  a list of songs may want to support commands for browsing up and down the list with buttons, or with a knob, as well as a button
 *  to load the selected song. These commands would be for example, KnobBrowse, BrowseUp, BrowseDown, and Load. This way, multiple physical
 *  controls can be mapped to different functions of the same MIDI responder.
 *
 *  @return An NSArray containing NSString identifers for all MIDI mappable commands supported by the receiver.
 */
- (MIKArrayOf(NSString *) *)commandIdentifiers;

/**
 *  The MIDI responder types the receiver will allow to be mapped to the command specified by commandID.
 *
 *  In the example given for -commandIdentifers, the "KnobBrowse" might be mappable to any physical knob,
 *  while BrowseUp, BrowseDown, and Load are mappable to buttons. The responder would return MIKMIDIResponderTypeKnob
 *  for @"KnobBrowse" while returning MIKMIDIResponderTypeButton for the other commands.
 *
 *  @param commandID A command identifier string.
 *
 *  @return A MIKMIDIResponderType bitfield specifing one or more responder type(s).
 *
 *  @see MIKMIDIResponderType
 */
- (MIKMIDIResponderType)MIDIResponderTypeForCommandIdentifier:(NSString *)commandID; // Optional. If not implemented, MIKMIDIResponderTypeAll will be assumed.

@optional

/**
 *  Whether the physical control mapped to the commandID in the receiver should
 *  be illuminated, or not.
 *
 *  Many hardware MIDI devices, e.g. DJ controllers, have buttons that can light
 *  up to show state for the associated function. For example, the play button
 *  could be illuminated when the software is playing. This method allows mapped
 *  MIDI responder objects to communicate the desired state of the physical control
 *  mapped to them.
 *
 *  Currently MIKMIDI doesn't provide automatic support for actually updating
 *  physical LED status. This must be implemented in application code. For most devices,
 *  this can be accomplished by sending a MIDI message _to_ the device. The MIDI message
 *  should identical to the message that the relevant control sends when pressed, with
 *  a non-zero value to illumniate the control, or zero to turn illumination off.
 *
 *  @param commandID The commandID for which the associated illumination state is desired.
 *
 *  @return YES if the associated control should be illuminated, NO otherwise.
 */
- (BOOL)illuminationStateForCommandIdentifier:(NSString *)commandID;

@end

NS_ASSUME_NONNULL_END