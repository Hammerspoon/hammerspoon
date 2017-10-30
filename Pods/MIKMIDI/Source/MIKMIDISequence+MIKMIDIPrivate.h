//
//  MIKMIDISequence+MIKMIDIPrivate.h
//  MIKMIDI
//
//  Created by Chris Flesner on 6/30/15.
//  Copyright (c) 2015 Mixed In Key. All rights reserved.
//

#import "MIKMIDISequence.h"
#import "MIKMIDICompilerCompatibility.h"

@class MIKMIDISequencer;

NS_ASSUME_NONNULL_BEGIN

@interface MIKMIDISequence (MIKMIDIPrivate)

@property (weak, nonatomic, nullable) MIKMIDISequencer *sequencer;

@end

NS_ASSUME_NONNULL_END