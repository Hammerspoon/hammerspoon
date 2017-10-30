//
//  MIKMIDIMappingItem.m
//  MIKMIDI
//
//  Created by Andrew Madsen on 5/20/15.
//  Copyright (c) 2015 Mixed In Key. All rights reserved.
//

#import "MIKMIDIMappingItem.h"
#import "MIKMIDIPrivateUtilities.h"
#import "MIKMIDIUtilities.h"

#if TARGET_OS_IPHONE
#import <libxml/xmlwriter.h>
#endif

@interface MIKMIDIMappingItem ()

@property (nonatomic, weak, readwrite) MIKMIDIMapping *mapping;

@end

@implementation MIKMIDIMappingItem

- (instancetype)initWithMIDIResponderIdentifier:(NSString *)MIDIResponderIdentifier andCommandIdentifier:(NSString *)commandIdentifier;
{
	self = [super init];
	
	if (self) {
		_MIDIResponderIdentifier = [MIDIResponderIdentifier copy];
		_commandIdentifier = [commandIdentifier copy];
	}
	
	return self;
}

- (id)init
{
	[NSException raise:NSInternalInconsistencyException format:@"-[MIKMIDIMappingItem init] is deprecated and should be replaced with a call to -initWithMIDIResponderIdentifier:andCommandIdentifier:."];
	return [self initWithMIDIResponderIdentifier:@"Unknown" andCommandIdentifier:@"Unknown"];
}

#if !TARGET_OS_IPHONE

- (instancetype)initWithXMLElement:(NSXMLElement *)element;
{
	if (!element) { self = nil; return self; }
	
	NSError *error = nil;
	
	NSXMLElement *responderIdentifier = [[element nodesForXPath:@"ResponderIdentifier" error:&error] lastObject];
	if (!responderIdentifier) {
		NSLog(@"Unable to read responder identifier from %@: %@", element, error);
		self = nil;
		return nil;
	}
	
	NSXMLElement *commandIdentifier = [[element nodesForXPath:@"CommandIdentifier" error:&error] lastObject];
	if (!commandIdentifier) {
		NSLog(@"Unable to read command identifier from %@: %@", element, error);
		self = nil;
		return nil;
	}
	
	NSXMLElement *channel = [[element nodesForXPath:@"Channel" error:&error] lastObject];
	if (!channel) {
		NSLog(@"Unable to read channel from %@: %@", element, error);
		self = nil;
		return nil;
	}
	
	NSXMLElement *commandType = [[element nodesForXPath:@"CommandType" error:&error] lastObject];
	if (!commandType) {
		NSLog(@"Unable to read command type from %@: %@", element, error);
	}
	
	NSXMLElement *controlNumber = [[element nodesForXPath:@"ControlNumber" error:&error] lastObject];
	if (!controlNumber) {
		NSLog(@"Unable to read control number from %@: %@", element, error);
		self = nil;
		return nil;
	}
	
	NSXMLElement *interactionType = [[element nodesForXPath:@"@InteractionType" error:&error] lastObject];
	if (!interactionType) {
		NSLog(@"Unable to read interaction type from %@: %@", element, error);
		self = nil;
		return nil;
	}
	
	NSXMLElement *flippedStatus = [[element nodesForXPath:@"@Flipped" error:&error] lastObject];
	
	NSMutableDictionary *attributes = [NSMutableDictionary dictionary];
	for (NSXMLNode *attribute in [element attributes]) {
		if (![[attribute stringValue] length]) continue;
		if ([[attribute name] isEqualToString:@"InteractionType"]) continue;
		if ([[attribute name] isEqualToString:@"Flipped"]) continue;
		[attributes setObject:[attribute stringValue] forKey:[attribute name]];
	}
	
	self = [self initWithMIDIResponderIdentifier:[responderIdentifier stringValue] andCommandIdentifier:[commandIdentifier stringValue]];
	if (self) {
		_channel = [[channel stringValue] integerValue];
		_commandType = [[commandType stringValue] integerValue];
		_controlNumber = [[controlNumber stringValue] integerValue];
		_interactionType = MIKMIDIMappingInteractionTypeForAttributeString([interactionType stringValue]);
		_flipped = [[flippedStatus stringValue] boolValue];
		
		_additionalAttributes = [attributes copy];
	}
	return self;
}

- (NSXMLDocument *)XMLRepresentation
{
	return [self privateXMLRepresentation];
}

- (NSXMLDocument *)privateXMLRepresentation
{
	NSXMLElement *responderIdentifier = [NSXMLElement elementWithName:@"ResponderIdentifier" stringValue:self.MIDIResponderIdentifier];
	NSXMLElement *commandIdentifier = [NSXMLElement elementWithName:@"CommandIdentifier" stringValue:self.commandIdentifier];
	NSXMLElement *channel = [NSXMLElement elementWithName:@"Channel"];
	[channel setStringValue:[@(self.channel) stringValue]];
	NSXMLElement *commandType = [NSXMLElement elementWithName:@"CommandType"];
	[commandType setStringValue:[@(self.commandType) stringValue]];
	NSXMLElement *controlNumber = [NSXMLElement elementWithName:@"ControlNumber"];
	[controlNumber setStringValue:[@(self.controlNumber) stringValue]];
	
	NSXMLElement *interactionType = [[NSXMLElement alloc] initWithKind:NSXMLAttributeKind];
	[interactionType setName:@"InteractionType"];
	NSString *interactionTypeString = MIKMIDIMappingAttributeStringForInteractionType(self.interactionType);
	[interactionType setStringValue:interactionTypeString];
	
	NSXMLElement *flippedStatus = [[NSXMLElement alloc] initWithKind:NSXMLAttributeKind];
	[flippedStatus setName:@"Flipped"];
	NSString *flippedStatusString = self.flipped ? @"true" : @"false";
	[flippedStatus setStringValue:flippedStatusString];
	
	NSMutableArray *attributes = [NSMutableArray arrayWithArray:@[interactionType, flippedStatus]];
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
	
	return [NSXMLElement elementWithName:@"MappingItem"
								children:@[responderIdentifier, commandIdentifier, channel, commandType, controlNumber]
							  attributes:attributes];
}

#endif

- (NSString *)XMLStringRepresentation
{
#if !TARGET_OS_IPHONE
	return [[self XMLRepresentation] XMLStringWithOptions:NSXMLNodePrettyPrint];
#else
	
	int err = 0;
	xmlTextWriterPtr writer = NULL;
	xmlBufferPtr buffer = xmlBufferCreate();
	if (!buffer) {
		NSLog(@"Unable to create XML buffer.");
		goto CLEANUP_AND_EXIT;
	}
	
	{
		writer = xmlNewTextWriterMemory(buffer, 0);
		if (!writer) {
			xmlBufferFree(buffer);
			NSLog(@"Unable to create XML writer.");
			goto CLEANUP_AND_EXIT;
		}
		
		xmlTextWriterSetIndent(writer, 1);
		
		err = xmlTextWriterStartElement(writer, BAD_CAST "MappingItem"); // <MappingItem>
		if (err < 0) {
			NSLog(@"Unable to start XML MappingItem element: %i", err);
			goto CLEANUP_AND_EXIT;
		}
		
		NSString *interactionTypeString = MIKMIDIMappingAttributeStringForInteractionType(self.interactionType);
		err = xmlTextWriterWriteAttribute(writer, BAD_CAST "InteractionType", BAD_CAST [interactionTypeString UTF8String]);
		if (err < 0) {
			NSLog(@"Unable to write InteractionType attribute for MappingItem element: %i", err);
			goto CLEANUP_AND_EXIT;
		}
		
		NSString *flippedStatusString = self.flipped ? @"true" : @"false";
		err = xmlTextWriterWriteAttribute(writer, BAD_CAST "Flipped", BAD_CAST [flippedStatusString UTF8String]);
		if (err < 0) {
			NSLog(@"Unable to write InteractionType attribute for MappingItem element: %i", err);
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
		
		err = xmlTextWriterWriteElement(writer, BAD_CAST "ResponderIdentifier", BAD_CAST [self.MIDIResponderIdentifier UTF8String]);
		if (err < 0) {
			NSLog(@"Unable to write ResponderIdentifier element for mapping %@: %i", self, err);
			goto CLEANUP_AND_EXIT;
		}
		
		err = xmlTextWriterWriteElement(writer, BAD_CAST "CommandIdentifier", BAD_CAST [self.commandIdentifier UTF8String]);
		if (err < 0) {
			NSLog(@"Unable to write CommandIdentifier element for mapping %@: %i", self, err);
			goto CLEANUP_AND_EXIT;
		}
		
		err = xmlTextWriterWriteElement(writer, BAD_CAST "Channel", BAD_CAST [[@(self.channel) stringValue] UTF8String]);
		if (err < 0) {
			NSLog(@"Unable to write Channel element for mapping %@: %i", self, err);
			goto CLEANUP_AND_EXIT;
		}
		
		err = xmlTextWriterWriteElement(writer, BAD_CAST "CommandType", BAD_CAST [[@(self.commandType) stringValue] UTF8String]);
		if (err < 0) {
			NSLog(@"Unable to write CommandType element for mapping %@: %i", self, err);
			goto CLEANUP_AND_EXIT;
		}
		
		err = xmlTextWriterWriteElement(writer, BAD_CAST "ControlNumber", BAD_CAST [[@(self.controlNumber) stringValue] UTF8String]);
		if (err < 0) {
			NSLog(@"Unable to write ControlNumber element for mapping %@: %i", self, err);
			goto CLEANUP_AND_EXIT;
		}
		
		err = xmlTextWriterEndElement(writer); // </MappingItem>
		if (err < 0) {
			NSLog(@"Unable to end XML MappingItem element: %i", err);
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

- (id)copyWithZone:(NSZone *)zone
{
	MIKMIDIMappingItem *result = [[MIKMIDIMappingItem alloc] initWithMIDIResponderIdentifier:self.MIDIResponderIdentifier andCommandIdentifier:self.commandIdentifier];
	result.interactionType = self.interactionType;
	result.flipped = self.flipped;
	result.channel = self.channel;
	result.commandType = self.commandType;
	result.controlNumber = self.controlNumber;
	result.additionalAttributes = self.additionalAttributes;
	
	return result;
}

- (BOOL)isEqual:(MIKMIDIMappingItem *)otherMappingItem
{
	if (self == otherMappingItem) return YES;
	
	if (self.controlNumber != otherMappingItem.controlNumber) return NO;
	if (self.channel != otherMappingItem.channel) return NO;
	if (self.commandType != otherMappingItem.commandType) return NO;
	if (self.interactionType != otherMappingItem.interactionType) return NO;
	if (self.flipped != otherMappingItem.flipped) return NO;
	if (![self.MIDIResponderIdentifier isEqualToString:otherMappingItem.MIDIResponderIdentifier]) return NO;
	if (![self.commandIdentifier isEqualToString:otherMappingItem.commandIdentifier]) return NO;
	if (![self.additionalAttributes isEqualToDictionary:otherMappingItem.additionalAttributes]) return NO;
	
	return YES;
}

- (NSUInteger)hash
{
	// Only depend on non-mutable properties
	NSUInteger result = [_MIDIResponderIdentifier hash];
	result += [_commandIdentifier hash];
	
	return result;
}

- (NSString *)description
{
	NSMutableString *result = [NSMutableString stringWithFormat:@"%@ %@ %@ CommandID: %@ Channel %li MIDI Command %li Control Number %lu flipped %i", [super description], MIKMIDIMappingAttributeStringForInteractionType(self.interactionType), self.MIDIResponderIdentifier, self.commandIdentifier, (long)self.channel, (long)self.commandType, (unsigned long)self.controlNumber, (int)self.flipped];
	if ([self.additionalAttributes count]) {
		for (NSString *key in self.additionalAttributes) {
			NSString *value = self.additionalAttributes[key];
			[result appendFormat:@" %@: %@", key, value];
		}
	}
	return result;
}

@end

