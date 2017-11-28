//
//  MIKMIDIChannelVoiceCommand_SubclassMethods.h
//  MIKMIDI
//
//  Created by Andrew Madsen on 10/10/13.
//  Copyright (c) 2013 Mixed In Key. All rights reserved.
//

#import "MIKMIDIChannelVoiceCommand.h"
#import "MIKMIDICommand_SubclassMethods.h"
#import "MIKMIDICompilerCompatibility.h"

NS_ASSUME_NONNULL_BEGIN

@interface MIKMIDIChannelVoiceCommand ()

@property (nonatomic, readwrite) NSUInteger value;

@end

NS_ASSUME_NONNULL_END