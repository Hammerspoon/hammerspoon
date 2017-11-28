//
//  MIKMIDIChannelPressureEvent.m
//  MIKMIDI
//
//  Created by Andrew Madsen on 3/4/15.
//  Copyright (c) 2015 Mixed In Key. All rights reserved.
//

#import "MIKMIDIChannelPressureEvent.h"
#import "MIKMIDIEvent_SubclassMethods.h"
#import "MIKMIDIUtilities.h"

#if !__has_feature(objc_arc)
#error MIKMIDIChannelPressureEvent.m must be compiled with ARC. Either turn on ARC for the project or set the -fobjc-arc flag for MIKMIDIChannelPressureEvent.m in the Build Phases for this target
#endif

@interface MIKMIDIChannelEvent (Protected)

@property (nonatomic, readwrite) UInt8 channel;
@property (nonatomic, readwrite) UInt8 dataByte1;
@property (nonatomic, readwrite) UInt8 dataByte2;

@end

@interface MIKMIDIChannelPressureEvent ()

@property (nonatomic, readwrite) UInt8 pressure;

@end

@implementation MIKMIDIChannelPressureEvent

+ (void)load { [MIKMIDIEvent registerSubclass:self]; }
+ (NSArray *)supportedMIDIEventTypes { return @[@(MIKMIDIEventTypeMIDIChannelPressureMessage)]; }
+ (Class)immutableCounterpartClass { return [MIKMIDIChannelPressureEvent class]; }
+ (Class)mutableCounterpartClass { return [MIKMutableMIDIChannelPressureEvent class]; }
+ (BOOL)isMutable { return NO; }
+ (NSData *)initialData
{
	MIDIChannelMessage message = {
		.status = MIKMIDIChannelEventTypeChannelPressure,
		.data1 = 0,
		.data2 = 0,
		.reserved = 0,
	};
	return [NSData dataWithBytes:&message length:sizeof(message)];
}

- (NSString *)additionalEventDescription
{
	return [NSString stringWithFormat:@"pressure: %u", (unsigned)self.pressure];
}

#pragma mark - Properties

+ (NSSet *)keyPathsForValuesAffectingPressure
{
	return [NSSet setWithObjects:@"dataByte1", nil];
}

- (UInt8)pressure
{
	return self.dataByte1;
}

- (void)setPressure:(UInt8)pressure
{
	if (![[self class] isMutable]) return MIKMIDI_RAISE_MUTATION_ATTEMPT_EXCEPTION;
	
	self.dataByte1 = MIN(pressure, 127);
}

@end

@implementation MIKMutableMIDIChannelPressureEvent

@dynamic pressure;

@dynamic timeStamp;
@dynamic data;
@dynamic channel;
@dynamic dataByte1;
@dynamic dataByte2;

+ (BOOL)isMutable { return YES; }

@end