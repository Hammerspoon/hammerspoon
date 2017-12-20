//
//  MIKMIDISystemKeepAliveCommand.m
//  MIKMIDI
//
//  Created by Andrew Madsen on 11/9/17.
//  Copyright © 2017 Mixed In Key. All rights reserved.
//

#import "MIKMIDISystemKeepAliveCommand.h"
#import "MIKMIDICommand_SubclassMethods.h"

#if !__has_feature(objc_arc)
#error MIKMIDISystemExclusiveCommand.m must be compiled with ARC. Either turn on ARC for the project or set the -fobjc-arc flag for MIKMIDISystemExclusiveCommand.m in the Build Phases for this target
#endif

@implementation MIKMIDISystemKeepAliveCommand

+ (void)load { [super load]; [MIKMIDICommand registerSubclass:self]; }
+ (NSArray *)supportedMIDICommandTypes { return @[@(MIKMIDICommandTypeSystemKeepAlive)]; }
+ (Class)immutableCounterpartClass; { return [MIKMIDISystemKeepAliveCommand class]; }
+ (Class)mutableCounterpartClass; { return [MIKMutableMIDISystemKeepAliveCommand class]; }

+ (instancetype)keepAliveCommand
{
	return [[self alloc] init];
}

@end

@implementation MIKMutableMIDISystemKeepAliveCommand

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
