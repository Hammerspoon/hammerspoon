//
//  MIKMIDIMetaCopyrightEvent.h
//  MIDI Files Testbed
//
//  Created by Jake Gundersen on 5/22/14.
//  Copyright (c) 2014 Mixed In Key. All rights reserved.
//

#import "MIKMIDIMetaTextEvent.h"
#import "MIKMIDICompilerCompatibility.h"

NS_ASSUME_NONNULL_BEGIN

/**
 *  A meta event containing copyright information.
 */
@interface MIKMIDIMetaCopyrightEvent : MIKMIDIMetaTextEvent

@end

/**
 *  The mutable counterpart of MIKMIDIMetaCopyrightEvent.
 */
@interface MIKMutableMIDIMetaCopyrightEvent : MIKMIDIMetaCopyrightEvent

@property (nonatomic, readwrite) MusicTimeStamp timeStamp;
@property (nonatomic, readwrite) MIKMIDIMetaEventType metadataType;
@property (nonatomic, strong, readwrite, null_resettable) NSData *metaData;

@end

NS_ASSUME_NONNULL_END