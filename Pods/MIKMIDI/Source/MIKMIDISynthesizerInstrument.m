//
//  MIKMIDISynthesizerInstrument.m
//  MIKMIDI
//
//  Created by Andrew Madsen on 2/19/15.
//  Copyright (c) 2015 Mixed In Key. All rights reserved.
//

#import "MIKMIDISynthesizerInstrument.h"

@implementation MIKMIDISynthesizerInstrument

+ (instancetype)instrumentWithID:(MusicDeviceInstrumentID)instrumentID name:(NSString *)name
{	
	return [[self alloc] initWithName:name instrumentID:instrumentID];
}

- (instancetype)initWithName:(NSString *)name instrumentID:(MusicDeviceInstrumentID)instrumentID
{
	self = [super init];
	if (self) {
		_name = name ?: @"No instrument name";
		_instrumentID = instrumentID;
	}
	return self;
}

- (NSString *)description
{
	return [NSString stringWithFormat:@"%@ %@ (%@)", [super description], self.name, @(self.instrumentID)];
}

- (BOOL)isEqual:(id)object
{
	if (object == self) return YES;
	if (![object isMemberOfClass:[self class]]) return NO;
	if (self.instrumentID != [object instrumentID]) return NO;
	return [self.name isEqualToString:[object name]];
}

- (NSUInteger)hash
{
	return (NSUInteger)self.instrumentID;
}

@end

#pragma mark - Deprecated

@implementation MIKMIDISynthesizerInstrument (Deprecated)

+ (AudioUnit)defaultInstrumentUnit
{
	static AudioUnit instrumentUnit = NULL;
	static dispatch_once_t onceToken;
	dispatch_once(&onceToken, ^{
		AudioComponentDescription componentDesc = {
			.componentManufacturer = kAudioUnitManufacturer_Apple,
			.componentType = kAudioUnitType_MusicDevice,
#if TARGET_OS_IPHONE
			.componentSubType = kAudioUnitSubType_MIDISynth,
#else
			.componentSubType = kAudioUnitSubType_DLSSynth,
#endif
		};
		AudioComponent instrumentComponent = AudioComponentFindNext(NULL, &componentDesc);
		if (!instrumentComponent) {
			NSLog(@"Unable to create the default synthesizer instrument audio unit.");
			return;
		}
		AudioComponentInstanceNew(instrumentComponent, &instrumentUnit);
		AudioUnitInitialize(instrumentUnit);
	});
	
	return instrumentUnit;
}

+ (NSArray *)availableInstruments
{
	static NSArray *availableInstruments = nil;
	static dispatch_once_t onceToken;
	dispatch_once(&onceToken, ^{
		AudioUnit audioUnit = [self defaultInstrumentUnit];
		NSMutableArray *result = [NSMutableArray array];
		
		UInt32 instrumentCount;
		UInt32 instrumentCountSize = sizeof(instrumentCount);
		
		OSStatus err = AudioUnitGetProperty(audioUnit, kMusicDeviceProperty_InstrumentCount, kAudioUnitScope_Global, 0, &instrumentCount, &instrumentCountSize);
		if (err) {
			NSLog(@"AudioUnitGetProperty() (Instrument Count) failed with error %@ in %s.", @(err), __PRETTY_FUNCTION__);
			return;
		}
		
		for (UInt32 i = 0; i < instrumentCount; i++) {
			MusicDeviceInstrumentID instrumentID;
			UInt32 idSize = sizeof(instrumentID);
			err = AudioUnitGetProperty(audioUnit, kMusicDeviceProperty_InstrumentNumber, kAudioUnitScope_Global, i, &instrumentID, &idSize);
			if (err) {
				NSLog(@"AudioUnitGetProperty() (Instrument Number) failed with error %@ in %s.", @(err), __PRETTY_FUNCTION__);
				continue;
			}
			
			MIKMIDISynthesizerInstrument *instrument = [MIKMIDISynthesizerInstrument instrumentWithID:instrumentID];
			if (instrument) [result addObject:instrument];
		}
		
		availableInstruments = [result copy];
	});
	
	return availableInstruments ?: @[];
}

+ (instancetype)instrumentWithID:(MusicDeviceInstrumentID)instrumentID
{
	return [self instrumentWithID:instrumentID name:@"Unspecified Name"];
}

@end