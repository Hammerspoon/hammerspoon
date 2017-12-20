//
//  MIKMIDITempoEvent.m
//  MIDI Files Testbed
//
//  Created by Andrew Madsen on 5/22/14.
//  Copyright (c) 2014 Mixed In Key. All rights reserved.
//

#import "MIKMIDITempoEvent.h"
#import "MIKMIDIEvent_SubclassMethods.h"
#import "MIKMIDIUtilities.h"

#if !__has_feature(objc_arc)
#error MIKMIDITempoEvent.m must be compiled with ARC. Either turn on ARC for the project or set the -fobjc-arc flag for MIKMIDITempoEvent.m in the Build Phases for this target
#endif

@implementation MIKMIDITempoEvent

+ (void)load { [MIKMIDIEvent registerSubclass:self]; }
+ (NSArray *)supportedMIDIEventTypes { return @[@(MIKMIDIEventTypeExtendedTempo)]; }
+ (Class)immutableCounterpartClass { return [MIKMIDITempoEvent class]; }
+ (Class)mutableCounterpartClass { return [MIKMutableMIDITempoEvent class]; }
+ (BOOL)isMutable { return NO; }
+ (NSData *)initialData { return [NSData dataWithBytes:&(ExtendedTempoEvent){0} length:sizeof(ExtendedTempoEvent)]; }

+ (instancetype)tempoEventWithTimeStamp:(MusicTimeStamp)timeStamp tempo:(Float64)bpm;
{
    ExtendedTempoEvent tempoEvent = { .bpm = bpm };
    NSData *data = [NSData dataWithBytes:&tempoEvent length:sizeof(tempoEvent)];
    return [self midiEventWithTimeStamp:timeStamp eventType:kMusicEventType_ExtendedTempo data:data];
}

- (NSString *)additionalEventDescription
{
	return [NSString stringWithFormat:@"tempo: %g BPM", self.bpm];
}

#pragma mark - Properties

+ (NSSet *)keyPathsForValuesAffectingInternalData
{
	return [NSSet setWithObjects:@"bpm", nil];
}

- (Float64)bpm
{
	ExtendedTempoEvent *tempoEvent = (ExtendedTempoEvent *)[self.data bytes];
	return tempoEvent->bpm;
}

- (void)setBpm:(Float64)bpm
{
	if (![[self class] isMutable]) return MIKMIDI_RAISE_MUTATION_ATTEMPT_EXCEPTION;
	
	ExtendedTempoEvent *tempoEvent = (ExtendedTempoEvent *)[self.internalData bytes];
	tempoEvent->bpm = bpm;
}

@end

@implementation MIKMutableMIDITempoEvent

+ (BOOL)isMutable { return YES; }

@dynamic bpm;
@dynamic timeStamp;
@dynamic data;

@end