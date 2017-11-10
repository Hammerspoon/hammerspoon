//
//  MIKMIDIDeviceManager.m
//  MIDI Testbed
//
//  Created by Andrew Madsen on 3/7/13.
//  Copyright (c) 2013 Mixed In Key. All rights reserved.
//

#import "MIKMIDIDeviceManager.h"
#import <CoreMIDI/CoreMIDI.h>
#import "MIKMIDIDevice.h"
#import "MIKMIDISourceEndpoint.h"
#import "MIKMIDIDestinationEndpoint.h"
#import "MIKMIDIInputPort.h"
#import "MIKMIDIOutputPort.h"
#import "MIKMIDIClientSourceEndpoint.h"
#import "MIKMIDIErrors.h"

#if TARGET_OS_IPHONE
#import <UIKit/UIApplication.h>
#endif

#if !__has_feature(objc_arc)
#error MIKMIDIDeviceManager.m must be compiled with ARC. Either turn on ARC for the project or set the -fobjc-arc flag for MIKMIDIDeviceManager.m in the Build Phases for this target
#endif

// Notifications
NSString * const MIKMIDIDeviceWasAddedNotification = @"MIKMIDIDeviceWasAddedNotification";
NSString * const MIKMIDIDeviceWasRemovedNotification = @"MIKMIDIDeviceWasRemovedNotification";
NSString * const MIKMIDIVirtualEndpointWasAddedNotification = @"MIKMIDIVirtualEndpointWasAddedNotification";
NSString * const MIKMIDIVirtualEndpointWasRemovedNotification = @"MIKMIDIVirtualEndpointWasRemovedNotification";


// Notification Keys
NSString * const MIKMIDIDeviceKey = @"MIKMIDIDeviceKey";
NSString * const MIKMIDIEndpointKey = @"MIKMIDIEndpointKey";

static MIKMIDIDeviceManager *sharedDeviceManager;

@interface MIKMIDIDeviceManager ()

@property (nonatomic) MIDIClientRef client;
@property (nonatomic, strong) NSMutableArray *internalDevices;
- (void)addInternalDevicesObject:(MIKMIDIDevice *)device;
- (void)removeInternalDevicesObject:(MIKMIDIDevice *)device;

@property (nonatomic, strong) NSMutableArray *internalVirtualSources;
- (void)addInternalVirtualSourcesObject:(MIKMIDISourceEndpoint *)source;
- (void)removeInternalVirtualSourcesObject:(MIKMIDISourceEndpoint *)source;

@property (nonatomic, strong) NSMutableArray *internalVirtualDestinations;
- (void)addInternalVirtualDestinationsObject:(MIKMIDIDestinationEndpoint *)destination;
- (void)removeInternalVirtualDestinationsObject:(MIKMIDIDestinationEndpoint *)destination;

@property (nonatomic, strong) MIKMIDIInputPort *inputPort;
@property (nonatomic, strong) MIKMIDIOutputPort *outputPort;

@end

@implementation MIKMIDIDeviceManager

+ (instancetype)sharedDeviceManager;
{
	static dispatch_once_t onceToken;
	dispatch_once(&onceToken, ^{
		sharedDeviceManager = [(MIKMIDIDeviceManager *)[super allocWithZone:NULL] init];
	});
	return sharedDeviceManager;
}

- (id)init
{
	if (self == sharedDeviceManager) return sharedDeviceManager;
	
    self = [super init];
    if (self) {
		[self createClient];
        [self retrieveAvailableDevices];
		[self retrieveVirtualEndpoints];
        
#if TARGET_OS_IPHONE
        NSNotificationCenter *nc = [NSNotificationCenter defaultCenter];
        [nc addObserver:self selector:@selector(appDidBecomeActiveNotification:) name:UIApplicationDidBecomeActiveNotification object:nil];
#endif
        
    }
    return self;
}

+ (id)allocWithZone:(NSZone *)zone
{
	return [self sharedDeviceManager];
}

- (id)copyWithZone:(NSZone *)zone
{
	return self;
}

- (void)dealloc
{
    [[NSNotificationCenter defaultCenter] removeObserver:self];
}

#pragma mark - Public

- (nullable id)connectDevice:(MIKMIDIDevice *)device error:(NSError **)error eventHandler:(MIKMIDIEventHandlerBlock)eventHandler
{
	error = error ?: &(NSError *__autoreleasing){ nil };
	NSMutableArray *sources = [device.entities valueForKeyPath:@"@unionOfArrays.sources"];
	if (![sources count]) {
		*error = [NSError MIKMIDIErrorWithCode:MIKMIDIDeviceHasNoSourcesErrorCode userInfo:nil];
		return nil;
	}
	
	NSMutableArray *tokens = [NSMutableArray array];
	for (MIKMIDISourceEndpoint *source in sources) {
		id token = [self.inputPort connectToSource:source error:error eventHandler:eventHandler];
		if (!token) {
			for (id token in tokens) { [self disconnectConnectionForToken:token]; }
			return nil;
		}
		[tokens addObject:token];
	}
	
	return tokens;
}

- (id)connectInput:(MIKMIDISourceEndpoint *)endpoint error:(NSError **)error eventHandler:(MIKMIDIEventHandlerBlock)eventHandler
{
	id result = [self.inputPort connectToSource:endpoint error:error eventHandler:eventHandler];
	if (!result) return nil;
	return @[result];
}

- (void)disconnectConnectionForToken:(id)connectionToken
{
	for (id token in (NSArray *)connectionToken) {
		[self.inputPort disconnectConnectionForToken:token];
	}
}

- (BOOL)sendCommands:(NSArray *)commands toEndpoint:(MIKMIDIDestinationEndpoint *)endpoint error:(NSError **)error;
{
	return [self.outputPort sendCommands:commands toDestination:endpoint error:error];
}

- (BOOL)sendCommands:(NSArray *)commands toVirtualEndpoint:(MIKMIDIClientSourceEndpoint *)endpoint error:(NSError **)error
{
    return [endpoint sendCommands:commands error:error];
}


#pragma mark - Private

- (void)createClient
{
	MIDIClientRef client;
	OSStatus error = MIDIClientCreate(CFSTR("MIKMIDIDeviceManager"), MIKMIDIDeviceManagerNotifyCallback, (__bridge void *)self, &client);
	if (error != noErr) { NSLog(@"Unable to create MIDI client"); return; }
	self.client = client;
}

- (void)retrieveAvailableDevices
{
	ItemCount numDevices = MIDIGetNumberOfDevices();
	NSMutableArray *devices = [NSMutableArray arrayWithCapacity:numDevices];
	
	for (ItemCount i=0; i<numDevices; i++) {
		MIDIDeviceRef deviceRef = MIDIGetDevice(i);
		MIKMIDIDevice *device = [MIKMIDIDevice MIDIObjectWithObjectRef:deviceRef];
		if (!device || !device.isOnline) continue;
		[devices addObject:device];
	}
	
	self.internalDevices = devices;
}

- (void)retrieveVirtualEndpoints
{
	NSMutableArray *sources = [NSMutableArray array];
	ItemCount numSources = MIDIGetNumberOfSources();
	for (ItemCount i=0; i<numSources; i++) {
		MIDIEndpointRef sourceRef = MIDIGetSource(i);
		MIKMIDIEndpoint *source = [MIKMIDIEndpoint MIDIObjectWithObjectRef:sourceRef];
		if (!source) continue;
		[sources addObject:source];
	}
	self.internalVirtualSources = sources;
	
	NSMutableArray *destinations = [NSMutableArray array];
	ItemCount numDestinations = MIDIGetNumberOfDestinations();
	for (ItemCount i=0; i<numDestinations; i++) {
		MIDIEndpointRef destinationRef = MIDIGetDestination(i);
		MIKMIDIEndpoint *destination = [MIKMIDIEndpoint MIDIObjectWithObjectRef:destinationRef];
		if (!destination) continue;
		[destinations addObject:destination];
	}
	self.internalVirtualDestinations = destinations;
}

#pragma mark - Notifications

- (void)appDidBecomeActiveNotification:(NSNotification *)notification
{
    [self retrieveAvailableDevices];
}

#pragma mark - Callbacks

- (void)handleMIDIObjectPropertyChangeNotification:(MIDIObjectPropertyChangeNotification *)notification
{
	NSNotificationCenter *nc = [NSNotificationCenter defaultCenter];
	
	NSString *changedProperty = (__bridge NSString *)notification->propertyName;
	
	switch (notification->objectType) {
		case kMIDIObjectType_Device: {
			
			if (![changedProperty isEqualToString:(__bridge NSString *)kMIDIPropertyOffline]) break;
			
			MIKMIDIDevice *changedObject = [MIKMIDIDevice MIDIObjectWithObjectRef:notification->object];
			if (!changedObject) break;
			
			if (changedObject.isOnline && ![self.internalDevices containsObject:changedObject]) {
				[self addInternalDevicesObject:changedObject];
				[nc postNotificationName:MIKMIDIDeviceWasAddedNotification object:self userInfo:@{MIKMIDIDeviceKey : changedObject}];
			}
			if (!changedObject.isOnline) {
				[self removeInternalDevicesObject:changedObject];
				[nc postNotificationName:MIKMIDIDeviceWasRemovedNotification object:self userInfo:@{MIKMIDIDeviceKey : changedObject}];
			}
		}
			break;
		case kMIDIObjectType_Source: {
			
			if (![changedProperty isEqualToString:(__bridge NSString *)kMIDIPropertyPrivate]) break;
			
			MIKMIDISourceEndpoint *changedObject = [MIKMIDISourceEndpoint MIDIObjectWithObjectRef:notification->object];
			if (!changedObject) break;
			
			if (!changedObject.isPrivate && ![self.internalVirtualSources containsObject:changedObject]) {
				[self addInternalVirtualSourcesObject:changedObject];
				[nc postNotificationName:MIKMIDIVirtualEndpointWasAddedNotification object:self userInfo:@{MIKMIDIEndpointKey : changedObject}];
			}
			if (changedObject.isPrivate) {
				[self removeInternalVirtualSourcesObject:changedObject];
				[nc postNotificationName:MIKMIDIVirtualEndpointWasRemovedNotification object:self userInfo:@{MIKMIDIEndpointKey : changedObject}];
			}
		}
			break;
		case kMIDIObjectType_Destination: {
			
			if (![changedProperty isEqualToString:(__bridge NSString *)kMIDIPropertyPrivate]) break;
			
			MIKMIDIDestinationEndpoint *changedObject = [MIKMIDIDestinationEndpoint MIDIObjectWithObjectRef:notification->object];
			if (!changedObject) break;
			
			if (!changedObject.isPrivate && ![self.internalVirtualDestinations containsObject:changedObject]) {
				[self addInternalVirtualDestinationsObject:changedObject];
				[nc postNotificationName:MIKMIDIVirtualEndpointWasAddedNotification object:self userInfo:@{MIKMIDIEndpointKey : changedObject}];
			}
			if (changedObject.isPrivate) {
				[self removeInternalVirtualDestinationsObject:changedObject];
				[nc postNotificationName:MIKMIDIVirtualEndpointWasRemovedNotification object:self userInfo:@{MIKMIDIEndpointKey : changedObject}];
			}
		}
			break;
		default:
			break;
	}
}

- (void)handleMIDIObjectRemoveNotification:(MIDIObjectAddRemoveNotification *)notification
{
	NSNotificationCenter *nc = [NSNotificationCenter defaultCenter];
	
	switch (notification->childType) {
		case kMIDIObjectType_Device: {
			MIKMIDIDevice *removedDevice = [MIKMIDIDevice MIDIObjectWithObjectRef:notification->child];
			if (!removedDevice) break;
			[self removeInternalDevicesObject:removedDevice];
		}
			break;
		case kMIDIObjectType_Source: {
			MIKMIDISourceEndpoint *removedSource = [MIKMIDISourceEndpoint MIDIObjectWithObjectRef:notification->child];
			if (!removedSource) {
				// Sometimes that fails even though the MIDIObjectRef is for an object we already have an instance for
				// FIXME: It might be better to have MIKMIDIObject maintain a table of instances and return an existing
				// instance if a known object ref is passed into MIDIObjectWithObjectRef:
				for (MIKMIDISourceEndpoint *source in self.virtualSources) {
					if (source.objectRef == notification->child) {
						removedSource = source;
						break;
					}
				}
			}
			if (!removedSource) break;
			[self removeInternalVirtualSourcesObject:removedSource];
			[nc postNotificationName:MIKMIDIVirtualEndpointWasRemovedNotification object:self userInfo:@{MIKMIDIEndpointKey : removedSource}];
		}
			break;
		case kMIDIObjectType_Destination: {
			MIKMIDIDestinationEndpoint *removedDestination = [MIKMIDIDestinationEndpoint MIDIObjectWithObjectRef:notification->child];
			if (!removedDestination) {
				// Sometimes that fails even though the MIDIObjectRef is for an object we already have an instance for
				for (MIKMIDIDestinationEndpoint *destination in self.virtualDestinations) {
					if (destination.objectRef == notification->child) {
						removedDestination = destination;
						break;
					}
				}
			}
			if (!removedDestination) break;
			[self removeInternalVirtualDestinationsObject:removedDestination];
			[nc postNotificationName:MIKMIDIVirtualEndpointWasRemovedNotification object:self userInfo:@{MIKMIDIEndpointKey : removedDestination}];
		}
			break;
		default:
			break;
	}
}

- (void)handleMIDIObjectAddNotification:(MIDIObjectAddRemoveNotification *)notification
{
	NSNotificationCenter *nc = [NSNotificationCenter defaultCenter];
	
	switch (notification->childType) {
		case kMIDIObjectType_Device: {
			MIKMIDIDevice *addedDevice = [MIKMIDIDevice MIDIObjectWithObjectRef:notification->child];
			if (addedDevice && ![self.internalDevices containsObject:addedDevice]) {
				[self addInternalDevicesObject:addedDevice];
				[nc postNotificationName:MIKMIDIDeviceWasAddedNotification object:self userInfo:@{MIKMIDIDeviceKey : addedDevice}];
			}
		}
			break;
		case kMIDIObjectType_Source: {
			MIKMIDISourceEndpoint *addedSource = [MIKMIDISourceEndpoint MIDIObjectWithObjectRef:notification->child];
			if (addedSource && ![self.internalVirtualSources containsObject:addedSource]) {
				[self addInternalVirtualSourcesObject:addedSource];
				[nc postNotificationName:MIKMIDIVirtualEndpointWasAddedNotification object:self userInfo:@{MIKMIDIEndpointKey : addedSource}];
			}
		}
			break;
		case kMIDIObjectType_Destination: {
			MIKMIDIDestinationEndpoint *addedDestination = [MIKMIDIDestinationEndpoint MIDIObjectWithObjectRef:notification->child];
			if (addedDestination && ![self.internalVirtualDestinations containsObject:addedDestination]) {
				[self addInternalVirtualDestinationsObject:addedDestination];
				[nc postNotificationName:MIKMIDIVirtualEndpointWasAddedNotification object:self userInfo:@{MIKMIDIEndpointKey : addedDestination}];
			}
		}
			break;
		default:
			break;
	}
}

void MIKMIDIDeviceManagerNotifyCallback(const MIDINotification *message, void *refCon)
{
	MIKMIDIDeviceManager *self = (__bridge MIKMIDIDeviceManager *)refCon;
	
	switch (message->messageID) {
		case kMIDIMsgPropertyChanged:
			[self handleMIDIObjectPropertyChangeNotification:(MIDIObjectPropertyChangeNotification *)message];
			break;
		case kMIDIMsgObjectRemoved:
			[self handleMIDIObjectRemoveNotification:(MIDIObjectAddRemoveNotification *)message];
			break;
		case kMIDIMsgObjectAdded:
			[self handleMIDIObjectAddNotification:(MIDIObjectAddRemoveNotification *)message];
			break;
		default:
			break;
	}
}

#pragma mark - Properties

+ (BOOL)automaticallyNotifiesObserversOfAvailableDevices { return NO; }

- (NSArray *)availableDevices { return [self.internalDevices copy]; }

- (void)addInternalDevicesObject:(MIKMIDIDevice *)device;
{
	NSUInteger index = self.internalDevices.count;
	[self willChange:NSKeyValueChangeInsertion valuesAtIndexes:[NSIndexSet indexSetWithIndex:index] forKey:@"availableDevices"];
	[self.internalDevices insertObject:device atIndex:index];
	[self didChange:NSKeyValueChangeInsertion valuesAtIndexes:[NSIndexSet indexSetWithIndex:index] forKey:@"availableDevices"];
}

- (void)removeInternalDevicesObject:(MIKMIDIDevice *)device;
{
	NSUInteger index = [self.internalDevices indexOfObject:device];
	if (index == NSNotFound) return;
	[self willChange:NSKeyValueChangeRemoval valuesAtIndexes:[NSIndexSet indexSetWithIndex:index] forKey:@"availableDevices"];
	[self.internalDevices removeObjectAtIndex:index];
	[self didChange:NSKeyValueChangeRemoval valuesAtIndexes:[NSIndexSet indexSetWithIndex:index] forKey:@"availableDevices"];
}

+ (BOOL)automaticallyNotifiesObserversOfInternalVirtualSources { return NO; }

- (NSArray *)virtualSources { return [self.internalVirtualSources copy]; }

- (void)addInternalVirtualSourcesObject:(MIKMIDISourceEndpoint *)source
{
    NSUInteger index = [self.internalVirtualSources count];
    [self willChange:NSKeyValueChangeInsertion valuesAtIndexes:[NSIndexSet indexSetWithIndex:index] forKey:@"virtualSources"];
    [self.internalVirtualSources insertObject:source atIndex:index];
    [self didChange:NSKeyValueChangeInsertion valuesAtIndexes:[NSIndexSet indexSetWithIndex:index] forKey:@"virtualSources"];
}

- (void)removeInternalVirtualSourcesObject:(MIKMIDISourceEndpoint *)source
{
	NSUInteger index = [self.internalVirtualSources indexOfObject:source];
	if (index == NSNotFound) return;
	[self willChange:NSKeyValueChangeRemoval valuesAtIndexes:[NSIndexSet indexSetWithIndex:index] forKey:@"virtualSources"];
	[self.internalVirtualSources removeObjectAtIndex:index];
	[self didChange:NSKeyValueChangeRemoval valuesAtIndexes:[NSIndexSet indexSetWithIndex:index] forKey:@"virtualSources"];
}

+ (BOOL)automaticallyNotifiesObserversOfVirtualSources { return NO; }

- (NSArray *)virtualDestinations { return [self.internalVirtualDestinations copy]; }

- (void)addInternalVirtualDestinationsObject:(MIKMIDIDestinationEndpoint *)destination
{
    NSUInteger index = [self.internalVirtualDestinations count];
    [self willChange:NSKeyValueChangeInsertion valuesAtIndexes:[NSIndexSet indexSetWithIndex:index] forKey:@"virtualDestinations"];
    [self.internalVirtualDestinations insertObject:destination atIndex:index];
    [self didChange:NSKeyValueChangeInsertion valuesAtIndexes:[NSIndexSet indexSetWithIndex:index] forKey:@"virtualDestinations"];
}

- (void)removeInternalVirtualDestinationsObject:(MIKMIDIDestinationEndpoint *)destination
{
	NSUInteger index = [self.internalVirtualDestinations indexOfObject:destination];
	if (index == NSNotFound) return;
	[self willChange:NSKeyValueChangeRemoval valuesAtIndexes:[NSIndexSet indexSetWithIndex:index] forKey:@"virtualDestinations"];
	[self.internalVirtualDestinations removeObjectAtIndex:index];
	[self didChange:NSKeyValueChangeRemoval valuesAtIndexes:[NSIndexSet indexSetWithIndex:index] forKey:@"virtualDestinations"];
}

+ (NSSet *)keyPathsForValuesAffectingConnectedInputSources
{
	return [NSSet setWithObjects:@"inputPort.connectedSources", nil];
}

- (NSArray *)connectedInputSources
{
	NSArray *result = self.inputPort.connectedSources;
	if (!result) result = @[];
	return result;
}

+ (NSSet *)keyPathsForValuesAffectingConnectedDevices
{
	return [NSSet setWithObjects:@"connectedInputSources", @"availableDevices", nil];
}

- (NSArray<MIKMIDIDevice *> *)connectedDevices
{
	NSSet *connectedSources = [NSSet setWithArray:self.connectedInputSources];
	NSMutableArray *result = [NSMutableArray array];
	for (MIKMIDIDevice *device in self.availableDevices) {
		NSMutableArray *sources = [device.entities valueForKeyPath:@"@unionOfArrays.sources"];
		for (MIKMIDISourceEndpoint *source in sources) {
			if ([connectedSources containsObject:source]) {
				[result addObject:device];
				break;
			}
		}
	}
	return result;
}

- (MIKMIDIInputPort *)inputPort
{
	if (!_inputPort) {
		_inputPort = [[MIKMIDIInputPort alloc] initWithClient:self.client name:@"InputPort"];
	}
	return _inputPort;
}

- (MIKMIDIOutputPort *)outputPort
{
	if (!_outputPort) {
		_outputPort = [[MIKMIDIOutputPort alloc] initWithClient:self.client name:@"OutputPort"];
	}
	return _outputPort;
}

@end

#pragma mark -

@implementation MIKMIDIDeviceManager (Deprecated)

- (void)disconnectInput:(MIKMIDISourceEndpoint *)endpoint forConnectionToken:(id)connectionToken
{
	[self disconnectConnectionForToken:connectionToken];
}

@end
