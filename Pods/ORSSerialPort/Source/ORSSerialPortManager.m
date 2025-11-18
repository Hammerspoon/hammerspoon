//
//  ORSSerialPortManager.m
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

#if !__has_feature(objc_arc)
#error ORSSerialPortManager.m must be compiled with ARC. Either turn on ARC for the project or set the -fobjc-arc flag for ORSSerialPortManager.m in the Build Phases for this target
#endif

#import "ORSSerialPortManager.h"
#import "ORSSerialPort.h"

#ifdef ORSSERIAL_FRAMEWORK
// To enable sleep/wake notifications, etc.
#import <Cocoa/Cocoa.h>
#endif

#import <IOKit/IOKitLib.h>
#import <IOKit/serial/IOSerialKeys.h>

#ifdef LOG_SERIAL_PORT_ERRORS
#define LOG_SERIAL_PORT_ERROR(fmt, ...) NSLog(fmt, ##__VA_ARGS__)
#else
#define LOG_SERIAL_PORT_ERROR(fmt, ...)
#endif

NSString * const ORSSerialPortsWereConnectedNotification = @"ORSSerialPortWasConnectedNotification";
NSString * const ORSSerialPortsWereDisconnectedNotification = @"ORSSerialPortWasDisconnectedNotification";

NSString * const ORSConnectedSerialPortsKey = @"ORSConnectedSerialPortsKey";
NSString * const ORSDisconnectedSerialPortsKey = @"ORSDisconnectedSerialPortsKey";

void ORSSerialPortManagerPortsPublishedNotificationCallback(void *refCon, io_iterator_t iterator);
void ORSSerialPortManagerPortsTerminatedNotificationCallback(void *refCon, io_iterator_t iterator);

@interface ORSSerialPortManager ()

@property (nonatomic, copy, readwrite) NSArray *availablePorts;
@property (nonatomic, strong) NSMutableArray *portsToReopenAfterSleep;
@property (nonatomic, strong) id terminationObserver;

@property (nonatomic) io_iterator_t portPublishedNotificationIterator;
@property (nonatomic) io_iterator_t portTerminatedNotificationIterator;

@end

static ORSSerialPortManager *sharedInstance = nil;

@implementation ORSSerialPortManager
{
	NSMutableArray *_availablePorts;
}

#pragma mark - Singleton Methods

- (instancetype)init
{
	if (self == sharedInstance) return sharedInstance; // Already initialized
	
	self = [super init];
	if (self != nil)
	{
		self.portsToReopenAfterSleep = [NSMutableArray array];
		
		[self retrieveAvailablePortsAndRegisterForChangeNotifications];
		[self registerForNotifications];
	}
	return self;
}

+ (ORSSerialPortManager *)sharedSerialPortManager;
{
	static dispatch_once_t onceToken;
	dispatch_once(&onceToken, ^{
		if (sharedInstance == nil) sharedInstance = [(ORSSerialPortManager *)[super allocWithZone:NULL] init];
	});
	
	return sharedInstance;
}

+ (id)allocWithZone:(NSZone *)zone
{
	return [self sharedSerialPortManager];
}

- (id)copyWithZone:(NSZone *)zone
{
	return self;
}

- (void)dealloc
{
	NSNotificationCenter *nc = [NSNotificationCenter defaultCenter];
	[nc removeObserver:self];
#ifdef NSAppKitVersionNumber10_0
	NSNotificationCenter *wsnc = [[NSWorkspace sharedWorkspace] notificationCenter];
	[wsnc removeObserver:self];
	if (self.terminationObserver) [nc removeObserver:self.terminationObserver];
#endif
	// Stop IOKit notifications for ports being added/removed
	IOObjectRelease(_portPublishedNotificationIterator);
	_portPublishedNotificationIterator = 0;
	IOObjectRelease(_portTerminatedNotificationIterator);
	_portTerminatedNotificationIterator = 0;
}

- (void)registerForNotifications
{
	// register for notifications (only if AppKit is available)
	void (^terminationBlock)(void) = ^{
		for (ORSSerialPort *eachPort in self.availablePorts) [eachPort cleanupAfterSystemRemoval];
		self.availablePorts = @[];
	};
	
#ifdef NSAppKitVersionNumber10_0
	NSNotificationCenter *nc = [NSNotificationCenter defaultCenter];
	self.terminationObserver = [nc addObserverForName:NSApplicationWillTerminateNotification
											   object:nil
												queue:nil
										   usingBlock:^(NSNotification *notification){ terminationBlock(); }];
	
	NSNotificationCenter *wsnc = [[NSWorkspace sharedWorkspace] notificationCenter];
	[wsnc addObserver:self selector:@selector(systemWillSleep:) name:NSWorkspaceWillSleepNotification object:NULL];
	[wsnc addObserver:self selector:@selector(systemDidWake:) name:NSWorkspaceDidWakeNotification object:NULL];
#else
	// If AppKit isn't available, as in a Foundation command-line tool, cleanup upon exit. Sleep/wake
	// notifications don't seem to be available without NSWorkspace.
	int result = atexit_b(terminationBlock);
	if (result) NSLog(@"ORSSerialPort was unable to register its termination handler for serial port cleanup: %i", errno);
#endif
}

#pragma mark - Public Methods

#pragma mark -
#pragma Sleep/Wake Management

- (void)systemWillSleep:(NSNotification *)notification;
{
	NSArray *ports = self.availablePorts;
	for (ORSSerialPort *port in ports)
	{
		if (port.isOpen)
		{
			if ([port close]) [self.portsToReopenAfterSleep addObject:port];
		}
	}
}

- (void)systemDidWake:(NSNotification *)notification;
{
	NSArray *portsToReopen = [self.portsToReopenAfterSleep copy];
	for (ORSSerialPort *port in portsToReopen)
	{
		[port open];
		[self.portsToReopenAfterSleep removeObject:port];
	}
}

#pragma mark - Private Methods

- (void)serialPortsWerePublished:(io_iterator_t)iterator;
{
	NSMutableArray *newlyConnectedPorts = [[NSMutableArray alloc] init];
	io_object_t device;
	while ((device = IOIteratorNext(iterator)))
	{
		ORSSerialPort *port = [[ORSSerialPort alloc] initWithDevice:device];
		if (![self.availablePorts containsObject:port]) [newlyConnectedPorts addObject:port];
		IOObjectRelease(device);
	}
	
	[[self mutableArrayValueForKey:@"availablePorts"] addObjectsFromArray:newlyConnectedPorts];
	
	NSNotificationCenter *nc = [NSNotificationCenter defaultCenter];
	NSDictionary *userInfo = @{ORSConnectedSerialPortsKey : newlyConnectedPorts};
	[nc postNotificationName:ORSSerialPortsWereConnectedNotification object:self userInfo:userInfo];
}

- (void)serialPortsWereTerminated:(io_iterator_t)iterator;
{
	NSMutableArray *newlyDisconnectedPorts = [[NSMutableArray alloc] init];
	io_object_t device;
	while ((device = IOIteratorNext(iterator)))
	{
		ORSSerialPort *port = [[ORSSerialPort alloc] initWithDevice:device];
		[newlyDisconnectedPorts addObject:port];
		IOObjectRelease(device);
	}
	
	[newlyDisconnectedPorts makeObjectsPerformSelector:@selector(cleanupAfterSystemRemoval)];
	[[self mutableArrayValueForKey:@"availablePorts"] removeObjectsInArray:newlyDisconnectedPorts];
	
	NSNotificationCenter *nc = [NSNotificationCenter defaultCenter];
	NSDictionary *userInfo = @{ORSDisconnectedSerialPortsKey : newlyDisconnectedPorts};
	[nc postNotificationName:ORSSerialPortsWereDisconnectedNotification object:self userInfo:userInfo];
}

- (void)retrieveAvailablePortsAndRegisterForChangeNotifications;
{
	IONotificationPortRef notificationPort = IONotificationPortCreate(kIOMasterPortDefault);
	CFRunLoopAddSource(CFRunLoopGetCurrent(),
					   IONotificationPortGetRunLoopSource(notificationPort),
					   kCFRunLoopDefaultMode);
	
	CFMutableDictionaryRef matchingDict = NULL;
	
	matchingDict = IOServiceMatching(kIOSerialBSDServiceValue);
	CFRetain(matchingDict); // Need to use it twice
	
	CFDictionaryAddValue(matchingDict, CFSTR(kIOSerialBSDTypeKey), CFSTR(kIOSerialBSDAllTypes));
	
	io_iterator_t portIterator = 0;
	kern_return_t result = IOServiceAddMatchingNotification(notificationPort,
															kIOPublishNotification,
															matchingDict,
															ORSSerialPortManagerPortsPublishedNotificationCallback,
															(__bridge void *)(self),			// refCon/contextInfo
															&portIterator);
	if (result)
	{
		LOG_SERIAL_PORT_ERROR(@"Error getting serialPort list:%i", result);
		if (portIterator) IOObjectRelease(portIterator);
		CFRelease(matchingDict); // Above call to IOServiceAddMatchingNotification consumes one reference, but we added a retain for the below call
		return;
	}
	
	self.portPublishedNotificationIterator = portIterator;
	IOObjectRelease(portIterator);
	
	NSMutableArray *ports = [NSMutableArray array];
	io_object_t eachPort;
	while ((eachPort = IOIteratorNext(self.portPublishedNotificationIterator)))
	{
		ORSSerialPort *port = [ORSSerialPort serialPortWithDevice:eachPort];
		if (port) [ports addObject:port];
		IOObjectRelease(eachPort);
	}
	
	self.availablePorts = ports;
	
	// Also register for removal
	IONotificationPortRef terminationNotificationPort = IONotificationPortCreate(kIOMasterPortDefault);
	CFRunLoopAddSource(CFRunLoopGetCurrent(),
					   IONotificationPortGetRunLoopSource(terminationNotificationPort),
					   kCFRunLoopDefaultMode);
	result = IOServiceAddMatchingNotification(terminationNotificationPort,
											  kIOTerminatedNotification,
											  matchingDict,
											  ORSSerialPortManagerPortsTerminatedNotificationCallback,
											  (__bridge void *)(self),			// refCon/contextInfo
											  &portIterator);
	if (result)
	{
		LOG_SERIAL_PORT_ERROR(@"Error registering for serial port termination notification:%i.", result);
		if (portIterator) IOObjectRelease(portIterator);
		return;
	}
	
	self.portTerminatedNotificationIterator = portIterator;
	IOObjectRelease(portIterator);
	
	while (IOIteratorNext(self.portTerminatedNotificationIterator)) {}; // Run out the iterator or notifications won't start
}

#pragma mark - Properties

- (void)setAvailablePorts:(NSArray *)ports
{
	if (ports != _availablePorts)
	{
		_availablePorts = [ports mutableCopy];
	}
}

- (NSUInteger)countOfAvailablePorts { return [_availablePorts count]; }
- (id)objectInAvailablePortsAtIndex:(NSUInteger)index { return _availablePorts[index]; }
- (void)insertAvailablePorts:(NSArray *)array atIndexes:(NSIndexSet *)indexes { [_availablePorts insertObjects:array atIndexes:indexes]; }
- (void)insertObject:(ORSSerialPort *)object inAvailablePortsAtIndex:(NSUInteger)index { [_availablePorts insertObject:object atIndex:index]; }
- (void)removeAvailablePortsAtIndexes:(NSIndexSet *)indexes { [_availablePorts removeObjectsAtIndexes:indexes]; }
- (void)removeObjectFromAvailablePortsAtIndex:(NSUInteger)index { [_availablePorts removeObjectAtIndex:index]; }

- (void)setPortPublishedNotificationIterator:(io_iterator_t)iterator
{
	if (iterator != _portPublishedNotificationIterator)
	{
		if (_portPublishedNotificationIterator) IOObjectRelease(_portPublishedNotificationIterator);
		
		_portPublishedNotificationIterator = iterator;
		IOObjectRetain(_portPublishedNotificationIterator);
	}
}

- (void)setPortTerminatedNotificationIterator:(io_iterator_t)iterator
{
	if (iterator != _portTerminatedNotificationIterator)
	{
		if (_portTerminatedNotificationIterator) IOObjectRelease(_portTerminatedNotificationIterator);
		
		_portTerminatedNotificationIterator = iterator;
		IOObjectRetain(_portTerminatedNotificationIterator);
	}
}

@end

void ORSSerialPortManagerPortsPublishedNotificationCallback(void *refCon, io_iterator_t iterator)
{
	ORSSerialPortManager *manager = (__bridge ORSSerialPortManager *)refCon;
	if (![manager isKindOfClass:[ORSSerialPortManager class]])
	{
		NSLog(@"Unexpected context object %@ in %s. Context object should be an instance of ORSSerialPortManager", manager, __PRETTY_FUNCTION__);
		return;
	}
	[manager serialPortsWerePublished:iterator];
}

void ORSSerialPortManagerPortsTerminatedNotificationCallback(void *refCon, io_iterator_t iterator)
{
	ORSSerialPortManager *manager = (__bridge ORSSerialPortManager *)refCon;
	if (![manager isKindOfClass:[ORSSerialPortManager class]])
	{
		NSLog(@"Unexpected context object %@ in %s. Context object should be an instance of ORSSerialPortManager", manager, __PRETTY_FUNCTION__);
		return;
	}
	[manager serialPortsWereTerminated:iterator];
}