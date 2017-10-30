//
//  MIKMIDIEndpoint.m
//  MIDI Testbed
//
//  Created by Andrew Madsen on 3/7/13.
//  Copyright (c) 2013 Mixed In Key. All rights reserved.
//

#import "MIKMIDIEndpoint.h"
#import "MIKMIDIUtilities.h"
#import "MIKMIDIEntity.h"

#if !__has_feature(objc_arc)
#error MIKMIDIEndpoint.m must be compiled with ARC. Either turn on ARC for the project or set the -fobjc-arc flag for MIKMIDIEndpoint.m in the Build Phases for this target
#endif

@interface MIKMIDIEndpoint ()

@property (nonatomic, weak, readwrite) MIKMIDIEntity *entity;

@end

@implementation MIKMIDIEndpoint

// Should always be MIKMIDISourceEndpoint or MIKMIDIDestinationEndpoint

- (BOOL)isPrivate
{
	NSError *error = nil;
	SInt32 result = MIKIntegerPropertyFromMIDIObject(self.objectRef, kMIDIPropertyPrivate, &error);
	if (result == INT32_MIN) {
		NSLog(@"Error getting private status for MIDI endpoint %@: %@", self, error);
		return NO;
	}
	return (result != 0);
}


@end
