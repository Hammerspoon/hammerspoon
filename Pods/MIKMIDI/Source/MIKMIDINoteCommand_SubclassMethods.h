//
//  MIKMIDIChannelVoiceCommand_SubclassMethods.h
//  MIKMIDI
//
//  Created by Andrew Madsen on 10/10/13.
//  Copyright (c) 2013 Mixed In Key. All rights reserved.
//

#import "MIKMIDINoteCommand.h"
#import "MIKMIDIChannelVoiceCommand_SubclassMethods.h"
#import "MIKMIDICompilerCompatibility.h"

NS_ASSUME_NONNULL_BEGIN

@interface MIKMIDINoteCommand ()

@property (nonatomic, readwrite, getter=isNoteOn) BOOL noteOn;

@end

NS_ASSUME_NONNULL_END
