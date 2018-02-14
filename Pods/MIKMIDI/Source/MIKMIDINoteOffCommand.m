//
//  MIKMIDINoteOffCommand.m
//  MIDI Testbed
//
//  Created by Andrew Madsen on 6/2/13.
//  Copyright (c) 2013 Mixed In Key. All rights reserved.
//

#import "MIKMIDINoteOffCommand.h"
#import "MIKMIDINoteCommand_SubclassMethods.h"
#import "MIKMIDINoteOnCommand.h"
#import "MIKMIDIUtilities.h"

#if !__has_feature(objc_arc)
#error MIKMIDINoteOffCommand.m must be compiled with ARC. Either turn on ARC for the project or set the -fobjc-arc flag for MIKMIDINoteOffCommand.m in the Build Phases for this target
#endif

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
	return [super noteCommandWithNote:note velocity:velocity channel:channel isNoteOn:NO timestamp:timestamp];
}

+ (instancetype)noteOffCommandWithNote:(NSUInteger)note
							  velocity:(NSUInteger)velocity
							   channel:(UInt8)channel
						 midiTimeStamp:(MIDITimeStamp)timestamp
{
	return [super noteCommandWithNote:note velocity:velocity channel:channel isNoteOn:NO midiTimeStamp:timestamp];
}

+ (instancetype _Nullable)noteOffCommandWithNoteCommand:(MIKMIDINoteCommand *)note
{
	if (note.isNoteOn && note.velocity > 0) { return nil; }
	
	return [MIKMIDINoteOffCommand noteOffCommandWithNote:note.note velocity:0 channel:note.channel timestamp:note.timestamp];
}

#pragma mark - Properties

- (BOOL)isNoteOn { return NO; }

- (void)setNoteOn:(BOOL)noteOn
{
	if (![[self class] isMutable]) { return MIKMIDI_RAISE_MUTATION_ATTEMPT_EXCEPTION; }
	
	if (noteOn) {
		[NSException raise:NSInvalidArgumentException format:@"Instances of MIKMIDINoteOffCommmand must always have a noteOn property value of NO"];
	}
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
