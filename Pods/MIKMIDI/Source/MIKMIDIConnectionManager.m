//
//  MIKMIDIConnectionManager.m
//  MIKMIDI
//
//  Created by Andrew Madsen on 11/5/15.
//  Copyright © 2015 Mixed In Key. All rights reserved.
//

#import "MIKMIDIConnectionManager.h"
#import "MIKMIDIDeviceManager.h"
#import "MIKMIDIDevice.h"
#import "MIKMIDIEntity.h"
#import "MIKMIDINoteOnCommand.h"
#import "MIKMIDINoteOffCommand.h"

#if TARGET_OS_IPHONE
#import <UIKit/UIApplication.h>
#else
#import <AppKit/NSApplication.h>
#endif

void *MIKMIDIConnectionManagerKVOContext = &MIKMIDIConnectionManagerKVOContext;

NSString * const MIKMIDIConnectionManagerConnectedDevicesKey = @"MIKMIDIConnectionManagerConnectedDevicesKey";
NSString * const MIKMIDIConnectionManagerUnconnectedDevicesKey = @"MIKMIDIConnectionManagerUnconnectedDevicesKey";

BOOL MIKMIDINoteOffCommandCorrespondsWithNoteOnCommand(MIKMIDINoteOffCommand *noteOff, MIKMIDINoteOnCommand *noteOn);

@interface MIKMIDIConnectionManager ()

@property (nonatomic, strong, readwrite) MIKArrayOf(MIKMIDIDevice *) *availableDevices;

@property (nonatomic, strong, readonly) MIKMutableSetOf(MIKMIDIDevice *) *internalConnectedDevices;
@property (nonatomic, strong, readonly) MIKMapTableOf(MIKMIDIDevice *, id) *connectionTokensByDevice;

@property (nonatomic, strong) MIKMapTableOf(MIKMIDIDevice *, NSMutableArray *) *pendingNoteOnsByDevice;

@property (nonatomic, readonly) MIKMIDIDeviceManager *deviceManager;

@end

@implementation MIKMIDIConnectionManager

- (instancetype)init
{
	[NSException raise:NSInternalInconsistencyException format:@"-initWithName: is the designated initializer for %@", NSStringFromClass([self class])];
	return nil;
}

- (instancetype)initWithName:(NSString *)name delegate:(id<MIKMIDIConnectionManagerDelegate>)delegate eventHandler:(MIKMIDIEventHandlerBlock)eventHandler
{
	self = [super init];
	if (self) {
		_name = [name copy];
		_delegate = delegate;
		_eventHandler = eventHandler;
		
		_automaticallySavesConfiguration = YES;
		_includesVirtualDevices = YES;
		
		_internalConnectedDevices = [[NSMutableSet alloc] init];
		
		_connectionTokensByDevice = [NSMapTable mapTableWithKeyOptions:NSPointerFunctionsStrongMemory valueOptions:NSPointerFunctionsStrongMemory];
		_pendingNoteOnsByDevice = [NSMapTable mapTableWithKeyOptions:NSPointerFunctionsStrongMemory valueOptions:NSPointerFunctionsStrongMemory];
		
		NSKeyValueObservingOptions options = NSKeyValueObservingOptionNew | NSKeyValueObservingOptionOld;
		[self.deviceManager addObserver:self forKeyPath:@"availableDevices" options:options context:MIKMIDIConnectionManagerKVOContext];
		[self.deviceManager addObserver:self forKeyPath:@"virtualSources" options:options context:MIKMIDIConnectionManagerKVOContext];
		[self.deviceManager addObserver:self forKeyPath:@"virtualDestinations" options:options context:MIKMIDIConnectionManagerKVOContext];
		
		NSNotificationCenter *nc = [NSNotificationCenter defaultCenter];
		[nc addObserver:self selector:@selector(deviceWasPluggedIn:) name:MIKMIDIDeviceWasAddedNotification object:nil];
		[nc addObserver:self selector:@selector(deviceWasUnplugged:) name:MIKMIDIDeviceWasRemovedNotification object:nil];
		[nc addObserver:self selector:@selector(endpointWasPluggedIn:) name:MIKMIDIVirtualEndpointWasAddedNotification object:nil];
		[nc addObserver:self selector:@selector(endpointWasUnplugged:) name:MIKMIDIVirtualEndpointWasRemovedNotification object:nil];
		
#if TARGET_OS_IPHONE
		[nc addObserver:self selector:@selector(saveConfigurationOnApplicationLifecycleEvent:) name:UIApplicationDidEnterBackgroundNotification object:nil];
		[nc addObserver:self selector:@selector(saveConfigurationOnApplicationLifecycleEvent:) name:UIApplicationWillTerminateNotification object:nil];
#else
		[nc addObserver:self selector:@selector(saveConfigurationOnApplicationLifecycleEvent:) name:NSApplicationWillTerminateNotification object:nil];
#endif
		
		[self updateAvailableDevices];
		[self scanAndConnectToInitialAvailableDevices];
	}
	return self;
}

- (instancetype)initWithName:(NSString *)name
{
	return [self initWithName:name delegate:nil eventHandler:nil];
}

- (void)dealloc
{
    __strong typeof(_delegate) delegate = self.delegate;
	for (MIKMIDIDevice *device in self.connectionTokensByDevice) {
		id token = [self.connectionTokensByDevice objectForKey:device];
		[self.deviceManager disconnectConnectionForToken:token];
		if ([delegate respondsToSelector:@selector(connectionManager:deviceWasDisconnected:withUnterminatedNoteOnCommands:)]) {
			NSArray *pendingNoteOns = [self pendingNoteOnCommandsForDevice:device];
			[delegate connectionManager:self deviceWasDisconnected:device withUnterminatedNoteOnCommands:pendingNoteOns];
		}
	}
	
	[self.deviceManager removeObserver:self forKeyPath:@"availableDevices" context:MIKMIDIConnectionManagerKVOContext];
	[self.deviceManager removeObserver:self forKeyPath:@"virtualSources" context:MIKMIDIConnectionManagerKVOContext];
	[self.deviceManager removeObserver:self forKeyPath:@"virtualDestinations" context:MIKMIDIConnectionManagerKVOContext];
	
	[[NSNotificationCenter defaultCenter] removeObserver:self];
}

#pragma mark - Public

#pragma mark Device Connection / Disconnection

- (BOOL)connectToDevice:(MIKMIDIDevice *)device error:(NSError **)error
{
	BOOL result = [self internalConnectToDevice:device error:error];
	if (self.automaticallySavesConfiguration) [self saveConfiguration];
	return result;
}

- (void)disconnectFromDevice:(MIKMIDIDevice *)device
{
	[self internalDisconnectFromDevice:device];
	if (self.automaticallySavesConfiguration) [self saveConfiguration];
}

- (BOOL)isConnectedToDevice:(MIKMIDIDevice *)device;
{
	return [self.connectedDevices containsObject:device];
}

#pragma mark Configuration Persistence

- (void)saveConfiguration
{
	NSUserDefaults *userDefaults = [NSUserDefaults standardUserDefaults];
	
	NSMutableDictionary *configuration = [NSMutableDictionary dictionaryWithDictionary:[self savedConfiguration]];
	
	// Save connected device names
	NSMutableArray *connectedDeviceNames = [configuration[MIKMIDIConnectionManagerConnectedDevicesKey] mutableCopy];
	if (!connectedDeviceNames) {
		connectedDeviceNames = [NSMutableArray array];
		configuration[MIKMIDIConnectionManagerConnectedDevicesKey] = connectedDeviceNames;
	}
	
	// And explicitly unconnected device names
	NSMutableArray *unconnectedDeviceNames = [configuration[MIKMIDIConnectionManagerUnconnectedDevicesKey] mutableCopy];
	if (!unconnectedDeviceNames) {
		unconnectedDeviceNames = [NSMutableArray array];
		configuration[MIKMIDIConnectionManagerUnconnectedDevicesKey] = unconnectedDeviceNames;
	}
	
	// For devices that were connected in saved configuration but are now unavailable, leave them
	// connected in the configuration so they'll reconnect automatically.
	for (MIKMIDIDevice *device in self.availableDevices) {
		NSString *name = device.name;
		if (![name length]) continue;
		if ([self isConnectedToDevice:device]) {
			if (![connectedDeviceNames containsObject:name]) { [connectedDeviceNames addObject:name]; }
			[unconnectedDeviceNames removeObject:name];
		} else {
			[connectedDeviceNames removeObject:name];
			if (![unconnectedDeviceNames containsObject:name]) { [unconnectedDeviceNames addObject:name]; }
		}
	}
	
	configuration[MIKMIDIConnectionManagerConnectedDevicesKey] = connectedDeviceNames;
	configuration[MIKMIDIConnectionManagerUnconnectedDevicesKey] = unconnectedDeviceNames;
	
	[userDefaults setObject:configuration forKey:[self userDefaultsConfigurationKey]];
}

- (void)loadConfiguration
{
	for (MIKMIDIDevice *device in self.availableDevices) {
		if ([self deviceIsUnconnectedInSavedConfiguration:device]) {
			[self internalDisconnectFromDevice:device];
		} else if ([self deviceIsConnectedInSavedConfiguration:device]) {
			NSError *error = nil;
			if (![self internalConnectToDevice:device error:&error]) {
				NSLog(@"Unable to connect to MIDI device %@: %@", device, error);
				return;
			}
		}
	}
}

#pragma mark - Private

- (void)updateAvailableDevices
{
	NSArray *regularDevices = self.deviceManager.availableDevices;
	NSMutableArray *result = [NSMutableArray arrayWithArray:regularDevices];
	
	if (self.includesVirtualDevices) {
		NSMutableSet *endpointsInDevices = [NSMutableSet set];
		for (MIKMIDIDevice *device in regularDevices) {
			NSSet *sources = [NSSet setWithArray:[device.entities valueForKeyPath:@"@distinctUnionOfArrays.sources"]];
			NSSet *destinations = [NSSet setWithArray:[device.entities valueForKeyPath:@"@distinctUnionOfArrays.destinations"]];
			[endpointsInDevices unionSet:sources];
			[endpointsInDevices unionSet:destinations];
		}
		
		NSMutableSet *devicelessSources = [NSMutableSet setWithArray:self.deviceManager.virtualSources];
		NSMutableSet *devicelessDestinations = [NSMutableSet setWithArray:self.deviceManager.virtualDestinations];
		[devicelessSources minusSet:endpointsInDevices];
		[devicelessDestinations minusSet:endpointsInDevices];
		
		// Now we need to try to associate each source with its corresponding destination on the same device
		NSMapTable *destinationToSourceMap = [NSMapTable mapTableWithKeyOptions:NSMapTableStrongMemory valueOptions:NSMapTableStrongMemory];
		NSMapTable *deviceNamesBySource = [NSMapTable mapTableWithKeyOptions:NSMapTableStrongMemory valueOptions:NSMapTableStrongMemory];
		
		for (MIKMIDIEndpoint *source in devicelessSources) {
			NSString *sourceName = [self deviceNameFromVirtualEndpoint:source];
			for (MIKMIDIEndpoint *destination in devicelessDestinations) {
				NSString *destinationName = [self deviceNameFromVirtualEndpoint:destination];
				if ([sourceName isEqualToString:destinationName]) { // Source and destination match
					[destinationToSourceMap setObject:destination forKey:source];
					[deviceNamesBySource setObject:sourceName forKey:source];
					break;
				}
			}
		}
		
		for (MIKMIDIEndpoint *source in destinationToSourceMap) {
			MIKMIDIEndpoint *destination = [destinationToSourceMap objectForKey:source];
			[devicelessSources removeObject:source];
			[devicelessDestinations removeObject:destination];
			
			MIKMIDIDevice *device = [MIKMIDIDevice deviceWithVirtualEndpoints:@[source, destination]];
			device.name = [deviceNamesBySource objectForKey:source];
			if (device) [result addObject:device];
		}
		for (MIKMIDIEndpoint *endpoint in devicelessSources) {
			MIKMIDIDevice *device = [MIKMIDIDevice deviceWithVirtualEndpoints:@[endpoint]];
			if (device) [result addObject:device];
		}
	}
	
	self.availableDevices = [result copy];
}

- (MIKMIDIDevice *)firstAvailableDeviceWithName:(NSString *)deviceName
{
	NSPredicate *predicate = [NSPredicate predicateWithFormat:@"name == %@", deviceName];
	return [[self.availableDevices filteredArrayUsingPredicate:predicate] firstObject];
}

#pragma mark Connection / Disconnection

- (BOOL)internalConnectToDevice:(MIKMIDIDevice *)device error:(NSError **)error
{
	if ([self isConnectedToDevice:device]) return YES;
	error = error ?: &(NSError *__autoreleasing){ nil };
	
	__weak typeof(self) weakSelf = self;
	id token = [self.deviceManager connectDevice:device error:error eventHandler:^(MIKMIDISourceEndpoint *endpoint, NSArray *commands) {
		__strong typeof(self) strongSelf = weakSelf;
		if (!strongSelf) { return; } // shouldn't actually happen
		[strongSelf recordPendingNoteOnCommands:commands fromDevice:device];
		[strongSelf removePendingNoteOnCommandsTerminatedByNoteOffCommands:commands fromDevice:device];
		
		MIKMIDIEventHandlerBlock eventHandler = [strongSelf eventHandler];
		if (eventHandler) { eventHandler(endpoint, commands); }
	}];
	if (!token) return NO;
	
	[self.connectionTokensByDevice setObject:token forKey:device];
	[self willChangeValueForKey:@"connectedDevices"
				withSetMutation:NSKeyValueUnionSetMutation
				   usingObjects:[NSSet setWithObject:device]];
	[self.internalConnectedDevices addObject:device];
	[self didChangeValueForKey:@"connectedDevices"
			   withSetMutation:NSKeyValueUnionSetMutation
				  usingObjects:[NSSet setWithObject:device]];
	
    __strong typeof(_delegate) delegate = self.delegate;
	if ([delegate respondsToSelector:@selector(connectionManager:deviceWasConnected:)]) {
		[delegate connectionManager:self deviceWasConnected:device];
	}
	
	return YES;
}

- (void)internalDisconnectFromDevice:(MIKMIDIDevice *)device
{
	if (![self isConnectedToDevice:device]) return;
	
	id token = [self.connectionTokensByDevice objectForKey:device];
	if (!token) return;
	
	[self.deviceManager disconnectConnectionForToken:token];
	
	[self.connectionTokensByDevice removeObjectForKey:device];
	[self willChangeValueForKey:@"connectedDevices"
				withSetMutation:NSKeyValueMinusSetMutation
				   usingObjects:[NSSet setWithObject:device]];
	[self.internalConnectedDevices removeObject:device];
	[self didChangeValueForKey:@"connectedDevices"
			   withSetMutation:NSKeyValueMinusSetMutation
				  usingObjects:[NSSet setWithObject:device]];
	
    __strong typeof(_delegate) delegate = self.delegate;
	if ([delegate respondsToSelector:@selector(connectionManager:deviceWasDisconnected:withUnterminatedNoteOnCommands:)]) {
		NSArray *pendingNoteOns = [self pendingNoteOnCommandsForDevice:device];
		[delegate connectionManager:self deviceWasDisconnected:device withUnterminatedNoteOnCommands:pendingNoteOns];
	}
	
	if (self.automaticallySavesConfiguration) [self saveConfiguration];
}

- (void)scanAndConnectToInitialAvailableDevices
{
	for (MIKMIDIDevice *device in self.availableDevices) {
		[self connectToNewlyAddedDeviceIfAppropriate:device];
	}
}

- (void)connectToNewlyAddedDeviceIfAppropriate:(MIKMIDIDevice *)device
{
	if (!device) return;
	
	MIKMIDIAutoConnectBehavior behavior = MIKMIDIAutoConnectBehaviorConnectIfPreviouslyConnectedOrNew;
	
    __strong typeof(_delegate) delegate = self.delegate;
	if ([delegate respondsToSelector:@selector(connectionManager:shouldConnectToNewlyAddedDevice:)]) {
		behavior = [delegate connectionManager:self shouldConnectToNewlyAddedDevice:device];
	}
	
	BOOL shouldConnect = NO;
	switch (behavior) {
		case MIKMIDIAutoConnectBehaviorDoNotConnect:
			shouldConnect = NO;
			break;
		case MIKMIDIAutoConnectBehaviorConnect:
			shouldConnect = YES;
			break;
		case MIKMIDIAutoConnectBehaviorConnectOnlyIfPreviouslyConnected:
			shouldConnect = [self deviceIsConnectedInSavedConfiguration:device];
			break;
		case MIKMIDIAutoConnectBehaviorConnectIfPreviouslyConnectedOrNew:
			shouldConnect = ![self deviceIsUnconnectedInSavedConfiguration:device];
			break;
	}
	
	if (shouldConnect) {
		NSError *error = nil;
		if (![self internalConnectToDevice:device error:&error]) {
			NSLog(@"Unable to connect to MIDI device %@: %@", device, error);
			return;
		}
	}
}

#pragma mark Configuration Persistence

- (NSString *)userDefaultsConfigurationKey
{
	NSString *name = self.name;
	if (![name length]) name = NSStringFromClass([self class]);
	return [NSString stringWithFormat:@"%@SavedMIDIConnectionConfiguration", name];
}

- (NSDictionary *)savedConfiguration
{
	NSUserDefaults *userDefaults = [NSUserDefaults standardUserDefaults];
	return [userDefaults objectForKey:[self userDefaultsConfigurationKey]];
}

- (BOOL)deviceIsConnectedInSavedConfiguration:(MIKMIDIDevice *)device
{
	NSString *deviceName = device.name;
	if (![deviceName length]) return NO;
	
	NSDictionary *configuration = [self savedConfiguration];
	NSArray *connectedDeviceNames = configuration[MIKMIDIConnectionManagerConnectedDevicesKey];
	return [connectedDeviceNames containsObject:deviceName];
}

- (BOOL)deviceIsUnconnectedInSavedConfiguration:(MIKMIDIDevice *)device
{
	NSString *deviceName = device.name;
	if (![deviceName length]) return NO;
	
	NSDictionary *configuration = [self savedConfiguration];
	NSArray *unconnectedDeviceNames = configuration[MIKMIDIConnectionManagerUnconnectedDevicesKey];
	return [unconnectedDeviceNames containsObject:deviceName];
}

#pragma mark Virtual Endpoints

- (NSString *)deviceNameFromVirtualEndpoint:(MIKMIDIEndpoint *)endpoint
{
	NSString *name = endpoint.name;
	if (![name length]) name = [endpoint description];
	NSCharacterSet *whitespace = [NSCharacterSet whitespaceCharacterSet];
	NSMutableArray *nameComponents = [[name componentsSeparatedByCharactersInSet:whitespace] mutableCopy];
	[nameComponents removeLastObject];
	return [nameComponents componentsJoinedByString:@" "];
}

- (MIKMIDIDevice *)deviceContainingEndpoint:(MIKMIDIEndpoint *)endpoint
{
	if (!endpoint) return nil;
	NSMutableSet *devices = [NSMutableSet setWithArray:self.availableDevices];
	[devices unionSet:self.connectedDevices];
	for (MIKMIDIDevice *device in devices) {
		NSMutableSet *deviceEndpoints = [NSMutableSet setWithArray:[device.entities valueForKeyPath:@"@distinctUnionOfArrays.sources"]];
		[deviceEndpoints unionSet:[NSSet setWithArray:[device.entities valueForKeyPath:@"@distinctUnionOfArrays.destinations"]]];
		if ([deviceEndpoints containsObject:endpoint]) return device;
	}
	return nil;
}

#pragma mark Pending Note Ons

- (NSMutableArray *)pendingNoteOnCommandsForDevice:(MIKMIDIDevice *)device
{
	NSMutableArray *result = [self.pendingNoteOnsByDevice objectForKey:device];
	if (!result) {
		result = [NSMutableArray array];
		[self.pendingNoteOnsByDevice setObject:result forKey:device];
	}
	return result;
}

- (void)recordPendingNoteOnCommands:(MIKArrayOf(MIKMIDICommand *) *)commands fromDevice:(MIKMIDIDevice *)device
{
	commands = [commands filteredArrayUsingPredicate:[NSPredicate predicateWithBlock:^BOOL(id obj, NSDictionary *b) {
		return [obj isKindOfClass:[MIKMIDINoteOnCommand class]];
	}]];
	if (![commands count]) return;
	
	NSMutableArray *pendingNoteOns = [self pendingNoteOnCommandsForDevice:device];
	[pendingNoteOns addObjectsFromArray:commands];
}

- (void)removePendingNoteOnCommandsTerminatedByNoteOffCommands:(MIKArrayOf(MIKMIDICommand *) *)commands fromDevice:(MIKMIDIDevice *)device
{
	commands = [commands filteredArrayUsingPredicate:[NSPredicate predicateWithBlock:^BOOL(id obj, NSDictionary *b) {
		if ([obj isKindOfClass:[MIKMIDINoteOnCommand class]] &&
			[(MIKMIDINoteOnCommand *)obj velocity] == 0) {
			return YES;
		}
		return [obj isKindOfClass:[MIKMIDINoteOffCommand class]];
	}]];
	if (![commands count]) return;
	
	NSMutableArray *pendingNoteOns = [self pendingNoteOnCommandsForDevice:device];
	if (![pendingNoteOns count]) return;
	
	for (MIKMIDINoteOffCommand *noteOff in commands) {
		for (MIKMIDINoteOnCommand *noteOn in [pendingNoteOns copy]) {
			if (MIKMIDINoteOffCommandCorrespondsWithNoteOnCommand(noteOff, noteOn)) {
				[pendingNoteOns removeObject:noteOn];
				continue;
			}
		}
	}
}

#pragma mark - Notifications

- (void)deviceWasPluggedIn:(NSNotification *)notification
{
	MIKMIDIDevice *device = [notification userInfo][MIKMIDIDeviceKey];
	[self connectToNewlyAddedDeviceIfAppropriate:device];
}

- (void)deviceWasUnplugged:(NSNotification *)notification
{
	MIKMIDIDevice *unpluggedDevice = [notification userInfo][MIKMIDIDeviceKey];
	[self internalDisconnectFromDevice:unpluggedDevice];
}

- (void)endpointWasPluggedIn:(NSNotification *)notification
{
	MIKMIDIEndpoint *pluggedInEndpoint = [notification userInfo][MIKMIDIEndpointKey];
	MIKMIDIDevice *pluggedInDevice = [self deviceContainingEndpoint:pluggedInEndpoint];
	[self connectToNewlyAddedDeviceIfAppropriate:pluggedInDevice];
}

- (void)endpointWasUnplugged:(NSNotification *)notification
{
	MIKMIDIEndpoint *unpluggedEndpoint = [notification userInfo][MIKMIDIEndpointKey];
	MIKMIDIDevice *unpluggedDevice = [self deviceContainingEndpoint:unpluggedEndpoint];
	if (unpluggedDevice) [self internalDisconnectFromDevice:unpluggedDevice];
}

- (void)saveConfigurationOnApplicationLifecycleEvent:(NSNotification *)notification
{
	if (self.automaticallySavesConfiguration) {
		[self saveConfiguration];
	}
}

#pragma mark - KVO

- (void)observeValueForKeyPath:(NSString *)keyPath ofObject:(id)object change:(NSDictionary<NSString *,id> *)change context:(void *)context
{
	if (context != MIKMIDIConnectionManagerKVOContext) {
		[super observeValueForKeyPath:keyPath ofObject:object change:change context:context];
		return;
	}
	
	if (object != self.deviceManager) return;
	
	if ([keyPath isEqualToString:@"availableDevices"]) {
		[self updateAvailableDevices];
	}
	
	if (self.includesVirtualDevices &&
		([keyPath isEqualToString:@"virtualSources"] || [keyPath isEqualToString:@"virtualDestinations"])) {
		[self updateAvailableDevices];
	}
}

#pragma mark - Properties

- (MIKMIDIDeviceManager *)deviceManager { return [MIKMIDIDeviceManager sharedDeviceManager]; }

- (MIKMIDIEventHandlerBlock)eventHandler
{
	return _eventHandler ?: ^(MIKMIDISourceEndpoint *s, NSArray *c){};
}

- (void)setIncludesVirtualDevices:(BOOL)includesVirtualDevices
{
	if (includesVirtualDevices != _includesVirtualDevices) {
		_includesVirtualDevices = includesVirtualDevices;
		[self updateAvailableDevices];
	}
}

- (void)setAvailableDevices:(NSArray *)availableDevices
{
	if (availableDevices != _availableDevices) {
		
		// Disconnect from newly unavailable devices.
		// This will include "partial" virtual devices that are now complete
		// by virtue of having been notified of other sources for them.
		for (MIKMIDIDevice *device in self.connectedDevices) {
			if (![availableDevices containsObject:device]) {
				[self internalDisconnectFromDevice:device];
			}
		}
		
		_availableDevices = availableDevices;
	}
}

+ (BOOL)automaticallyNotifiesObserversOfConnectedDevices { return NO; }
- (MIKSetOf(MIKMIDIDevice *) *)connectedDevices
{
	return [self.internalConnectedDevices copy];
}

@end

BOOL MIKMIDINoteOffCommandCorrespondsWithNoteOnCommand(MIKMIDINoteOffCommand *noteOff, MIKMIDINoteOnCommand *noteOn)
{
	if (noteOff.channel != noteOn.channel) return NO;
	if (noteOff.note != noteOn.note) return NO;
	if ([noteOff.timestamp compare:noteOn.timestamp] != NSOrderedAscending) return NO;
	
	return YES;
}
