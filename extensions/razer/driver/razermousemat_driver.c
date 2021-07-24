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

#include "razermousemat_driver.h"
#include "razercommon.h"
#include "razerchromacommon.h"

/**
 * Send report to the mouse mat
 */
static int razer_get_report(IOUSBDeviceInterface **usb_dev, struct razer_report *request_report, struct razer_report *response_report)
{
    UInt16 product = -1;
    (*usb_dev)->GetDeviceProduct(usb_dev, &product);

    return razer_get_usb_response(usb_dev, 0x00, request_report, 0x00, response_report, RAZER_MOUSEMAT_WAIT_MIN_US);
}

/**
 * Function to send to device, get response, and actually check the response
 */
static struct razer_report razer_send_payload(IOUSBDeviceInterface **usb_dev, struct razer_report *request_report)
{
    IOReturn retval = -1;

    struct razer_report response_report = {0};

    request_report->crc = razer_calculate_crc(request_report);

    retval = razer_get_report(usb_dev, request_report, &response_report);

    if(retval == 0) {
        // Check the packet number, class and command are the same
        if(response_report.remaining_packets != request_report->remaining_packets ||
           response_report.command_class != request_report->command_class ||
           response_report.command_id.id != request_report->command_id.id) {
            printf("Response doesn't match request (mousemat)\n");
        } else if (response_report.status == RAZER_CMD_BUSY) {
            //printf("Device is busy (mousemat)\n");
        } else if (response_report.status == RAZER_CMD_FAILURE) {
            printf("Command failed (mousemat)\n");
        } else if (response_report.status == RAZER_CMD_NOT_SUPPORTED) {
            printf("Command not supported (mousemat)\n");
        } else if (response_report.status == RAZER_CMD_TIMEOUT) {
            printf("Command timed out (mousemat)\n");
        }
    } else {
        printf("Invalid Report Length (mousemat)\n");
    }

    return response_report;
}

/**
 * Write device file "mode_none"
 *
 * No effect is activated whenever this file is written to
 */
ssize_t razer_mouse_mat_attr_write_mode_none(IOUSBDeviceInterface **usb_dev, const char *buf, size_t count)
{
    struct razer_report report = {0};
    
    UInt16 product = -1;
    (*usb_dev)->GetDeviceProduct(usb_dev, &product);

    switch(product) {
    case USB_DEVICE_ID_RAZER_FIREFLY_HYPERFLUX:
    case USB_DEVICE_ID_RAZER_FIREFLY_V2:
    case USB_DEVICE_ID_RAZER_GOLIATHUS_CHROMA:
    case USB_DEVICE_ID_RAZER_GOLIATHUS_CHROMA_EXTENDED:
        report = razer_chroma_extended_matrix_effect_none(VARSTORE, ZERO_LED);
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
 * When 1 is written (as a character, 0x31) the wave effect is displayed moving anti clockwise
 * if 2 is written (0x32) then the wave effect goes clockwise
 */
ssize_t razer_mouse_mat_attr_write_mode_wave(IOUSBDeviceInterface **usb_dev, const char *buf, size_t count)
{
    unsigned char direction = (unsigned char)strtol(buf, NULL, 10);
    struct razer_report report = {0};
    
    UInt16 product = -1;
    (*usb_dev)->GetDeviceProduct(usb_dev, &product);

    switch(product) {
    case USB_DEVICE_ID_RAZER_FIREFLY_V2:
    case USB_DEVICE_ID_RAZER_FIREFLY_HYPERFLUX:
        report = razer_chroma_extended_matrix_effect_wave(VARSTORE, ZERO_LED, direction, 0x28);
        break;

    default:
        report = razer_chroma_standard_matrix_effect_wave(VARSTORE, BACKLIGHT_LED, direction);
        break;
    }

    razer_send_payload(usb_dev, &report);
    return count;
}

/**
 * Write device file "mode_breath"
 */
ssize_t razer_mouse_mat_attr_write_mode_breath(IOUSBDeviceInterface **usb_dev, const char *buf, size_t count)
{
    struct razer_report report = {0};

    UInt16 product = -1;
    (*usb_dev)->GetDeviceProduct(usb_dev, &product);

    switch(product) {
    case USB_DEVICE_ID_RAZER_FIREFLY_V2:
    case USB_DEVICE_ID_RAZER_FIREFLY_HYPERFLUX:
    case USB_DEVICE_ID_RAZER_GOLIATHUS_CHROMA:
    case USB_DEVICE_ID_RAZER_GOLIATHUS_CHROMA_EXTENDED:
        switch(count) {
        case 3: // Single colour mode
            report = razer_chroma_extended_matrix_effect_breathing_single(VARSTORE, ZERO_LED, (struct razer_rgb *)&buf[0]);
            break;

        case 6: // Dual colour mode
            report = razer_chroma_extended_matrix_effect_breathing_dual(VARSTORE, ZERO_LED, (struct razer_rgb *)&buf[0], (struct razer_rgb *)&buf[3]);
            break;

        default: // "Random" colour mode
            report = razer_chroma_extended_matrix_effect_breathing_random(VARSTORE, ZERO_LED);
            break;
        }
        break;

    default:
        switch(count) {
        case 3: // Single colour mode
            report = razer_chroma_standard_matrix_effect_breathing_single(VARSTORE, BACKLIGHT_LED, (struct razer_rgb*)&buf[0]);
            break;

        case 6: // Dual colour mode
            report = razer_chroma_standard_matrix_effect_breathing_dual(VARSTORE, BACKLIGHT_LED, (struct razer_rgb*)&buf[0], (struct razer_rgb*)&buf[3]);
            break;

        default: // "Random" colour mode
            report = razer_chroma_standard_matrix_effect_breathing_random(VARSTORE, BACKLIGHT_LED);
            break;
        }
        break;
    }

    razer_send_payload(usb_dev, &report);

    return count;
}

/**
 * Write device file "mode_static"
 *
 * Set the mousemat to static mode when 3 RGB bytes are written
 */
ssize_t razer_mouse_mat_attr_write_mode_static(IOUSBDeviceInterface **usb_dev, const char *buf, size_t count)
{
    struct razer_report report = {0};
    
    UInt16 product = -1;
    (*usb_dev)->GetDeviceProduct(usb_dev, &product);

    if(count == 3) {
        switch(product) {
        case USB_DEVICE_ID_RAZER_FIREFLY_V2:
        case USB_DEVICE_ID_RAZER_FIREFLY_HYPERFLUX:
        case USB_DEVICE_ID_RAZER_GOLIATHUS_CHROMA:
        case USB_DEVICE_ID_RAZER_GOLIATHUS_CHROMA_EXTENDED:
            report = razer_chroma_extended_matrix_effect_static(VARSTORE, ZERO_LED, (struct razer_rgb *)&buf[0]);
            break;

        default:
            report = razer_chroma_standard_matrix_effect_static(VARSTORE, BACKLIGHT_LED, (struct razer_rgb*)&buf[0]);
            break;
        }

        razer_send_payload(usb_dev, &report);
    } else {
        printf("razermousemat: Static mode only accepts RGB (3byte)\n");
    }

    return count;
}

/**
 * Write device file "mode_static"
 *
 * ** NOSTORE version for efficiency in custom lighting configurations
 * 
 * Set the mousemat to static mode when 3 RGB bytes are written
 */
ssize_t razer_mouse_mat_attr_write_mode_static_no_store(IOUSBDeviceInterface **usb_dev, const char *buf, size_t count)
{
    struct razer_report report = {0};
    
    UInt16 product = -1;
    (*usb_dev)->GetDeviceProduct(usb_dev, &product);

    if(count == 3) {
        switch(product) {
        case USB_DEVICE_ID_RAZER_FIREFLY_V2:
        case USB_DEVICE_ID_RAZER_FIREFLY_HYPERFLUX:
        case USB_DEVICE_ID_RAZER_GOLIATHUS_CHROMA:
        case USB_DEVICE_ID_RAZER_GOLIATHUS_CHROMA_EXTENDED:
            report = razer_chroma_extended_matrix_effect_static(NOSTORE, ZERO_LED, (struct razer_rgb *)&buf[0]);
            break;

        default:
            report = razer_chroma_standard_matrix_effect_static(NOSTORE, BACKLIGHT_LED, (struct razer_rgb*)&buf[0]);
            break;
        }

        razer_send_payload(usb_dev, &report);
    } else {
        printf("razermousemat: Static mode only accepts RGB (3byte)\n");
    }

    return count;
}

ssize_t razer_mouse_mat_attr_write_set_brightness(IOUSBDeviceInterface **usb_dev, ushort brightness, size_t count)
{
    UInt16 product = -1;
    (*usb_dev)->GetDeviceProduct(usb_dev, &product);
    struct razer_report report = {0};

    switch (product) {
        case USB_DEVICE_ID_RAZER_FIREFLY_HYPERFLUX:
        case USB_DEVICE_ID_RAZER_FIREFLY_V2:
        case USB_DEVICE_ID_RAZER_GOLIATHUS_CHROMA:
        case USB_DEVICE_ID_RAZER_GOLIATHUS_CHROMA_EXTENDED:
            report = razer_chroma_extended_matrix_brightness(VARSTORE, ZERO_LED, brightness);
            break;

        default:
            printf("razermousemat: Unknown device\n");
            break;
    }

    razer_send_payload(usb_dev, &report);

    return count;
}

ushort razer_mouse_mat_attr_read_set_brightness(IOUSBDeviceInterface **usb_dev)
{
    UInt16 product = -1;
    (*usb_dev)->GetDeviceProduct(usb_dev, &product);

    struct razer_report report = razer_chroma_standard_get_led_brightness(VARSTORE, BACKLIGHT_LED);
    struct razer_report response = {0};
    unsigned char brightness = 0;

    switch (product) {
        case USB_DEVICE_ID_RAZER_FIREFLY_HYPERFLUX:
        case USB_DEVICE_ID_RAZER_FIREFLY_V2:
        case USB_DEVICE_ID_RAZER_GOLIATHUS_CHROMA:
        case USB_DEVICE_ID_RAZER_GOLIATHUS_CHROMA_EXTENDED:
            brightness = 0xff; // Unfortunately, we can't read the brightness from the device directly. return dummy value.
            break;

        default:
            response = razer_send_payload(usb_dev, &report);
            brightness = response.arguments[2];
            break;
    }
    brightness = round(brightness / 2.55);
    return brightness;
}

/**
 * Write device file "mode_spectrum"
 *
 * Specrum effect mode is activated whenever the file is written to
 */
ssize_t razer_mouse_mat_attr_write_mode_spectrum(IOUSBDeviceInterface **usb_dev, const char *buf, size_t count)
{
    struct razer_report report = {0};
    
    UInt16 product = -1;
    (*usb_dev)->GetDeviceProduct(usb_dev, &product);

    switch(product) {
    case USB_DEVICE_ID_RAZER_FIREFLY_V2:
    case USB_DEVICE_ID_RAZER_FIREFLY_HYPERFLUX:
    case USB_DEVICE_ID_RAZER_GOLIATHUS_CHROMA:
    case USB_DEVICE_ID_RAZER_GOLIATHUS_CHROMA_EXTENDED:
        report = razer_chroma_extended_matrix_effect_spectrum(VARSTORE, ZERO_LED);
        break;

    default:
        report = razer_chroma_standard_matrix_effect_spectrum(VARSTORE, BACKLIGHT_LED);
        break;
    }

    razer_send_payload(usb_dev, &report);
    return count;
}