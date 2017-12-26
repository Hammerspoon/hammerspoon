//
//  MIKMIDIPort_SubclassMethods.h
//  MIDI Testbed
//
//  Created by Andrew Madsen on 3/8/13.
//  Copyright (c) 2013 Mixed In Key. All rights reserved.
//

#import <MIKMIDI/MIKMIDIPort.h>
#import <MIKMIDI/MIKMIDICompilerCompatibility.h>

NS_ASSUME_NONNULL_BEGIN

@interface MIKMIDIPort ()

@property (nonatomic, readwrite) MIDIPortRef portRef;

@end

NS_ASSUME_NONNULL_END
