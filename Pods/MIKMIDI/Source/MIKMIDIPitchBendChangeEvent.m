//
//  MIKMIDIPitchBendChangeEvent.m
//  MIKMIDI
//
//  Created by Andrew Madsen on 3/4/15.
//  Copyright (c) 2015 Mixed In Key. All rights reserved.
//

#import "MIKMIDIPitchBendChangeEvent.h"
#import "MIKMIDIEvent_SubclassMethods.h"
#import "MIKMIDIUtilities.h"

#if !__has_feature(objc_arc)
#error MIKMIDIPitchBendChangeEvent.m must be compiled with ARC. Either turn on ARC for the project or set the -fobjc-arc flag for MIKMIDIPitchBendChangeEvent.m in the Build Phases for this target
#endif

@interface MIKMIDIChannelEvent (Protected)

@property (nonatomic, readwrite) UInt8 channel;
@property (nonatomic, readwrite) UInt8 dataByte1;
@property (nonatomic, readwrite) UInt8 dataByte2;

@end

@interface MIKMIDIPitchBendChangeEvent ()

@property (nonatomic, readwrite) UInt16 pitchChange;

@end

@implementation MIKMIDIPitchBendChangeEvent

+ (void)load { [MIKMIDIEvent registerSubclass:self]; }
+ (NSArray *)supportedMIDIEventTypes { return @[@(MIKMIDIEventTypeMIDIPitchBendChangeMessage)]; }
+ (Class)immutableCounterpartClass { return [MIKMIDIPitchBendChangeEvent class]; }
+ (Class)mutableCounterpartClass { return [MIKMutableMIDIPitchBendChangeEvent class]; }
+ (BOOL)isMutable { return NO; }
+ (NSData *)initialData
{
	MIDIChannelMessage message = {
		.status = MIKMIDIChannelEventTypePitchBendChange,
		.data1 = 0,
		.data2 = 0,
		.reserved = 0,
	};
	return [NSData dataWithBytes:&message length:sizeof(message)];
}

- (NSString *)additionalEventDescription
{
	return [NSString stringWithFormat:@"pitch change: %u", (unsigned)self.pitchChange];
}

#pragma mark - Properties

+ (NSSet *)keyPathsForValuesAffectingPitchChange
{
	return [NSSet setWithObjects:@"dataByte1", @"dataByte2", nil];
}

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
	self.dataByte2 = pitchChange & 0x3F80;
}

@end

@implementation MIKMutableMIDIPitchBendChangeEvent

@dynamic pitchChange;

@dynamic timeStamp;
@dynamic data;
@dynamic channel;
@dynamic dataByte1;
@dynamic dataByte2;

+ (BOOL)isMutable { return YES; }

@end