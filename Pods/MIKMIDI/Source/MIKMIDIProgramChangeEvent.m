//
//  MIKMIDIProgramChangeEvent.m
//  MIKMIDI
//
//  Created by Andrew Madsen on 3/4/15.
//  Copyright (c) 2015 Mixed In Key. All rights reserved.
//

#import "MIKMIDIProgramChangeEvent.h"
#import "MIKMIDIEvent_SubclassMethods.h"
#import "MIKMIDIUtilities.h"

@interface MIKMIDIChannelEvent (Protected)

@property (nonatomic, readwrite) UInt8 channel;
@property (nonatomic, readwrite) UInt8 dataByte1;
@property (nonatomic, readwrite) UInt8 dataByte2;

@end

@interface MIKMIDIProgramChangeEvent ()

@property (nonatomic, readwrite) NSUInteger programNumber;

@end

@implementation MIKMIDIProgramChangeEvent

+ (void)load { [MIKMIDIEvent registerSubclass:self]; }
+ (NSArray *)supportedMIDIEventTypes { return @[@(MIKMIDIEventTypeMIDIProgramChangeMessage)]; }
+ (Class)immutableCounterpartClass { return [MIKMIDIProgramChangeEvent class]; }
+ (Class)mutableCounterpartClass { return [MIKMutableMIDIProgramChangeEvent class]; }
+ (BOOL)isMutable { return NO; }
+ (NSData *)initialData
{
	MIDIChannelMessage message = {
		.status = MIKMIDIChannelEventTypeProgramChange,
		.data1 = 0,
		.data2 = 0,
		.reserved = 0,
	};
	return [NSData dataWithBytes:&message length:sizeof(message)];
}

- (NSString *)additionalEventDescription
{
	return [NSString stringWithFormat:@"program number: %lu", (unsigned long)self.programNumber];
}

#pragma mark - Properties

+ (NSSet *)keyPathsForValuesAffectingProgramNumber
{
	return [NSSet setWithObjects:@"dataByte1", nil];
}

- (NSUInteger)programNumber
{
	return self.dataByte1;
}

- (void)setProgramNumber:(NSUInteger)programNumber
{
	if (![[self class] isMutable]) return MIKMIDI_RAISE_MUTATION_ATTEMPT_EXCEPTION;
	
	self.dataByte1 = MIN(programNumber, 127);
}

@end

@implementation MIKMutableMIDIProgramChangeEvent

@dynamic programNumber;

@dynamic timeStamp;
@dynamic data;
@dynamic channel;
@dynamic dataByte1;
@dynamic dataByte2;

+ (BOOL)isMutable { return YES; }

@end