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

#ifndef __HID_RAZER_KRAKEN_H
#define __HID_RAZER_KRAKEN_H


#define USB_DEVICE_ID_RAZER_KRAKEN_CLASSIC 0x0501
// Codename Rainie
#define USB_DEVICE_ID_RAZER_KRAKEN 0x0504
// Codename Unknown
#define USB_DEVICE_ID_RAZER_KRAKEN_CLASSIC_ALT 0x0506
// Codename Kylie
#define USB_DEVICE_ID_RAZER_KRAKEN_V2 0x0510
// Codename Unknown
#define USB_DEVICE_ID_RAZER_KRAKEN_ULTIMATE 0x0527

#define USB_INTERFACE_PROTOCOL_NONE 0

// #define RAZER_KRAKEN_V2_REPORT_LEN ?

struct razer_kraken_device {
    unsigned char usb_interface_protocol;
    unsigned short usb_pid;
    unsigned short usb_vid;

    // Will be set with the correct address for setting LED mode for each device
    unsigned short led_mode_address;
    unsigned short custom_address;
    unsigned short breathing_address[3];

    char serial[23];
    // 3 Bytes, first byte is whether fw version is collected, 2nd byte is major version, 3rd is minor, should be printed out in hex form as are bcd
    unsigned char firmware_version[3];

    char data[33];

};

union razer_kraken_effect_byte {
    unsigned char value;
    struct razer_kraken_effect_byte_bits {
        unsigned char on_off_static :1;
        unsigned char single_colour_breathing :1;
        unsigned char spectrum_cycling :1;
        unsigned char sync :1;
        unsigned char two_colour_breathing :1;
        unsigned char three_colour_breathing :1;
    } bits;
};

/*
 * Should wait 15ms per write to EEPROM
 *
 * Report ID:
 *   0x04 - Output ID for memory access
 *   0x05 - Input ID for memory access result
 *
 * Destination:
 *   0x20 - Read data from EEPROM
 *   0x40 - Write data to RAM
 *   0x00 - Read data from RAM
 *
 * Address:
 *   RAM - Both
 *   0x1189 - Custom effect Colour1 Red
 *   0x118A - Custom effect Colour1 Green
 *   0x118B - Custom effect Colour1 Blue
 *   0x118C - Custom effect Colour1 Intensity
 *
 *   RAM - Kylie
 *   0x172D - Set LED Effect, see note 1
 *   0x1741 - Static/Breathing1 Colour1 Red
 *   0x1742 - Static/Breathing1 Colour1 Green
 *   0x1743 - Static/Breathing1 Colour1 Blue
 *   0x1744 - Static/Breathing1 Colour1 Intensity
 *
 *   0x1745 - Breathing2 Colour1 Red
 *   0x1746 - Breathing2 Colour1 Green
 *   0x1747 - Breathing2 Colour1 Blue
 *   0x1748 - Breathing2 Colour1 Intensity
 *   0x1749 - Breathing2 Colour2 Red
 *   0x174A - Breathing2 Colour2 Green
 *   0x174B - Breathing2 Colour2 Blue
 *   0x174C - Breathing2 Colour2 Intensity
 *
 *   0x174D - Breathing3 Colour1 Red
 *   0x174E - Breathing3 Colour1 Green
 *   0x174F - Breathing3 Colour1 Blue
 *   0x1750 - Breathing3 Colour1 Intensity
 *   0x1751 - Breathing3 Colour2 Red
 *   0x1752 - Breathing3 Colour2 Green
 *   0x1753 - Breathing3 Colour2 Blue
 *   0x1754 - Breathing3 Colour2 Intensity
 *   0x1755 - Breathing3 Colour3 Red
 *   0x1756 - Breathing3 Colour3 Green
 *   0x1757 - Breathing3 Colour3 Blue
 *   0x1758 - Breathing3 Colour3 Intensity
 *
 *   RAM - Rainie
 *   0x1008 - Set LED Effect, see note 1
 *   0x15DE - Static/Breathing1 Colour1 Red
 *   0x15DF - Static/Breathing1 Colour1 Green
 *   0x15E0 - Static/Breathing1 Colour1 Blue
 *   0x15E1 - Static/Breathing1 Colour1 Intensity
 *
 *   EEPROM
 *   0x0030 - Firmware version, 2 byted BCD
 *   0x7f00 - Serial Number - 22 Bytes
 *
 *
 * Note 1:
 *   Takes one byte which is a bitfield (0 being the rightmost byte 76543210)
 *     - Bit 0 = LED ON/OFF = 1/0 Static
 *     - Bit 1 = Single Colour Breathing ON/OFF, 1/0
 *     - Bit 2 = Spectrum Cycling
 *     - Bit 3 = Sync = 1
 *     - Bit 4 = 2 Colour breathing ON/OFF = 1/0
 *     - Bit 5 = 3 Colour breathing ON/OFF = 1/0
 *   E.g.
 *    7   6  5  4  3  2  1  0
 *    128 64 32 16 8  4  2  1
 *    =====================================================
 *    0   0  0  0  0  1  0  1 0x05 Spectrum Cycling on
 *
 * Note 2:
 *   Razer Kraken Classic uses 0x1008 for Logo LED on off.
 * */

#define KYLIE_SET_LED_ADDRESS 0x172D
#define RAINIE_SET_LED_ADDRESS 0x1008

#define KYLIE_CUSTOM_ADDRESS_START 0x1189
#define RAINIE_CUSTOM_ADDRESS_START 0x1189

#define KYLIE_BREATHING1_ADDRESS_START 0x1741
#define RAINIE_BREATHING1_ADDRESS_START 0x15DE

#define KYLIE_BREATHING2_ADDRESS_START 0x1745
#define KYLIE_BREATHING3_ADDRESS_START 0x174D


struct razer_kraken_request_report {
    unsigned char report_id;
    unsigned char destination;
    unsigned char length;
    unsigned char addr_h;
    unsigned char addr_l;
    unsigned char arguments[32];
};

struct razer_kraken_response_report {
    unsigned char report_id;
    unsigned char arguments[36];
};



ssize_t razer_kraken_attr_write_mode_none(IOUSBDeviceInterface **dev, const char *buf, size_t count);
ssize_t razer_kraken_attr_write_mode_static(IOUSBDeviceInterface **dev, const char *buf, size_t count);
ssize_t razer_kraken_attr_write_mode_custom(IOUSBDeviceInterface **dev, const char *buf, size_t count);
ssize_t razer_kraken_attr_write_mode_breath(IOUSBDeviceInterface **dev, const char *buf, size_t count);
ssize_t razer_kraken_attr_write_mode_spectrum(IOUSBDeviceInterface **dev, const char *buf, size_t count);

#endif