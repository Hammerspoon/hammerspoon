#include <IOKit/IOKitLib.h>
#include <IOKit/usb/IOUSBLib.h>

#ifndef __HID_RAZER_HEADPHONE_H
#define __HID_RAZER_HEADPHONE_H

#define USB_DEVICE_ID_RAZER_KRAKEN_KITTY_EDITION 0x0F19

#define RAZER_HEADPHONE_WAIT_MIN_US 600
#define RAZER_HEADPHONE_WAIT_MAX_US 1000

struct razer_headphone_device {
    struct usb_device *usbdev;
    struct hid_device *hiddev;
    unsigned char effect;
    char name[128];
    char phys[64];
};

ssize_t razer_headphone_attr_write_mode_none(IOUSBDeviceInterface **usb_dev, const char *buf, size_t count);
ssize_t razer_headphone_attr_write_mode_breath(IOUSBDeviceInterface **usb_dev, const char *buf, size_t count);
ssize_t razer_headphone_attr_write_mode_static(IOUSBDeviceInterface **usb_dev, const char *buf, size_t count);
ssize_t razer_headphone_attr_write_mode_static_no_store(IOUSBDeviceInterface **usb_dev, const char *buf, size_t count);
ssize_t razer_headphone_attr_write_mode_spectrum(IOUSBDeviceInterface **usb_dev, const char *buf, size_t count);

#endif
