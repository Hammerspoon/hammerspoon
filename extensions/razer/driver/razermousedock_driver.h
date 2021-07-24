/*
 * Copyright (c) 2015 Terry Cain <terry@terrys-home.co.uk>
 */

/*
 * This program is free software; you can redistribute it and/or modify it
 * under the terms of the GNU General Public License as published by the Free
 * Software Foundation; either version 2 of the License, or (at your option)
 * any later version.
 */
 
#include <IOKit/IOKitLib.h>
#include <IOKit/usb/IOUSBLib.h>

#ifndef __HID_RAZER_MOUSE_DOCK_H
#define __HID_RAZER_MOUSE_DOCK_H

#define USB_DEVICE_ID_RAZER_MOUSE_CHARGING_DOCK 0x007E

/* Each report has 90 bytes*/
#define RAZER_REPORT_LEN 0x5A

#define RAZER_MOUSE_DOCK_WAIT_MIN_US 600
#define RAZER_MOUSE_DOCK_WAIT_MAX_US 800


ssize_t razer_mouse_dock_attr_write_mode_static(IOUSBDeviceInterface **usb_dev, const char *buf, size_t count);
ssize_t razer_mouse_dock_attr_write_mode_static_no_store(IOUSBDeviceInterface **usb_dev, const char *buf, size_t count);
ssize_t razer_mouse_dock_attr_write_mode_spectrum(IOUSBDeviceInterface **usb_dev, const char *buf, size_t count);
ssize_t razer_mouse_dock_attr_write_mode_breath(IOUSBDeviceInterface **usb_dev, const char *buf, size_t count);
ssize_t razer_mouse_dock_attr_write_mode_none(IOUSBDeviceInterface **usb_dev, const char *buf, size_t count);

#endif