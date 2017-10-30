//
//  MIKMIDIPolyphonicKeyPressureEvent.m
//  MIKMIDI
//
//  Created by Andrew Madsen on 3/4/15.
//  Copyright (c) 2015 Mixed In Key. All rights reserved.
//

#import "MIKMIDIPolyphonicKeyPressureEvent.h"
#import "MIKMIDIEvent_SubclassMethods.h"
#import "MIKMIDIUtilities.h"

#if !__has_feature(objc_arc)
#error MIKMIDIPolyphonicKeyPressureEvent.m must be compiled with ARC. Either turn on ARC for the project or set the -fobjc-arc flag for MIKMIDIPolyphonicKeyPressureEvent.m in the Build Phases for this target
#endif

@interface MIKMIDIChannelEvent (Protected)

@property (nonatomic, readwrite) UInt8 channel;
@property (nonatomic, readwrite) UInt8 dataByte1;
@property (nonatomic, readwrite) UInt8 dataByte2;

@end

@interface MIKMIDIPolyphonicKeyPressureEvent ()

@property (nonatomic, readwrite) UInt8 note;
@property (nonatomic, readwrite) UInt8 pressure;

@end

@implementation MIKMIDIPolyphonicKeyPressureEvent

+ (void)load { [MIKMIDIEvent registerSubclass:self]; }
+ (NSArray *)supportedMIDIEventTypes { return @[@(MIKMIDIEventTypeMIDIPolyphonicKeyPressureMessage)]; }
+ (Class)immutableCounterpartClass { return [MIKMIDIPolyphonicKeyPressureEvent class]; }
+ (Class)mutableCounterpartClass { return [MIKMutableMIDIPolyphonicKeyPressureEvent class]; }
+ (BOOL)isMutable { return NO; }
+ (NSData *)initialData
{
	MIDIChannelMessage message = {
		.status = MIKMIDIChannelEventTypePolyphonicKeyPressure,
		.data1 = 0,
		.data2 = 0,
		.reserved = 0,
	};
	return [NSData dataWithBytes:&message length:sizeof(message)];
}

- (NSString *)additionalEventDescription
{
	return [NSString stringWithFormat:@"note: %u pressure: %u", (unsigned)self.note, (unsigned)self.pressure];
}

#pragma mark - Properties

+ (NSSet *)keyPathsForValuesAffectingNote
{
	return [NSSet setWithObjects:@"dataByte1", nil];
}

- (UInt8)note
{
	return self.dataByte1;
}

- (void)setNote:(UInt8)note
{
	if (![[self class] isMutable]) return MIKMIDI_RAISE_MUTATION_ATTEMPT_EXCEPTION;
	
	self.dataByte1 = MIN(note, 127);
}

+ (NSSet *)keyPathsForValuesAffectingPressure
{
	return [NSSet setWithObjects:@"dataByte2", nil];
}

- (UInt8)pressure
{
	return self.dataByte2;
}

- (void)setPressure:(UInt8)pressure
{
	if (![[self class] isMutable]) return MIKMIDI_RAISE_MUTATION_ATTEMPT_EXCEPTION;
	
	self.dataByte2 = MIN(pressure, 127);
}

@end

@implementation MIKMutableMIDIPolyphonicKeyPressureEvent

@dynamic note;
@dynamic pressure;

@dynamic timeStamp;
@dynamic data;
@dynamic channel;
@dynamic dataByte1;
@dynamic dataByte2;

+ (BOOL)isMutable { return YES; }

@end