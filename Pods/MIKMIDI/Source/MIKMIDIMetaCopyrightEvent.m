//
//  MIKMIDIMetaCopyrightEvent.m
//  MIDI Files Testbed
//
//  Created by Jake Gundersen on 5/22/14.
//  Copyright (c) 2014 Mixed In Key. All rights reserved.
//

#import "MIKMIDIMetaCopyrightEvent.h"
#import "MIKMIDIEvent_SubclassMethods.h"
#import "MIKMIDIUtilities.h"

#if !__has_feature(objc_arc)
#error MIKMIDIMetaCopyrightEvent.m must be compiled with ARC. Either turn on ARC for the project or set the -fobjc-arc flag for MIKMIDIMetaCopyrightEvent.m in the Build Phases for this target
#endif

@implementation MIKMIDIMetaCopyrightEvent

+ (void)load { [MIKMIDIEvent registerSubclass:self]; }
+ (NSArray *)supportedMIDIEventTypes { return @[@(MIKMIDIEventTypeMetaCopyright)]; }
+ (Class)immutableCounterpartClass { return [MIKMIDIMetaCopyrightEvent class]; }
+ (Class)mutableCounterpartClass { return [MIKMutableMIDIMetaCopyrightEvent class]; }
+ (BOOL)isMutable { return NO; }

@end

@implementation MIKMutableMIDIMetaCopyrightEvent

@dynamic timeStamp;
@dynamic metadataType;
@dynamic metaData;

+ (BOOL)isMutable { return YES; }

@end