//
//  MIKMIDIMappingXMLParser.m
//  MIDI Soundboard
//
//  Created by Andrew Madsen on 4/15/14.
//  Copyright (c) 2014 Open Reel Software. All rights reserved.
//

#import "MIKMIDIMappingXMLParser.h"
#import "MIKMIDIMapping.h"
#import "MIKMIDIMappingItem.h"
#import "MIKMIDIUtilities.h"

@interface NSString (MIKMIDIMappingXMLParserUtilities)

- (NSString *)mik_uncapitalizedString;

@end

@interface MIKMIDIMappingXMLParser () <NSXMLParserDelegate>

@property (nonatomic, strong) NSXMLParser *parser;
@property (nonatomic, strong) NSData *xmlData;
@property (nonatomic, strong) NSMutableArray *internalMappings;
@property (nonatomic, strong) NSArray *mappings;
@property (nonatomic, strong) MIKMIDIMapping *currentMapping;

@property (nonatomic, strong) NSMutableDictionary *currentItemInfo;
@property (nonatomic, strong) NSString *currentElementName;
@property (nonatomic, strong) NSMutableString *currentElementValueBuffer;

@property (nonatomic) BOOL hasParsed;

@end

@implementation MIKMIDIMappingXMLParser

+ (instancetype)parserWithXMLData:(NSData *)xmlData
{
	return [[self alloc] initWithXMLData:xmlData];
}

- (instancetype)initWithXMLData:(NSData *)xmlData
{
	if (![xmlData length]) {
		[NSException raise:NSInvalidArgumentException format:@"Argument passed to -[%@ %@] must have a non-zero length.", NSStringFromClass([self class]), NSStringFromSelector(_cmd)];
	}
	
	self = [super init];
	if (self) {
		_xmlData = xmlData;
		_internalMappings = [NSMutableArray array];
	}
	return self;
}

#pragma mark - Private

- (void)parse
{
	NSXMLParser *parser = [[NSXMLParser alloc] initWithData:self.xmlData];
	[parser setDelegate:self];
	
	self.hasParsed = [parser parse];
}

#pragma mark - NSXMLParserDelegate

- (void)parser:(NSXMLParser *)parser didStartElement:(NSString *)elementName namespaceURI:(NSString *)namespaceURI qualifiedName:(NSString *)qName attributes:(NSDictionary *)attributeDict
{
	if ([elementName isEqualToString:@"Mapping"]) {
		self.currentMapping =  [[MIKMIDIMapping alloc] init];
		self.currentMapping.controllerName = attributeDict[@"ControllerName"];
		self.currentMapping.name = attributeDict[@"MappingName"];
		NSMutableDictionary *attributeDictScratch = [attributeDict mutableCopy];
		[attributeDictScratch removeObjectForKey:@"ControllerName"];
		[attributeDictScratch removeObjectForKey:@"MappingName"];
		self.currentMapping.additionalAttributes = attributeDictScratch;
		return;
	}
	
	if ([elementName isEqualToString:@"MappingItem"]) {
		self.currentItemInfo = [NSMutableDictionary dictionary];
		self.currentItemInfo[@"additionalAttributes"] = [NSMutableDictionary dictionary];
		for (NSString *key in attributeDict) {
			id attributeValue = attributeDict[key];
			if ([key isEqualToString:@"InteractionType"]) {
				self.currentItemInfo[@"interactionType"] = @(MIKMIDIMappingInteractionTypeForAttributeString(attributeValue));
				continue;
			} else if ([key isEqualToString:@"Flipped"]) {
				self.currentItemInfo[@"flipped"] = @([attributeValue boolValue]);
				continue;
			}
			
			self.currentItemInfo[@"additionalAttributes"][key] = attributeValue;
		}
		return;
	}
	
	if (self.currentItemInfo) {
		// In the middle parsing a mapping item
		self.currentElementName = elementName;
		self.currentElementValueBuffer = [NSMutableString string];
		
		return;
	}
}

- (void)parser:(NSXMLParser *)parser foundCharacters:(NSString *)string
{
	[self.currentElementValueBuffer appendString:string];
}

- (void)parser:(NSXMLParser *)parser didEndElement:(NSString *)elementName namespaceURI:(NSString *)namespaceURI qualifiedName:(NSString *)qName
{
	if ([elementName isEqualToString:@"Mapping"]) {
		if (!self.currentMapping) return;
		[self.internalMappings addObject:self.currentMapping];
		self.currentMapping = nil;
		
		return;
	}
	
	if ([elementName isEqualToString:@"MappingItem"]) {
		NSString *responderID = self.currentItemInfo[@"responderIdentifier"];
		[self.currentItemInfo removeObjectForKey:@"responderIdentifier"];
		NSString *commandID = self.currentItemInfo[@"commandIdentifier"];
		[self.currentItemInfo removeObjectForKey:@"commandIdentifier"];
		MIKMIDIMappingItem *item = [[MIKMIDIMappingItem alloc] initWithMIDIResponderIdentifier:responderID andCommandIdentifier:commandID];
		
		item.additionalAttributes = self.currentItemInfo[@"additionalAttributes"];
		item.channel = [self.currentItemInfo[@"channel"] integerValue];
		item.commandType = [self.currentItemInfo[@"commandType"] integerValue];
		item.controlNumber = [self.currentItemInfo[@"controlNumber"] unsignedIntegerValue];
		item.flipped = [self.currentItemInfo[@"flipped"] boolValue];
		item.interactionType = [self.currentItemInfo[@"interactionType"] integerValue];
		
		[self.currentMapping addMappingItemsObject:item];
		
		self.currentItemInfo = nil;

		return;
	}
	
	if ([elementName isEqualToString:self.currentElementName]) {
		// Current element is stored as a string which may need to be converted to an NSNumber.
		// Using NSScanner here, as detailed in https://stackoverflow.com/a/572312/8653957
		NSString* currentElement = [self.currentElementValueBuffer copy];
		NSScanner* scanner = [NSScanner scannerWithString:currentElement];
		self.currentItemInfo[[elementName mik_uncapitalizedString]] = ([scanner scanInt:nil] && [scanner isAtEnd]) ? @(currentElement.integerValue) : currentElement;
		
		self.currentElementName = nil;
		self.currentElementValueBuffer = nil;
		
		return;
	}
}

- (void)parser:(NSXMLParser *)parser parseErrorOccurred:(NSError *)parseError
{
	NSLog(@"Parsing failed with error: %@", parseError);
	self.currentMapping = nil;
}

- (void)parserDidEndDocument:(NSXMLParser *)parser
{
	self.mappings = [self.internalMappings copy];
}

#pragma mark - Properties

- (NSArray *)mappings
{
	if (!self.hasParsed) [self parse];
	return _mappings ?: @[];
}

@end

@implementation NSString (MIKMIDIMappingXMLParserUtilities)

- (NSString *)mik_uncapitalizedString
{
	// This is a bit quick and dirty, but it does the job
	if (![self length]) return self;
	
	NSMutableString *scratch = [self mutableCopy];
	NSString *firstCharacter = [self substringToIndex:1];
	[scratch replaceCharactersInRange:NSMakeRange(0, 1) withString:[firstCharacter lowercaseString]];
	return [scratch copy];
}

@end
