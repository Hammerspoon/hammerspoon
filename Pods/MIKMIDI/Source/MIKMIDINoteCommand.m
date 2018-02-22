//
//  MIKMIDINoteCommand.m
//  MIKMIDI
//
//  Created by Andrew R Madsen on 9/18/17.
//  Copyright © 2017 Mixed In Key. All rights reserved.
//

#import "MIKMIDINoteCommand.h"
#import "MIKMIDIChannelVoiceCommand_SubclassMethods.h"
#import "MIKMIDIUtilities.h"
#import "MIKMIDINoteOnCommand.h"
#import "MIKMIDINoteOffCommand.h"

#if !__has_feature(objc_arc)
#error MIKMIDINoteOnCommand.m must be compiled with ARC. Either turn on ARC for the project or set the -fobjc-arc flag for MIKMIDINoteOnCommand.m in the Build Phases for this target
#endif

@interface MIKMIDINoteCommand ()

@property (nonatomic, readwrite) NSUInteger note;
@property (nonatomic, readwrite) NSUInteger velocity;

@end

@implementation MIKMIDINoteCommand

//+ (void)load { [super load]; [MIKMIDICommand registerSubclass:self]; }
//+ (NSArray *)supportedMIDICommandTypes { return @[@(MIKMIDICommandTypeNoteOn), @(MIKMIDICommandTypeNoteOff)]; }
+ (Class)immutableCounterpartClass; { return [MIKMIDINoteOnCommand class]; }
+ (Class)mutableCounterpartClass; { return [MIKMutableMIDINoteOnCommand class]; }

- (instancetype)init
{
	if (![self isKindOfClass:[MIKMIDINoteOnCommand class]] && ![self isKindOfClass:[MIKMIDINoteOffCommand class]] ) {
		[NSException raise:NSInternalInconsistencyException format:@"MIKMIDINoteCommand is an abstract base class for MIKMIDINoteOnCommand and MIKMIDINoteOffCommand. Initialize one of those, or use -initWithMIDIPacket instead."];
		return nil;
	} else {
		return [super init];
	}
}

+ (instancetype)noteCommandWithNote:(NSUInteger)note
						   velocity:(NSUInteger)velocity
							channel:(UInt8)channel
						   isNoteOn:(BOOL)isNoteOn
						  timestamp:(NSDate *)timestamp
{
	Class resultClass = isNoteOn ? [MIKMutableMIDINoteOnCommand class] : [MIKMutableMIDINoteOffCommand class];
	MIKMutableMIDINoteCommand *result = [[resultClass alloc] init];
	result.note = note;
	result.velocity = velocity;
	result.channel = channel;
	result.timestamp = timestamp ?: [NSDate date];
	
	return [self isMutable] ? result : [result copy];
}

+ (instancetype)noteCommandWithNote:(NSUInteger)note
						   velocity:(NSUInteger)velocity
							channel:(UInt8)channel
						   isNoteOn:(BOOL)isNoteOn
					  midiTimeStamp:(MIDITimeStamp)timestamp
{
	Class resultClass = isNoteOn ? [MIKMutableMIDINoteOnCommand class] : [MIKMutableMIDINoteOffCommand class];
	MIKMutableMIDINoteCommand *result = [[resultClass alloc] init];
	result.note = note;
	result.velocity = velocity;
	result.channel = channel;
	result.midiTimestamp = timestamp;
	
	return [self isMutable] ? result : [result copy];
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

- (NSString *)additionalCommandDescription
{
	return [NSString stringWithFormat:@"%@ note: %lu velocity: %lu", [super additionalCommandDescription], (unsigned long)self.note, (unsigned long)self.velocity];
}

@end

@implementation MIKMutableMIDINoteCommand

+ (BOOL)isMutable { return YES; }

#pragma mark - Properties

// One of the super classes already implements a getter *and* setter for these. @dynamic keeps the compiler happy.
@dynamic timestamp;
@dynamic midiTimestamp;
@dynamic channel;
@dynamic value;
@dynamic note;
@dynamic velocity;
@dynamic noteOn;

@end
