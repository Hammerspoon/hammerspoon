//
//  MIKMIDIMetadataTextEvent.h
//  MIDI Files Testbed
//
//  Created by Jake Gundersen on 5/22/14.
//  Copyright (c) 2014 Mixed In Key. All rights reserved.
//

#import "MIKMIDIMetaEvent.h"
#import "MIKMIDICompilerCompatibility.h"

NS_ASSUME_NONNULL_BEGIN

/**
 *  A meta event containing text.
 */
@interface MIKMIDIMetaTextEvent : MIKMIDIMetaEvent

- (instancetype)initWithString:(NSString *)string timeStamp:(MusicTimeStamp)timeStamp;

/**
 *  The text for the event.
 */
@property (nonatomic, readonly, nullable) NSString *string;

@end

/**
 *  The mutable counterpart of MIKMIDIMetaTextEvent.
 */
@interface MIKMutableMIDIMetaTextEvent : MIKMIDIMetaTextEvent

@property (nonatomic, readwrite) MusicTimeStamp timeStamp;
@property (nonatomic, readwrite) MIKMIDIMetaEventType metadataType;
@property (nonatomic, strong, readwrite, null_resettable) NSData *metaData;
@property (nonatomic, copy, readwrite, nullable) NSString *string;

@end

NS_ASSUME_NONNULL_END