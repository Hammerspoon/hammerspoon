#import "HSRazerDevice.h"

#include <IOKit/usb/IOUSBLib.h>

double getSecondsSinceEpoch(void) {
    struct timeval v;
    gettimeofday(&v, (struct timezone *) NULL);
    return v.tv_sec + v.tv_usec/1.0e6;
}

// HSRazerResult:
@implementation HSRazerResult
- (id)init {
    if ((self = [super init])) {
        self.success = NO;
    }
    return self;
}
@end

// HSRazerDevice:
@interface HSRazerDevice ()
@end

@implementation HSRazerDevice
- (id)initWithDevice:(IOHIDDeviceRef)device manager:(id)manager {
    self = [super init];
    if (self) {
        self.device                     = device;
        self.isValid                    = YES;
        self.manager                    = manager;
        self.buttonCallbackRef          = LUA_NOREF;
        self.selfRefCount               = 0;

        // These defaults are not necessary, all base classes will override them, but if we miss something, these are chosen to try and provoke a crash where possible, so we notice the lack of an override.
        self.name                       = @"Unknown";
        self.scrollWheelPressed         = NO;
        self.lastScrollWheelEvent       = getSecondsSinceEpoch();

        //NSLog(@"[hs.razer] Added new Razer device %p with IOKit device %p from manager %p", (__bridge void *)self, (void*)self.device, (__bridge void *)self.manager);
    }
    return self;
}

- (void)invalidate {
    self.isValid = NO;
    [self destroyEventTap];
}

#pragma mark - Button Callbacks

- (void)deviceButtonPress:(NSString*)scancodeString pressed:(long)pressed {
    //NSLog(@"Tartarus V2 deviceButtonPress!");
    //NSLog(@"scancode: %@", scancodeString);
    //NSLog(@"pressed: %ld", pressed);

    // Abort if the device is no longer valid:
    if (!self.isValid) {
        //NSLog(@"[hs.razer] The Razer device is no longer valid.");
        return;
    }

    // Get button name from device dictonary:
    NSString *buttonName = [self.buttonNames valueForKey:scancodeString];

    // Abort if there's no button name:
    if (!buttonName) {
        //NSLog(@"[hs.razer] There's no button assigned for: %@", scancodeString);
        return;
    }

    // Process the button action:
    NSString *buttonAction = @"";
    NSString *scrollWheelID = [NSString stringWithFormat:@"%d", self.scrollWheelID];
    if ([scancodeString isEqualToString:scrollWheelID]) {
        // Scroll Wheel:
        if (pressed == 1){
            buttonAction = @"up";
            self.lastScrollWheelEvent = getSecondsSinceEpoch();
        }
        else if (pressed == -1) {
            buttonAction = @"down";
            self.lastScrollWheelEvent = getSecondsSinceEpoch();
        }
        else if (pressed == 0) {
            if (self.scrollWheelPressed) {
                buttonAction = @"released";
                self.scrollWheelPressed = NO;
            } else {
                buttonAction = @"pressed";
                self.scrollWheelPressed = YES;
            }
        }
    }
    else
    {
        // Buttons:
        if (pressed == 1){
            buttonAction = @"pressed";
        }
        else {
            buttonAction = @"released";
        }
    }

    // Trigger the Lua callback:
    if (self.buttonCallbackRef != LUA_NOREF) {
        LuaSkin *skin = [LuaSkin sharedWithState:NULL];

        if (![skin checkGCCanary:self.lsCanary]) {
            return;
        }

        _lua_stackguard_entry(skin.L);
        [skin pushLuaRef:razerRefTable ref:self.buttonCallbackRef];
        [skin pushNSObject:self];
        [skin pushNSObject:buttonName];
        [skin pushNSObject:buttonAction];
        [skin protectedCallAndError:@"hs.razer:callback" nargs:3 nresults:0];
        _lua_stackguard_exit(skin.L);
    }

}

#pragma mark - Event Tap for Scroll Wheel

// We need to use an eventtap to stop the scroll wheel on the Razer Tartarus V2 from actually scrolling.

static CGEventRef eventTapCallback(CGEventTapProxy proxy,
                           CGEventType type,
                           CGEventRef event,
                           void* refcon) {

    //NSLog(@"[hs.razer] Event Tap Callback Triggered");

    // Prevent a crash when doing garbage collection:
    if (type == kCGEventTapDisabledByUserInput) {
        //NSLog(@"[hs.razer] Aborting Event Tap Callback, because event tap disabled by user input.");
        return event;
    }

    HSRazerDevice *manager = (__bridge HSRazerDevice *)refcon;

    // Make sure the manager still exists:
    if (manager == nil) {
        //NSLog(@"[hs.razer] Aborting Event Tap Callback, because manager no longer exists.");
        return event; // Allow the event to pass through unmodified
    }

    // Restart event tap if it times out:
    if (type == kCGEventTapDisabledByTimeout) {
        //NSLog(@"[hs.razer] Aborting Event Tap Callback, because event tap disabled by timeout.");
        CGEventTapEnable(manager.eventTap, true);
        return event; // Allow the event to pass through unmodified
    }

    // Guard against this callback being delivered at a point where LuaSkin has been reset and our references wouldn't make sense anymore:
    LuaSkin *skin = [LuaSkin sharedWithState:NULL];
    if (![skin checkGCCanary:manager.lsCanary]) {
        //NSLog(@"[hs.razer] Aborting Event Tap Callback, because canary test failed.");
        return event; // Allow the event to pass through unmodified
    }
    
    // Throw away the event if we recently scrolled with the Razer Device:
    double currentTime = getSecondsSinceEpoch() - 0.1;
    if (currentTime < manager.lastScrollWheelEvent) {
        return NULL;
    } else {
        return event;
    }
}

- (void)setupEventTap
{
    if (!self.scrollWheelID) {
        NSLog(@"[hs.razer] The device does not have a scroll wheel ID, so aborting event tap setup.");
        return;
    }

    //NSLog(@"[hs.razer] Setting up Event Tap.");

    CGEventTapLocation location = kCGHIDEventTap;

    CGEventMask mask = CGEventMaskBit(kCGEventScrollWheel);

    self.eventTap = CGEventTapCreate(location,
                                     kCGTailAppendEventTap,
                                     kCGEventTapOptionDefault,
                                     mask,
                                     eventTapCallback,
                                     (__bridge void*)(self));

    if (!self.eventTap) {
        NSLog(@"[hs.razer] Failed to create the event tap.");
    } else {
        CFRunLoopSourceRef source = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, self.eventTap, 0);
        CFRunLoopAddSource(CFRunLoopGetCurrent(), source, kCFRunLoopCommonModes);
        CFRelease(source);

        CGEventTapEnable(self.eventTap, true);
    }
}

- (void)destroyEventTap
{
    if (self.eventTap){
        if (CGEventTapIsEnabled(self.eventTap)) {
            CGEventTapEnable(self.eventTap, false);
        }
        CFRelease(self.eventTap);
    }
}

#pragma mark - hs.razer: Keyboard Backlight Placeholders

- (HSRazerResult*)setBacklightToStaticColor:(NSColor*)color {
    NSException *exception = [NSException exceptionWithName:@"HSRazerDeviceUnimplemented"
                                                     reason:@"setBacklightToStaticColor method not implemented"
                                                   userInfo:nil];
    [exception raise];
    return [[HSRazerResult alloc] init];
}
- (HSRazerResult*)setBacklightToOff {
    NSException *exception = [NSException exceptionWithName:@"HSRazerDeviceUnimplemented"
                                                     reason:@"setBacklightToOff method not implemented"
                                                   userInfo:nil];
    [exception raise];
    return [[HSRazerResult alloc] init];
}

- (HSRazerResult*)setBacklightToWaveWithSpeed:(NSNumber*)speed direction:(NSString*)direction {
    NSException *exception = [NSException exceptionWithName:@"HSRazerDeviceUnimplemented"
                                                     reason:@"setBacklightToWaveWithSpeed method not implemented"
                                                   userInfo:nil];
    [exception raise];
    return [[HSRazerResult alloc] init];
}
- (HSRazerResult*)setBacklightToSpectrum {
    NSException *exception = [NSException exceptionWithName:@"HSRazerDeviceUnimplemented"
                                                     reason:@"setBacklightToSpectrum method not implemented"
                                                   userInfo:nil];
    [exception raise];
    return [[HSRazerResult alloc] init];
}

- (HSRazerResult*)setBacklightToReactiveWithColor:(NSColor*)color speed:(NSNumber*)speed {
    NSException *exception = [NSException exceptionWithName:@"HSRazerDeviceUnimplemented"
                                                     reason:@"setBacklightToReactiveWithColor method not implemented"
                                                   userInfo:nil];
    [exception raise];
    return [[HSRazerResult alloc] init];
}

- (HSRazerResult*)setBacklightToStarlightWithColor:(NSColor*)color secondaryColor:(NSColor*)secondaryColor speed:(NSNumber*)speed {
    NSException *exception = [NSException exceptionWithName:@"HSRazerDeviceUnimplemented"
                                                     reason:@"setBacklightToStarlightWithColor method not implemented"
                                                   userInfo:nil];
    [exception raise];
    return [[HSRazerResult alloc] init];
}

- (HSRazerResult*)setBacklightToBreathingWithColor:(NSColor*)color secondaryColor:(NSColor*)secondaryColor {
    NSException *exception = [NSException exceptionWithName:@"HSRazerDeviceUnimplemented"
                                                     reason:@"setBacklightToBreathWithColor method not implemented"
                                                   userInfo:nil];
    [exception raise];
    return [[HSRazerResult alloc] init];
}

- (HSRazerResult*)setBacklightToCustomWithColors:(NSMutableDictionary *)customColors {
    NSException *exception = [NSException exceptionWithName:@"HSRazerDeviceUnimplemented"
                                                     reason:@"setBacklightToCustomWithColors method not implemented"
                                                   userInfo:nil];
    [exception raise];
    return [[HSRazerResult alloc] init];
}

#pragma mark - hs.razer: Brightness Placeholders

- (HSRazerResult*)getBrightness {
    NSException *exception = [NSException exceptionWithName:@"HSRazerDeviceUnimplemented"
                                                     reason:@"getBrightness method not implemented"
                                                   userInfo:nil];
    [exception raise];
    return [[HSRazerResult alloc] init];
}

- (HSRazerResult*)setBrightness:(NSNumber *)brightness {
    NSException *exception = [NSException exceptionWithName:@"HSRazerDeviceUnimplemented"
                                                     reason:@"setBrightness method not implemented"
                                                   userInfo:nil];
    [exception raise];
    return [[HSRazerResult alloc] init];
}

#pragma mark - hs.razer: Status Light Placeholders

- (HSRazerResult*)getOrangeStatusLight {
    NSException *exception = [NSException exceptionWithName:@"HSRazerDeviceUnimplemented"
                                                     reason:@"getOrangeStatusLight method not implemented"
                                                   userInfo:nil];
    [exception raise];
    return [[HSRazerResult alloc] init];
}

- (HSRazerResult*)setOrangeStatusLight:(BOOL)active {
    NSException *exception = [NSException exceptionWithName:@"HSRazerDeviceUnimplemented"
                                                     reason:@"setOrangeStatusLight method not implemented"
                                                   userInfo:nil];
    [exception raise];
    return [[HSRazerResult alloc] init];
}

- (HSRazerResult*)getGreenStatusLight {
    NSException *exception = [NSException exceptionWithName:@"HSRazerDeviceUnimplemented"
                                                     reason:@"getGreenStatusLight method not implemented"
                                                   userInfo:nil];
    [exception raise];
    return [[HSRazerResult alloc] init];
}

- (HSRazerResult*)setGreenStatusLight:(BOOL)active {
    NSException *exception = [NSException exceptionWithName:@"HSRazerDeviceUnimplemented"
                                                     reason:@"setGreenStatusLight method not implemented"
                                                   userInfo:nil];
    [exception raise];
    return [[HSRazerResult alloc] init];
}

- (HSRazerResult*)getBlueStatusLight {
    NSException *exception = [NSException exceptionWithName:@"HSRazerDeviceUnimplemented"
                                                     reason:@"getBlueStatusLight method not implemented"
                                                   userInfo:nil];
    [exception raise];
    return [[HSRazerResult alloc] init];
}

- (HSRazerResult*)setBlueStatusLight:(BOOL)active {
    NSException *exception = [NSException exceptionWithName:@"HSRazerDeviceUnimplemented"
                                                     reason:@"setBlueStatusLight method not implemented"
                                                   userInfo:nil];
    [exception raise];
    return [[HSRazerResult alloc] init];
}

#pragma mark - hs.razer: USB Device Methods

- (IOUSBDeviceInterface**)getUSBRazerDevice {

    //NSLog(@"[hs.razer] Getting Razer USB Device");

    CFMutableDictionaryRef matchingDict = IOServiceMatching(kIOUSBDeviceClassName);

    // Get all the USB devices:
    io_iterator_t iter;
    kern_return_t kReturn = IOServiceGetMatchingServices(kIOMasterPortDefault, matchingDict, &iter);

    // Abort if something goes wrong:
    if (kReturn != kIOReturnSuccess) {
        //NSLog(@"[hs.razer] Failed to get any USB devices: %d", kReturn);
        return NULL;
    }

    // Check each USB device to see if there's a match:
    io_service_t usbDevice;
    while ((usbDevice = IOIteratorNext(iter)))
    {
        IOCFPlugInInterface **plugInInterface = NULL;
        SInt32 score;

        // Create a new device plugin:
        kReturn = IOCreatePlugInInterfaceForService(usbDevice, kIOUSBDeviceUserClientTypeID, kIOCFPlugInInterfaceID, &plugInInterface, &score);

        // Clean up unnecessary object:
        IOObjectRelease(usbDevice);

        // Skip the current USB device if can't create plugin:
        if ((kReturn != kIOReturnSuccess) || plugInInterface == NULL) {
            //NSLog(@"[hs.razer] Failed to create plugin: %d", kReturn);
            continue;
        }

        // Create a new device interface:
        IOUSBDeviceInterface **dev = NULL;
        HRESULT hResult = (*plugInInterface)->QueryInterface(plugInInterface, CFUUIDGetUUIDBytes(kIOUSBDeviceInterfaceID), (LPVOID *)&dev);

        // Clean up unnecessary object:
        (*plugInInterface)->Release(plugInInterface);

        // Skip the current USB device if can't create interface:
        if (hResult || !dev) {
            //NSLog(@"[hs.razer] Failed to create device interface: %d", (int)hResult);
            continue;
        }

        // Clean up unnecessary object:
        kern_return_t kr;

        // Make sure the location ID matches:
        UInt32 locationID;
        kr = (*dev)->GetLocationID(dev, &locationID);
        if (kr != kIOReturnSuccess || locationID != [self.locationID unsignedIntValue]) {
            //NSLog(@"[hs.razer] The location ID for the IOHID Device doesn't match the USB Device.");
            continue;
        }

        // Make sure the vendor matches (just for safety):
        UInt16 vendor;
        kr = (*dev)->GetDeviceVendor(dev, &vendor);
        if (kr != kIOReturnSuccess || vendor != USB_VID_RAZER) {
            //NSLog(@"[hs.razer] Vendor is not Razer: %hu", vendor);
            continue;
        }

        // Make sure the product matches (just for safety):
        UInt16 product;
        kr = (*dev)->GetDeviceProduct(dev, &product);
        if (kr != kIOReturnSuccess || product != self.productID) {
            //NSLog(@"[hs.razer] Product is not a Taratus V2: %hu", product);
            continue;
        }

        // Open the device:
        kReturn = (*dev)->USBDeviceOpen(dev);
        if (kReturn != kIOReturnSuccess) {
            //NSLog(@"[hs.razer] Failed to open USB device: %d", kReturn);
            (*dev)->Release(dev);
            continue;
         }

        // Clean up unnecessary object:
        IOObjectRelease(iter);

        // Party time! We found the Razer USB device.
        //NSLog(@"[hs.razer] Found a device!");
        return dev;
    }

    // No device found:
    //NSLog(@"[hs.razer] No Razer USB Devices found that match IOHID Device.");
    return NULL;
}

- (HSRazerResult*)sendRazerReportToDeviceWithTransactionID:(int)transactionID commandClass:(int)commandClass commandID:(int)commandID arguments:(NSDictionary*)arguments {
    /*
    Handy Resources:

        - Information on USB Packets:
          https://www.beyondlogic.org/usbnutshell/usb6.shtml

        - AppleUSBDefinitions.h:
          https://lab.qaq.wiki/Lakr233/IOKit-deploy/-/blob/master/IOKit/usb/AppleUSBDefinitions.h
    */

    // Setup the result we'll eventually return:
    HSRazerResult *result = [[HSRazerResult alloc] init];

    // The wValue and wIndex fields allow parameters to be passed with the request:
    int wValue  = 0x300;    // wValue   = 16 bit parameter for request, low byte first.
    int wIndex  = 0x01;     // wIndex   = 16 bit parameter for request, low byte first.

    // wLength is used the specify the number of bytes to be transferred should there be a data phase:
    int wLength = 90;       // wLength  = Length of data part of request, 16 bits, low byte first. A Razer Report is always 90 bytes.

    // Setup an empty Razor Report:
    struct HSRazerReport report   = {0};            // Setup an empty Razer Report

    // Determine the data size based on the amount of arguments provided:
    int dataSize = (int)[arguments count];

    // Now fill it with data:
    report.status                 = 0x00;           // Always 0x00 for a New Command
    report.transaction_id.id      = transactionID;  // Allows you to group requests if using multiple devices
    report.remaining_packets      = 0x00;           // Remaning Packets (using Big Endian Byte Order)
    report.protocol_type          = 0x00;           // Always seems to be 0x00
    report.data_size              = dataSize;       // How many arguments
    report.command_class          = commandClass;   // The type of command being triggered
    report.command_id.id          = commandID;      // The ID of the command being triggered
    report.reserved               = 0x00;           // A reserved byte - always 0x00

    // Process the arguments:
    for (unsigned long x = 0; x < [arguments count]; x++)
    {
        id argument = [arguments objectForKey:[NSNumber numberWithUnsignedLong:x]];
        if (argument) {
            report.arguments[x] = [argument integerValue];
        }
    }

    // Razer uses a CRC as a simple checksum to make sure the report data is correct and valid. You just XOR all the bytes.
    unsigned char crc = 0;
    unsigned char *crcReport = (unsigned char*)&report;
    for(unsigned int i = 2; i < 88; i++) { crc ^= crcReport[i]; }
    report.crc = crc;

    // Parameter block for control requests, using a simple pointer for the data to be transferred:
    IOUSBDevRequest request;

    // The bmRequestType field will determine the direction of the request, type of request and designated recipient:
    request.bmRequestType           = kIOUSBDeviceRequestDirectionOut | kIOUSBDeviceRequestTypeClass | kIOUSBDeviceRequestRecipientValueInterface;

    // The bRequest field determines the request being made:
    request.bRequest                = kIOUSBDeviceRequestSetConfiguration;

    // The wValue and wIndex fields allow parameters to be passed with the request:
    request.wValue                  = wValue;           // wValue   = 16 bit parameter for request, low byte first.
    request.wIndex                  = wIndex;           // wIndex   = 16 bit parameter for request, low byte first.

    // wLength is used the specify the number of bytes to be transferred should there be a data phase:
    request.wLength                 = wLength;          // wLength  = Length of data part of request, 16 bits, low byte first.

    // wData is the actual data to send:
    request.pData                   = (void*)&report;   // pData    = Pointer to data for request.

    // Get the Razer USB device:
    IOUSBDeviceInterface **razerDevice = self.getUSBRazerDevice;

    // If no device could be found, abort:
    if (!razerDevice) {
        result.errorMessage = @"Failed to create a Razer device for the initial report.";
        return result;
    }

    // Send the report to the device:
    IOReturn deviceRequestResult = (*razerDevice)->DeviceRequest(razerDevice, &request);

    // Opps! Something has gone wrong:
    if (deviceRequestResult != kIOReturnSuccess) {
        // Close & Release the USB Device:
        (*razerDevice)->USBDeviceClose(razerDevice);
        (*razerDevice)->Release(razerDevice);

        result.errorMessage = [NSString stringWithFormat:@"Failed to send Device Request: %d", deviceRequestResult];
        return result;
    }

    // Wait for a response back...
    usleep(500); // Standard Device requests with a data stage must start to return data 500ms after the request.

    // Parameter block for control requests, using a simple pointer for the data to be transferred:
    IOUSBDevRequest responseRequest;

    // Setup an empty Razor Report for the response back:
    struct HSRazerReport responseReport       = {0};

    // The bmRequestType field will determine the direction of the request, type of request and designated recipient:
    responseRequest.bmRequestType           = kIOUSBDeviceRequestDirectionIn | kIOUSBDeviceRequestTypeClass | kIOUSBDeviceRequestRecipientValueInterface;

    // The bRequest field determines the request being made:
    responseRequest.bRequest                = kIOUSBDeviceRequestClearFeature;

    // The wValue and wIndex fields allow parameters to be passed with the request:
    responseRequest.wValue                  = wValue;            // wValue   = 16 bit parameter for request, low byte first.
    responseRequest.wIndex                  = wIndex;            // wIndex   = 16 bit parameter for request, low byte first.

    // wLength is used the specify the number of bytes to be transferred should there be a data phase:
    responseRequest.wLength                 = wLength;           // wLength  = Length of data part of request, 16 bits, low byte first.

    // wData is the actual data to send:
    responseRequest.pData                   = &responseReport;   // pData    = Pointer to data for request.

    // Send the report to the device:
    IOReturn responseResult = (*razerDevice)->DeviceRequest(razerDevice, &responseRequest);

    // Close & Release the USB Device:
    (*razerDevice)->USBDeviceClose(razerDevice);
    (*razerDevice)->Release(razerDevice);

    // Process the response:
    if(responseResult != kIOReturnSuccess) {
        result.errorMessage = [NSString stringWithFormat:@"Failed to get a response back from the Razer Device: %s", mach_error_string(responseResult)];
    } else {
        if (responseReport.remaining_packets != report.remaining_packets) {
            result.errorMessage = @"The sent report remaining packets don't match the response remaining packets.";
        } else if (responseReport.command_class != report.command_class) {
            result.errorMessage = @"The sent report command class doesn't match the response command class.";
        } else if (responseReport.command_id.id != report.command_id.id) {
            result.errorMessage = @"The sent report command ID doesn't match the response command ID.";
        } else if (responseReport.status == 0x01) {
            // NOTE:
            // It seems that the Razer device sends back a "busy" response quite a bit, but
            // still successfully executes the command, so not sure what's going on there.
            // We'll just assume that "busy" actually means slightly delayed, but still successful.

            //result.errorMessage = @"Razer device is busy.";

            // Victory!
            result.success = YES;
        } else if (responseReport.status == 0x02) {
            // Victory!
            result.success = YES;
        } else if (responseReport.status == 0x03) {
            result.errorMessage = @"The command sent to the Razer device failed.";
        } else if (responseReport.status == 0x04) {
            result.errorMessage = @"The command sent to the Razer device timed out.";
        } else if (responseReport.status == 0x05) {
            result.errorMessage = @"The command sent to the Razer device is not supported.";
        } else {
            result.errorMessage = [NSString stringWithFormat:@"Unexpected status back from the Razer device: %c", responseReport.status];
        }
    }

    // Put any useful arguments into the result:
    result.argumentTwo = responseReport.arguments[2];

    // Something went wrong:
    return result;
}

@end
