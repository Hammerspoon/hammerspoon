//
//  MIKMIDIMapping.h
//  Energetic
//
//  Created by Andrew Madsen on 3/15/13.
//  Copyright (c) 2013 Mixed In Key. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "MIKMIDICompilerCompatibility.h"

#import "MIKMIDICommand.h"
#import "MIKMIDIResponder.h"

@protocol MIKMIDIMappableResponder;

@class MIKMIDIChannelVoiceCommand;
@class MIKMIDIMappingItem;

NS_ASSUME_NONNULL_BEGIN

/**
 *  Overview
 *  --------
 *
 *  MIKMIDIMapping includes represents a complete mapping between a particular hardware controller,
 *  and an application's functionality. Primarily, it acts as a container for MIKMIDIMappingItems,
 *  each of which specifies the mapping for a single hardware control.
 *
 *  MIKMIDIMapping can be stored on disk using a straightforward XML format, and includes methods
 *  to load and write these XML files. Currently this is only implemented on OS X (see 
 *  https://github.com/mixedinkey-opensource/MIKMIDI/issues/2 ).
 *
 *  Another class, MIKMIDIMappingManager can be used to manage both application-supplied, and
 *  user customized mappings.
 *
 *  Creating Mappings
 *  -----------------
 *
 *  MIKMIDIMappings can be generated manually, as the XML format is fairly straightforward.
 *  MIKMIDI also includes powerful functionality to assist in creating a way for users to
 *  easily create their own mappings using a "MIDI learning" interface.
 *
 *  Using Mappings
 *  --------------
 *  
 *  MIKMIDI does not include built in support for automatically routing messages using a mapping,
 *  so a user of MIKMIDI must write some code to make this happen. Typically, this is done by having
 *  a single controller in the application be responsible for receiving all incoming MIDI messages.
 *  When a MIDI message is received, it can query the MIDI mapping for the mapping item correspoding
 *  to the incomding message, then send the command to the mapped responder. Example code for this scenario:
 *
 *  	- (void)connectToMIDIDevice:(MIKMIDIDevice *)device {
 *  		MIKMIDIDeviceManager *manager = [MIKMIDIDeviceManager sharedDeviceManager];
 *  		BOOL success = [manager connectInput:source error:error eventHandler:^(MIKMIDISourceEndpoint *source, NSArray *commands) {
 *  			for (MIKMIDICommand *command in commands) {
 *  				[self routeIncomingMIDICommand:command];
 *  			}
 *  		}];
 *
 *  		if (success) self.device = device;
 *  	}
 *
 *  	- (void)routeIncomingMIDICommand:
 *  	{
 *  	    MIKMIDIDevice *controller = self.device; // The connected MIKMIDIDevice instance
 *  		MIKMIDIMapping *mapping = [[[MIKMIDIMappingManager sharedManager] mappingsForControllerName:controller.name] anyObject];
 *  		MIKMIDIMappingItem *mappingItem = [[self.MIDIMapping mappingItemsForMIDICommand:command] anyObject];
 *  		if (!mappingItem) return;
 *
 *  		id<MIKMIDIResponder> responder = [NSApp MIDIResponderWithIdentifier:mappingItem.MIDIResponderIdentifier];
 *  		if ([responder respondsToMIDICommand:command]) {
 *  			[responder handleMIDICommand:command];
 *  		}
 *  	}
 *
 *  @see MIKMIDIMappingManager
 *  @see MIKMIDIMappingGenerator
 */
@interface MIKMIDIMapping : NSObject <NSCopying>

/**
 *  Initializes and returns an MIKMIDIMapping object created from the XML file at url.
 *
 *  @param url   An NSURL for the file to be read.
 *  @param error If an error occurs, upon returns contains an NSError object that describes the problem. If you are not interested in possible errors, you may pass in NULL.
 *
 *  @return An initialized MIKMIDIMapping instance, or nil if an error occurred.
 */
- (nullable instancetype)initWithFileAtURL:(NSURL *)url error:(NSError **)error;

/**
 *	Creates and initializes an MIKMIDIMapping object that is the same as the passed in bundled mapping
 *	but with isBundledMapping set to NO.
 *
 *	@param bundledMapping The bundled mapping you would like to make a user mapping copy of.
 *
 *	@return An initialized MIKMIDIMapping instance that is the same as the passed in mapping but
 *	with isBundledMapping set to NO.
 */
+ (instancetype)userMappingFromBundledMapping:(MIKMIDIMapping *)bundledMapping;

#if !TARGET_OS_IPHONE
/**
 *  Returns an NSXMLDocument representation of the receiver.
 *  The XML document returned by this method can be written to disk.
 *
 *  @note This method is currently only available on OS X. -XMLStringRepresentation can be used on iOS.
 *  @deprecated This method is deprecated on OS X. Use -XMLStringRepresentation instead.
 *
 *  @return An NSXMLDocument representation of the receiver.
 *
 *  @see -writeToFileAtURL:error:
 */
- (NSXMLDocument *)XMLRepresentation DEPRECATED_ATTRIBUTE;

#endif

/**
 *  Returns an NSString instance containing an XML representation of the receiver.
 *  The XML document returned by this method can be written to disk.
 *
 *  @return An NSString containing an XML representation of the receiver, or nil if an error occurred.
 *
 *  @see -writeToFileAtURL:error:
 */
- (nullable NSString *)XMLStringRepresentation;

/**
 *  Writes the receiver as an XML file to the specified URL.
 *
 *  @note This method is currently only available on OS X. See https://github.com/mixedinkey-opensource/MIKMIDI/issues/2
 *
 *  @param fileURL The URL for the file to be written.
 *  @param error   If an error occurs, upon returns contains an NSError object that describes the problem. If you are not interested in possible errors, you may pass in NULL.
 *
 *  @return YES if writing the mapping to a file succeeded, NO if an error occurred.
 */
- (BOOL)writeToFileAtURL:(NSURL *)fileURL error:(NSError **)error;

/**
 *  The mapping items that map controls to responder. 
 *
 *  This can be used to get mapping items for all commands supported by a responder. It is
 *  also possible for multiple physical controls to be mapped to a single command on the same responder.
 *
 *  @param responder An object that coforms to the MIKMIDIMappableResponder protocol.
 *
 *  @return An NSSet containing MIKMIDIMappingItems for responder, or an empty set if none are found.
 */
- (MIKSetOf(MIKMIDIMappingItem *) *)mappingItemsForMIDIResponder:(id<MIKMIDIMappableResponder>)responder;

/**
 *  The mapping items that map controls to a specific command identifier supported by a MIDI responder.
 *
 *  @param commandID An NSString containing one of the responder's supported command identifiers.
 *  @param responder  An object that coforms to the MIKMIDIMappableResponder protocol.
 *
 *  @return An NSSet containing MIKMIDIMappingItems for the responder and command identifer, or an empty set if none are found.
 *
 *  @see -[<MIKMIDIMappableResponder> commandIdentifiers]
 *  @see -mappingItemsForCommandIdentifier:responderWithIdentifier:
 */
- (MIKSetOf(MIKMIDIMappingItem *) *)mappingItemsForCommandIdentifier:(NSString *)commandID responder:(id<MIKMIDIMappableResponder>)responder;

/**
 *  The mapping items that map controls to a specific command identifier supported by a MIDI responder with a given
 *  identifier.
 *
 *  @param commandID An NSString containing one of the responder's supported command identifiers.
 *  @param responderID An NSString
 *
 *  @return An NSSet containing MIKMIDIMappingItems for the responder and command identifer, or an empty set if none are found.
 *
 *  @see -[<MIKMIDIMappableResponder> commandIdentifiers]
 *  @see -mappingItemsForCommandIdentifier:responder:
 */
- (MIKSetOf(MIKMIDIMappingItem *) *)mappingItemsForCommandIdentifier:(NSString *)commandID responderWithIdentifier:(NSString *)responderID;

/**
 *  The mapping items for a particular MIDI command (corresponding to a physical control).
 *
 *  This method is typically used to route incoming messages from a controller to the correct mapped responder.
 *
 *  @param command An an instance of MIKMIDICommand.
 *
 *  @return An NSSet containing MIKMIDIMappingItems for command, or an empty set if none are found.
 */
- (MIKSetOf(MIKMIDIMappingItem *) *)mappingItemsForMIDICommand:(MIKMIDIChannelVoiceCommand *)command;

/**
 *  The name of the MIDI mapping. Currently only used to determine the (default) file name when saving a mapping to disk.
 *  If not set, this defaults to the controllerName.
 */
@property (nonatomic, copy) NSString *name;

/**
 *  The name of the hardware controller this mapping is for. This should (typically) be the same as the name returned by
 *  calling -[MIKMIDIDevice name] on the controller's MIKMIDIDevice instance.
 */
@property (nonatomic, copy) NSString *controllerName;

/**
 *  YES if the receiver was loaded from the application bundle, NO if loaded from user-accessible folder (e.g. Application Support)
 */
@property (nonatomic, readonly, getter = isBundledMapping) BOOL bundledMapping;

/**
 *  Optional additional key value pairs, which will be saved as attributes in this mapping's XML representation. Keys and values must be NSStrings.
 */
@property (nonatomic, copy, nullable) NSDictionary *additionalAttributes;

/**
 *  All mapping items this mapping contains.
 */
@property (nonatomic, readonly) MIKSetOf(MIKMIDIMappingItem *) *mappingItems;

/**
 *  Add a single mapping item to the receiver.
 *
 *  @param mappingItem An MIKMIDIMappingItem instance.
 */
- (void)addMappingItemsObject:(MIKMIDIMappingItem *)mappingItem;

/**
 *  Add multiple mapping items to the receiver.
 *
 *  @param mappingItems An NSSet containing mappings to be added.
 */
- (void)addMappingItems:(MIKSetOf(MIKMIDIMappingItem *) *)mappingItems;

/**
 *  Remove a mapping item from the receiver.
 *
 *  @param mappingItem An MIKMIDIMappingItem instance.
 */
- (void)removeMappingItemsObject:(MIKMIDIMappingItem *)mappingItem;

/**
 *  Remove multiple mapping items from the receiver.
 *
 *  @param mappingItems An NSSet containing mappings to be removed.
 */
- (void)removeMappingItems:(MIKSetOf(MIKMIDIMappingItem *) *)mappingItems;

@end

#pragma mark - 

@interface MIKMIDIMapping (Deprecated)

/**
 *  @deprecated Use -initWithFileAtURL:error: instead.
 *  Initializes and returns an MIKMIDIMapping object created from the XML file at url.
 *
 *  @param url   An NSURL for the file to be read.
 *
 *  @return An initialized MIKMIDIMapping instance, or nil if an error occurred.
 *
 *  @see -initWithFileAtURL:error:
 */
- (nullable instancetype)initWithFileAtURL:(NSURL *)url DEPRECATED_ATTRIBUTE;

@end

NS_ASSUME_NONNULL_END