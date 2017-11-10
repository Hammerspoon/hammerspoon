//
//  MIKMIDIClock.h
//  MIKMIDI
//
//  Created by Chris Flesner on 11/26/14.
//  Copyright (c) 2014 Mixed In Key. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <AudioToolbox/AudioToolbox.h>
#import "MIKMIDICompilerCompatibility.h"

/**
 *  Returns the number of MIDITimeStamps that would occur during a specified time interval.
 *
 *  @param timeInterval The number of seconds to convert into number of MIDITimeStamps.
 *
 *  @return The number of MIDITimeStamps that would occur in the specified time interval.
 */
Float64 MIKMIDIClockMIDITimeStampsPerTimeInterval(NSTimeInterval timeInterval);

/**
 *  Returns the number of seconds per each MIDITimeStamp.
 *
 *  @return Then number of seconds per each MIDITimeStamp.
 */
Float64 MIKMIDIClockSecondsPerMIDITimeStamp(void);

NS_ASSUME_NONNULL_BEGIN

/**
 *  MIKMIDIClock provides the number of seconds per MIDITimeStamp, as well as the
 *  number of MIDITimeStamps per a specified time interval.
 *
 *  Instances of MIKMIDIClock can be used to convert between MIDITimeStamp
 *  and MusicTimeStamp.
 */
@interface MIKMIDIClock : NSObject

/**
 *  Creates and initializes a new instance of MIKMIDIClock.
 *
 *  @return A new instance of MIKMIDIClock.
 */
+ (instancetype)clock;

/**
 *  Internally synchronizes the musicTimeStamp with the midiTimeStamp using the specified tempo. 
 *  This method must be called for the clock to become ready to use.
 *
 *  @param musicTimeStamp The MusicTimeStamp to synchronize the clock to.
 *  @param midiTimeStamp The MIDITimeStamp to synchronize the clock to.
 *	@param tempo The beats per minute at which MusicTimeStamps should tick.
 *
 *  @note When this method is called, historical tempo and timing information more than 1 second
 *  old is pruned. At that point, calls to -musicTimeStampForMIDITimeStamp:,
 *  -midiTimeStampForMusicTimeStamp:, -tempoAtMIDITimeStamp:, and -tempoAtMusicTimeStamp:
 *  with time stamps more than one second older than the time stamps set with this method
 *  may not necessarily return accurate information.
 *
 *	@see -unsyncMusicTimeStampsAndTemposFromMIDITimeStamps
 *  @see -isReady
 */
- (void)syncMusicTimeStamp:(MusicTimeStamp)musicTimeStamp withMIDITimeStamp:(MIDITimeStamp)midiTimeStamp tempo:(Float64)tempo;

/**
 *	Internally unsynchronizes the tempo and MusicTimeStamp information with MIDITimeStamps.
 *
 *  @see -syncMusicTimeStamp:withMIDITimeStamp:tempo:
 *	@see -isReady
 */
- (void)unsyncMusicTimeStampsAndTemposFromMIDITimeStamps;

/**
 *  Converts the specified MIDITimeStamp into the corresponding MusicTimeStamp.
 *
 *  @param midiTimeStamp The MIDITimeStamp to convert into a MusicTimeStamp.
 *
 *  @return The MusicTimeStamp that will occur at the same time as the specified MIDITimeStamp.
 *
 *  @note If the clock is not ready this method will return 0.
 *
 *  @see -isReady
 */
- (MusicTimeStamp)musicTimeStampForMIDITimeStamp:(MIDITimeStamp)midiTimeStamp;

/**
 *  Converts the specified MusicTimeStamp into the corresponding MIDITimeStamp.
 *
 *  @param musicTimeStamp The MusicTimeStamp to convert into a MIDITimeStamp.
 *
 *  @return The MIDITimeStamp that will occur at the same time as the specified MusicTimeStamp.
 *
 *  @note If the clock is not ready this method will return 0.
 *
 *  @see -isReady
 */
- (MIDITimeStamp)midiTimeStampForMusicTimeStamp:(MusicTimeStamp)musicTimeStamp;

/**
 *  Converts the specified number of beats in the MusicTimeStamp into the 
 *  corresponding number of MIDITimeStamps.
 *
 *  @param musicTimeStamp The number of beats to convert into MIDITimeStamps.
 *
 *  @return The number of MIDITimeStamps that will occur during the specified number of beats.
 *
 *  @note If the clock is not ready this method will return 0.
 *
 *  @see -isReady
 */
- (MIDITimeStamp)midiTimeStampsPerMusicTimeStamp:(MusicTimeStamp)musicTimeStamp;


/**
 *  A readonly copy of the clock that remains synced with this instance.
 *  
 *  This clock can be queried and will always return the same tempo and timing
 *  information as the clock instance that dispensed the synced clock.
 *
 *  Calling -syncMusicTimeStamp:withMIDITimeStamp:tempo: or 
 *  -unsyncMusicTimeStampsAndTemposFromMIDITimeStamps on the synced clock
 *  has no effect.
 */
- (MIKMIDIClock *)syncedClock;

/**
 *  Returns the tempo of the clock at the specified MIDITimeStamp.
 *
 *  @param midiTimeStamp The MIDITimeStamp you would like the clock's tempo for.
 *
 *  @return The tempo of the clock at the specified MIDITimeStamp.
 *
 *  @note If the clock is not ready this method will return 0.
 *
 *  @see -isReady
 */
- (Float64)tempoAtMIDITimeStamp:(MIDITimeStamp)midiTimeStamp;

/**
 *  Returns the tempo of the clock at the specified MusicTimeStamp.
 *
 *  @param musicTimeStamp The MusicTimeStamp you would like the clock's tempo for.
 *
 *  @return The tempo of the clock at the specified MusicTimeStamp.
 *
 *  @note If the clock is not ready this method will return 0.
 *
 *  @see -isReady
 */
- (Float64)tempoAtMusicTimeStamp:(MusicTimeStamp)musicTimeStamp;

/**
 *	Whether or not the clock has synchronized MusicTimeStamps and MIDITimeStamps
 *  and is ready to use for getting tempo and timing information.
 *
 *	@see -syncMusicTimeStamp:withMIDITimeStamp:tempo:
 *	@see -unsyncMusicTimeStampsAndTemposFromMIDITimeStamps
 */
@property (readonly, nonatomic, getter=isReady) BOOL ready;

/**
 *  The tempo that was set in the last call to -syncMusicTimeStamp:withMIDITimeStamp:tempo:
 *  or 0 if the clock is not ready.
 *
 *  If you need earlier tempo information use either -tempoAtMIDITimeStamp:
 *  or -tempoAtMusicTimeStamp:
 *
 *  @see -isReady
 */
@property (readonly, nonatomic) Float64 currentTempo;

#pragma mark - Deprecated Methods

/**
 *	@deprecated This method is deprecated. Use -[MIKMIDIClock
 *	syncMusicTimeStamp:withMIDITimeStamp:tempo:] instead.
 *
 *  Internally synchronizes the musicTimeStamp with the midiTimeStamp using the specified tempo. 
 *  This method must be called at least once before -musicTimeStampForMIDITimeStamp: and 
 *  -midiTimeStampForMusicTimeStamp: will return any meaningful values.
 *
 *  @param musicTimeStamp The MusicTimeStamp to synchronize the clock to.
 *  @param tempo The beats per minute at which MusicTimeStamps should tick.
 *  @param midiTimeStamp The MIDITimeStamp to synchronize the clock to.
 *
 *  @note When this method is called, historical tempo and timing information more than 1 second
 *  old is pruned. At that point, calls to -musicTimeStampForMIDITimeStamp:,
 *  -midiTimeStampForMusicTimeStamp:, -tempoAtMIDITimeStamp:, and -tempoAtMusicTimeStamp:
 *  with time stamps more than one second older than the time stamps set with this method
 *  may not necessarily return accurate information.
 *
 *  @see -musicTimeStampForMIDITimeStamp:
 *  @see -midiTimeStampForMusicTimeStamp:
 */
- (void)setMusicTimeStamp:(MusicTimeStamp)musicTimeStamp withTempo:(Float64)tempo atMIDITimeStamp:(MIDITimeStamp)midiTimeStamp DEPRECATED_ATTRIBUTE;

/**
 *	@deprecated This method is deprecated. Use MIKMIDIClockSecondsPerMIDITimeStamp() instead.
 *
 *  Returns the number of seconds per each MIDITimeStamp.
 *
 *  @return Then number of seconds per each MIDITimeStamp.
 */
+ (Float64)secondsPerMIDITimeStamp DEPRECATED_ATTRIBUTE;

/**
 *	@deprecated This method is deprecated. Use MIKMIDIClockMIDITimeStampsPerTimeInterval() instead.
 *
 *  Returns the number of MIDITimeStamps that would occur during a specified time interval.
 *
 *  @param timeInterval The number of seconds to convert into number of MIDITimeStamps.
 *
 *  @return The number of MIDITimeStamps that would occur in the specified time interval.
 */
+ (Float64)midiTimeStampsPerTimeInterval:(NSTimeInterval)timeInterval DEPRECATED_ATTRIBUTE;

@end

NS_ASSUME_NONNULL_END
