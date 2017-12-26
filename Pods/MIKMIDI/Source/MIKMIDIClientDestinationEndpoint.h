//
//  MIKMIDIClientDestinationEndpoint.h
//  Pods
//
//  Created by Andrew Madsen on 9/26/14.
//
//

#import "MIKMIDIDestinationEndpoint.h"
#import "MIKMIDICompilerCompatibility.h"

@class MIKMIDIClientDestinationEndpoint;
@class MIKMIDICommand;

NS_ASSUME_NONNULL_BEGIN

typedef void(^MIKMIDIClientDestinationEndpointEventHandler)(MIKMIDIClientDestinationEndpoint *destination, MIKArrayOf(MIKMIDICommand *) *commands);

/**
 *	MIKMIDIClientDestinationEndpoint represents a virtual endpoint created by your application to receive MIDI
 *	from other applications on the system.
 *
 *  Instances of this class will be visible and can be connected to by other applications.
 */
@interface MIKMIDIClientDestinationEndpoint : MIKMIDIDestinationEndpoint

/**
 *  Initializes a new virtual destination endpoint.
 *
 *  This is essentially equivalent to creating a Core MIDI destination endpoint
 *  using MIDIDestinationCreate(). Destination endpoints created using this
 *  method can be used by your application to *receive* MIDI rather than send
 *  it. They can be seen and connected to by other applications on the system.
 *
 *  @note On iOS, in order to create MIKMIDIClientDestinationEndpoint instances,
 *  your app must include the 'audio' key in its UIBackgroundModes in its Info.plist.
 *  Please see https://github.com/mixedinkey-opensource/MIKMIDI/wiki/Adding-Audio-to-UIBackgroundModes .
 *
 *  @param name	A name for the new virtual endpoint.
 *  @param handler A block to be called when the endpoint receives MIDI messages.
 *
 *  @return An instance of MIKMIDIClientDestinationEndpoint, or nil if an error occurs.
 */
- (nullable instancetype)initWithName:(NSString *)name receivedMessagesHandler:(nullable MIKMIDIClientDestinationEndpointEventHandler)handler;

/**
 *  A block to be called when the receiver receives new incoming MIDI messages.
 */
@property (nonatomic, strong, nullable) MIKMIDIClientDestinationEndpointEventHandler receivedMessagesHandler;

@end

NS_ASSUME_NONNULL_END