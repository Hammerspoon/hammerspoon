//
//  MIKMIDIMetaMarkerTextEvent.m
//  MIDI Files Testbed
//
//  Created by Jake Gundersen on 5/22/14.
//  Copyright (c) 2014 Mixed In Key. All rights reserved.
//

#import "MIKMIDIMetaMarkerTextEvent.h"
#import "MIKMIDIEvent_SubclassMethods.h"
#import "MIKMIDIUtilities.h"

#if !__has_feature(objc_arc)
#error MIKMIDIMetaMarkerTextEvent.m must be compiled with ARC. Either turn on ARC for the project or set the -fobjc-arc flag for MIKMIDIMetaMarkerTextEvent.m in the Build Phases for this target
#endif

@implementation MIKMIDIMetaMarkerTextEvent

+ (void)load { [MIKMIDIEvent registerSubclass:self]; }
+ (NSArray *)supportedMIDIEventTypes { return @[@(MIKMIDIEventTypeMetaMarkerText)]; }
+ (Class)immutableCounterpartClass { return [MIKMIDIMetaMarkerTextEvent class]; }
+ (Class)mutableCounterpartClass { return [MIKMutableMIDIMetaMarkerTextEvent class]; }
+ (BOOL)isMutable { return NO; }

@end

@implementation MIKMutableMIDIMetaMarkerTextEvent

@dynamic timeStamp;
@dynamic metadataType;
@dynamic metaData;

+ (BOOL)isMutable { return YES; }

@end