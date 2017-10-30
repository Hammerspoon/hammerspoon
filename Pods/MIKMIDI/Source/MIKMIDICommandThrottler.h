//
//  MIKMIDICommandThrottler.h
//  MIKMIDI
//
//  Created by Andrew Madsen on 11/11/13.
//  Copyright (c) 2013 Mixed In Key. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "MIKMIDICompilerCompatibility.h"

@class MIKMIDIChannelVoiceCommand;

NS_ASSUME_NONNULL_BEGIN

/**
 *  MIKMIDICommandThrottler is a simple utility class useful for throttling e.g. jog wheel/turntable controls, 
 *  which otherwise send many messages per revolution.
 */
@interface MIKMIDICommandThrottler : NSObject

/**
 *  Determine whether a command from a throttled control should be handled or discarded.
 *
 *  @param command The command received from the throttled control.
 *  @param factor  The throttling factor to apply. e.g. a value of 20 means that only 1 of every 20 messages should be handled.
 *
 *  @return YES if the command should be handled, NO if it should be discarded.
 */
- (BOOL)shouldPassCommand:(MIKMIDIChannelVoiceCommand *)command forThrottlingFactor:(NSUInteger)factor;

/**
 *  Resets the throttle counter for command.
 *
 *  @param command The command received from the throttled control.
 */
- (void)resetThrottlingCountForCommand:(MIKMIDIChannelVoiceCommand *)command;

@end

NS_ASSUME_NONNULL_END
