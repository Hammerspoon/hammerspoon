//
//  MIKMIDIMetaTrackSequenceNameEvent.h
//  MIDI Files Testbed
//
//  Created by Jake Gundersen on 5/22/14.
//  Copyright (c) 2014 Mixed In Key. All rights reserved.
//

#import "MIKMIDIMetaTextEvent.h"
#import "MIKMIDICompilerCompatibility.h"

NS_ASSUME_NONNULL_BEGIN

/**
 *  A meta event containing a track name.
 */
@interface MIKMIDIMetaTrackSequenceNameEvent : MIKMIDIMetaTextEvent

- (instancetype)initWithName:(NSString *)name timeStamp:(MusicTimeStamp)timeStamp;

@property (nonatomic, readonly, nullable) NSString *name;

@end

/**
 *  The mutable counterpart of MIKMIDIMetaTrackSequenceNameEvent
 */
@interface MIKMutableMIDIMetaTrackSequenceNameEvent : MIKMIDIMetaTrackSequenceNameEvent

@property (nonatomic, copy, readwrite, nullable) NSString *name;

@property (nonatomic, readwrite) MusicTimeStamp timeStamp;
@property (nonatomic, readwrite) UInt8 metadataType;
@property (nonatomic, strong, readwrite, null_resettable) NSData *metaData;
@property (nonatomic, copy, readwrite) NSString *string;

@end

NS_ASSUME_NONNULL_END