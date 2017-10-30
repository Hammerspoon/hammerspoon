//
//  MIKMIDIClientSourceEndpoint.h
//  MIKMIDI
//  
//  Created by Dan Rosenstark on 2015-01-07
//

#import "MIKMIDISourceEndpoint.h"
#import "MIKMIDICompilerCompatibility.h"

@class MIKMIDICommand;

NS_ASSUME_NONNULL_BEGIN

/**
 *	MIKMIDIClientSourceEndpoint represents a virtual endpoint created by your application to send MIDI
 *	to other applications on the system.
 *
 *  Instances of this class will be visible and can be connected to by other applications.
 */
@interface MIKMIDIClientSourceEndpoint : MIKMIDISourceEndpoint

/**
 *  Initializes a new virtual source endpoint.
 *
 *  This is essentially equivalent to creating a Core MIDI source endpoint
 *  using MIDISourceCreate(). Source endpoints created using this
 *  method can be used by your application to *send* MIDI rather than receive
 *  it. They can be seen and connected to by other applications on the system.
 *
 *  @param name	A name for the new virtual endpoint.
 *
 *  @return An instance of MIKMIDIClientSourceEndpoint, or nil if an error occurs.
 */
- (nullable instancetype)initWithName:(NSString *)name;

/**
 *  Used to send MIDI messages/commands from your application to a MIDI output endpoint.
 *  Use this to send messages to a virtual MIDI port created in the  your client using the MIKMIDIClientSourceEndpoint class.
 *
 *  @param commands An NSArray containing MIKMIDICommand instances to be sent.
 *  @param error    If an error occurs, upon returns contains an NSError object that describes the problem. If you are not interested in possible errors, you may pass in NULL.
 *
 *  @return YES if the commands were successfully sent, NO if an error occurred.
 */
- (BOOL)sendCommands:(MIKArrayOf(MIKMIDICommand *) *)commands error:(NSError **)error;

@end

NS_ASSUME_NONNULL_END