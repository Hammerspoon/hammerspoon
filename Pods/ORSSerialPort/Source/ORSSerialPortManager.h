//
//  ORSSerialPortManager.h
//  ORSSerialPort
//
//  Created by Andrew R. Madsen on 08/7/11.
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

NS_ASSUME_NONNULL_BEGIN

/// Posted when a serial port is connected to the system
extern NSString * const ORSSerialPortsWereConnectedNotification;

/// Posted when a serial port is disconnected from the system
extern NSString * const ORSSerialPortsWereDisconnectedNotification;

/// Key for connected port in ORSSerialPortWasConnectedNotification userInfo dictionary
extern NSString * const ORSConnectedSerialPortsKey;
/// Key for disconnected port in ORSSerialPortWasDisconnectedNotification userInfo dictionary
extern NSString * const ORSDisconnectedSerialPortsKey;

@class ORSSerialPort;

/**
 *  `ORSSerialPortManager` is a singleton class (one instance per
 *  application) that can be used to get a list of available serial ports.
 *  It will also handle closing open serial ports when the Mac goes to
 *  sleep, and reopening them automatically on wake. This prevents problems
 *  I've seen with serial port drivers that can hang if the port is left
 *  open when putting the machine to sleep. Note that using
 *  `ORSSerialPortManager` is optional. It provides some nice functionality,
 *  but only `ORSSerialPort` is necessary to simply send and received data.
 *
 *  Using ORSSerialPortManager
 *  --------------------------
 *
 *  To get the shared serial port
 *  manager:
 *
 *      ORSSerialPortManager *portManager = [ORSSerialPortManager sharedSerialPortManager];
 *
 *  To get a list of available ports:
 *
 *      NSArray *availablePorts = portManager.availablePorts;
 *
 *  Notifications
 *  -------------
 *
 *  `ORSSerialPort` posts notifications when a port is added to or removed from the system.
 *  `ORSSerialPortsWereConnectedNotification` is posted when one or more ports
 *  are added to the system. `ORSSerialPortsWereDisconnectedNotification` is posted when
 *  one ore more ports are removed from the system. The user info dictionary for each
 *  notification contains the list of ports added or removed. The keys to access these array
 *  are `ORSConnectedSerialPortsKey`, and `ORSDisconnectedSerialPortsKey` respectively.
 *
 *  KVO Compliance
 *  --------------
 *
 *  `ORSSerialPortManager` is Key-Value Observing (KVO) compliant for its
 *  `availablePorts` property. This means that you can observe
 *  `availablePorts` to be notified when ports are added to or removed from
 *  the system. This also means that you can easily bind UI elements to the
 *  serial port manager's `availablePorts` property using Cocoa-bindings.
 *  This makes it easy to create a popup menu that displays available serial
 *  ports and updates automatically, for example.
 *
 *  Close-On-Sleep
 *  --------------
 *
 *  `ORSSerialPortManager`'s close-on-sleep, reopen-on-wake functionality is
 *  automatic. The only thing necessary to enable it is to make sure that
 *  the singleton instance of `ORSSerialPortManager` has been created by
 *  calling `+sharedSerialPortManager` at least once. Note that this
 *  behavior is only available in Cocoa apps, and is disabled when
 *  ORSSerialPort is used in a command-line only app.
 */
@interface ORSSerialPortManager : NSObject

/**
 *  Returns the shared (singleton) serial port manager object.
 *
 *  @return The shared serial port manager.
 */
+ (ORSSerialPortManager *)sharedSerialPortManager;

/**
 *  An array containing ORSSerialPort instances representing the
 *  serial ports available on the system. (read-only)
 *  
 *  As explained above, this property is Key Value Observing
 *  compliant, and can be bound to for example an NSPopUpMenu
 *  to easily give the user a way to select an available port 
 *  on the system.
 */
@property (nonatomic, copy, readonly) ORSArrayOf(ORSSerialPort *) *availablePorts;

@end

NS_ASSUME_NONNULL_END