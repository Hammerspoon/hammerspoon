//
//  MIKMIDIPitchBendChangeCommand.m
//  MIKMIDI
//
//  Created by Andrew Madsen on 3/5/15.
//  Copyright (c) 2015 Mixed In Key. All rights reserved.
//

#import "MIKMIDIPitchBendChangeCommand.h"
#import "MIKMIDIChannelVoiceCommand_SubclassMethods.h"
#import "MIKMIDIUtilities.h"

#if !__has_feature(objc_arc)
#error MIKMIDIPitchBendChangeCommand.m must be compiled with ARC. Either turn on ARC for the project or set the -fobjc-arc flag for MIKMIDIPitchBendChangeCommand.m in the Build Phases for this target
#endif

@interface MIKMIDIPitchBendChangeCommand ()

@end

@implementation MIKMIDIPitchBendChangeCommand

+ (void)load { [super load]; [MIKMIDICommand registerSubclass:self]; }
+ (NSArray *)supportedMIDICommandTypes { return @[@(MIKMIDICommandTypePitchWheelChange)]; }
+ (Class)immutableCounterpartClass; { return [MIKMIDIPitchBendChangeCommand class]; }
+ (Class)mutableCounterpartClass; { return [MIKMutableMIDIPitchBendChangeCommand class]; }
+ (BOOL)isMutable { return NO; }

- (NSString *)additionalCommandDescription
{
	return [NSString stringWithFormat:@"pitch change: %u", (unsigned)self.pitchChange];
}

#pragma mark - Properties

- (UInt16)pitchChange
{
	UInt16 ms7 = (self.dataByte2 << 7) & 0x3F80;
	UInt16 ls7 = self.dataByte1 & 0x007F;
	return ms7 | ls7;
}

- (void)setPitchChange:(UInt16)pitchChange
{
	if (![[self class] isMutable]) return MIKMIDI_RAISE_MUTATION_ATTEMPT_EXCEPTION;
	
	pitchChange = MIN(pitchChange, 0x3FFF);
	self.dataByte1 = pitchChange & 0x007F;
	self.dataByte2 = (pitchChange & 0x3F80) >> 7;
}

@end

#pragma mark -

@implementation MIKMutableMIDIPitchBendChangeCommand

+ (BOOL)isMutable { return YES; }

- (NSString *)description
{
	return [NSString stringWithFormat:@"%@ channel %d", [super description], self.channel];
}

#pragma mark - Properties

@dynamic pitchChange;

// MIKMIDICommand already implements these. This keeps the compiler happy.
@dynamic channel;
@dynamic value;
@dynamic timestamp;
@dynamic dataByte1;
@dynamic dataByte2;
@dynamic midiTimestamp;
@dynamic data;

@dynamic commandType;
- (void)setCommandType:(MIKMIDICommandType)commandType
{
	if ([self.internalData length] < 2) [self.internalData increaseLengthBy:2-[self.internalData length]];
	
	UInt8 *data = (UInt8 *)[self.internalData mutableBytes];
	data[0] &= 0x0F | (commandType & 0xF0); // Need to avoid changing channel
}

@end