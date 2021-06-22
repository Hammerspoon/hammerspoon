#import <Cocoa/Cocoa.h>
#import <Carbon/Carbon.h>
#import <Foundation/Foundation.h>
#import <LuaSkin/LuaSkin.h>
#import <AudioToolbox/AudioQueue.h>
#import <AudioToolbox/AudioFile.h>

#include "detectors.h"

// This warning doesn't make sense for this application, where a system API needs direct pointers
// into a struct, and the hacks and heap allocation to use properties would be a performance hit
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wdirect-ivar-access"

#define NUM_BUFFERS 1
static const int kSampleRate = 44100;

#define USERDATA_TAG "hs.noises"
static LSRefTable refTable;
#define get_listener_arg(L, idx) (__bridge Listener*)*((void**)luaL_checkudata(L, idx, USERDATA_TAG))

typedef struct
{
  AudioStreamBasicDescription dataFormat;
  AudioQueueRef               queue;
  AudioQueueBufferRef         buffers[NUM_BUFFERS];
  AudioFileID                 audioFile;
  UInt64                      currentFrame;
  bool                        recording;
}RecordState;

@interface Listener : NSObject
- (Listener*)initPlugins;
- (void)setupAudioFormat:(AudioStreamBasicDescription*)format;
- (void)startRecording;
- (void)stopRecording;
- (void)feedSamplesToEngine:(UInt32)audioDataBytesCapacity audioData:(void *)audioData;
- (RecordState*)recordState;
- (void)runCallbackWithEvent: (NSNumber*)evNumber;
- (void)mainThreadCallback: (NSUInteger)evNumber;

@property lua_State* L;
@property int fn;
@end

void AudioInputCallback(void * inUserData,  // Custom audio metadata
                        AudioQueueRef inAQ,
                        AudioQueueBufferRef inBuffer,
                        const AudioTimeStamp * inStartTime,
                        UInt32 inNumberPacketDescriptions,
                        const AudioStreamPacketDescription * inPacketDescs) {

  Listener *rec = (__bridge Listener *)inUserData;
  RecordState * recordState = [rec recordState];
  if(!recordState->recording) return;

  AudioQueueEnqueueBuffer(recordState->queue, inBuffer, 0, NULL);
  [rec feedSamplesToEngine:inBuffer->mAudioDataBytesCapacity audioData:inBuffer->mAudioData];
}

@implementation Listener {
  RecordState recordState;
  detectors_t *detectors;
}

- (Listener*)initPlugins {
  self = [super init];
  if (self) {
    self.fn = LUA_NOREF ;
    recordState.recording = false;
    detectors = detectors_new();
  }
  return self;
}

- (void)dealloc {
  [self stopRecording]; // remove callbacks if not already stopped before deallocating
  detectors_free(detectors);
}

- (RecordState*)recordState {
  return &recordState;
}

- (void)setupAudioFormat:(AudioStreamBasicDescription*)format {
  format->mSampleRate = kSampleRate;

  format->mFormatID = kAudioFormatLinearPCM;
  format->mFormatFlags = kAudioFormatFlagsNativeFloatPacked;
  format->mFramesPerPacket  = 1;
  format->mChannelsPerFrame = 1;
  format->mBytesPerFrame    = sizeof(float);
  format->mBytesPerPacket   = sizeof(float);
  format->mBitsPerChannel   = sizeof(float) * 8;
}

- (void)startRecording {
  if(recordState.recording) return;
  [self setupAudioFormat:&recordState.dataFormat];

  recordState.currentFrame = 0;

  OSStatus status;
  status = AudioQueueNewInput(&recordState.dataFormat,
                              AudioInputCallback,
                              (__bridge void *)self,
                              NULL, // seems more responsive than CFRunLoopGetCurrent(),
                              kCFRunLoopCommonModes,
                              0,
                              &recordState.queue);

  if (status == 0) {

    for (int i = 0; i < NUM_BUFFERS; i++) {
      AudioQueueAllocateBuffer(recordState.queue, DETECTORS_BLOCK_SIZE*sizeof(float), &recordState.buffers[i]);
      AudioQueueEnqueueBuffer(recordState.queue, recordState.buffers[i], 0, nil);
    }

    recordState.recording = true;

    status = AudioQueueStart(recordState.queue, NULL);
  } else {
    NSLog(@"Error: Couldn't open audio queue.");
  }
}

- (void)stopRecording {
  if(!recordState.recording) return;
  recordState.recording = false;

  AudioQueueStop(recordState.queue, true);

  for (int i = 0; i < NUM_BUFFERS; i++) {
    AudioQueueFreeBuffer(recordState.queue, recordState.buffers[i]);
  }

  AudioQueueDispose(recordState.queue, true);
  AudioFileClose(recordState.audioFile);
}
- (void)mainThreadCallback: (NSUInteger)evNumber {
  [self performSelectorOnMainThread:@selector(runCallbackWithEvent:)
                         withObject:[NSNumber numberWithLong: evNumber] waitUntilDone:NO];
}

- (void)feedSamplesToEngine:(UInt32)audioDataBytesCapacity audioData:(void *)audioData {
  int sampleCount = audioDataBytesCapacity / sizeof(float);
  float *samples = (float*)audioData;
  NSAssert(sampleCount == DETECTORS_BLOCK_SIZE, @"Incorrect buffer size %i", sampleCount);

  int result = detectors_process(detectors, samples);
  if((result & TSS_START_CODE) == TSS_START_CODE) {
    [self mainThreadCallback: 1]; // Tss on
  }
  if((result & TSS_STOP_CODE) == TSS_STOP_CODE) {
    [self mainThreadCallback: 2]; // Tss off
  }
  if((result & POP_CODE) == POP_CODE) {
    [self mainThreadCallback: 3]; // Pop
  }

  recordState.currentFrame += sampleCount;
}

- (void)runCallbackWithEvent: (NSNumber*)evNumber {
  if (self.fn != LUA_NOREF) {
      LuaSkin *skin = [LuaSkin sharedWithState:NULL];
      lua_State* L = self.L;
      _lua_stackguard_entry(L);
      [skin pushLuaRef:refTable ref:self.fn];
      lua_pushinteger(L, [evNumber intValue]);
      [skin protectedCallAndError:@"hs.noises callback" nargs:1 nresults:0];
      _lua_stackguard_exit(L);
  }
}
@end

static int listener_gc(lua_State* L) {
  LuaSkin *skin = [LuaSkin sharedWithState:L];
  // Have to some contortions to make sure ARC properly frees the Listener
  void **userdata = (void**)luaL_checkudata(L, 1, USERDATA_TAG);
  Listener *listener = (__bridge_transfer Listener*)(*userdata);
  [listener stopRecording];
  listener.fn = [skin luaUnref:refTable ref:listener.fn];

  *userdata = nil;
  listener = nil;
  return 0;
}

/// hs.noises:stop() -> self
/// Method
/// Stops the listener from recording and analyzing microphone input.
///
/// Parameters:
///  * None
///
/// Returns:
///  * The `hs.noises` object
static int listener_stop(lua_State* L) {
  Listener* listener = get_listener_arg(L, 1);
  [listener stopRecording];
  lua_settop(L,1);
  return 1;
}

/// hs.noises:start() -> self
/// Method
/// Starts listening to the microphone and passing the audio to the recognizer.
///
/// Parameters:
///  * None
///
/// Returns:
///  * The `hs.noises` object
static int listener_start(lua_State* L) {
  Listener* listener = get_listener_arg(L, 1);
  [listener startRecording];
  lua_settop(L,1);
  return 1;
}

static int listener_eq(lua_State* L) {
  Listener* listenA = get_listener_arg(L, 1);
  Listener* listenB = get_listener_arg(L, 2);
  lua_pushboolean(L, listenA == listenB);
  return 1;
}

void new_listener(lua_State* L, Listener* listener) {
  void** listenptr = lua_newuserdata(L, sizeof(Listener**));
  *listenptr = (__bridge_retained void*)listener;

  luaL_getmetatable(L, USERDATA_TAG);
  lua_setmetatable(L, -2);
}

/// hs.noises.new(fn) -> listener
/// Constructor
/// Creates a new listener for mouth noise recognition
///
/// Parameters:
///  * A function that is called when a mouth noise is recognized. It should accept a single parameter which will be a number representing the event type (see module docs).
///
/// Returns:
///  * An `hs.noises` object
static int listener_new(lua_State* L) {
  LuaSkin *skin = [LuaSkin sharedWithState:L];
  [skin checkArgs:LS_TFUNCTION, LS_TBREAK];

  Listener *listener = [[Listener alloc] initPlugins];

  lua_pushvalue(L, 1);
  listener.fn = [skin luaRef:refTable];
  listener.L = L;
  new_listener(L, listener);
  return 1;
}

static int meta_gc(lua_State* __unused L) {
  return 0;
}

// Metatable for created objects when _new invoked
static const luaL_Reg noises_metalib[] = {
  {"start",   listener_start},
  {"stop",    listener_stop},
  {"__gc",    listener_gc},
  {"__eq",    listener_eq},
  {NULL,      NULL}
};

// Functions for returned object when module loads
static const luaL_Reg noisesLib[] = {
  {"new",    listener_new},
  {NULL,      NULL}
};

// Metatable for returned object when module loads
static const luaL_Reg meta_gcLib[] = {
  {"__gc",    meta_gc},
  {NULL,      NULL}
};

int luaopen_hs_noises_internal(lua_State* L) {
  LuaSkin *skin = [LuaSkin sharedWithState:L];
  refTable = [skin registerLibraryWithObject:USERDATA_TAG functions:noisesLib metaFunctions:meta_gcLib objectFunctions:noises_metalib];
  return 1;
}

#pragma clang diagnostic pop
