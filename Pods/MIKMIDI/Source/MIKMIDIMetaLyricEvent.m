//
//  MIKMIDIMetaLyricEvent.m
//  MIDI Files Testbed
//
//  Created by Jake Gundersen on 5/22/14.
//  Copyright (c) 2014 Mixed In Key. All rights reserved.
//

#import "MIKMIDIMetaLyricEvent.h"
#import "MIKMIDIEvent_SubclassMethods.h"
#import "MIKMIDIUtilities.h"

#if !__has_feature(objc_arc)
#error MIKMIDIMetaLyricEvent.m must be compiled with ARC. Either turn on ARC for the project or set the -fobjc-arc flag for MIKMIDIMetaLyricEvent.m in the Build Phases for this target
#endif

@implementation MIKMIDIMetaLyricEvent

+ (void)load { [MIKMIDIEvent registerSubclass:self]; }
+ (NSArray *)supportedMIDIEventTypes { return @[@(MIKMIDIEventTypeMetaLyricText)]; }
+ (Class)immutableCounterpartClass { return [MIKMIDIMetaLyricEvent class]; }
+ (Class)mutableCounterpartClass { return [MIKMutableMIDIMetaLyricEvent class]; }
+ (BOOL)isMutable { return NO; }

@end

@implementation MIKMutableMIDIMetaLyricEvent

@dynamic timeStamp;
@dynamic metadataType;
@dynamic metaData;

+ (BOOL)isMutable { return YES; }

@end