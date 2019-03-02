//
//  MIKMIDIEvent.m
//  MIDI Files Testbed
//
//  Created by Jake Gundersen on 5/21/14.
//  Copyright (c) 2014 Mixed In Key. All rights reserved.
//

#import "MIKMIDIEvent.h"
#import "MIKMIDIEvent_SubclassMethods.h"
#import "MIKMIDIMetaEvent.h"
#import "MIKMIDIUtilities.h"

#if !__has_feature(objc_arc)
#error MIKMIDIEvent.m must be compiled with ARC. Either turn on ARC for the project or set the -fobjc-arc flag for MIKMIDIEvent.m in the Build Phases for this target
#endif

static NSMutableSet *registeredMIKMIDIEventSubclasses;

@implementation MIKMIDIEvent

+ (BOOL)supportsMIKMIDIEventType:(MIKMIDIEventType)type { return [[self supportedMIDIEventTypes] containsObject:@(type)]; }
+ (NSArray *)supportedMIDIEventTypes { return @[]; }
+ (Class)immutableCounterpartClass; { return [MIKMIDIEvent class]; }
+ (Class)mutableCounterpartClass; { return [MIKMutableMIDIEvent class]; }
+ (BOOL)isMutable { return NO; }
+ (NSData *)initialData { return [NSData data]; }

+ (instancetype)midiEventWithTimeStamp:(MusicTimeStamp)timeStamp eventType:(MusicEventType)eventType data:(NSData *)data
{
	MIKMIDIEventType midiEventType = [[self class] mikEventTypeForMusicEventType:eventType andData:data];
	// -initWithTimeStamp:midiEventType:data: will do subclass lookup too, but this way we avoid a second alloc
	Class subclass = [[self class] subclassForEventType:midiEventType];
	if (!subclass) subclass = self;
	if ([self isMutable]) subclass = [subclass mutableCounterpartClass];
	return [[subclass alloc] initWithTimeStamp:timeStamp midiEventType:midiEventType data:data];
}

- (id)init
{
	MIKMIDIEventType eventType = (MIKMIDIEventType)[[[[self class] supportedMIDIEventTypes] firstObject] unsignedIntegerValue];
	return [self initWithTimeStamp:0 midiEventType:eventType data:nil];
}

- (instancetype)initWithTimeStamp:(MusicTimeStamp)timeStamp midiEventType:(MIKMIDIEventType)eventType data:(NSData *)data
{
	// If we don't directly support eventType, return an instance of an MIKMIDIEvent subclass that does.
	if (![[[self class] supportedMIDIEventTypes] containsObject:@(eventType)]) {
		BOOL isMutable = [[self class] isMutable];
		Class subclass = [[self class] subclassForEventType:eventType];
		if (!subclass) subclass = [MIKMIDIEvent class];
		if (isMutable) subclass = [subclass mutableCounterpartClass];
		self = [subclass alloc];
	}
	
	self = [super init];
	if (self) {
		_timeStamp = timeStamp;
		_eventType = eventType;
		
		if (!data) data = [[self class] initialData];
		_internalData = [NSMutableData dataWithData:data];
	}
	return self;
}

- (instancetype)initWithTimeStamp:(MusicTimeStamp)timeStamp midiEventType:(MIKMIDIEventType)eventType
{
	return [self initWithTimeStamp:timeStamp midiEventType:eventType data:nil];
}

- (NSString *)additionalEventDescription
{
	return @"";
}

- (NSString *)description
{
	NSString *additionalDescription = [self additionalEventDescription];
	if ([additionalDescription length] > 0) {
		additionalDescription = [NSString stringWithFormat:@"%@ ", additionalDescription];
	}
	return [NSString stringWithFormat:@"%@ Timestamp: %f Type: %u, %@", [super description], self.timeStamp, (unsigned int)self.eventType, additionalDescription];
}

#pragma mark - Equality

- (BOOL)isEqual:(id)object
{
	if (object == self) return YES;
	if (![object isKindOfClass:[MIKMIDIEvent class]]) return NO;
	
	MIKMIDIEvent *otherEvent = (MIKMIDIEvent *)object;
	if (otherEvent.eventType != self.eventType) return NO;
	return (self.timeStamp == otherEvent.timeStamp && [self.internalData isEqualToData:otherEvent.internalData]);
}

- (NSUInteger)hash
{
	MusicTimeStamp timestamp = self.timeStamp;
	if (timestamp == 0) return [self.data hash];
	return (NSUInteger)(timestamp * [self.data hash]);
}

#pragma mark - Private

#pragma mark Subclass Management

+ (void)registerSubclass:(Class)subclass;
{
	static dispatch_once_t onceToken;
	dispatch_once(&onceToken, ^{
		registeredMIKMIDIEventSubclasses = [[NSMutableSet alloc] init];
	});
	[registeredMIKMIDIEventSubclasses addObject:subclass];
	[self cacheSubclassesByEvent];
}

+ (void)unregisterSubclass:(Class)subclass;
{
	[registeredMIKMIDIEventSubclasses removeObject:subclass];
	[self cacheSubclassesByEvent];
}

+ (NSMutableDictionary *)subclassesByEventCache
{
	static NSMutableDictionary *subclassesByEventCache = nil;
	static dispatch_once_t onceToken;
	dispatch_once(&onceToken, ^{ subclassesByEventCache = [[NSMutableDictionary alloc] init]; });
	return subclassesByEventCache;
}

+ (void)cacheSubclassesByEvent
{
	[[self subclassesByEventCache] removeAllObjects];
	
	// Regenerate cache
	for (Class eachSubclass in registeredMIKMIDIEventSubclasses) {
		for (NSNumber *eventType in [eachSubclass supportedMIDIEventTypes]) {
			[[self subclassesByEventCache] setObject:eachSubclass forKey:eventType];
		}
	}
}

+ (MIKMIDIEventType)mikEventTypeForMusicEventType:(MusicEventType)musicEventType andData:(NSData *)data
{
	static NSDictionary *channelEventTypeToMIDITypeMap = nil;
	static NSDictionary *musicEventToMIDITypeMap = nil;
	static dispatch_once_t onceToken;
	dispatch_once(&onceToken, ^{
		channelEventTypeToMIDITypeMap = @{@(MIKMIDIChannelEventTypePolyphonicKeyPressure) : @(MIKMIDIEventTypeMIDIPolyphonicKeyPressureMessage),
										  @(MIKMIDIChannelEventTypeControlChange) : @(MIKMIDIEventTypeMIDIControlChangeMessage),
										  @(MIKMIDIChannelEventTypeProgramChange) : @(MIKMIDIEventTypeMIDIProgramChangeMessage),
										  @(MIKMIDIChannelEventTypeChannelPressure) : @(MIKMIDIEventTypeMIDIChannelPressureMessage),
										  @(MIKMIDIChannelEventTypePitchBendChange) : @(MIKMIDIEventTypeMIDIPitchBendChangeMessage)};
		
		musicEventToMIDITypeMap = @{@(kMusicEventType_NULL) : @(MIKMIDIEventTypeNULL),
									@(kMusicEventType_ExtendedNote) : @(MIKMIDIEventTypeExtendedNote),
									@(kMusicEventType_ExtendedTempo) : @(MIKMIDIEventTypeExtendedTempo),
									@(kMusicEventType_User) : @(MIKMIDIEventTypeUser),
									@(kMusicEventType_Meta) : @(MIKMIDIEventTypeMeta),
									@(kMusicEventType_MIDINoteMessage) : @(MIKMIDIEventTypeMIDINoteMessage),
									@(kMusicEventType_MIDIChannelMessage) : @(MIKMIDIEventTypeMIDIChannelMessage),
									@(kMusicEventType_MIDIRawData) : @(MIKMIDIEventTypeMIDIRawData),
									@(kMusicEventType_Parameter) : @(MIKMIDIEventTypeParameter),
									@(kMusicEventType_AUPreset) : @(MIKMIDIEventTypeAUPreset),};
		
	});
	
	if (musicEventType == kMusicEventType_Meta) {
		MIKMIDIMetaEventType metaEventType = *(MIKMIDIMetaEventType *)[data bytes];
		return [MIKMIDIMetaEvent eventTypeForMetaSubtype:metaEventType];
	} else if (musicEventType == kMusicEventType_MIDIChannelMessage) {
		UInt8 channelEventType = *(UInt8 *)[data bytes] & 0xF0;
		return [channelEventTypeToMIDITypeMap[@(channelEventType)] unsignedIntegerValue];
	} else {
		return [musicEventToMIDITypeMap[@(musicEventType)] unsignedIntegerValue];
	}
}

+ (Class)subclassForEventType:(MIKMIDIEventType)eventType
{
	Class result = [[self subclassesByEventCache] objectForKey:@(eventType)];
	if (result) return result;
	
	for (Class subclass in registeredMIKMIDIEventSubclasses) {
		if ([[subclass supportedMIDIEventTypes] containsObject:@(eventType)]) {
			result = subclass;
			break;
		}
	}
	return result;
}

+ (Class)subclassForMusicEventType:(MusicEventType)eventType andData:(NSData *)data
{
	MIKMIDIEventType midiEventType = [[self class] mikEventTypeForMusicEventType:eventType andData:data];
	return [self subclassForEventType:midiEventType];
}

#pragma mark - NSCopying

- (id)copyWithZone:(NSZone *)zone
{
	Class copyClass = [[self class] immutableCounterpartClass];
	MIKMIDIEvent *result = [[copyClass alloc] init];
	result.internalData = self.internalData;
	result->_eventType = self.eventType;
	result->_timeStamp = self.timeStamp;
	return result;
}

- (id)mutableCopy
{
	Class copyClass = [[self class] mutableCounterpartClass];
	MIKMutableMIDIEvent *result = [[copyClass alloc] init];
	result.internalData = self.internalData;
	result.eventType = self.eventType;
	result.timeStamp = self.timeStamp;
	return result;
}

#pragma mark - Properties

+ (NSSet *)keyPathsForValuesAffectingInternalData
{
	return [NSSet set];
}

+ (NSSet *)keyPathsForValuesAffectingData
{
	return [NSSet setWithObject:@"internalData"];
}

- (NSData *)data { return [self.internalData copy]; }

- (void)setData:(NSData *)data
{
	if (![[self class] isMutable]) return MIKMIDI_RAISE_MUTATION_ATTEMPT_EXCEPTION;
	self.internalData = data ? [data mutableCopy] : [NSMutableData data];
}

- (void)setTimeStamp:(MusicTimeStamp)timeStamp
{
	if (![[self class] isMutable]) return MIKMIDI_RAISE_MUTATION_ATTEMPT_EXCEPTION;
	_timeStamp = timeStamp;
}

- (void)setInternalData:(NSMutableData *)internalData
{
	if (internalData != _internalData) {
		_internalData = internalData ? [internalData mutableCopy] : [NSMutableData data];
	}
}

@end

@implementation MIKMutableMIDIEvent

+ (BOOL)isMutable { return YES; }

@dynamic eventType;
@dynamic data;
@dynamic timeStamp;

#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wdeprecated-implementations"

+ (BOOL)supportsMIKMIDIEventType:(MIKMIDIEventType)type { return [[self immutableCounterpartClass] supportsMIKMIDIEventType:type]; }

#pragma clang diagnostic pop

@end

#pragma mark - MIKMIDICommand+MIKMIDIEventToCommands

#import "MIKMIDIClock.h"
#import "MIKMIDINoteEvent.h"
#import "MIKMIDIChannelEvent.h"

@implementation MIKMIDICommand (MIKMIDIEventToCommands)

+ (NSArray *)commandsFromMIDIEvent:(MIKMIDIEvent *)event clock:(MIKMIDIClock *)clock
{
	NSMutableArray *result = [NSMutableArray array];
	if ([event isKindOfClass:[MIKMIDINoteEvent class]]) {
		NSArray *commands = [MIKMIDICommand commandsFromNoteEvent:(MIKMIDINoteEvent *)event clock:clock];
		if (commands) [result addObjectsFromArray:commands];
	} else if ([event isKindOfClass:[MIKMIDIChannelEvent class]]) {
		MIKMIDICommand *command = [MIKMIDICommand commandFromChannelEvent:(MIKMIDIChannelEvent *)event clock:clock];
		if (command) [result addObject:command];
	}
	return result;
}

@end
