//
//  MIKMIDIMetadataSequenceEvent.m
//  MIDI Files Testbed
//
//  Created by Jake Gundersen on 5/22/14.
//  Copyright (c) 2014 Mixed In Key. All rights reserved.
//

#import "MIKMIDIMetaSequenceEvent.h"

#if !__has_feature(objc_arc)
#error MIKMIDIMetaSequenceEvent.m must be compiled with ARC. Either turn on ARC for the project or set the -fobjc-arc flag for MIKMIDIMetaSequenceEvent.m in the Build Phases for this target
#endif

@implementation MIKMIDIMetaSequenceEvent

@end

@implementation MIKMutableMIDIMetaSequenceEvent

@dynamic timeStamp;
@dynamic metadataType;
@dynamic metaData;

@end
