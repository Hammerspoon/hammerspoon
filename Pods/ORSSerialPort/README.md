# ORSSerialPort 

ORSSerialPort is an easy-to-use Objective-C serial port library for macOS. It is useful for programmers writing Objective-C or Swift Mac apps that communicate with external devices through a serial port (most commonly RS-232). You can use ORSSerialPort to write apps that connect to Arduino projects, robots, data acquisition devices, ham radios, and all kinds of other devices. Using ORSSerialPort to open a port and send data can be as simple as this:

```objective-c
ORSSerialPort *serialPort = [ORSSerialPort serialPortWithPath:@"/dev/cu.KeySerial1"];
serialPort.baudRate = @4800;
[serialPort open];
[serialPort sendData:someData]; // someData is an NSData object
[serialPort close]; // Later, when you're done with the port
```

Or, in Swift:

```swift
let serialPort = ORSSerialPort(path: "/dev/cu.KeySerial1")
serialPort.baudRate = 4800
serialPort.open()
serialPort.sendData(someData) // someData is an NSData object
serialPort.close() // Later, when you're done with the port
```
    
ORSSerialPort is released under an MIT license, meaning you're free to use it in both closed and open source projects. However, even in a closed source project, you must include a publicly-accessible copy of ORSSerialPort's copyright notice, which you can find in the LICENSE file.

If you have any questions about, suggestions for, or contributions to ORSSerialPort, please [contact me](mailto:andrew@openreelsoftware.com). I'd also love to hear about any cool projects you're using it in.

This readme provides an overview of the ORSSerialPort library and is meant to provide enough information to get up and running quickly. You can read complete technical documentation for ORSSerialPort on [http://cocoadocs.org/docsets/ORSSerialPort/](http://cocoadocs.org/docsets/ORSSerialPort/). The [ORSSerialPort wiki](https://github.com/armadsen/ORSSerialPort/wiki) also contains detailed documentation.

The example code in this readme is in Objective-C. However, ORSSerialPort can also easily be used from Swift code. The Examples folder contains Swift versions of all four example projects. See the Example Projects section below for more information.

# How to Use ORSSerialPort

There are a number of ways to add ORSSerialPort to your project. You can use the included framework project, [Carthage](https://github.com/Carthage), [CocoaPods](http://cocoapods.org), or manually include the ORSSerialPort source code in your project. See the [Guide to Installing ORSSerialPort](https://github.com/armadsen/ORSSerialPort/wiki/Installing-ORSSerialPort) for detailed instructions for each of these methods.

### Opening a Port and Setting It Up

You can get an `ORSSerialPort` instance either of two ways. The easiest is to use `ORSSerialPortManager`'s `availablePorts` array (explained below). The other way is to get a new `ORSSerialPort` instance using the serial port's BSD device path:

```objective-c
ORSSerialPort *port = [ORSSerialPort serialPortWithPath:@"/dev/cu.KeySerial1"];
```

Note that you must give `+serialPortWithPath:` the full path to the device, as shown in the example above.

After you've got a port instance, you can open it with the `-open` method. When you're done using the port, close it using the `-close` method.

Port settings such as baud rate, number of stop bits, parity, and flow control settings can be set using the various properties `ORSSerialPort` provides:

```objective-c
port.baudRate = @9600;
port.parity = ORSSerialPortParityNone;
port.numberOfStopBits = 1;
port.usesRTSCTSFlowControl = YES;
```

For more information, see the [Getting Started Guide](https://github.com/armadsen/ORSSerialPort/wiki/Getting-Started#opening-a-port-and-setting-it-up).

### Sending Data

Send raw data by passing an `NSData` object to the `-sendData:` method:

```objective-c
NSData *dataToSend = [self.sendTextField.stringValue dataUsingEncoding:NSUTF8StringEncoding];
[self.serialPort sendData:dataToSend];
```

### Receiving Data

To receive data, you can implement the `ORSSerialPortDelegate` protocol's `-serialPort:didReceiveData:` method, and set the `ORSSerialPort` instance's delegate property. As noted below, this method is always called on the main queue. An example implementation is included below:

```objective-c
- (void)serialPort:(ORSSerialPort *)serialPort didReceiveData:(NSData *)data
{
    NSString *string = [[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding];
    [self.receivedDataTextView.textStorage.mutableString appendString:string];
    [self.receivedDataTextView setNeedsDisplay:YES];
}
```

### ORSSerialPortDelegate 

`ORSSerialPort` includes a delegate property, and a delegate protocol called `ORSSerialPortDelegate`. A port informs its delegate of events including receipt of data, port open/close events, removal from the system, and errors. For more information, see the [Getting Started Guide](https://github.com/armadsen/ORSSerialPort/wiki/Getting-Started#orsserialportdelegate), or read the documentation in [ORSSerialPort.h](https://github.com/armadsen/ORSSerialPort/blob/master/Source/ORSSerialPort.h#L443).

### ORSSerialPortManager

`ORSSerialPortManager` is a singleton class (one instance per application) that can be used to get a list of available serial ports. Use the manager's `availablePorts` property to get a list of ports:

```objective-c
NSArray *ports = [[ORSSerialPortManager sharedSerialPortManager] availablePorts];
```

ORSSerialPortManager's `availablePorts` can be observed with Key Value Observing to be notified when a USB to serial adapter is plugged in or removed. Additionally, it posts NSNotifications when these events occur. It will also handle closing open serial ports when the Mac goes to sleep, and reopening them automatically on wake. This prevents problems I've seen with serial port drivers that can hang if the port is left open when putting the machine to sleep. Note that using `ORSSerialPortManager` is optional. It provides some nice functionality, but only `ORSSerialPort` is necessary to simply send and receive data.

For more information about ORSSerialPortManager, see the [Getting Started Guide](https://github.com/armadsen/ORSSerialPort/wiki/Getting-Started#orsserialportmanager), or read the documentation in [ORSSerialPortManager.h](https://github.com/armadsen/ORSSerialPort/blob/master/Source/ORSSerialPortManager.h).

### ORSSerialPacketDescriptor

Incoming serial data is delivered to your application as it is received. A low level library like ORSSerialPort has no way of knowing anything about the structure and format of the data you're sending and receiving. For example, you may be expecting a complete packet of data, but receive callbacks for each byte. Normally, this requires you to maintain a buffer which you fill up with incoming data, only processing it when a complete packet has been received. In order to eliminate the need for manual management and buffering of incoming data, ORSSerialPort includes a packet parsing API. This is implemented by `ORSSerialPacketDescriptor` and associated methods on `ORSSerialPort`.

For more information about ORSSerialPort's packet parsing API, see the [Packet Parsing API Guide](https://github.com/armadsen/ORSSerialPort/wiki/Packet-Parsing-API), read the documentation in [ORSSerialPacketDescriptor.h](https://github.com/armadsen/ORSSerialPort/blob/master/Source/ORSSerialPacketDescriptor.h), and see the [PacketParsingDemo](https://github.com/armadsen/ORSSerialPort/tree/master/Examples/PacketParsingDemo) example app.

### ORSSerialRequest

Often, applications will want to send a command to a device, then wait to receive a specific response before continuing. To ease implementing this kind of scenario, ORSSerialPort includes a request/response API. This is implemented by `ORSSerialRequest` and associated methods on `ORSSerialPort`.

For example, a program that read the temperature from a connected device might do the following:

```objective-c
- (void)readTemperature
{
    NSData *command = [@"$TEMP?;" dataUsingEncoding:NSASCIIStringEncoding];
    ORSSerialPacketDescriptor *responseDescriptor = 
    [[ORSSerialPacketDescriptor alloc] initWithMaximumPacketLength:9
                                                          userInfo:nil
                                                 responseEvaluator:^BOOL(NSData *data) {
        return [self temperatureFromResponsePacket:data] != nil;
    }];
    ORSSerialRequest *request = 
        [ORSSerialRequest requestWithDataToSend:command
                                       userInfo:nil
                                timeoutInterval:kTimeoutDuration
                             responseDescriptor:responseDescriptor];
    [self.serialPort sendRequest:request];
} 

- (void)serialPort:(ORSSerialPort *)port didReceiveResponse:(NSData *)data toRequest:(ORSSerialRequest *)request
{
    NSString *response = [[NSString alloc] initWithData:data usingEncoding:NSASCIIStringEncoding];
    NSLog(@"response = %@", response);
    self.temperature = [self temperatureFromResponsePacket:data];
}

- (void)serialPort:(ORSSerialPort *)port requestDidTimeout:(ORSSerialRequest *)request
{
    NSLog(@"command timed out!);
}
```

For more information about ORSSerialPort's request/response API, see the [Request/Response API Guide](https://github.com/armadsen/ORSSerialPort/wiki/Request-Response-API), read the documentation in [ORSSerialRequest.h](https://github.com/armadsen/ORSSerialPort/blob/master/Source/ORSSerialRequest.h), and see the [RequestResponseDemo](https://github.com/armadsen/ORSSerialPort/tree/master/Examples/RequestResponseDemo) example app.

# Example Projects

Included with ORSSerialPort is a folder called Examples, containing Xcode projects for small programs demonstrating the use of ORSSerialPort. Each example is available in *both* Objective-C and Swift. The following example apps are included:

- [ORSSerialPortDemo](https://github.com/armadsen/ORSSerialPort/wiki/ORSSerialPortDemo) - Simple graphical serial terminal example app. This is the main ORSSerialPort example.
- [CommandLineDemo](https://github.com/armadsen/ORSSerialPort/wiki/Command-Line-Demo) - Command line app example.
- [PacketParsingDemo](https://github.com/armadsen/ORSSerialPort/wiki/Packet-Parsing-API) - GUI app demonstrating the use of ORSSerialPacketDescriptor.
- [RequestResponseDemo](https://github.com/armadsen/ORSSerialPort/wiki/Request-Response-API) - GUI app demonstrating the use of ORSSerialRequest.

You can read more about these examples on the [ORSSerialPort wiki](https://github.com/armadsen/ORSSerialPort/wiki).

# Contributing

Contributions to ORSSerialPort are very welcome. However, contributors are encouraged to read the [contribution guidelines](CONTRIBUTING.md) before starting work on any contributions. Please also feel free to open a GitHub issue or [email](mailto:andrew@openreelsoftware.com) with questions about specific contributions.

[![GitHub License Badge](https://img.shields.io/badge/license-MIT-blue.svg)](https://raw.githubusercontent.com/armadsen/ORSSerialPort/master/LICENSE)
[![Build Status Badge](https://travis-ci.org/armadsen/ORSSerialPort.svg?branch=master)](https://travis-ci.org/armadsen/ORSSerialPort)
[![CocoaPods Badge](https://img.shields.io/cocoapods/v/ORSSerialPort.svg)]()
