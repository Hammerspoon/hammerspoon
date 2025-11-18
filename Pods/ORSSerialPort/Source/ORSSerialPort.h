//
//  ORSSerialPort.h
//  ORSSerialPort
//
//  Created by Andrew R. Madsen on 08/6/11.
//	Copyright (c) 2011-2014 Andrew R. Madsen (andrew@openreelsoftware.com)
//	
//	Permission is hereby granted, free of charge, to any person obtaining a
//	copy of this software and associated documentation files (the
//	"Software"), to deal in the Software without restriction, including
//	without limitation the rights to use, copy, modify, merge, publish,
//	distribute, sublicense, and/or sell copies of the Software, and to
//	permit persons to whom the Software is furnished to do so, subject to
//	the following conditions:
//	
//	The above copyright notice and this permission notice shall be included
//	in all copies or substantial portions of the Software.
//	
//	THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS
//	OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF
//	MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT.
//	IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY
//	CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT,
//	TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION WITH THE
//	SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.

#import <Foundation/Foundation.h>
#import <IOKit/IOTypes.h>
#import <termios.h>

// Keep older versions of the compiler happy
#ifndef NS_ASSUME_NONNULL_BEGIN
#define NS_ASSUME_NONNULL_BEGIN
#define NS_ASSUME_NONNULL_END
#define nullable
#define nonnullable
#define __nullable
#endif

#ifndef NS_DESIGNATED_INITIALIZER
#define NS_DESIGNATED_INITIALIZER
#endif

#ifndef ORSArrayOf
	#if __has_feature(objc_generics)
		#define ORSArrayOf(TYPE) NSArray<TYPE>
	#else
		#define ORSArrayOf(TYPE) NSArray
	#endif
#endif // #ifndef ORSArrayOf

//#define LOG_SERIAL_PORT_ERRORS
typedef NS_ENUM(NSUInteger, ORSSerialPortParity) {
	ORSSerialPortParityNone = 0,
	ORSSerialPortParityOdd,
	ORSSerialPortParityEven
};

@protocol ORSSerialPortDelegate;

@class ORSSerialRequest;
@class ORSSerialPacketDescriptor;

NS_ASSUME_NONNULL_BEGIN

/**
 *  The ORSSerialPort class represents a serial port, and includes methods to
 *  configure, open and close a port, and send and receive data to and from
 *  a port.
 *
 *  There is a 1:1 correspondence between port devices on the
 *  system and instances of `ORSSerialPort`. That means that repeated requests
 *  for a port object for a given device or device path will return the same 
 *  instance of `ORSSerialPort`.
 *
 *  Opening a Port and Setting It Up
 *  --------------------------------
 *
 *  You can get an `ORSSerialPort` instance either of two ways. The easiest
 *  is to use `ORSSerialPortManager`'s `availablePorts` array. The other way
 *  is to get a new `ORSSerialPort` instance using the serial port's BSD device path:
 *
 *  	ORSSerialPort *port = [ORSSerialPort serialPortWithPath:@"/dev/cu.KeySerial1"];
 *
 *  Note that you must give `+serialPortWithPath:` the full path to the
 *  device, as shown in the example above.
 *
 *
 *  After you've got a port instance, you can open it with the `-open`
 *  method. When you're done using the port, close it using the `-close`
 *  method.
 *
 *  Port settings such as baud rate, number of stop bits, parity, and flow
 *  control settings can be set using the various properties `ORSSerialPort`
 *  provides. Note that all of these properties are Key Value Observing
 *  (KVO) compliant. This KVO compliance also applies to read-only
 *  properties for reading the state of the CTS, DSR and DCD pins. Among
 *  other things, this means it's easy to be notified when the state of one
 *  of these pins changes, without having to continually poll them, as well
 *  as making them easy to connect to a UI with Cocoa bindings.
 *
 *  Sending Data
 *  ------------
 *
 *  Send data by passing an `NSData` object to the `-sendData:` method:
 *
 *  	NSData *dataToSend = [self.sendTextField.stringValue dataUsingEncoding:NSUTF8StringEncoding];
 *  	[self.serialPort sendData:dataToSend];
 *
 *  Receiving Data
 *  --------------
 *
 *  To receive data, you must implement the `ORSSerialPortDelegate`
 *  protocol's `-serialPort:didReceiveData:` method, and set the
 *  `ORSSerialPort` instance's delegate property. As noted in the documentation
 *  for ORSSerialPortDelegate, this method is always called on the main queue.
 *  An example implementation is included below:
 *
 *  	- (void)serialPort:(ORSSerialPort *)serialPort didReceiveData:(NSData *)data
 *  	{
 *  		NSString *string = [[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding];
 *  		[self.receivedDataTextView.textStorage.mutableString appendString:string];
 *  		[self.receivedDataTextView setNeedsDisplay:YES];
 *  	}
 */
@interface ORSSerialPort : NSObject

/** ---------------------------------------------------------------------------------------
 * @name Getting a Serial Port
 *  ---------------------------------------------------------------------------------------
 */

/**
 *  Returns an `ORSSerialPort` instance representing the serial port at `devicePath`.
 *
 *  `devicePath` must be the full, callout (cu.) or tty (tty.) path to an available
 *  serial port device on the system.
 *
 *  @param devicePath The full path (e.g. /dev/cu.usbserial) to the device.
 *
 *  @return An initalized `ORSSerialPort` instance, or nil if there was an error.
 * 
 *  @see -[ORSSerialPortManager availablePorts]
 *  @see -initWithPath:
 */
+ (nullable ORSSerialPort *)serialPortWithPath:(NSString *)devicePath;

/**
 *  Returns an `ORSSerialPort` instance for the serial port represented by `device`.
 *
 *  Generally, `+serialPortWithPath:` is the method to use to get port instances
 *  programatically. This method may be useful if you're doing your own
 *  device discovery with IOKit functions, or otherwise have an IOKit port object
 *  you want to "turn into" an ORSSerialPort. Most people will not use this method
 *  directly.
 *
 *  @param device An IOKit port object representing the serial port device.
 *
 *  @return An initalized `ORSSerialPort` instance, or nil if there was an error.
 *
 *  @see -[ORSSerialPortManager availablePorts]
 *  @see +serialPortWithPath:
 */
+ (nullable ORSSerialPort *)serialPortWithDevice:(io_object_t)device;

/**
 *  Returns an `ORSSerialPort` instance representing the serial port at `devicePath`.
 *
 *  `devicePath` must be the full, callout (cu.) or tty (tty.) path to an available
 *  serial port device on the system.
 *
 *  @param devicePath The full path (e.g. /dev/cu.usbserial) to the device.
 *
 *  @return An initalized `ORSSerialPort` instance, or nil if there was an error.
 *
 *  @see -[ORSSerialPortManager availablePorts]
 *  @see +serialPortWithPath:
 */
- (nullable instancetype)initWithPath:(NSString *)devicePath;

/**
 *  Returns an `ORSSerialPort` instance for the serial port represented by `device`.
 *
 *  Generally, `-initWithPath:` is the method to use to get port instances
 *  programatically. This method may be useful if you're doing your own
 *  device discovery with IOKit functions, or otherwise have an IOKit port object
 *  you want to "turn into" an ORSSerialPort. Most people will not use this method
 *  directly.
 *
 *  @param device An IOKit port object representing the serial port device.
 *
 *  @return An initalized `ORSSerialPort` instance, or nil if there was an error.
 *
 *  @see -[ORSSerialPortManager availablePorts]
 *  @see -initWithPath:
 */
- (nullable instancetype)initWithDevice:(io_object_t)device;

/** ---------------------------------------------------------------------------------------
 * @name Opening and Closing
 *  ---------------------------------------------------------------------------------------
 */

/**
 *  Opens the port represented by the receiver.
 *
 *  If this method succeeds, the ORSSerialPortDelegate method `-serialPortWasOpened:` will
 *  be called.
 *
 *  If opening the port fails, the ORSSerialPortDelegate method `-serialPort:didEncounterError:` will
 *  be called.
 */
- (void)open;

/**
 *  Closes the port represented by the receiver.
 *
 *  If the port is closed successfully, the ORSSerialPortDelegate method `-serialPortWasClosed:` will
 *  be called before this method returns.
 *
 *  @return YES if closing the port was closed successfully, NO if closing the port failed.
 */
- (BOOL)close;

- (void)cleanup DEPRECATED_ATTRIBUTE; // Should never have been called in client code, anyway.

/**
 *  Closes the port and cleans up.
 *
 *  This method should never be called directly. Call `-close` to close a port instead.
 */
- (void)cleanupAfterSystemRemoval;

/** ---------------------------------------------------------------------------------------
 * @name Sending Data
 *  ---------------------------------------------------------------------------------------
 */

/**
 *  Sends data out through the serial port represented by the receiver.
 *
 *  This method attempts to send all data synchronously. That is, the method
 *  will not return until all passed in data has been sent, or an error has occurred.
 *
 *  If an error occurs, the ORSSerialPortDelegate method `-serialPort:didEncounterError:` will
 *  be called. The exception to this is if sending data fails because the port
 *  is closed. In that case, this method returns NO, but `-serialPort:didEncounterError:`
 *  is *not* called. You can ensure that the port is open by calling `-isOpen` before 
 *  calling this method.
 *
 *  @note This method can take a long time to return when a very large amount of data
 *  is passed in, due to the relatively slow nature of serial communication. It is better
 *  to send data in discrete short packets if possible.
 *
 *  @param data An `NSData` object containing the data to be sent.
 *
 *  @return YES if sending data succeeded, NO if an error occurred.
 */
- (BOOL)sendData:(NSData *)data;

/**
 *  Sends the data in request, and begins watching for a valid response to the request,
 *  to be delivered to the delegate.
 *
 *  If the receiver already has one or more pending requests, the request is queued to be
 *  sent after all previous requests have received valid responses or have timed out
 *  and this method will return YES. If there are no pending requests, the request
 *  is sent immediately and NO is returned if an error occurs.
 *
 *  @note This method calls through to -sendData:, and the same caveat
 *  about it taking a long time to send very large requests applies.
 *
 *  @param request An ORSSerialRequest instance including the data to be sent.
 *
 *  @return YES if sending the request's data succeeded, NO if an error occurred.
 */
- (BOOL)sendRequest:(ORSSerialRequest *)request;

/**
 *  Requests the cancellation of a queued (not yet sent) request. The request
 *  is removed from the requests queue and will not be sent.
 *
 *  Note that a pending request cannot be cancelled, as it has already been sent and is
 *  awaiting a response. If a pending request is passed in, this method will simply
 *  do nothing. Because the requests queue is handled in the background, occasionally
 *  a request may leave the queue and becoming pending after this method is called, 
 *  causing cancellation to fail. If you need to absolutely guarantee that a request
 *  is not sent you should avoid sending it rather than depending on later cancellation.
 *
 *  @param request The pending request to be cancelled.
 */
- (void)cancelQueuedRequest:(ORSSerialRequest *)request;

/**
 *  Cancels all queued requests. The requests queue is emptied.
 *
 *  Note that if there is a pending request, it is not cancelled, as it has already
 *  been sent and is awaiting a response.
 */
- (void)cancelAllQueuedRequests;

/** ---------------------------------------------------------------------------------------
 * @name Listening For Packets
 *  ---------------------------------------------------------------------------------------
 */

/**
 *  Tells the receiver to begin listening for incoming packets matching the specified
 *  descriptor.
 *
 *  When incoming data that constitutes a packet as described by descriptor is received,
 *  the delegate method -serialPort:didReceivePacket:matchingDescriptor: will be called.
 *
 *  @param descriptor An ORSerialPacketDescriptor instance describing the packets the receiver
 *  should listen for.
 *
 *  @see -stopListeningForPacketsMatchingDescriptor:
 *  @see -serialPort:didReceivePacket:matchingDescriptor:
 */
- (void)startListeningForPacketsMatchingDescriptor:(ORSSerialPacketDescriptor *)descriptor;

/**
 *  Tells the receiver to stop listening for incoming packets matching the specified
 *  descriptor. 
 *
 *  @note The passed in descriptor must be the exact same instance as was previously
 *  provided to -startListeningForPacketsMatchingDescriptor:
 *
 *  @param descriptor An ORSSerialPacketDescriptor instance previously passed to
 *  -startListeningForPacketsMatchingDescriptor:
 *
 *  @see -startListeningForPacketsMatchingDescriptor:
 */
- (void)stopListeningForPacketsMatchingDescriptor:(ORSSerialPacketDescriptor *)descriptor;

/** ---------------------------------------------------------------------------------------
 * @name Delegate
 *  ---------------------------------------------------------------------------------------
 */

/**
 *  The delegate for the serial port object. Must implement the `ORSSerialPortDelegate` protocol.
 *
 */
#if MAC_OS_X_VERSION_MIN_REQUIRED >= MAC_OS_X_VERSION_10_8
@property (nonatomic, weak, nullable) id<ORSSerialPortDelegate> delegate;
#else
@property (nonatomic, unsafe_unretained, nullable) id<ORSSerialPortDelegate> delegate;
#endif

/** ---------------------------------------------------------------------------------------
 * @name Request/Response Properties
 *  ---------------------------------------------------------------------------------------
 */

/**
 *  The previously-sent request for which the port is awaiting a response, or nil
 *  if there is no pending request.
 *
 *	This property can be observed using Key Value Observing.
 */
@property (strong, readonly, nullable) ORSSerialRequest *pendingRequest;

/**
 *  Requests in the queue waiting to be sent, or an empty array if there are no queued requests.
 *  Requests are sent from the queue in FIFO order. That is, the first request in the array
 *  returned by this property is the next request to be sent.
 *
 *	This property can be observed using Key Value Observing.
 *
 *  @note This array does not contain the pending request, a sent request for which
 *  the port is awaiting a response.
 */
@property (strong, readonly) ORSArrayOf(ORSSerialRequest *) *queuedRequests;

/** ---------------------------------------------------------------------------------------
 * @name Packet Parsing Properties
 *  ---------------------------------------------------------------------------------------
 */

/**
 *  An array of packet descriptors for which the port is listening. 
 *
 *  Returns an empty array if no packet descriptors are installed.
 */
@property (nonatomic, strong, readonly) ORSArrayOf(ORSSerialPacketDescriptor *) *packetDescriptors;

/** ---------------------------------------------------------------------------------------
 * @name Port Properties
 *  ---------------------------------------------------------------------------------------
 */

/**
 *  A Boolean value that indicates whether the port is open. (read-only)
 */
@property (readonly, getter = isOpen) BOOL open;

/**
 *  An string representation of the device path for the serial port represented by the receiver. (read-only)
 */
@property (copy, readonly) NSString *path;

/**
 *  The IOKit port object for the serial port device represented by the receiver. (read-only)
 */
@property (readonly) io_object_t IOKitDevice;

/**
 *  The name of the serial port. 
 *  
 *  Can be presented to the user, e.g. in a serial port selection pop up menu.
 */
@property (copy, readonly) NSString *name;

/** ---------------------------------------------------------------------------------------
 * @name Configuring the Serial Port
 *  ---------------------------------------------------------------------------------------
 */

/**
 *  The baud rate for the port.
 *
 *  Unless supportsNonStandardBaudRates is YES, 
 *  this value should be one of the values defined in termios.h:
 *
 *	- 0
 *	- 50
 *	- 75
 *	- 110
 *	- 134
 *	- 150
 *	- 200
 *	- 300
 *	- 600
 *	- 1200
 *	- 1800
 *	- 2400
 *	- 4800
 *	- 9600
 *	- 19200
 *	- 38400
 *	- 7200
 *	- 14400
 *	- 28800
 *	- 57600
 *	- 76800
 *	- 115200
 *	- 230400
 */
@property (nonatomic, copy) NSNumber *baudRate;

/**
 *  Whether or not the port allows setting non-standard baud rates.
 *  Set this property to YES to allow setting non-standard baud rates
 *  for the port. The default is NO.
 *
 *  @note Support for non-standard baud rates
 *  depends on the serial hardware and driver being used. Even
 *  for hardware/drivers that support non-standard baud rates,
 *  it may be that not all baud rates are supported.
 *  ORSSerialPort may *not* report an error when setting
 *  a non-standard baud rate, nor will the baudRate getter return
 *  the actual baud rate when non-standard baud rates are
 *  used. This option should only be used when necessary,
 *  and should be used with caution.
 */
@property (nonatomic) BOOL allowsNonStandardBaudRates;

/**
 *  The number of stop bits. Values other than 1 or 2 are invalid.
 */
@property (nonatomic) NSUInteger numberOfStopBits;

/**
 *  The number of data bits. Values other than 5, 6, 7, or 8 are ignored.
 */
@property (nonatomic) NSUInteger numberOfDataBits;

/**
 *
 */
@property (nonatomic) BOOL shouldEchoReceivedData;

/**
 *  The parity setting for the port. Possible values are:
 *  
 *  - ORSSerialPortParityNone
 *  - ORSSerialPortParityOdd
 *  - ORSSerialPortParityEven
 */
@property (nonatomic) ORSSerialPortParity parity;

/**
 *  A Boolean value indicating whether the serial port uses RTS/CTS Flow Control.
 */
@property (nonatomic) BOOL usesRTSCTSFlowControl;

/**
 *  A Boolean value indicating whether the serial port uses DTR/DSR Flow Control.
 */
@property (nonatomic) BOOL usesDTRDSRFlowControl;

/**
 *  A Boolean value indicating whether the serial port uses DCD Flow Control.
 */
@property (nonatomic) BOOL usesDCDOutputFlowControl;

/** ---------------------------------------------------------------------------------------
 * @name Other Port Pins
 *  ---------------------------------------------------------------------------------------
 */

/**
 *  The state of the serial port's RTS pin.
 *
 *  - YES means 1 or high state.
 *  - NO means 0 or low state.
 *
 *  This property is observable using Key Value Observing.
 */
@property (nonatomic) BOOL RTS;

/**
 *  The state of the serial port's DTR pin.
 *
 *  - YES means 1 or high state.
 *  - NO means 0 or low state.
 *
 *  This property is observable using Key Value Observing.
 */
@property (nonatomic) BOOL DTR;

/**
 *  The state of the serial port's CTS pin.
 *
 *  - YES means 1 or high state.
 *  - NO means 0 or low state.
 *
 *  This property is observable using Key Value Observing.
 */
@property (nonatomic, readonly) BOOL CTS;

/**
 *  The state of the serial port's DSR pin. (read-only)
 *
 *  - YES means 1 or high state.
 *  - NO means 0 or low state.
 *
 *  This property is observable using Key Value Observing.
 */
@property (nonatomic, readonly) BOOL DSR;

/**
 *  The state of the serial port's DCD pin. (read-only)
 *
 *  - YES means 1 or high state.
 *  - NO means 0 or low state.
 *
 *  This property is observable using Key Value Observing.
 */
@property (nonatomic, readonly) BOOL DCD;

@end

NS_ASSUME_NONNULL_END

/**
 *  The ORSSerialPortDelegate protocol defines methods to be implemented
 *  by the delegate of an `ORSSerialPort` object.
 *
 *  *Note*: All `ORSSerialPortDelegate` methods are always called on the main queue.
 *  If you need to handle them on a background queue, you must dispatch your handling
 *  to a background queue in your implementation of the delegate method.
 */

NS_ASSUME_NONNULL_BEGIN

@protocol ORSSerialPortDelegate <NSObject>

@required

/**
 *  Called when a serial port is removed from the system, e.g. the user unplugs
 *  the USB to serial adapter for the port.
 *
 *	In this method, you should discard any strong references you have maintained for the
 *  passed in `serialPort` object. The behavior of `ORSSerialPort` instances whose underlying
 *  serial port has been removed from the system is undefined.
 *
 *  @param serialPort The `ORSSerialPort` instance representing the port that was removed.
 */
- (void)serialPortWasRemovedFromSystem:(ORSSerialPort *)serialPort NS_SWIFT_NAME(serialPortWasRemovedFromSystem(_:));

@optional

/**
 *  Called any time new data is received by the serial port from an external source.
 *
 *  @param serialPort The `ORSSerialPort` instance representing the port that received `data`.
 *  @param data       An `NSData` instance containing the data received.
 */
- (void)serialPort:(ORSSerialPort *)serialPort didReceiveData:(NSData *)data;

/**
 *  Called when a valid, complete packet matching a descriptor installed with 
 *  -startListeningForPacketsMatchingDescriptor: is received.
 *
 *  @param serialPort		The `ORSSerialPort` instance representing the port that received `packetData`.
 *  @param packetData		The An `NSData` instance containing the received packet data.
 *  @param descriptor		The packet descriptor object for which packetData is a match.
 */
- (void)serialPort:(ORSSerialPort *)serialPort didReceivePacket:(NSData *)packetData matchingDescriptor:(ORSSerialPacketDescriptor *)descriptor;

/**
 *  Called when a valid, complete response is received for a previously sent request.
 *
 *  @param serialPort   The `ORSSerialPort` instance representing the port that received `responseData`.
 *  @param responseData The An `NSData` instance containing the received response data.
 *  @param request      The request to which the responseData is a respone.
 */
- (void)serialPort:(ORSSerialPort *)serialPort didReceiveResponse:(NSData *)responseData toRequest:(ORSSerialRequest *)request;

/**
 *  Called when a the timeout interval for a previously sent request elapses without a valid
 *  response having been received.
 *
 *  The request can be re-sent by simply calling -sendRequest: again.
 *
 *  @param serialPort The `ORSSerialPort` instance representing the port through which the request was sent.
 *  @param request    The request for which a response has not been received.
 */
- (void)serialPort:(ORSSerialPort *)serialPort requestDidTimeout:(ORSSerialRequest *)request;

/**
 *  Called when an error occurs during an operation involving a serial port.
 *
 *	This method is always used to report errors. No `ORSSerialPort` methods
 *  take a passed in `NSError **` reference because errors may occur asynchonously,
 *  after a method has returned.
 *
 *	Currently, errors reported using this method are always in the `NSPOSIXErrorDomain`,
 *  and a list of error codes can be found in the system header errno.h.
 *
 *  The error object's userInfo dictionary contains the following keys:
 *
 *	- NSLocalizedDescriptionKey - An error message string.
 *	- NSFilePathErrorKey - The device path to the serial port. Same as `[serialPort path]`.
 *
 *  @param serialPort The `ORSSerialPort` instance for the port
 *  @param error      An `NSError` object containing information about the error.
 */
- (void)serialPort:(ORSSerialPort *)serialPort didEncounterError:(NSError *)error;

/**
 *  Called when a serial port is successfully opened.
 *
 *  @param serialPort The `ORSSerialPort` instance representing the port that was opened.
 */
- (void)serialPortWasOpened:(ORSSerialPort *)serialPort;

/**
 *  Called when a serial port was closed (e.g. because `-close`) was called.
 *
 *  When an ORSSerialPort instance is closed, its queued requests are cancelled, and
 *  its pending request is discarded. This is done _after_ the call to `-serialPortWasClosed:`.
 *  If upon later reopening you may need to resend those requests, you 
 *  should retrieve and store them in your implementation of this method.
 *
 *  @param serialPort The `ORSSerialPort` instance representing the port that was closed.
 */
- (void)serialPortWasClosed:(ORSSerialPort *)serialPort;

@end

NS_ASSUME_NONNULL_END
