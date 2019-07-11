#import <Foundation/Foundation.h>
#include <mach/mach_error.h>
#include <IOKit/hid/IOHIDUsageTables.h>

static NSMutableDictionary* _CreateMatchingDict(Boolean isDeviceNotElement,
                                                uint32_t inUsagePage,
                                                uint32_t inUsage);

static NSMutableDictionary* _CreateMatchingDict(Boolean isDeviceNotElement,
                                                uint32_t inUsagePage,
                                                uint32_t inUsage)
{
    NSMutableDictionary* dic = [[NSMutableDictionary alloc] initWithObjectsAndKeys:
                                [NSNumber numberWithUnsignedInt:inUsagePage],
                                (isDeviceNotElement)?
                                CFSTR(kIOHIDDeviceUsagePageKey):
                                CFSTR(kIOHIDElementUsagePageKey),
                                NULL];
    if (inUsage) [dic setObject:[NSNumber numberWithUnsignedInt:inUsage]
                         forKey:(isDeviceNotElement)?
                  (NSString*)CFSTR(kIOHIDDeviceUsageKey):
                  (NSString*)CFSTR(kIOHIDElementUsageKey)];
    return dic;
}

#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wcast-qual"
#pragma clang diagnostic ignored "-Wdirect-ivar-access"

bool hidled_set(uint32 usage, long target_value) {
    bool success = false;
    CFSetRef deviceCFSetRef = NULL;
    IOHIDDeviceRef * refs = NULL;
    // create a IO HID Manager reference
    IOHIDManagerRef mgr = IOHIDManagerCreate(kCFAllocatorDefault, kIOHIDOptionsTypeNone);
    if(!mgr)
        return false;
    // Create a device matching dictionary
    NSDictionary* dic = _CreateMatchingDict(true, kHIDPage_GenericDesktop,
                                            kHIDUsage_GD_Keyboard);
    if (!dic)
        goto Oops;
    // set the HID device matching dictionary
    IOHIDManagerSetDeviceMatching(mgr, (__bridge CFDictionaryRef)dic);
    //    [dic release];
    // Now open the IO HID Manager reference
    IOReturn err = IOHIDManagerOpen(mgr, kIOHIDOptionsTypeNone);
    if (err != 0)
        goto Oops;
    // and copy out its devices
    deviceCFSetRef = IOHIDManagerCopyDevices(mgr);
    if (!deviceCFSetRef)
        goto Oops;
    // how many devices in the set?
    CFIndex deviceIndex, deviceCount = CFSetGetCount(deviceCFSetRef);
    // allocate a block of memory to extact the device refs from the set into
    refs = malloc(sizeof(IOHIDDeviceRef) * deviceCount);
    if (!refs)
        goto Oops;
    // now extract the device refs from the set
    CFSetGetValues(deviceCFSetRef, (const void **)(void *)refs);
    // before we get into the device loop set up element matching dictionary
    dic = _CreateMatchingDict(false, kHIDPage_LEDs, 0);
    if (!dic)
        goto Oops;
    
    for (deviceIndex = 0; deviceIndex < deviceCount; deviceIndex++)
    {
        // if this isn't a keyboard device...
        if (!IOHIDDeviceConformsTo((IOHIDDeviceRef)refs[deviceIndex], kHIDPage_GenericDesktop,
                                   kHIDUsage_GD_Keyboard))
        {
            continue;  // ...skip it
        }
        // copy all the elements
        CFArrayRef elements = IOHIDDeviceCopyMatchingElements(refs[deviceIndex],
                                                              (__bridge CFDictionaryRef)dic,
                                                              kIOHIDOptionsTypeNone);
        if(!elements)
            continue;
        // iterate over all the elements
        CFIndex i, n = CFArrayGetCount(elements);
        for (i = 0; i < n; i++)
        {
            IOHIDElementRef element = (IOHIDElementRef)CFArrayGetValueAtIndex(elements, i);
            if(!element)
                continue;
            uint32_t usagePage = IOHIDElementGetUsagePage(element);
            // if this isn't an LED element, skip it
            if (kHIDPage_LEDs != usagePage) continue;
            uint32_t elusage = IOHIDElementGetUsage(element);
            if (elusage == usage)
            {
                // set led
                //err = IOHIDDeviceOpen(refs[deviceIndex], 0);
                err = 0;
                if (err == 0) {
                    // create the IO HID Value to be sent to this LED element
                    uint64_t timestamp = 0;
                    IOHIDValueRef val = IOHIDValueCreateWithIntegerValue(kCFAllocatorDefault,
                                                                         element, timestamp,
                                                                         target_value);
                    if (val)
                    {
                        // now set it on the device
                        IOHIDDeviceSetValue(refs[deviceIndex], element, val);
                        CFRelease(val);
                        success = true;
                    }
                    //IOHIDDeviceClose(refs[deviceIndex], 0);
                }
                break;
            }
        }
        CFRelease(elements);
    }

Oops:
    if (mgr) {
        IOHIDManagerClose(mgr, kIOHIDOptionsTypeNone);
        CFRelease(mgr);
    }
    if (deviceCFSetRef)
        CFRelease(deviceCFSetRef);
    if (refs)
        free(refs);

    return success;
}

#pragma clang diagnostic pop
