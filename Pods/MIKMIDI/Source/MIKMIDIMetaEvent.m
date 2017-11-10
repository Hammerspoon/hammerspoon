//
//  MIKMIDIMetadataEvent.m
//  MIDI Files Testbed
//
//  Created by Jake Gundersen on 5/22/14.
//  Copyright (c) 2014 Mixed In Key. All rights reserved.
//

#import "MIKMIDIMetaEvent.h"
#import "MIKMIDIEvent_SubclassMethods.h"
#import "MIKMIDIUtilities.h"

#if !__has_feature(objc_arc)
#error MIKMIDIMetaEvent.m must be compiled with ARC. Either turn on ARC for the project or set the -fobjc-arc flag for MIKMIDIMetaEvent.m in the Build Phases for this target
#endif

@implementation MIKMIDIMetaEvent

+ (void)load { [MIKMIDIEvent registerSubclass:self]; }
+ (NSArray *)supportedMIDIEventTypes { return @[@(MIKMIDIEventTypeMeta)]; }
+ (Class)immutableCounterpartClass { return [MIKMIDIMetaEvent class]; }
+ (Class)mutableCounterpartClass { return [MIKMutableMIDIMetaEvent class]; }
+ (BOOL)isMutable { return NO; }
+ (NSData *)initialData { return [NSData dataWithBytes:&(MIDIMetaEvent){0} length:sizeof(MIDIMetaEvent)]; }

- (nullable instancetype)initWithTimeStamp:(MusicTimeStamp)timeStamp midiEventType:(MIKMIDIEventType)eventType data:(nullable NSData *)data
{
	self = [super initWithTimeStamp:timeStamp midiEventType:eventType data:data];
	if (self) {
		MIKMIDIMetaEventType metadataType = [[self class] metaSubtypeForEventType:eventType];
		if (self.metadataType != metadataType) {
			MIDIMetaEvent *metaEvent = (MIDIMetaEvent*)[self.internalData bytes];
			metaEvent->metaEventType = metadataType;
		}
	}
	return self;
}

- (instancetype)initWithMetaData:(NSData *)metaData metadataType:(MIKMIDIMetaEventType)type timeStamp:(MusicTimeStamp)timeStamp
{
	MIKMIDIEventType eventType = [MIKMIDIMetaEvent eventTypeForMetaSubtype:type];
	if (eventType == MIKMIDIEventTypeNULL) {
		type = 0;
		eventType = MIKMIDIEventTypeMeta;
	}
	NSMutableData *data = [[[[self class] initialData] subdataWithRange:NSMakeRange(0, MIKMIDIEventMetadataStartOffset)] mutableCopy];
	[data appendData:metaData];
	MIDIMetaEvent *metaEvent = (MIDIMetaEvent *)[data mutableBytes];
	metaEvent->metaEventType = type;
	metaEvent->dataLength = (UInt32)[metaData length];
	return [self initWithTimeStamp:timeStamp midiEventType:eventType data:data];
}

- (instancetype)initWithMetaData:(NSData *)metaData timeStamp:(MusicTimeStamp)timeStamp
{
	MIKMIDIEventType eventType = [[[[self class] supportedMIDIEventTypes] firstObject] unsignedIntegerValue];
	MIKMIDIMetaEventType metaType = [MIKMIDIMetaEvent metaSubtypeForEventType:eventType];
	return [self initWithMetaData:metaData metadataType:metaType timeStamp:timeStamp];
}

- (NSString *)additionalEventDescription
{
    return [NSString stringWithFormat:@"Metadata Type: 0x%02x, Length: %u, Data: %@", self.metadataType, (unsigned int)self.metadataLength, self.metaData];
}

#pragma mark - Public

+ (MIKMIDIEventType)eventTypeForMetaSubtype:(MIKMIDIMetaEventType)subtype
{
	return [[self metaTypeToMIDITypeMap][@(subtype)] unsignedIntegerValue];
}

+ (MIKMIDIMetaEventType)metaSubtypeForEventType:(MIKMIDIEventType)eventType
{
	NSDictionary *map = [self metaTypeToMIDITypeMap];
	for (NSNumber *key in map) {
		if ([map[key] isEqualToNumber:@(eventType)]) {
			return [key unsignedIntegerValue];
		}
	}
	return MIKMIDIMetaEventTypeInvalid;
}

#pragma mark - Private

+ (NSDictionary *)metaTypeToMIDITypeMap
{
	static NSDictionary *metaTypeToMIDITypeMap = nil;
	static dispatch_once_t onceToken;
	dispatch_once(&onceToken, ^{
		metaTypeToMIDITypeMap = @{@(MIKMIDIMetaEventTypeSequenceNumber) : @(MIKMIDIEventTypeMetaSequence),
								  @(MIKMIDIMetaEventTypeTextEvent) : @(MIKMIDIEventTypeMetaText),
								  @(MIKMIDIMetaEventTypeCopyrightNotice) : @(MIKMIDIEventTypeMetaCopyright),
								  @(MIKMIDIMetaEventTypeTrackSequenceName) : @(MIKMIDIEventTypeMetaTrackSequenceName),
								  @(MIKMIDIMetaEventTypeInstrumentName) : @(MIKMIDIEventTypeMetaInstrumentName),
								  @(MIKMIDIMetaEventTypeLyricText) : @(MIKMIDIEventTypeMetaLyricText),
								  @(MIKMIDIMetaEventTypeMarkerText) : @(MIKMIDIEventTypeMetaMarkerText),
								  @(MIKMIDIMetaEventTypeCuePoint) : @(MIKMIDIEventTypeMetaCuePoint),
								  @(MIKMIDIMetaEventTypeMIDIChannelPrefix) : @(MIKMIDIEventTypeMetaMIDIChannelPrefix),
								  @(MIKMIDIMetaEventTypeEndOfTrack) : @(MIKMIDIEventTypeMetaEndOfTrack),
								  @(MIKMIDIMetaEventTypeTempoSetting) : @(MIKMIDIEventTypeMetaTempoSetting),
								  @(MIKMIDIMetaEventTypeSMPTEOffset) : @(MIKMIDIEventTypeMetaSMPTEOffset),
								  @(MIKMIDIMetaEventTypeTimeSignature) : @(MIKMIDIEventTypeMetaTimeSignature),
								  @(MIKMIDIMetaEventTypeKeySignature) : @(MIKMIDIEventTypeMetaKeySignature),
								  @(MIKMIDIMetaEventTypeSequencerSpecificEvent) : @(MIKMIDIEventTypeMetaSequenceSpecificEvent),};
	});
	return metaTypeToMIDITypeMap;
}

#pragma mark - Properties

+ (NSSet *)keyPathsForValuesAffectingInternalData
{
	return [NSSet setWithObjects:@"metadataType", @"metadata", nil];
}

- (MIKMIDIMetaEventType)metadataType
{
    MIDIMetaEvent *metaEvent = (MIDIMetaEvent*)[self.internalData bytes];
    return metaEvent->metaEventType;
}

- (void)setMetadataType:(UInt8)metadataType
{
    if (![[self class] isMutable]) return MIKMIDI_RAISE_MUTATION_ATTEMPT_EXCEPTION;
	
    MIDIMetaEvent *metaEvent = (MIDIMetaEvent*)[self.internalData bytes];
    metaEvent->metaEventType = metadataType;
}

+ (NSSet *)keyPathsForValuesAffectingMetadataLength
{
	return [NSSet setWithObjects:@"metaData", nil];
}

- (UInt32)metadataLength
{
    MIDIMetaEvent *metaEvent = (MIDIMetaEvent*)[self.internalData bytes];
    return metaEvent->dataLength;
}

- (NSData *)metaData
{
    return [self.internalData subdataWithRange:NSMakeRange(MIKMIDIEventMetadataStartOffset, self.metadataLength)];
}

- (void)setMetaData:(NSData *)metaData
{
    if (![[self class] isMutable]) return MIKMIDI_RAISE_MUTATION_ATTEMPT_EXCEPTION;
    
    MIDIMetaEvent *metaEvent = (MIDIMetaEvent*)[self.internalData bytes];
    metaEvent->dataLength = (UInt32)[metaData length];
    NSMutableData *newMetaData = [[self.internalData subdataWithRange:NSMakeRange(0, MIKMIDIEventMetadataStartOffset)] mutableCopy];
    [newMetaData appendData:metaData];
	self.internalData = newMetaData ?: [NSMutableData data];
}

@end


@implementation MIKMutableMIDIMetaEvent

@dynamic timeStamp;
@dynamic metadataType;
@dynamic metaData;

+ (BOOL)isMutable { return YES; }

@end
