//
//  MIKMIDIClock.m
//  MIKMIDI
//
//  Created by Chris Flesner on 11/26/14.
//  Copyright (c) 2014 Mixed In Key. All rights reserved.
//

#import "MIKMIDIClock.h"
#import "MIKMIDIUtilities.h"
#import <mach/mach_time.h>

#if !__has_feature(objc_arc)
#error MIKMIDIClock.m must be compiled with ARC. Either turn on ARC for the project or set the -fobjc-arc flag for MIKMIDIClock.m in the Build Phases for this target
#endif


#define kDurationToKeepHistoricalClocks	1.0


#pragma mark -
@interface MIKMIDISyncedClockProxy : NSProxy
+ (instancetype)syncedClockWithClock:(MIKMIDIClock *)masterClock;
@property (readonly, nonatomic) MIKMIDIClock *masterClock;
@end


#pragma mark -
@interface MIKMIDIClock ()
{
    Float64 _currentTempo;
    MIDITimeStamp _timeStampZero;
    MIDITimeStamp _lastSyncedMIDITimeStamp;
    MusicTimeStamp _lastSyncedMusicTimeStamp;
    
    Float64 _musicTimeStampsPerMIDITimeStamp;
    Float64 _midiTimeStampsPerMusicTimeStamp;
    
    CFMutableDictionaryRef _historicalClocks;
    CFMutableSetRef _historicalClockMIDITimeStampsSet;
    CFMutableArrayRef _historicalClockMIDITimeStampsArray;
    
    dispatch_queue_t _clockQueue;
}

@property (nonatomic, getter=isReady) BOOL ready;

@end


#pragma mark -
@implementation MIKMIDIClock

#pragma mark - Lifecycle

+ (instancetype)clock
{
    return [[self alloc] init];
}

- (instancetype)init
{
    return [self initWithQueue:YES];
}

- (instancetype)initWithQueue:(BOOL)createQueue
{
    if (self = [super init]) {
        if (createQueue) {
            NSString *queueLabel = [[[NSBundle mainBundle] bundleIdentifier] stringByAppendingFormat:@".%@.%p", [self class], self];
            dispatch_queue_attr_t attr = DISPATCH_QUEUE_SERIAL;
            
#if defined (__MAC_10_10) || defined (__IPHONE_8_0)
            if (@available(macOS 10.10, iOS 8, *)) {
                if (&dispatch_queue_attr_make_with_qos_class != NULL) {
                    attr = dispatch_queue_attr_make_with_qos_class(DISPATCH_QUEUE_SERIAL, QOS_CLASS_USER_INTERACTIVE, 0);
                }
            }
#endif
            
            _clockQueue = dispatch_queue_create(queueLabel.UTF8String, attr);
        }
    }
    return self;
}

- (void)dealloc
{
    releaseHistoricalClocks(self);
}

#pragma mark - Queue

static void dispatchToClockQueue(MIKMIDIClock *self, void(^block)(void))
{
    if (!block) return;
    
    dispatch_queue_t queue = self->_clockQueue;
    if (queue) {
        dispatch_sync(queue, block);
    } else {
        block();
    }
}

#pragma mark - Time Stamps

- (void)syncMusicTimeStamp:(MusicTimeStamp)musicTimeStamp withMIDITimeStamp:(MIDITimeStamp)midiTimeStamp tempo:(Float64)tempo
{
    [self willChangeValueForKey:@"ready"];
    dispatchToClockQueue(self, ^{
        if (self->_lastSyncedMIDITimeStamp != 0) {
            // Add a clock to the historical clocks
            NSNumber *midiTimeStampNumber = @(midiTimeStamp);
            
            if (!self->_historicalClocks) {
                self->_historicalClocks = CFDictionaryCreateMutable(NULL, 0, &kCFTypeDictionaryKeyCallBacks, &kCFTypeDictionaryValueCallBacks);
                self->_historicalClockMIDITimeStampsSet = CFSetCreateMutable(NULL, 0, &kCFTypeSetCallBacks);
                self->_historicalClockMIDITimeStampsArray = CFArrayCreateMutable(NULL, 0, &kCFTypeArrayCallBacks);
            } else {
                // Remove clocks old enough to not be needed anymore
                MIDITimeStamp oldTimeStamp = MIKMIDIGetCurrentTimeStamp() - MIKMIDIClockMIDITimeStampsPerTimeInterval(kDurationToKeepHistoricalClocks);
                
                CFIndex count = CFArrayGetCount(self->_historicalClockMIDITimeStampsArray);
                CFMutableArrayRef timeStampsToRemove = CFArrayCreateMutable(NULL, 0, &kCFTypeArrayCallBacks);
                CFMutableSetRef indexesToRemoveSet = CFSetCreateMutable(NULL, 0, &kCFTypeSetCallBacks);
                CFMutableArrayRef indexesToRemoveArray = CFArrayCreateMutable(NULL, 0, &kCFTypeArrayCallBacks);
                
                for (CFIndex i = 0; i < count; i++) {
                    NSNumber *timeStampNumber = (__bridge NSNumber *)CFArrayGetValueAtIndex(self->_historicalClockMIDITimeStampsArray, i);
                    MIDITimeStamp timeStamp = timeStampNumber.unsignedLongLongValue;
                    if (timeStamp <= oldTimeStamp) {
                        void *timeStampValue = (__bridge void *)timeStampNumber;
                        
                        CFArrayAppendValue(timeStampsToRemove, timeStampValue);
                        if (!CFSetContainsValue(indexesToRemoveSet, timeStampValue)) {
                            CFSetAddValue(indexesToRemoveSet, timeStampValue);
                            CFArrayAppendValue(indexesToRemoveArray, timeStampValue);
                        }
                    } else {
                        break;
                    }
                }
                
                CFIndex timeStampsToRemoveCount = CFArrayGetCount(timeStampsToRemove);
                for (CFIndex i = (timeStampsToRemoveCount - 1); i >= 0; i--) {
                    const void *timeStampValue = CFArrayGetValueAtIndex(timeStampsToRemove, i);
                    CFDictionaryRemoveValue(self->_historicalClocks, timeStampValue);
                    CFSetRemoveValue(self->_historicalClockMIDITimeStampsSet, timeStampValue);
                    CFArrayRemoveValueAtIndex(self->_historicalClockMIDITimeStampsArray, i);
                }
                
                CFRelease(timeStampsToRemove);
                CFRelease(indexesToRemoveSet);
                CFRelease(indexesToRemoveArray);
            }
            
            // Add clock to history
            MIKMIDIClock *historicalClock = [[MIKMIDIClock alloc] initWithQueue:NO];
            historicalClock->_currentTempo = self->_currentTempo;
            historicalClock->_timeStampZero = self->_timeStampZero;
            historicalClock->_lastSyncedMIDITimeStamp = self->_lastSyncedMIDITimeStamp;
			historicalClock->_lastSyncedMusicTimeStamp = self->_lastSyncedMusicTimeStamp;
            historicalClock->_musicTimeStampsPerMIDITimeStamp = self->_musicTimeStampsPerMIDITimeStamp;
            historicalClock->_midiTimeStampsPerMusicTimeStamp = self->_midiTimeStampsPerMusicTimeStamp;
            
            void *midiTimeStampValue = (__bridge void *)midiTimeStampNumber;
            CFDictionaryAddValue(self->_historicalClocks, midiTimeStampValue, (__bridge void *)historicalClock);
            
            if (!CFSetContainsValue(self->_historicalClockMIDITimeStampsSet, midiTimeStampValue)) {
                CFSetAddValue(self->_historicalClockMIDITimeStampsSet, midiTimeStampValue);
                CFArrayAppendValue(self->_historicalClockMIDITimeStampsArray, midiTimeStampValue);
            }
        }
        
        // Update new tempo and timing information
        Float64 secondsPerMIDITimeStamp = MIKMIDIClockSecondsPerMIDITimeStamp();
        Float64 secondsPerMusicTimeStamp = 60.0 / tempo;
        Float64 midiTimeStampsPerMusicTimeStamp = secondsPerMusicTimeStamp / secondsPerMIDITimeStamp;
        
        self->_currentTempo = tempo;
        self->_lastSyncedMIDITimeStamp = midiTimeStamp;
        self->_lastSyncedMusicTimeStamp = musicTimeStamp;
        self->_timeStampZero = midiTimeStamp - (musicTimeStamp * midiTimeStampsPerMusicTimeStamp);
        self->_midiTimeStampsPerMusicTimeStamp = midiTimeStampsPerMusicTimeStamp;
        self->_musicTimeStampsPerMIDITimeStamp = secondsPerMIDITimeStamp / secondsPerMusicTimeStamp;
        self->_ready = YES;
    });
    [self didChangeValueForKey:@"ready"];
}

- (void)unsyncMusicTimeStampsAndTemposFromMIDITimeStamps
{
    [self willChangeValueForKey:@"ready"];
    dispatchToClockQueue(self, ^{
        self->_ready = NO;
        self->_currentTempo = 0;
        self->_lastSyncedMIDITimeStamp = 0;
        releaseHistoricalClocks(self);
    });
    [self didChangeValueForKey:@"ready"];
}

static MusicTimeStamp musicTimeStampForMIDITimeStamp(MIKMIDIClock *self, MIDITimeStamp midiTimeStamp)
{
    __block MusicTimeStamp musicTimeStamp = 0;
    
    dispatchToClockQueue(self, ^{
        if (!self->_ready) return;
        
        MIDITimeStamp lastSyncedMIDITimeStamp = self->_lastSyncedMIDITimeStamp;
        if (midiTimeStamp >= lastSyncedMIDITimeStamp) {
            musicTimeStamp = musicTimeStampForMIDITimeStampWithHistoricalClock(midiTimeStamp, self);
        } else {
            musicTimeStamp = musicTimeStampForMIDITimeStampWithHistoricalClock(midiTimeStamp, clockForMIDITimeStamp(self, midiTimeStamp));
        }
    });
    
    return musicTimeStamp;
}

- (MusicTimeStamp)musicTimeStampForMIDITimeStamp:(MIDITimeStamp)midiTimeStamp
{
    return musicTimeStampForMIDITimeStamp(self, midiTimeStamp);
}

static MusicTimeStamp musicTimeStampForMIDITimeStampWithHistoricalClock(MIDITimeStamp midiTimeStamp, MIKMIDIClock *clock)
{
    if (midiTimeStamp == clock->_lastSyncedMIDITimeStamp) return clock->_lastSyncedMusicTimeStamp;
    MIDITimeStamp timeStampZero = clock->_timeStampZero;
    return (midiTimeStamp >= timeStampZero) ? ((midiTimeStamp - timeStampZero) * clock->_musicTimeStampsPerMIDITimeStamp) : -((timeStampZero - midiTimeStamp) * clock->_musicTimeStampsPerMIDITimeStamp);
}

static MIDITimeStamp midiTimeStampForMusicTimeStamp(MIKMIDIClock *self, MusicTimeStamp musicTimeStamp)
{
    __block MIDITimeStamp midiTimeStamp = 0;
    
    dispatchToClockQueue(self, ^{
        if (!self->_ready) return;
        if (musicTimeStamp == self->_lastSyncedMusicTimeStamp) { midiTimeStamp = self->_lastSyncedMIDITimeStamp; return; }
        
        midiTimeStamp = round(musicTimeStamp * self->_midiTimeStampsPerMusicTimeStamp) + self->_timeStampZero;
        
        if (midiTimeStamp < self->_lastSyncedMIDITimeStamp && self->_historicalClockMIDITimeStampsArray) {
            CFIndex historicalClockMIDITimeStampsCount = CFArrayGetCount(self->_historicalClockMIDITimeStampsArray);
            for (CFIndex i = (historicalClockMIDITimeStampsCount - 1); i >= 0; i--) {
                const void *midiTimeStampValue = CFArrayGetValueAtIndex(self->_historicalClockMIDITimeStampsArray, i);
                
                MIKMIDIClock *clock = (__bridge MIKMIDIClock *)CFDictionaryGetValue(self->_historicalClocks, midiTimeStampValue);
                MIDITimeStamp historicalMIDITimeStamp = round(musicTimeStamp * clock->_midiTimeStampsPerMusicTimeStamp) + clock->_timeStampZero;
                if (historicalMIDITimeStamp >= clock->_lastSyncedMIDITimeStamp) {
                    midiTimeStamp = historicalMIDITimeStamp;
                    break;
                }
            }
        }
    });
    
    return midiTimeStamp;
}

- (MIDITimeStamp)midiTimeStampForMusicTimeStamp:(MusicTimeStamp)musicTimeStamp
{
    return midiTimeStampForMusicTimeStamp(self, musicTimeStamp);
}

static MIDITimeStamp midiTimeStampsPerMusicTimeStamp(MIKMIDIClock *self, MusicTimeStamp musicTimeStamp)
{
    __block MIDITimeStamp midiTimeStamps = 0;
    
    dispatchToClockQueue(self, ^{
        if (self->_ready) midiTimeStamps = musicTimeStamp * self->_midiTimeStampsPerMusicTimeStamp;
    });
    
    return midiTimeStamps;
}

- (MIDITimeStamp)midiTimeStampsPerMusicTimeStamp:(MusicTimeStamp)musicTimeStamp
{
    return midiTimeStampsPerMusicTimeStamp(self, musicTimeStamp);
}

#pragma mark - Tempo

static Float64 tempoAtMIDITimeStamp(MIKMIDIClock *self, MIDITimeStamp midiTimeStamp)
{
    __block Float64 tempo = 0;
    
    dispatchToClockQueue(self, ^{
        if (self->_ready) {
            if (midiTimeStamp >= self->_lastSyncedMIDITimeStamp) {
                tempo = self->_currentTempo;
            } else {
                tempo = [clockForMIDITimeStamp(self, midiTimeStamp) currentTempo];
            }
        }
    });
    
    return tempo;
}

- (Float64)tempoAtMIDITimeStamp:(MIDITimeStamp)midiTimeStamp
{
    return tempoAtMIDITimeStamp(self, midiTimeStamp);
}

Float64 tempoAtMusicTimeStamp(MIKMIDIClock *self, MusicTimeStamp musicTimeStamp)
{
    return tempoAtMIDITimeStamp(self, midiTimeStampForMusicTimeStamp(self, musicTimeStamp));
}

- (Float64)tempoAtMusicTimeStamp:(MusicTimeStamp)musicTimeStamp
{
    return tempoAtMusicTimeStamp(self, musicTimeStamp);
}

#pragma mark - Historical Clocks

static MIKMIDIClock *clockForMIDITimeStamp(MIKMIDIClock *self, MIDITimeStamp midiTimeStamp)
{
    MIKMIDIClock *clock = self;
    
    if (self->_historicalClockMIDITimeStampsArray) {
        CFIndex count = CFArrayGetCount(self->_historicalClockMIDITimeStampsArray);
        for (CFIndex i = (count - 1); i >= 0; i--) {
            NSNumber *historicalClockTimeStamp = (__bridge NSNumber *)CFArrayGetValueAtIndex(self->_historicalClockMIDITimeStampsArray, i);
            if ([historicalClockTimeStamp unsignedLongLongValue] > midiTimeStamp) {
                clock = (__bridge MIKMIDIClock *)CFDictionaryGetValue(self->_historicalClocks, (__bridge void *)historicalClockTimeStamp);
            } else {
                break;
            }
        }
    }
    
    return clock;
}

static void releaseHistoricalClocks(MIKMIDIClock *self)
{
    if (self->_historicalClocks) {
        CFRelease(self->_historicalClocks);
        self->_historicalClocks = NULL;
    }
    if (self->_historicalClockMIDITimeStampsSet) {
        CFRelease(self->_historicalClockMIDITimeStampsSet);
        self->_historicalClockMIDITimeStampsSet = NULL;
    }
    if (self->_historicalClockMIDITimeStampsArray) {
        CFRelease(self->_historicalClockMIDITimeStampsArray);
        self->_historicalClockMIDITimeStampsArray = NULL;
    }
}

#pragma mark - Synced Clock

- (MIKMIDIClock *)syncedClock
{
    return (MIKMIDIClock *)[MIKMIDISyncedClockProxy syncedClockWithClock:self];
}

#pragma mark - Functions

Float64 MIKMIDIClockSecondsPerMIDITimeStamp()
{
    static Float64 secondsPerMIDITimeStamp;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        mach_timebase_info_data_t timeBaseInfoData;
        mach_timebase_info(&timeBaseInfoData);
        secondsPerMIDITimeStamp = ((Float64)timeBaseInfoData.numer / (Float64)timeBaseInfoData.denom) / 1.0e9;
    });
    return secondsPerMIDITimeStamp;
    
}

Float64 MIKMIDIClockMIDITimeStampsPerTimeInterval(NSTimeInterval timeInterval)
{
    static Float64 midiTimeStampsPerSecond = 0;
    if (!midiTimeStampsPerSecond) midiTimeStampsPerSecond = (1.0 / MIKMIDIClockSecondsPerMIDITimeStamp());
    return midiTimeStampsPerSecond * timeInterval;
}

#pragma mark - Deprecated Methods

- (void)setMusicTimeStamp:(MusicTimeStamp)musicTimeStamp withTempo:(Float64)tempo atMIDITimeStamp:(MIDITimeStamp)midiTimeStamp
{
    [self syncMusicTimeStamp:musicTimeStamp withMIDITimeStamp:midiTimeStamp tempo:tempo];
}

+ (Float64)secondsPerMIDITimeStamp
{
    return MIKMIDIClockSecondsPerMIDITimeStamp();
}

+ (Float64)midiTimeStampsPerTimeInterval:(NSTimeInterval)timeInterval
{
    return MIKMIDIClockMIDITimeStampsPerTimeInterval(timeInterval);
}

@end


#pragma mark -
@implementation MIKMIDISyncedClockProxy

+ (instancetype)syncedClockWithClock:(MIKMIDIClock *)masterClock
{
    MIKMIDISyncedClockProxy *proxy = [self alloc];
    proxy->_masterClock = masterClock;
    return proxy;
}

- (void)forwardInvocation:(NSInvocation *)invocation
{
    SEL selector = invocation.selector;
    
    // Optimizations
    if (selector == @selector(midiTimeStampForMusicTimeStamp:)) {
        MusicTimeStamp musicTimeStamp;
        [invocation getArgument:&musicTimeStamp atIndex:2];
        
        MIDITimeStamp midiTimeStamp = midiTimeStampForMusicTimeStamp(_masterClock, musicTimeStamp);
        return [invocation setReturnValue:&midiTimeStamp];
    } else if (selector == @selector(musicTimeStampForMIDITimeStamp:)) {
        MIDITimeStamp midiTimeStamp;
        [invocation getArgument:&midiTimeStamp atIndex:2];
        
        MusicTimeStamp musicTimeStamp = musicTimeStampForMIDITimeStamp(_masterClock, midiTimeStamp);
        return [invocation setReturnValue:&musicTimeStamp];
    } else if (selector == @selector(tempoAtMIDITimeStamp:)) {
        MIDITimeStamp midiTimeStamp;
        [invocation getArgument:&midiTimeStamp atIndex:2];
        
        Float64 tempo = tempoAtMIDITimeStamp(_masterClock, midiTimeStamp);
        return [invocation setReturnValue:&tempo];
    } else if (selector == @selector(tempoAtMusicTimeStamp:)) {
        MusicTimeStamp musicTimeStamp;
        [invocation getArgument:&musicTimeStamp atIndex:2];
        
        Float64 tempo = tempoAtMusicTimeStamp(_masterClock, musicTimeStamp);
        return [invocation setReturnValue:&tempo];
    } else if (selector == @selector(midiTimeStampsPerMusicTimeStamp:)) {
        MusicTimeStamp musicTimeStamp;
        [invocation getArgument:&musicTimeStamp atIndex:2];
        
        MIDITimeStamp midiTimeStamps = midiTimeStampsPerMusicTimeStamp(_masterClock, musicTimeStamp);
        return [invocation setReturnValue:&midiTimeStamps];
    } else if (selector == @selector(syncedClock)) {
        MIKMIDISyncedClockProxy *syncedClock = self;
        return [invocation setReturnValue:&syncedClock];
    }
    
    // Ignored selectors
    if (selector == @selector(syncMusicTimeStamp:withMIDITimeStamp:tempo:)) return;
    if (selector == @selector(unsyncMusicTimeStampsAndTemposFromMIDITimeStamps)) return;
    if (selector == @selector(setMusicTimeStamp:withTempo:atMIDITimeStamp:)) return;	// deprecated
    
    // Pass through remaining selectors
    [invocation invokeWithTarget:_masterClock];
}

- (NSMethodSignature *)methodSignatureForSelector:(SEL)sel
{
    return [_masterClock methodSignatureForSelector:sel];
}

@end
