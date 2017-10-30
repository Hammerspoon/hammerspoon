//
//  MIKMIDINoteOffCommand.m
//  MIDI Testbed
//
//  Created by Andrew Madsen on 6/2/13.
//  Copyright (c) 2013 Mixed In Key. All rights reserved.
//

#import "MIKMIDINoteOffCommand.h"
#import "MIKMIDIChannelVoiceCommand_SubclassMethods.h"
#import "MIKMIDIUtilities.h"

#if !__has_feature(objc_arc)
#error MIKMIDINoteOffCommand.m must be compiled with ARC. Either turn on ARC for the project or set the -fobjc-arc flag for MIKMIDINoteOffCommand.m in the Build Phases for this target
#endif

@interface MIKMIDINoteOffCommand ()

@property (nonatomic, readwrite) NSUInteger note;
@property (nonatomic, readwrite) NSUInteger velocity;

@end

@implementation MIKMIDINoteOffCommand

+ (void)load { [super load]; [MIKMIDICommand registerSubclass:self]; }
+ (NSArray *)supportedMIDICommandTypes { return @[@(MIKMIDICommandTypeNoteOff)]; }
+ (Class)immutableCounterpartClass; { return [MIKMIDINoteOffCommand class]; }
+ (Class)mutableCounterpartClass; { return [MIKMutableMIDINoteOffCommand class]; }

+ (instancetype)noteOffCommandWithNote:(NSUInteger)note
							  velocity:(NSUInteger)velocity
							   channel:(UInt8)channel
							 timestamp:(NSDate *)timestamp
{
	MIKMutableMIDINoteOffCommand *result = [[MIKMutableMIDINoteOffCommand alloc] init];
	result.note = note;
	result.velocity = velocity;
	result.channel = channel;
	result.timestamp = timestamp ?: [NSDate date];
	
	return [self isMutable] ? result : [result copy];
}

+ (instancetype)noteOffCommandWithNote:(NSUInteger)note
							  velocity:(NSUInteger)velocity
							   channel:(UInt8)channel
						 midiTimeStamp:(MIDITimeStamp)timestamp
{
	MIKMutableMIDINoteOffCommand *result = [[MIKMutableMIDINoteOffCommand alloc] init];
	result.note = note;
	result.velocity = velocity;
	result.channel = channel;
	result.midiTimestamp = timestamp;

	return [self isMutable] ? result : [result copy];
}


- (NSString *)additionalCommandDescription
{
	return [NSString stringWithFormat:@"%@ note: %lu velocity: %lu", [super additionalCommandDescription], (unsigned long)self.note, (unsigned long)self.velocity];
}

#pragma mark - Properties

- (NSUInteger)note { return self.dataByte1; }
- (void)setNote:(NSUInteger)value
{
	if (![[self class] isMutable]) return MIKMIDI_RAISE_MUTATION_ATTEMPT_EXCEPTION;
	self.dataByte1 = (UInt8)value;
}

- (NSUInteger)velocity { return self.value; }
- (void)setVelocity:(NSUInteger)value
{
	if (![[self class] isMutable]) return MIKMIDI_RAISE_MUTATION_ATTEMPT_EXCEPTION;
	self.value = value;
}

@end

@implementation MIKMutableMIDINoteOffCommand

+ (BOOL)isMutable { return YES; }

#pragma mark - Properties

// One of the super classes already implements a getter *and* setter for these. @dynamic keeps the compiler happy.
@dynamic timestamp;
@dynamic midiTimestamp;
@dynamic channel;
@dynamic value;
@dynamic note;
@dynamic velocity;

@end
