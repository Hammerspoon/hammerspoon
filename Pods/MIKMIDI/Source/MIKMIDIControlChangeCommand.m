//
//  MIKMIDIControlChangeCommand.m
//  MIDI Testbed
//
//  Created by Andrew Madsen on 6/2/13.
//  Copyright (c) 2013 Mixed In Key. All rights reserved.
//

#import "MIKMIDIControlChangeCommand.h"
#import "MIKMIDIChannelVoiceCommand_SubclassMethods.h"
#import "MIKMIDIUtilities.h"

#if !__has_feature(objc_arc)
#error MIKMIDIControlChangeCommand.m must be compiled with ARC. Either turn on ARC for the project or set the -fobjc-arc flag for MIKMIDIControlChangeCommand.m in the Build Phases for this target
#endif

@interface MIKMIDIControlChangeCommand ()

@property (nonatomic, readwrite) NSUInteger controllerNumber;
@property (nonatomic, readwrite) NSUInteger controllerValue;

@property (nonatomic, readwrite) NSUInteger fourteenBitValue;
@property (nonatomic, readwrite, getter = isFourteenBitCommand) BOOL fourteenBitCommand;

@end

@implementation MIKMIDIControlChangeCommand

+ (void)load { [super load]; [MIKMIDICommand registerSubclass:self]; }
+ (NSArray *)supportedMIDICommandTypes { return @[@(MIKMIDICommandTypeControlChange)]; }
+ (Class)immutableCounterpartClass; { return [MIKMIDIControlChangeCommand class]; }
+ (Class)mutableCounterpartClass; { return [MIKMutableMIDIControlChangeCommand class]; }

+ (instancetype)controlChangeCommandWithControllerNumber:(NSUInteger)controllerNumber value:(NSUInteger)sevenBitValue
{
	MIKMutableMIDIControlChangeCommand *command = [[[self mutableCounterpartClass] alloc] init];
	command.controllerNumber = controllerNumber;
	command.controllerValue = sevenBitValue;
	if (![[self class] isMutable]) { command = [command copy]; }
	return command;
}

+ (instancetype)fourteenBitControlChangeCommandWithControllerNumber:(NSUInteger)controllerNumber value:(NSUInteger)fourteenBitValue
{
	MIKMutableMIDIControlChangeCommand *command = [[[self mutableCounterpartClass] alloc] init];
	command.fourteenBitCommand = YES;
	command.controllerNumber = controllerNumber;
	command.fourteenBitValue = fourteenBitValue;
	if (![[self class] isMutable]) { command = [command copy]; }
	return command;
}

+ (instancetype)commandByCoalescingMSBCommand:(MIKMIDIControlChangeCommand *)msbCommand andLSBCommand:(MIKMIDIControlChangeCommand *)lsbCommand;
{
	if (!msbCommand || !lsbCommand) return nil;
	
	if (![msbCommand isKindOfClass:[MIKMIDIControlChangeCommand class]] ||
		![lsbCommand isKindOfClass:[MIKMIDIControlChangeCommand class]]) return nil;
	
	if (msbCommand.controllerNumber > 31) return nil;
	if (lsbCommand.controllerNumber < 32 || lsbCommand.controllerNumber > 63) return nil;
	
	if (lsbCommand.controllerNumber - msbCommand.controllerNumber != 32) return nil;
	
	MIKMIDIControlChangeCommand *result = [[MIKMIDIControlChangeCommand alloc] init];
	result.midiTimestamp = lsbCommand.midiTimestamp;
	result.internalData = [msbCommand.data mutableCopy];
	result->_fourteenBitCommand = YES;
	[result.internalData appendData:[lsbCommand.data subdataWithRange:NSMakeRange(2, 1)]];
	
	return result;
}

-(NSString *)additionalCommandDescription
{
	if (self.isFourteenBitCommand) {
		return [NSString stringWithFormat:@"%@ control number: %lu value: %f 14-bit? %i", [super additionalCommandDescription], (unsigned long)self.controllerNumber, (float)self.fourteenBitValue / 128.0f, self.isFourteenBitCommand];
	} else {
		return [NSString stringWithFormat:@"%@ control number: %lu value: %lu 14-bit? %i", [super additionalCommandDescription], (unsigned long)self.controllerNumber, (unsigned long)self.controllerValue, self.isFourteenBitCommand];
	}
}

- (id)copyWithZone:(NSZone *)zone
{
	MIKMIDIControlChangeCommand *result = [super copyWithZone:zone];
	result->_fourteenBitCommand = self.isFourteenBitCommand;
	return result;
}

- (id)mutableCopy
{
	MIKMIDIControlChangeCommand *result = [super mutableCopy];
	result->_fourteenBitCommand = self.isFourteenBitCommand;
	return result;
}

- (MIKMIDIControlChangeCommand *)commandForMostSignificantBits
{
	MIKMutableMIDIControlChangeCommand *result = [self mutableCopy];
	result.fourteenBitCommand = NO;
	return [result copy];
}

- (MIKMIDIControlChangeCommand *)commandForLeastSignificantBits
{
	if (self.controllerNumber > 31) { return nil; }
	if ([self.data length] <= 3) { return nil; }
	UInt8 *data = (UInt8 *)[self.data bytes];
	NSUInteger LSB = data[3] & 0x7F;
	
	MIKMutableMIDIControlChangeCommand *result = [self mutableCopy];
	result.fourteenBitCommand = NO;
	result.controllerNumber += 32;
	result.controllerValue = LSB;
	
	return [result copy];
}

- (NSArray *)commandsForTransmission
{
	if (!self.isFourteenBitCommand) { return @[self]; }
	
	// Split 14-bit CC command
	MIKMIDIControlChangeCommand *msb = [self commandForMostSignificantBits];
	MIKMIDIControlChangeCommand *lsb = [self commandForLeastSignificantBits];
	if (msb && lsb) { return @[msb, lsb]; }
	
	return @[self];
}

#pragma mark - Private

#pragma mark - Properties

- (NSUInteger)controllerNumber { return self.dataByte1; }

- (void)setControllerNumber:(NSUInteger)value
{
	if (![[self class] isMutable]) return MIKMIDI_RAISE_MUTATION_ATTEMPT_EXCEPTION;
	self.dataByte1 = (UInt8)value;
}

- (NSUInteger)controllerValue { return self.value; }

- (void)setControllerValue:(NSUInteger)value
{
	if (![[self class] isMutable]) return MIKMIDI_RAISE_MUTATION_ATTEMPT_EXCEPTION;
	
	self.value = value;
}

- (void)setFourteenBitCommand:(BOOL)fourteenBitCommand
{
	if (![[self class] isMutable]) return MIKMIDI_RAISE_MUTATION_ATTEMPT_EXCEPTION;
	
	if (fourteenBitCommand != _fourteenBitCommand) {
		_fourteenBitCommand = fourteenBitCommand;
		if (_fourteenBitCommand) {
			[self setFourteenBitValue:(self.controllerValue << 7) & 0x7F];
		} else {
			// Shrink internal data
			if ([self.internalData length] >= 4) {
				[self.internalData replaceBytesInRange:NSMakeRange(3, [self.internalData length] - 3) withBytes:NULL length:0];
			}
		}
	}
}

- (NSUInteger)fourteenBitValue
{
	NSUInteger MSB = ([super value] << 7) & 0x3F80;
	NSUInteger LSB = 0;
	if ([self.data length] > 3) {
		UInt8 *data = (UInt8 *)[self.data bytes];
		LSB = data[3] & 0x7F;
	}
	
	return MSB + LSB;
}

- (void)setFourteenBitValue:(NSUInteger)value
{
	if (![[self class] isMutable]) return MIKMIDI_RAISE_MUTATION_ATTEMPT_EXCEPTION;
	
	NSUInteger MSB = (value >> 7) & 0x7F;
	NSUInteger LSB = self.isFourteenBitCommand ? value & 0x7F : 0;
	
	[super setValue:MSB];
	if ([self.internalData length] < 4) [self.internalData increaseLengthBy:4-[self.internalData length]];
	[self.internalData replaceBytesInRange:NSMakeRange(3, 1) withBytes:&LSB length:1];
}

@dynamic channel; // MIKMIDIChannelVoiceCommand already implements a getter *and* setter for this. This keeps the compiler happy.

@end

@implementation MIKMutableMIDIControlChangeCommand

+ (BOOL)isMutable { return YES; }

#pragma mark - Properties

// One of the super classes already implements a getter *and* setter for these. @dynamic keeps the compiler happy.
@dynamic channel;
@dynamic value;
@dynamic controllerNumber;
@dynamic controllerValue;
@dynamic fourteenBitCommand;
@dynamic fourteenBitValue;
@dynamic timestamp;
@dynamic midiTimestamp;
@dynamic commandType;
@dynamic dataByte1;
@dynamic dataByte2;
@dynamic data;

@end
