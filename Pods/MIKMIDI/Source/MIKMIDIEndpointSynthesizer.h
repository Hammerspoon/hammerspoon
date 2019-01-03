//
//  MIKMIDIEndpointSynthesizer.h
//  MIKMIDI
//
//  Created by Andrew Madsen on 5/27/14.
//  Copyright (c) 2014 Mixed In Key. All rights reserved.
//

#import "MIKMIDISynthesizer.h"
#import "MIKMIDICompilerCompatibility.h"

@class MIKMIDIEndpoint;
@class MIKMIDISourceEndpoint;
@class MIKMIDIClientDestinationEndpoint;
@class MIKMIDISynthesizerInstrument;

NS_ASSUME_NONNULL_BEGIN

/**
 *  MIKMIDIEndpointSynthesizer is a subclass of MIKMIDISynthesizer that
 *  provides a very simple way to synthesize MIDI commands coming from a
 *  MIDI endpoint (e.g. from a connected MIDI piano keyboard) to produce sound output.
 *
 *  To use it, simply create a synthesizer instance with the source you'd like it to play. It will
 *  continue playing incoming MIDI until it is deallocated.
 *
 *  @see MIKMIDISynthesizer
 */
@interface MIKMIDIEndpointSynthesizer : MIKMIDISynthesizer

/**
 *  Creates and initializes an MIKMIDIEndpointSynthesizer instance using Apple's DLS synth as the
 *  underlying instrument.
 *
 *  @param source An MIKMIDISourceEndpoint instance from which MIDI note events will be received.
 *  @param error   If an error occurs, upon returns contains an NSError object that describes the problem. If you are not interested in possible errors, you may pass in NULL.
 *
 *  @return An initialized MIKMIDIEndpointSynthesizer or nil if an error occurs.
 */
+ (nullable instancetype)playerWithMIDISource:(MIKMIDISourceEndpoint *)source error:(NSError * __autoreleasing *)error;

/**
 *  Creates and initializes an MIKMIDIEndpointSynthesizer instance.
 *
 *  @param source An MIKMIDISourceEndpoint instance from which MIDI note events will be received.
 *  @param componentDescription an AudioComponentDescription describing the Audio Unit instrument
 *  you would like the synthesizer to use.
 *  @param error   If an error occurs, upon returns contains an NSError object that describes the problem. If you are not interested in possible errors, you may pass in NULL.
 *
 *  @return An initialized MIKMIDIEndpointSynthesizer or nil if an error occurs.
 */
+ (nullable instancetype)playerWithMIDISource:(MIKMIDISourceEndpoint *)source
                         componentDescription:(AudioComponentDescription)componentDescription
                                        error:(NSError * __autoreleasing *)error;

/**
 *  Initializes an MIKMIDIEndpointSynthesizer instance using Apple's DLS synth as the
 *  underlying instrument.
 *
 *  @param source An MIKMIDISourceEndpoint instance from which MIDI note events will be received.
 *  @param error   If an error occurs, upon returns contains an NSError object that describes the problem. If you are not interested in possible errors, you may pass in NULL.
 *
 *  @return An initialized MIKMIDIEndpointSynthesizer or nil if an error occurs.
 */
- (nullable instancetype)initWithMIDISource:(MIKMIDISourceEndpoint *)source
                                      error:(NSError * __autoreleasing *)error;

/**
 *  Initializes an MIKMIDIEndpointSynthesizer instance.
 *
 *  @param source An MIKMIDISourceEndpoint instance from which MIDI note events will be received.
 *  @param componentDescription an AudioComponentDescription describing the Audio Unit instrument
 *  you would like the synthesizer to use.
 *  @param error   If an error occurs, upon returns contains an NSError object that describes the problem. If you are not interested in possible errors, you may pass in NULL.
 *
 *  @return An initialized MIKMIDIEndpointSynthesizer or nil if an error occurs.
 */
- (nullable instancetype)initWithMIDISource:(MIKMIDISourceEndpoint *)source
                       componentDescription:(AudioComponentDescription)componentDescription
                                      error:(NSError * __autoreleasing *)error;

/**
 *  Creates and initializes an MIKMIDIEndpointSynthesizer instance using Apple's DLS synth as the
 *  underlying instrument.
 *
 *  @param destination An MIKMIDIClientDestinationEndpoint instance from which MIDI note events will be received.
 *  @param error   If an error occurs, upon returns contains an NSError object that describes the problem. If you are not interested in possible errors, you may pass in NULL.
 *
 *  @return An initialized MIKMIDIEndpointSynthesizer or nil if an error occurs.
 */
+ (nullable instancetype)synthesizerWithClientDestinationEndpoint:(MIKMIDIClientDestinationEndpoint *)destination
                                                            error:(NSError * __autoreleasing *)error;

/**
 *  Creates and initializes an MIKMIDIEndpointSynthesizer instance.
 *
 *  @param destination An MIKMIDIClientDestinationEndpoint instance from which MIDI note events will be received.
 *  @param componentDescription an AudioComponentDescription describing the Audio Unit instrument
 *  you would like the synthesizer to use.
 *  @param error   If an error occurs, upon returns contains an NSError object that describes the problem. If you are not interested in possible errors, you may pass in NULL.
 *
 *  @return An initialized MIKMIDIEndpointSynthesizer or nil if an error occurs.
 */
+ (nullable instancetype)synthesizerWithClientDestinationEndpoint:(MIKMIDIClientDestinationEndpoint *)destination
                                             componentDescription:(AudioComponentDescription)componentDescription
                                                            error:(NSError * __autoreleasing *)error;

/**
 *  Initializes an MIKMIDIEndpointSynthesizer instance using Apple's DLS synth as the
 *  underlying instrument.
 *
 *  @param destination An MIKMIDIClientDestinationEndpoint instance from which MIDI note events will be received.
 *  @param error   If an error occurs, upon returns contains an NSError object that describes the problem. If you are not interested in possible errors, you may pass in NULL.
 *
 *  @return An initialized MIKMIDIEndpointSynthesizer or nil if an error occurs.
 */
- (nullable instancetype)initWithClientDestinationEndpoint:(MIKMIDIClientDestinationEndpoint *)destination
                                                     error:(NSError * __autoreleasing *)error;

/**
 *  Initializes an MIKMIDIEndpointSynthesizer instance.
 *
 *  @param destination An MIKMIDIClientDestinationEndpoint instance from which MIDI note events will be received.
 *  @param componentDescription an AudioComponentDescription describing the Audio Unit instrument
 *  you would like the synthesizer to use.
 *  @param error   If an error occurs, upon returns contains an NSError object that describes the problem. If you are not interested in possible errors, you may pass in NULL.
 *
 *  @return An initialized MIKMIDIEndpointSynthesizer or nil if an error occurs.
 */
- (nullable instancetype)initWithClientDestinationEndpoint:(MIKMIDIClientDestinationEndpoint *)destination
                                      componentDescription:(AudioComponentDescription)componentDescription
                                                     error:(NSError * __autoreleasing *)error;

// Properties

/**
 *  The endpoint from which the receiver is receiving MIDI messages.
 *  This may be either an external MIKMIDISourceEndpoint, e.g. to synthesize MIDI
 *  events coming from an external MIDI keyboard, or it may be an MIKMIDIClientDestinationEndpoint,
 *  e.g. to synthesize MIDI events coming from an another application on the system.
 */
@property (nonatomic, strong, readonly, nullable) MIKMIDIEndpoint *endpoint;

@end

#pragma mark - Deprecated

@interface MIKMIDIEndpointSynthesizer (Deprecated)

/**
 *  Creates and initializes an MIKMIDIEndpointSynthesizer instance using Apple's DLS synth as the
 *  underlying instrument.
 *
 *  @deprecated Use -playerWithMIDISource:error: instead.
 *
 *  @param source An MIKMIDISourceEndpoint instance from which MIDI note events will be received.
 *
 *  @return An initialized MIKMIDIEndpointSynthesizer or nil if an error occurs.
 */
+ (nullable instancetype)playerWithMIDISource:(MIKMIDISourceEndpoint *)source DEPRECATED_MSG_ATTRIBUTE("Use -playerWithMIDISource:error: instead.") ;

/**
 *  Creates and initializes an MIKMIDIEndpointSynthesizer instance.
 *
 *  @deprecated Use -playerWithMIDISource:componentDescription:error: instead.
 *
 *  @param source An MIKMIDISourceEndpoint instance from which MIDI note events will be received.
 *  @param componentDescription an AudioComponentDescription describing the Audio Unit instrument
 *  you would like the synthesizer to use.
 *
 *  @return An initialized MIKMIDIEndpointSynthesizer or nil if an error occurs.
 */
+ (nullable instancetype)playerWithMIDISource:(MIKMIDISourceEndpoint *)source componentDescription:(AudioComponentDescription)componentDescription
DEPRECATED_MSG_ATTRIBUTE("Use -playerWithMIDISource:componentDescription:error: instead.");

/**
 *  Initializes an MIKMIDIEndpointSynthesizer instance using Apple's DLS synth as the
 *  underlying instrument.
 *
 *  @deprecated Use -initWithMIDISource:error: instead.
 *
 *  @param source An MIKMIDISourceEndpoint instance from which MIDI note events will be received.
 *
 *  @return An initialized MIKMIDIEndpointSynthesizer or nil if an error occurs.
 */
- (nullable instancetype)initWithMIDISource:(MIKMIDISourceEndpoint *)source DEPRECATED_MSG_ATTRIBUTE("Use -initWithMIDISource:error: instead.");

/**
 *  Initializes an MIKMIDIEndpointSynthesizer instance.
 *
 *  @deprecated Use -initWithMIDISource:componentDescription:error: instead.
 *
 *  @param source An MIKMIDISourceEndpoint instance from which MIDI note events will be received.
 *  @param componentDescription an AudioComponentDescription describing the Audio Unit instrument
 *  you would like the synthesizer to use.
 *
 *  @return An initialized MIKMIDIEndpointSynthesizer or nil if an error occurs.
 */
- (nullable instancetype)initWithMIDISource:(MIKMIDISourceEndpoint *)source componentDescription:(AudioComponentDescription)componentDescription
DEPRECATED_MSG_ATTRIBUTE("Use -initWithMIDISource:componentDescription:error: instead.");

/**
 *  Creates and initializes an MIKMIDIEndpointSynthesizer instance using Apple's DLS synth as the
 *  underlying instrument.
 *
 *  @deprecated Use -synthesizerWithClientDestinationEndpoint:error: instead.
 *
 *  @param destination An MIKMIDIClientDestinationEndpoint instance from which MIDI note events will be received.
 *
 *  @return An initialized MIKMIDIEndpointSynthesizer or nil if an error occurs.
 */
+ (nullable instancetype)synthesizerWithClientDestinationEndpoint:(MIKMIDIClientDestinationEndpoint *)destination
DEPRECATED_MSG_ATTRIBUTE("Use -synthesizerWithClientDestinationEndpoint:error: instead.");

/**
 *  Creates and initializes an MIKMIDIEndpointSynthesizer instance.
 *
 *  @deprecated Use -synthesizerWithClientDestinationEndpoint:componentDescription:error: instead.
 *
 *  @param destination An MIKMIDIClientDestinationEndpoint instance from which MIDI note events will be received.
 *  @param componentDescription an AudioComponentDescription describing the Audio Unit instrument
 *  you would like the synthesizer to use.
 *
 *  @return An initialized MIKMIDIEndpointSynthesizer or nil if an error occurs.
 */
+ (nullable instancetype)synthesizerWithClientDestinationEndpoint:(MIKMIDIClientDestinationEndpoint *)destination
                                             componentDescription:(AudioComponentDescription)componentDescription
DEPRECATED_MSG_ATTRIBUTE("Use -synthesizerWithClientDestinationEndpoint:componentDescription:error: instead.");

/**
 *  Initializes an MIKMIDIEndpointSynthesizer instance using Apple's DLS synth as the
 *  underlying instrument.
 *
 *  @deprecated Use -initWithClientDestinationEndpoint:error: instead.
 *
 *  @param destination An MIKMIDIClientDestinationEndpoint instance from which MIDI note events will be received.
 *
 *  @return An initialized MIKMIDIEndpointSynthesizer or nil if an error occurs.
 */
- (nullable instancetype)initWithClientDestinationEndpoint:(MIKMIDIClientDestinationEndpoint *)destination
DEPRECATED_MSG_ATTRIBUTE("Use -initWithClientDestinationEndpoint:error: instead.");

/**
 *  Initializes an MIKMIDIEndpointSynthesizer instance.
 *
 *  @deprecated Use -initWithClientDestinationEndpoint:componentDescription:error: instead.
 *
 *  @param destination An MIKMIDIClientDestinationEndpoint instance from which MIDI note events will be received.
 *  @param componentDescription an AudioComponentDescription describing the Audio Unit instrument
 *  you would like the synthesizer to use.
 *
 *  @return An initialized MIKMIDIEndpointSynthesizer or nil if an error occurs.
 */
- (nullable instancetype)initWithClientDestinationEndpoint:(MIKMIDIClientDestinationEndpoint *)destination
                                      componentDescription:(AudioComponentDescription)componentDescription
DEPRECATED_MSG_ATTRIBUTE("Use -initWithClientDestinationEndpoint:componentDescription:error: instead.");

@end

NS_ASSUME_NONNULL_END
