//
//  MIKMIDIClientDestinationEndpoint.m
//  Pods
//
//  Created by Andrew Madsen on 9/26/14.
//
//

#import "MIKMIDIClientDestinationEndpoint.h"
#import "MIKMIDIObject_SubclassMethods.h"
#import "MIKMIDIDeviceManager.h"
#import "MIKMIDICommand.h"
#import "MIKMIDIUtilities.h"

#if !__has_feature(objc_arc)
#error MIKMIDIClientDestinationEndpoint.m must be compiled with ARC. Either turn on ARC for the project or set the -fobjc-arc flag for MIKMIDIClientDestinationEndpoint.m in the Build Phases for this target
#endif

@interface MIKMIDIClientDestinationEndpoint ()

@end

@implementation MIKMIDIClientDestinationEndpoint
{
	void *_selfTrampoline;
}

+ (NSArray *)representedMIDIObjectTypes; { return @[@(kMIDIObjectType_Destination)]; }

+ (MIDIClientRef)MIDIClient
{
	static MIDIClientRef client;
	static dispatch_once_t onceToken;
	dispatch_once(&onceToken, ^{
		OSStatus err = MIDIClientCreate(CFSTR("MIKMIDIDestinationEndpointMIDIClient"), NULL, NULL, &client);
		if (err) NSLog(@"Unable to create MIDI client for MIKMIDIDestinationEndpoint class.");
	});
	
	return client;
}

- (instancetype)initWithName:(NSString *)name receivedMessagesHandler:(MIKMIDIClientDestinationEndpointEventHandler)handler;
{
	__unsafe_unretained id *trampoline = (__unsafe_unretained id *)malloc(sizeof(id));
	
	MIDIEndpointRef endpoint;
	OSStatus err = MIDIDestinationCreate([[self class] MIDIClient], (__bridge CFStringRef)name, MIKMIDIDestinationReadProc, trampoline, &endpoint);
	if (err != noErr) {
		NSLog(@"%s failed. Unable to create MIDIDestination.", __PRETTY_FUNCTION__);
#if TARGET_OS_IPHONE
		if (err == kMIDINotPermitted) {
			NSLog(@"MIKMIDI's use of some CoreMIDI functions requires that your app have the audio key in its UIBackgroundModes.\n"
				  "Please see https://github.com/mixedinkey-opensource/MIKMIDI/wiki/Adding-Audio-to-UIBackgroundModes");
		}
#endif
		free(trampoline);
		return nil;
	}
	
	self = [self initWithObjectRef:endpoint];
	if (!self) {
		free(trampoline);
		return nil;
	}
	if (self) {
		*trampoline = self;
		_selfTrampoline = trampoline;
		
		_receivedMessagesHandler = handler;
	}
	return self;
}

- (void)dealloc
{
	if (_selfTrampoline) free(_selfTrampoline);
    MIDIEndpointDispose(self.objectRef);
}

#pragma mark - Private

void MIKMIDIDestinationReadProc(const MIDIPacketList *pktList, void *readProcRefCon, void *srcConnRefCon)
{
	if (!readProcRefCon) return;
	@autoreleasepool {
		MIKMIDIClientDestinationEndpoint *self = *(__unsafe_unretained MIKMIDIClientDestinationEndpoint **)readProcRefCon;
		
		NSMutableArray *receivedCommands = [NSMutableArray array];
		MIDIPacket *packet = (MIDIPacket *)pktList->packet;
		for (UInt32 i=0; i<pktList->numPackets; i++) {
            if (packet->length > 0) {
                NSArray *commands = [MIKMIDICommand commandsWithMIDIPacket:packet];
                if (commands) [receivedCommands addObjectsFromArray:commands];
            }
			packet = MIDIPacketNext(packet);
		}
		
		if ([receivedCommands count] && self.receivedMessagesHandler) {
			self.receivedMessagesHandler(self, receivedCommands);
		}
	}
}



@end
