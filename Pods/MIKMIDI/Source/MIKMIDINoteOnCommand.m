//
//  MIKMIDINoteOnCommand.m
//  MIDI Testbed
//
//  Created by Andrew Madsen on 6/2/13.
//  Copyright (c) 2013 Mixed In Key. All rights reserved.
//

#import "MIKMIDINoteOnCommand.h"
#import "MIKMIDINoteCommand_SubclassMethods.h"
#import "MIKMIDIUtilities.h"

#if !__has_feature(objc_arc)
#error MIKMIDINoteOnCommand.m must be compiled with ARC. Either turn on ARC for the project or set the -fobjc-arc flag for MIKMIDINoteOnCommand.m in the Build Phases for this target
#endif


@implementation MIKMIDINoteOnCommand

+ (void)load { [super load]; [MIKMIDICommand registerSubclass:self]; }
+ (NSArray *)supportedMIDICommandTypes { return @[@(MIKMIDICommandTypeNoteOn)]; }
+ (Class)immutableCounterpartClass; { return [MIKMIDINoteOnCommand class]; }
+ (Class)mutableCounterpartClass; { return [MIKMutableMIDINoteOnCommand class]; }

+ (instancetype)noteOnCommandWithNote:(NSUInteger)note
							 velocity:(NSUInteger)velocity
							  channel:(UInt8)channel
							timestamp:(NSDate *)timestamp
{
	return [super noteCommandWithNote:note velocity:velocity channel:channel isNoteOn:YES timestamp:timestamp];
}

+ (instancetype)noteOnCommandWithNote:(NSUInteger)note
							 velocity:(NSUInteger)velocity
							  channel:(UInt8)channel
						midiTimeStamp:(MIDITimeStamp)timestamp
{
	return [super noteCommandWithNote:note velocity:velocity channel:channel isNoteOn:YES midiTimeStamp:timestamp];
}

#pragma mark - Properties

- (BOOL)isNoteOn { return YES; }

- (void)setNoteOn:(BOOL)noteOn
{
	if (![[self class] isMutable]) { return MIKMIDI_RAISE_MUTATION_ATTEMPT_EXCEPTION; }
	
	if (!noteOn) {
		[NSException raise:NSInvalidArgumentException format:@"Instances of MIKMIDINoteOnCommmand must always have a noteOn property value of YES"];
	}
}

@end

@implementation MIKMutableMIDINoteOnCommand

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
