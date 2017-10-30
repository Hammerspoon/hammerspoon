//
//  MIKMIDICommandThrottler.m
//  MIKMIDI
//
//  Created by Andrew Madsen on 11/11/13.
//  Copyright (c) 2013 Mixed In Key. All rights reserved.
//

#import "MIKMIDICommandThrottler.h"
#import "MIKMIDIChannelVoiceCommand.h"
#import "MIKMIDIPrivateUtilities.h"

#if !__has_feature(objc_arc)
#error MIKMIDICommandThrottler.m must be compiled with ARC. Either turn on ARC for the project or set the -fobjc-arc flag for MIKMIDICommandThrottler.m in the Build Phases for this target
#endif

@interface MIKMIDICommandThrottler ()

@property (nonatomic, strong) NSMutableDictionary *throttleCounters;

@end

@implementation MIKMIDICommandThrottler

- (id)init
{
    self = [super init];
    if (self) {
        _throttleCounters = [[NSMutableDictionary alloc] init];
    }
    return self;
}

#pragma mark - Public

- (BOOL)shouldPassCommand:(MIKMIDIChannelVoiceCommand *)command forThrottlingFactor:(NSUInteger)factor
{
	if (factor <= 1) return YES;
	
	// Increment current count
	id key = [self throttleCounterKeyForCommand:command];
	NSNumber *count = self.throttleCounters[key];
	if (!count) count = @0;
	self.throttleCounters[key] = @([count unsignedIntegerValue] +1);
	
	return ([self.throttleCounters[key] unsignedIntegerValue] % factor == 0);
}

- (void)resetThrottlingCountForCommand:(MIKMIDIChannelVoiceCommand *)command;
{
	self.throttleCounters[[self throttleCounterKeyForCommand:command]] = @0;
}

#pragma mark - Private

- (id)throttleCounterKeyForCommand:(MIKMIDIChannelVoiceCommand *)command
{
//	char direction = 0;
//	if (command.commandType == MIKMIDICommandTypeControlChange) direction = command.value > 64;
	
	return @{@"channel" : @(command.channel),
			 @"controllerNumber" : @(MIKMIDIControlNumberFromCommand(command))};
}

@end
