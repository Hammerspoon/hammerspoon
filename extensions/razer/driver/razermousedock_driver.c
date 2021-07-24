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

#include "razermousedock_driver.h"
#include "razercommon.h"
#include "razerchromacommon.h"

/**
 * Send report to the dock
 */
static int razer_get_report(IOUSBDeviceInterface **usb_dev, struct razer_report *request_report, struct razer_report *response_report)
{
    UInt16 product = -1;
    (*usb_dev)->GetDeviceProduct(usb_dev, &product);

    switch (product) {
    // These devices require longer waits to read their firmware, serial, and other setting values
    case USB_DEVICE_ID_RAZER_MOUSE_CHARGING_DOCK:
        return razer_get_usb_response(usb_dev, 0x00, request_report, 0x00, response_report, RAZER_MOUSE_DOCK_WAIT_MIN_US);
        break;

    default:
        return -1;
    }
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
            printf("Response doesn't match request (mousedock)\n");
        } else if (response_report.status == RAZER_CMD_BUSY) {
            //printf("Device is busy (mousedock)\n");
        } else if (response_report.status == RAZER_CMD_FAILURE) {
            printf("Command failed (mousedock)\n");
        } else if (response_report.status == RAZER_CMD_NOT_SUPPORTED) {
            printf("Command not supported (mousedock)\n");
        } else if (response_report.status == RAZER_CMD_TIMEOUT) {
            printf("Command timed out (mousedock)\n");
        }
    } else {
        printf("Invalid Report Length (mousedock)\n");
    }

    return response_report;
}

/**
 * Write device file "mode_static"
 *
 * Static effect mode is activated whenever the file is written to with 3 bytes
 */
ssize_t razer_mouse_dock_attr_write_mode_static(IOUSBDeviceInterface **usb_dev, const char *buf, size_t count)
{
    struct razer_report report = {0};

    UInt16 product = -1;
    (*usb_dev)->GetDeviceProduct(usb_dev, &product);

    if(count == 3) {
        switch (product) {
        case USB_DEVICE_ID_RAZER_MOUSE_CHARGING_DOCK:
            report = razer_chroma_extended_matrix_effect_static(VARSTORE, ZERO_LED, (struct razer_rgb*) & buf[0]);
            break;

        default:
            printf("razerdock: logo_mode_static not supported for this model\n");
            break;
        }

        report.transaction_id.id = 0x3F;

        razer_send_payload(usb_dev, &report);

    } else {
        printf("razerdock: Static mode only accepts RGB (3byte)\n");
    }

    return count;
}


/**
 * Write device file "mode_static"
 *
 * ** NOSTORE version for efficiency in custom lighting configurations
 *
 * Static effect mode is activated whenever the file is written to with 3 bytes
 */
ssize_t razer_mouse_dock_attr_write_mode_static_no_store(IOUSBDeviceInterface **usb_dev, const char *buf, size_t count)
{
    struct razer_report report = {0};

    UInt16 product = -1;
    (*usb_dev)->GetDeviceProduct(usb_dev, &product);

    if(count == 3) {
        switch (product) {
        case USB_DEVICE_ID_RAZER_MOUSE_CHARGING_DOCK:
            report = razer_chroma_extended_matrix_effect_static(NOSTORE, ZERO_LED, (struct razer_rgb*) & buf[0]);
            break;

        default:
            printf("razerdock: logo_mode_static not supported for this model\n");
            break;
        }

        report.transaction_id.id = 0x3F;

        razer_send_payload(usb_dev, &report);
        
    } else {
        printf("razerdock: Static mode only accepts RGB (3byte)\n");
    }

    return count;
}


/**
 * Write device file "logo_mode_spectrum" (for extended mouse matrix effects)
 *
 * Spectrum effect mode is activated whenever the file is written to
 */
ssize_t razer_mouse_dock_attr_write_mode_spectrum(IOUSBDeviceInterface **usb_dev, const char *buf, size_t count)
{
    struct razer_report report = {0};

    UInt16 product = -1;
    (*usb_dev)->GetDeviceProduct(usb_dev, &product);

    switch(product) {
    case USB_DEVICE_ID_RAZER_MOUSE_CHARGING_DOCK:
        report = razer_chroma_extended_matrix_effect_spectrum(VARSTORE, ZERO_LED);
        break;

    default:
        printf("razerdock: logo_mode_spectrum not supported for this model\n");
        return count;
    }

    razer_send_payload(usb_dev, &report);
    return count;
}


/**
 * Write device file "logo_mode_breath" (for extended mouse matrix effects)
 *
 * Sets breathing mode by writing 1, 3 or 6 bytes
 */
ssize_t razer_mouse_dock_attr_write_mode_breath(IOUSBDeviceInterface **usb_dev, const char *buf, size_t count)
{
    struct razer_report report = {0};

    UInt16 product = -1;
    (*usb_dev)->GetDeviceProduct(usb_dev, &product);

    switch(product) {
    case USB_DEVICE_ID_RAZER_MOUSE_CHARGING_DOCK:
        switch(count) {
        case 3: // Single colour mode
            report = razer_chroma_extended_matrix_effect_breathing_single(VARSTORE, ZERO_LED, (struct razer_rgb*)&buf[0]);
            break;

        case 6: // Dual colour mode
            report = razer_chroma_extended_matrix_effect_breathing_dual(VARSTORE, ZERO_LED, (struct razer_rgb*)&buf[0], (struct razer_rgb*)&buf[3]);
            break;

        default: // "Random" colour mode
            report = razer_chroma_extended_matrix_effect_breathing_random(VARSTORE, ZERO_LED);
            break;
        }
        break;
    }

    report.transaction_id.id = 0x3f;

    razer_send_payload(usb_dev, &report);
    return count;
}


/**
 * Write device file "logo_mode_none" (for extended mouse matrix effects)
 *
 * No effect is activated whenever this file is written to
 */
ssize_t razer_mouse_dock_attr_write_mode_none(IOUSBDeviceInterface **usb_dev, const char *buf, size_t count)
{
    struct razer_report report = {0};

    UInt16 product = -1;
    (*usb_dev)->GetDeviceProduct(usb_dev, &product);

    switch(product) {
    case USB_DEVICE_ID_RAZER_MOUSE_CHARGING_DOCK:
        report = razer_chroma_extended_matrix_effect_none(VARSTORE, ZERO_LED);
        break;

    default:
        printf("razerdock: logo_mode_none not supported for this model\n");
        return count;
    }

    razer_send_payload(usb_dev, &report);
    return count;
}
