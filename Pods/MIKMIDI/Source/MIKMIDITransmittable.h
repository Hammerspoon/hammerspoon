//
//  MIKMIDITransmittable.h
//  MIKMIDI
//
//  Created by Andrew Madsen on 2/7/18.
//  Copyright © 2018 Mixed In Key. All rights reserved.
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@protocol MIKMIDITransmittable <NSObject>

@optional
/*
 Some MIDI commands, e.g. 14-bit MIKMIDIControlChangeCommands, need to be split into multiple MIDI messages or otherwise transformed before sending through an output port. This method should return an array of command(s) to be sent to represent the receiver.
 */
- (NSArray *)commandsForTransmission;

@end

NS_ASSUME_NONNULL_END
