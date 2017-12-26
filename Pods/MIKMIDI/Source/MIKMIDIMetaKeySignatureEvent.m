//
//  MIKMIDIMetaKeySignatureEvent.m
//  MIDI Files Testbed
//
//  Created by Jake Gundersen on 5/23/14.
//  Copyright (c) 2014 Mixed In Key. All rights reserved.
//

#import "MIKMIDIMetaKeySignatureEvent.h"
#import "MIKMIDIMetaEvent_SubclassMethods.h"
#import "MIKMIDIUtilities.h"

#if !__has_feature(objc_arc)
#error MIKMIDIMetaKeySignatureEvent.m must be compiled with ARC. Either turn on ARC for the project or set the -fobjc-arc flag for MIKMIDIMetaKeySignatureEvent.m in the Build Phases for this target
#endif

@implementation MIKMIDIMetaKeySignatureEvent

+ (void)load { [MIKMIDIEvent registerSubclass:self]; }
+ (NSArray *)supportedMIDIEventTypes { return @[@(MIKMIDIEventTypeMetaKeySignature)]; }
+ (Class)immutableCounterpartClass { return [MIKMIDIMetaKeySignatureEvent class]; }
+ (Class)mutableCounterpartClass { return [MIKMutableMIDIMetaKeySignatureEvent class]; }
+ (BOOL)isMutable { return NO; }
+ (NSData *)initialData
{
	NSMutableData *result = [NSMutableData dataWithBytes:&(MIDIMetaEvent){0} length:sizeof(MIDIMetaEvent)];
	MIDIMetaEvent *metaEvent = (MIDIMetaEvent *)[result mutableBytes];
	metaEvent->dataLength = 2;
	metaEvent->metaEventType = MIKMIDIMetaEventTypeKeySignature;
	NSInteger metaDataLength = result.length - MIKMIDIEventMetadataStartOffset;
	if (metaDataLength < 2) { [result increaseLengthBy:2-metaDataLength]; }
	UInt8 *metaDataBytes = (UInt8 *)[result mutableBytes] + MIKMIDIEventMetadataStartOffset;
	metaDataBytes[0] = 0; // C
	metaDataBytes[1] = 0; // Major
	return [result copy];
}

- (instancetype)initWithMusicalKey:(MIKMIDIMusicalKey)musicalKey timeStamp:(MusicTimeStamp)timeStamp
{
	NSMutableData *metaData = [[NSMutableData alloc] init];
	int8_t scale = [self scaleForMusicalKey:musicalKey];
	UInt8 numberOfFlatsAndSharps = [self numberOfFlatsAndSharpsInMusicalKey:musicalKey];
	[metaData appendBytes:&(UInt8){numberOfFlatsAndSharps} length:1];
	[metaData appendBytes:&(int8_t){scale} length:1];
	return [self initWithMetaData:metaData timeStamp:timeStamp];
}

#pragma mark - Private

- (MIKMIDIMusicalKey)musicalKeyForNumberOfFlatsAndSharps:(int8_t)flatsSharps scale:(MIKMIDIMusicalScale)scale
{
	return flatsSharps + scale * 100;
}

- (MIKMIDIMusicalScale)scaleForMusicalKey:(MIKMIDIMusicalKey)musicalKey
{
	return musicalKey > 7 ? MIKMIDIMusicalScaleMinor : MIKMIDIMusicalScaleMajor;
}

- (int8_t)numberOfFlatsAndSharpsInMusicalKey:(MIKMIDIMusicalKey)musicalKey
{
	MIKMIDIMusicalScale scale = [self scaleForMusicalKey:musicalKey];
	return musicalKey - scale * 100;
}

#pragma mark - Properties

+ (NSSet *)keyPathsForValuesAffectingValueForKey:(NSString *)key
{
    NSSet *keyPaths = [super keyPathsForValuesAffectingValueForKey:key];
    if ([key isEqualToString:@"key"] || [key isEqualToString:@"scale"] ||
		[key isEqualToString:@"musicalKey"] || [key isEqualToString:@"numberOfFlatsAndSharps"]) {
        keyPaths = [keyPaths setByAddingObject:@"metaData"];
    }
    return keyPaths;
}

- (MIKMIDIMusicalKey)musicalKey
{
	return [self musicalKeyForNumberOfFlatsAndSharps:self.numberOfFlatsAndSharps scale:self.scale];
}

- (void)setMusicalKey:(MIKMIDIMusicalKey)musicalKey
{
	self.scale = [self scaleForMusicalKey:musicalKey];
	self.numberOfFlatsAndSharps = [self numberOfFlatsAndSharpsInMusicalKey:musicalKey];
}

- (int8_t)numberOfFlatsAndSharps
{
	return *(int8_t*)[self.metaData bytes];
}

- (void)setNumberOfFlatsAndSharps:(int8_t)numberOfFlatsAndSharps
{
    if (![[self class] isMutable]) return MIKMIDI_RAISE_MUTATION_ATTEMPT_EXCEPTION;
    
    NSMutableData *mutableMetaData = [self.metaData mutableCopy];
    [mutableMetaData replaceBytesInRange:NSMakeRange(0, 1) withBytes:&numberOfFlatsAndSharps length:1];
    [self setMetaData:[mutableMetaData copy]];
}

- (MIKMIDIMusicalScale)scale
{
    return *((MIKMIDIMusicalScale*)[self.metaData bytes] + 1);
}

- (void)setScale:(MIKMIDIMusicalScale)scale
{
    if (![[self class] isMutable]) return MIKMIDI_RAISE_MUTATION_ATTEMPT_EXCEPTION;
    
    NSMutableData *mutableMetaData = [self.metaData mutableCopy];
    [mutableMetaData replaceBytesInRange:NSMakeRange(1, 1) withBytes:&scale length:1];
    [self setMetaData:[mutableMetaData copy]];
}

- (NSString *)additionalEventDescription
{
    return [NSString stringWithFormat:@"Metadata Type: 0x%02x, Key: %d, Scale %d", self.metadataType, self.numberOfFlatsAndSharps, self.scale];
}

@end

@implementation MIKMutableMIDIMetaKeySignatureEvent

@dynamic timeStamp;
@dynamic metadataType;
@dynamic metaData;
@dynamic musicalKey;
@dynamic numberOfFlatsAndSharps;
@dynamic scale;

+ (BOOL)isMutable { return YES; }

@end

#pragma mark -

@implementation MIKMIDIMetaKeySignatureEvent (Deprecated)

- (UInt8)key { return self.numberOfFlatsAndSharps; }
- (void)setKey:(UInt8)key { self.numberOfFlatsAndSharps = key; }

@end