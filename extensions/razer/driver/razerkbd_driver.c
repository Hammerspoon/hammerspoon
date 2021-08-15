/*
 * This program is free software; you can redistribute it and/or modify
 * it under the terms of the GNU General Public License as published by
 * the Free Software Foundation; either version 2 of the License, or
 * (at your option) any later version.
 *
 * This program is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 * GNU General Public License for more details.
 *
 * You should have received a copy of the GNU General Public License
 * along with this program; if not, write to the Free Software
 * Foundation, Inc., 51 Franklin Street, Fifth Floor, Boston, MA 02110-1301, USA
 *
 * Should you need to contact me, the author, you can do so by
 * e-mail - mail your message to Terry Cain <terry@terrys-home.co.uk>
 */

#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <math.h>

#include "razerkbd_driver.h"
#include "razerchromacommon.h"
#include "razercommon.h"

static struct razer_report razer_send_payload(IOUSBDeviceInterface **dev, struct razer_report *request_report);

bool is_blade_laptop(IOUSBDeviceInterface **usb_dev)
{
    UInt16 product = -1;
    (*usb_dev)->GetDeviceProduct(usb_dev, &product);

    switch (product)
    {
    case USB_DEVICE_ID_RAZER_BLADE_STEALTH:
    case USB_DEVICE_ID_RAZER_BLADE_STEALTH_LATE_2016:
    case USB_DEVICE_ID_RAZER_BLADE_PRO_LATE_2016:
    case USB_DEVICE_ID_RAZER_BLADE_2018:
    case USB_DEVICE_ID_RAZER_BLADE_2018_MERCURY:
    case USB_DEVICE_ID_RAZER_BLADE_2018_BASE:
    case USB_DEVICE_ID_RAZER_BLADE_2019_ADV:
    case USB_DEVICE_ID_RAZER_BLADE_MID_2019_MERCURY:
    case USB_DEVICE_ID_RAZER_BLADE_STUDIO_EDITION_2019:
    case USB_DEVICE_ID_RAZER_BLADE_QHD:
    case USB_DEVICE_ID_RAZER_BLADE_LATE_2016:
    case USB_DEVICE_ID_RAZER_BLADE_STEALTH_MID_2017:
    case USB_DEVICE_ID_RAZER_BLADE_STEALTH_LATE_2017:
    case USB_DEVICE_ID_RAZER_BLADE_STEALTH_2019:
    case USB_DEVICE_ID_RAZER_BLADE_PRO_2017:
    case USB_DEVICE_ID_RAZER_BLADE_PRO_2017_FULLHD:
    case USB_DEVICE_ID_RAZER_BLADE_2019_BASE:
    case USB_DEVICE_ID_RAZER_BLADE_STEALTH_LATE_2019:
        return true;
    }

    return false;
}

/**
 * Read device file "game_mode"
 *
 * Returns a string
 */
ssize_t razer_attr_read_mode_game(IOUSBDeviceInterface **usb_dev, char *buf)
{
    struct razer_report report = razer_chroma_standard_get_led_state(VARSTORE, GAME_LED);
    struct razer_report response;

    response = razer_send_payload(usb_dev, &report);
    return sprintf(buf, "%d\n", response.arguments[2]);
}

/**
 * Write device file "mode_macro" 
 *
 * When 1 is written (as a character, 0x31) Macro mode will be enabled, if 0 is written (0x30)
 * then game mode will be disabled
 */
ssize_t razer_attr_write_mode_macro(IOUSBDeviceInterface **usb_dev, const char *buf, int count)
{
    unsigned char enabled = (unsigned char)strtol(buf, NULL, 10);
    struct razer_report report = razer_chroma_standard_set_led_state(VARSTORE, MACRO_LED, enabled);

    razer_send_payload(usb_dev, &report);

    return count;
}

/**
 * Write device file "mode_macro_effect"
 *
 * When 1 is written the LED will blink, 0 will static
 */
ssize_t razer_attr_write_mode_macro_effect(IOUSBDeviceInterface **usb_dev, const char *buf, int count)
{

    struct razer_report report = {0};
    unsigned char enabled = (unsigned char)strtoul(buf, NULL, 10);

    UInt16 product = -1;
    (*usb_dev)->GetDeviceProduct(usb_dev, &product);

    switch (product)
    {
    case USB_DEVICE_ID_RAZER_BLACKWIDOW_LITE:
    case USB_DEVICE_ID_RAZER_ORNATA:
    case USB_DEVICE_ID_RAZER_ORNATA_CHROMA:
    case USB_DEVICE_ID_RAZER_ORNATA_CHROMA_V2:
    case USB_DEVICE_ID_RAZER_HUNTSMAN_ELITE:
    case USB_DEVICE_ID_RAZER_HUNTSMAN_TE:
    case USB_DEVICE_ID_RAZER_BLACKWIDOW_2019:
    case USB_DEVICE_ID_RAZER_HUNTSMAN:
    case USB_DEVICE_ID_RAZER_BLACKWIDOW_ESSENTIAL:
    case USB_DEVICE_ID_RAZER_CYNOSA_CHROMA:
    case USB_DEVICE_ID_RAZER_CYNOSA_LITE:
    case USB_DEVICE_ID_RAZER_BLACKWIDOW_V3:
    case USB_DEVICE_ID_RAZER_BLACKWIDOW_V3_TK:
    case USB_DEVICE_ID_RAZER_HUNTSMAN_MINI:
        report = razer_chroma_standard_set_led_effect(NOSTORE, MACRO_LED, enabled);
        report.transaction_id.id = 0x3F;
        break;

    case USB_DEVICE_ID_RAZER_TARTARUS_V2:
    case USB_DEVICE_ID_RAZER_BLACKWIDOW_ELITE:
        report = razer_chroma_standard_set_led_effect(NOSTORE, MACRO_LED, enabled);
        report.transaction_id.id = 0x1F;
        break;

    case USB_DEVICE_ID_RAZER_ANANSI:
        report = razer_chroma_standard_set_led_effect(NOSTORE, MACRO_LED, enabled);
        razer_send_payload(usb_dev, &report);

        report = razer_chroma_standard_set_led_blinking(NOSTORE, MACRO_LED);
        break;

    default:
        report = razer_chroma_standard_set_led_effect(VARSTORE, MACRO_LED, enabled);
        break;
    }
    razer_send_payload(usb_dev, &report);

    return count;
}

/**
 * Read device file "macro_mode_effect"
 *
 * Returns a string
 */
ssize_t razer_attr_read_mode_macro_effect(IOUSBDeviceInterface **usb_dev, char *buf)
{
    struct razer_report report = razer_chroma_standard_get_led_effect(VARSTORE, MACRO_LED);
    struct razer_report response = razer_send_payload(usb_dev, &report);

    return sprintf(buf, "%d\n", response.arguments[2]);
}

/**
 * Write device file "mode_pulsate"
 *
 * The brightness oscillates between fully on and fully off generating a pulsing effect
 */
ssize_t razer_attr_write_mode_pulsate(IOUSBDeviceInterface **usb_dev, const char *buf, int count)
{
    struct razer_report report = razer_chroma_standard_set_led_effect(VARSTORE, BACKLIGHT_LED, 0x02);
    razer_send_payload(usb_dev, &report);

    UInt16 product = -1;
    (*usb_dev)->GetDeviceProduct(usb_dev, &product);

    switch (product)
    {
    case USB_DEVICE_ID_RAZER_BLACKWIDOW_STEALTH:
    case USB_DEVICE_ID_RAZER_BLACKWIDOW_STEALTH_EDITION:
    case USB_DEVICE_ID_RAZER_BLACKWIDOW_ULTIMATE_2012:
    case USB_DEVICE_ID_RAZER_BLACKWIDOW_ULTIMATE_2013:
        report = razer_chroma_standard_set_led_effect(VARSTORE, LOGO_LED, 0x02);
        break;
    }

    return count;
}

/**
 * Read device file "mode_pulsate"
 *
 * Returns a string
 */
ssize_t razer_attr_read_mode_pulsate(IOUSBDeviceInterface **usb_dev, char *buf)
{
    struct razer_report report = razer_chroma_standard_get_led_effect(VARSTORE, LOGO_LED);
    struct razer_report response = razer_send_payload(usb_dev, &report);

    return sprintf(buf, "%d\n", response.arguments[2]);
}

/**
 * Read device file "profile_led_red"
 *
 * Actually a Yellow LED
 *
 * Returns a string
 */
ssize_t razer_attr_read_tartarus_profile_led_red(IOUSBDeviceInterface **usb_dev, char *buf)
{
    struct razer_report report = razer_chroma_standard_get_led_state(VARSTORE, RED_PROFILE_LED);
    struct razer_report response = razer_send_payload(usb_dev, &report);

    // CHRIS MODIFIED:
    //return sprintf(buf, "%d\n", response.arguments[2]);
    
    return response.arguments[2];
}

/**
 * Read device file "profile_led_green"
 *
 * Returns a string
 */
ssize_t razer_attr_read_tartarus_profile_led_green(IOUSBDeviceInterface **usb_dev, char *buf)
{
    struct razer_report report = razer_chroma_standard_get_led_state(VARSTORE, GREEN_PROFILE_LED);
    struct razer_report response = razer_send_payload(usb_dev, &report);

    // CHRIS MODIFIED:
    //return sprintf(buf, "%d\n", response.arguments[2]);
    
    return response.arguments[2];
    
}

/**
 * Read device file "profile_led_blue"
 *
 * Returns a string
 */
ssize_t razer_attr_read_tartarus_profile_led_blue(IOUSBDeviceInterface **usb_dev, char *buf)
{
    struct razer_report report = razer_chroma_standard_get_led_state(VARSTORE, BLUE_PROFILE_LED);
    struct razer_report response = razer_send_payload(usb_dev, &report);

    // CHRIS MODIFIED:
    //return sprintf(buf, "%d\n", response.arguments[2]);
    
    return response.arguments[2];
}

/**
 * Read device file "get_firmware_version"
 *
 * Returns a string
 */
ssize_t razer_attr_read_get_firmware_version(IOUSBDeviceInterface **usb_dev, char *buf)
{
    struct razer_report report = razer_chroma_standard_get_firmware_version();
    struct razer_report response_report = razer_send_payload(usb_dev, &report);
    
    return sprintf(buf, "v%d.%d\n", response_report.arguments[0], response_report.arguments[1]);
}

// Added by Chris:
ssize_t razer_attr_read_get_firmware_version_major(IOUSBDeviceInterface **usb_dev, char *buf)
{
    struct razer_report report = razer_chroma_standard_get_firmware_version();
    struct razer_report response_report = razer_send_payload(usb_dev, &report);
    
    unsigned char major = response_report.arguments[0];
    
    return major;
}

// Added by Chris:
ssize_t razer_attr_read_get_firmware_version_minor(IOUSBDeviceInterface **usb_dev, char *buf)
{
    struct razer_report report = razer_chroma_standard_get_firmware_version();
    struct razer_report response_report = razer_send_payload(usb_dev, &report);
        
    unsigned char minor = response_report.arguments[1];
    
    return minor;
}

/**
 * Write device file "mode_none"
 *
 * No keyboard effect is activated whenever this file is written to
 */
ssize_t razer_attr_write_mode_none(IOUSBDeviceInterface **usb_dev, const char *buf, int count)
{
    struct razer_report report = {0};
    razer_chroma_standard_matrix_effect_none(VARSTORE, BACKLIGHT_LED);

    UInt16 product = -1;
    (*usb_dev)->GetDeviceProduct(usb_dev, &product);

    switch (product)
    {
    case USB_DEVICE_ID_RAZER_BLACKWIDOW_LITE:
    case USB_DEVICE_ID_RAZER_ORNATA:
    case USB_DEVICE_ID_RAZER_ORNATA_CHROMA:
    case USB_DEVICE_ID_RAZER_HUNTSMAN_ELITE:
    case USB_DEVICE_ID_RAZER_HUNTSMAN_TE:
    case USB_DEVICE_ID_RAZER_BLACKWIDOW_2019:
    case USB_DEVICE_ID_RAZER_HUNTSMAN:
    case USB_DEVICE_ID_RAZER_BLACKWIDOW_ESSENTIAL:
    case USB_DEVICE_ID_RAZER_CYNOSA_CHROMA:
    case USB_DEVICE_ID_RAZER_CYNOSA_LITE:
    case USB_DEVICE_ID_RAZER_BLACKWIDOW_V3_TK:
    case USB_DEVICE_ID_RAZER_HUNTSMAN_MINI:
        report = razer_chroma_extended_matrix_effect_none(VARSTORE, BACKLIGHT_LED);
        break;

    case USB_DEVICE_ID_RAZER_TARTARUS_V2:
    case USB_DEVICE_ID_RAZER_BLACKWIDOW_ELITE:
    case USB_DEVICE_ID_RAZER_CYNOSA_V2:
    case USB_DEVICE_ID_RAZER_BLACKWIDOW_V3:
    case USB_DEVICE_ID_RAZER_ORNATA_CHROMA_V2:
        report = razer_chroma_extended_matrix_effect_none(VARSTORE, BACKLIGHT_LED);
        report.transaction_id.id = 0x1F;
        break;

    case USB_DEVICE_ID_RAZER_ANANSI:
        report = razer_chroma_standard_set_led_state(VARSTORE, BACKLIGHT_LED, OFF);
        break;

    case USB_DEVICE_ID_RAZER_BLACKWIDOW_CHROMA_V2:
        report = razer_chroma_standard_matrix_effect_none(VARSTORE, BACKLIGHT_LED);
        report.transaction_id.id = 0x3F; // TODO move to a usb_device variable
        break;

    default:
        report = razer_chroma_standard_matrix_effect_none(VARSTORE, BACKLIGHT_LED);
        break;
    }

    razer_send_payload(usb_dev, &report);

    return count;
}

/**
 * Write device file "mode_wave"
 *
 * When 1 is written (as a character, 0x31) the wave effect is displayed moving left across the keyboard
 * if 2 is written (0x32) then the wave effect goes right
 *
 * For the extended its 0x00 and 0x01
 */
ssize_t razer_attr_write_mode_wave(IOUSBDeviceInterface **usb_dev, const char *buf, int count, int speed)
{
    unsigned char direction = (unsigned char)strtol(buf, NULL, 10);
    struct razer_report report;

    UInt16 product = -1;
    (*usb_dev)->GetDeviceProduct(usb_dev, &product);

    switch (product)
    {
    case USB_DEVICE_ID_RAZER_ORNATA:
    case USB_DEVICE_ID_RAZER_ORNATA_CHROMA:
    case USB_DEVICE_ID_RAZER_HUNTSMAN_ELITE:
    case USB_DEVICE_ID_RAZER_HUNTSMAN_TE:
    case USB_DEVICE_ID_RAZER_BLACKWIDOW_2019:
    case USB_DEVICE_ID_RAZER_HUNTSMAN:
    case USB_DEVICE_ID_RAZER_BLACKWIDOW_ESSENTIAL:
    case USB_DEVICE_ID_RAZER_CYNOSA_CHROMA:
    case USB_DEVICE_ID_RAZER_BLACKWIDOW_V3:
    case USB_DEVICE_ID_RAZER_BLACKWIDOW_V3_TK:
    case USB_DEVICE_ID_RAZER_HUNTSMAN_MINI:
        report = razer_chroma_extended_matrix_effect_wave(VARSTORE, BACKLIGHT_LED, direction, speed);
        break;

    case USB_DEVICE_ID_RAZER_BLACKWIDOW_CHROMA_V2:
        report = razer_chroma_standard_matrix_effect_wave(VARSTORE, BACKLIGHT_LED, direction);
        report.transaction_id.id = 0x3F; // TODO move to a usb_device variable
        break;

    case USB_DEVICE_ID_RAZER_TARTARUS_V2:
    case USB_DEVICE_ID_RAZER_BLACKWIDOW_ELITE:
    case USB_DEVICE_ID_RAZER_CYNOSA_V2:
    case USB_DEVICE_ID_RAZER_ORNATA_CHROMA_V2:
        report = razer_chroma_extended_matrix_effect_wave(VARSTORE, BACKLIGHT_LED, direction, speed);
        report.transaction_id.id = 0x1F;
        break;

    default:
        report = razer_chroma_standard_matrix_effect_wave(VARSTORE, BACKLIGHT_LED, direction);
        break;
    }
    razer_send_payload(usb_dev, &report);

    return count;
}
/**
 * Write device file "mode_spectrum"
 *
 * Specrum effect mode is activated whenever the file is written to
 */
ssize_t razer_attr_write_mode_spectrum(IOUSBDeviceInterface **usb_dev, const char *buf, int count)
{
    struct razer_report report = {0};

    UInt16 product = -1;
    (*usb_dev)->GetDeviceProduct(usb_dev, &product);

    switch (product)
    {
    case USB_DEVICE_ID_RAZER_ORNATA:
    case USB_DEVICE_ID_RAZER_ORNATA_CHROMA:
    case USB_DEVICE_ID_RAZER_HUNTSMAN_ELITE:
    case USB_DEVICE_ID_RAZER_HUNTSMAN_TE:
    case USB_DEVICE_ID_RAZER_BLACKWIDOW_2019:
    case USB_DEVICE_ID_RAZER_HUNTSMAN:
    case USB_DEVICE_ID_RAZER_CYNOSA_CHROMA:
    case USB_DEVICE_ID_RAZER_CYNOSA_LITE:
    case USB_DEVICE_ID_RAZER_BLACKWIDOW_V3:
    case USB_DEVICE_ID_RAZER_BLACKWIDOW_V3_TK:
    case USB_DEVICE_ID_RAZER_HUNTSMAN_MINI:
        report = razer_chroma_extended_matrix_effect_spectrum(VARSTORE, BACKLIGHT_LED);
        break;

    case USB_DEVICE_ID_RAZER_BLACKWIDOW_ELITE:
    case USB_DEVICE_ID_RAZER_CYNOSA_V2:
    case USB_DEVICE_ID_RAZER_ORNATA_CHROMA_V2:
        report = razer_chroma_extended_matrix_effect_spectrum(VARSTORE, BACKLIGHT_LED);
        report.transaction_id.id = 0x1F;
        break;

    case USB_DEVICE_ID_RAZER_ANANSI:
        report = razer_chroma_standard_set_led_state(VARSTORE, BACKLIGHT_LED, ON);
        razer_send_payload(usb_dev, &report);
        report = razer_chroma_standard_set_led_effect(VARSTORE, BACKLIGHT_LED, LED_SPECTRUM_CYCLING);
        break;

    case USB_DEVICE_ID_RAZER_TARTARUS_V2:
        report = razer_chroma_extended_matrix_effect_spectrum(VARSTORE, BACKLIGHT_LED);
        report.transaction_id.id = 0x1F; // TODO move to a usb_device variable
        break;

    case USB_DEVICE_ID_RAZER_BLACKWIDOW_CHROMA_V2:
        report = razer_chroma_standard_matrix_effect_spectrum(VARSTORE, BACKLIGHT_LED);
        report.transaction_id.id = 0x3F; // TODO move to a usb_device variable
        break;

    default:
        report = razer_chroma_standard_matrix_effect_spectrum(VARSTORE, BACKLIGHT_LED);
        break;
    }

    razer_send_payload(usb_dev, &report);

    return count;
}

/**
 * Write device file "mode_reactive"
 *
 * Sets reactive mode when this file is written to. A speed byte and 3 RGB bytes should be written
 */
ssize_t razer_attr_write_mode_reactive(IOUSBDeviceInterface **usb_dev, const char *buf, int count)
{
    struct razer_report report;

    UInt16 product = -1;
    (*usb_dev)->GetDeviceProduct(usb_dev, &product);
    if (count == 4)
    {
        unsigned char speed = (unsigned char)buf[0];
        switch (product)
        {
        case USB_DEVICE_ID_RAZER_ORNATA:
        case USB_DEVICE_ID_RAZER_ORNATA_CHROMA:
        case USB_DEVICE_ID_RAZER_HUNTSMAN_ELITE:
        case USB_DEVICE_ID_RAZER_HUNTSMAN_TE:
        case USB_DEVICE_ID_RAZER_BLACKWIDOW_2019:
        case USB_DEVICE_ID_RAZER_HUNTSMAN:
        case USB_DEVICE_ID_RAZER_CYNOSA_CHROMA:
        case USB_DEVICE_ID_RAZER_BLACKWIDOW_V3:
        case USB_DEVICE_ID_RAZER_BLACKWIDOW_V3_TK:
        case USB_DEVICE_ID_RAZER_HUNTSMAN_MINI:
            report = razer_chroma_extended_matrix_effect_reactive(VARSTORE, BACKLIGHT_LED, speed, (struct razer_rgb *)&buf[1]);
            break;

        case USB_DEVICE_ID_RAZER_TARTARUS_V2:
        case USB_DEVICE_ID_RAZER_BLACKWIDOW_ELITE:
        case USB_DEVICE_ID_RAZER_CYNOSA_V2:
        case USB_DEVICE_ID_RAZER_ORNATA_CHROMA_V2:
            report = razer_chroma_extended_matrix_effect_reactive(VARSTORE, BACKLIGHT_LED, speed, (struct razer_rgb *)&buf[1]);
            report.transaction_id.id = 0x1F;
            break;

        case USB_DEVICE_ID_RAZER_BLACKWIDOW_CHROMA_V2:
            report = razer_chroma_standard_matrix_effect_reactive(VARSTORE, BACKLIGHT_LED, speed, (struct razer_rgb *)&buf[1]);
            report.transaction_id.id = 0x3F; // TODO move to a usb_device variable
            break;
        default:
            report = razer_chroma_standard_matrix_effect_reactive(VARSTORE, BACKLIGHT_LED, speed, (struct razer_rgb *)&buf[1]);
            break;
        }
        razer_send_payload(usb_dev, &report);
    }
    else
    {
        printf("razerkbd: Reactive only accepts Speed, RGB (4byte)\n");
    }

    return count;
}

/**
 * Write device file "mode_static"
 *
 * Set the keyboard to mode when 3 RGB bytes are written
 */
ssize_t razer_attr_write_mode_static(IOUSBDeviceInterface **usb_dev, const char *buf, int count)
{
    struct razer_report report = {0};

    UInt16 product = -1;
    (*usb_dev)->GetDeviceProduct(usb_dev, &product);

    switch (product)
    {

    case USB_DEVICE_ID_RAZER_TARTARUS_V2:
        report = razer_chroma_extended_matrix_effect_static(VARSTORE, BACKLIGHT_LED, (struct razer_rgb *)&buf[0]);
        razer_send_payload(usb_dev, &report);
        report.transaction_id.id = 0x1F;
        break;

    case USB_DEVICE_ID_RAZER_ORBWEAVER:
    case USB_DEVICE_ID_RAZER_DEATHSTALKER_EXPERT:
        report = razer_chroma_standard_set_led_effect(VARSTORE, BACKLIGHT_LED, 0x00);
        razer_send_payload(usb_dev, &report);
        break;

    case USB_DEVICE_ID_RAZER_BLACKWIDOW_STEALTH:
    case USB_DEVICE_ID_RAZER_BLACKWIDOW_STEALTH_EDITION:
    case USB_DEVICE_ID_RAZER_BLACKWIDOW_ULTIMATE_2012:
    case USB_DEVICE_ID_RAZER_BLACKWIDOW_ULTIMATE_2013: // Doesn't need any parameters as can only do one type of static
        report = razer_chroma_standard_set_led_effect(VARSTORE, LOGO_LED, 0x00);
        razer_send_payload(usb_dev, &report);
        break;

    case USB_DEVICE_ID_RAZER_BLACKWIDOW_OVERWATCH:
    case USB_DEVICE_ID_RAZER_BLACKWIDOW_CHROMA:
    case USB_DEVICE_ID_RAZER_DEATHSTALKER_CHROMA:
    case USB_DEVICE_ID_RAZER_BLACKWIDOW_CHROMA_TE:
    case USB_DEVICE_ID_RAZER_BLACKWIDOW_X_CHROMA:
    case USB_DEVICE_ID_RAZER_BLACKWIDOW_X_CHROMA_TE:
    case USB_DEVICE_ID_RAZER_BLACKWIDOW_ULTIMATE_2016:
    case USB_DEVICE_ID_RAZER_BLACKWIDOW_X_ULTIMATE:
    case USB_DEVICE_ID_RAZER_BLADE_STEALTH:
    case USB_DEVICE_ID_RAZER_BLADE_STEALTH_LATE_2016:
    case USB_DEVICE_ID_RAZER_BLADE_STEALTH_MID_2017:
    case USB_DEVICE_ID_RAZER_BLADE_STEALTH_LATE_2017:
    case USB_DEVICE_ID_RAZER_BLADE_STEALTH_2019:
    case USB_DEVICE_ID_RAZER_BLADE_STEALTH_LATE_2019:
    case USB_DEVICE_ID_RAZER_BLADE_QHD:
    case USB_DEVICE_ID_RAZER_BLADE_PRO_LATE_2016:
    case USB_DEVICE_ID_RAZER_BLADE_2018:
    case USB_DEVICE_ID_RAZER_BLADE_2018_MERCURY:
    case USB_DEVICE_ID_RAZER_BLADE_2018_BASE:
    case USB_DEVICE_ID_RAZER_BLADE_2019_ADV:
    case USB_DEVICE_ID_RAZER_BLADE_2019_BASE:
    case USB_DEVICE_ID_RAZER_BLADE_MID_2019_MERCURY:
    case USB_DEVICE_ID_RAZER_BLADE_STUDIO_EDITION_2019:
    case USB_DEVICE_ID_RAZER_BLADE_LATE_2016:
    case USB_DEVICE_ID_RAZER_BLADE_PRO_2017:
    case USB_DEVICE_ID_RAZER_BLADE_PRO_2017_FULLHD:
    case USB_DEVICE_ID_RAZER_TARTARUS:
    case USB_DEVICE_ID_RAZER_TARTARUS_CHROMA:
    case USB_DEVICE_ID_RAZER_ORBWEAVER_CHROMA:
        if (count == 3)
        {
            report = razer_chroma_standard_matrix_effect_static(VARSTORE, BACKLIGHT_LED, (struct razer_rgb *)&buf[0]);
            razer_send_payload(usb_dev, &report);
        }
        else
        {
            printf("razerkbd: Static mode only accepts RGB (3byte)");
        }
        break;

    case USB_DEVICE_ID_RAZER_BLACKWIDOW_CHROMA_V2:
        if (count == 3)
        {
            report = razer_chroma_standard_matrix_effect_static(VARSTORE, BACKLIGHT_LED, (struct razer_rgb *)&buf[0]);
            report.transaction_id.id = 0x3F; // TODO move to a usb_device variable
            razer_send_payload(usb_dev, &report);
        }
        else
        {
            printf("razerkbd: Static mode only accepts RGB (3byte)");
        }
        break;

    case USB_DEVICE_ID_RAZER_BLACKWIDOW_LITE:
    case USB_DEVICE_ID_RAZER_ORNATA:
    case USB_DEVICE_ID_RAZER_ORNATA_CHROMA:
    case USB_DEVICE_ID_RAZER_HUNTSMAN_ELITE:
    case USB_DEVICE_ID_RAZER_HUNTSMAN_TE:
    case USB_DEVICE_ID_RAZER_BLACKWIDOW_2019:
    case USB_DEVICE_ID_RAZER_HUNTSMAN:
    case USB_DEVICE_ID_RAZER_BLACKWIDOW_ESSENTIAL:
    case USB_DEVICE_ID_RAZER_CYNOSA_CHROMA:
    case USB_DEVICE_ID_RAZER_CYNOSA_LITE:
    case USB_DEVICE_ID_RAZER_BLACKWIDOW_V3:
    case USB_DEVICE_ID_RAZER_BLACKWIDOW_V3_TK:
    case USB_DEVICE_ID_RAZER_HUNTSMAN_MINI:
        if (count == 3)
        {
            report = razer_chroma_extended_matrix_effect_static(VARSTORE, BACKLIGHT_LED, (struct razer_rgb *)&buf[0]);
            razer_send_payload(usb_dev, &report);
        }
        else
        {
            printf("razerkbd: Static mode only accepts RGB (3byte)");
        }
        break;

    case USB_DEVICE_ID_RAZER_BLACKWIDOW_ELITE:
    case USB_DEVICE_ID_RAZER_CYNOSA_V2:
    case USB_DEVICE_ID_RAZER_ORNATA_CHROMA_V2:
        if (count == 3)
        {
            report = razer_chroma_extended_matrix_effect_static(VARSTORE, BACKLIGHT_LED, (struct razer_rgb *)&buf[0]);
            report.transaction_id.id = 0x1F;
            razer_send_payload(usb_dev, &report);
        }
        else
        {
            printf("razerkbd: Static mode only accepts RGB (3byte)");
        }
        break;

    case USB_DEVICE_ID_RAZER_ANANSI:
        if (count == 3)
        {
            report = razer_chroma_standard_set_led_state(VARSTORE, BACKLIGHT_LED, ON);
            razer_send_payload(usb_dev, &report);
            report = razer_chroma_standard_set_led_effect(VARSTORE, BACKLIGHT_LED, LED_STATIC);
            razer_send_payload(usb_dev, &report);
            report = razer_chroma_standard_set_led_rgb(VARSTORE, BACKLIGHT_LED, (struct razer_rgb *)&buf[0]);
            razer_send_payload(usb_dev, &report);
        }
        else
            printf("razerkbd: Static mode only accepts RGB (3byte)\n");
        break;

    default:
        printf("razerkbd: Cannot set static mode for this device\n");
        break;
    }

    return count;
}

/**
 * Write device file "mode_static"
 * 
 * ** NOSTORE version for efficiency in custom lighting configurations
 * 
 * Set the keyboard to mode when 3 RGB bytes are written
 */
ssize_t razer_attr_write_mode_static_no_store(IOUSBDeviceInterface **usb_dev, const char *buf, int count)
{
    struct razer_report report = {0};

    UInt16 product = -1;
    (*usb_dev)->GetDeviceProduct(usb_dev, &product);

    switch (product)
    {

    case USB_DEVICE_ID_RAZER_TARTARUS_V2:
        report = razer_chroma_extended_matrix_effect_static(NOSTORE, BACKLIGHT_LED, (struct razer_rgb *)&buf[0]);
        razer_send_payload(usb_dev, &report);
        report.transaction_id.id = 0x1F;
        break;

    case USB_DEVICE_ID_RAZER_ORBWEAVER:
    case USB_DEVICE_ID_RAZER_DEATHSTALKER_EXPERT:
        report = razer_chroma_standard_set_led_effect(NOSTORE, BACKLIGHT_LED, 0x00);
        razer_send_payload(usb_dev, &report);
        break;

    case USB_DEVICE_ID_RAZER_BLACKWIDOW_STEALTH:
    case USB_DEVICE_ID_RAZER_BLACKWIDOW_STEALTH_EDITION:
    case USB_DEVICE_ID_RAZER_BLACKWIDOW_ULTIMATE_2012:
    case USB_DEVICE_ID_RAZER_BLACKWIDOW_ULTIMATE_2013: // Doesn't need any parameters as can only do one type of static
        report = razer_chroma_standard_set_led_effect(NOSTORE, LOGO_LED, 0x00);
        razer_send_payload(usb_dev, &report);
        break;

    case USB_DEVICE_ID_RAZER_BLACKWIDOW_OVERWATCH:
    case USB_DEVICE_ID_RAZER_BLACKWIDOW_CHROMA:
    case USB_DEVICE_ID_RAZER_DEATHSTALKER_CHROMA:
    case USB_DEVICE_ID_RAZER_BLACKWIDOW_CHROMA_TE:
    case USB_DEVICE_ID_RAZER_BLACKWIDOW_X_CHROMA:
    case USB_DEVICE_ID_RAZER_BLACKWIDOW_X_CHROMA_TE:
    case USB_DEVICE_ID_RAZER_BLACKWIDOW_ULTIMATE_2016:
    case USB_DEVICE_ID_RAZER_BLACKWIDOW_X_ULTIMATE:
    case USB_DEVICE_ID_RAZER_BLADE_STEALTH:
    case USB_DEVICE_ID_RAZER_BLADE_STEALTH_LATE_2016:
    case USB_DEVICE_ID_RAZER_BLADE_STEALTH_MID_2017:
    case USB_DEVICE_ID_RAZER_BLADE_STEALTH_LATE_2017:
    case USB_DEVICE_ID_RAZER_BLADE_STEALTH_2019:
    case USB_DEVICE_ID_RAZER_BLADE_STEALTH_LATE_2019:
    case USB_DEVICE_ID_RAZER_BLADE_QHD:
    case USB_DEVICE_ID_RAZER_BLADE_PRO_LATE_2016:
    case USB_DEVICE_ID_RAZER_BLADE_2018:
    case USB_DEVICE_ID_RAZER_BLADE_2018_MERCURY:
    case USB_DEVICE_ID_RAZER_BLADE_2018_BASE:
    case USB_DEVICE_ID_RAZER_BLADE_2019_ADV:
    case USB_DEVICE_ID_RAZER_BLADE_2019_BASE:
    case USB_DEVICE_ID_RAZER_BLADE_MID_2019_MERCURY:
    case USB_DEVICE_ID_RAZER_BLADE_STUDIO_EDITION_2019:
    case USB_DEVICE_ID_RAZER_BLADE_LATE_2016:
    case USB_DEVICE_ID_RAZER_BLADE_PRO_2017:
    case USB_DEVICE_ID_RAZER_BLADE_PRO_2017_FULLHD:
    case USB_DEVICE_ID_RAZER_TARTARUS:
    case USB_DEVICE_ID_RAZER_TARTARUS_CHROMA:
    case USB_DEVICE_ID_RAZER_ORBWEAVER_CHROMA:
        if (count == 3)
        {
            report = razer_chroma_standard_matrix_effect_static(NOSTORE, BACKLIGHT_LED, (struct razer_rgb *)&buf[0]);
            razer_send_payload(usb_dev, &report);
        }
        else
        {
            printf("razerkbd: Static mode only accepts RGB (3byte)");
        }
        break;

    case USB_DEVICE_ID_RAZER_BLACKWIDOW_CHROMA_V2:
        if (count == 3)
        {
            report = razer_chroma_standard_matrix_effect_static(NOSTORE, BACKLIGHT_LED, (struct razer_rgb *)&buf[0]);
            report.transaction_id.id = 0x3F; // TODO move to a usb_device variable
            razer_send_payload(usb_dev, &report);
        }
        else
        {
            printf("razerkbd: Static mode only accepts RGB (3byte)");
        }
        break;

    case USB_DEVICE_ID_RAZER_BLACKWIDOW_LITE:
    case USB_DEVICE_ID_RAZER_ORNATA:
    case USB_DEVICE_ID_RAZER_ORNATA_CHROMA:
    case USB_DEVICE_ID_RAZER_HUNTSMAN_ELITE:
    case USB_DEVICE_ID_RAZER_HUNTSMAN_TE:
    case USB_DEVICE_ID_RAZER_BLACKWIDOW_2019:
    case USB_DEVICE_ID_RAZER_HUNTSMAN:
    case USB_DEVICE_ID_RAZER_BLACKWIDOW_ESSENTIAL:
    case USB_DEVICE_ID_RAZER_CYNOSA_CHROMA:
    case USB_DEVICE_ID_RAZER_BLACKWIDOW_V3:
    case USB_DEVICE_ID_RAZER_BLACKWIDOW_V3_TK:
    case USB_DEVICE_ID_RAZER_HUNTSMAN_MINI:
        if (count == 3)
        {
            report = razer_chroma_extended_matrix_effect_static(NOSTORE, BACKLIGHT_LED, (struct razer_rgb *)&buf[0]);
            razer_send_payload(usb_dev, &report);
        }
        else
        {
            printf("razerkbd: Static mode only accepts RGB (3byte)");
        }
        break;

    case USB_DEVICE_ID_RAZER_BLACKWIDOW_ELITE:
    case USB_DEVICE_ID_RAZER_CYNOSA_V2:
    case USB_DEVICE_ID_RAZER_ORNATA_CHROMA_V2:
        if (count == 3)
        {
            report = razer_chroma_extended_matrix_effect_static(NOSTORE, BACKLIGHT_LED, (struct razer_rgb *)&buf[0]);
            report.transaction_id.id = 0x1F;
            razer_send_payload(usb_dev, &report);
        }
        else
        {
            printf("razerkbd: Static mode only accepts RGB (3byte)");
        }
        break;

    case USB_DEVICE_ID_RAZER_ANANSI:
        if (count == 3)
        {
            report = razer_chroma_standard_set_led_state(NOSTORE, BACKLIGHT_LED, ON);
            razer_send_payload(usb_dev, &report);
            report = razer_chroma_standard_set_led_effect(NOSTORE, BACKLIGHT_LED, LED_STATIC);
            razer_send_payload(usb_dev, &report);
            report = razer_chroma_standard_set_led_rgb(NOSTORE, BACKLIGHT_LED, (struct razer_rgb *)&buf[0]);
            razer_send_payload(usb_dev, &report);
        }
        else
            printf("razerkbd: Static mode only accepts RGB (3byte)\n");
        break;

    default:
        printf("razerkbd: Cannot set static mode for this device\n");
        break;
    }

    return count;
}

/**
* Write device file "mode_starlight"
*
* Starlight keyboard effect is activated whenever this file is written to (for bw2016)
*
* Or if an Ornata
* 7 bytes, speed, rgb, rgb
* 4 bytes, speed, rgb
* 1 byte, speed
*/
ssize_t razer_attr_write_mode_starlight(IOUSBDeviceInterface **usb_dev, const char *buf, int count)
{
    struct razer_report report = {0};
    struct razer_rgb rgb1 = {.r = 0x00, .g = 0xFF, .b = 0x00};

    UInt16 product = -1;
    (*usb_dev)->GetDeviceProduct(usb_dev, &product);

    switch (product)
    {
    case USB_DEVICE_ID_RAZER_ORNATA:
        if (count == 4)
        {
            report = razer_chroma_extended_matrix_effect_starlight_single(VARSTORE, BACKLIGHT_LED, buf[0], (struct razer_rgb *)&buf[1]);
            razer_send_payload(usb_dev, &report);
        }
        else
        {
            printf("razerkbd: Starlight only accepts Speed (1byte). Speed, RGB (4byte). Speed, RGB, RGB (7byte)");
        }
        break;

    case USB_DEVICE_ID_RAZER_ORNATA_CHROMA:
    case USB_DEVICE_ID_RAZER_HUNTSMAN_ELITE:
    case USB_DEVICE_ID_RAZER_HUNTSMAN_TE:
    case USB_DEVICE_ID_RAZER_BLACKWIDOW_2019:
    case USB_DEVICE_ID_RAZER_HUNTSMAN:
    case USB_DEVICE_ID_RAZER_CYNOSA_CHROMA:
    case USB_DEVICE_ID_RAZER_BLACKWIDOW_V3:
    case USB_DEVICE_ID_RAZER_BLACKWIDOW_V3_TK:
    case USB_DEVICE_ID_RAZER_HUNTSMAN_MINI:
        if (count == 7)
        {
            report = razer_chroma_extended_matrix_effect_starlight_dual(VARSTORE, BACKLIGHT_LED, buf[0], (struct razer_rgb *)&buf[1], (struct razer_rgb *)&buf[4]);
            razer_send_payload(usb_dev, &report);
        }
        else if (count == 4)
        {
            report = razer_chroma_extended_matrix_effect_starlight_single(VARSTORE, BACKLIGHT_LED, buf[0], (struct razer_rgb *)&buf[1]);
            razer_send_payload(usb_dev, &report);
        }
        else if (count == 1)
        {
            report = razer_chroma_extended_matrix_effect_starlight_random(VARSTORE, BACKLIGHT_LED, buf[0]);
            razer_send_payload(usb_dev, &report);
        }
        else
        {
            printf("razerkbd: Starlight only accepts Speed (1byte). Speed, RGB (4byte). Speed, RGB, RGB (7byte)");
        }
        break;

    case USB_DEVICE_ID_RAZER_BLACKWIDOW_ELITE:
    case USB_DEVICE_ID_RAZER_CYNOSA_V2:
    case USB_DEVICE_ID_RAZER_ORNATA_CHROMA_V2:
        if (count == 7)
        {
            report = razer_chroma_extended_matrix_effect_starlight_dual(VARSTORE, BACKLIGHT_LED, buf[0], (struct razer_rgb *)&buf[1], (struct razer_rgb *)&buf[4]);
        }
        else if (count == 4)
        {
            report = razer_chroma_extended_matrix_effect_starlight_single(VARSTORE, BACKLIGHT_LED, buf[0], (struct razer_rgb *)&buf[1]);
        }
        else if (count == 1)
        {
            report = razer_chroma_extended_matrix_effect_starlight_random(VARSTORE, BACKLIGHT_LED, buf[0]);
        }
        else
        {
            printf("razerkbd: Starlight only accepts Speed (1byte). Speed, RGB (4byte). Speed, RGB, RGB (7byte)");
            break;
        }
        report.transaction_id.id = 0x1F;
        razer_send_payload(usb_dev, &report);
        break;

    case USB_DEVICE_ID_RAZER_TARTARUS_V2:
        if (count == 7)
        {
            report = razer_chroma_extended_matrix_effect_starlight_dual(VARSTORE, BACKLIGHT_LED, buf[0], (struct razer_rgb *)&buf[1], (struct razer_rgb *)&buf[4]);
            report.transaction_id.id = 0x1F; // TODO move to a usb_device variable
            razer_send_payload(usb_dev, &report);
        }
        else if (count == 4)
        {
            report = razer_chroma_extended_matrix_effect_starlight_single(VARSTORE, BACKLIGHT_LED, buf[0], (struct razer_rgb *)&buf[1]);
            report.transaction_id.id = 0x1F; // TODO move to a usb_device variable
            razer_send_payload(usb_dev, &report);
        }
        else if (count == 1)
        {
            report = razer_chroma_extended_matrix_effect_starlight_random(VARSTORE, BACKLIGHT_LED, buf[0]);
            report.transaction_id.id = 0x1F; // TODO move to a usb_device variable
            razer_send_payload(usb_dev, &report);
        }
        else
        {
            printf("razerkbd: Starlight only accepts Speed (1byte). Speed, RGB (4byte). Speed, RGB, RGB (7byte)");
        }
        break;

    case USB_DEVICE_ID_RAZER_BLACKWIDOW_CHROMA_V2:
        if (count == 7)
        {
            report = razer_chroma_standard_matrix_effect_starlight_dual(VARSTORE, BACKLIGHT_LED, buf[0], (struct razer_rgb *)&buf[1], (struct razer_rgb *)&buf[4]);
            report.transaction_id.id = 0x3F; // TODO move to a usb_device variable
            razer_send_payload(usb_dev, &report);
        }
        else if (count == 4)
        {
            report = razer_chroma_standard_matrix_effect_starlight_single(VARSTORE, BACKLIGHT_LED, buf[0], (struct razer_rgb *)&buf[1]);
            report.transaction_id.id = 0x3F; // TODO move to a usb_device variable
            razer_send_payload(usb_dev, &report);
        }
        else if (count == 1)
        {
            report = razer_chroma_standard_matrix_effect_starlight_random(VARSTORE, BACKLIGHT_LED, buf[0]);
            report.transaction_id.id = 0x3F; // TODO move to a usb_device variable
            razer_send_payload(usb_dev, &report);
        }
        else
        {
            printf("razerkbd: Starlight only accepts Speed (1byte). Speed, RGB (4byte). Speed, RGB, RGB (7byte)");
        }
        break;

    default: // BW2016 can do normal starlight
        report = razer_chroma_standard_matrix_effect_starlight_single(VARSTORE, BACKLIGHT_LED, 0x01, &rgb1);
        razer_send_payload(usb_dev, &report);
        break;
    }

    return count;
}

/**
 * Write device file "mode_breath"
 */
ssize_t razer_attr_write_mode_breath(IOUSBDeviceInterface **usb_dev, const char *buf, int count)
{
    struct razer_report report = {0};

    UInt16 product = -1;
    (*usb_dev)->GetDeviceProduct(usb_dev, &product);

    switch (product)
    {
    case USB_DEVICE_ID_RAZER_BLACKWIDOW_LITE:
    case USB_DEVICE_ID_RAZER_ORNATA:
        switch (count)
        {
        case 3: // Single colour mode
            report = razer_chroma_extended_matrix_effect_breathing_single(VARSTORE, BACKLIGHT_LED, (struct razer_rgb *)&buf[0]);
            razer_send_payload(usb_dev, &report);
            break;

        default:
            printf("razerkbd: Breathing only accepts '1' (1byte). RGB (3byte). RGB, RGB (6byte)");
            break;
        }
        break;

    case USB_DEVICE_ID_RAZER_TARTARUS_V2:
        switch (count)
        {
        case 3: // Single colour mode
            report = razer_chroma_extended_matrix_effect_breathing_single(VARSTORE, BACKLIGHT_LED, (struct razer_rgb *)&buf[0]);
            razer_send_payload(usb_dev, &report);
            report.transaction_id.id = 0x1F;
            break;

        case 6: // Dual colour mode
            report = razer_chroma_extended_matrix_effect_breathing_dual(VARSTORE, BACKLIGHT_LED, (struct razer_rgb *)&buf[0], (struct razer_rgb *)&buf[3]);
            razer_send_payload(usb_dev, &report);
            report.transaction_id.id = 0x1F;
            break;

        case 1: // "Random" colour mode
            report = razer_chroma_extended_matrix_effect_breathing_random(VARSTORE, BACKLIGHT_LED);
            razer_send_payload(usb_dev, &report);
            report.transaction_id.id = 0x1F;
            break;

        default:
            printf("razerkbd: Breathing only accepts '1' (1byte). RGB (3byte). RGB, RGB (6byte)");
            break;
        }
        break;

    case USB_DEVICE_ID_RAZER_ORNATA_CHROMA:
    case USB_DEVICE_ID_RAZER_HUNTSMAN_ELITE:
    case USB_DEVICE_ID_RAZER_HUNTSMAN_TE:
    case USB_DEVICE_ID_RAZER_BLACKWIDOW_2019:
    case USB_DEVICE_ID_RAZER_HUNTSMAN:
    case USB_DEVICE_ID_RAZER_BLACKWIDOW_ESSENTIAL:
    case USB_DEVICE_ID_RAZER_CYNOSA_CHROMA:
    case USB_DEVICE_ID_RAZER_CYNOSA_LITE:
    case USB_DEVICE_ID_RAZER_BLACKWIDOW_V3:
    case USB_DEVICE_ID_RAZER_BLACKWIDOW_V3_TK:
    case USB_DEVICE_ID_RAZER_HUNTSMAN_MINI:
        switch (count)
        {
        case 3: // Single colour mode
            report = razer_chroma_extended_matrix_effect_breathing_single(VARSTORE, BACKLIGHT_LED, (struct razer_rgb *)&buf[0]);
            razer_send_payload(usb_dev, &report);
            break;

        case 6: // Dual colour mode
            report = razer_chroma_extended_matrix_effect_breathing_dual(VARSTORE, BACKLIGHT_LED, (struct razer_rgb *)&buf[0], (struct razer_rgb *)&buf[3]);
            razer_send_payload(usb_dev, &report);
            break;

        case 1: // "Random" colour mode
            report = razer_chroma_extended_matrix_effect_breathing_random(VARSTORE, BACKLIGHT_LED);
            razer_send_payload(usb_dev, &report);
            break;

        default:
            printf("razerkbd: Breathing only accepts '1' (1byte). RGB (3byte). RGB, RGB (6byte)");
            break;
        }
        break;

    case USB_DEVICE_ID_RAZER_BLACKWIDOW_ELITE:
    case USB_DEVICE_ID_RAZER_CYNOSA_V2:
    case USB_DEVICE_ID_RAZER_ORNATA_CHROMA_V2:
        if (count == 3)
        { // Single colour mode
            report = razer_chroma_extended_matrix_effect_breathing_single(VARSTORE, BACKLIGHT_LED, (struct razer_rgb *)&buf[0]);
        }
        else if (count == 6)
        { // Dual colour mode
            report = razer_chroma_extended_matrix_effect_breathing_dual(VARSTORE, BACKLIGHT_LED, (struct razer_rgb *)&buf[0], (struct razer_rgb *)&buf[3]);
        }
        else if (count == 1)
        { // "Random" colour mode
            report = razer_chroma_extended_matrix_effect_breathing_random(VARSTORE, BACKLIGHT_LED);
        }
        else
        {
            printf("razerkbd: Breathing only accepts '1' (1byte). RGB (3byte). RGB, RGB (6byte)");
            break;
        }
        report.transaction_id.id = 0x1F;
        razer_send_payload(usb_dev, &report);
        break;

    case USB_DEVICE_ID_RAZER_BLACKWIDOW_CHROMA_V2:
        switch (count)
        {
        case 3: // Single colour mode
            report = razer_chroma_standard_matrix_effect_breathing_single(VARSTORE, BACKLIGHT_LED, (struct razer_rgb *)&buf[0]);
            report.transaction_id.id = 0x3F; // TODO move to a usb_device variable
            razer_send_payload(usb_dev, &report);
            break;

        case 6: // Dual colour mode
            report = razer_chroma_standard_matrix_effect_breathing_dual(VARSTORE, BACKLIGHT_LED, (struct razer_rgb *)&buf[0], (struct razer_rgb *)&buf[3]);
            report.transaction_id.id = 0x3F; // TODO move to a usb_device variable
            razer_send_payload(usb_dev, &report);
            break;

        default: // "Random" colour mode
            report = razer_chroma_standard_matrix_effect_breathing_random(VARSTORE, BACKLIGHT_LED);
            report.transaction_id.id = 0x3F; // TODO move to a usb_device variable
            razer_send_payload(usb_dev, &report);
            break;
            // TODO move default to case 1:. Then default: printk(warning). Also remove pointless buffer
        }
        break;

    default:
        switch (count)
        {
        case 3: // Single colour mode
            report = razer_chroma_standard_matrix_effect_breathing_single(VARSTORE, BACKLIGHT_LED, (struct razer_rgb *)&buf[0]);
            razer_send_payload(usb_dev, &report);
            break;

        case 6: // Dual colour mode
            report = razer_chroma_standard_matrix_effect_breathing_dual(VARSTORE, BACKLIGHT_LED, (struct razer_rgb *)&buf[0], (struct razer_rgb *)&buf[3]);
            razer_send_payload(usb_dev, &report);
            break;

        default: // "Random" colour mode
            report = razer_chroma_standard_matrix_effect_breathing_random(VARSTORE, BACKLIGHT_LED);
            razer_send_payload(usb_dev, &report);
            break;
            // TODO move default to case 1:. Then default: printk(warning). Also remove pointless buffer
        }
        break;
    }

    return count;
}

ssize_t has_inverted_led_state(IOUSBDeviceInterface **usb_dev)
{
    UInt16 product = -1;
    (*usb_dev)->GetDeviceProduct(usb_dev, &product);

    switch (product)
    {
    case USB_DEVICE_ID_RAZER_BLADE_STEALTH_LATE_2016:
    case USB_DEVICE_ID_RAZER_BLADE_PRO_LATE_2016:
    case USB_DEVICE_ID_RAZER_BLADE_QHD:
    case USB_DEVICE_ID_RAZER_BLADE_LATE_2016:
        return 1;
    default:
        return 0;
    }
}

/**
 * Read device file "set_logo"
 *
 * Sets the logo lighting state to the ASCII number written to this file.
 */
ssize_t razer_attr_read_set_logo(IOUSBDeviceInterface **usb_dev, char *buf, int count)
{
    struct razer_report report = razer_chroma_standard_get_led_effect(VARSTORE, LOGO_LED);
    struct razer_report response = get_empty_razer_report();
    int state;

    // Blade laptops don't use effect for logo on/off, and mode 2 ("blink") is technically unsupported.
    if (is_blade_laptop(usb_dev))
    {
        report = razer_chroma_standard_get_led_state(VARSTORE, LOGO_LED);
    }

    response = razer_send_payload(usb_dev, &report);
    state = response.arguments[2];

    if (has_inverted_led_state(usb_dev) && (state == 0 || state == 1))
    {
        state = !state;
    }

    return sprintf(buf, "%d\n", state);
}

/**
 * Write device file "set_logo"
 *
 * Sets the logo lighting state to the ASCII number written to this file.
 */
ssize_t razer_attr_write_set_logo(IOUSBDeviceInterface **usb_dev, const char *buf, int count)
{
    unsigned char state = (unsigned char)strtol(buf, NULL, 10);
    struct razer_report report = {0};

    if (has_inverted_led_state(usb_dev) && (state == 0 || state == 1))
    {
        state = !state;
    }

    // Blade laptops are... different. They use state instead of effect.
    // Note: This does allow setting of mode 2 ("blink"), but this is an undocumented feature.
    if (is_blade_laptop(usb_dev) && (state == 0 || state == 1))
    {
        report = razer_chroma_standard_set_led_state(VARSTORE, LOGO_LED, state);
    }
    else
    {
        report = razer_chroma_standard_set_led_effect(VARSTORE, LOGO_LED, state);
    }

    razer_send_payload(usb_dev, &report);

    return count;
}

/**
 * Write device file "mode_custom"
 *
 * Sets the keyboard to custom mode whenever the file is written to
 */
ssize_t razer_attr_write_mode_custom(IOUSBDeviceInterface **usb_dev, const char *buf, int count)
{
    struct razer_report report = {0};

    UInt16 product = -1;
    (*usb_dev)->GetDeviceProduct(usb_dev, &product);

    switch (product)
    {
    case USB_DEVICE_ID_RAZER_ORNATA:
    case USB_DEVICE_ID_RAZER_ORNATA_CHROMA:
    case USB_DEVICE_ID_RAZER_HUNTSMAN_ELITE:
    case USB_DEVICE_ID_RAZER_HUNTSMAN_TE:
    case USB_DEVICE_ID_RAZER_BLACKWIDOW_2019:
    case USB_DEVICE_ID_RAZER_HUNTSMAN:
    case USB_DEVICE_ID_RAZER_CYNOSA_CHROMA:
    case USB_DEVICE_ID_RAZER_BLACKWIDOW_V3:
    case USB_DEVICE_ID_RAZER_BLACKWIDOW_V3_TK:
    case USB_DEVICE_ID_RAZER_HUNTSMAN_MINI:
        report = razer_chroma_extended_matrix_effect_custom_frame();
        break;

    case USB_DEVICE_ID_RAZER_TARTARUS_V2:
    case USB_DEVICE_ID_RAZER_BLACKWIDOW_ELITE:
    case USB_DEVICE_ID_RAZER_CYNOSA_V2:
    case USB_DEVICE_ID_RAZER_ORNATA_CHROMA_V2:
        report = razer_chroma_extended_matrix_effect_custom_frame();
        report.transaction_id.id = 0x1F;
        break;

    case USB_DEVICE_ID_RAZER_BLACKWIDOW_CHROMA_V2:
        report = razer_chroma_standard_matrix_effect_custom_frame(VARSTORE); // Possibly could use VARSTORE
        report.transaction_id.id = 0x3F;                                     // TODO move to a usb_device variable
        break;

    default:
        report = razer_chroma_standard_matrix_effect_custom_frame(VARSTORE); // Possibly could use VARSTORE
        break;
    }
    razer_send_payload(usb_dev, &report);
    return count;
}

/**
 * Write device file "set_fn_toggle"
 *
 * Sets the logo lighting state to the ASCII number written to this file.
 */
ssize_t razer_attr_write_set_fn_toggle(IOUSBDeviceInterface **usb_dev, const char *buf, int count)
{
    unsigned char state = (unsigned char)strtol(buf, NULL, 10);
    struct razer_report report = razer_chroma_misc_fn_key_toggle(state);
    razer_send_payload(usb_dev, &report);

    return count;
}

/**
 * Write device file "set_brightness"
 *
 * Sets the brightness to the ASCII number written to this file.
 */
ssize_t razer_attr_write_set_brightness(IOUSBDeviceInterface **usb_dev, ushort brightness, int count)
{
    struct razer_report report = {0};

    UInt16 product = -1;
    (*usb_dev)->GetDeviceProduct(usb_dev, &product);

    switch (product)
    {

    case USB_DEVICE_ID_RAZER_TARTARUS_V2:
        report = razer_chroma_extended_matrix_brightness(VARSTORE, ZERO_LED, brightness);
        report.transaction_id.id = 0x1F;
        break;

    case USB_DEVICE_ID_RAZER_BLACKWIDOW_LITE:
    case USB_DEVICE_ID_RAZER_ORNATA:
    case USB_DEVICE_ID_RAZER_ORNATA_CHROMA:
    case USB_DEVICE_ID_RAZER_HUNTSMAN_ELITE:
    case USB_DEVICE_ID_RAZER_HUNTSMAN_TE:
    case USB_DEVICE_ID_RAZER_BLACKWIDOW_2019:
    case USB_DEVICE_ID_RAZER_HUNTSMAN:
    case USB_DEVICE_ID_RAZER_BLACKWIDOW_ESSENTIAL:
    case USB_DEVICE_ID_RAZER_CYNOSA_CHROMA:
    case USB_DEVICE_ID_RAZER_CYNOSA_LITE:
    case USB_DEVICE_ID_RAZER_BLACKWIDOW_V3:
    case USB_DEVICE_ID_RAZER_BLACKWIDOW_V3_TK:
    case USB_DEVICE_ID_RAZER_HUNTSMAN_MINI:
        report = razer_chroma_extended_matrix_brightness(VARSTORE, BACKLIGHT_LED, brightness);
        break;

    case USB_DEVICE_ID_RAZER_BLACKWIDOW_ELITE:
    case USB_DEVICE_ID_RAZER_CYNOSA_V2:
    case USB_DEVICE_ID_RAZER_ORNATA_CHROMA_V2:
        report = razer_chroma_extended_matrix_brightness(VARSTORE, BACKLIGHT_LED, brightness);
        report.transaction_id.id = 0x1F;
        break;

    case USB_DEVICE_ID_RAZER_BLACKWIDOW_STEALTH:
    case USB_DEVICE_ID_RAZER_BLACKWIDOW_STEALTH_EDITION:
    case USB_DEVICE_ID_RAZER_BLACKWIDOW_ULTIMATE_2012:
    case USB_DEVICE_ID_RAZER_BLACKWIDOW_ULTIMATE_2013:
        report = razer_chroma_standard_set_led_brightness(VARSTORE, LOGO_LED, brightness);
        break;

    case USB_DEVICE_ID_RAZER_NOSTROMO:
    default:
        if (is_blade_laptop(usb_dev))
        {
            report = razer_chroma_misc_set_blade_brightness(brightness);
        }
        else
        {
            report = razer_chroma_standard_set_led_brightness(VARSTORE, BACKLIGHT_LED, brightness);
        }
        break;
    }
    razer_send_payload(usb_dev, &report);

    return count;
}

/**
 * Read device file "macro_mode"
 *
 * Returns a string
 */
ushort razer_attr_read_set_brightness(IOUSBDeviceInterface **usb_dev)
{
    bool is_matrix_brightness = false;
    unsigned char brightness = 0;
    struct razer_report report = {0};
    struct razer_report response = {0};

    UInt16 product = -1;
    (*usb_dev)->GetDeviceProduct(usb_dev, &product);

    switch (product)
    {

    case USB_DEVICE_ID_RAZER_TARTARUS_V2:
        report = razer_chroma_extended_matrix_get_brightness(VARSTORE, ZERO_LED);
        report.transaction_id.id = 0x1F;
        is_matrix_brightness = true;
        break;

    case USB_DEVICE_ID_RAZER_BLACKWIDOW_LITE:
    case USB_DEVICE_ID_RAZER_ORNATA:
    case USB_DEVICE_ID_RAZER_ORNATA_CHROMA:
    case USB_DEVICE_ID_RAZER_HUNTSMAN_ELITE:
    case USB_DEVICE_ID_RAZER_HUNTSMAN_TE:
    case USB_DEVICE_ID_RAZER_BLACKWIDOW_2019:
    case USB_DEVICE_ID_RAZER_HUNTSMAN:
    case USB_DEVICE_ID_RAZER_BLACKWIDOW_ESSENTIAL:
    case USB_DEVICE_ID_RAZER_CYNOSA_CHROMA:
    case USB_DEVICE_ID_RAZER_CYNOSA_LITE:
    case USB_DEVICE_ID_RAZER_BLACKWIDOW_V3:
    case USB_DEVICE_ID_RAZER_BLACKWIDOW_V3_TK:
    case USB_DEVICE_ID_RAZER_HUNTSMAN_MINI:
        report = razer_chroma_extended_matrix_get_brightness(VARSTORE, BACKLIGHT_LED);
        is_matrix_brightness = true;
        break;

    case USB_DEVICE_ID_RAZER_BLACKWIDOW_ELITE:
    case USB_DEVICE_ID_RAZER_CYNOSA_V2:
    case USB_DEVICE_ID_RAZER_ORNATA_CHROMA_V2:
        report = razer_chroma_extended_matrix_get_brightness(VARSTORE, BACKLIGHT_LED);
        report.transaction_id.id = 0x1F;
        is_matrix_brightness = true;
        break;

    case USB_DEVICE_ID_RAZER_BLACKWIDOW_STEALTH:
    case USB_DEVICE_ID_RAZER_BLACKWIDOW_STEALTH_EDITION:
    case USB_DEVICE_ID_RAZER_BLACKWIDOW_ULTIMATE_2012:
    case USB_DEVICE_ID_RAZER_BLACKWIDOW_ULTIMATE_2013:
        report = razer_chroma_standard_get_led_brightness(VARSTORE, LOGO_LED);
        break;

    case USB_DEVICE_ID_RAZER_NOSTROMO:
    default:
        if (is_blade_laptop(usb_dev))
        {
            report = razer_chroma_misc_get_blade_brightness();
        }
        else
        {
            report = razer_chroma_standard_get_led_brightness(VARSTORE, BACKLIGHT_LED);
        }
        break;
    }

    response = razer_send_payload(usb_dev, &report);

    // Brightness is stored elsewhere for the stealth cmds
    if (is_blade_laptop(usb_dev))
    {
        brightness = response.arguments[1];
    }
    else
    {
        brightness = response.arguments[2];
    }

    if(is_matrix_brightness) {
        brightness = round(brightness / 2.55);
    }

    return brightness;
}

/**
 * Write device file "matrix_custom_frame"
 *
 * Format
 * ROW_ID START_COL STOP_COL RGB...
 */
ssize_t razer_attr_write_matrix_custom_frame(IOUSBDeviceInterface **usb_dev, const char *buf, int count)
{
    struct razer_report report;
    int offset = 0;
    unsigned char row_id;
    unsigned char start_col;
    unsigned char stop_col;
    unsigned char row_length;

    UInt16 product = -1;
    (*usb_dev)->GetDeviceProduct(usb_dev, &product);

    //printk(KERN_ALERT "razerkbd: Total count: %d\n", (unsigned char)count);

    while (offset < count)
    {
        if (offset + 3 > count)
        {
            printf("razerkbd: Wrong Amount of data provided: Should be ROW_ID, START_COL, STOP_COL, N_RGB\n");
            break;
        }

        row_id = buf[offset++];
        start_col = buf[offset++];
        stop_col = buf[offset++];
        row_length = ((stop_col + 1) - start_col) * 3;

        // printk(KERN_ALERT "razerkbd: Row ID: %d, Start: %d, Stop: %d, row length: %d\n", row_id, start_col, stop_col, row_length);

        if (start_col > stop_col)
        {
            printf("razerkbd: Start column is greater than end column\n");
            break;
        }

        if (offset + row_length > count)
        {
            printf("razerkbd: Not enough RGB to fill row\n");
            break;
        }

        // Offset now at beginning of RGB data
        switch (product)
        {
        case USB_DEVICE_ID_RAZER_ORNATA:
        case USB_DEVICE_ID_RAZER_ORNATA_CHROMA:
        case USB_DEVICE_ID_RAZER_HUNTSMAN_ELITE:
        case USB_DEVICE_ID_RAZER_HUNTSMAN_TE:
        case USB_DEVICE_ID_RAZER_BLACKWIDOW_2019:
        case USB_DEVICE_ID_RAZER_HUNTSMAN:
        case USB_DEVICE_ID_RAZER_CYNOSA_CHROMA:
        case USB_DEVICE_ID_RAZER_BLACKWIDOW_V3:
        case USB_DEVICE_ID_RAZER_BLACKWIDOW_V3_TK:
        case USB_DEVICE_ID_RAZER_HUNTSMAN_MINI:
            report = razer_chroma_extended_matrix_set_custom_frame(row_id, start_col, stop_col, (unsigned char *)&buf[offset]);
            break;

        case USB_DEVICE_ID_RAZER_TARTARUS_V2:
        case USB_DEVICE_ID_RAZER_BLACKWIDOW_ELITE:
        case USB_DEVICE_ID_RAZER_CYNOSA_V2:
        case USB_DEVICE_ID_RAZER_ORNATA_CHROMA_V2:
            report = razer_chroma_extended_matrix_set_custom_frame(row_id, start_col, stop_col, (unsigned char *)&buf[offset]);
            report.transaction_id.id = 0x1F;
            break;

        case USB_DEVICE_ID_RAZER_DEATHSTALKER_CHROMA:
            report = razer_chroma_misc_one_row_set_custom_frame(start_col, stop_col, (unsigned char *)&buf[offset]);
            break;

        case USB_DEVICE_ID_RAZER_BLADE_LATE_2016:
        case USB_DEVICE_ID_RAZER_BLACKWIDOW_CHROMA_V2:
            report = razer_chroma_standard_matrix_set_custom_frame(row_id, start_col, stop_col, (unsigned char *)&buf[offset]);
            report.transaction_id.id = 0x3F; // TODO move to a usb_device variable
            break;

        case USB_DEVICE_ID_RAZER_BLACKWIDOW_X_ULTIMATE:
        case USB_DEVICE_ID_RAZER_BLACKWIDOW_ULTIMATE_2016:
        case USB_DEVICE_ID_RAZER_BLADE_STEALTH:
        case USB_DEVICE_ID_RAZER_BLADE_STEALTH_LATE_2016:
        case USB_DEVICE_ID_RAZER_BLADE_STEALTH_MID_2017:
        case USB_DEVICE_ID_RAZER_BLADE_STEALTH_LATE_2017:
        case USB_DEVICE_ID_RAZER_BLADE_STEALTH_2019:
        case USB_DEVICE_ID_RAZER_BLADE_QHD:
        case USB_DEVICE_ID_RAZER_BLADE_PRO_LATE_2016:
        case USB_DEVICE_ID_RAZER_BLADE_2018:
        case USB_DEVICE_ID_RAZER_BLADE_2018_MERCURY:
        case USB_DEVICE_ID_RAZER_BLADE_2018_BASE:
        case USB_DEVICE_ID_RAZER_BLADE_2019_ADV:
        case USB_DEVICE_ID_RAZER_BLADE_MID_2019_MERCURY:
        case USB_DEVICE_ID_RAZER_BLADE_STUDIO_EDITION_2019:
        case USB_DEVICE_ID_RAZER_BLADE_PRO_2017:
        case USB_DEVICE_ID_RAZER_BLADE_PRO_2017_FULLHD:
            report.transaction_id.id = 0x80; // Fall into the 2016/blade/blade2016 to set device id
        /* fall through */
        default:
            report = razer_chroma_standard_matrix_set_custom_frame(row_id, start_col, stop_col, (unsigned char *)&buf[offset]);
            break;
        }
        razer_send_payload(usb_dev, &report);

        // *3 as its 3 bytes per col (RGB)
        offset += row_length;
    }

    return count;
}

/**
 * Send report to the keyboard
 */
static int razer_get_report(IOUSBDeviceInterface **usb_dev, struct razer_report *request_report, struct razer_report *response_report)
{
    UInt16 product = -1;
    (*usb_dev)->GetDeviceProduct(usb_dev, &product);

    uint report_index;
    uint response_index;

    switch (product)
    {
    case USB_DEVICE_ID_RAZER_ANANSI:
    case USB_DEVICE_ID_RAZER_HUNTSMAN_TE:
    case USB_DEVICE_ID_RAZER_ORNATA_CHROMA_V2:
    case USB_DEVICE_ID_RAZER_BLACKWIDOW_V3_TK:
    case USB_DEVICE_ID_RAZER_HUNTSMAN_MINI:
        report_index = 0x02;
        response_index = 0x02;
        break;
    case USB_DEVICE_ID_RAZER_BLACKWIDOW_V3:
        report_index = 0x03;
        response_index = 0x03;
        break;
    default:
        report_index = 0x01;
        response_index = 0x01;
        break;
    }

    return razer_get_usb_response(usb_dev, report_index, request_report, response_index, response_report, RAZER_BLACKWIDOW_CHROMA_WAIT_MIN_US);
}

/**
 * Function to send to device, get response, and actually check the response
 */
static struct razer_report razer_send_payload(IOUSBDeviceInterface **dev, struct razer_report *request_report)
{
    IOReturn retval = -1;

    struct razer_report response_report = {0};
    request_report->crc = razer_calculate_crc(request_report);

    retval = razer_get_report(dev, request_report, &response_report);

    if (retval == kIOReturnSuccess)
    {
        // Check the packet number, class and command are the same
        if (response_report.remaining_packets != request_report->remaining_packets ||
            response_report.command_class != request_report->command_class ||
            response_report.command_id.id != request_report->command_id.id)
        {
            printf("Response doesnt match request (keyboard)\n");
        } else if (response_report.status == RAZER_CMD_BUSY) {
            //printf("Device is busy (keyboard)\n");
        } else if (response_report.status == RAZER_CMD_FAILURE) {
            printf("Command failed (keyboard)\n");
        } else if (response_report.status == RAZER_CMD_NOT_SUPPORTED) {
            printf("Command not supported (keyboard)\n");
        } else if (response_report.status == RAZER_CMD_TIMEOUT) {
            printf("Command timed out (keyboard)\n");
        }
    } else {
        printf("Invalid Report Length (keyboard)\n");
    }

    return response_report;
}
