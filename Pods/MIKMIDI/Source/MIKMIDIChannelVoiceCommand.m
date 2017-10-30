
//
//  MIKMIDIChannelVoiceCommand.m
//  MIDI Testbed
//
//  Created by Andrew Madsen on 6/2/13.
//  Copyright (c) 2013 Mixed In Key. All rights reserved.
//

#import "MIKMIDIChannelVoiceCommand.h"
#import "MIKMIDICommand_SubclassMethods.h"
#import "MIKMIDIUtilities.h"

#if !__has_feature(objc_arc)
#error MIKMIDIChannelVoiceCommand.m must be compiled with ARC. Either turn on ARC for the project or set the -fobjc-arc flag for MIKMIDIChannelVoiceCommand.m in the Build Phases for this target
#endif

@interface MIKMIDIChannelVoiceCommand ()

@property (nonatomic, readwrite) UInt8 channel;
@property (nonatomic, readwrite) NSUInteger value;

@end

@implementation MIKMIDIChannelVoiceCommand

+ (void)load { [super load]; [MIKMIDICommand registerSubclass:self]; }
+ (NSArray *)supportedMIDICommandTypes { return  @[]; }

+ (Class)immutableCounterpartClass; { return [MIKMIDIChannelVoiceCommand class]; }
+ (Class)mutableCounterpartClass; { return [MIKMutableMIDIChannelVoiceCommand class]; }

- (instancetype)initWithMIDIPacket:(MIDIPacket *)packet
{
	self = [super initWithMIDIPacket:packet];
	if (self) {
		if (!packet) {
			if ([self.internalData length] < 2) [self.internalData increaseLengthBy:2-[self.internalData length]];
			UInt8 *data = (UInt8 *)[self.internalData mutableBytes];
			data[0] &= 0xF0; // Set channel to 0
		}
	}
	return self;
}

- (NSString *)additionalCommandDescription
{
	return [NSString stringWithFormat:@"channel %d", self.channel];
}

#pragma mark - Properties

- (UInt8)channel
{
	if ([self.internalData length] < 1) return 0;
	UInt8 *data = (UInt8 *)[self.internalData mutableBytes];
	return data[0] & 0x0F;
}

- (void)setChannel:(UInt8)channel
{
	if (![[self class] isMutable]) return MIKMIDI_RAISE_MUTATION_ATTEMPT_EXCEPTION;
	
	if ([self.internalData length] < 2) [self.internalData increaseLengthBy:2-[self.internalData length]];
	
	UInt8 *data = (UInt8 *)[self.internalData mutableBytes];
	data[0] = (0xF0 & data[0]) | (channel & 0x0F);
}

- (NSUInteger)value { return self.dataByte2 & 0x7F; }

- (void)setValue:(NSUInteger)value
{
	if (![[self class] isMutable]) return MIKMIDI_RAISE_MUTATION_ATTEMPT_EXCEPTION;
	
	self.dataByte2 = value & 0x7F;
}

@end

@implementation MIKMutableMIDIChannelVoiceCommand

+ (BOOL)isMutable { return YES; }

- (NSString *)description
{
	return [NSString stringWithFormat:@"%@ channel %d", [super description], self.channel];
}

#pragma mark - Properties

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
    data[0] = (0xF0 & commandType) | (data[0] & 0x0F);
}

@end
