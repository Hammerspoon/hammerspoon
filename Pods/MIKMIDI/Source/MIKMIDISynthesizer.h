//
//  MIKMIDISynthesizer.h
//  
//
//  Created by Andrew Madsen on 2/19/15.
//
//

#import <Foundation/Foundation.h>
#import <AudioToolbox/AudioToolbox.h>
#import "MIKMIDISynthesizerInstrument.h"
#import "MIKMIDICommandScheduler.h"
#import "MIKMIDICompilerCompatibility.h"

NS_ASSUME_NONNULL_BEGIN

/**
 *  MIKMIDISynthesizer provides a simple way to synthesize MIDI messages to
 *  produce sound output.
 *
 *  To use it, simply create a synthesizer instance, then pass MIDI messages
 *  to it by calling -handleMIDIMessages:.
 *
 *  A subclass, MIKMIDIEndpointSynthesizer, adds the ability to easily connect
 *  to a MIDI endpoint and automatically synthesize incoming messages.
 *
 *  @see MIKMIDIEndpointSynthesizer
 *
 */
@interface MIKMIDISynthesizer : NSObject <MIKMIDICommandScheduler>

/**
 *  Initializes an MIKMIDISynthesizer instance which uses the default 
 *  MIDI instrument audio unit.
 *
 *  On OS X, the default unit is Apple's DLS Synth audio unit.
 *  On iOS, the default is Apple's AUSampler audio unit.
 *
 *  @return An initialized MIKMIDIEndpointSynthesizer or nil if an error occurs.
 */
- (nullable instancetype)init;

/**
 *  Initializes an MIKMIDISynthesizer instance which uses an audio unit matching
 *  the provided description.
 *
 *  @param componentDescription AudioComponentDescription describing the Audio Unit instrument
 *  you would like the synthesizer to use.
 *
 *  @return An initialized MIKMIDIEndpointSynthesizer or nil if an error occurs.
 */
- (nullable instancetype)initWithAudioUnitDescription:(AudioComponentDescription)componentDescription NS_DESIGNATED_INITIALIZER;

/**
 *  This synthesizer's available instruments. An array of 
 *  MIKMIDISynthesizerInstrument instances.
 *
 *  Note that this method currently always returns an empty array
 *  on iOS. See https://github.com/mixedinkey-opensource/MIKMIDI/issues/76
 * 
 *  Instruments returned by this property can be selected using
 *  -selectInstrument:
 */
@property (nonatomic, readonly) MIKArrayOf(MIKMIDISynthesizerInstrument *) *availableInstruments;

/**
 * Changes the instrument/voice used by the synthesizer.
 *
 *  @param instrument An MIKMIDISynthesizerInstrument instance.
 *
 *  @return YES if the instrument was successfully changed, NO if the change failed.
 *
 *  @see +[MIKMIDISynthesizerInstrument availableInstruments]
 */
- (BOOL)selectInstrument:(MIKMIDISynthesizerInstrument *)instrument;

/**
 *  Loads the sound font (.dls or .sf2) file at fileURL.
 *
 *  @param fileURL A fileURL for a .dls or .sf2 file.
 *  @param error   If an error occurs, upon returns contains an NSError object that describes the problem. If you are not interested in possible errors, you may pass in NULL.
 *
 *	@return YES if loading the sound font file was succesful, NO if an error occurred.
 */
- (BOOL)loadSoundfontFromFileAtURL:(NSURL *)fileURL error:(NSError **)error;

+ (AudioComponentDescription)appleSynthComponentDescription;

// methods for property 'componentDescription'
/**
 *  Sets up the AUGraph for the instrument. Do not call this method, as it is 
 *  called automatically during initialization.
 *  
 *  The method is provided to give subclasses a chance to override
 *  the AUGraph behavior for the instrument. If you do override it, you will need
 *  to create an AudioUnit instrument and set it to the instrument property. Also,
 *  if you intend to use the graph property, you will be responsible for setting
 *  that as well. DisposeAUGraph() is called on the previous graph when setting 
 *  the graph property, and in dealloc.
 *
 *  @return YES is setting up the graph was succesful, and initialization
 *  should continue, NO if setting up the graph failed and initialization should
 *  return nil.
 */
- (BOOL)setupAUGraph;

/**
 *  Plays MIDI messages through the synthesizer.
 *
 *  This method can be used to synthesize arbitrary MIDI events. It is especially
 *  useful for MIKMIDIEndpointSynthesizers that are not connected to a MIDI
 *  endpoint.
 *
 *  @param messages An NSArray of MIKMIDICommand (subclass) instances.
 */
- (void)handleMIDIMessages:(MIKArrayOf(MIKMIDICommand *) *)messages;

// Properties

/**
 *  The component description of the underlying Audio Unit instrument.
 */
@property (nonatomic, readonly) AudioComponentDescription componentDescription;

/**
 *  The Audio Unit instrument that ultimately receives all of the MIDI messages sent to
 *  this endpoint synthesizer.
 *
 *  @note You should only use the setter for this property from an
 *  MIKMIDIEndpointSynthesizer subclass.
 *
 *  @see -setupAUGraph
 */
@property (nonatomic, readonly, nullable) AudioUnit instrumentUnit;

/**
 *  The AUGraph for the instrument.
 *
 *  @note You should only use the setter for this property from an
 *  MIKMIDIEndpointSynthesizer subclass.
 *
 *  @see -setupAUGraph
 */
@property (nonatomic, nullable) AUGraph graph;

// Deprecated

/**
 *  @deprecated This has been (renamed to) instrumentUnit. Use that instead.
 */
@property (nonatomic) AudioUnit instrument DEPRECATED_ATTRIBUTE;

@end

NS_ASSUME_NONNULL_END