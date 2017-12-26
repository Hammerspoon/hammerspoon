//
//  MIKMIDIEventMIDINoteMessage.m
//  MIDI Files Testbed
//
//  Created by Jake Gundersen on 5/21/14.
//  Copyright (c) 2014 Mixed In Key. All rights reserved.
//

#import "MIKMIDINoteEvent.h"
#import "MIKMIDIEvent_SubclassMethods.h"
#import "MIKMIDIUtilities.h"
#import "MIKMIDIClock.h"

#if !__has_feature(objc_arc)
#error MIKMIDINoteEvent.m must be compiled with ARC. Either turn on ARC for the project or set the -fobjc-arc flag for MIKMIDINoteEvent.m in the Build Phases for this target
#endif

@implementation MIKMIDINoteEvent

+ (void)load { [MIKMIDIEvent registerSubclass:self]; }
+ (NSArray *)supportedMIDIEventTypes { return @[@(MIKMIDIEventTypeMIDINoteMessage)]; }
+ (Class)immutableCounterpartClass { return [MIKMIDINoteEvent class]; }
+ (Class)mutableCounterpartClass { return [MIKMutableMIDINoteEvent class]; }
+ (BOOL)isMutable { return NO; }
+ (NSData *)initialData { return [NSData dataWithBytes:&(MIDINoteMessage){0} length:sizeof(MIDINoteMessage)]; }

#pragma mark - Lifecycle

+ (instancetype)noteEventWithTimeStamp:(MusicTimeStamp)timeStamp
								  note:(UInt8)note
							  velocity:(UInt8)velocity
							  duration:(Float32)duration
							   channel:(UInt8)channel
{
	MIDINoteMessage message = {
		.note = note,
		.velocity = velocity,
		.channel = channel,
		.duration = duration,
		.releaseVelocity = 0,
	};
	return [self noteEventWithTimeStamp:timeStamp message:message];
}

+ (instancetype)noteEventWithTimeStamp:(MusicTimeStamp)timeStamp message:(MIDINoteMessage)message
{
    NSData *data = [NSData dataWithBytes:&message length:sizeof(message)];
    return [self midiEventWithTimeStamp:timeStamp eventType:kMusicEventType_MIDINoteMessage data:data];
}

#pragma mark - Properties

+ (NSSet *)keyPathsForValuesAffectingInternalData
{
	return [NSSet setWithObjects:@"note", @"channel", @"velocity", @"releaseVelocity", @"duration", nil];
}

+ (NSSet *)keyPathsForValuesAffectingEndTimeStamp
{
	return [NSSet setWithObjects:@"timeStamp", @"duration", nil];
}

- (UInt8)note
{
    MIDINoteMessage *noteMessage = (MIDINoteMessage*)[self.internalData bytes];
    return noteMessage->note;
}

- (void)setNote:(UInt8)note
{
    if (![[self class] isMutable]) return MIKMIDI_RAISE_MUTATION_ATTEMPT_EXCEPTION;
    
    MIDINoteMessage *noteMessage = (MIDINoteMessage*)[self.internalData bytes];
    noteMessage->note = note;
}

- (UInt8)channel
{
    MIDINoteMessage *noteMessage = (MIDINoteMessage*)[self.internalData bytes];
    return noteMessage->channel;
}

- (void)setChannel:(UInt8)channel
{
    if (![[self class] isMutable]) return MIKMIDI_RAISE_MUTATION_ATTEMPT_EXCEPTION;
    
    MIDINoteMessage *noteMessage = (MIDINoteMessage*)[self.internalData bytes];
    noteMessage->channel = channel;
}

- (UInt8)velocity
{
    MIDINoteMessage *noteMessage = (MIDINoteMessage*)[self.internalData bytes];
    return noteMessage->velocity;
}

- (void)setVelocity:(UInt8)velocity
{
    if (![[self class] isMutable]) return MIKMIDI_RAISE_MUTATION_ATTEMPT_EXCEPTION;
    
    MIDINoteMessage *noteMessage = (MIDINoteMessage*)[self.internalData bytes];
    noteMessage->velocity = velocity;
}

- (UInt8)releaseVelocity
{
    MIDINoteMessage *noteMessage = (MIDINoteMessage*)[self.internalData bytes];
    return noteMessage->releaseVelocity;
}

- (void)setReleaseVelocity:(UInt8)releaseVelocity
{
    if (![[self class] isMutable]) return MIKMIDI_RAISE_MUTATION_ATTEMPT_EXCEPTION;
    
    MIDINoteMessage *noteMessage = (MIDINoteMessage*)[self.internalData bytes];
    noteMessage->releaseVelocity = releaseVelocity;
}

- (Float32)duration
{
    MIDINoteMessage *noteMessage = (MIDINoteMessage*)[self.internalData bytes];
    return noteMessage->duration;
}

- (void)setDuration:(Float32)duration
{
    if (![[self class] isMutable]) return MIKMIDI_RAISE_MUTATION_ATTEMPT_EXCEPTION;
    
    MIDINoteMessage *noteMessage = (MIDINoteMessage*)[self.internalData bytes];
    noteMessage->duration = duration;
}

- (MusicTimeStamp)endTimeStamp
{
	return self.timeStamp + self.duration;
}

- (float)frequency
{
    //tuning based on A4 = 440 hz
    float A = 440.0f;
    return (A / 32.0f) * powf(2.0f, (((float)self.note - 9.0f) / 12.0f));
}

- (NSString *)noteLetter
{
	return MIKMIDINoteLetterForMIDINoteNumber(self.note);
}

- (NSString *)noteLetterAndOctave
{
	return MIKMIDINoteLetterAndOctaveForMIDINote(self.note);
}

- (NSString *)additionalEventDescription
{
    return [NSString stringWithFormat:@"MIDINote: %d, Note: %@, channel %d, duration %f, velocity %d, frequency %f", self.note, self.noteLetter, self.channel, self.duration, self.velocity, self.frequency];
}

@end


@implementation MIKMutableMIDINoteEvent

@dynamic timeStamp;
@dynamic data;
@dynamic note;
@dynamic velocity;
@dynamic channel;
@dynamic releaseVelocity;
@dynamic duration;

+ (BOOL)isMutable { return YES; }

@end

#pragma mark -

@implementation MIKMIDICommand (MIKMIDINoteEventToCommands)

+ (NSArray *)commandsFromNoteEvent:(MIKMIDINoteEvent *)noteEvent clock:(MIKMIDIClock *)clock
{
	if (!clock) {
		clock = [MIKMIDIClock clock];
		[clock syncMusicTimeStamp:noteEvent.timeStamp withMIDITimeStamp:MIKMIDIGetCurrentTimeStamp() tempo:120];
	}

	return @[[self noteOnCommandFromNoteEvent:noteEvent clock:clock], [self noteOffCommandFromNoteEvent:noteEvent clock:clock]];
}

+ (MIKMIDINoteOnCommand *)noteOnCommandFromNoteEvent:(MIKMIDINoteEvent *)noteEvent clock:(MIKMIDIClock *)clock
{
	MIKMutableMIDINoteOnCommand *noteOn = [[MIKMutableMIDINoteOnCommand alloc] init];
	MIDITimeStamp timestamp = clock ? [clock midiTimeStampForMusicTimeStamp:noteEvent.timeStamp] : MIKMIDIGetCurrentTimeStamp();
	noteOn.midiTimestamp = timestamp;
	noteOn.channel = noteEvent.channel;
	noteOn.note = noteEvent.note;
	noteOn.velocity = noteEvent.velocity;
	return [noteOn copy];
}

+ (MIKMIDINoteOffCommand *)noteOffCommandFromNoteEvent:(MIKMIDINoteEvent *)noteEvent clock:(MIKMIDIClock *)clock
{
	MIKMutableMIDINoteOffCommand *noteOff = [[MIKMutableMIDINoteOffCommand alloc] init];
	MIDITimeStamp timestamp = clock ? [clock midiTimeStampForMusicTimeStamp:noteEvent.endTimeStamp] : MIKMIDIGetCurrentTimeStamp();
	noteOff.midiTimestamp = timestamp;
	noteOff.channel = noteEvent.channel;
	noteOff.note = noteEvent.note;
	noteOff.velocity = noteEvent.releaseVelocity;
	return [noteOff copy];
}

@end
