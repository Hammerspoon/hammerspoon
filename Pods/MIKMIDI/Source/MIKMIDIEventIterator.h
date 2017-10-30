//
//  MIKMIDIEventIterator.h
//  MIKMIDI
//
//  Created by Chris Flesner on 9/9/14.
//  Copyright (c) 2014 Mixed In Key. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <AudioToolbox/AudioToolbox.h>
#import "MIKMIDICompilerCompatibility.h"

@class MIKMIDITrack;
@class MIKMIDIEvent;

NS_ASSUME_NONNULL_BEGIN

/**
 *  MIKMIDIEventIterator is an Objective-C wrapper for CoreMIDI's MusicEventIterator. It is not intended for use by clients/users of
 *  of MIKMIDI. Rather, it should be thought of as an MIKMIDI private class.
 */
@interface MIKMIDIEventIterator : NSObject

@property (nonatomic, readonly) BOOL hasPreviousEvent;
@property (nonatomic, readonly) BOOL hasCurrentEvent;
@property (nonatomic, readonly) BOOL hasNextEvent;
@property (nonatomic, readonly, nullable) MIKMIDIEvent *currentEvent;

- (nullable instancetype)initWithTrack:(MIKMIDITrack *)track;
+ (nullable instancetype)iteratorForTrack:(MIKMIDITrack *)track;

- (BOOL)seek:(MusicTimeStamp)timeStamp;
- (BOOL)moveToNextEvent;
- (BOOL)moveToPreviousEvent;
- (BOOL)deleteCurrentEventWithError:(NSError **)error;
- (BOOL)moveCurrentEventTo:(MusicTimeStamp)timestamp error:(NSError **)error;

@end

NS_ASSUME_NONNULL_END