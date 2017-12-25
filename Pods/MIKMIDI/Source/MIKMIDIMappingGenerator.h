//
//  MIKMIDIMappingGenerator.h
//  Danceability
//
//  Created by Andrew Madsen on 7/19/13.
//  Copyright (c) 2013 Mixed In Key. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "MIKMIDICompilerCompatibility.h"

#import "MIKMIDIMapping.h"

@class MIKMIDIDevice;
@class MIKMIDIMapping;
@class MIKMIDIMappingItem;
@class MIKMIDICommand;

@protocol MIKMIDIMappingGeneratorDelegate;

NS_ASSUME_NONNULL_BEGIN

/**
 *  Completion block for mapping generation method.
 *
 *  @param mappingItem The mapping item generated, or nil if mapping failed.
 *  @param messages    The messages used to generate the mapping. May not include all messages received during mapping.
 *  @param error       If mapping failed, an NSError explaing the failure, nil if mapping succeeded.
 */
typedef void(^MIKMIDIMappingGeneratorMappingCompletionBlock)(MIKMIDIMappingItem *mappingItem, MIKArrayOf(MIKMIDICommand *) *messages, NSError *_Nullable error);

/**
 *  MIKMIDIMappingGenerator is used to map incoming commands from a MIDI device to MIDI responders in an application.
 *  It is intended to be used as the basis for a MIDI learning interface, where the application steps through controls/features
 *  and for each control, the user simply activates the hardware MIDI control (button, knob, etc.) to map it to that
 *  application function.
 *
 *  MIKMIDIMappingGenerator is able to interpret messages coming from a device to determine characteristics of the control
 *  sending the messages. This information is stored in the generated mapping for later use in correctly responding
 *  to incomding messages from each control. For example, some buttons on MIDI devices send a single message when 
 *  pressed down, while other button send a message on press, and another on release. MIKMIDIMappingGenerator can
 *  determine the behavior for a button during mapping, so that an application knows to expect two messages from the
 *  mapped button during later use.
 */
@interface MIKMIDIMappingGenerator : NSObject

/**
 *  Convenience method for creating a mapping generator for a MIKMIDIDevice. 
 *  The mapping generator will connect to the device's
 *  source endpoint(s) in order to receive MIDI messages from it.
 *
 *  @param device  The MIDI device for which a mapping is to be generated.
 *  @param error   If an error occurs, upon returns contains an NSError object that describes the problem. 
 *  If you are not interested in possible errors, you may pass in NULL.
 *
 *  @return An initialized MIKMIDIMappingGenerator instance, or nil if an error occurred.
 */
+ (instancetype)mappingGeneratorWithDevice:(MIKMIDIDevice *)device error:(NSError **)error;

/**
 *  Creates and initializes a mapping generator for a MIKMIDIDevice. 
 *  The mapping generator will connect to the device's
 *  source endpoint(s) in order to receive MIDI messages from it.
 *
 *  @param device  The MIDI device for which a mapping is to be generated.
 *  @param error   If an error occurs, upon returns contains an NSError object that describes the problem.
 *  If you are not interested in possible errors, you may pass in NULL.
 *
 *  @return An initialized MIKMIDIMappingGenerator instance, or nil if an error occurred.
 */
- (instancetype)initWithDevice:(MIKMIDIDevice *)device error:(NSError **)error NS_DESIGNATED_INITIALIZER;

/**
 *  Begins mapping a given MIDIResponder. This method returns immediately.
 *
 *  @param control         The MIDI Responder object to map. Must conform to the MIKMIDIMappableResponder protocol.
 *  @param commandID       The command identifier to be mapped. Must be one of the identifiers returned by the responder's -commandIdentifiers method.
 *  @param numMessages     The minimum number of messages to receive before immediately mapping the control. Pass 0 for the default.
 *  @param timeout         Time to wait (in seconds) after the last received message before attempting to generate a mapping, or start over. Pass 0 for the default.
 *  @param completionBlock Block called when mapping is successfully completed. Call -cancelCurrentCommandLearning to cancel a failed mapping.
 */
- (void)learnMappingForControl:(id<MIKMIDIMappableResponder>)control
		 withCommandIdentifier:(NSString *)commandID
	 requiringNumberOfMessages:(NSUInteger)numMessages
			 orTimeoutInterval:(NSTimeInterval)timeout
			   completionBlock:(MIKMIDIMappingGeneratorMappingCompletionBlock)completionBlock;

/**
 *  Cancels the mapping previously started by calling -learnMappingForControl:withCommandIdentifier:requiringNumberOfMessages:orTimeoutInterval:completionBlock:.
 */
- (void)cancelCurrentCommandLearning;

/**
 *  Temporarily suspends mapping without discarding state. Unlike -cancelCurrentCommandLearning, or -endMapping,
 *  mapping can be resumed exactly where it left off by calling -resumeMapping. Incoming MIDI is simply
 *  ignored while mapping is suspended.
 *
 *  Note that if mapping is not currently in progress, this method has no effect.
 */
- (void)suspendMapping;

/**
 *  Resumes mapping after it was previously suspended using -suspendMapping.
 *
 *  Note that if mapping was not previously in progress and currently suspended, this has no effect.
 */
- (void)resumeMapping;

/**
 *  Stops mapping generation, disconnecting from the device.
 */
- (void)endMapping;

// Properties

/**
 * The delegate for the mapping generator. Can be used to customize certain mapping behavior. Optional.
 *
 * The delegate must implement the MIKMIDIMappingGeneratorDelegate protocol.
 */
@property (nonatomic, MIKTargetSafeWeak) id<MIKMIDIMappingGeneratorDelegate> delegate;

/**
 *  The device for which a mapping is being generated. Must not be nil for mapping to work.
 */
@property (nonatomic, strong, nullable) MIKMIDIDevice *device;

/**
 *  The mapping being generated. Assign before mapping starts to modify existing mapping.
 */
@property (nonatomic, strong) MIKMIDIMapping *mapping;

/**
 *  Set this to YES to enable printing diagnostic messages to the console. This is intended
 *  to help with eg. debugging trouble mapping specific controllers. The default
 *  is NO, ie. logging is disabled.
 */
@property (nonatomic, getter=isDiagnosticLoggingEnabled) BOOL diagnosticLoggingEnabled;

@end


/**
 *  Possible values to return from the following methods in MIKMIDIMappingGeneratorDelegate:
 *
 *  -mappingGenerator:behaviorForRemappingCommandMappedToControls:toNewControl:
 *
 */
typedef NS_ENUM(NSUInteger, MIKMIDIMappingGeneratorRemapBehavior) {
	
	/**
	 *  Ignore the previously mapped control, and do not (re)map it to the responder for which mapping is in progress.
	 */
	MIKMIDIMappingGeneratorRemapDisallow,
	
	/**
	 *  Map the previously mapped control to the responder for which mapping is in progress. Do not remove the previous/existing
	 *  mappings for the control.
	 */
	MIKMIDIMappingGeneratorRemapAllowDuplicate,
	
	/**
	 *  Map the previously mapped control to the responder for which mapping is in progress. Remove the previous/existing
	 *  mappings for the control. With this option, after mapping, only the newly-mapped responder will be associated with the
	 *  mapped physical control.
	 */
	MIKMIDIMappingGeneratorRemapReplace,
	
	/**
	 * The default behavior which is MIKMIDIMappingGeneratorRemapDisallow.
	 */
	MIKMIDIMappingGeneratorRemapDefault = MIKMIDIMappingGeneratorRemapDisallow,
};

/**
 *  Defines methods to be implemented by the delegate of an MIKMIDIMappingGenerator in order
 *  to customize mapping generation behavior.
 */
@protocol MIKMIDIMappingGeneratorDelegate <NSObject>

@optional

/**
 *  Used to determine behavior when attempting to map a physical control that has been previously mapped to a new responder.
 *
 *  When MIKMIDIMappingGenerator receives mappable messages from a physical control and finds that that control has already
 *  been mapped to one or more other virtual controls (responder/command combinations), it will call this method to ask what
 *  to do. One of the options specified in MIKMIDIMappingGeneratorRemapBehavior should be returned.
 *
 *  To use the default behavior, (currently MIKMIDIMappingGeneratorRemapDisallow) return MIKMIDIMappingGeneratorRemapDefault. If the
 *  delegate does not respond to this method, the default behavior is used.
 *
 *  @param generator         The mapping generator performing the mapping.
 *  @param mappingItems      The mapping items for commands previously mapped to the physical control in question.
 *  @param newResponder      The responder for which a mapping is currently being generated.
 *  @param commandIdentifier The command identifier of newResponder that is being mapped.
 *
 *  @return The behavior to use when mapping the newResponder. See MIKMIDIMappingGeneratorRemapBehavior for a list of possible values.
 */
- (MIKMIDIMappingGeneratorRemapBehavior)mappingGenerator:(MIKMIDIMappingGenerator *)generator
			  behaviorForRemappingControlMappedWithItems:(MIKSetOf(MIKMIDIMappingItem *) *)mappingItems
										  toNewResponder:(id<MIKMIDIMappableResponder>)newResponder
									   commandIdentifier:(NSString *)commandIdentifier;

/**
 *  Used to determine whether the existing mapping item for a responder should be superceded by a new mapping item.
 *
 *  The default behavior is to remove existing mapping items (return value of YES). If the delegate does not respond to
 *  this method, the default behavior is used.
 *
 *  @param generator    The mapping generator performing the mapping.
 *  @param mappingItems The set of existing MIKMIDIMappingItems associated with responder.
 *  @param responder    The reponsder for which a mapping is currently being generated.
 *
 *  @return YES to remove the existing mapping items. NO to keep the existing mapping items in addition to the new mapping item being generated.
 */
- (BOOL)mappingGenerator:(MIKMIDIMappingGenerator *)generator
shouldRemoveExistingMappingItems:(MIKSetOf(MIKMIDIMappingItem *) *)mappingItems
 forResponderBeingMapped:(id<MIKMIDIMappableResponder>)responder;

/**
 *  The delegate can implement this to do some transformation of incoming commands in order to customize
 *  mapping. For instance, controls can be dynamically remapped, or incoming commands can be selectively ignored.
 *  Most users of MIKMIDIMappingGenerator will not need to use this.
 *
 *  @param command An incoming MIKMIDICommand.
 *
 *  @return A processed/modified copy of the incoming command, or nil to ignore the command.
 */
- (MIKMIDIChannelVoiceCommand *)mappingGenerator:(MIKMIDIMappingGenerator *)generator
			  commandByProcessingIncomingCommand:(MIKMIDIChannelVoiceCommand *)command;

@end

NS_ASSUME_NONNULL_END