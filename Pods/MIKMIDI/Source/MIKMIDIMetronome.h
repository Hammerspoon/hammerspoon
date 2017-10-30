//
//  MIKMIDIMetronome.h
//  MIKMIDI
//
//  Created by Chris Flesner on 11/24/14.
//  Copyright (c) 2014 Mixed In Key. All rights reserved.
//

#import "MIKMIDIEndpointSynthesizer.h"
#import "MIKMIDICompilerCompatibility.h"

NS_ASSUME_NONNULL_BEGIN

/**
 *	This class is only a subclass of MIKMIDIEndpointSynthesizer so it continues to function with MIKMIDIPlayer while
 *	it still exists. Once MIKMIDIPlayer is removed from the code base, expect this to become a subclass of MIKMIDISynthesizer.
 */
@interface MIKMIDIMetronome : MIKMIDIEndpointSynthesizer

@property (nonatomic) MIDINoteMessage tickMessage;
@property (nonatomic) MIDINoteMessage tockMessage;

@end


@interface MIKMIDIMetronome (Private)

/**
 *  This should not be called directly, but may be overridden by subclasses to setup the metronome instrument
 *	in a custom manner.
 */
- (BOOL)setupMetronome;

@end

NS_ASSUME_NONNULL_END
