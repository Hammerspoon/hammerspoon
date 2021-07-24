/*
 * Copyright (c) 2015 Tim Theede <pez2001@voyagerproject.de>
 *               2015 Terry Cain <terrys-home.co.uk>
 */

/*
 * This program is free software; you can redistribute it and/or modify it
 * under the terms of the GNU General Public License as published by the Free
 * Software Foundation; either version 2 of the License, or (at your option)
 * any later version.
 */

#include <IOKit/IOKitLib.h>
#include <IOKit/usb/IOUSBLib.h>

#ifndef __HID_RAZER_KBD_H
#define __HID_RAZER_KBD_H

#define USB_DEVICE_ID_RAZER_BLACKWIDOW_ULTIMATE_2012 0x010D
// 2011 or so edition, see https://web.archive.org/web/20111113132427/http://store.razerzone.com:80/store/razerusa/en_US/pd/productID.235228400/categoryId.49136200/parentCategoryId.35156900
#define USB_DEVICE_ID_RAZER_BLACKWIDOW_STEALTH_EDITION 0x010E
#define USB_DEVICE_ID_RAZER_ANANSI 0x010F
#define USB_DEVICE_ID_RAZER_NOSTROMO 0x0111
#define USB_DEVICE_ID_RAZER_ORBWEAVER 0x0113
#define USB_DEVICE_ID_RAZER_BLACKWIDOW_ULTIMATE_2013 0x011A
#define USB_DEVICE_ID_RAZER_BLACKWIDOW_STEALTH 0x011B
#define USB_DEVICE_ID_RAZER_TARTARUS 0x0201
#define USB_DEVICE_ID_RAZER_DEATHSTALKER_EXPERT 0x0202
#define USB_DEVICE_ID_RAZER_BLACKWIDOW_CHROMA 0x0203
#define USB_DEVICE_ID_RAZER_DEATHSTALKER_CHROMA 0x0204
#define USB_DEVICE_ID_RAZER_BLADE_STEALTH 0x0205
#define USB_DEVICE_ID_RAZER_ORBWEAVER_CHROMA 0x0207
#define USB_DEVICE_ID_RAZER_TARTARUS_CHROMA 0x0208
#define USB_DEVICE_ID_RAZER_BLACKWIDOW_CHROMA_TE 0x0209
#define USB_DEVICE_ID_RAZER_BLADE_QHD 0x020F
#define USB_DEVICE_ID_RAZER_BLADE_PRO_LATE_2016 0x0210
#define USB_DEVICE_ID_RAZER_BLACKWIDOW_OVERWATCH 0x0211
#define USB_DEVICE_ID_RAZER_BLACKWIDOW_ULTIMATE_2016 0x0214
#define USB_DEVICE_ID_RAZER_BLACKWIDOW_X_CHROMA 0x0216
#define USB_DEVICE_ID_RAZER_BLACKWIDOW_X_ULTIMATE 0x0217
#define USB_DEVICE_ID_RAZER_BLACKWIDOW_X_CHROMA_TE 0x021A
#define USB_DEVICE_ID_RAZER_ORNATA_CHROMA 0x021E
#define USB_DEVICE_ID_RAZER_ORNATA 0x021F
#define USB_DEVICE_ID_RAZER_ORNATA_CHROMA_V2 0x025D
#define USB_DEVICE_ID_RAZER_BLADE_STEALTH_LATE_2016 0x0220
#define USB_DEVICE_ID_RAZER_BLACKWIDOW_CHROMA_V2 0x0221
#define USB_DEVICE_ID_RAZER_BLACKWIDOW_V3 0x024e
#define USB_DEVICE_ID_RAZER_BLADE_LATE_2016 0x0224
#define USB_DEVICE_ID_RAZER_BLADE_PRO_2017 0x0225
#define USB_DEVICE_ID_RAZER_HUNTSMAN_ELITE 0x0226
#define USB_DEVICE_ID_RAZER_HUNTSMAN 0x0227
#define USB_DEVICE_ID_RAZER_BLACKWIDOW_ELITE 0x0228
#define USB_DEVICE_ID_RAZER_CYNOSA_CHROMA 0x022A
#define USB_DEVICE_ID_RAZER_TARTARUS_V2 0x022B
#define USB_DEVICE_ID_RAZER_BLADE_STEALTH_MID_2017 0x022D
#define USB_DEVICE_ID_RAZER_BLADE_PRO_2017_FULLHD 0x022F
#define USB_DEVICE_ID_RAZER_BLADE_STEALTH_LATE_2017 0x0232
#define USB_DEVICE_ID_RAZER_BLADE_2018 0x0233
#define USB_DEVICE_ID_RAZER_BLACKWIDOW_LITE 0x0235
#define USB_DEVICE_ID_RAZER_BLACKWIDOW_ESSENTIAL 0x0237
#define USB_DEVICE_ID_RAZER_BLADE_STEALTH_2019 0x0239
#define USB_DEVICE_ID_RAZER_BLADE_2019_ADV 0x023a
#define USB_DEVICE_ID_RAZER_BLADE_2018_BASE 0x023b
#define USB_DEVICE_ID_RAZER_BLADE_2018_MERCURY 0x0240
#define USB_DEVICE_ID_RAZER_BLACKWIDOW_2019 0x0241
#define USB_DEVICE_ID_RAZER_HUNTSMAN_TE 0x0243
#define USB_DEVICE_ID_RAZER_BLADE_MID_2019_MERCURY 0x0245
#define USB_DEVICE_ID_RAZER_BLADE_2019_BASE 0x0246
#define USB_DEVICE_ID_RAZER_BLADE_STEALTH_LATE_2019 0x024a
#define USB_DEVICE_ID_RAZER_BLADE_STUDIO_EDITION_2019 0x024d
#define USB_DEVICE_ID_RAZER_CYNOSA_V2 0x025E
#define USB_DEVICE_ID_RAZER_CYNOSA_LITE 0x023F
#define USB_DEVICE_ID_RAZER_BLACKWIDOW_V3_TK 0x0a24
#define USB_DEVICE_ID_RAZER_HUNTSMAN_MINI 0x0257

/* Each keyboard report has 90 bytes*/
#define RAZER_BLACKWIDOW_REPORT_LEN 0x5A

#define RAZER_BLACKWIDOW_CHROMA_WAVE_DIRECTION_LEFT 2
#define RAZER_BLACKWIDOW_CHROMA_WAVE_DIRECTION_RIGHT 1

#define RAZER_BLACKWIDOW_CHROMA_CHANGE_EFFECT 0x0A

#define RAZER_BLACKWIDOW_CHROMA_EFFECT_NONE 0
#define RAZER_BLACKWIDOW_CHROMA_EFFECT_WAVE 1
#define RAZER_BLACKWIDOW_CHROMA_EFFECT_REACTIVE 2
#define RAZER_BLACKWIDOW_CHROMA_EFFECT_BREATH 3
#define RAZER_BLACKWIDOW_CHROMA_EFFECT_SPECTRUM 4
#define RAZER_BLACKWIDOW_CHROMA_EFFECT_CUSTOM 5 // draw frame
#define RAZER_BLACKWIDOW_CHROMA_EFFECT_STATIC 6
#define RAZER_BLACKWIDOW_CHROMA_EFFECT_CLEAR_ROW 8

#define RAZER_BLACKWIDOW_ULTIMATE_2016_EFFECT_STARLIGHT 0x19


#define RAZER_BLACKWIDOW_CHROMA_EFFECT_SET_KEYS 9 //update profile needs to be called after setting keys to reflect changes
#define RAZER_BLACKWIDOW_CHROMA_EFFECT_RESET 10
#define RAZER_BLACKWIDOW_CHROMA_EFFECT_UNKNOWN 11
#define RAZER_BLACKWIDOW_CHROMA_EFFECT_UNKNOWN2 12
#define RAZER_BLACKWIDOW_CHROMA_EFFECT_UNKNOWN3 13
#define RAZER_BLACKWIDOW_CHROMA_EFFECT_UNKNOWN4 14


#define RAZER_BLACKWIDOW_CHROMA_ROW_LEN 0x16
#define RAZER_BLACKWIDOW_CHROMA_ROWS_NUM 6


#define RAZER_STEALTH_ROW_LEN 0x10
#define RAZER_STEALTH_ROWS_NUM 6



#define RAZER_BLACKWIDOW_CHROMA_WAIT_MS 1
#define RAZER_BLACKWIDOW_CHROMA_WAIT_MIN_US 600
#define RAZER_BLACKWIDOW_CHROMA_WAIT_MAX_US 800

#define RAZER_FIREFLY_WAIT_MIN_US 900
#define RAZER_FIREFLY_WAIT_MAX_US 1000


// struct razer_kbd_device {
//     IOUSBDeviceInterface **usbdev;
//     unsigned int fn_on;
//     char name[128];
//     char phys[64];

//     unsigned char block_keys[3];
//     unsigned char left_alt_on;
// };

bool is_blade_laptop(IOUSBDeviceInterface **usb_dev);

ssize_t razer_attr_read_mode_game(IOUSBDeviceInterface **usb_dev, char *buf);
ssize_t razer_attr_write_mode_macro(IOUSBDeviceInterface **usb_dev, const char *buf, int count);
ssize_t razer_attr_write_mode_macro_effect(IOUSBDeviceInterface **usb_dev, const char *buf, int count);
ssize_t razer_attr_read_mode_macro_effect(IOUSBDeviceInterface **usb_dev, char *buf);
ssize_t razer_attr_write_mode_pulsate(IOUSBDeviceInterface **usb_dev, const char *buf, int count);
ssize_t razer_attr_read_mode_pulsate(IOUSBDeviceInterface **usb_dev, char *buf);
ssize_t razer_attr_read_tartarus_profile_led_red(IOUSBDeviceInterface **usb_dev, char *buf);
ssize_t razer_attr_read_tartarus_profile_led_green(IOUSBDeviceInterface **usb_dev, char *buf);
ssize_t razer_attr_read_tartarus_profile_led_blue(IOUSBDeviceInterface **usb_dev, char *buf);
ssize_t razer_attr_read_get_firmware_version(IOUSBDeviceInterface **usb_dev, char *buf);
ssize_t razer_attr_write_mode_none(IOUSBDeviceInterface **usb_dev, const char *buf, int count);
ssize_t razer_attr_write_mode_wave(IOUSBDeviceInterface **usb_dev, const char *buf, int count, int speed);
ssize_t razer_attr_write_mode_spectrum(IOUSBDeviceInterface **usb_dev, const char *buf, int count);
ssize_t razer_attr_write_mode_reactive(IOUSBDeviceInterface **usb_dev, const char *buf, int count);
ssize_t razer_attr_write_mode_static(IOUSBDeviceInterface **usb_dev, const char *buf, int count);
ssize_t razer_attr_write_mode_static_no_store(IOUSBDeviceInterface **usb_dev, const char *buf, int count);
ssize_t razer_attr_write_mode_starlight(IOUSBDeviceInterface **usb_dev, const char *buf, int count);
ssize_t razer_attr_write_mode_breath(IOUSBDeviceInterface **usb_dev, const char *buf, int count);
ssize_t razer_attr_read_set_logo(IOUSBDeviceInterface **usb_dev, char *buf, int count);
ssize_t razer_attr_write_set_logo(IOUSBDeviceInterface **usb_dev, const char *buf, int count);
ssize_t razer_attr_write_mode_custom(IOUSBDeviceInterface **usb_dev, const char *buf, int count);
ssize_t razer_attr_write_set_fn_toggle(IOUSBDeviceInterface **usb_dev, const char *buf, int count);
ssize_t razer_attr_write_set_brightness(IOUSBDeviceInterface **usb_dev, ushort brightness, int count);
ushort razer_attr_read_set_brightness(IOUSBDeviceInterface **usb_dev);
ssize_t razer_attr_write_matrix_custom_frame(IOUSBDeviceInterface **usb_dev, const char *buf, int count);
#endif
