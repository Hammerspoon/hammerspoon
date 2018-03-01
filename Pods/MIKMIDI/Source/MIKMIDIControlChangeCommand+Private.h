//
//  MIKMIDIControlChangeCommand+Private.h
//  MIKMIDI
//
//  Created by Andrew Madsen on 2/7/18.
//  Copyright © 2018 Mixed In Key. All rights reserved.
//

#import <MIKMIDI/MIKMIDIControlChangeCommand.h>
#import <MIKMIDI/MIKMIDIOutputPort.h>

@interface MIKMIDIControlChangeCommand () <MIKMIDITransmittable>

/**
 Returns an array of commands to be directly transmitted over a MIDI connection for this command. This method
 is here to support easily splitting a single 14-bit MIKMIDIControlChangeCommand instance into the two separate
 MIDI messages that actually get transmitted. For standard 7-bit control change commands, this returns an array
 containing only the receiver itself.
 
 @return An array of MIKMIDIControlChangeCommand instances.
 */
- (NSArray *)commandsForTransmission;

@end
