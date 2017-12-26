//
//  MIKMIDIControlChangeEvent.m
//  MIKMIDI
//
//  Created by Andrew Madsen on 3/3/15.
//  Copyright (c) 2015 Mixed In Key. All rights reserved.
//

#import "MIKMIDIControlChangeEvent.h"
#import "MIKMIDIEvent_SubclassMethods.h"
#import "MIKMIDIUtilities.h"

#if !__has_feature(objc_arc)
#error MIKMIDIControlChangeEvent.m must be compiled with ARC. Either turn on ARC for the project or set the -fobjc-arc flag for MIKMIDIControlChangeEvent.m in the Build Phases for this target
#endif

@interface MIKMIDIChannelEvent (Protected)

@property (nonatomic, readwrite) UInt8 channel;
@property (nonatomic, readwrite) UInt8 dataByte1;
@property (nonatomic, readwrite) UInt8 dataByte2;

@end

@interface MIKMIDIControlChangeEvent ()

@property (nonatomic, readwrite) NSUInteger controllerNumber;
@property (nonatomic, readwrite) NSUInteger controllerValue;

@end

@implementation MIKMIDIControlChangeEvent

+ (void)load { [MIKMIDIEvent registerSubclass:self]; }
+ (NSArray *)supportedMIDIEventTypes { return @[@(MIKMIDIEventTypeMIDIControlChangeMessage)]; }
+ (Class)immutableCounterpartClass { return [MIKMIDIControlChangeEvent class]; }
+ (Class)mutableCounterpartClass { return [MIKMutableMIDIControlChangeEvent class]; }
+ (BOOL)isMutable { return NO; }
+ (NSData *)initialData
{
	MIDIChannelMessage message = {
		.status = MIKMIDIChannelEventTypeControlChange,
		.data1 = 0,
		.data2 = 0,
		.reserved = 0,
	};
	return [NSData dataWithBytes:&message length:sizeof(message)];
}

- (NSString *)additionalEventDescription
{
	return [NSString stringWithFormat:@"controller number: %lu value: %lu", (unsigned long)self.controllerNumber, (unsigned long)self.controllerValue];
}

#pragma mark - Properties

+ (NSSet *)keyPathsForValuesAffectingControllerNumber
{
	return [NSSet setWithObjects:@"dataByte1", nil];
}

- (NSUInteger)controllerNumber
{
	return self.dataByte1;
}

- (void)setControllerNumber:(NSUInteger)controllerNumber
{
	if (![[self class] isMutable]) return MIKMIDI_RAISE_MUTATION_ATTEMPT_EXCEPTION;
	
	self.dataByte1 = MIN(controllerNumber, 127);
}

+ (NSSet *)keyPathsForValuesAffectingControllerValue
{
	return [NSSet setWithObjects:@"dataByte2", nil];
}

- (NSUInteger)controllerValue
{
	return self.dataByte2;
}

- (void)setControllerValue:(NSUInteger)controllerValue
{
	if (![[self class] isMutable]) return MIKMIDI_RAISE_MUTATION_ATTEMPT_EXCEPTION;
	
	self.dataByte2 = MIN(controllerValue, 127);
}

@end

@implementation MIKMutableMIDIControlChangeEvent

@dynamic controllerNumber;
@dynamic controllerValue;

@dynamic timeStamp;
@dynamic data;
@dynamic channel;
@dynamic dataByte1;
@dynamic dataByte2;

+ (BOOL)isMutable { return YES; }

@end