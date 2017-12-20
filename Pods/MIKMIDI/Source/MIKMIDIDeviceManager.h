//
//  MIKMIDIDeviceManager.h
//  MIDI Testbed
//
//  Created by Andrew Madsen on 3/7/13.
//  Copyright (c) 2013 Mixed In Key. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "MIKMIDIInputPort.h"
#import "MIKMIDICompilerCompatibility.h"

@class MIKMIDIDevice;
@class MIKMIDISourceEndpoint;
@class MIKMIDIClientSourceEndpoint;
@class MIKMIDIDestinationEndpoint;
@class MIKMIDICommand;

NS_ASSUME_NONNULL_BEGIN

// Notifications
/**
 *  Posted whenever a device is added (connected) to the system.
 */
extern NSString * const MIKMIDIDeviceWasAddedNotification;

/**
 *  Posted whenever a device is removed (disconnected) from the system.
 */
extern NSString * const MIKMIDIDeviceWasRemovedNotification;

/**
 *  Posted whenever a virtual endpoint is added to the system.
 */
extern NSString * const MIKMIDIVirtualEndpointWasAddedNotification;

/**
 *  Posted whenever a virtual endpoint is removed from the system.
 */
extern NSString * const MIKMIDIVirtualEndpointWasRemovedNotification;

// Notification Keys
/**
 *  Key whose value is the device added or removed in MIKMIDIDeviceWasAdded/RemovedNotification's userInfo dictionary.
 */
extern NSString * const MIKMIDIDeviceKey;

/**
 *  Key whose value is the virtual endpoint added or removed in MIKMIDIVirtualEndpointWasAdded/RemovedNotification's userInfo dictionary.
 */
extern NSString * const MIKMIDIEndpointKey;

/**
 *  MIKMIDIDeviceManager is used to retrieve devices and virtual endpoints available on the system, 
 *  as well as for connecting to and disconnecting from MIDI endpoints. It is a singleton object.
 *
 *  To get a list of devices available on the system, call -availableDevices. Virtual sources can be
 *  retrieved by calling -virtualSources and -virtualDevices, respectively. All three of these properties,
 *  are KVO compliant, meaning they can be observed using KVO for changes, and (on OS X) can be bound to UI
 *  elements using Cocoa bindings.
 *
 *  MIKMIDIDeviceManager is also used to connect to and disonnect from MIDI endpoints, as well as to send and receive MIDI
 *  messages. To connect to a MIDI source endpoint, call -connectInput:error:eventHandler:. To disconnect, call -disconnectInput:.
 *  To send MIDI messages/commands to an output endpoint, call -sendCommands:toEndpoint:error:.
 */
@interface MIKMIDIDeviceManager : NSObject

/**
 *  Used to obtain the shared MIKMIDIDeviceManager instance.
 *  MIKMIDIDeviceManager should not be created directly using +alloc/-init or +new.
 *  Rather, the singleton shared instance should always be obtained by calling this method.
 *
 *  @return The shared MIKMIDIDeviceManager instance.
 */
+ (instancetype)sharedDeviceManager;

/**
 *  Used to connect to a MIDI device. Returns a token that must be kept and passed into the
 *  -disconnectConnectionforToken: method.
 *
 *  When a connection is made using this method, all of the devices valid source endpoints are connected to. To
 *  connect to specific endpoints only, use -connectInput:error:eventHandler:
 *
 *  @param device		An MIKMIDIDevice instance that should be connected.
 *  @param error		If an error occurs, upon returns contains an NSError object that describes the problem.
 *  If you are not interested in possible errors, you may pass in NULL.
 *  @param eventHandler A block which will be called anytime incoming MIDI messages are received from the device.
 *
 *  @return A connection token to be used to disconnect the input, or nil if an error occurred. The connection token is opaque.
 */
- (nullable id)connectDevice:(MIKMIDIDevice *)device error:(NSError **)error eventHandler:(MIKMIDIEventHandlerBlock)eventHandler;

/**
 *  Used to connect to a single MIDI input/source endpoint. Returns a token that must be kept and passed into the
 *  -disconnectConnectionforToken: method.
 *
 *  @param endpoint		An MIKMIDISourceEndpoint instance that should be connected.
 *  @param error		If an error occurs, upon returns contains an NSError object that describes the problem.
 *  If you are not interested in possible errors, you may pass in NULL.
 *  @param eventHandler A block which will be called anytime incoming MIDI messages are received from the endpoint.
 *
 *  @return A connection token to be used to disconnect the input, or nil if an error occurred. The connection token is opaque.
 */
- (nullable id)connectInput:(MIKMIDISourceEndpoint *)endpoint error:(NSError **)error eventHandler:(MIKMIDIEventHandlerBlock)eventHandler;

/**
 *  Disconnects a previously connected MIDI device or input/source endpoint. The connectionToken argument
 *  must be a token previously returned by -connectDevice:error:eventHandler: or -connectInput:error:eventHandler:.
 *  Only the event handler block passed into the call that returned the token will be disconnected.
 *
 *  @param connectionToken The connection token returned by -connectInput:error:eventHandler: when the input was connected.
 */
- (void)disconnectConnectionForToken:(id)connectionToken;

/**
 *  Used to send MIDI messages/commands from your application to a MIDI output endpoint. 
 *  Use this to send messages to a connected device, or another app connected via virtual MIDI port.
 *
 *  @param commands An NSArray containing MIKMIDICommand instances to be sent.
 *  @param endpoint An MIKMIDIDestinationEndpoint to which the commands should be sent.
 *  @param error    If an error occurs, upon returns contains an NSError object that describes the problem. If you are not interested in possible errors, you may pass in NULL.
 *
 *  @return YES if the commands were successfully sent, NO if an error occurred.
 */
- (BOOL)sendCommands:(MIKArrayOf(MIKMIDICommand *) *)commands toEndpoint:(MIKMIDIDestinationEndpoint *)endpoint error:(NSError **)error;


/**
 *  Used to send MIDI messages/commands from your application to a MIDI output endpoint.
 *  Use this to send messages to a virtual MIDI port created in the  your client using the MIKMIDIClientSourceEndpoint class.
 *
 *  @param commands An NSArray containing MIKMIDICommand instances to be sent.
 *  @param endpoint An MIKMIDIClientSourceEndpoint to which the commands should be sent.
 *  @param error    If an error occurs, upon returns contains an NSError object that describes the problem. If you are not interested in possible errors, you may pass in NULL.
 *
 *  @return YES if the commands were successfully sent, NO if an error occurred.
 */
- (BOOL)sendCommands:(MIKArrayOf(MIKMIDICommand *) *)commands toVirtualEndpoint:(MIKMIDIClientSourceEndpoint *)endpoint error:(NSError **)error;



/**
 *  An NSArray containing MIKMIDIDevice instances representing MIDI devices connected to the system.
 *
 *  This property is Key Value Observing (KVO) compliant, and can be observed
 *  to be notified when devices are connected or disconnected. It is also suitable
 *  for binding to UI using Cocoa Bindings (OS X only).
 *
 *  @see MIKMIDIDeviceWasAddedNotification
 *  @see MIKMIDIDeviceWasRemovedNotification
 */
@property (nonatomic, readonly) MIKArrayOf(MIKMIDIDevice *) *availableDevices;

/**
 *  An NSArray containing MIKMIDISourceEndpoint instances representing virtual MIDI sources (inputs) on the system.
 *
 *  This property is Key Value Observing (KVO) compliant, and can be observed
 *  to be notified when  virtual sources appear or disappear. It is also suitable
 *  for binding to UI using Cocoa Bindings (OS X only).
 *
 *  @see MIKMIDIVirtualEndpointWasAddedNotification
 *  @see MIKMIDIVirtualEndpointWasRemovedNotification
 */
@property (nonatomic, readonly) MIKArrayOf(MIKMIDISourceEndpoint *) *virtualSources;

/**
 *  An NSArray containing MIKMIDIDestinationEndpoint instances representing virtual
 *  MIDI destinations (outputs) on the system.
 *
 *  This property is Key Value Observing (KVO) compliant, and can be observed
 *  to be notified when virtual destinations appear or disappear. It is also suitable
 *  for binding to UI using Cocoa Bindings (OS X only).
 *
 *  @see MIKMIDIVirtualEndpointWasAddedNotification
 *  @see MIKMIDIVirtualEndpointWasRemovedNotification
 */
@property (nonatomic, readonly) MIKArrayOf(MIKMIDIDestinationEndpoint *) *virtualDestinations;

/**
 *  An NSArray of MIKMIDIDevice instances that are connected to at least one event handler.
 */
@property (nonatomic, readonly) MIKArrayOf(MIKMIDIDevice *) *connectedDevices;

/**
 *  An NSArray of MIKMIDISourceEndpoint instances that are connected to at least one event handler.
 */
@property (nonatomic, readonly) MIKArrayOf(MIKMIDISourceEndpoint *) *connectedInputSources;

@end

@interface MIKMIDIDeviceManager (Deprecated)

/**
 *  @deprecated Use disconnectConnectionforToken: instead. This method now simply calls through to that one.
 *
 *  Disconnects a previously connected MIDI input/source endpoint. The connectionToken argument
 *  must be a token previously returned by -connectInput:error:eventHandler:. Only the
 *  event handler block passed into the call that returned the token will be disconnected.
 *
 *  @param endpoint        This argument is ignored.
 *  @param connectionToken The connection token returned by -connectInput:error:eventHandler: when the input was connected.
 */
- (void)disconnectInput:(nullable MIKMIDISourceEndpoint *)endpoint forConnectionToken:(id)connectionToken DEPRECATED_ATTRIBUTE;

@end

NS_ASSUME_NONNULL_END