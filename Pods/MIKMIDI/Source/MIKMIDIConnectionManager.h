//
//  MIKMIDIConnectionManager.h
//  MIKMIDI
//
//  Created by Andrew Madsen on 11/5/15.
//  Copyright © 2015 Mixed In Key. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "MIKMIDICompilerCompatibility.h"
#import "MIKMIDISourceEndpoint.h"

@class MIKMIDIDevice;
@class MIKMIDINoteOnCommand;

@protocol MIKMIDIConnectionManagerDelegate;

NS_ASSUME_NONNULL_BEGIN

/**
 *  MIKMIDIConnectionManager can be used to manage a set of connected devices. It can be configured to automatically
 *  connect to devices as they are added, and disconnect from them as they are removed. It also supports saving
 *  the list of connected to NSUserDefaults and restoring them upon relaunch.
 *
 *  The use of MIKMIDIConnectionManager is optional. It is meant to be useful in implementing functionality that
 *  many MIDI device enabled apps need. However, simple connection to devices or MIDI endpoints can be done with
 *  MIKMIDIDeviceManager directly, if desired.
 */
@interface MIKMIDIConnectionManager : NSObject

/**
 *  This method will throw an exception if called. Use -initWithName:delegate:eventHandler: instead.
 *
 *  @return nil
 */
- (instancetype)init NS_UNAVAILABLE;

/**
 *  Initializes an instance of MIKMIDIConnectionManager. The passed in name is used to independently
 *  store and load the connection manager's configuration using NSUserDefaults. The passed in name
 *  should be unique across your application, and the same from launch to launch.
 *
 *  @param name			The name to give the connection manager. Must not be nil or empty.
 *	@param delegate		The delegate of the connection manager
 *  @param eventHandler An MIKMIDIEventHandlerBlock to be called with incoming MIDI messages from any connected device.
 *
 *  @return An initialized MIKMIDIConnectionManager instance.
 */
- (instancetype)initWithName:(NSString *)name
					delegate:(nullable id<MIKMIDIConnectionManagerDelegate>)delegate
				eventHandler:(nullable MIKMIDIEventHandlerBlock)eventHandler NS_DESIGNATED_INITIALIZER;

/**
 *  Initializes an instance of MIKMIDIConnectionManager. The passed in name is used to independently
 *  store and load the connection manager's configuration using NSUserDefaults. The passed in name
 *  should be unique across your application, and the same from launch to launch. This is the same
 *  as calling -initWithName:delegate:eventHandler: with a nil delegate and eventHandler.
 *
 *  @param name			The name to give the connection manager. Must not be nil or empty.
 *
 *  @return An initialized MIKMIDIConnectionManager instance.
 */
- (instancetype)initWithName:(NSString *)name;

/**
 *  Connect to the specified device. When MIDI messages are received, the connection manager's event handler
 *  block will be executed.
 *
 *  @param device	An MIKMIDIDevice instance.
 *  @param error	If an error occurs, upon returns contains an NSError object that describes the problem.
 *  If you are not interested in possible errors, you may pass in NULL.
 *
 *  @return YES if the connection was successful, NO if an error occurred.
 */
- (BOOL)connectToDevice:(MIKMIDIDevice *)device error:(NSError **)error;

/**
 *  Disconnect from a connected device. No further messages from the specified device will be processed.
 *
 *  Note that you don't need to call this method when a previously-connected device was removed from the system.
 *  Disconnection in that situation is handled automatically.
 *
 *  @param device An MIKMIDIDevice instance.
 */
- (void)disconnectFromDevice:(MIKMIDIDevice *)device;

/**
 *  This method can be used to determine if the receiver is connected to a given MIDI device.
 *
 *  @param device An MIKMIDIDevice instance.
 *
 *  @return YES if the receiver is connected to and processing MIDI input from the device, NO otherwise.
 */
- (BOOL)isConnectedToDevice:(MIKMIDIDevice *)device;

/**
 *  If YES (the default), the connection manager will automatically save its configuration at appropriate
 *  times. If this property is NO, -saveConfiguration can still be used to manually trigger saving the
 *  receiver's configuration. Note that -loadConfiguration must always be called manually, e.g. at launch.
 */
@property (nonatomic) BOOL automaticallySavesConfiguration;

/**
 *  Save the receiver's list of connected devices to disk for later restoration.
 */
- (void)saveConfiguration;

/**
 *  Load and reconnect to the devices previously saved to disk by a call to -saveConfiguration. For
 *  this to work, the receiver's name must be the same as it was upon the previous call to -saveConfiguration.
 *
 *  @note: This method will only connect to new devices. It will not disconnect from devices not found in the
 *  saved configuration.
 */
- (void)loadConfiguration;

/**
 *  The name of the receiver. Used for configuration save/load.
 */
@property (nonatomic, copy, readonly) NSString *name;

/**
 *  An MIKMIDIEventHandlerBlock to be called with incoming MIDI messages from any connected device.
 *
 *  If you need to determine which device sent the passed in messages, call source.entity.device on the
 *  passed in MIKMIDISourceEndpoint argument.
 */
@property (nonatomic, copy, null_resettable) MIKMIDIEventHandlerBlock eventHandler;

/**
 *  A delegate, used to customize MIKMIDIConnectionManager behavior.
 */
@property (nonatomic, weak, nullable) id<MIKMIDIConnectionManagerDelegate>delegate;

/**
 *  Controls whether the receiver's availableDevices property includes virtual devices (i.e. devices made
 *  up of automatically paired virtual sources and destinations).
 *
 *  If this property is YES (the default), the connection manager will attempt to automtically related
 *  associated virtual sources and destinations and create "virtual" MIKMIDIDevice instances for them.
 *
 *  If this property is NO, the connection manager's availableDevices array will _only_ contain non-virtual
 *  MIKMIDIDevices.
 *
 *  For most applications, this should be left at the default YES, as even many physical MIDI devices present as
 *  "virtual" devices in software.
 *
 *  @note: The caveat here is that this relies on some heuristics to match up source endpoints with destination endpoints.
 *  These heuristics are based on the way certain common MIDI devices behave, but may not be universal, and therefore
 *  may miss, or fail to properly associate endpoints for some devices. If this is a problem for your application,
 *  you should obtain and connect to virtual sources/endpoints using MIKMIDIDeviceManager directly instead.
 */
@property (nonatomic) BOOL includesVirtualDevices; // Default is YES

/**
 *  An array of available MIDI devices.
 *
 *  This property is observable using Key Value Observing.
 */
@property (nonatomic, strong, readonly) MIKArrayOf(MIKMIDIDevice *) *availableDevices;

/**
 *  The set of MIDI devices to which the receiver is connected.
 *
 *  This property is observable using Key Value Observing.
 */
@property (nonatomic, strong, readonly) MIKSetOf(MIKMIDIDevice *) *connectedDevices;

@end


/**
 *  Specifies behavior for connecting to a newly connected device. See
 *  -connectionManager:shouldConnectToNewlyAddedDevice:
 */
typedef NS_ENUM(NSInteger, MIKMIDIAutoConnectBehavior) {
	
	/** Do not connect to the newly added device */
	MIKMIDIAutoConnectBehaviorDoNotConnect,
	
	/** Connect to the newly added device */
	MIKMIDIAutoConnectBehaviorConnect,
	
	/** Connect to the newly added device only if it was previously connected (ie. in the saved configuration data) */
	MIKMIDIAutoConnectBehaviorConnectOnlyIfPreviouslyConnected,
	
	/** Connect to the newly added device if it was previously connected, or is unknown in the configuration data.*/
	MIKMIDIAutoConnectBehaviorConnectIfPreviouslyConnectedOrNew,
};

/**
 *  Protocol containing method(s) to be implemented by delegates of MIKMIDIConnectionManager.
 */
@protocol MIKMIDIConnectionManagerDelegate <NSObject>

@optional

/**
 *  A connection manager's delegate can implement this method to determine whether or not to automatically connect
 *  to a newly added MIDI device. See MIKMIDIAutoConnectBehavior for possible return values.
 *
 *	If this method is not implemented, the default behavior is MIKMIDIAutoConnectBehaviorConnectIfPreviouslyConnectedOrNew.
 *
 *  @param manager An instance of MIKMIDIConnectionManager.
 *  @param device  The newly added MIDI device.
 *
 *  @return One of the values defined in MIKMIDIAutoConnectBehavior.
 */
- (MIKMIDIAutoConnectBehavior)connectionManager:(MIKMIDIConnectionManager *)manager shouldConnectToNewlyAddedDevice:(MIKMIDIDevice *)device;

/**
 *  A connection manager's delegate can implement this method to be notified when a connected device is disconnected,
 *  either because -disconnectFromDevice: was called, or because the device was unplugged.
 *
 *	If a MIDI device is disconnected between sending a note on message and sending the corresponding note off command,
 *  this can cause a "stuck note" because the note off command will now never be delivered. e.g. a MIDI piano keyboard
 *  that is disconnected with a key held down. This method includes an array of these unterminated note on commands (if any)
 *  so that the receiver can appropriately deal with this situation. For example, corresponding note off commands could
 *  be generated and sent through whatever processing chain is processing incoming MIDI commands to terminate stuck notes.
 *
 *  @param manager  An instance of MIKMIDIConnectionManager.
 *  @param device   The MIKMIDIDevice that was disconnected.
 *  @param commands An array of note on messages for which corresponding note off messages have not yet been received.
 */
- (void)connectionManager:(MIKMIDIConnectionManager *)manager deviceWasDisconnected:(MIKMIDIDevice *)device withUnterminatedNoteOnCommands:(MIKArrayOf(MIKMIDINoteOnCommand *) *)commands;

@end

NS_ASSUME_NONNULL_END

