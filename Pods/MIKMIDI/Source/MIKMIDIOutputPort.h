//
//  MIKMIDIOutputPort.h
//  MIDI Testbed
//
//  Created by Andrew Madsen on 3/8/13.
//  Copyright (c) 2013 Mixed In Key. All rights reserved.
//

#import "MIKMIDIPort.h"
#import "MIKMIDICompilerCompatibility.h"

@class MIKMIDICommand;
@class MIKMIDIDestinationEndpoint;

NS_ASSUME_NONNULL_BEGIN

/**
 *  MIKMIDIOutputPort is an Objective-C wrapper for CoreMIDI's MIDIPort class, and is only for destination ports.
 *  It is not intended for use by clients/users of of MIKMIDI. Rather, it should be thought of as an
 *  MIKMIDI private class.
 */
@interface MIKMIDIOutputPort : MIKMIDIPort

- (BOOL)sendCommands:(MIKArrayOf(MIKMIDICommand *) *)commands toDestination:(MIKMIDIDestinationEndpoint *)destination error:(NSError **)error;

@end

NS_ASSUME_NONNULL_END