//
//  MIKMIDIPolyphonicKeyPressureCommand.m
//  MIKMIDI
//
//  Created by Andrew Madsen on 11/12/15.
//  Copyright © 2015 Mixed In Key. All rights reserved.
//

#import "MIKMIDIPolyphonicKeyPressureCommand.h"
#import "MIKMIDIChannelVoiceCommand_SubclassMethods.h"
#import "MIKMIDIUtilities.h"

@interface MIKMIDIPolyphonicKeyPressureCommand ()

@property (nonatomic, readwrite) NSUInteger note;
@property (nonatomic, readwrite) NSUInteger pressure;

@end

@implementation MIKMIDIPolyphonicKeyPressureCommand

+ (void)load { [super load]; [MIKMIDICommand registerSubclass:self]; }
+ (NSArray *)supportedMIDICommandTypes { return  @[@(MIKMIDICommandTypePolyphonicKeyPressure)]; }

+ (Class)immutableCounterpartClass; { return [MIKMIDIPolyphonicKeyPressureCommand class]; }
+ (Class)mutableCounterpartClass; { return [MIKMutableMIDIPolyphonicKeyPressureCommand class]; }

+ (BOOL)isMutable { return NO; }

#pragma mark - Properties

- (NSUInteger)note { return self.dataByte1; }
- (void)setNote:(NSUInteger)value
{
	if (![[self class] isMutable]) return MIKMIDI_RAISE_MUTATION_ATTEMPT_EXCEPTION;
	self.dataByte1 = (UInt8)value;
}

- (NSUInteger)pressure { return self.value; }
- (void)setPressure:(NSUInteger)value
{
	if (![[self class] isMutable]) return MIKMIDI_RAISE_MUTATION_ATTEMPT_EXCEPTION;
	self.value = value;
}

@end

#pragma mark -

@implementation MIKMutableMIDIPolyphonicKeyPressureCommand

+ (BOOL)isMutable { return YES; }

#pragma mark - Properties

@dynamic note;
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
