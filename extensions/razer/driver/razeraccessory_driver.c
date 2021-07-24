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

#include "razeraccessory_driver.h"
#include "razercommon.h"
#include "razerchromacommon.h"

/**
 * Send report to the device
 */
static int razer_get_report(IOUSBDeviceInterface **usb_dev, struct razer_report *request_report, struct razer_report *response_report)
{
    return razer_get_usb_response(usb_dev, 0x00, request_report, 0x00, response_report, RAZER_ACCESSORY_WAIT_MIN_US);
}

/**
 * Function to send to device, get response, and actually check the response
 */
static struct razer_report razer_send_payload(IOUSBDeviceInterface **usb_dev, struct razer_report *request_report)
{
    int retval = -1;
    struct razer_report response_report = {0};

    request_report->crc = razer_calculate_crc(request_report);

    retval = razer_get_report(usb_dev, request_report, &response_report);

    if(retval == 0) {
        // Check the packet number, class and command are the same
        if(response_report.remaining_packets != request_report->remaining_packets ||
           response_report.command_class != request_report->command_class ||
           response_report.command_id.id != request_report->command_id.id) {
            printf("Response doesn't match request (accessory)\n");
        } else if (response_report.status == RAZER_CMD_BUSY) {
            //printf("Device is busy (accessory)\n");
        } else if (response_report.status == RAZER_CMD_FAILURE) {
            printf("Command failed (accessory)\n");
        } else if (response_report.status == RAZER_CMD_NOT_SUPPORTED) {
            printf("Command not supported (accessory)\n");
        } else if (response_report.status == RAZER_CMD_TIMEOUT) {
            printf("Command timed out (accessory)\n");
        }
    } else {
        printf("Invalid Report Length (accessory)\n");
    }

    return response_report;
}

/**
 * Write device file "mode_spectrum"
 *
 * Specrum effect mode is activated whenever the file is written to
 */
ssize_t razer_accessory_attr_write_mode_spectrum(IOUSBDeviceInterface **usb_dev, const char *buf, size_t count)
{
    UInt16 product = -1;
    (*usb_dev)->GetDeviceProduct(usb_dev, &product);
    struct razer_report report = { 0 };

    switch (product) {
        case USB_DEVICE_ID_RAZER_CHROMA_MUG:
            report = razer_chroma_standard_matrix_effect_spectrum(VARSTORE, BACKLIGHT_LED);
            report.transaction_id.id = 0x3F;
            break;

        case USB_DEVICE_ID_RAZER_CHROMA_HDK:
        case USB_DEVICE_ID_RAZER_CHROMA_BASE:
        case USB_DEVICE_ID_RAZER_NOMMO_PRO:
        case USB_DEVICE_ID_RAZER_NOMMO_CHROMA:
            report = razer_chroma_extended_matrix_effect_spectrum(VARSTORE, ZERO_LED);
            report.transaction_id.id = 0x3F;
            break;

        case USB_DEVICE_ID_RAZER_MOUSE_BUNGEE_V3_CHROMA:
        case USB_DEVICE_ID_RAZER_BASE_STATION_V2_CHROMA:
            report = razer_chroma_extended_matrix_effect_spectrum(VARSTORE, ZERO_LED);
            report.transaction_id.id = 0x1F;
            break;

        default:
            printf("razeraccessory: Unknown device\n");
            break;
    }

    razer_send_payload(usb_dev, &report);

    return count;
}

/**
 * Write device file "mode_none"
 *
 * None effect mode is activated whenever the file is written to
 */
ssize_t razer_accessory_attr_write_mode_none(IOUSBDeviceInterface **usb_dev, const char *buf, size_t count)
{
    UInt16 product = -1;
    (*usb_dev)->GetDeviceProduct(usb_dev, &product);
    struct razer_report report = { 0 };

    switch (product) {
        case USB_DEVICE_ID_RAZER_CHROMA_MUG:
            report = razer_chroma_standard_matrix_effect_none(VARSTORE, BACKLIGHT_LED);
            report.transaction_id.id = 0x3F;
            break;

        case USB_DEVICE_ID_RAZER_CHROMA_HDK:
        case USB_DEVICE_ID_RAZER_CHROMA_BASE:
        case USB_DEVICE_ID_RAZER_NOMMO_PRO:
        case USB_DEVICE_ID_RAZER_NOMMO_CHROMA:
            report = razer_chroma_extended_matrix_effect_none(VARSTORE, ZERO_LED);
            report.transaction_id.id = 0x3F;
            break;

        case USB_DEVICE_ID_RAZER_MOUSE_BUNGEE_V3_CHROMA:
        case USB_DEVICE_ID_RAZER_BASE_STATION_V2_CHROMA:
            report = razer_chroma_extended_matrix_effect_none(VARSTORE, ZERO_LED);
            report.transaction_id.id = 0x1F;
            break;

        default:
            printf("razeraccessory: Unknown device\n");
            break;
    }

    razer_send_payload(usb_dev, &report);

    return count;
}

/**
 * Write device file "mode_blinking"
 *
 * Blinking effect mode is activated whenever the file is written to with 3 bytes
 */
ssize_t razer_accessory_attr_write_mode_blinking(IOUSBDeviceInterface **usb_dev, const char *buf, size_t count)
{

    struct razer_report report_rgb = {0};
    struct razer_report report_effect = razer_chroma_standard_set_led_effect(VARSTORE, BACKLIGHT_LED, 0x01);
    report_effect.transaction_id.id = 0x3F;

    if(count == 3) {
        report_rgb = razer_chroma_standard_set_led_rgb(VARSTORE, BACKLIGHT_LED, (struct razer_rgb*)&buf[0]);
        report_rgb.transaction_id.id = 0x3F;

        razer_send_payload(usb_dev, &report_rgb);
        usleep(5 * 1000);
        razer_send_payload(usb_dev, &report_effect);

    } else {
        printf("razeraccessory: Blinking mode only accepts RGB (3byte)\n");
    }

    return count;
}

/**
 * Write device file "mode_custom"
 *
 * Sets the device to custom mode whenever the file is written to
 */
ssize_t razer_accessory_attr_write_mode_custom(IOUSBDeviceInterface **usb_dev, const char *buf, size_t count)
{
    UInt16 product = -1;
    (*usb_dev)->GetDeviceProduct(usb_dev, &product);
    struct razer_report report = { 0 };

    switch (product) {
        case USB_DEVICE_ID_RAZER_CHROMA_MUG:
            report = razer_chroma_standard_matrix_effect_custom_frame(NOSTORE);
            break;

        case USB_DEVICE_ID_RAZER_CHROMA_HDK:
        case USB_DEVICE_ID_RAZER_CHROMA_BASE:
        case USB_DEVICE_ID_RAZER_NOMMO_PRO:
        case USB_DEVICE_ID_RAZER_NOMMO_CHROMA:
            report = razer_chroma_extended_matrix_effect_custom_frame();
            break;

        case USB_DEVICE_ID_RAZER_MOUSE_BUNGEE_V3_CHROMA:
        case USB_DEVICE_ID_RAZER_BASE_STATION_V2_CHROMA:
            report = razer_chroma_extended_matrix_effect_custom_frame();
            report.transaction_id.id = 0x1F;
            break;

        default:
            printf("razeraccessory: Unknown device\n");
            break;
    }

    razer_send_payload(usb_dev, &report);

    return count;
}

/**
 * Write device file "mode_static"
 *
 * Static effect mode is activated whenever the file is written to with 3 bytes
 */
ssize_t razer_accessory_attr_write_mode_static(IOUSBDeviceInterface **usb_dev, const char *buf, size_t count)
{
    UInt16 product = -1;
    (*usb_dev)->GetDeviceProduct(usb_dev, &product);
    struct razer_report report = {0};

    if(count == 3) {
        switch (product) {
            case USB_DEVICE_ID_RAZER_CHROMA_MUG:
                report = razer_chroma_standard_matrix_effect_static(VARSTORE, BACKLIGHT_LED, (struct razer_rgb*) & buf[0]);
                report.transaction_id.id = 0x3F;
                break;

            case USB_DEVICE_ID_RAZER_CHROMA_HDK:
            case USB_DEVICE_ID_RAZER_CHROMA_BASE:
            case USB_DEVICE_ID_RAZER_NOMMO_PRO:
            case USB_DEVICE_ID_RAZER_NOMMO_CHROMA:
                report = razer_chroma_extended_matrix_effect_static(VARSTORE, ZERO_LED, (struct razer_rgb*) & buf[0]);
                report.transaction_id.id = 0x3F;
                break;

            case USB_DEVICE_ID_RAZER_MOUSE_BUNGEE_V3_CHROMA:
            case USB_DEVICE_ID_RAZER_BASE_STATION_V2_CHROMA:
                report = razer_chroma_extended_matrix_effect_static(VARSTORE, ZERO_LED, (struct razer_rgb*) & buf[0]);
                report.transaction_id.id = 0x1F;
                break;

            default:
                printf("razeraccessory: Unknown device\n");
                break;
        }

        razer_send_payload(usb_dev, &report);

    } else {
        printf("razeraccessory: Static mode only accepts RGB (3byte)\n");
    }

    return count;
}

/**
 * Write device file "mode_wave"
 *
 * When 1 is written (as a character, 0x31) the wave effect is displayed moving anti clockwise
 * if 2 is written (0x32) then the wave effect goes clockwise
 */
ssize_t razer_accessory_attr_write_mode_wave(IOUSBDeviceInterface **usb_dev, const char *buf, size_t count, int speed)
{
    UInt16 product = -1;
    (*usb_dev)->GetDeviceProduct(usb_dev, &product);
    unsigned char direction = (unsigned char)strtol(buf, NULL, 10);
    struct razer_report report = { 0 };

    switch (product) {
        case USB_DEVICE_ID_RAZER_CHROMA_MUG:
            report = razer_chroma_standard_matrix_effect_wave(VARSTORE, BACKLIGHT_LED, direction);
            report.transaction_id.id = 0x3F;
            break;

        case USB_DEVICE_ID_RAZER_CHROMA_HDK:
        case USB_DEVICE_ID_RAZER_CHROMA_BASE:
        case USB_DEVICE_ID_RAZER_NOMMO_PRO:
        case USB_DEVICE_ID_RAZER_NOMMO_CHROMA:
            report = razer_chroma_extended_matrix_effect_wave(VARSTORE, ZERO_LED, direction, speed);
            report.transaction_id.id = 0x3F;
            break;

        case USB_DEVICE_ID_RAZER_MOUSE_BUNGEE_V3_CHROMA:
        case USB_DEVICE_ID_RAZER_BASE_STATION_V2_CHROMA:
            report = razer_chroma_extended_matrix_effect_wave(VARSTORE, ZERO_LED, direction, speed);
            report.transaction_id.id = 0x1F;
            break;

        default:
            printf("razeraccessory: Unknown device\n");
            break;
    }

    razer_send_payload(usb_dev, &report);

    return count;
}

/**
 * Write device file "mode_breath"
 *
 * Breathing effect mode is activated whenever the file is written to with 1, 3, or 6 bytes
 */
ssize_t razer_accessory_attr_write_mode_breath(IOUSBDeviceInterface **usb_dev, const char *buf, size_t count)
{
    UInt16 product = -1;
    (*usb_dev)->GetDeviceProduct(usb_dev, &product);
    struct razer_report report = {0};

    switch (product) {
        case USB_DEVICE_ID_RAZER_CHROMA_HDK:
        case USB_DEVICE_ID_RAZER_CHROMA_BASE:
        case USB_DEVICE_ID_RAZER_NOMMO_PRO:
        case USB_DEVICE_ID_RAZER_NOMMO_CHROMA:
            switch(count) {
                case 3: // Single colour mode
                    report = razer_chroma_extended_matrix_effect_breathing_single(VARSTORE, ZERO_LED, (struct razer_rgb *)&buf[0]);
                    report.transaction_id.id = 0x3F;
                    break;

                case 6: // Dual colour mode
                    report = razer_chroma_extended_matrix_effect_breathing_dual(VARSTORE, ZERO_LED, (struct razer_rgb *)&buf[0], (struct razer_rgb *)&buf[3]);
                    report.transaction_id.id = 0x3F;
                    break;

                default: // "Random" colour mode
                    report = razer_chroma_extended_matrix_effect_breathing_random(VARSTORE, ZERO_LED);
                    report.transaction_id.id = 0x3F;
                    break;
            }
            break;

        case USB_DEVICE_ID_RAZER_MOUSE_BUNGEE_V3_CHROMA:
        case USB_DEVICE_ID_RAZER_BASE_STATION_V2_CHROMA:
            switch(count) {
                case 3: // Single colour mode
                    report = razer_chroma_extended_matrix_effect_breathing_single(VARSTORE, ZERO_LED, (struct razer_rgb *)&buf[0]);
                    report.transaction_id.id = 0x1F;
                    break;

                case 6: // Dual colour mode
                    report = razer_chroma_extended_matrix_effect_breathing_dual(VARSTORE, ZERO_LED, (struct razer_rgb *)&buf[0], (struct razer_rgb *)&buf[3]);
                    report.transaction_id.id = 0x1F;
                    break;

                default: // "Random" colour mode
                    report = razer_chroma_extended_matrix_effect_breathing_random(VARSTORE, ZERO_LED);
                    report.transaction_id.id = 0x1F;
                    break;
            }
            break;

        case USB_DEVICE_ID_RAZER_CHROMA_MUG:
            switch(count) {
                case 3: // Single colour mode
                    report = razer_chroma_standard_matrix_effect_breathing_single(VARSTORE, BACKLIGHT_LED, (struct razer_rgb*)&buf[0]);
                    report.transaction_id.id = 0x3F;
                    break;

                case 6: // Dual colour mode
                    report = razer_chroma_standard_matrix_effect_breathing_dual(VARSTORE, BACKLIGHT_LED, (struct razer_rgb*)&buf[0], (struct razer_rgb*)&buf[3]);
                    report.transaction_id.id = 0x3F;
                    break;

                default: // "Random" colour mode
                    report = razer_chroma_standard_matrix_effect_breathing_random(VARSTORE, BACKLIGHT_LED);
                    report.transaction_id.id = 0x3F;
                    break;
            }
            break;

        default:
            printf("razeraccessory: Unknown device\n");
            break;
    }

    razer_send_payload(usb_dev, &report);

    return count;
}

/**
 * Write device file "device_mode"
 */
ssize_t razer_accessory_attr_write_device_mode(IOUSBDeviceInterface **usb_dev, const char *buf, size_t count)
{
    UInt16 product = -1;
    (*usb_dev)->GetDeviceProduct(usb_dev, &product);
    struct razer_report report = {0};

    if (count != 2) {
        printf("razeraccessory: Device mode only takes 2 bytes.");
    } else {

        report = razer_chroma_standard_set_device_mode(buf[0], buf[1]);

        switch(product) {
            case USB_DEVICE_ID_RAZER_MOUSE_BUNGEE_V3_CHROMA:
            case USB_DEVICE_ID_RAZER_BASE_STATION_V2_CHROMA:
                report.transaction_id.id = 0x1F;
                break;
        }

        razer_send_payload(usb_dev, &report);
    }

    return count;
}

ssize_t razer_accessory_attr_read_get_cup_state(IOUSBDeviceInterface **usb_dev, char *buf)
{
    struct razer_report report = get_razer_report(0x02, 0x81, 0x02);
    struct razer_report response = {0};

    response = razer_send_payload(usb_dev, &report);

    return sprintf(buf, "%u\n", response.arguments[1]);
}

/**
 * Read device file "device_mode"
 *
 * Returns a string
 */
ssize_t razer_accessory_attr_read_device_mode(IOUSBDeviceInterface **usb_dev, char *buf)
{
    UInt16 product = -1;
    (*usb_dev)->GetDeviceProduct(usb_dev, &product);
    struct razer_report report = razer_chroma_standard_get_device_mode();
    struct razer_report response = {0};

    switch(product) {
        case USB_DEVICE_ID_RAZER_MOUSE_BUNGEE_V3_CHROMA:
        case USB_DEVICE_ID_RAZER_BASE_STATION_V2_CHROMA:
            report.transaction_id.id = 0x1F;
            break;
    }

    response = razer_send_payload(usb_dev, &report);

    return sprintf(buf, "%d:%d\n", response.arguments[0], response.arguments[1]);
}

/**
 * Write device file "set_brightness"
 *
 * Sets the brightness to the ASCII number written to this file.
 */
ssize_t razer_accessory_attr_write_set_brightness(IOUSBDeviceInterface **usb_dev, ushort brightness, size_t count)
{
    UInt16 product = -1;
    (*usb_dev)->GetDeviceProduct(usb_dev, &product);
    struct razer_report report = {0};

    switch (product) {
        case USB_DEVICE_ID_RAZER_MOUSE_BUNGEE_V3_CHROMA:
        case USB_DEVICE_ID_RAZER_BASE_STATION_V2_CHROMA:
            report = razer_chroma_extended_matrix_brightness(VARSTORE, ZERO_LED, brightness);
            report.transaction_id.id = 0x1F;
            break;

        case USB_DEVICE_ID_RAZER_CHROMA_MUG:
            report = razer_chroma_standard_set_led_brightness(VARSTORE, BACKLIGHT_LED, brightness);
            break;

        case USB_DEVICE_ID_RAZER_CHROMA_HDK:
        case USB_DEVICE_ID_RAZER_CHROMA_BASE:
        case USB_DEVICE_ID_RAZER_NOMMO_PRO:
        case USB_DEVICE_ID_RAZER_NOMMO_CHROMA:
            report = razer_chroma_extended_matrix_brightness(VARSTORE, ZERO_LED, brightness);
            break;

        default:
            printf("razeraccessory: Unknown device\n");
            break;
    }

    razer_send_payload(usb_dev, &report);

    return count;
}

/**
 * Read device file "set_brightness"
 *
 * Returns brightness or -1 if the initial brightness is not known
 */
ushort razer_accessory_attr_read_set_brightness(IOUSBDeviceInterface **usb_dev)
{
    UInt16 product = -1;
    (*usb_dev)->GetDeviceProduct(usb_dev, &product);
    struct razer_report report = razer_chroma_standard_get_led_brightness(VARSTORE, BACKLIGHT_LED);
    struct razer_report response = {0};
    unsigned char brightness = 0;

    switch (product) {
        case USB_DEVICE_ID_RAZER_MOUSE_BUNGEE_V3_CHROMA:
        case USB_DEVICE_ID_RAZER_BASE_STATION_V2_CHROMA:
            break;

        default:
            response = razer_send_payload(usb_dev, &report);
            brightness = response.arguments[2];
            break;
    }

    return brightness;
}