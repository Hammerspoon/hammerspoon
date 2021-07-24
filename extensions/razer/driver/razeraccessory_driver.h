/*
 * Copyright (c) 2015 Terry Cain <terrys-home.co.uk>
 */

/*
 * This program is free software; you can redistribute it and/or modify it
 * under the terms of the GNU General Public License as published by the Free
 * Software Foundation; either version 2 of the License, or (at your option)
 * any later version.
 */

#include <IOKit/IOKitLib.h>
#include <IOKit/usb/IOUSBLib.h>

#ifndef __HID_RAZER_ACCESSORY_H
#define __HID_RAZER_ACCESSORY_H

#define USB_DEVICE_ID_RAZER_NOMMO_CHROMA 0x0517
#define USB_DEVICE_ID_RAZER_NOMMO_PRO 0x0518
#define USB_DEVICE_ID_RAZER_CHROMA_MUG 0x0F07
#define USB_DEVICE_ID_RAZER_CHROMA_BASE 0x0F08
#define USB_DEVICE_ID_RAZER_CHROMA_HDK 0x0F09
#define USB_DEVICE_ID_RAZER_MOUSE_BUNGEE_V3_CHROMA 0x0F1D
#define USB_DEVICE_ID_RAZER_BASE_STATION_V2_CHROMA 0x0F20

#define RAZER_ACCESSORY_WAIT_MIN_US 600
#define RAZER_ACCESSORY_WAIT_MAX_US 1000

ssize_t razer_accessory_attr_write_mode_none(IOUSBDeviceInterface **usb_dev, const char *buf, size_t count);
ssize_t razer_accessory_attr_write_mode_spectrum(IOUSBDeviceInterface **usb_dev, const char *buf, size_t count);
ssize_t razer_accessory_attr_write_mode_wave(IOUSBDeviceInterface **usb_dev, const char *buf, size_t count, int speed);
ssize_t razer_accessory_attr_write_mode_static(IOUSBDeviceInterface **usb_dev, const char *buf, size_t count);
ssize_t razer_accessory_attr_write_mode_breath(IOUSBDeviceInterface **usb_dev, const char *buf, size_t count);
ushort razer_accessory_attr_read_set_brightness(IOUSBDeviceInterface **usb_dev);
ssize_t razer_accessory_attr_write_set_brightness(IOUSBDeviceInterface **usb_dev, ushort brightness, size_t count);


#endif