//
//  MIKMIDIMapping.m
//  Energetic
//
//  Created by Andrew Madsen on 3/15/13.
//  Copyright (c) 2013 Mixed In Key. All rights reserved.
//

#import "MIKMIDIMapping.h"
#import "MIKMIDIMappingItem.h"
#import "MIKMIDICommand.h"
#import "MIKMIDIChannelVoiceCommand.h"
#import "MIKMIDIControlChangeCommand.h"
#import "MIKMIDINoteOnCommand.h"
#import "MIKMIDINoteOffCommand.h"
#import "MIKMIDIPrivateUtilities.h"
#import "MIKMIDIUtilities.h"
#import "MIKMIDIMappingXMLParser.h"

#if TARGET_OS_IPHONE
#import <libxml/xmlwriter.h>
#endif

#if !__has_feature(objc_arc)
#error MIKMIDIMapping.m must be compiled with ARC. Either turn on ARC for the project or set the -fobjc-arc flag for MIKMIDIMapping.m in the Build Phases for this target
#endif

@interface MIKMIDIMappingItem ()

#if !TARGET_OS_IPHONE
- (instancetype)initWithXMLElement:(NSXMLElement *)element;
- (NSXMLElement *)XMLRepresentation;
#endif

@property (nonatomic, weak, readwrite) MIKMIDIMapping *mapping;

@end

@interface MIKMIDIMapping ()

@property (nonatomic, readwrite, getter = isBundledMapping) BOOL bundledMapping;
@property (nonatomic, strong) NSMutableSet *internalMappingItems;

@end

@implementation MIKMIDIMapping

- (instancetype)initWithFileAtURL:(NSURL *)url error:(NSError **)error;
{
	error = error ? error : &(NSError *__autoreleasing){ nil };
#if TARGET_OS_IPHONE
	// iOS
	NSData *data = [NSData dataWithContentsOfURL:url options:0 error:error];
	if (!data) return nil;
	MIKMIDIMappingXMLParser *parser = [MIKMIDIMappingXMLParser parserWithXMLData:data];
	self = [parser.mappings firstObject];
	return self;
#else
	// OS X
	NSXMLDocument *xmlDocument = [[NSXMLDocument alloc] initWithContentsOfURL:url options:0 error:error];
	if (!xmlDocument) {
		NSLog(@"Unable to read MIDI map XML file at %@: %@", url, *error);
		self = nil;
		return nil;
	}
	self = [self initWithXMLDocument:xmlDocument];
	if (self) {
		if (![_name length]) _name = [[url lastPathComponent] stringByDeletingPathExtension];
	}
	return self;
#endif // TARGET_OS_IPHONE
}

#if !TARGET_OS_IPHONE
- (instancetype)initWithXMLDocument:(NSXMLDocument *)xmlDocument
{
	self = [self init];
	if (self) {
		if (![self loadPropertiesFromXMLDocument:xmlDocument]) {
			self = nil;
			return nil;
		}
	}
	return self;
}
#endif

- (id)init
{
    self = [super init];
    if (self) {
        _internalMappingItems = [NSMutableSet set];
    }
    return self;
}

- (id)copyWithZone:(NSZone *)zone
{
	MIKMIDIMapping *result = [[[self class] alloc] init];
	result.name = self.name;
	result.controllerName = self.controllerName;
	result.bundledMapping = self.bundledMapping;
	result.additionalAttributes = self.additionalAttributes;
	
	for (MIKMIDIMappingItem *item in self.mappingItems) {
		[result addMappingItemsObject:[item copy]];
	}
	
	return result;
}

+ (instancetype)userMappingFromBundledMapping:(MIKMIDIMapping *)bundledMapping
{
	MIKMIDIMapping *userMapping = [bundledMapping copy];
	userMapping.bundledMapping = NO;
	return userMapping;
}

#if !TARGET_OS_IPHONE

- (NSXMLDocument *)XMLRepresentation
{
	return [self privateXMLRepresentation];
}

- (NSXMLDocument *)privateXMLRepresentation
{
	NSXMLElement *controllerName = [[NSXMLElement alloc] initWithKind:NSXMLAttributeKind];
	[controllerName setName:@"ControllerName"];
	[controllerName setStringValue:self.controllerName];
	NSXMLElement *mappingName = [[NSXMLElement alloc] initWithKind:NSXMLAttributeKind];
	[mappingName setName:@"MappingName"];
	[mappingName setStringValue:self.name];
	
	NSMutableArray *attributes = [NSMutableArray arrayWithArray:@[mappingName, controllerName]];
	for (NSString *key in self.additionalAttributes) {
		NSXMLElement *attributeElement = [[NSXMLElement alloc] initWithKind:NSXMLAttributeKind];
		NSString *stringValue = self.additionalAttributes[key];
		if (![stringValue isKindOfClass:[NSString class]]) {
			NSLog(@"Ignoring additional attribute %@ : %@ because it is not a string.", key, stringValue);
			continue;
		}
		[attributeElement setName:key];
		[attributeElement setStringValue:stringValue];
		[attributes addObject:attributeElement];
	}
	
	NSSortDescriptor *sortByResponderID = [NSSortDescriptor sortDescriptorWithKey:@"MIDIResponderIdentifier" ascending:YES];
	NSSortDescriptor *sortByCommandID = [NSSortDescriptor sortDescriptorWithKey:@"commandIdentifier" ascending:YES];
	NSArray *sortedMappingItems = [self.mappingItems sortedArrayUsingDescriptors:@[sortByResponderID, sortByCommandID]];
	NSArray *mappingItemXMLElements = [sortedMappingItems valueForKey:@"XMLRepresentation"];
	NSXMLElement *mappingItems = [NSXMLElement elementWithName:@"MappingItems" children:mappingItemXMLElements attributes:nil];
	
	NSXMLElement *rootElement = [NSXMLElement elementWithName:@"Mapping"
													 children:@[mappingItems]
												   attributes:attributes];
	
	NSXMLDocument *result = [[NSXMLDocument alloc] initWithRootElement:rootElement];
	[result setVersion:@"1.0"];
	[result setCharacterEncoding:@"UTF-8"];
	return result;
}

#endif

- (NSString *)XMLStringRepresentation;
{
#if !TARGET_OS_IPHONE
	return [[self privateXMLRepresentation] XMLStringWithOptions:NSXMLNodePrettyPrint];
#else
	
	int err = 0;
	xmlTextWriterPtr writer = NULL;
	xmlBufferPtr buffer = xmlBufferCreate();
	if (!buffer) {
		NSLog(@"Unable to create XML buffer.");
		goto CLEANUP_AND_EXIT;
	}
	
	writer = xmlNewTextWriterMemory(buffer, 0);
	if (!writer) {
		xmlBufferFree(buffer);
		NSLog(@"Unable to create XML writer.");
		goto CLEANUP_AND_EXIT;
	}
	
	// Start the document
	err = xmlTextWriterStartDocument(writer, NULL, "UTF-8", NULL);
	if (err < 0) {
		NSLog(@"Unable to start XML document: %i", err);
		goto CLEANUP_AND_EXIT;
	}
	
	err = xmlTextWriterStartElement(writer, BAD_CAST "Mapping"); // <Mapping>
	if (err < 0) {
		NSLog(@"Unable to start XML Mapping element: %i", err);
		goto CLEANUP_AND_EXIT;
	}
	
	xmlTextWriterSetIndent(writer, 1);
	
	err = xmlTextWriterWriteAttribute(writer, BAD_CAST "ControllerName", BAD_CAST [self.controllerName UTF8String]);
	if (err < 0) {
		NSLog(@"Unable to write ControllerName attribute for Mapping element: %i", err);
		goto CLEANUP_AND_EXIT;
	}
	
	err = xmlTextWriterWriteAttribute(writer, BAD_CAST "MappingName", BAD_CAST [self.name UTF8String]);
	if (err < 0) {
		NSLog(@"Unable to write MappingName attribute for Mapping element: %i", err);
		goto CLEANUP_AND_EXIT;
	}
	
	for (NSString *key in self.additionalAttributes) {
		NSString *stringValue = self.additionalAttributes[key];
		if (![stringValue isKindOfClass:[NSString class]]) {
			NSLog(@"Ignoring additional attribute %@ : %@ because it is not a string.", key, stringValue);
			continue;
		}
		
		err = xmlTextWriterWriteAttribute(writer, BAD_CAST [key UTF8String], BAD_CAST [stringValue UTF8String]);
		if (err < 0) {
			NSLog(@"Unable to write MappingName attribute for Mapping element: %i", err);
			goto CLEANUP_AND_EXIT;
		}
	}
	
	err = xmlTextWriterStartElement(writer, BAD_CAST "MappingItems"); // <MappingItems>
	if (err < 0) {
		NSLog(@"Unable to start XML Mapping Items element: %i", err);
		goto CLEANUP_AND_EXIT;
	}
	
	{
		// Write mapping items
		NSSortDescriptor *sortByResponderID = [NSSortDescriptor sortDescriptorWithKey:@"MIDIResponderIdentifier" ascending:YES];
		NSSortDescriptor *sortByCommandID = [NSSortDescriptor sortDescriptorWithKey:@"commandIdentifier" ascending:YES];
		NSArray *sortedMappingItems = [self.mappingItems sortedArrayUsingDescriptors:@[sortByResponderID, sortByCommandID]];
		
		for (MIKMIDIMappingItem *item in sortedMappingItems) {
			NSString *xmlString = [item XMLStringRepresentation];
			err = xmlTextWriterWriteRaw(writer, BAD_CAST [xmlString UTF8String]);
			if (err < 0) {
				NSLog(@"Unable to write XML for mapping item %@: %i", item, err);
				goto CLEANUP_AND_EXIT;
			}
		}
		
		err = xmlTextWriterEndElement(writer); // </MappingItems>
		if (err < 0) {
			NSLog(@"Unable to end XML Mapping Items element: %i", err);
			goto CLEANUP_AND_EXIT;
		}
		
		err = xmlTextWriterEndElement(writer); // </Mapping>
		if (err < 0) {
			NSLog(@"Unable to end XML Mapping element: %i", err);
			goto CLEANUP_AND_EXIT;
		}
		
		err = xmlTextWriterEndDocument(writer);
		if (err < 0) {
			NSLog(@"Unable to end XML Mapping document: %i", err);
			goto CLEANUP_AND_EXIT;
		}
	}
	
CLEANUP_AND_EXIT:
	if (writer) xmlFreeTextWriter(writer);
	NSString *result = nil;
	if (buffer && err >= 0) {
		result = [[NSString alloc] initWithCString:(const char *)buffer->content encoding:NSUTF8StringEncoding];
		xmlBufferFree(buffer);
	}
	
	return result;
#endif
}

- (BOOL)writeToFileAtURL:(NSURL *)fileURL error:(NSError **)error;
{
	error = error ? error : &(NSError *__autoreleasing){ nil };
	NSData *xmlData = [[self XMLStringRepresentation] dataUsingEncoding:NSUTF8StringEncoding];
	if (![xmlData writeToURL:fileURL options:NSDataWritingAtomic error:error]) {
		NSLog(@"Error saving MIDI mapping %@ to %@: %@", self.name, fileURL, *error);
		return NO;
	}
	return YES;
}

- (BOOL)isEqual:(MIKMIDIMapping *)otherMapping
{
	if (self == otherMapping) return YES;
	if (![self.name isEqualToString:otherMapping.name]) return NO;
	if (![self.controllerName isEqualToString:otherMapping.controllerName]) return NO;
	if (![self.additionalAttributes isEqualToDictionary:otherMapping.additionalAttributes]) return NO;
	if (self.isBundledMapping != otherMapping.isBundledMapping) return NO;
	
	return [self.mappingItems isEqualToSet:otherMapping.mappingItems];
}

- (NSUInteger)hash
{
	NSUInteger result = [self.name hash];
	result += [self.controllerName hash];
	result += [self.additionalAttributes hash];
	result += [self.internalMappingItems count];
	return result;
}

- (NSString *)description
{
	return [NSString stringWithFormat:@"%@ %@ for %@ Mapping Items: %@ Additional Attributes: %@", [super description], self.name, self.controllerName, self.mappingItems, self.additionalAttributes];
}

- (NSSet *)mappingItemsForMIDIResponder:(id<MIKMIDIMappableResponder>)responder;
{	
	NSString *MIDIIdentifer = [responder MIDIIdentifier];
	
	NSMutableSet *matches = [NSMutableSet set];
	for (MIKMIDIMappingItem *item in self.internalMappingItems) {
		if (![item.MIDIResponderIdentifier isEqualToString:MIDIIdentifer]) continue;
		if (![[responder commandIdentifiers] containsObject:item.commandIdentifier]) continue;
		[matches addObject:item];
	}
	
	return matches;
}

- (NSSet *)mappingItemsForCommandIdentifier:(NSString *)commandID responder:(id<MIKMIDIMappableResponder>)responder;
{
	NSString *MIDIIdentifer = [responder MIDIIdentifier];
	return [self mappingItemsForCommandIdentifier:commandID responderWithIdentifier:MIDIIdentifer];
}

- (NSSet *)mappingItemsForCommandIdentifier:(NSString *)commandID responderWithIdentifier:(NSString *)responderID
{
	NSMutableSet *matches = [NSMutableSet set];
	for (MIKMIDIMappingItem *item in self.internalMappingItems) {
		if (![item.MIDIResponderIdentifier isEqualToString:responderID]) continue;
		if (![item.commandIdentifier isEqualToString:commandID]) continue;
		[matches addObject:item];
	}
	
	return matches;
}

- (NSSet *)mappingItemsForMIDICommand:(MIKMIDIChannelVoiceCommand *)command;
{
	NSUInteger controlNumber = MIKMIDIControlNumberFromCommand(command);
	UInt8 channel = command.channel;
	MIKMIDICommandType commandType = command.commandType;

	NSMutableSet *matches = [NSMutableSet set];
	for (MIKMIDIMappingItem *item in self.internalMappingItems) {
		if (item.controlNumber != controlNumber) continue;
		if (item.channel != channel) continue;
		if (item.commandType != commandType) continue;
		[matches addObject:item];
	}
	
	return matches;
}

#pragma mark - Private

#if !TARGET_OS_IPHONE
- (BOOL)loadPropertiesFromXMLDocument:(NSXMLDocument *)xmlDocument
{
	NSError *error = nil;
	
	NSArray *mappings = [xmlDocument nodesForXPath:@"./Mapping" error:&error];
	if (![mappings count]) {
		NSLog(@"Unable to get mapping from MIDI Mapping XML: %@", error);
		return NO;
	}
	NSXMLElement *mapping = [mappings lastObject];
	
	NSArray *nameAttributes = [mapping nodesForXPath:@"./@MappingName" error:&error];
	if (!nameAttributes) NSLog(@"Unable to get name attributes from MIDI Mapping XML: %@", error);
	self.name = [[nameAttributes lastObject] stringValue];
	
	NSArray *controllerNameAttributes = [mapping nodesForXPath:@"./@ControllerName" error:&error];
	if (!controllerNameAttributes) NSLog(@"Unable to get controller name attributes from MIDI Mapping XML: %@", error);
	self.controllerName = [[controllerNameAttributes lastObject] stringValue];
	
	NSArray *mappingItemElements = [mapping nodesForXPath:@"./MappingItems/MappingItem" error:&error];
	if (!mappingItemElements) {
		NSLog(@"Unable to get mapping items from MIDI mapping XML: %@", error);
		return NO;
	}
	
	for (NSXMLElement *element in mappingItemElements) {
		MIKMIDIMappingItem *item = [[MIKMIDIMappingItem alloc] initWithXMLElement:element];
		if (!item) continue;
		[self addMappingItemsObject:item];
	}
	
	NSMutableDictionary *attributes = [NSMutableDictionary dictionary];
	for (NSXMLNode *attribute in [mapping attributes]) {
		if (![[attribute stringValue] length]) continue;
		if ([[attribute name] isEqualToString:@"MappingName"]) continue;
		if ([[attribute name] isEqualToString:@"ControllerName"]) continue;
		[attributes setObject:[attribute stringValue] forKey:[attribute name]];
	}
	self.additionalAttributes = attributes;
	
	return YES;
}
#endif

#pragma mark - Properties

+ (NSSet *)keyPathsForValuesAffectingValueForKey:(NSString *)key
{
	NSSet *keyPaths = [super keyPathsForValuesAffectingValueForKey:key];
	
	if ([key isEqualToString:@"mappingItems"]) {
		keyPaths = [keyPaths setByAddingObject:@"internalMappingItems"];
	}
	
	if ([key isEqualToString:@"name"]) {
		keyPaths = [keyPaths setByAddingObject:@"controllerName"];
	}
	
	return keyPaths;
}

- (NSSet *)mappingItems { return [self.internalMappingItems copy]; }

- (void)addMappingItemsObject:(MIKMIDIMappingItem *)mappingItem
{
	[self.internalMappingItems addObject:mappingItem];
	mappingItem.mapping = self;
}

- (void)addMappingItems:(NSSet *)mappingItems
{
	[self.internalMappingItems unionSet:mappingItems];
	[mappingItems setValue:self forKey:@"mapping"];
}

- (void)removeMappingItemsObject:(MIKMIDIMappingItem *)mappingItem
{
	mappingItem.mapping = nil;
	[self.internalMappingItems removeObject:mappingItem];
}

- (void)removeMappingItems:(NSSet *)mappingItems
{
	NSMutableSet *removedMappingItems = [self.internalMappingItems mutableCopy];
	[self.internalMappingItems minusSet:mappingItems];
	[removedMappingItems minusSet:self.internalMappingItems];
	for (MIKMIDIMappingItem *item in removedMappingItems) { item.mapping = nil; }
}

- (NSString *)name
{
	if (![_name length]) return self.controllerName;
	return _name;
}

@end

#pragma mark -

@implementation MIKMIDIMapping (Deprecated)

- (instancetype)initWithFileAtURL:(NSURL *)url
{
	return [self initWithFileAtURL:url error:NULL];
}

@end