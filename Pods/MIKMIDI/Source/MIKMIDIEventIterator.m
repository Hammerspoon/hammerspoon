//
//  MIKMIDIEventIterator.m
//  MIKMIDI
//
//  Created by Chris Flesner on 9/9/14.
//  Copyright (c) 2014 Mixed In Key. All rights reserved.
//

#import "MIKMIDIEventIterator.h"
#import "MIKMIDITrack.h"
#import "MIKMIDIEvent.h"

#if !__has_feature(objc_arc)
#error MIKMIDIEventIterator.m must be compiled with ARC. Either turn on ARC for the project or set the -fobjc-arc flag for MIKMIDIEventIterator.m in the Build Phases for this target
#endif

@interface MIKMIDIEventIterator ()

@property (nonatomic) MusicEventIterator iterator;

@end


@implementation MIKMIDIEventIterator

#pragma mark - Lifecycle

- (instancetype)initWithTrack:(MIKMIDITrack *)track
{
    if (self = [super init]) {
        OSStatus err = NewMusicEventIterator(track.musicTrack, &_iterator);
        if (err) {
            NSLog(@"NewMusicEventIterator() failed with error %@ in %s.", @(err), __PRETTY_FUNCTION__);
            return nil;
        }
    }
    return self;
}

+ (instancetype)iteratorForTrack:(MIKMIDITrack *)track
{
    return [[self alloc] initWithTrack:track];
}

- (instancetype)init
{
#ifdef DEBUG
    @throw [NSException exceptionWithName:NSGenericException reason:@"Invalid initializer." userInfo:nil];
#endif
    return nil;
}

- (void)dealloc
{
    OSStatus err = DisposeMusicEventIterator(_iterator);
    if (err) NSLog(@"DisposeMusicEventIterator() failed with error %@ in %s.", @(err), __PRETTY_FUNCTION__);
}

#pragma mark - Navigating

- (BOOL)seek:(MusicTimeStamp)timeStamp
{
    OSStatus err = MusicEventIteratorSeek(self.iterator, timeStamp);
    if (err) NSLog(@"MusicEventIteratorSeek() failed with error %@ in %s.", @(err), __PRETTY_FUNCTION__);
    return err == noErr;
}

- (BOOL)moveToNextEvent
{
    OSStatus err = MusicEventIteratorNextEvent(self.iterator);
    if (err) NSLog(@"MusicEventIteratorNextEvent() failed with error %@ in %s.", @(err), __PRETTY_FUNCTION__);
    return err == noErr;
}

- (BOOL)moveToPreviousEvent
{
    OSStatus err = MusicEventIteratorPreviousEvent(self.iterator);
    if (err) NSLog(@"MusicEventIteratorPreviousEvent() failed with error %@ in %s.", @(err), __PRETTY_FUNCTION__);
    return err == noErr;
}

- (BOOL)deleteCurrentEventWithError:(NSError **)error
{
	error = error ? error : &(NSError *__autoreleasing){ nil };
	OSStatus err = MusicEventIteratorDeleteEvent(self.iterator);
	if (err) {
		NSLog(@"MusicEventIteratorDeleteEvent() failed with error %@ in %s.", @(err), __PRETTY_FUNCTION__);
		*error = [NSError errorWithDomain:NSOSStatusErrorDomain code:err userInfo:nil];
		return NO;
	}
	return YES;
}

- (BOOL)moveCurrentEventTo:(MusicTimeStamp)timestamp error:(NSError **)error
{
	error = error ? error : &(NSError *__autoreleasing){ nil };
	OSStatus err = MusicEventIteratorSetEventTime(self.iterator, timestamp);
	if (err) {
		NSLog(@"MusicEventIteratorSetEventTime() failed with error %@ in %s.", @(err), __PRETTY_FUNCTION__);
		*error = [NSError errorWithDomain:NSOSStatusErrorDomain code:err userInfo:nil];
		return NO;
	}
	return YES;
}

#pragma mark - Current Event

- (MIKMIDIEvent *)currentEvent
{
    MusicTimeStamp timeStamp;
    MusicEventType type;
    const void *data;
    UInt32 dataSize;

    OSStatus err = MusicEventIteratorGetEventInfo(self.iterator, &timeStamp, &type, &data , &dataSize);
    if (err) {
        NSLog(@"MusicEventIteratorGetEventInfo() failed with error %@ in %s.", @(err), __PRETTY_FUNCTION__);
        return nil;
    }
    
    return [MIKMIDIEvent midiEventWithTimeStamp:timeStamp eventType:type data:[NSData dataWithBytes:data length:dataSize]];
}

#pragma mark - Properties

- (BOOL)hasPreviousEvent
{
    Boolean hasPreviousEvent = false;
    OSStatus err = MusicEventIteratorHasPreviousEvent(self.iterator, &hasPreviousEvent);
    if (err) NSLog(@"MusicEventIteratorHasPreviousEvent() failed with error %@ in %s.", @(err), __PRETTY_FUNCTION__);
    return hasPreviousEvent;
}

- (BOOL)hasCurrentEvent
{
    Boolean hasCurrentEvent = false;
    OSStatus err = MusicEventIteratorHasCurrentEvent(self.iterator, &hasCurrentEvent);
    if (err) NSLog(@"MusicEventIteratorHasCurrentEvent() failed with error %@ in %s.", @(err), __PRETTY_FUNCTION__);
    return hasCurrentEvent;
}

- (BOOL)hasNextEvent
{
    Boolean hasNextEvent = false;
    OSStatus err = MusicEventIteratorHasNextEvent(self.iterator, &hasNextEvent);
    if (err) NSLog(@"MusicEventIteratorHasNextEvent() failed with error %@ in %s.", @(err), __PRETTY_FUNCTION__);
    return hasNextEvent;
}

@end
