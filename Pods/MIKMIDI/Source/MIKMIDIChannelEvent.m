//
//  MIKMIDIChannelEvent.m
//  MIKMIDI
//
//  Created by Andrew Madsen on 3/3/15.
//  Copyright (c) 2015 Mixed In Key. All rights reserved.
//

#import "MIKMIDIChannelEvent.h"
#import "MIKMIDIEvent_SubclassMethods.h"
#import "MIKMIDIUtilities.h"
#import "MIKMIDIClock.h"

#if !__has_feature(objc_arc)
#error MIKMIDIChannelEvent.m must be compiled with ARC. Either turn on ARC for the project or set the -fobjc-arc flag for MIKMIDIChannelEvent.m in the Build Phases for this target
#endif

@interface MIKMIDIChannelEvent ()

@property (nonatomic, readwrite) UInt8 channel;
@property (nonatomic, readwrite) UInt8 dataByte1;
@property (nonatomic, readwrite) UInt8 dataByte2;

@end

@implementation MIKMIDIChannelEvent

+ (void)load { [MIKMIDIEvent registerSubclass:self]; }
+ (NSArray *)supportedMIDIEventTypes { return @[]; }
+ (Class)immutableCounterpartClass { return [MIKMIDIChannelEvent class]; }
+ (Class)mutableCounterpartClass { return [MIKMutableMIDIChannelEvent class]; }
+ (BOOL)isMutable { return NO; }
+ (NSData *)initialData { return [NSData dataWithBytes:&(MIDIChannelMessage){0} length:sizeof(MIDIChannelMessage)]; }

+ (instancetype)channelEventWithTimeStamp:(MusicTimeStamp)timeStamp message:(MIDIChannelMessage)message;
{
	NSData *data = [NSData dataWithBytes:&message length:sizeof(message)];
	return [self midiEventWithTimeStamp:timeStamp eventType:kMusicEventType_MIDIChannelMessage data:data];
}

#pragma mark - Properties

+ (NSSet *)keyPathsForValuesAffectingInternalData
{
	return [NSSet setWithObjects:@"channel", @"dataByte1", @"dataByte2", nil];
}

- (UInt8)channel
{
	MIDIChannelMessage *channelMessage = (MIDIChannelMessage*)[self.internalData bytes];
	return (channelMessage->status & 0x0F);
}

- (void)setChannel:(UInt8)channel
{
	if (![[self class] isMutable]) return MIKMIDI_RAISE_MUTATION_ATTEMPT_EXCEPTION;
	
	MIDIChannelMessage *channelMessage = (MIDIChannelMessage*)[self.internalData bytes];
	channelMessage->status = (channelMessage->status & 0xF0) | (channel & 0x0F);
}

- (UInt8)dataByte1
{
	MIDIChannelMessage *channelMessage = (MIDIChannelMessage*)[self.internalData bytes];
	return channelMessage->data1;
}

- (void)setDataByte1:(UInt8)dataByte1
{
	if (![[self class] isMutable]) return MIKMIDI_RAISE_MUTATION_ATTEMPT_EXCEPTION;
	
	MIDIChannelMessage *channelMessage = (MIDIChannelMessage*)[self.internalData bytes];
	channelMessage->data1 = dataByte1 & 0x7F;
}

- (UInt8)dataByte2
{
	MIDIChannelMessage *channelMessage = (MIDIChannelMessage*)[self.internalData bytes];
	return channelMessage->data2;
}

- (void)setDataByte2:(UInt8)dataByte2
{
	if (![[self class] isMutable]) return MIKMIDI_RAISE_MUTATION_ATTEMPT_EXCEPTION;
	
	MIDIChannelMessage *channelMessage = (MIDIChannelMessage*)[self.internalData bytes];
	channelMessage->data2 = dataByte2 & 0x7F;
}

@end

@implementation MIKMutableMIDIChannelEvent

@dynamic timeStamp;
@dynamic data;
@dynamic channel;
@dynamic dataByte1;
@dynamic dataByte2;

+ (BOOL)isMutable { return YES; }

@end

#pragma mark - MIKMIDICommand+MIKMIDIChannelEventToCommands

#import "MIKMIDIPolyphonicKeyPressureCommand.h"
#import "MIKMIDIControlChangeCommand.h"
#import "MIKMIDIProgramChangeCommand.h"
#import "MIKMIDIChannelPressureCommand.h"
#import "MIKMIDIPitchBendChangeCommand.h"

@implementation MIKMIDICommand (MIKMIDIChannelEventToCommands)

+ (instancetype)commandFromChannelEvent:(MIKMIDIChannelEvent *)event clock:(MIKMIDIClock *)clock
{
	NSDictionary *classes = @{@(MIKMIDIEventTypeMIDIPolyphonicKeyPressureMessage) : [MIKMIDIPolyphonicKeyPressureCommand class],
							  @(MIKMIDIEventTypeMIDIControlChangeMessage) : [MIKMIDIControlChangeCommand class],
							  @(MIKMIDIEventTypeMIDIProgramChangeMessage) : [MIKMIDIProgramChangeCommand class],
							  @(MIKMIDIEventTypeMIDIChannelPressureMessage) : [MIKMIDIChannelPressureCommand class],
							  @(MIKMIDIEventTypeMIDIPitchBendChangeMessage) : [MIKMIDIPitchBendChangeCommand class]};
	Class commandClass = classes[@(event.eventType)];
	if (!commandClass) return nil;
	
	MIKMutableMIDIChannelVoiceCommand *result = [[[commandClass mutableCounterpartClass] alloc] init];
	result.channel = event.channel;
	result.dataByte1 = event.dataByte1;
	result.dataByte2 = event.dataByte2;
	result.midiTimestamp = [clock midiTimeStampForMusicTimeStamp:event.timeStamp];
	
	return [result copy];
}

@end
