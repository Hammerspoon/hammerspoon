/*
 * Copyright (c) 2015 Tim Theede <pez2001@voyagerproject.de>
 *               2015 Terry Cain <terry@terrys-home.co.uk>
 *
 * This program is free software; you can redistribute it and/or modify it
 * under the terms of the GNU General Public License as published by the Free
 * Software Foundation; either version 2 of the License, or (at your option)
 * any later version.
 */

#include <IOKit/IOKitLib.h>
#include <IOKit/usb/IOUSBLib.h>

#ifndef __HID_RAZER_MOUSEMAT_H
#define __HID_RAZER_MOUSEMAT_H

#define USB_DEVICE_ID_RAZER_FIREFLY_HYPERFLUX 0x0068
#define USB_DEVICE_ID_RAZER_FIREFLY 0x0C00
#define USB_DEVICE_ID_RAZER_FIREFLY_V2 0x0c04
#define USB_DEVICE_ID_RAZER_GOLIATHUS_CHROMA 0x0C01
#define USB_DEVICE_ID_RAZER_GOLIATHUS_CHROMA_EXTENDED 0x0C02

#define RAZER_MOUSEMAT_WAIT_MIN_US 900
#define RAZER_MOUSEMAT_WAIT_MAX_US 1000

struct razer_mousemat_device {
    struct usb_device *usbdev;
    struct hid_device *hiddev;
    unsigned char effect;
    char name[128];
    char phys[64];
};

ssize_t razer_mouse_mat_attr_write_mode_none(IOUSBDeviceInterface **usb_dev, const char *buf, size_t count);
ssize_t razer_mouse_mat_attr_write_mode_wave(IOUSBDeviceInterface **usb_dev, const char *buf, size_t count);
ssize_t razer_mouse_mat_attr_write_mode_breath(IOUSBDeviceInterface **usb_dev, const char *buf, size_t count);
ssize_t razer_mouse_mat_attr_write_mode_static(IOUSBDeviceInterface **usb_dev, const char *buf, size_t count);
ssize_t razer_mouse_mat_attr_write_mode_static_no_store(IOUSBDeviceInterface **usb_dev, const char *buf, size_t count);
ssize_t razer_mouse_mat_attr_write_mode_spectrum(IOUSBDeviceInterface **usb_dev, const char *buf, size_t count);
ssize_t razer_mouse_mat_attr_write_set_brightness(IOUSBDeviceInterface **usb_dev, ushort brightness, size_t count);
ushort razer_mouse_mat_attr_read_set_brightness(IOUSBDeviceInterface **usb_dev);

#endif