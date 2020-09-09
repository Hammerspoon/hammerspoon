//
//  MIKMIDIInputPort.m
//  MIDI Testbed
//
//  Created by Andrew Madsen on 3/8/13.
//  Copyright (c) 2013 Mixed In Key. All rights reserved.
//

#import "MIKMIDIPort_SubclassMethods.h"
#import <CoreMIDI/CoreMIDI.h>
#import "MIKMIDIInputPort.h"
#import "MIKMIDIPrivate.h"
#import "MIKMIDISourceEndpoint.h"
#import "MIKMIDICommand.h"
#import "MIKMIDISystemExclusiveCommand.h"
#import "MIKMIDIControlChangeCommand.h"
#import "MIKMIDIUtilities.h"

#if !__has_feature(objc_arc)
#error MIKMIDIInputPort.m must be compiled with ARC. Either turn on ARC for the project or set the -fobjc-arc flag for MIKMIDIInputPort.m in the Build Phases for this target
#endif

@interface MIKMIDIConnectionTokenAndEventHandler : NSObject

- (instancetype)initWithConnectionToken:(NSString *)token eventHandler:(MIKMIDIEventHandlerBlock)eventHandler;

@property (nonatomic, strong, readonly) NSString *connectionToken;
@property (nonatomic, strong, readonly) MIKMIDIEventHandlerBlock eventHandler;

@end

@interface MIKMIDIInputPort ()

@property (nonatomic, strong) NSMutableArray *internalSources;
@property (nonatomic, strong) MIKMapTableOf(MIKMIDIEndpoint *, NSMutableArray *) *handlerTokenPairsByEndpoint;
@property (nonatomic) dispatch_queue_t handlerTokenQueue;

@property (nonatomic, strong) NSMutableArray *bufferedMSBCommands;
@property (nonatomic) dispatch_queue_t bufferedCommandQueue;

@property (atomic, strong) NSMutableData *sysexData;
@property (atomic, strong) NSTimer *sysexTimeOutTimer;
@property (assign) MIDITimeStamp sysexStartTimeStamp;
@property (readonly) BOOL isCoalescingSysex;

@end

@implementation MIKMIDIInputPort

- (instancetype)initWithClient:(MIDIClientRef)clientRef name:(NSString *)name
{
	self = [super initWithClient:clientRef name:name];
	if (self) {
		name = [name length] ? name : @"Input port";
		MIDIPortRef port;
		OSStatus error = MIDIInputPortCreate(clientRef,
											 (__bridge CFStringRef)name,
											 MIKMIDIPortReadCallback,
											 (__bridge void *)self,
											 &port);
		if (error != noErr) { self = nil; return nil; }
		self.portRef = port; // MIKMIDIPort will take care of disposing of the port when needed
		
		_handlerTokenQueue = dispatch_queue_create("com.mixedinkey.MIKMIDI.com.mixedinkey.MIKMIDI.MIKMIDIInputPort.handlerTokenQueue", DISPATCH_QUEUE_SERIAL);
		dispatch_sync(_handlerTokenQueue, ^{
			self->_handlerTokenPairsByEndpoint = [NSMapTable mapTableWithKeyOptions:NSPointerFunctionsStrongMemory valueOptions:NSPointerFunctionsStrongMemory];
		});
		
		_internalSources = [[NSMutableArray alloc] init];
		_coalesces14BitControlChangeCommands = YES;
		
		_bufferedCommandQueue = dispatch_queue_create("com.mixedinkey.MIKMIDI.MIKMIDIInputPort.bufferedCommandQueue", DISPATCH_QUEUE_SERIAL);
		dispatch_sync(_bufferedCommandQueue, ^{ self.bufferedMSBCommands = [[NSMutableArray alloc] init]; });
		
		_sysexTimeOut = 1.0; // seconds
	}
	return self;
}

- (void)dealloc
{
	MIKMIDI_GCD_RELEASE(_bufferedCommandQueue);
	MIKMIDI_GCD_RELEASE(_handlerTokenQueue);
}

#pragma mark - Public

- (id)connectToSource:(MIKMIDISourceEndpoint *)source
				error:(NSError **)error
		 eventHandler:(MIKMIDIEventHandlerBlock)eventHandler
{
	error = error ?: &(NSError *__autoreleasing){ nil };
	if (![self.connectedSources containsObject:source] &&
		![self connectToSource:source error:error]) {
		return nil;
	}
	
	NSString *uuidString = [self createNewConnectionToken];
	[self addConnectionToken:uuidString andEventHandler:eventHandler forSource:source];
	return uuidString;
}

- (void)disconnectConnectionForToken:(id)token
{
	MIKMIDISourceEndpoint *source = [self sourceEndpointForConnectionToken:token];
	if (!source) return; // Already disconnected?
	
	[self removeEventHandlerForConnectionToken:token source:source];
	
	__block NSArray *handlerPairs = nil;
	dispatch_sync(self.handlerTokenQueue, ^{
		handlerPairs = [self.handlerTokenPairsByEndpoint objectForKey:source];
	});
	if (![handlerPairs count]) {
		[self disconnectFromSource:source];
	}
}

#pragma mark - Private

#pragma mark Connection / Disconnection

- (BOOL)connectToSource:(MIKMIDISourceEndpoint *)source error:(NSError **)error;
{
	if ([self.connectedSources containsObject:source]) return YES;
	
	error = error ? error : &(NSError *__autoreleasing){ nil };
	OSStatus err = MIDIPortConnectSource(self.portRef, source.objectRef, (__bridge void *)source);
	if (err != noErr) {
		*error = [NSError errorWithDomain:NSOSStatusErrorDomain code:err userInfo:nil];
		return NO;
	}
	[self addInternalSourcesObject:source];
	return YES;
}

- (void)disconnectFromSource:(MIKMIDISourceEndpoint *)source
{
	OSStatus err = MIDIPortDisconnectSource(self.portRef, source.objectRef);
	if (err != noErr) NSLog(@"Error disconnecting MIDI source %@ from port %@", source, self);
	[self removeInternalSourcesObject:source];
}

#pragma mark Event Handler Management

- (NSString *)createNewConnectionToken
{
	__block NSString *uuidString = nil;
	dispatch_sync(self.handlerTokenQueue, ^{
		do { // Very unlikely, but just to be safe
			CFUUIDRef uuid = CFUUIDCreate(kCFAllocatorDefault);
			uuidString = CFBridgingRelease(CFUUIDCreateString(kCFAllocatorDefault, uuid));
			CFRelease(uuid);
			MIKMIDIConnectionTokenAndEventHandler *existingPair = nil;
			for (NSArray *handlerPairs in self.handlerTokenPairsByEndpoint.objectEnumerator) {
				for (MIKMIDIConnectionTokenAndEventHandler *pair in handlerPairs) {
					if ([pair.connectionToken isEqualToString:uuidString]) {
						existingPair = pair;
						break;
					}
				}
			}
			if (!existingPair) break;
		} while (1);
	});
	return uuidString;
}

- (void)addConnectionToken:(NSString *)connectionToken andEventHandler:(MIKMIDIEventHandlerBlock)eventHandler forSource:(MIKMIDISourceEndpoint *)source
{
	MIKMIDIConnectionTokenAndEventHandler *tokenHandlerPair =
	[[MIKMIDIConnectionTokenAndEventHandler alloc] initWithConnectionToken:connectionToken eventHandler:eventHandler];
	dispatch_async(self.handlerTokenQueue, ^{
		NSMutableArray *tokenPairs = [self.handlerTokenPairsByEndpoint objectForKey:source];
		if (!tokenPairs) {
			tokenPairs = [NSMutableArray array];
			[self.handlerTokenPairsByEndpoint setObject:tokenPairs forKey:source];
		}
		[tokenPairs addObject:tokenHandlerPair];
	});
}

- (void)removeEventHandlerForConnectionToken:(NSString *)connectionToken source:(MIKMIDISourceEndpoint *)source
{
	dispatch_async(self.handlerTokenQueue, ^{
		NSMutableArray *handlerPairs = [self.handlerTokenPairsByEndpoint objectForKey:source];
		for (MIKMIDIConnectionTokenAndEventHandler *pair in [handlerPairs copy]) {
			if ([pair.connectionToken isEqual:connectionToken]) {
				[handlerPairs removeObject:pair];
			}
		}
	});
}

- (MIKMIDISourceEndpoint *)sourceEndpointForConnectionToken:(NSString *)token
{
	__block MIKMIDISourceEndpoint *result = nil;
	dispatch_sync(self.handlerTokenQueue, ^{
		for (MIKMIDISourceEndpoint *source in self.handlerTokenPairsByEndpoint) {
			NSArray *handlerPairs = [self.handlerTokenPairsByEndpoint objectForKey:source];
			for (MIKMIDIConnectionTokenAndEventHandler *handlerPair in handlerPairs) {
				if ([handlerPair.connectionToken isEqual:token]) {
					result = source;
					return; // Return from block
				}
			}
		}
	});
	return result;
}

#pragma mark Coaelescing

- (BOOL)commandIsPossibleMSBOf14BitCommand:(MIKMIDICommand *)command
{
	if (command.commandType != MIKMIDICommandTypeControlChange) return NO;
	
	MIKMIDIControlChangeCommand *controlChange = (MIKMIDIControlChangeCommand *)command;
	
	if (controlChange.isFourteenBitCommand) return NO; // Already coalesced
	return controlChange.controllerNumber < 32;
}

- (NSArray *)commandsByCoalescingCommands:(NSArray *)commands
{
	NSMutableArray *coalescedCommands = [commands mutableCopy];
	MIKMIDICommand *lastCommand = commands.firstObject;
	for (MIKMIDICommand *command in commands) {
		MIKMIDIControlChangeCommand *coalesced =
		[MIKMIDIControlChangeCommand commandByCoalescingMSBCommand:(MIKMIDIControlChangeCommand *)lastCommand
													 andLSBCommand:(MIKMIDIControlChangeCommand *)command];
		if (coalesced) {
			[coalescedCommands removeObject:command];
			NSUInteger lastCommandIndex = [coalescedCommands indexOfObject:lastCommand];
			[coalescedCommands replaceObjectAtIndex:lastCommandIndex withObject:coalesced];
		}
		lastCommand = command;
	}
	return [coalescedCommands copy];
}

- (BOOL)coalesceSysexFromMIDIPacket:(const MIDIPacket *)packet toCommandInArray:(NSMutableArray **)commandsArray
{	
	const Byte *data = packet->data;
	
	Byte firstByte = data[0];
	
	if (self.sysexData == nil) {
		// Check for Sysex Begin
		if (firstByte != kMIKMIDISysexBeginDelimiter) {
			return NO;
		}
		
		self.sysexData = [NSMutableData new];
		self.sysexStartTimeStamp = packet->timeStamp;
	} else if (firstByte > 0x7F && firstByte != kMIKMIDISysexEndDelimiter) {
		// Invalid Start Byte: send sysex buffered until now, even if invalid
		[*commandsArray addObject:[self commandByCoalescingSysexData]];
		// Parse current packet normally
		return NO;
	}
	
	for (UInt16 idx = 0; idx < packet->length; idx++) {
		Byte byte = data[idx];
		
		// Append byte
		[self.sysexData appendBytes:&byte length:1];
		
		// Check for Sysex End
		if (byte == kMIKMIDISysexEndDelimiter) {
			[*commandsArray addObject:[self commandByCoalescingSysexData]];
			break;
		}
	}
	
	return YES;
}

- (MIKMIDISystemExclusiveCommand *)commandByCoalescingSysexData
{
	NSParameterAssert(self.sysexData);
	
	MIKMIDISystemExclusiveCommand *command = [[MIKMIDISystemExclusiveCommand alloc] initWithRawData:self.sysexData timeStamp:self.sysexStartTimeStamp];
	
	// Clear Sysex Buffer & Timestamp
	self.sysexData = nil;
	self.sysexStartTimeStamp = 0;
	
	// Clear Sysex Timer
	[self.sysexTimeOutTimer invalidate];
	self.sysexTimeOutTimer = nil;
	
	return command;
}

#pragma mark Command Handling

- (void)sendCommands:(NSArray *)commands toEventHandlersFromSource:(MIKMIDISourceEndpoint *)source
{
	dispatch_async(self.handlerTokenQueue, ^{
		NSArray *handlerPairs = [self.handlerTokenPairsByEndpoint objectForKey:source];
		for (MIKMIDIConnectionTokenAndEventHandler *handlerTokenPair in handlerPairs) {
			MIKMIDIEventHandlerBlock eventHandler = handlerTokenPair.eventHandler;
			dispatch_async(dispatch_get_main_queue(), ^{
				eventHandler(source, commands);
			});
		}
	});
}

#pragma mark - Callbacks

// May be called on a background thread!
void MIKMIDIPortReadCallback(const MIDIPacketList *pktList, void *readProcRefCon, void *srcConnRefCon)
{
	@autoreleasepool {
		MIKMIDIInputPort *self = (__bridge MIKMIDIInputPort *)readProcRefCon;
		MIKMIDISourceEndpoint *source = (__bridge MIKMIDISourceEndpoint *)srcConnRefCon;
		
		[self interpretPacketList:pktList handleResultingCommands:^(NSArray <MIKMIDICommand*> *receivedCommands) {
			[self sendCommands:receivedCommands toEventHandlersFromSource:source];
		}];
	}
}

- (void)interpretPacketList:(const MIDIPacketList *)pktList handleResultingCommands:(void (^_Nonnull)(NSArray <MIKMIDICommand*> *receivedCommands))completionBlock
{
	NSMutableArray *receivedCommands = [NSMutableArray array];
	
	// Get the first packet
	MIDIPacket *packet = (MIDIPacket *)pktList->packet;
	
	for (UInt32 i = 0; i < pktList->numPackets; i++)
	{
		// Ignore empty packets
		if (packet->length == 0) {
			packet = MIDIPacketNext(packet);
			continue;
		}
		
		// Try Sysex Coalescing, otherwise parse MIDI commands
		if (![self coalesceSysexFromMIDIPacket:packet toCommandInArray:&receivedCommands]) {
			[receivedCommands addObjectsFromArray:[MIKMIDICommand commandsWithMIDIPacket:packet]];
		}
		
		packet = MIDIPacketNext(packet);
	}
	
	// Safeguard against sysex time-out
	if (self.isCoalescingSysex) {
		// Create or extend time-out timer
		if (!self.sysexTimeOutTimer) {
			// Weakify Self
			__weak typeof(self) weakSelf = self;
			
			self.sysexTimeOutTimer = [NSTimer timerWithTimeInterval:self.sysexTimeOut target:[NSBlockOperation blockOperationWithBlock:^{
				// Strongify Self
				__strong typeof(self) self = weakSelf;
				
				// Force-End Sysex, if necessary
				if (self.isCoalescingSysex) {
					completionBlock(@[[self commandByCoalescingSysexData]]);
				}
			}] selector:@selector(main) userInfo:nil repeats:NO];
			
			// Run Timer
			NSRunLoop *currentRunLoop = [NSRunLoop currentRunLoop];
			NSRunLoopMode mode = currentRunLoop.currentMode ?: NSDefaultRunLoopMode;
			
			[currentRunLoop addTimer:self.sysexTimeOutTimer forMode:mode];
		} else {
			self.sysexTimeOutTimer.fireDate = [NSDate dateWithTimeIntervalSinceNow:self.sysexTimeOut];
		}
		return;
	}
	
	// Clear Sysex Timer
	[self.sysexTimeOutTimer invalidate];
	self.sysexTimeOutTimer = nil;
	
	// Handle Commands
	if (receivedCommands.count == 0) {
		return;
	}
	
	if (self.coalesces14BitControlChangeCommands) {
		dispatch_sync(self.bufferedCommandQueue, ^{
			if ([self.bufferedMSBCommands count]) {
				[receivedCommands insertObject:self.bufferedMSBCommands.firstObject atIndex:0];
				[self.bufferedMSBCommands removeObjectAtIndex:0];
			}
		});
		receivedCommands = [[self commandsByCoalescingCommands:receivedCommands] mutableCopy];
		MIKMIDICommand *finalCommand = [receivedCommands lastObject];
		if ([self commandIsPossibleMSBOf14BitCommand:finalCommand]) {
			// Hold back and wait for a possible LSB command to come in.
			dispatch_sync(self.bufferedCommandQueue, ^{ [self.bufferedMSBCommands addObject:finalCommand]; });
			[receivedCommands removeLastObject];
			
			// Wait 4ms, then send the buffered command if it hasn't been coalesced (and therefore set to nil)
			dispatch_time_t popTime = dispatch_time(DISPATCH_TIME_NOW, (int64_t)(4 * NSEC_PER_MSEC));
			dispatch_after(popTime, self.bufferedCommandQueue, ^(void){
				if (![self.bufferedMSBCommands containsObject:finalCommand]) return;
				[self.bufferedMSBCommands removeObject:finalCommand];
				completionBlock(@[finalCommand]);
			});
		}
	}
	
	if ([receivedCommands count] == 0) {
		return;
	}
	
	completionBlock(receivedCommands);
}

#pragma mark - Properties

+ (NSSet *)keyPathsForValuesAffectingConnectedSources { return [NSSet setWithObjects:@"internalSources", nil]; }

- (NSArray *)connectedSources { return [self.internalSources copy]; }

- (void)addInternalSourcesObject:(MIKMIDISourceEndpoint *)source
{
	[self.internalSources addObject:source];
}

- (void)removeInternalSourcesObject:(MIKMIDISourceEndpoint *)source
{
	[self.internalSources removeObject:source];
}

@synthesize bufferedCommandQueue = _bufferedCommandQueue;

- (void)setCommandsBufferQueue:(dispatch_queue_t)commandsBufferQueue
{
	MIKMIDI_GCD_RETAIN(commandsBufferQueue);
	MIKMIDI_GCD_RELEASE(_bufferedCommandQueue);
	_bufferedCommandQueue = commandsBufferQueue;
}

@synthesize handlerTokenQueue = _handlerTokenQueue;

- (void)setHandlerTokenQueue:(dispatch_queue_t)handlerTokenQueue
{
	MIKMIDI_GCD_RETAIN(handlerTokenQueue);
	MIKMIDI_GCD_RELEASE(_handlerTokenQueue);
	_handlerTokenQueue = handlerTokenQueue;
}

- (BOOL)isCoalescingSysex
{
	return (self.sysexData != nil);
}

@end

#pragma mark -

@implementation MIKMIDIConnectionTokenAndEventHandler

- (instancetype)initWithConnectionToken:(NSString *)token eventHandler:(MIKMIDIEventHandlerBlock)eventHandler
{
	self = [super init];
	if (self) {
		_connectionToken = [token copy];
		_eventHandler = [eventHandler copy];
	}
	return self;
}

@end
