//
//  MIKMIDI.h
//  MIKMIDI
//
//  Created by Andrew Madsen on 6/2/13.
//  Copyright (c) 2013 Mixed In Key. All rights reserved.
//

/** Umbrella header for MIKMIDI public interface. */

// Core MIDI object wrapper
#import "MIKMIDIObject.h"

// MIDI port
#import "MIKMIDIPort.h"
#import "MIKMIDIInputPort.h"
#import "MIKMIDIOutputPort.h"

// MIDI Device support
#import "MIKMIDIDevice.h"
#import "MIKMIDIDeviceManager.h"
#import "MIKMIDIConnectionManager.h"

#import "MIKMIDIEntity.h"

// Endpoints
#import "MIKMIDIEndpoint.h"
#import "MIKMIDIDestinationEndpoint.h"
#import "MIKMIDISourceEndpoint.h"
#import "MIKMIDIClientDestinationEndpoint.h"
#import "MIKMIDIClientSourceEndpoint.h"

// MIDI Commands/Messages
#import "MIKMIDICommand.h"
#import "MIKMIDIChannelVoiceCommand.h"
#import "MIKMIDIChannelPressureCommand.h"
#import "MIKMIDIControlChangeCommand.h"
#import "MIKMIDIProgramChangeCommand.h"
#import "MIKMIDIPitchBendChangeCommand.h"
#import "MIKMIDINoteOnCommand.h"
#import "MIKMIDINoteOffCommand.h"
#import "MIKMIDIPolyphonicKeyPressureCommand.h"
#import "MIKMIDISystemExclusiveCommand.h"
#import "MIKMIDISystemMessageCommand.h"

// MIDI Sequence/File support
#import "MIKMIDISequence.h"
#import "MIKMIDITrack.h"

// MIDI Events
#import "MIKMIDIEvent.h"
#import "MIKMIDITempoEvent.h"
#import "MIKMIDINoteEvent.h"

// Channel Events
#import "MIKMIDIChannelEvent.h"
#import "MIKMIDIPolyphonicKeyPressureEvent.h"
#import "MIKMIDIControlChangeEvent.h"
#import "MIKMIDIProgramChangeEvent.h"
#import "MIKMIDIChannelPressureEvent.h"
#import "MIKMIDIPitchBendChangeEvent.h"

// Meta Events
#import "MIKMIDIMetaEvent.h"
#import "MIKMIDIMetaCopyrightEvent.h"
#import "MIKMIDIMetaCuePointEvent.h"
#import "MIKMIDIMetaInstrumentNameEvent.h"
#import "MIKMIDIMetaKeySignatureEvent.h"
#import "MIKMIDIMetaLyricEvent.h"
#import "MIKMIDIMetaMarkerTextEvent.h"
#import "MIKMIDIMetaSequenceEvent.h"
#import "MIKMIDIMetaTextEvent.h"
#import "MIKMIDIMetaTimeSignatureEvent.h"
#import "MIKMIDIMetaTrackSequenceNameEvent.h"

// Sequencing and Synthesis
#import "MIKMIDISequencer.h"
#import "MIKMIDIMetronome.h"
#import "MIKMIDIClock.h"
#import "MIKMIDIPlayer.h"
#import "MIKMIDIEndpointSynthesizer.h"

// MIDI Mapping
#import "MIKMIDIMapping.h"
#import "MIKMIDIMappingItem.h"
#import "MIKMIDIMappableResponder.h"
#import "MIKMIDIMappingManager.h"
#import "MIKMIDIMappingGenerator.h"

// Intra-application MIDI command routing
#import "NSUIApplication+MIKMIDI.h"
#import "MIKMIDIResponder.h"
#import "MIKMIDICommandThrottler.h"

// Utilities
#import "MIKMIDIUtilities.h"
#import "MIKMIDIErrors.h"
#import "MIKMIDICompilerCompatibility.h"
