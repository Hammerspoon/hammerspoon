//
//  MIKMIDITrack_Protected.h
//  MIKMIDI
//
//  Created by Andrew Madsen on 2/25/15.
//  Copyright (c) 2015 Mixed In Key. All rights reserved.
//

#import "MIKMIDITrack.h"
#import "MIKMIDICompilerCompatibility.h"

NS_ASSUME_NONNULL_BEGIN

@interface MIKMIDITrack ()

/**
 *  Creates and initializes a new MIKMIDITrack.
 *
 *  @param sequence The MIDI sequence the new track will belong to.
 *  @param musicTrack The MusicTrack to use as the backing for the new MIDI track.
 *
 *  @note You should not call this method. It is for internal MIKMIDI use only.
 *  To add a new track to a MIDI sequence use -[MIKMIDISequence addTrack].
 */
+ (nullable instancetype)trackWithSequence:(MIKMIDISequence *)sequence musicTrack:(MusicTrack)musicTrack;

/**
 *  Sets a temporary length and loopInfo for the track.
 *
 *  @param length The temporary length for the track.
 *  @param loopInfo The temporary loopInfo for the track.
 *
 *  @note You should not call this method. It is exclusivley used by MIKMIDISequence when the sequence is being looped by a MIKMIDIPlayer.
 */
- (void)setTemporaryLength:(MusicTimeStamp)length andLoopInfo:(MusicTrackLoopInfo)loopInfo;

/**
 *  Restores the length and loopInfo of the track to what it was before calling -setTemporaryLength:andLoopInfo:.
 *
 *  @note You should not call this method. It is exclusively used by MIKMIDISequence when the sequence is being looped by a MIKMIDIPlayer.
 */
- (void)restoreLengthAndLoopInfo;

@end

NS_ASSUME_NONNULL_END