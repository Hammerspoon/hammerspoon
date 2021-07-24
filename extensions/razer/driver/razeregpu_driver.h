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

#ifndef __HID_RAZER_EGPU_H
#define __HID_RAZER_EGPU_H

#define USB_DEVICE_ID_RAZER_CORE_X_CHROMA 0x0f1a

#define RAZER_EGPU_WAIT_MIN_US 900
#define RAZER_EGPU_WAIT_MAX_US 1000

ssize_t razer_egpu_attr_write_mode_none(IOUSBDeviceInterface **usb_dev, const char *buf, size_t count);
ssize_t razer_egpu_attr_write_mode_wave(IOUSBDeviceInterface **usb_dev, const char *buf, size_t count);
ssize_t razer_egpu_attr_write_mode_breath(IOUSBDeviceInterface **usb_dev, const char *buf, size_t count);
ssize_t razer_egpu_attr_write_mode_static(IOUSBDeviceInterface **usb_dev, const char *buf, size_t count);
ssize_t razer_egpu_attr_write_mode_static_no_store(IOUSBDeviceInterface **usb_dev, const char *buf, size_t count);
ssize_t razer_egpu_attr_write_mode_spectrum(IOUSBDeviceInterface **usb_dev, const char *buf, size_t count);

#endif