//
//  MIKMIDIResponder.h
//  Energetic
//
//  Created by Andrew Madsen on 3/11/13.
//  Copyright (c) 2013 Mixed In Key. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "MIKMIDICompilerCompatibility.h"

@class MIKMIDICommand;

NS_ASSUME_NONNULL_BEGIN

/**
 *  The MIKMIDIResponder protocol defines methods to be implemented by any object that wishes
 *  to receive MIDI messages/commands.
 *
 *  Any class in an application can implement this protocol. To actually receive MIDI messages,
 *  a responder object must be registered by calling -[NS/UIApplication registerMIDIResponder].
 *  Additionally, it is the client application's responsibility to pass incoming MIDI messages to
 *  the application instance by calling -[NS/UIApplication handleMIDICommand:]
 */

@protocol MIKMIDIResponder <NSObject>

@required
/**
 *  Returns an NSString used to uniquely identify this MIDI responder. Need not be 
 *  human readable, but it should be unique in the application.
 *
 *  This identifier can be used to find a given responder at runtime. It is also used by
 *  MIKMIDI's MIDI mapping system to uniquely identify mapped responders.
 *
 *  @return An NSString containing a unique identifier for the receiver.
 *  @see -[MIK_APPLICATION_CLASS(MIKMIDI) MIDIResponderWithIdentifier:]
 */
- (NSString *)MIDIIdentifier;

/**
 *  This method is called to determine if the receiver wants to handle the passed in
 *  MIDI command. If this method returns YES, -handleMIDICommand: is then called.
 *
 *  @param command The MIDI command to be handled.
 *
 *  @return YES if the receiver wishes to handle command, NO to ignore.
 */
- (BOOL)respondsToMIDICommand:(MIKMIDICommand *)command;

/**
 *  The primary method used for MIDI message/command handling. Implmenent the real
 *
 *  This method is only called if the preceeding call to -respondsToMIDICommand: returns YES.
 *
 *  @param command The MIDI command to be handled.
 */
- (void)handleMIDICommand:(MIKMIDICommand *)command;

@optional

/**
 *  An array of subresponders, which must also conform to MIKMIDIResponder.
 *  Responders returned by this method will be eligible
 *  to receive MIDI commands without needing to be explicitly registered with the
 *  application, as long as the receiver (or a parent responder) is registered.
 *
 *  Should return a flat (non-recursive) array of subresponders.
 *  Return empty array, or don't implement if you don't want subresponders to be
 *  included in any case where the receiver would be considered for receiving MIDI
 *
 *  @return An NSArray containing the receivers subresponders. Each object in the array must also conform to MIKMIDIResponder.
 */
- (nullable MIKArrayOf(id<MIKMIDIResponder>) *)subresponders; // Nullable for historical reasons.

@end

NS_ASSUME_NONNULL_END