//
//  MIKMIDIOutputPort.m
//  MIDI Testbed
//
//  Created by Andrew Madsen on 3/8/13.
//  Copyright (c) 2013 Mixed In Key. All rights reserved.
//

#import "MIKMIDIPort_SubclassMethods.h"
#import "MIKMIDIOutputPort.h"
#import "MIKMIDIDestinationEndpoint.h"
#import "MIKMIDICommand.h"
#import "MIKMIDICommand_SubclassMethods.h"

#if !__has_feature(objc_arc)
#error MIKMIDIOutputPort.m must be compiled with ARC. Either turn on ARC for the project or set the -fobjc-arc flag for MIKMIDIOutputPort.m in the Build Phases for this target
#endif

@implementation MIKMIDIOutputPort

- (instancetype)initWithClient:(MIDIClientRef)clientRef name:(NSString *)name
{
	self = [super initWithClient:clientRef name:name];
	if (self) {
		name = [name length] ? name : @"Input port";
		MIDIPortRef port;
		OSStatus error = MIDIOutputPortCreate(clientRef,
											  (__bridge CFStringRef)name,
											  &port);
		if (error != noErr) { self = nil; return nil; }
		self.portRef = port; // MIKMIDIPort will take care of disposing of the port when needed
	}
	return self;
}

- (BOOL)sendCommands:(NSArray *)commands toDestination:(MIKMIDIDestinationEndpoint *)destination error:(NSError **)error;
{
	commands = [self commandsByTransformingForTransmissionCommands:commands];
	if (![commands count] || !destination) return NO;
	
	error = error ? error : &(NSError *__autoreleasing){ nil };
	
	MIDIPacketList *packetList;
	if (!MIKCreateMIDIPacketListFromCommands(&packetList, commands)) return NO;
	
	OSStatus err = MIDISend(self.portRef, destination.objectRef, packetList);
	free(packetList);
	if (err != noErr) {
		*error = [NSError errorWithDomain:NSOSStatusErrorDomain code:err userInfo:nil];
		return NO;
	}
	
	return YES;
}

#pragma mark - Private


- (NSArray *)commandsByTransformingForTransmissionCommands:(NSArray *)commands
{
	NSMutableArray *transformedCommands = [NSMutableArray array];
	for (MIKMIDICommand *command in commands) {
		if ([command respondsToSelector:@selector(commandsForTransmission)]) {
			[transformedCommands addObjectsFromArray:[command commandsForTransmission]];
		} else {
			[transformedCommands addObject:command];
		}
	}
	return transformedCommands;
}

@end
