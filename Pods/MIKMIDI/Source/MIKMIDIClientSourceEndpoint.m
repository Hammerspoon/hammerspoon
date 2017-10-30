//
//  MIKMIDIClientSourceEndpoint.m
//  MIKMIDI
//
//  Created by Dan Rosenstark on 2015-01-07
//

#import "MIKMIDIClientSourceEndpoint.h"
#import "MIKMIDICommand.h"

@implementation MIKMIDIClientSourceEndpoint

+ (NSArray *)representedMIDIObjectTypes; { return @[@(kMIDIObjectType_Source)]; }

- (instancetype)initWithName:(NSString*)name
{
	if (!name || name.length == 0) {
		[NSException raise:@"Problem instantiating MIKMIDIClientSourceEndpoint" format:@"Virtual endpoint needs name"];
	}
	
	MIDIClientRef midiClient;
	MIDIEndpointRef midiOut;
	
	MIDIClientCreate((__bridge CFStringRef)name, NULL, NULL, &midiClient);
	OSStatus err = MIDISourceCreate(midiClient, (__bridge CFStringRef)name, &midiOut);
	if (err != noErr) {
		NSLog(@"%s failed. Unable to create MIDISource.", __PRETTY_FUNCTION__);
#if TARGET_OS_IPHONE
		if (err == kMIDINotPermitted) {
			NSLog(@"MIKMIDI's use of some CoreMIDI functions requires that your app have the audio key in its UIBackgroundModes.\n"
				  "Please see https://github.com/mixedinkey-opensource/MIKMIDI/wiki/Adding-Audio-to-UIBackgroundModes");
		}
#endif
		return nil;
	}
	
	self = [super initWithObjectRef:midiOut];
	if (self) {
		
		
	}
	return self;
}

- (BOOL)sendCommands:(NSArray *)commands error:(NSError **)error
{
	if (![commands count]) return NO;
	
	error = error ? error : &(NSError *__autoreleasing){ nil };
	
	MIDIPacketList *packetList;
	if (!MIKCreateMIDIPacketListFromCommands(&packetList, commands)) return NO;
	OSStatus err = MIDIReceived(self.objectRef, packetList);
	
	free(packetList);
	if (err != noErr) {
		*error = [NSError errorWithDomain:NSOSStatusErrorDomain code:err userInfo:nil];
		return NO;
	}
	
	return YES;
}

-(void)dealloc
{
	MIDIEndpointDispose(self.objectRef);
}

@end
