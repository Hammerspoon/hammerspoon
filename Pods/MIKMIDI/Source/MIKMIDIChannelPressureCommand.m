//
//  MIKMIDIChannelPressureCommand.m
//  MIKMIDI
//
//  Created by Andrew Madsen on 11/12/15.
//  Copyright © 2015 Mixed In Key. All rights reserved.
//

#import "MIKMIDIChannelPressureCommand.h"
#import "MIKMIDIChannelVoiceCommand_SubclassMethods.h"
#import "MIKMIDIUtilities.h"

@interface MIKMIDIChannelPressureCommand ()

@property (nonatomic, readwrite) NSUInteger pressure;

@end

@implementation MIKMIDIChannelPressureCommand

+ (void)load { [super load]; [MIKMIDICommand registerSubclass:self]; }
+ (NSArray *)supportedMIDICommandTypes { return  @[@(MIKMIDICommandTypeChannelPressure)]; }

+ (Class)immutableCounterpartClass; { return [MIKMIDIChannelPressureCommand class]; }
+ (Class)mutableCounterpartClass; { return [MIKMutableMIDIChannelPressureCommand class]; }

+ (BOOL)isMutable { return NO; }

+ (instancetype)channelPressureCommandWithPressure:(NSUInteger)pressure channel:(UInt8)channel timestamp:(nullable NSDate *)timestamp
{
	MIKMutableMIDIChannelPressureCommand *result = [[MIKMutableMIDIChannelPressureCommand alloc] init];
	result.pressure = pressure;
	result.channel = channel;
	result.timestamp = timestamp ?: [NSDate date];
	
	return [self isMutable] ? result : [result copy];
}

#pragma mark - Properties

- (NSUInteger)pressure { return self.dataByte1; }
- (void)setPressure:(NSUInteger)value
{
	if (![[self class] isMutable]) return MIKMIDI_RAISE_MUTATION_ATTEMPT_EXCEPTION;
	self.dataByte1 = value;
}

@end

#pragma mark -

@implementation MIKMutableMIDIChannelPressureCommand

+ (BOOL)isMutable { return YES; }

#pragma mark - Properties

@dynamic pressure;

// MIKMIDICommand already implements these. This keeps the compiler happy.
@dynamic channel;
@dynamic value;
@dynamic timestamp;
@dynamic dataByte1;
@dynamic dataByte2;
@dynamic midiTimestamp;
@dynamic data;

@end
