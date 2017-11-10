//
//  MIKMIDIInputPort.h
//  MIDI Testbed
//
//  Created by Andrew Madsen on 3/8/13.
//  Copyright (c) 2013 Mixed In Key. All rights reserved.
//

#import "MIKMIDIPort.h"
#import "MIKMIDISourceEndpoint.h"
#import "MIKMIDICompilerCompatibility.h"

@class MIKMIDIEndpoint;
@class MIKMIDICommand;

NS_ASSUME_NONNULL_BEGIN

/**
 *  MIKMIDIInputPort is an Objective-C wrapper for CoreMIDI's MIDIPort class, and is only for source ports.
 *  It is not intended for use by clients/users of of MIKMIDI. Rather, it should be thought of as an
 *  MIKMIDI private class.
 */
@interface MIKMIDIInputPort : MIKMIDIPort

- (id _Nullable)connectToSource:(MIKMIDISourceEndpoint *)source
						  error:(NSError **)error
				   eventHandler:(MIKMIDIEventHandlerBlock)eventHandler;
- (void)disconnectConnectionForToken:(id)token;

@property (nonatomic, strong, readonly) MIKArrayOf(MIKMIDIEndpoint *) *connectedSources;

@property (nonatomic) BOOL coalesces14BitControlChangeCommands; // Default is YES

/**
 * Time before sysex transmissions are considered over.
 *
 * This takes care of interruption in the data (devices being turned off or unplugged) as well as
 * ill-behaved devices which don't terminate their sysex messages with 0xF7.
 */
@property (assign) NSTimeInterval sysexTimeOut;

@end

NS_ASSUME_NONNULL_END
