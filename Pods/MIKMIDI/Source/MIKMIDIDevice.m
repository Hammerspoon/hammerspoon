//
//  MIKMIDIDevice.m
//  MIDI Testbed
//
//  Created by Andrew Madsen on 3/7/13.
//  Copyright (c) 2013 Mixed In Key. All rights reserved.
//

#import "MIKMIDIDevice.h"
#import "MIKMIDIObject_SubclassMethods.h"
#import "MIKMIDIEntity.h"
#import "MIKMIDISourceEndpoint.h"
#import "MIKMIDIDestinationEndpoint.h"
#import "MIKMIDIUtilities.h"

#if !__has_feature(objc_arc)
#error MIKMIDIDevice.m must be compiled with ARC. Either turn on ARC for the project or set the -fobjc-arc flag for MIKMIDIDevice.m in the Build Phases for this target
#endif

@interface MIKMIDIDevice ()

@property (nonatomic, strong, readwrite) NSString *manufacturer;
@property (nonatomic, strong, readwrite) NSString *model;

@property (nonatomic, strong) NSMutableArray *internalEntities;
- (void)addInternalEntitiesObject:(MIKMIDIEntity *)entity;
- (void)removeInternalEntitiesObject:(MIKMIDIEntity *)entity;

@end

@interface MIKMIDIEntity (Private)

@property (nonatomic, weak, readwrite) MIKMIDIDevice *device;

@end

@implementation MIKMIDIDevice

+ (void)load { [MIKMIDIObject registerSubclass:[self class]]; }

+ (NSArray *)representedMIDIObjectTypes; { return @[@(kMIDIObjectType_Device)]; }

+ (BOOL)canInitWithObjectRef:(MIDIObjectRef)objectRef
{
	if (!objectRef) return YES; // To allow creating 'virtual' devices
	return [super canInitWithObjectRef:objectRef];
}

- (id)initWithObjectRef:(MIDIObjectRef)objectRef
{
	self = [super initWithObjectRef:objectRef];
	if (self) {
		if (objectRef)  [self retrieveEntities];
	}
	return self;
}

+ (instancetype)deviceWithVirtualEndpoints:(NSArray *)endpoints;
{
	return [[self alloc] initWithVirtualEndpoints:endpoints];
}

- (instancetype)initWithVirtualEndpoints:(NSArray *)endpoints;
{
	self = [self initWithObjectRef:0];
	if (self) {
		self.isVirtual = YES;
		MIKMIDIEntity *entity = [MIKMIDIEntity entityWithVirtualEndpoints:endpoints];
		entity.device = self;
		self.internalEntities = [NSMutableArray arrayWithObject:entity];
	}
	return self;
}

- (BOOL)isEqual:(id)object
{
	if (![super isEqual:object]) return NO;
	return [self.entities isEqualToArray:[(MIKMIDIDevice *)object entities]];
}

- (NSUInteger)hash
{
	if (!self.isVirtual) {
		return [super hash];
	}
	return [self.entities hash];
}

#pragma mark - Public

- (NSString *)description
{
	NSMutableString *result = [NSMutableString stringWithFormat:@"%@:\r        Entities: {\r", [super description]];
	for (MIKMIDIEntity *entity in self.entities) {
		[result appendFormat:@"            %@,\r", entity];
	}
	[result appendString:@"        }"];
	return result;
}

#pragma mark - Private

- (void)retrieveEntities
{
	NSMutableArray *entities = [NSMutableArray array];
	
	ItemCount numEntities = MIDIDeviceGetNumberOfEntities(self.objectRef);
	for (ItemCount i=0; i<numEntities; i++) {
		MIDIEntityRef entityRef = MIDIDeviceGetEntity(self.objectRef, i);
		MIKMIDIEntity *entity = [MIKMIDIEntity MIDIObjectWithObjectRef:entityRef];
		if (!entity) continue;
		entity.device = self;
		[entities addObject:entity];
	}
	
	self.internalEntities = entities;
}

#pragma mark - Properties

+ (NSSet *)keyPathsForValuesAffectingValueForKey:(NSString *)key
{
	NSSet *keyPaths = [super keyPathsForValuesAffectingValueForKey:key];
	
	if ([key isEqualToString:@"entities"]) {
		keyPaths = [keyPaths setByAddingObject:@"internalEntities"];
	}
	
	return keyPaths;
}

- (MIDIObjectRef)objectRef
{
	if (self.isVirtual) {
		MIKMIDIEntity *entity = [self.entities firstObject];
		MIKMIDIEndpoint	*endpoint = [entity.sources count] ? [entity.sources firstObject] : [entity.destinations firstObject];
		return endpoint.objectRef;
	}
	return [super objectRef];
}

- (NSString *)manufacturer
{
	if (!_manufacturer) {
		NSError *error = nil;
		NSString *value = MIKStringPropertyFromMIDIObject(self.objectRef, kMIDIPropertyManufacturer, &error);
		if (!value) {
			NSLog(@"Unable to get MIDI device manufacturer: %@", error);
			return nil;
		}
		self.manufacturer = value;
	}
	return _manufacturer;
}

- (NSString *)model
{
	if (!_model) {
		NSError *error = nil;
		NSString *value = MIKStringPropertyFromMIDIObject(self.objectRef, kMIDIPropertyModel, &error);
		if (!value) {
			NSLog(@"Unable to get MIDI device model: %@", error);
			return nil;
		}
		self.model = value;
	}
	return _model;
}

- (NSString *)name
{
	NSString *result = [super name];
	if (result) return result;
	return self.model;
}

- (NSString *)displayName
{
	NSString *result = [super displayName];
	if (result) return result;
	return self.model;
}

- (NSArray *)entities { return [self.internalEntities copy]; }

- (void)addInternalEntitiesObject:(MIKMIDIEntity *)entity;
{
	[self.internalEntities addObject:entity];
}

- (void)removeInternalEntitiesObject:(MIKMIDIEntity *)entity;
{
	[self.internalEntities removeObject:entity];
}

@end
