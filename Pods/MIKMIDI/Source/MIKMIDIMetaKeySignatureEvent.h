//
//  MIKMIDIMetaKeySignatureEvent.h
//  MIDI Files Testbed
//
//  Created by Jake Gundersen on 5/23/14.
//  Copyright (c) 2014 Mixed In Key. All rights reserved.
//

#import "MIKMIDIMetaEvent.h"
#import "MIKMIDICompilerCompatibility.h"

typedef NS_ENUM(int8_t, MIKMIDIMusicalKey) {
	MIKMIDIMusicalKeyCFlatMajor = -7,
	MIKMIDIMusicalKeyGFlatMajor,
	MIKMIDIMusicalKeyDFlatMajor,
	MIKMIDIMusicalKeyAFlatMajor,
	MIKMIDIMusicalKeyEFlatMajor,
	MIKMIDIMusicalKeyBFlatMajor,
	MIKMIDIMusicalKeyFMajor,
	MIKMIDIMusicalKeyCMajor,
	MIKMIDIMusicalKeyGMajor,
	MIKMIDIMusicalKeyDMajor,
	MIKMIDIMusicalKeyAMajor,
	MIKMIDIMusicalKeyEMajor,
	MIKMIDIMusicalKeyBMajor,
	MIKMIDIMusicalKeyFSharpMajor,
	MIKMIDIMusicalKeyCSharpMajor,
	
	MIKMIDIMusicalKeyAFlatMinor = MIKMIDIMusicalKeyCFlatMajor+100,
	MIKMIDIMusicalKeyEFlatMinor,
	MIKMIDIMusicalKeyBFlatMinor,
	MIKMIDIMusicalKeyFMinor,
	MIKMIDIMusicalKeyCMinor,
	MIKMIDIMusicalKeyGMinor,
	MIKMIDIMusicalKeyDMinor,
	MIKMIDIMusicalKeyAMinor,
	MIKMIDIMusicalKeyEMinor,
	MIKMIDIMusicalKeyBMinor,
	MIKMIDIMusicalKeyFSharpMinor,
	MIKMIDIMusicalKeyCSharpMinor,
	MIKMIDIMusicalKeyGSharpMinor,
	MIKMIDIMusicalKeyDSharpMinor,
	MIKMIDIMusicalKeyASharpMinor,
};

typedef NS_ENUM(UInt8, MIKMIDIMusicalScale) {
	MIKMIDIMusicalScaleMajor = 0,
	MIKMIDIMusicalScaleMinor = 1
};

NS_ASSUME_NONNULL_BEGIN

/**
 *  A meta event containing key signature information.
 */
@interface MIKMIDIMetaKeySignatureEvent : MIKMIDIMetaEvent

/**
 *  Initializes an instane of MIKMIDIMetaKeySignatureEvent with the specified musical key and timeStamp.
 *
 *  @param musicalKey The musical key for the event. See MIKMIDIMusicalKey for a list of possible values.
 *  @param timeStamp The time stamp for the event.
 *
 *  @return An initialized MIKMIDIMetaKeySignatureEvent instance.
 */
- (instancetype)initWithMusicalKey:(MIKMIDIMusicalKey)musicalKey timeStamp:(MusicTimeStamp)timeStamp;

/**
 *  The musical key for the event. See MIKMIDIMusicalKey for a list of possible values.
 */
@property (nonatomic, readonly) MIKMIDIMusicalKey musicalKey;

/**
 *  The key for the event. Values can be between -7 and 7 and specify
 *  the key signature in terms of number of flats (if negative) or sharps (if positive).
 */
@property (nonatomic, readonly) int8_t numberOfFlatsAndSharps;

/**
 *  The scale for the event. A value of 0 indicates a major scale, a value of 1 indicates a minor scale.
 */
@property (nonatomic, readonly) MIKMIDIMusicalScale scale;

@end

/**
 *  The mutable counterpart of MIKMIDIMetaKeySignatureEvent.
 */
@interface MIKMutableMIDIMetaKeySignatureEvent : MIKMIDIMetaKeySignatureEvent

@property (nonatomic, readwrite) MusicTimeStamp timeStamp;
@property (nonatomic, readwrite) MIKMIDIMetaEventType metadataType;
@property (nonatomic, strong, readwrite, null_resettable) NSData *metaData;
@property (nonatomic, readwrite) MIKMIDIMusicalKey musicalKey;
@property (nonatomic, readwrite) int8_t numberOfFlatsAndSharps;
@property (nonatomic, readwrite) MIKMIDIMusicalScale scale;

@end

#pragma mark - Deprecated

@interface MIKMIDIMetaKeySignatureEvent (Deprecated)

/**
 *  @deprecated: This property is deprecated, and didn't work properly in previous versions
 *  due to the use of a signed type. Use numberOfFlatsAndSharps, which is directly equivalent, or 
 *  musicalKey, instead.
 *
 *  The key for the event. Values can be between -7 and 7 and specify
 *  the key signature in terms of number of flats (if negative) or sharps (if positive).
 */
@property (nonatomic, readonly) UInt8 key DEPRECATED_ATTRIBUTE;

@end

@interface MIKMutableMIDIMetaKeySignatureEvent (Deprecated)

@property (nonatomic, readwrite) UInt8 key DEPRECATED_ATTRIBUTE;

@end

NS_ASSUME_NONNULL_END