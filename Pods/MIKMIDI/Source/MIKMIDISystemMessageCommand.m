//
//  MIKMIDISystemMessageCommand.m
//  MIDI Testbed
//
//  Created by Andrew Madsen on 6/2/13.
//  Copyright (c) 2013 Mixed In Key. All rights reserved.
//

#import "MIKMIDISystemMessageCommand.h"
#import "MIKMIDICommand_SubclassMethods.h"

#if !__has_feature(objc_arc)
#error MIKMIDISystemMessageCommand.m must be compiled with ARC. Either turn on ARC for the project or set the -fobjc-arc flag for MIKMIDISystemMessageCommand.m in the Build Phases for this target
#endif

@interface MIKMIDISystemMessageCommand ()

@end

@implementation	MIKMIDISystemMessageCommand

+ (void)load { [super load]; [MIKMIDICommand registerSubclass:self]; }
+ (NSArray *)supportedMIDICommandTypes
{
	return @[@(MIKMIDICommandTypeSystemMessage),
			 @(MIKMIDICommandTypeSystemTimecodeQuarterFrame),
			 @(MIKMIDICommandTypeSystemSongPositionPointer),
			 @(MIKMIDICommandTypeSystemSongSelect),
			 @(MIKMIDICommandTypeSystemTuneRequest)];
}

+ (Class)immutableCounterpartClass; { return [MIKMIDISystemMessageCommand class]; }
+ (Class)mutableCounterpartClass; { return [MIKMutableMIDISystemMessageCommand class]; }

@end

@implementation MIKMutableMIDISystemMessageCommand

+ (BOOL)isMutable { return YES; }

#pragma mark - Properties

// One of the super classes already implements a getter *and* setter for these. @dynamic keeps the compiler happy.
@dynamic timestamp;
@dynamic commandType;
@dynamic dataByte1;
@dynamic dataByte2;
@dynamic midiTimestamp;
@dynamic data;

@end
