//
//  MIKMIDIEntity.m
//  MIDI Testbed
//
//  Created by Andrew Madsen on 3/7/13.
//  Copyright (c) 2013 Mixed In Key. All rights reserved.
//

#import "MIKMIDIEntity.h"
#import "MIKMIDIObject_SubclassMethods.h"
#import "MIKMIDISourceEndpoint.h"
#import "MIKMIDIDestinationEndpoint.h"
#import "MIKMIDIUtilities.h"

#if !__has_feature(objc_arc)
#error MIKMIDIEntity.m must be compiled with ARC. Either turn on ARC for the project or set the -fobjc-arc flag for MIKMIDIEntity.m in the Build Phases for this target
#endif

@interface MIKMIDIEntity ()

@property (nonatomic, weak, readwrite) MIKMIDIDevice *device;

@property (nonatomic, strong) NSMutableArray *internalSources;
- (void)addInternalSourcesObject:(MIKMIDISourceEndpoint *)source;
- (void)removeInternalSourcesObject:(MIKMIDISourceEndpoint *)source;

@property (nonatomic, strong) NSMutableArray *internalDestinations;
- (void)addInternalDestinationsObject:(MIKMIDIDestinationEndpoint *)destination;
- (void)removeInternalDestinationsObject:(MIKMIDIDestinationEndpoint *)destination;

@end

@interface MIKMIDIEndpoint (Private)

@property (nonatomic, weak, readwrite) MIKMIDIEntity *entity;

@end

@implementation MIKMIDIEntity

+ (void)load { [MIKMIDIObject registerSubclass:[self class]]; }

+ (NSArray *)representedMIDIObjectTypes; { return @[@(kMIDIObjectType_Entity)]; }

+ (BOOL)canInitWithObjectRef:(MIDIObjectRef)objectRef
{
	if (!objectRef) return YES; // To allow creating 'virtual' entities
	return [super canInitWithObjectRef:objectRef];
}

- (id)initWithObjectRef:(MIDIObjectRef)objectRef
{
	self = [super initWithObjectRef:objectRef];
	if (self) {
		if (objectRef) [self retrieveEndpoints];
	}
	return self;
}

+ (instancetype)entityWithVirtualEndpoints:(NSArray *)endpoints;
{
	return [[self alloc] initWithVirtualEndpoints:endpoints];
}

- (instancetype)initWithVirtualEndpoints:(NSArray *)endpoints;
{
	self = [self initWithObjectRef:0];
	if (self) {
		self.isVirtual = YES;
		
		NSMutableArray *sources = [NSMutableArray array];
		NSMutableArray *destinations = [NSMutableArray array];
		for (MIKMIDIEndpoint *endpoint in endpoints) {
			if ([endpoint isKindOfClass:[MIKMIDISourceEndpoint class]]) {
				endpoint.entity = self;
				[sources addObject:endpoint];
			} else if ([endpoint isKindOfClass:[MIKMIDIDestinationEndpoint class]]) {
				endpoint.entity = self;
				[destinations addObject:endpoint];
			}
		}
		_internalSources = sources;
		_internalDestinations = destinations;
	}
	return self;
}

- (BOOL)isEqual:(id)object
{
	if (![super isEqual:object]) return NO;
	return [self.sources isEqualToArray:[(MIKMIDIEntity *)object sources]] &&
	[self.destinations isEqualToArray:[(MIKMIDIEntity *)object destinations]];
}

- (NSString *)description
{
	NSMutableString *result = [NSMutableString stringWithFormat:@"%@:\r        Sources: {\r", [super description]];
	for (MIKMIDISourceEndpoint *source in self.sources) {
		[result appendFormat:@"            %@,\r", source];
	}
	[result appendString:@"        }\r        Destinations: {\r"];
	for (MIKMIDIDestinationEndpoint *destination in self.destinations) {
		[result appendFormat:@"            %@,\r", destination];
	}
	[result appendString:@"        }"];
	return result;
}

#pragma mark - Private

- (void)retrieveEndpoints
{
	NSMutableArray *sources = [NSMutableArray array];
	ItemCount numSources = MIDIEntityGetNumberOfSources(self.objectRef);
	for (ItemCount i=0; i<numSources; i++) {
		MIDIEndpointRef sourceRef = MIDIEntityGetSource(self.objectRef, i);
		MIKMIDISourceEndpoint *source = [MIKMIDISourceEndpoint MIDIObjectWithObjectRef:sourceRef];
		if (!source) continue;
		source.entity = self;
		[sources addObject:source];
	}
	self.internalSources = sources;
	
	NSMutableArray *destinations = [NSMutableArray array];
	ItemCount numDestinations = MIDIEntityGetNumberOfDestinations(self.objectRef);
	for (ItemCount i=0; i<numDestinations; i++) {
		MIDIEndpointRef destinationRef = MIDIEntityGetDestination(self.objectRef, i);
		MIKMIDISourceEndpoint *destination = [MIKMIDISourceEndpoint MIDIObjectWithObjectRef:destinationRef];
		if (!destination) continue;
		destination.entity = self;
		[destinations addObject:destination];
	}
	self.internalDestinations = destinations;
}

#pragma mark - Properties

+ (NSSet *)keyPathsForValuesAffectingValueForKey:(NSString *)key
{
	NSSet *keyPaths = [super keyPathsForValuesAffectingValueForKey:key];
	
	if ([key isEqualToString:@"sources"]) {
		keyPaths = [keyPaths setByAddingObject:@"internalSources"];
	}
	
	if ([key isEqualToString:@"destinations"]) {
		keyPaths = [keyPaths setByAddingObject:@"internalDestinations"];
	}
	
	return keyPaths;
}

- (MIDIObjectRef)objectRef
{
	if (self.isVirtual) {
		MIKMIDIObject *endpoint = [self.sources count] ? [self.sources firstObject] : [self.destinations firstObject];
		return endpoint.objectRef;
	}
	return [super objectRef];
}

- (NSArray *)sources { return [self.internalSources copy]; }

- (void)addInternalSourcesObject:(MIKMIDISourceEndpoint *)source
{
	[self.internalSources addObject:source];
}

- (void)removeInternalSourcesObject:(MIKMIDISourceEndpoint *)source
{
	[self.internalSources removeObject:source];
}

- (NSArray *)destinations { return [self.internalDestinations copy]; }

- (void)addInternalDestinationsObject:(MIKMIDIDestinationEndpoint *)destination
{
	[self.internalDestinations addObject:destination];
}

- (void)removeInternalDestinationsObject:(MIKMIDIDestinationEndpoint *)destination
{
	[self.internalDestinations removeObject:destination];
}

@end
