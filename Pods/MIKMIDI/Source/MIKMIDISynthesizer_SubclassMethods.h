//
//  MIKMIDISynthesizer_SubclassMethods.h
//  MIKMIDI
//
//  Created by Andrew Madsen on 2/26/15.
//  Copyright (c) 2015 Mixed In Key. All rights reserved.
//

#import "MIKMIDISynthesizer.h"
#import "MIKMIDICompilerCompatibility.h"

NS_ASSUME_NONNULL_BEGIN

@interface MIKMIDISynthesizer ()

- (BOOL)sendBankSelectAndProgramChangeForInstrumentID:(MusicDeviceInstrumentID)instrumentID error:(NSError **)error;

@property (nonatomic, readwrite, nullable) AudioUnit instrumentUnit;
@property (nonatomic, copy) OSStatus (^sendMIDICommand)(MIKMIDISynthesizer *synth, MusicDeviceComponent inUnit, UInt32 inStatus, UInt32 inData1, UInt32 inData2, UInt32 inOffsetSampleFrame);

@end

FOUNDATION_EXPORT OSStatus MIKMIDISynthesizerScheduleUpcomingMIDICommands(MIKMIDISynthesizer *synth,
																		  AudioUnit _Nullable instrumentUnit,
																		  UInt32 inNumberFrames,
																		  Float64 sampleRate,
																		  const AudioTimeStamp *inTimeStamp);

NS_ASSUME_NONNULL_END
