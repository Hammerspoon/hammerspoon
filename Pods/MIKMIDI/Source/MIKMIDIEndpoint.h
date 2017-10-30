//
//  MIKMIDIEndpoint.h
//  MIDI Testbed
//
//  Created by Andrew Madsen on 3/7/13.
//  Copyright (c) 2013 Mixed In Key. All rights reserved.
//

#import "MIKMIDIObject.h"
#import "MIKMIDICompilerCompatibility.h"

@class MIKMIDIEntity;

NS_ASSUME_NONNULL_BEGIN

/**
 *  Base class for MIDI endpoint objects. Not used directly, rather, in use, instances will always be
 *  instances of MIKMIDISourceEndpoint or MIKMIDIDestinationEndpoint.
 */
@interface MIKMIDIEndpoint : MIKMIDIObject

/**
 *  The entity that contains the receiver. Will be nil for non-wrapped virtual endpoints.
 */
@property (nonatomic, weak, readonly, nullable) MIKMIDIEntity *entity;

/**
 *  Whether or not the endpoint is private or hidden. See kMIDIPropertyPrivate in MIDIServices.h.
 */
@property (nonatomic, readonly) BOOL isPrivate;

@end

NS_ASSUME_NONNULL_END