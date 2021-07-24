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

#include "razermouse_driver.h"
#include "razercommon.h"
#include "razerchromacommon.h"

/**
 * Static values for mouse devices
 */
// Setup orochi2011
int orochi2011_dpi = 0x4c;
int orochi2011_poll = 500;

// Setup default values for DeathAdder 3.5G
DeathAdder3_5g da3_5g = {
        .leds = 3, // Lights up all lights
        .dpi = 1, // 3500 DPI
        .profile = 1, // Profile 1
        .poll = 1 // Poll rate 1000
};

/**
 * Send report to the mouse
 */
static int razer_get_report(IOUSBDeviceInterface **usb_dev, struct razer_report *request_report, struct razer_report *response_report)
{
    UInt16 product = -1;
    (*usb_dev)->GetDeviceProduct(usb_dev, &product);

    switch (product) {
    // These devices require longer waits to read their firmware, serial, and other setting values
    case USB_DEVICE_ID_RAZER_LANCEHEAD_WIRELESS_RECEIVER:
    case USB_DEVICE_ID_RAZER_LANCEHEAD_WIRELESS_WIRED:
    case USB_DEVICE_ID_RAZER_LANCEHEAD_WIRELESS:
    case USB_DEVICE_ID_RAZER_MAMBA_WIRELESS_RECEIVER:
    case USB_DEVICE_ID_RAZER_MAMBA_WIRELESS_WIRED:
    case USB_DEVICE_ID_RAZER_BASILISK_ULTIMATE_RECEIVER:
        return razer_get_usb_response(usb_dev, 0x00, request_report, 0x00, response_report, RAZER_NEW_MOUSE_RECEIVER_WAIT_MIN_US);
        break;

    case USB_DEVICE_ID_RAZER_VIPER_ULTIMATE_WIRELESS:
    case USB_DEVICE_ID_RAZER_VIPER_ULTIMATE_WIRED:
    case USB_DEVICE_ID_RAZER_NAGA_TRINITY:
    case USB_DEVICE_ID_RAZER_DEATHADDER_V2_PRO_WIRELESS:
    case USB_DEVICE_ID_RAZER_DEATHADDER_V2_PRO_WIRED:
        return razer_get_usb_response(usb_dev, 0x00, request_report, 0x00, response_report, RAZER_VIPER_MOUSE_RECEIVER_WAIT_MIN_US);
        break;

    default:
        return razer_get_usb_response(usb_dev, 0x00, request_report, 0x00, response_report, RAZER_MOUSE_WAIT_MIN_US);
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
            printf("Response doesn't match request (mouse)\n");
        } else if (response_report.status == RAZER_CMD_BUSY) {
            //printf("Device is busy (mouse)\n");
        } else if (response_report.status == RAZER_CMD_FAILURE) {
            printf("Command failed (mouse)\n");
        } else if (response_report.status == RAZER_CMD_NOT_SUPPORTED) {
            printf("Command not supported (mouse)\n");
        } else if (response_report.status == RAZER_CMD_TIMEOUT) {
            printf("Command timed out (mouse)\n");
        }
    } else {
        printf("Invalid Report Length (mouse)\n");
    }

    return response_report;
}

ssize_t razer_attr_write_side_mode_wave(IOUSBDeviceInterface **usb_dev, const char *buf, size_t count, int side)
{
    unsigned char direction = (unsigned char)strtol(buf, NULL, 10);
    struct razer_report report = {0};

    UInt16 product = -1;
    (*usb_dev)->GetDeviceProduct(usb_dev, &product);

    switch(product) {
        case USB_DEVICE_ID_RAZER_LANCEHEAD_WIRED:
        case USB_DEVICE_ID_RAZER_LANCEHEAD_WIRELESS:
        case USB_DEVICE_ID_RAZER_LANCEHEAD_TE_WIRED:
        case USB_DEVICE_ID_RAZER_LANCEHEAD_WIRELESS_RECEIVER:
        case USB_DEVICE_ID_RAZER_LANCEHEAD_WIRELESS_WIRED:
        case USB_DEVICE_ID_RAZER_BASILISK_ULTIMATE:
        case USB_DEVICE_ID_RAZER_BASILISK_ULTIMATE_RECEIVER:
            report = razer_chroma_extended_matrix_effect_wave(VARSTORE, side, direction, 0x28);
            break;

        case USB_DEVICE_ID_RAZER_MAMBA_ELITE:
        case USB_DEVICE_ID_RAZER_BASILISK_V2:
            report = razer_chroma_extended_matrix_effect_wave(VARSTORE, side, direction, 0x28);
            report.transaction_id.id = 0x1f;
            break;

        default:
            printf("razermouse: logo_mode_wave not supported for this model\n");
            return count;
    }

    razer_send_payload(usb_dev, &report);
    return count;
}

ssize_t razer_attr_write_side_mode_static(IOUSBDeviceInterface **usb_dev, const char *buf, size_t count, int side)
{
    struct razer_report report = {0};

    UInt16 product = -1;
    (*usb_dev)->GetDeviceProduct(usb_dev, &product);

    if(count == 3) {
        switch(product) {
            case USB_DEVICE_ID_RAZER_NAGA_CHROMA:
            case USB_DEVICE_ID_RAZER_NAGA_HEX_V2:
                report = razer_chroma_mouse_extended_matrix_effect_static(VARSTORE, side, (struct razer_rgb*)&buf[0]);
                break;

            case USB_DEVICE_ID_RAZER_DEATHADDER_ELITE:
            case USB_DEVICE_ID_RAZER_LANCEHEAD_WIRED:
            case USB_DEVICE_ID_RAZER_LANCEHEAD_WIRELESS:
            case USB_DEVICE_ID_RAZER_LANCEHEAD_TE_WIRED:
            case USB_DEVICE_ID_RAZER_LANCEHEAD_WIRELESS_RECEIVER:
            case USB_DEVICE_ID_RAZER_LANCEHEAD_WIRELESS_WIRED:
            case USB_DEVICE_ID_RAZER_DEATHADDER_ESSENTIAL:
            case USB_DEVICE_ID_RAZER_DEATHADDER_ESSENTIAL_WHITE_EDITION:
            case USB_DEVICE_ID_RAZER_MAMBA_WIRELESS_RECEIVER:
            case USB_DEVICE_ID_RAZER_MAMBA_WIRELESS_WIRED:
            case USB_DEVICE_ID_RAZER_ABYSSUS_ELITE_DVA_EDITION:
            case USB_DEVICE_ID_RAZER_ABYSSUS_ESSENTIAL:
            case USB_DEVICE_ID_RAZER_VIPER:
            case USB_DEVICE_ID_RAZER_VIPER_8KHZ:
            case USB_DEVICE_ID_RAZER_VIPER_MINI:
            case USB_DEVICE_ID_RAZER_VIPER_ULTIMATE_WIRED:
            case USB_DEVICE_ID_RAZER_NAGA_TRINITY:
            case USB_DEVICE_ID_RAZER_VIPER_ULTIMATE_WIRELESS:
            case USB_DEVICE_ID_RAZER_BASILISK:
            case USB_DEVICE_ID_RAZER_BASILISK_ULTIMATE:
            case USB_DEVICE_ID_RAZER_BASILISK_ULTIMATE_RECEIVER:
            case USB_DEVICE_ID_RAZER_DEATHADDER_V2:
            case USB_DEVICE_ID_RAZER_DEATHADDER_V2_PRO_WIRED:
            case USB_DEVICE_ID_RAZER_DEATHADDER_V2_PRO_WIRELESS:
            case USB_DEVICE_ID_RAZER_DEATHADDER_V2_MINI:
                report = razer_chroma_extended_matrix_effect_static(VARSTORE, side, (struct razer_rgb*)&buf[0]);
                break;

            case USB_DEVICE_ID_RAZER_MAMBA_ELITE:
            case USB_DEVICE_ID_RAZER_BASILISK_V2:
                report = razer_chroma_extended_matrix_effect_static(VARSTORE, side, (struct razer_rgb*)&buf[0]);
                report.transaction_id.id = 0x1f;
                break;

            default:
                printf("razermouse: logo_mode_static not supported for this model\n");
                return count;
        }

        razer_send_payload(usb_dev, &report);
    } else {
        printf("razermouse: Static mode only accepts RGB (3byte)\n");
    }
    return count;
}

ssize_t razer_attr_write_side_mode_static_no_store(IOUSBDeviceInterface **usb_dev, const char *buf, size_t count, int side)
{
    struct razer_report report = {0};

    UInt16 product = -1;
    (*usb_dev)->GetDeviceProduct(usb_dev, &product);

    if(count == 3) {
        switch(product) {
            case USB_DEVICE_ID_RAZER_NAGA_CHROMA:
            case USB_DEVICE_ID_RAZER_NAGA_HEX_V2:
                report = razer_chroma_mouse_extended_matrix_effect_static(NOSTORE, side, (struct razer_rgb*)&buf[0]);
                break;

            case USB_DEVICE_ID_RAZER_DEATHADDER_ELITE:
            case USB_DEVICE_ID_RAZER_LANCEHEAD_WIRED:
            case USB_DEVICE_ID_RAZER_LANCEHEAD_WIRELESS:
            case USB_DEVICE_ID_RAZER_LANCEHEAD_TE_WIRED:
            case USB_DEVICE_ID_RAZER_LANCEHEAD_WIRELESS_RECEIVER:
            case USB_DEVICE_ID_RAZER_LANCEHEAD_WIRELESS_WIRED:
            case USB_DEVICE_ID_RAZER_DEATHADDER_ESSENTIAL:
            case USB_DEVICE_ID_RAZER_DEATHADDER_ESSENTIAL_WHITE_EDITION:
            case USB_DEVICE_ID_RAZER_MAMBA_WIRELESS_RECEIVER:
            case USB_DEVICE_ID_RAZER_MAMBA_WIRELESS_WIRED:
            case USB_DEVICE_ID_RAZER_ABYSSUS_ELITE_DVA_EDITION:
            case USB_DEVICE_ID_RAZER_ABYSSUS_ESSENTIAL:
            case USB_DEVICE_ID_RAZER_VIPER:
            case USB_DEVICE_ID_RAZER_VIPER_8KHZ:
            case USB_DEVICE_ID_RAZER_VIPER_MINI:
            case USB_DEVICE_ID_RAZER_VIPER_ULTIMATE_WIRED:
            case USB_DEVICE_ID_RAZER_NAGA_TRINITY:
            case USB_DEVICE_ID_RAZER_VIPER_ULTIMATE_WIRELESS:
            case USB_DEVICE_ID_RAZER_BASILISK:
            case USB_DEVICE_ID_RAZER_BASILISK_ULTIMATE:
            case USB_DEVICE_ID_RAZER_BASILISK_ULTIMATE_RECEIVER:
            case USB_DEVICE_ID_RAZER_DEATHADDER_V2:
            case USB_DEVICE_ID_RAZER_DEATHADDER_V2_PRO_WIRED:
            case USB_DEVICE_ID_RAZER_DEATHADDER_V2_PRO_WIRELESS:
            case USB_DEVICE_ID_RAZER_DEATHADDER_V2_MINI:
                report = razer_chroma_extended_matrix_effect_static(NOSTORE, side, (struct razer_rgb*)&buf[0]);
                break;

            case USB_DEVICE_ID_RAZER_MAMBA_ELITE:
            case USB_DEVICE_ID_RAZER_BASILISK_V2:
                report = razer_chroma_extended_matrix_effect_static(NOSTORE, side, (struct razer_rgb*)&buf[0]);
                report.transaction_id.id = 0x1f;
                break;

            default:
                printf("razermouse: side_mode_static_no_store not supported for this model\n");
                return count;
        }

        razer_send_payload(usb_dev, &report);
    } else {
        printf("razermouse: Static mode only accepts RGB (3byte)\n");
    }
    return count;
}

ssize_t razer_attr_write_side_mode_spectrum(IOUSBDeviceInterface **usb_dev, const char *buf, size_t count, int side)
{
    struct razer_report report = {0};

    UInt16 product = -1;
    (*usb_dev)->GetDeviceProduct(usb_dev, &product);

    switch(product) {
        case USB_DEVICE_ID_RAZER_NAGA_CHROMA:
        case USB_DEVICE_ID_RAZER_NAGA_HEX_V2:
            report = razer_chroma_mouse_extended_matrix_effect_spectrum(VARSTORE, side);
            break;

        case USB_DEVICE_ID_RAZER_DEATHADDER_ELITE:
        case USB_DEVICE_ID_RAZER_LANCEHEAD_WIRED:
        case USB_DEVICE_ID_RAZER_LANCEHEAD_WIRELESS:
        case USB_DEVICE_ID_RAZER_LANCEHEAD_TE_WIRED:
        case USB_DEVICE_ID_RAZER_LANCEHEAD_WIRELESS_RECEIVER:
        case USB_DEVICE_ID_RAZER_LANCEHEAD_WIRELESS_WIRED:
        case USB_DEVICE_ID_RAZER_MAMBA_WIRELESS_RECEIVER:
        case USB_DEVICE_ID_RAZER_MAMBA_WIRELESS_WIRED:
        case USB_DEVICE_ID_RAZER_ABYSSUS_ELITE_DVA_EDITION:
        case USB_DEVICE_ID_RAZER_ABYSSUS_ESSENTIAL:
        case USB_DEVICE_ID_RAZER_VIPER:
        case USB_DEVICE_ID_RAZER_VIPER_8KHZ:
        case USB_DEVICE_ID_RAZER_VIPER_MINI:
        case USB_DEVICE_ID_RAZER_VIPER_ULTIMATE_WIRED:
        case USB_DEVICE_ID_RAZER_NAGA_TRINITY:
        case USB_DEVICE_ID_RAZER_DEATHADDER_V2_PRO_WIRELESS:
        case USB_DEVICE_ID_RAZER_DEATHADDER_V2_PRO_WIRED:
        case USB_DEVICE_ID_RAZER_VIPER_ULTIMATE_WIRELESS:
        case USB_DEVICE_ID_RAZER_BASILISK:
        case USB_DEVICE_ID_RAZER_BASILISK_ULTIMATE:
        case USB_DEVICE_ID_RAZER_BASILISK_ULTIMATE_RECEIVER:
        case USB_DEVICE_ID_RAZER_DEATHADDER_V2:
        case USB_DEVICE_ID_RAZER_DEATHADDER_V2_MINI:
            report = razer_chroma_extended_matrix_effect_spectrum(VARSTORE, side);
            break;

        case USB_DEVICE_ID_RAZER_MAMBA_ELITE:
        case USB_DEVICE_ID_RAZER_BASILISK_V2:
            report = razer_chroma_extended_matrix_effect_spectrum(VARSTORE, side);
            report.transaction_id.id = 0x1f;
            break;

        default:
            printf("razermouse: side_mode_spectrum not supported for this model\n");
            return count;
    }

    razer_send_payload(usb_dev, &report);
    return count;
}

ssize_t razer_attr_write_side_mode_breath(IOUSBDeviceInterface **usb_dev, const char *buf, size_t count, int side)
{
    struct razer_report report = {0};

    UInt16 product = -1;
    (*usb_dev)->GetDeviceProduct(usb_dev, &product);

    switch(product) {
        case USB_DEVICE_ID_RAZER_NAGA_CHROMA:
        case USB_DEVICE_ID_RAZER_NAGA_HEX_V2:
            switch(count) {
                case 3: // Single colour mode
                    report = razer_chroma_mouse_extended_matrix_effect_breathing_single(VARSTORE, side, (struct razer_rgb*)&buf[0]);
                    break;

                case 6: // Dual colour mode
                    report = razer_chroma_mouse_extended_matrix_effect_breathing_dual(VARSTORE, side, (struct razer_rgb*)&buf[0], (struct razer_rgb*)&buf[3]);
                    break;

                default: // "Random" colour mode
                    report = razer_chroma_mouse_extended_matrix_effect_breathing_random(VARSTORE, side);
                    break;
            }
            break;

        case USB_DEVICE_ID_RAZER_DEATHADDER_ELITE:
        case USB_DEVICE_ID_RAZER_LANCEHEAD_WIRED:
        case USB_DEVICE_ID_RAZER_LANCEHEAD_WIRELESS:
        case USB_DEVICE_ID_RAZER_LANCEHEAD_TE_WIRED:
        case USB_DEVICE_ID_RAZER_LANCEHEAD_WIRELESS_RECEIVER:
        case USB_DEVICE_ID_RAZER_LANCEHEAD_WIRELESS_WIRED:
        case USB_DEVICE_ID_RAZER_MAMBA_ELITE:
        case USB_DEVICE_ID_RAZER_BASILISK_V2:
        case USB_DEVICE_ID_RAZER_DEATHADDER_ESSENTIAL:
        case USB_DEVICE_ID_RAZER_DEATHADDER_ESSENTIAL_WHITE_EDITION:
        case USB_DEVICE_ID_RAZER_MAMBA_WIRELESS_RECEIVER:
        case USB_DEVICE_ID_RAZER_MAMBA_WIRELESS_WIRED:
        case USB_DEVICE_ID_RAZER_ABYSSUS_ELITE_DVA_EDITION:
        case USB_DEVICE_ID_RAZER_ABYSSUS_ESSENTIAL:
        case USB_DEVICE_ID_RAZER_VIPER:
        case USB_DEVICE_ID_RAZER_VIPER_8KHZ:
        case USB_DEVICE_ID_RAZER_VIPER_MINI:
        case USB_DEVICE_ID_RAZER_VIPER_ULTIMATE_WIRED:
        case USB_DEVICE_ID_RAZER_NAGA_TRINITY:
        case USB_DEVICE_ID_RAZER_DEATHADDER_V2_PRO_WIRELESS:
        case USB_DEVICE_ID_RAZER_DEATHADDER_V2_PRO_WIRED:
        case USB_DEVICE_ID_RAZER_VIPER_ULTIMATE_WIRELESS:
        case USB_DEVICE_ID_RAZER_BASILISK:
        case USB_DEVICE_ID_RAZER_BASILISK_ULTIMATE:
        case USB_DEVICE_ID_RAZER_BASILISK_ULTIMATE_RECEIVER:
        case USB_DEVICE_ID_RAZER_DEATHADDER_V2:
        case USB_DEVICE_ID_RAZER_DEATHADDER_V2_MINI:
            switch(count) {
                case 3: // Single colour mode
                    report = razer_chroma_extended_matrix_effect_breathing_single(VARSTORE, side, (struct razer_rgb*)&buf[0]);
                    break;

                case 6: // Dual colour mode
                    report = razer_chroma_extended_matrix_effect_breathing_dual(VARSTORE, side, (struct razer_rgb*)&buf[0], (struct razer_rgb*)&buf[3]);
                    break;

                default: // "Random" colour mode
                    report = razer_chroma_extended_matrix_effect_breathing_random(VARSTORE, side);
                    break;
            }
            break;
    }

    switch(product) {
        case USB_DEVICE_ID_RAZER_MAMBA_ELITE:
        case USB_DEVICE_ID_RAZER_BASILISK_V2:
            report.transaction_id.id = 0x1f;
            break;

        default:
            report.transaction_id.id = 0x3f;
            break;
    }

    razer_send_payload(usb_dev, &report);
    return count;
}

ssize_t razer_attr_write_side_mode_none(IOUSBDeviceInterface **usb_dev, const char *buf, size_t count, int side)
{
    struct razer_report report = {0};

    UInt16 product = -1;
    (*usb_dev)->GetDeviceProduct(usb_dev, &product);

    switch(product) {
        case USB_DEVICE_ID_RAZER_NAGA_CHROMA:
        case USB_DEVICE_ID_RAZER_NAGA_HEX_V2:
            report = razer_chroma_mouse_extended_matrix_effect_none(VARSTORE, LOGO_LED);
            break;

        case USB_DEVICE_ID_RAZER_DEATHADDER_ELITE:
        case USB_DEVICE_ID_RAZER_LANCEHEAD_WIRED:
        case USB_DEVICE_ID_RAZER_LANCEHEAD_WIRELESS:
        case USB_DEVICE_ID_RAZER_LANCEHEAD_TE_WIRED:
        case USB_DEVICE_ID_RAZER_LANCEHEAD_WIRELESS_RECEIVER:
        case USB_DEVICE_ID_RAZER_LANCEHEAD_WIRELESS_WIRED:
        case USB_DEVICE_ID_RAZER_DEATHADDER_ESSENTIAL:
        case USB_DEVICE_ID_RAZER_DEATHADDER_ESSENTIAL_WHITE_EDITION:
        case USB_DEVICE_ID_RAZER_MAMBA_WIRELESS_RECEIVER:
        case USB_DEVICE_ID_RAZER_MAMBA_WIRELESS_WIRED:
        case USB_DEVICE_ID_RAZER_ABYSSUS_ELITE_DVA_EDITION:
        case USB_DEVICE_ID_RAZER_ABYSSUS_ESSENTIAL:
        case USB_DEVICE_ID_RAZER_VIPER:
        case USB_DEVICE_ID_RAZER_VIPER_8KHZ:
        case USB_DEVICE_ID_RAZER_VIPER_MINI:
        case USB_DEVICE_ID_RAZER_VIPER_ULTIMATE_WIRED:
        case USB_DEVICE_ID_RAZER_NAGA_TRINITY:
        case USB_DEVICE_ID_RAZER_DEATHADDER_V2_PRO_WIRELESS:
        case USB_DEVICE_ID_RAZER_DEATHADDER_V2_PRO_WIRED:
        case USB_DEVICE_ID_RAZER_VIPER_ULTIMATE_WIRELESS:
        case USB_DEVICE_ID_RAZER_BASILISK:
        case USB_DEVICE_ID_RAZER_BASILISK_ULTIMATE:
        case USB_DEVICE_ID_RAZER_BASILISK_ULTIMATE_RECEIVER:
        case USB_DEVICE_ID_RAZER_DEATHADDER_V2:
        case USB_DEVICE_ID_RAZER_DEATHADDER_V2_MINI:
            report = razer_chroma_extended_matrix_effect_none(VARSTORE, side);
            break;

        case USB_DEVICE_ID_RAZER_MAMBA_ELITE:
        case USB_DEVICE_ID_RAZER_BASILISK_V2:
            report = razer_chroma_extended_matrix_effect_none(VARSTORE, side);
            report.transaction_id.id = 0x1f;
            break;

        default:
            printf("razermouse: logo_mode_none not supported for this model\n");
            return count;
    }

    razer_send_payload(usb_dev, &report);
    return count;
}

/**
 * Write device file "logo_mode_wave" (for extended mouse matrix effects)
 *
 * Wave effect mode is activated whenever the file is written to
 */
ssize_t razer_attr_write_logo_mode_wave(IOUSBDeviceInterface **usb_dev, const char *buf, size_t count)
{
    unsigned char direction = (unsigned char)strtol(buf, NULL, 10);
    struct razer_report report = {0};

    UInt16 product = -1;
    (*usb_dev)->GetDeviceProduct(usb_dev, &product);

    switch(product) {
    case USB_DEVICE_ID_RAZER_LANCEHEAD_WIRED:
    case USB_DEVICE_ID_RAZER_LANCEHEAD_WIRELESS:
    case USB_DEVICE_ID_RAZER_LANCEHEAD_TE_WIRED:
    case USB_DEVICE_ID_RAZER_LANCEHEAD_WIRELESS_RECEIVER:
    case USB_DEVICE_ID_RAZER_LANCEHEAD_WIRELESS_WIRED:
    case USB_DEVICE_ID_RAZER_BASILISK_ULTIMATE:
    case USB_DEVICE_ID_RAZER_BASILISK_ULTIMATE_RECEIVER:
        report = razer_chroma_extended_matrix_effect_wave(VARSTORE, LOGO_LED, direction, 0x28);
        break;

    case USB_DEVICE_ID_RAZER_MAMBA_ELITE:
    case USB_DEVICE_ID_RAZER_BASILISK_V2:
        report = razer_chroma_extended_matrix_effect_wave(VARSTORE, LOGO_LED, direction, 0x28);
        report.transaction_id.id = 0x1f;
        break;

    default:
        printf("razermouse: logo_mode_wave not supported for this model\n");
        return count;
    }

    razer_send_payload(usb_dev, &report);
    return count;
}

/**
 * Write device file "scroll_mode_wave" (for extended mouse matrix effects)
 *
 * Wave effect mode is activated whenever the file is written to
 */
ssize_t razer_attr_write_scroll_mode_wave(IOUSBDeviceInterface **usb_dev, const char *buf, size_t count)
{
    unsigned char direction = (unsigned char)strtol(buf, NULL, 10);
    struct razer_report report = {0};

    UInt16 product = -1;
    (*usb_dev)->GetDeviceProduct(usb_dev, &product);

    switch(product) {
        case USB_DEVICE_ID_RAZER_LANCEHEAD_WIRED:
        case USB_DEVICE_ID_RAZER_LANCEHEAD_WIRELESS:
        case USB_DEVICE_ID_RAZER_LANCEHEAD_TE_WIRED:
        case USB_DEVICE_ID_RAZER_LANCEHEAD_WIRELESS_RECEIVER:
        case USB_DEVICE_ID_RAZER_LANCEHEAD_WIRELESS_WIRED:
        case USB_DEVICE_ID_RAZER_BASILISK_ULTIMATE:
        case USB_DEVICE_ID_RAZER_BASILISK_ULTIMATE_RECEIVER:
            report = razer_chroma_extended_matrix_effect_wave(VARSTORE, SCROLL_WHEEL_LED, direction, 0x28);
            break;

        case USB_DEVICE_ID_RAZER_MAMBA_ELITE:
        case USB_DEVICE_ID_RAZER_BASILISK_V2:
            report = razer_chroma_extended_matrix_effect_wave(VARSTORE, SCROLL_WHEEL_LED, direction, 0x28);
            report.transaction_id.id = 0x1f;
            break;

        default:
            printf("razermouse: logo_mode_wave not supported for this model\n");
            return count;
    }

    razer_send_payload(usb_dev, &report);
    return count;
}

/**
 * Write device file "left_mode_wave" (for extended mouse matrix effects)
 *
 * Wave effect mode is activated whenever the file is written to
 */
ssize_t razer_attr_write_left_mode_wave(IOUSBDeviceInterface **usb_dev, const char *buf, size_t count)
{
    return razer_attr_write_side_mode_wave(usb_dev, buf, count, LEFT_SIDE_LED);
}

/**
 * Write device file "right_mode_wave" (for extended mouse matrix effects)
 *
 * Wave effect mode is activated whenever the file is written to
 */
ssize_t razer_attr_write_right_mode_wave(IOUSBDeviceInterface **usb_dev, const char *buf, size_t count)
{
    return razer_attr_write_side_mode_wave(usb_dev, buf, count, RIGHT_SIDE_LED);
}

/**
 * Write device file "logo_mode_static" (for extended mouse matrix effects)
 *
 * Set the mouse to static mode when 3 RGB bytes are written
 */
ssize_t razer_attr_write_logo_mode_static(IOUSBDeviceInterface **usb_dev, const char *buf, size_t count)
{
    struct razer_report report = {0};

    UInt16 product = -1;
    (*usb_dev)->GetDeviceProduct(usb_dev, &product);

    if(count == 3) {
        switch(product) {
        case USB_DEVICE_ID_RAZER_NAGA_CHROMA:
        case USB_DEVICE_ID_RAZER_NAGA_HEX_V2:
            report = razer_chroma_mouse_extended_matrix_effect_static(VARSTORE, LOGO_LED, (struct razer_rgb*)&buf[0]);
            break;

        case USB_DEVICE_ID_RAZER_DEATHADDER_ELITE:
        case USB_DEVICE_ID_RAZER_LANCEHEAD_WIRED:
        case USB_DEVICE_ID_RAZER_LANCEHEAD_WIRELESS:
        case USB_DEVICE_ID_RAZER_LANCEHEAD_TE_WIRED:
        case USB_DEVICE_ID_RAZER_LANCEHEAD_WIRELESS_RECEIVER:
        case USB_DEVICE_ID_RAZER_LANCEHEAD_WIRELESS_WIRED:
        case USB_DEVICE_ID_RAZER_DEATHADDER_ESSENTIAL:
        case USB_DEVICE_ID_RAZER_DEATHADDER_ESSENTIAL_WHITE_EDITION:
        case USB_DEVICE_ID_RAZER_MAMBA_WIRELESS_RECEIVER:
        case USB_DEVICE_ID_RAZER_MAMBA_WIRELESS_WIRED:
        case USB_DEVICE_ID_RAZER_ABYSSUS_ELITE_DVA_EDITION:
        case USB_DEVICE_ID_RAZER_ABYSSUS_ESSENTIAL:
        case USB_DEVICE_ID_RAZER_VIPER:
        case USB_DEVICE_ID_RAZER_VIPER_8KHZ:
        case USB_DEVICE_ID_RAZER_VIPER_MINI:
        case USB_DEVICE_ID_RAZER_VIPER_ULTIMATE_WIRED:
        case USB_DEVICE_ID_RAZER_NAGA_TRINITY:
        case USB_DEVICE_ID_RAZER_DEATHADDER_V2_PRO_WIRELESS:
        case USB_DEVICE_ID_RAZER_DEATHADDER_V2_PRO_WIRED:
        case USB_DEVICE_ID_RAZER_VIPER_ULTIMATE_WIRELESS:
        case USB_DEVICE_ID_RAZER_BASILISK:
        case USB_DEVICE_ID_RAZER_BASILISK_ULTIMATE:
        case USB_DEVICE_ID_RAZER_BASILISK_ULTIMATE_RECEIVER:
        case USB_DEVICE_ID_RAZER_DEATHADDER_V2:
        case USB_DEVICE_ID_RAZER_DEATHADDER_V2_MINI:
            report = razer_chroma_extended_matrix_effect_static(VARSTORE, LOGO_LED, (struct razer_rgb*)&buf[0]);
            break;

        case USB_DEVICE_ID_RAZER_MAMBA_ELITE:
        case USB_DEVICE_ID_RAZER_BASILISK_V2:
            report = razer_chroma_extended_matrix_effect_static(VARSTORE, LOGO_LED, (struct razer_rgb*)&buf[0]);
            report.transaction_id.id = 0x1f;
            break;
        case USB_DEVICE_ID_RAZER_ABYSSUS_V2:
            report = razer_chroma_standard_set_led_rgb(VARSTORE, LOGO_LED, (struct razer_rgb*)&buf[0]);
            report.transaction_id.id = 0x3F;
            break;
        default:
            printf("razermouse: logo_mode_static not supported for this model\n");
            return count;
        }

        razer_send_payload(usb_dev, &report);
    } else {
        printf("razermouse: Static mode only accepts RGB (3byte)\n");
    }

    return count;
}

/**
 * Write device file "logo_mode_static" (for extended mouse matrix effects)
 *
 * Set the mouse to static mode when 3 RGB bytes are written
 */
ssize_t razer_attr_write_scroll_mode_static(IOUSBDeviceInterface **usb_dev, const char *buf, size_t count)
{
    struct razer_report report = {0};

    UInt16 product = -1;
    (*usb_dev)->GetDeviceProduct(usb_dev, &product);

    if(count == 3) {
        switch(product) {
            case USB_DEVICE_ID_RAZER_NAGA_CHROMA:
            case USB_DEVICE_ID_RAZER_NAGA_HEX_V2:
                report = razer_chroma_mouse_extended_matrix_effect_static(VARSTORE, LOGO_LED, (struct razer_rgb*)&buf[0]);
                break;

            case USB_DEVICE_ID_RAZER_DEATHADDER_ELITE:
            case USB_DEVICE_ID_RAZER_LANCEHEAD_WIRED:
            case USB_DEVICE_ID_RAZER_LANCEHEAD_WIRELESS:
            case USB_DEVICE_ID_RAZER_LANCEHEAD_TE_WIRED:
            case USB_DEVICE_ID_RAZER_LANCEHEAD_WIRELESS_RECEIVER:
            case USB_DEVICE_ID_RAZER_LANCEHEAD_WIRELESS_WIRED:
            case USB_DEVICE_ID_RAZER_DEATHADDER_ESSENTIAL:
            case USB_DEVICE_ID_RAZER_DEATHADDER_ESSENTIAL_WHITE_EDITION:
            case USB_DEVICE_ID_RAZER_MAMBA_WIRELESS_RECEIVER:
            case USB_DEVICE_ID_RAZER_MAMBA_WIRELESS_WIRED:
            case USB_DEVICE_ID_RAZER_ABYSSUS_ELITE_DVA_EDITION:
            case USB_DEVICE_ID_RAZER_ABYSSUS_ESSENTIAL:
            case USB_DEVICE_ID_RAZER_VIPER:
            case USB_DEVICE_ID_RAZER_VIPER_8KHZ:
            case USB_DEVICE_ID_RAZER_VIPER_MINI:
            case USB_DEVICE_ID_RAZER_VIPER_ULTIMATE_WIRED:
            case USB_DEVICE_ID_RAZER_NAGA_TRINITY:
            case USB_DEVICE_ID_RAZER_DEATHADDER_V2_PRO_WIRELESS:
            case USB_DEVICE_ID_RAZER_DEATHADDER_V2_PRO_WIRED:
            case USB_DEVICE_ID_RAZER_VIPER_ULTIMATE_WIRELESS:
            case USB_DEVICE_ID_RAZER_BASILISK:
            case USB_DEVICE_ID_RAZER_BASILISK_ULTIMATE:
            case USB_DEVICE_ID_RAZER_BASILISK_ULTIMATE_RECEIVER:
            case USB_DEVICE_ID_RAZER_DEATHADDER_V2:
                report = razer_chroma_extended_matrix_effect_static(VARSTORE, SCROLL_WHEEL_LED, (struct razer_rgb*)&buf[0]);
                break;

            case USB_DEVICE_ID_RAZER_MAMBA_ELITE:
            case USB_DEVICE_ID_RAZER_BASILISK_V2:
                report = razer_chroma_extended_matrix_effect_static(VARSTORE, SCROLL_WHEEL_LED, (struct razer_rgb*)&buf[0]);
                report.transaction_id.id = 0x1f;
                break;
            case USB_DEVICE_ID_RAZER_ABYSSUS_V2:
                report = razer_chroma_standard_set_led_rgb(VARSTORE, SCROLL_WHEEL_LED, (struct razer_rgb*)&buf[0]);
                report.transaction_id.id = 0x3F;
                break;

            default:
                printf("razermouse: logo_mode_static not supported for this model\n");
                return count;
        }

        razer_send_payload(usb_dev, &report);
    } else {
        printf("razermouse: Static mode only accepts RGB (3byte)\n");
    }

    return count;
}

/**
 * Write device file "left_mode_wave" (for extended mouse matrix effects)
 *
 * Wave effect mode is activated whenever the file is written to
 */
ssize_t razer_attr_write_left_mode_static(IOUSBDeviceInterface **usb_dev, const char *buf, size_t count)
{
    return razer_attr_write_side_mode_static(usb_dev, buf, count, LEFT_SIDE_LED);
}

/**
 * Write device file "right_mode_static" (for extended mouse matrix effects)
 *
 * Static effect mode is activated whenever the file is written to
 */
ssize_t razer_attr_write_right_mode_static(IOUSBDeviceInterface **usb_dev, const char *buf, size_t count)
{
    return razer_attr_write_side_mode_static(usb_dev, buf, count, RIGHT_SIDE_LED);
}


/**
 * Write device file "logo_mode_static" (for extended mouse matrix effects)
 *
 * ** NOSTORE version for efficiency in custom lighting configurations
 *
 * Set the mouse to static mode when 3 RGB bytes are written
 */
ssize_t razer_attr_write_logo_mode_static_no_store(IOUSBDeviceInterface **usb_dev, const char *buf, size_t count)
{
    struct razer_report report = {0};

    UInt16 product = -1;
    (*usb_dev)->GetDeviceProduct(usb_dev, &product);

    if(count == 3) {
        switch(product) {
        case USB_DEVICE_ID_RAZER_NAGA_CHROMA:
        case USB_DEVICE_ID_RAZER_NAGA_HEX_V2:
            report = razer_chroma_mouse_extended_matrix_effect_static(NOSTORE, LOGO_LED, (struct razer_rgb*)&buf[0]);
            break;

        case USB_DEVICE_ID_RAZER_DEATHADDER_ELITE:
        case USB_DEVICE_ID_RAZER_LANCEHEAD_WIRED:
        case USB_DEVICE_ID_RAZER_LANCEHEAD_WIRELESS:
        case USB_DEVICE_ID_RAZER_LANCEHEAD_TE_WIRED:
        case USB_DEVICE_ID_RAZER_LANCEHEAD_WIRELESS_RECEIVER:
        case USB_DEVICE_ID_RAZER_LANCEHEAD_WIRELESS_WIRED:
        case USB_DEVICE_ID_RAZER_DEATHADDER_ESSENTIAL:
        case USB_DEVICE_ID_RAZER_DEATHADDER_ESSENTIAL_WHITE_EDITION:
        case USB_DEVICE_ID_RAZER_MAMBA_WIRELESS_RECEIVER:
        case USB_DEVICE_ID_RAZER_MAMBA_WIRELESS_WIRED:
        case USB_DEVICE_ID_RAZER_ABYSSUS_ELITE_DVA_EDITION:
        case USB_DEVICE_ID_RAZER_ABYSSUS_ESSENTIAL:
        case USB_DEVICE_ID_RAZER_VIPER:
        case USB_DEVICE_ID_RAZER_VIPER_MINI:
        case USB_DEVICE_ID_RAZER_VIPER_8KHZ:
        case USB_DEVICE_ID_RAZER_VIPER_ULTIMATE_WIRED:
        case USB_DEVICE_ID_RAZER_NAGA_TRINITY:
        case USB_DEVICE_ID_RAZER_DEATHADDER_V2_PRO_WIRELESS:
        case USB_DEVICE_ID_RAZER_DEATHADDER_V2_PRO_WIRED:
        case USB_DEVICE_ID_RAZER_VIPER_ULTIMATE_WIRELESS:
        case USB_DEVICE_ID_RAZER_BASILISK:
        case USB_DEVICE_ID_RAZER_BASILISK_ULTIMATE:
        case USB_DEVICE_ID_RAZER_BASILISK_ULTIMATE_RECEIVER:
        case USB_DEVICE_ID_RAZER_DEATHADDER_V2:
        case USB_DEVICE_ID_RAZER_DEATHADDER_V2_MINI:
            report = razer_chroma_extended_matrix_effect_static(NOSTORE, LOGO_LED, (struct razer_rgb*)&buf[0]);
            break;

        case USB_DEVICE_ID_RAZER_MAMBA_ELITE:
        case USB_DEVICE_ID_RAZER_BASILISK_V2:
            report = razer_chroma_extended_matrix_effect_static(NOSTORE, LOGO_LED, (struct razer_rgb*)&buf[0]);
            report.transaction_id.id = 0x1f;
            break;
        case USB_DEVICE_ID_RAZER_ABYSSUS_V2:
            report = razer_chroma_standard_set_led_rgb(NOSTORE, LOGO_LED, (struct razer_rgb*)&buf[0]);
            report.transaction_id.id = 0x1f;
            break;

        default:
            printf("razermouse: logo_mode_static not supported for this model\n");
            return count;
        }

        razer_send_payload(usb_dev, &report);
    } else {
        printf("razermouse: Static mode only accepts RGB (3byte)\n");
    }

    return count;
}

/**
 * Write device file "logo_mode_static" (for extended mouse matrix effects)
 *
 * ** NOSTORE version for efficiency in custom lighting configurations
 *
 * Set the mouse to static mode when 3 RGB bytes are written
 */
ssize_t razer_attr_write_scroll_mode_static_no_store(IOUSBDeviceInterface **usb_dev, const char *buf, size_t count)
{
    struct razer_report report = {0};

    UInt16 product = -1;
    (*usb_dev)->GetDeviceProduct(usb_dev, &product);

    if(count == 3) {
        switch(product) {
            case USB_DEVICE_ID_RAZER_NAGA_CHROMA:
            case USB_DEVICE_ID_RAZER_NAGA_HEX_V2:
                report = razer_chroma_mouse_extended_matrix_effect_static(NOSTORE, SCROLL_WHEEL_LED, (struct razer_rgb*)&buf[0]);
                break;

            case USB_DEVICE_ID_RAZER_DEATHADDER_ELITE:
            case USB_DEVICE_ID_RAZER_LANCEHEAD_WIRED:
            case USB_DEVICE_ID_RAZER_LANCEHEAD_WIRELESS:
            case USB_DEVICE_ID_RAZER_LANCEHEAD_TE_WIRED:
            case USB_DEVICE_ID_RAZER_LANCEHEAD_WIRELESS_RECEIVER:
            case USB_DEVICE_ID_RAZER_LANCEHEAD_WIRELESS_WIRED:
            case USB_DEVICE_ID_RAZER_DEATHADDER_ESSENTIAL:
            case USB_DEVICE_ID_RAZER_DEATHADDER_ESSENTIAL_WHITE_EDITION:
            case USB_DEVICE_ID_RAZER_MAMBA_WIRELESS_RECEIVER:
            case USB_DEVICE_ID_RAZER_MAMBA_WIRELESS_WIRED:
            case USB_DEVICE_ID_RAZER_ABYSSUS_ELITE_DVA_EDITION:
            case USB_DEVICE_ID_RAZER_ABYSSUS_ESSENTIAL:
            case USB_DEVICE_ID_RAZER_VIPER:
            case USB_DEVICE_ID_RAZER_VIPER_8KHZ:
            case USB_DEVICE_ID_RAZER_VIPER_MINI:
            case USB_DEVICE_ID_RAZER_VIPER_ULTIMATE_WIRED:
            case USB_DEVICE_ID_RAZER_NAGA_TRINITY:
            case USB_DEVICE_ID_RAZER_DEATHADDER_V2_PRO_WIRELESS:
            case USB_DEVICE_ID_RAZER_DEATHADDER_V2_PRO_WIRED:
            case USB_DEVICE_ID_RAZER_VIPER_ULTIMATE_WIRELESS:
            case USB_DEVICE_ID_RAZER_BASILISK:
            case USB_DEVICE_ID_RAZER_BASILISK_ULTIMATE:
            case USB_DEVICE_ID_RAZER_BASILISK_ULTIMATE_RECEIVER:
            case USB_DEVICE_ID_RAZER_DEATHADDER_V2:
                report = razer_chroma_extended_matrix_effect_static(NOSTORE, SCROLL_WHEEL_LED, (struct razer_rgb*)&buf[0]);
                break;

            case USB_DEVICE_ID_RAZER_MAMBA_ELITE:
            case USB_DEVICE_ID_RAZER_BASILISK_V2:
                report = razer_chroma_extended_matrix_effect_static(NOSTORE, SCROLL_WHEEL_LED, (struct razer_rgb*)&buf[0]);
                report.transaction_id.id = 0x1f;
                break;
            case USB_DEVICE_ID_RAZER_ABYSSUS_V2:
                report = razer_chroma_standard_set_led_rgb(NOSTORE, SCROLL_WHEEL_LED, (struct razer_rgb*)&buf[0]);
                report.transaction_id.id = 0x3F;
                break;

            default:
                printf("razermouse: logo_mode_static not supported for this model\n");
                return count;
        }

        razer_send_payload(usb_dev, &report);
    } else {
        printf("razermouse: Static mode only accepts RGB (3byte)\n");
    }

    return count;
}

/**
 * Write device file "left_mode_no_store" (for extended mouse matrix effects)
 *
 * NOSTORE version for efficiency in custom lighting configurations
 */
ssize_t razer_attr_write_left_mode_static_no_store(IOUSBDeviceInterface **usb_dev, const char *buf, size_t count)
{
    return razer_attr_write_side_mode_static_no_store(usb_dev, buf, count, LEFT_SIDE_LED);
}

/**
 * Write device file "right_mode_no_store" (for extended mouse matrix effects)
 *
 * NOSTORE version for efficiency in custom lighting configurations
 */
ssize_t razer_attr_write_right_mode_static_no_store(IOUSBDeviceInterface **usb_dev, const char *buf, size_t count)
{
    return razer_attr_write_side_mode_static_no_store(usb_dev, buf, count, RIGHT_SIDE_LED);
}

/**
 * Write device file "logo_mode_spectrum" (for extended mouse matrix effects)
 *
 * Spectrum effect mode is activated whenever the file is written to
 */
ssize_t razer_attr_write_logo_mode_spectrum(IOUSBDeviceInterface **usb_dev, const char *buf, size_t count)
{
    struct razer_report report = {0};

    UInt16 product = -1;
    (*usb_dev)->GetDeviceProduct(usb_dev, &product);

    switch(product) {
    case USB_DEVICE_ID_RAZER_NAGA_CHROMA:
    case USB_DEVICE_ID_RAZER_NAGA_HEX_V2:
        report = razer_chroma_mouse_extended_matrix_effect_spectrum(VARSTORE, LOGO_LED);
        break;

    case USB_DEVICE_ID_RAZER_DEATHADDER_ELITE:
    case USB_DEVICE_ID_RAZER_LANCEHEAD_WIRED:
    case USB_DEVICE_ID_RAZER_LANCEHEAD_WIRELESS:
    case USB_DEVICE_ID_RAZER_LANCEHEAD_TE_WIRED:
    case USB_DEVICE_ID_RAZER_LANCEHEAD_WIRELESS_RECEIVER:
    case USB_DEVICE_ID_RAZER_LANCEHEAD_WIRELESS_WIRED:
    case USB_DEVICE_ID_RAZER_MAMBA_WIRELESS_RECEIVER:
    case USB_DEVICE_ID_RAZER_MAMBA_WIRELESS_WIRED:
    case USB_DEVICE_ID_RAZER_ABYSSUS_ELITE_DVA_EDITION:
    case USB_DEVICE_ID_RAZER_ABYSSUS_ESSENTIAL:
    case USB_DEVICE_ID_RAZER_VIPER:
    case USB_DEVICE_ID_RAZER_VIPER_8KHZ:
    case USB_DEVICE_ID_RAZER_VIPER_MINI:
    case USB_DEVICE_ID_RAZER_VIPER_ULTIMATE_WIRED:
    case USB_DEVICE_ID_RAZER_NAGA_TRINITY:
    case USB_DEVICE_ID_RAZER_DEATHADDER_V2_PRO_WIRELESS:
    case USB_DEVICE_ID_RAZER_DEATHADDER_V2_PRO_WIRED:
    case USB_DEVICE_ID_RAZER_VIPER_ULTIMATE_WIRELESS:
    case USB_DEVICE_ID_RAZER_BASILISK:
    case USB_DEVICE_ID_RAZER_BASILISK_ULTIMATE:
    case USB_DEVICE_ID_RAZER_BASILISK_ULTIMATE_RECEIVER:
    case USB_DEVICE_ID_RAZER_DEATHADDER_V2:
    case USB_DEVICE_ID_RAZER_DEATHADDER_V2_MINI:
        report = razer_chroma_extended_matrix_effect_spectrum(VARSTORE, LOGO_LED);
        break;

    case USB_DEVICE_ID_RAZER_MAMBA_ELITE:
    case USB_DEVICE_ID_RAZER_BASILISK_V2:
        report = razer_chroma_extended_matrix_effect_spectrum(VARSTORE, LOGO_LED);
        report.transaction_id.id = 0x1f;
        break;

    default:
        printf("razermouse: logo_mode_spectrum not supported for this model\n");
        return count;
    }

    razer_send_payload(usb_dev, &report);
    return count;
}

/**
 * Write device file "logo_mode_spectrum" (for extended mouse matrix effects)
 *
 * Spectrum effect mode is activated whenever the file is written to
 */
ssize_t razer_attr_write_scroll_mode_spectrum(IOUSBDeviceInterface **usb_dev, const char *buf, size_t count)
{
    struct razer_report report = {0};

    UInt16 product = -1;
    (*usb_dev)->GetDeviceProduct(usb_dev, &product);

    switch(product) {
        case USB_DEVICE_ID_RAZER_NAGA_CHROMA:
        case USB_DEVICE_ID_RAZER_NAGA_HEX_V2:
            report = razer_chroma_mouse_extended_matrix_effect_spectrum(VARSTORE, SCROLL_WHEEL_LED);
            break;

        case USB_DEVICE_ID_RAZER_DEATHADDER_ELITE:
        case USB_DEVICE_ID_RAZER_LANCEHEAD_WIRED:
        case USB_DEVICE_ID_RAZER_LANCEHEAD_WIRELESS:
        case USB_DEVICE_ID_RAZER_LANCEHEAD_TE_WIRED:
        case USB_DEVICE_ID_RAZER_LANCEHEAD_WIRELESS_RECEIVER:
        case USB_DEVICE_ID_RAZER_LANCEHEAD_WIRELESS_WIRED:
        case USB_DEVICE_ID_RAZER_MAMBA_WIRELESS_RECEIVER:
        case USB_DEVICE_ID_RAZER_MAMBA_WIRELESS_WIRED:
        case USB_DEVICE_ID_RAZER_ABYSSUS_ELITE_DVA_EDITION:
        case USB_DEVICE_ID_RAZER_ABYSSUS_ESSENTIAL:
        case USB_DEVICE_ID_RAZER_VIPER:
        case USB_DEVICE_ID_RAZER_VIPER_8KHZ:
        case USB_DEVICE_ID_RAZER_VIPER_MINI:
        case USB_DEVICE_ID_RAZER_VIPER_ULTIMATE_WIRED:
        case USB_DEVICE_ID_RAZER_NAGA_TRINITY:
        case USB_DEVICE_ID_RAZER_DEATHADDER_V2_PRO_WIRELESS:
        case USB_DEVICE_ID_RAZER_DEATHADDER_V2_PRO_WIRED:
        case USB_DEVICE_ID_RAZER_VIPER_ULTIMATE_WIRELESS:
        case USB_DEVICE_ID_RAZER_BASILISK:
        case USB_DEVICE_ID_RAZER_BASILISK_ULTIMATE:
        case USB_DEVICE_ID_RAZER_BASILISK_ULTIMATE_RECEIVER:
        case USB_DEVICE_ID_RAZER_DEATHADDER_V2:
            report = razer_chroma_extended_matrix_effect_spectrum(VARSTORE, SCROLL_WHEEL_LED);
            break;

        case USB_DEVICE_ID_RAZER_MAMBA_ELITE:
        case USB_DEVICE_ID_RAZER_BASILISK_V2:
            report = razer_chroma_extended_matrix_effect_spectrum(VARSTORE, SCROLL_WHEEL_LED);
            report.transaction_id.id = 0x1f;
            break;

        default:
            printf("razermouse: logo_mode_spectrum not supported for this model\n");
            return count;
    }

    razer_send_payload(usb_dev, &report);
    return count;
}

/**
 * Write device file "left_mode_spectrum" (for extended mouse matrix effects)
 *
 * Spectrum effect mode is activated whenever the file is written to
 */
ssize_t razer_attr_write_left_mode_spectrum(IOUSBDeviceInterface **usb_dev, const char *buf, size_t count)
{
    return razer_attr_write_side_mode_spectrum(usb_dev, buf, count, LEFT_SIDE_LED);
}

/**
 * Write device file "right_mode_spectrum" (for extended mouse matrix effects)
 *
 * Spectrum effect mode is activated whenever the file is written to
 */
ssize_t razer_attr_write_right_mode_spectrum(IOUSBDeviceInterface **usb_dev, const char *buf, size_t count)
{
    return razer_attr_write_side_mode_spectrum(usb_dev, buf, count, RIGHT_SIDE_LED);
}


/**
 * Write device file "logo_mode_breath" (for extended mouse matrix effects)
 *
 * Sets breathing mode by writing 1, 3 or 6 bytes
 */
ssize_t razer_attr_write_logo_mode_breath(IOUSBDeviceInterface **usb_dev, const char *buf, size_t count)
{
    struct razer_report report = {0};

    UInt16 product = -1;
    (*usb_dev)->GetDeviceProduct(usb_dev, &product);

    switch(product) {
    case USB_DEVICE_ID_RAZER_NAGA_CHROMA:
    case USB_DEVICE_ID_RAZER_NAGA_HEX_V2:
        switch(count) {
        case 3: // Single colour mode
            report = razer_chroma_mouse_extended_matrix_effect_breathing_single(VARSTORE, LOGO_LED, (struct razer_rgb*)&buf[0]);
            break;

        case 6: // Dual colour mode
            report = razer_chroma_mouse_extended_matrix_effect_breathing_dual(VARSTORE, LOGO_LED, (struct razer_rgb*)&buf[0], (struct razer_rgb*)&buf[3]);
            break;

        default: // "Random" colour mode
            report = razer_chroma_mouse_extended_matrix_effect_breathing_random(VARSTORE, LOGO_LED);
            break;
        }
        break;

    case USB_DEVICE_ID_RAZER_DEATHADDER_ELITE:
    case USB_DEVICE_ID_RAZER_LANCEHEAD_WIRED:
    case USB_DEVICE_ID_RAZER_LANCEHEAD_WIRELESS:
    case USB_DEVICE_ID_RAZER_LANCEHEAD_TE_WIRED:
    case USB_DEVICE_ID_RAZER_LANCEHEAD_WIRELESS_RECEIVER:
    case USB_DEVICE_ID_RAZER_LANCEHEAD_WIRELESS_WIRED:
    case USB_DEVICE_ID_RAZER_MAMBA_ELITE:
    case USB_DEVICE_ID_RAZER_BASILISK_V2:
    case USB_DEVICE_ID_RAZER_DEATHADDER_ESSENTIAL:
    case USB_DEVICE_ID_RAZER_DEATHADDER_ESSENTIAL_WHITE_EDITION:
    case USB_DEVICE_ID_RAZER_MAMBA_WIRELESS_RECEIVER:
    case USB_DEVICE_ID_RAZER_MAMBA_WIRELESS_WIRED:
    case USB_DEVICE_ID_RAZER_ABYSSUS_ELITE_DVA_EDITION:
    case USB_DEVICE_ID_RAZER_ABYSSUS_ESSENTIAL:
    case USB_DEVICE_ID_RAZER_VIPER:
    case USB_DEVICE_ID_RAZER_VIPER_8KHZ:
    case USB_DEVICE_ID_RAZER_VIPER_MINI:
    case USB_DEVICE_ID_RAZER_VIPER_ULTIMATE_WIRED:
    case USB_DEVICE_ID_RAZER_NAGA_TRINITY:
    case USB_DEVICE_ID_RAZER_DEATHADDER_V2_PRO_WIRELESS:
    case USB_DEVICE_ID_RAZER_DEATHADDER_V2_PRO_WIRED:
    case USB_DEVICE_ID_RAZER_VIPER_ULTIMATE_WIRELESS:
    case USB_DEVICE_ID_RAZER_BASILISK:
    case USB_DEVICE_ID_RAZER_BASILISK_ULTIMATE:
    case USB_DEVICE_ID_RAZER_BASILISK_ULTIMATE_RECEIVER:
    case USB_DEVICE_ID_RAZER_DEATHADDER_V2:
    case USB_DEVICE_ID_RAZER_DEATHADDER_V2_MINI:
        switch(count) {
        case 3: // Single colour mode
            report = razer_chroma_extended_matrix_effect_breathing_single(VARSTORE, LOGO_LED, (struct razer_rgb*)&buf[0]);
            break;

        case 6: // Dual colour mode
            report = razer_chroma_extended_matrix_effect_breathing_dual(VARSTORE, LOGO_LED, (struct razer_rgb*)&buf[0], (struct razer_rgb*)&buf[3]);
            break;

        default: // "Random" colour mode
            report = razer_chroma_extended_matrix_effect_breathing_random(VARSTORE, LOGO_LED);
            break;
        }
        break;
    }

    switch(product) {
    case USB_DEVICE_ID_RAZER_MAMBA_ELITE:
    case USB_DEVICE_ID_RAZER_BASILISK_V2:
        report.transaction_id.id = 0x1f;
        break;

    default:
        report.transaction_id.id = 0x3f;
        break;
    }

    razer_send_payload(usb_dev, &report);
    return count;
}

/**
 * Write device file "scroll_mode_breath" (for extended mouse matrix effects)
 *
 * Sets breathing mode by writing 1, 3 or 6 bytes
 */
ssize_t razer_attr_write_scroll_mode_breath(IOUSBDeviceInterface **usb_dev, const char *buf, size_t count)
{
    struct razer_report report = {0};

    UInt16 product = -1;
    (*usb_dev)->GetDeviceProduct(usb_dev, &product);

    switch(product) {
        case USB_DEVICE_ID_RAZER_NAGA_CHROMA:
        case USB_DEVICE_ID_RAZER_NAGA_HEX_V2:
            switch(count) {
                case 3: // Single colour mode
                    report = razer_chroma_mouse_extended_matrix_effect_breathing_single(VARSTORE, SCROLL_WHEEL_LED, (struct razer_rgb*)&buf[0]);
                    break;

                case 6: // Dual colour mode
                    report = razer_chroma_mouse_extended_matrix_effect_breathing_dual(VARSTORE, SCROLL_WHEEL_LED, (struct razer_rgb*)&buf[0], (struct razer_rgb*)&buf[3]);
                    break;

                default: // "Random" colour mode
                    report = razer_chroma_mouse_extended_matrix_effect_breathing_random(VARSTORE, SCROLL_WHEEL_LED);
                    break;
            }
            break;

        case USB_DEVICE_ID_RAZER_DEATHADDER_ELITE:
        case USB_DEVICE_ID_RAZER_LANCEHEAD_WIRED:
        case USB_DEVICE_ID_RAZER_LANCEHEAD_WIRELESS:
        case USB_DEVICE_ID_RAZER_LANCEHEAD_TE_WIRED:
        case USB_DEVICE_ID_RAZER_LANCEHEAD_WIRELESS_RECEIVER:
        case USB_DEVICE_ID_RAZER_LANCEHEAD_WIRELESS_WIRED:
        case USB_DEVICE_ID_RAZER_MAMBA_ELITE:
        case USB_DEVICE_ID_RAZER_BASILISK_V2:
        case USB_DEVICE_ID_RAZER_DEATHADDER_ESSENTIAL:
        case USB_DEVICE_ID_RAZER_DEATHADDER_ESSENTIAL_WHITE_EDITION:
        case USB_DEVICE_ID_RAZER_MAMBA_WIRELESS_RECEIVER:
        case USB_DEVICE_ID_RAZER_MAMBA_WIRELESS_WIRED:
        case USB_DEVICE_ID_RAZER_ABYSSUS_ELITE_DVA_EDITION:
        case USB_DEVICE_ID_RAZER_ABYSSUS_ESSENTIAL:
        case USB_DEVICE_ID_RAZER_VIPER:
        case USB_DEVICE_ID_RAZER_VIPER_8KHZ:
        case USB_DEVICE_ID_RAZER_VIPER_MINI:
        case USB_DEVICE_ID_RAZER_VIPER_ULTIMATE_WIRED:
        case USB_DEVICE_ID_RAZER_NAGA_TRINITY:
        case USB_DEVICE_ID_RAZER_DEATHADDER_V2_PRO_WIRELESS:
        case USB_DEVICE_ID_RAZER_DEATHADDER_V2_PRO_WIRED:
        case USB_DEVICE_ID_RAZER_VIPER_ULTIMATE_WIRELESS:
        case USB_DEVICE_ID_RAZER_BASILISK:
        case USB_DEVICE_ID_RAZER_BASILISK_ULTIMATE:
        case USB_DEVICE_ID_RAZER_BASILISK_ULTIMATE_RECEIVER:
        case USB_DEVICE_ID_RAZER_DEATHADDER_V2:
            switch(count) {
                case 3: // Single colour mode
                    report = razer_chroma_extended_matrix_effect_breathing_single(VARSTORE, SCROLL_WHEEL_LED, (struct razer_rgb*)&buf[0]);
                    break;

                case 6: // Dual colour mode
                    report = razer_chroma_extended_matrix_effect_breathing_dual(VARSTORE, SCROLL_WHEEL_LED, (struct razer_rgb*)&buf[0], (struct razer_rgb*)&buf[3]);
                    break;

                default: // "Random" colour mode
                    report = razer_chroma_extended_matrix_effect_breathing_random(VARSTORE, SCROLL_WHEEL_LED);
                    break;
            }
            break;
    }

    switch(product) {
        case USB_DEVICE_ID_RAZER_MAMBA_ELITE:
        case USB_DEVICE_ID_RAZER_BASILISK_V2:
            report.transaction_id.id = 0x1f;
            break;

        default:
            report.transaction_id.id = 0x3f;
            break;
    }

    razer_send_payload(usb_dev, &report);
    return count;
}

/**
 * Write device file "left_mode_breath" (for extended mouse matrix effects)
 *
 * Sets breathing mode by writing 1, 3 or 6 bytes
 */
ssize_t razer_attr_write_left_mode_breath(IOUSBDeviceInterface **usb_dev, const char *buf, size_t count)
{
    return razer_attr_write_side_mode_breath(usb_dev, buf, count, LEFT_SIDE_LED);
}

/**
 * Write device file "right_mode_breath" (for extended mouse matrix effects)
 *
 * Sets breathing mode by writing 1, 3 or 6 bytes
 */
ssize_t razer_attr_write_right_mode_breath(IOUSBDeviceInterface **usb_dev, const char *buf, size_t count)
{
    return razer_attr_write_side_mode_breath(usb_dev, buf, count, RIGHT_SIDE_LED);
}

/**
 * Write device file "logo_mode_none" (for extended mouse matrix effects)
 *
 * No effect is activated whenever this file is written to
 */
ssize_t razer_attr_write_logo_mode_none(IOUSBDeviceInterface **usb_dev, const char *buf, size_t count)
{
    struct razer_report report = {0};

    UInt16 product = -1;
    (*usb_dev)->GetDeviceProduct(usb_dev, &product);

    switch(product) {
    case USB_DEVICE_ID_RAZER_NAGA_CHROMA:
    case USB_DEVICE_ID_RAZER_NAGA_HEX_V2:
        report = razer_chroma_mouse_extended_matrix_effect_none(VARSTORE, LOGO_LED);
        break;

    case USB_DEVICE_ID_RAZER_DEATHADDER_ELITE:
    case USB_DEVICE_ID_RAZER_LANCEHEAD_WIRED:
    case USB_DEVICE_ID_RAZER_LANCEHEAD_WIRELESS:
    case USB_DEVICE_ID_RAZER_LANCEHEAD_TE_WIRED:
    case USB_DEVICE_ID_RAZER_LANCEHEAD_WIRELESS_RECEIVER:
    case USB_DEVICE_ID_RAZER_LANCEHEAD_WIRELESS_WIRED:
    case USB_DEVICE_ID_RAZER_DEATHADDER_ESSENTIAL:
    case USB_DEVICE_ID_RAZER_DEATHADDER_ESSENTIAL_WHITE_EDITION:
    case USB_DEVICE_ID_RAZER_MAMBA_WIRELESS_RECEIVER:
    case USB_DEVICE_ID_RAZER_MAMBA_WIRELESS_WIRED:
    case USB_DEVICE_ID_RAZER_ABYSSUS_ELITE_DVA_EDITION:
    case USB_DEVICE_ID_RAZER_ABYSSUS_ESSENTIAL:
    case USB_DEVICE_ID_RAZER_VIPER:
    case USB_DEVICE_ID_RAZER_VIPER_8KHZ:
    case USB_DEVICE_ID_RAZER_VIPER_MINI:
    case USB_DEVICE_ID_RAZER_VIPER_ULTIMATE_WIRED:
    case USB_DEVICE_ID_RAZER_NAGA_TRINITY:
    case USB_DEVICE_ID_RAZER_DEATHADDER_V2_PRO_WIRELESS:
    case USB_DEVICE_ID_RAZER_DEATHADDER_V2_PRO_WIRED:
    case USB_DEVICE_ID_RAZER_VIPER_ULTIMATE_WIRELESS:
    case USB_DEVICE_ID_RAZER_BASILISK:
    case USB_DEVICE_ID_RAZER_BASILISK_ULTIMATE:
    case USB_DEVICE_ID_RAZER_BASILISK_ULTIMATE_RECEIVER:
    case USB_DEVICE_ID_RAZER_DEATHADDER_V2:
    case USB_DEVICE_ID_RAZER_DEATHADDER_V2_MINI:
        report = razer_chroma_extended_matrix_effect_none(VARSTORE, LOGO_LED);
        break;

    case USB_DEVICE_ID_RAZER_MAMBA_ELITE:
    case USB_DEVICE_ID_RAZER_BASILISK_V2:
        report = razer_chroma_extended_matrix_effect_none(VARSTORE, LOGO_LED);
        report.transaction_id.id = 0x1f;
        break;


    default:
        printf("razermouse: logo_mode_none not supported for this model\n");
        return count;
    }

    razer_send_payload(usb_dev, &report);
    return count;
}

/**
 * Write device file "logo_mode_none" (for extended mouse matrix effects)
 *
 * No effect is activated whenever this file is written to
 */
ssize_t razer_attr_write_scroll_mode_none(IOUSBDeviceInterface **usb_dev, const char *buf, size_t count)
{
    struct razer_report report = {0};

    UInt16 product = -1;
    (*usb_dev)->GetDeviceProduct(usb_dev, &product);

    switch(product) {
        case USB_DEVICE_ID_RAZER_NAGA_CHROMA:
        case USB_DEVICE_ID_RAZER_NAGA_HEX_V2:
            report = razer_chroma_mouse_extended_matrix_effect_none(VARSTORE, SCROLL_WHEEL_LED);
            break;

        case USB_DEVICE_ID_RAZER_DEATHADDER_ELITE:
        case USB_DEVICE_ID_RAZER_LANCEHEAD_WIRED:
        case USB_DEVICE_ID_RAZER_LANCEHEAD_WIRELESS:
        case USB_DEVICE_ID_RAZER_LANCEHEAD_TE_WIRED:
        case USB_DEVICE_ID_RAZER_LANCEHEAD_WIRELESS_RECEIVER:
        case USB_DEVICE_ID_RAZER_LANCEHEAD_WIRELESS_WIRED:
        case USB_DEVICE_ID_RAZER_DEATHADDER_ESSENTIAL:
        case USB_DEVICE_ID_RAZER_DEATHADDER_ESSENTIAL_WHITE_EDITION:
        case USB_DEVICE_ID_RAZER_MAMBA_WIRELESS_RECEIVER:
        case USB_DEVICE_ID_RAZER_MAMBA_WIRELESS_WIRED:
        case USB_DEVICE_ID_RAZER_ABYSSUS_ELITE_DVA_EDITION:
        case USB_DEVICE_ID_RAZER_ABYSSUS_ESSENTIAL:
        case USB_DEVICE_ID_RAZER_VIPER:
        case USB_DEVICE_ID_RAZER_VIPER_8KHZ:
        case USB_DEVICE_ID_RAZER_VIPER_MINI:
        case USB_DEVICE_ID_RAZER_VIPER_ULTIMATE_WIRED:
        case USB_DEVICE_ID_RAZER_NAGA_TRINITY:
        case USB_DEVICE_ID_RAZER_DEATHADDER_V2_PRO_WIRELESS:
        case USB_DEVICE_ID_RAZER_DEATHADDER_V2_PRO_WIRED:
        case USB_DEVICE_ID_RAZER_VIPER_ULTIMATE_WIRELESS:
        case USB_DEVICE_ID_RAZER_BASILISK:
        case USB_DEVICE_ID_RAZER_BASILISK_ULTIMATE:
        case USB_DEVICE_ID_RAZER_BASILISK_ULTIMATE_RECEIVER:
        case USB_DEVICE_ID_RAZER_DEATHADDER_V2:
            report = razer_chroma_extended_matrix_effect_none(VARSTORE, SCROLL_WHEEL_LED);
            break;

        case USB_DEVICE_ID_RAZER_MAMBA_ELITE:
        case USB_DEVICE_ID_RAZER_BASILISK_V2:
            report = razer_chroma_extended_matrix_effect_none(VARSTORE, SCROLL_WHEEL_LED);
            report.transaction_id.id = 0x1f;
            break;

        default:
            printf("razermouse: logo_mode_none not supported for this model\n");
            return count;
    }

    razer_send_payload(usb_dev, &report);
    return count;
}

/**
 * Write device file "left_mode_none" (for extended mouse matrix effects)
 *
 * No effect is activated whenever this file is written to
 */
ssize_t razer_attr_write_left_mode_none(IOUSBDeviceInterface **usb_dev, const char *buf, size_t count)
{
    return razer_attr_write_side_mode_none(usb_dev, buf, count, LEFT_SIDE_LED);
}

/**
 * Write device file "right_mode_none" (for extended mouse matrix effects)
 *
 * No effect is activated whenever this file is written to
 */
ssize_t razer_attr_write_right_mode_none(IOUSBDeviceInterface **usb_dev, const char *buf, size_t count)
{
    return razer_attr_write_side_mode_none(usb_dev, buf, count, RIGHT_SIDE_LED);
}

// These are for older mice, eg DeathAdder 2013

/**
 * Write device file "scroll_led_effect"
 */
ssize_t razer_attr_write_scroll_led_effect(IOUSBDeviceInterface **usb_dev, const char *buf, size_t count)
{
    unsigned char effect = (unsigned char)strtoul(buf, NULL, 10);
    struct razer_report report = razer_chroma_standard_set_led_effect(VARSTORE, SCROLL_WHEEL_LED, effect);
    report.transaction_id.id = 0x3F;

    razer_send_payload(usb_dev, &report);

    return count;
}

/**
 * Write device file "logo_led_effect"
 */
ssize_t razer_attr_write_logo_led_effect(IOUSBDeviceInterface **usb_dev, const char *buf, size_t count)
{
    unsigned char effect = (unsigned char)strtoul(buf, NULL, 10);
    struct razer_report report = razer_chroma_standard_set_led_effect(VARSTORE, LOGO_LED, effect);
    report.transaction_id.id = 0x3F;

    razer_send_payload(usb_dev, &report);

    return count;
}

/**
 * Write device file "logo_led_rgb"
 */
ssize_t razer_attr_write_logo_led_rgb(IOUSBDeviceInterface **usb_dev, const char *buf, size_t count)
{
    struct razer_report report = {0};

    if(count == 3) {
        report = razer_chroma_standard_set_led_rgb(VARSTORE, LOGO_LED, (struct razer_rgb*)&buf[0]);
        report.transaction_id.id = 0x3F;
        razer_send_payload(usb_dev, &report);
    } else {
        printf("razermouse: Logo LED mode only accepts RGB (3byte)\n");
    }

    return count;
}

/**
 * Write device file "mode_reactive"
 *
 * Sets reactive mode when this file is written to. A speed byte and 3 RGB bytes should be written
 */
ssize_t razer_attr_write_logo_mode_reactive(IOUSBDeviceInterface **usb_dev, const char *buf, size_t count)
{
    struct razer_report report = {0};

    UInt16 product = -1;
    (*usb_dev)->GetDeviceProduct(usb_dev, &product);

    if(count == 4) {
        unsigned char speed = (unsigned char)buf[0];

        switch(product) {
        case USB_DEVICE_ID_RAZER_NAGA_CHROMA:
        case USB_DEVICE_ID_RAZER_NAGA_HEX_V2:
            report = razer_chroma_mouse_extended_matrix_effect_reactive(VARSTORE, LOGO_LED, speed, (struct razer_rgb*)&buf[1]);
            break;

        case USB_DEVICE_ID_RAZER_DEATHADDER_ELITE:
        case USB_DEVICE_ID_RAZER_LANCEHEAD_WIRED:
        case USB_DEVICE_ID_RAZER_LANCEHEAD_WIRELESS:
        case USB_DEVICE_ID_RAZER_LANCEHEAD_TE_WIRED:
        case USB_DEVICE_ID_RAZER_LANCEHEAD_WIRELESS_RECEIVER:
        case USB_DEVICE_ID_RAZER_LANCEHEAD_WIRELESS_WIRED:
        case USB_DEVICE_ID_RAZER_MAMBA_WIRELESS_RECEIVER:
        case USB_DEVICE_ID_RAZER_MAMBA_WIRELESS_WIRED:
        case USB_DEVICE_ID_RAZER_ABYSSUS_ELITE_DVA_EDITION:
        case USB_DEVICE_ID_RAZER_ABYSSUS_ESSENTIAL:
        case USB_DEVICE_ID_RAZER_VIPER:
        case USB_DEVICE_ID_RAZER_VIPER_8KHZ:
        case USB_DEVICE_ID_RAZER_VIPER_MINI:
        case USB_DEVICE_ID_RAZER_VIPER_ULTIMATE_WIRED:
        case USB_DEVICE_ID_RAZER_NAGA_TRINITY:
        case USB_DEVICE_ID_RAZER_DEATHADDER_V2_PRO_WIRELESS:
        case USB_DEVICE_ID_RAZER_DEATHADDER_V2_PRO_WIRED:
        case USB_DEVICE_ID_RAZER_VIPER_ULTIMATE_WIRELESS:
        case USB_DEVICE_ID_RAZER_BASILISK:
        case USB_DEVICE_ID_RAZER_DEATHADDER_V2:
        case USB_DEVICE_ID_RAZER_DEATHADDER_V2_MINI:
            report = razer_chroma_extended_matrix_effect_reactive(VARSTORE, LOGO_LED, speed, (struct razer_rgb*)&buf[1]);
            break;

        case USB_DEVICE_ID_RAZER_MAMBA_ELITE:
        case USB_DEVICE_ID_RAZER_BASILISK_V2:
            report = razer_chroma_extended_matrix_effect_reactive(VARSTORE, LOGO_LED, speed, (struct razer_rgb*)&buf[1]);
            report.transaction_id.id = 0x1f;
            break;

        default:
            printf("razermouse: logo_mode_reactive not supported for this model\n");
            return count;
        }

        razer_send_payload(usb_dev, &report);

    } else {
        printf("razermouse: Reactive only accepts Speed, RGB (4byte)\n");
    }
    return count;
}

/**
 * Write device file "scroll_mode_reactive" (for extended mouse matrix effects)
 *
 * Sets reactive mode when this file is written to. A speed byte and 3 RGB bytes should be written
 */
ssize_t razer_attr_write_scroll_mode_reactive(IOUSBDeviceInterface **usb_dev, const char *buf, size_t count)
{
    struct razer_report report = {0};

    UInt16 product = -1;
    (*usb_dev)->GetDeviceProduct(usb_dev, &product);

    if(count == 4) {
        unsigned char speed = (unsigned char)buf[0];

        switch(product) {
        case USB_DEVICE_ID_RAZER_NAGA_HEX_V2:
        case USB_DEVICE_ID_RAZER_NAGA_CHROMA:
            report = razer_chroma_mouse_extended_matrix_effect_reactive(VARSTORE, SCROLL_WHEEL_LED, speed, (struct razer_rgb*)&buf[1]);
            break;

        case USB_DEVICE_ID_RAZER_DEATHADDER_ELITE:
        case USB_DEVICE_ID_RAZER_LANCEHEAD_WIRED:
        case USB_DEVICE_ID_RAZER_LANCEHEAD_WIRELESS:
        case USB_DEVICE_ID_RAZER_LANCEHEAD_TE_WIRED:
        case USB_DEVICE_ID_RAZER_LANCEHEAD_WIRELESS_RECEIVER:
        case USB_DEVICE_ID_RAZER_LANCEHEAD_WIRELESS_WIRED:
        case USB_DEVICE_ID_RAZER_MAMBA_WIRELESS_RECEIVER:
        case USB_DEVICE_ID_RAZER_MAMBA_WIRELESS_WIRED:
        case USB_DEVICE_ID_RAZER_BASILISK:
        case USB_DEVICE_ID_RAZER_DEATHADDER_V2:
        case USB_DEVICE_ID_RAZER_DEATHADDER_V2_PRO_WIRED:
        case USB_DEVICE_ID_RAZER_DEATHADDER_V2_PRO_WIRELESS:
            report = razer_chroma_extended_matrix_effect_reactive(VARSTORE, SCROLL_WHEEL_LED, speed, (struct razer_rgb*)&buf[1]);
            break;

        case USB_DEVICE_ID_RAZER_MAMBA_ELITE:
        case USB_DEVICE_ID_RAZER_BASILISK_V2:
            report = razer_chroma_extended_matrix_effect_reactive(VARSTORE, SCROLL_WHEEL_LED, speed, (struct razer_rgb*)&buf[1]);
            report.transaction_id.id = 0x1f;
            break;

        default:
            printf("razermouse: scroll_mode_reactive not supported for this model\n");
            return count;
        }

        razer_send_payload(usb_dev, &report);

    } else {
        printf("razermouse: Reactive only accepts Speed, RGB (4byte)\n");
    }
    return count;
}

ssize_t razer_attr_write_side_mode_reactive(IOUSBDeviceInterface **usb_dev, const char *buf, size_t count, int side)
{
    struct razer_report report = {0};

    UInt16 product = -1;
    (*usb_dev)->GetDeviceProduct(usb_dev, &product);

    if(count == 4) {
        unsigned char speed = (unsigned char)buf[0];

        switch(product) {
        case USB_DEVICE_ID_RAZER_LANCEHEAD_WIRED:
        case USB_DEVICE_ID_RAZER_LANCEHEAD_WIRELESS:
        case USB_DEVICE_ID_RAZER_LANCEHEAD_TE_WIRED:
        case USB_DEVICE_ID_RAZER_LANCEHEAD_WIRELESS_RECEIVER:
        case USB_DEVICE_ID_RAZER_LANCEHEAD_WIRELESS_WIRED:
            report = razer_chroma_extended_matrix_effect_reactive(VARSTORE, side, speed, (struct razer_rgb*)&buf[1]);
            break;

        case USB_DEVICE_ID_RAZER_MAMBA_ELITE:
        case USB_DEVICE_ID_RAZER_BASILISK_V2:
            report = razer_chroma_extended_matrix_effect_reactive(VARSTORE, side, speed, (struct razer_rgb*)&buf[1]);
            report.transaction_id.id = 0x1f;
            break;

        default:
            printf("razermouse: left/right mode_reactive not supported for this model\n");
            return count;
        }

        razer_send_payload(usb_dev, &report);

    } else {
        printf("razermouse: Reactive only accepts Speed, RGB (4byte)\n");
    }
    return count;
}

/**
 * Write device file "left_mode_reactive" (for extended mouse matrix effects)
 *
 * Sets reactive mode when this file is written to. A speed byte and 3 RGB bytes should be written
 */
ssize_t razer_attr_write_left_mode_reactive(IOUSBDeviceInterface **usb_dev, const char *buf, size_t count)
{
    return razer_attr_write_side_mode_reactive(usb_dev, buf, count, LEFT_SIDE_LED);
}

/**
 * Write device file "right_mode_reactive" (for extended mouse matrix effects)
 *
 * Sets reactive mode when this file is written to. A speed byte and 3 RGB bytes should be written
 */
ssize_t razer_attr_write_right_mode_reactive(IOUSBDeviceInterface **usb_dev, const char *buf, size_t count)
{
    return razer_attr_write_side_mode_reactive(usb_dev, buf, count, RIGHT_SIDE_LED);
}

ushort razer_attr_read_dpi(IOUSBDeviceInterface **usb_dev)
{
    struct razer_report report, response_report;
    report = razer_chroma_misc_get_dpi_xy(0x01);
    response_report = razer_send_payload(usb_dev, &report);
    ushort dpi_x = (response_report.arguments[1] << 8) | (response_report.arguments[2] & 0xFF);
    return dpi_x;
}

void razer_attr_write_dpi(IOUSBDeviceInterface **usb_dev, ushort dpi_x, ushort dpi_y)
{
    struct razer_report report = razer_chroma_misc_set_dpi_xy(0x01, dpi_x, dpi_y);
    razer_send_payload(usb_dev, &report);
}

ssize_t razer_attr_read_get_battery(IOUSBDeviceInterface **usb_dev, char *buf)
{
    struct razer_report report = razer_chroma_misc_get_battery_level();
    struct razer_report response_report = {0};
    UInt16 product = -1;
    (*usb_dev)->GetDeviceProduct(usb_dev, &product);

    switch (product)
    {
        case USB_DEVICE_ID_RAZER_LANCEHEAD_WIRED:
        case USB_DEVICE_ID_RAZER_LANCEHEAD_WIRELESS:
        case USB_DEVICE_ID_RAZER_MAMBA_WIRELESS_RECEIVER:
        case USB_DEVICE_ID_RAZER_MAMBA_WIRELESS_WIRED:
        case USB_DEVICE_ID_RAZER_BASILISK_ULTIMATE:
        case USB_DEVICE_ID_RAZER_BASILISK_ULTIMATE_RECEIVER:
        case USB_DEVICE_ID_RAZER_DEATHADDER_V2_PRO_WIRED:
        case USB_DEVICE_ID_RAZER_DEATHADDER_V2_PRO_WIRELESS:
            report.transaction_id.id = 0x3f;
            break;
        case USB_DEVICE_ID_RAZER_LANCEHEAD_WIRELESS_RECEIVER:
        case USB_DEVICE_ID_RAZER_LANCEHEAD_WIRELESS_WIRED:
            report.transaction_id.id = 0x1f;
            break;
    }
    response_report = razer_send_payload(usb_dev, &report);
    return sprintf(buf, "%d\n", response_report.arguments[1]);
}

/**
 * Read device file "is_charging"
 *
 * Returns 0 when not charging, 1 when charging
 */
ssize_t razer_attr_read_is_charging(IOUSBDeviceInterface **usb_dev, char *buf)
{
    struct razer_report report = razer_chroma_misc_get_charging_status();
    struct razer_report response_report = {0};
    UInt16 product = -1;
    (*usb_dev)->GetDeviceProduct(usb_dev, &product);

    switch(product) {
        case USB_DEVICE_ID_RAZER_LANCEHEAD_WIRED:
        case USB_DEVICE_ID_RAZER_LANCEHEAD_WIRELESS:
        case USB_DEVICE_ID_RAZER_MAMBA_WIRELESS_RECEIVER:
        case USB_DEVICE_ID_RAZER_MAMBA_WIRELESS_WIRED:
        case USB_DEVICE_ID_RAZER_BASILISK_ULTIMATE:
        case USB_DEVICE_ID_RAZER_BASILISK_ULTIMATE_RECEIVER:
        case USB_DEVICE_ID_RAZER_DEATHADDER_V2_PRO_WIRED:
        case USB_DEVICE_ID_RAZER_DEATHADDER_V2_PRO_WIRELESS:
            report.transaction_id.id = 0x3f;
            break;
        case USB_DEVICE_ID_RAZER_LANCEHEAD_WIRELESS_RECEIVER:
        case USB_DEVICE_ID_RAZER_LANCEHEAD_WIRELESS_WIRED:
            report.transaction_id.id = 0x1f;
            break;
    }

    response_report = razer_send_payload(usb_dev, &report);
    return sprintf(buf, "%d\n", response_report.arguments[1]);
}

/**
 * Read device file "poll_rate"
 *
 * Returns a string
 */
ushort razer_attr_read_poll_rate(IOUSBDeviceInterface **usb_dev)
{
    struct razer_report report = razer_chroma_misc_get_polling_rate();
    struct razer_report response_report = {0};
    unsigned short polling_rate = 0;

    UInt16 product = -1;
    (*usb_dev)->GetDeviceProduct(usb_dev, &product);
    switch(product) {
        case USB_DEVICE_ID_RAZER_DEATHADDER_3_5G:
            switch(da3_5g.poll) {
                case 0x01:
                    polling_rate = 1000;
                    break;
                case 0x02:
                    polling_rate = 500;
                    break;
                case 0x03:
                    polling_rate = 125;
                    break;
            }
            return polling_rate;
            break;

        case USB_DEVICE_ID_RAZER_NAGA_HEX_V2:
        case USB_DEVICE_ID_RAZER_DEATHADDER_ELITE:
        case USB_DEVICE_ID_RAZER_LANCEHEAD_WIRED:
        case USB_DEVICE_ID_RAZER_LANCEHEAD_WIRELESS:
        case USB_DEVICE_ID_RAZER_LANCEHEAD_TE_WIRED:
        case USB_DEVICE_ID_RAZER_LANCEHEAD_WIRELESS_RECEIVER:
        case USB_DEVICE_ID_RAZER_LANCEHEAD_WIRELESS_WIRED:
        case USB_DEVICE_ID_RAZER_MAMBA_WIRELESS_RECEIVER:
        case USB_DEVICE_ID_RAZER_MAMBA_WIRELESS_WIRED:
        case USB_DEVICE_ID_RAZER_BASILISK:
        case USB_DEVICE_ID_RAZER_DEATHADDER_V2:
        case USB_DEVICE_ID_RAZER_DEATHADDER_V2_PRO_WIRED:
        case USB_DEVICE_ID_RAZER_DEATHADDER_V2_PRO_WIRELESS:
        case USB_DEVICE_ID_RAZER_DEATHADDER_V2_MINI:
            report.transaction_id.id = 0x3f;
            break;

        case USB_DEVICE_ID_RAZER_NAGA_LEFT_HANDED_2020:
        case USB_DEVICE_ID_RAZER_ATHERIS_RECEIVER:
        case USB_DEVICE_ID_RAZER_BASILISK_V2:
            report.transaction_id.id = 0x1f;
            break;
    }

    if(product == USB_DEVICE_ID_RAZER_OROCHI_2011) {
        response_report.arguments[0] = orochi2011_poll;
    } else {
        response_report = razer_send_payload(usb_dev, &report);
    }

    switch(response_report.arguments[0]) {
        case 0x01:
            polling_rate = 1000;
            break;
        case  0x02:
            polling_rate = 500;
            break;
        case  0x08:
            polling_rate = 125;
            break;
    }

    return polling_rate;
}

void deathadder3_5g_set_poll_rate(IOUSBDeviceInterface **usb_dev, unsigned short poll_rate)
{
    switch(poll_rate) {
        case 1000:
            da3_5g.poll = 1;
            break;
        case 500:
            da3_5g.poll = 2;
            break;
        case 125:
            da3_5g.poll = 3;
            break;
        default: // 500
            da3_5g.poll = 2;
            break;
    }

    razer_send_control_msg_old_device(usb_dev, &da3_5g, 0x10, 0x00, 4);
}

/**
 * Write device file "poll_rate"
 *
 * Sets the poll rate
 */
void razer_attr_write_poll_rate(IOUSBDeviceInterface **usb_dev, ushort polling_rate)
{
    struct razer_report report = razer_chroma_misc_set_polling_rate(polling_rate);

    UInt16 product = -1;
    (*usb_dev)->GetDeviceProduct(usb_dev, &product);

    switch(product) {
        case USB_DEVICE_ID_RAZER_DEATHADDER_3_5G:
            deathadder3_5g_set_poll_rate(usb_dev, polling_rate);
            return;

        case USB_DEVICE_ID_RAZER_OROCHI_2011:
            orochi2011_poll = polling_rate;
            report = razer_chroma_misc_set_orochi2011_poll_dpi(orochi2011_poll, orochi2011_dpi, orochi2011_dpi);
            break;

        case USB_DEVICE_ID_RAZER_NAGA_HEX_V2:
        case USB_DEVICE_ID_RAZER_DEATHADDER_ELITE:
        case USB_DEVICE_ID_RAZER_LANCEHEAD_WIRED:
        case USB_DEVICE_ID_RAZER_LANCEHEAD_WIRELESS:
        case USB_DEVICE_ID_RAZER_LANCEHEAD_TE_WIRED:
        case USB_DEVICE_ID_RAZER_LANCEHEAD_WIRELESS_RECEIVER:
        case USB_DEVICE_ID_RAZER_LANCEHEAD_WIRELESS_WIRED:
        case USB_DEVICE_ID_RAZER_MAMBA_WIRED:
        case USB_DEVICE_ID_RAZER_MAMBA_WIRELESS:
        case USB_DEVICE_ID_RAZER_MAMBA_WIRELESS_RECEIVER:
        case USB_DEVICE_ID_RAZER_MAMBA_WIRELESS_WIRED:
        case USB_DEVICE_ID_RAZER_BASILISK:
        case USB_DEVICE_ID_RAZER_DEATHADDER_V2:
        case USB_DEVICE_ID_RAZER_DEATHADDER_V2_PRO_WIRED:
        case USB_DEVICE_ID_RAZER_DEATHADDER_V2_PRO_WIRELESS:
        case USB_DEVICE_ID_RAZER_DEATHADDER_V2_MINI:
            report.transaction_id.id = 0x3f;
            break;

        case USB_DEVICE_ID_RAZER_NAGA_LEFT_HANDED_2020:
        case USB_DEVICE_ID_RAZER_ATHERIS_RECEIVER:
        case USB_DEVICE_ID_RAZER_BASILISK_V2:
            report.transaction_id.id = 0x1f;
            break;
    }

    razer_send_payload(usb_dev, &report);
}

/**
 * Write device file "matrix_brightness"
 *
 * Sets the brightness to the ASCII number written to this file.
 */

void razer_attr_write_matrix_brightness(IOUSBDeviceInterface **usb_dev, unsigned char brightness)
{
    brightness = round(brightness * 2.55);
    struct razer_report report = {0};

    UInt16 product = -1;
    (*usb_dev)->GetDeviceProduct(usb_dev, &product);

    switch(product) {
        case USB_DEVICE_ID_RAZER_MAMBA_WIRELESS:
            report = razer_chroma_misc_set_dock_brightness(brightness);
            break;

        case USB_DEVICE_ID_RAZER_OROCHI_CHROMA:
            // Orochi sets brightness of scroll wheel apparently
            report = razer_chroma_standard_set_led_brightness(VARSTORE, SCROLL_WHEEL_LED, brightness);
            break;

        case USB_DEVICE_ID_RAZER_NAGA_HEX_V2:
            report = razer_chroma_standard_set_led_brightness(VARSTORE, BACKLIGHT_LED, brightness);
            report.transaction_id.id = 0x3f;
            break;

        case USB_DEVICE_ID_RAZER_NAGA_LEFT_HANDED_2020:
        case USB_DEVICE_ID_RAZER_MAMBA_ELITE:
            report = razer_chroma_extended_matrix_brightness(VARSTORE, 0x00, brightness);
            report.transaction_id.id = 0x1F;
            break;

        case USB_DEVICE_ID_RAZER_NAGA_TRINITY:
            // Naga Trinity uses the LED 0x00 and Matrix Brightness
            report = razer_chroma_extended_matrix_brightness(VARSTORE, 0x00, brightness);
            break;

        default:
            report = razer_chroma_standard_set_led_brightness(VARSTORE, BACKLIGHT_LED, brightness);
            break;
    }
    razer_send_payload(usb_dev, &report);
}

/**
 * Read device file "matrix_brightness"
 *
 * Returns a string
 */
ushort razer_attr_read_matrix_brightness(IOUSBDeviceInterface **usb_dev)
{
    struct razer_report report = {0};
    struct razer_report response = {0};
    unsigned char brightness_index = 0x02;

    UInt16 product = -1;
    (*usb_dev)->GetDeviceProduct(usb_dev, &product);

    switch(product) {
        case USB_DEVICE_ID_RAZER_MAMBA_WIRELESS:
            report = razer_chroma_misc_get_dock_brightness();
            brightness_index = 0x00;
            break;

        case USB_DEVICE_ID_RAZER_OROCHI_CHROMA:
            // Orochi sets brightness of scroll wheel apparently
            report = razer_chroma_standard_get_led_brightness(VARSTORE, SCROLL_WHEEL_LED);
            break;

        case USB_DEVICE_ID_RAZER_NAGA_HEX_V2:
            // Orochi sets brightness of scroll wheel apparently
            report = razer_chroma_standard_get_led_brightness(VARSTORE, BACKLIGHT_LED);
            report.transaction_id.id = 0x3f;
            break;

        case USB_DEVICE_ID_RAZER_NAGA_LEFT_HANDED_2020:
        case USB_DEVICE_ID_RAZER_MAMBA_ELITE:
            report = razer_chroma_extended_matrix_get_brightness(VARSTORE, 0x00);
            report.transaction_id.id = 0x1F;
            break;

        case USB_DEVICE_ID_RAZER_NAGA_TRINITY:
            // Naga Trinity uses the LED 0x00 and Matrix Brightness
            report = razer_chroma_extended_matrix_get_brightness(VARSTORE, 0x00);
            break;

        default:
            report = razer_chroma_standard_get_led_brightness(VARSTORE, BACKLIGHT_LED);
            break;
    }
    response = razer_send_payload(usb_dev, &report);

    if (response.status != RAZER_CMD_SUCCESSFUL) {
        return 0;
    }
    // Brightness is at arg[0] for dock and arg[1] for led_brightness
    ushort brightness = response.arguments[brightness_index];
    brightness = round(brightness / 2.55);
    return brightness;
}

/**
 * Read device file "scroll_led_brightness"
 */
ushort razer_attr_read_scroll_led_brightness(IOUSBDeviceInterface **usb_dev)
{
    struct razer_report report = razer_chroma_standard_get_led_brightness(VARSTORE, SCROLL_WHEEL_LED);
    struct razer_report response = {0};

    UInt16 product = -1;
    (*usb_dev)->GetDeviceProduct(usb_dev, &product);

    switch(product) {
        case USB_DEVICE_ID_RAZER_NAGA_HEX_V2:
            report = razer_chroma_standard_get_led_brightness(VARSTORE, SCROLL_WHEEL_LED);
            report.transaction_id.id = 0x3F;
            break;

        case USB_DEVICE_ID_RAZER_NAGA_LEFT_HANDED_2020:
        case USB_DEVICE_ID_RAZER_MAMBA_ELITE:
        case USB_DEVICE_ID_RAZER_BASILISK_V2:
            report = razer_chroma_extended_matrix_get_brightness(VARSTORE, SCROLL_WHEEL_LED);
            report.transaction_id.id = 0x1f;
            break;

        case USB_DEVICE_ID_RAZER_DEATHADDER_ELITE:
        case USB_DEVICE_ID_RAZER_LANCEHEAD_WIRED:
        case USB_DEVICE_ID_RAZER_LANCEHEAD_WIRELESS:
        case USB_DEVICE_ID_RAZER_LANCEHEAD_TE_WIRED:
        case USB_DEVICE_ID_RAZER_LANCEHEAD_WIRELESS_RECEIVER:
        case USB_DEVICE_ID_RAZER_LANCEHEAD_WIRELESS_WIRED:
        case USB_DEVICE_ID_RAZER_DEATHADDER_ESSENTIAL:
        case USB_DEVICE_ID_RAZER_DEATHADDER_ESSENTIAL_WHITE_EDITION:
        case USB_DEVICE_ID_RAZER_MAMBA_WIRELESS_RECEIVER:
        case USB_DEVICE_ID_RAZER_MAMBA_WIRELESS_WIRED:
        case USB_DEVICE_ID_RAZER_BASILISK:
        case USB_DEVICE_ID_RAZER_DEATHADDER_V2:
            report = razer_chroma_extended_matrix_get_brightness(VARSTORE, SCROLL_WHEEL_LED);
            break;

        default:
            report = razer_chroma_standard_get_led_brightness(VARSTORE, SCROLL_WHEEL_LED);
            break;
    }

    response = razer_send_payload(usb_dev, &report);

    ushort brightness = response.arguments[2];
    brightness = round(brightness / 2.55);
    return brightness;
}

/**
 * Write device file "scroll_led_brightness"
 */
void razer_attr_write_scroll_led_brightness(IOUSBDeviceInterface **usb_dev, unsigned char brightness)
{
    struct razer_report report = {0};

    UInt16 product = -1;
    (*usb_dev)->GetDeviceProduct(usb_dev, &product);

    switch(product) {
        case USB_DEVICE_ID_RAZER_NAGA_HEX_V2:
            report = razer_chroma_standard_set_led_brightness(VARSTORE, SCROLL_WHEEL_LED, brightness);
            report.transaction_id.id = 0x3F;
            break;

        case USB_DEVICE_ID_RAZER_NAGA_LEFT_HANDED_2020:
        case USB_DEVICE_ID_RAZER_MAMBA_ELITE:
        case USB_DEVICE_ID_RAZER_BASILISK_V2:
            report = razer_chroma_extended_matrix_brightness(VARSTORE, SCROLL_WHEEL_LED, brightness);
            report.transaction_id.id = 0x1f;
            break;

        case USB_DEVICE_ID_RAZER_DEATHADDER_ELITE:
        case USB_DEVICE_ID_RAZER_LANCEHEAD_WIRED:
        case USB_DEVICE_ID_RAZER_LANCEHEAD_WIRELESS:
        case USB_DEVICE_ID_RAZER_LANCEHEAD_TE_WIRED:
        case USB_DEVICE_ID_RAZER_LANCEHEAD_WIRELESS_RECEIVER:
        case USB_DEVICE_ID_RAZER_LANCEHEAD_WIRELESS_WIRED:
        case USB_DEVICE_ID_RAZER_DEATHADDER_ESSENTIAL:
        case USB_DEVICE_ID_RAZER_DEATHADDER_ESSENTIAL_WHITE_EDITION:
        case USB_DEVICE_ID_RAZER_MAMBA_WIRELESS_RECEIVER:
        case USB_DEVICE_ID_RAZER_MAMBA_WIRELESS_WIRED:
        case USB_DEVICE_ID_RAZER_BASILISK:
        case USB_DEVICE_ID_RAZER_DEATHADDER_V2:
            report = razer_chroma_extended_matrix_brightness(VARSTORE, SCROLL_WHEEL_LED, brightness);
            break;

        default:
            report = razer_chroma_standard_set_led_brightness(VARSTORE, SCROLL_WHEEL_LED, brightness);
            break;
    }

    razer_send_payload(usb_dev, &report);
}

/**
 * Read device file "logo_led_brightness"
 */
ushort razer_attr_read_logo_led_brightness(IOUSBDeviceInterface **usb_dev)
{
    struct razer_report report = {0};
    struct razer_report response = {0};

    UInt16 product = -1;
    (*usb_dev)->GetDeviceProduct(usb_dev, &product);

    switch(product) {
        case USB_DEVICE_ID_RAZER_NAGA_HEX_V2:
            report = razer_chroma_standard_get_led_brightness(VARSTORE, LOGO_LED);
            report.transaction_id.id = 0x3F;
            break;

        case USB_DEVICE_ID_RAZER_NAGA_LEFT_HANDED_2020:
        case USB_DEVICE_ID_RAZER_MAMBA_ELITE:
        case USB_DEVICE_ID_RAZER_BASILISK_V2:
            report = razer_chroma_extended_matrix_get_brightness(VARSTORE, LOGO_LED);
            report.transaction_id.id = 0x1f;
            break;

        case USB_DEVICE_ID_RAZER_DEATHADDER_ELITE:
        case USB_DEVICE_ID_RAZER_LANCEHEAD_WIRED:
        case USB_DEVICE_ID_RAZER_LANCEHEAD_WIRELESS:
        case USB_DEVICE_ID_RAZER_LANCEHEAD_TE_WIRED:
        case USB_DEVICE_ID_RAZER_LANCEHEAD_WIRELESS_RECEIVER:
        case USB_DEVICE_ID_RAZER_LANCEHEAD_WIRELESS_WIRED:
        case USB_DEVICE_ID_RAZER_DEATHADDER_ESSENTIAL:
        case USB_DEVICE_ID_RAZER_DEATHADDER_ESSENTIAL_WHITE_EDITION:
        case USB_DEVICE_ID_RAZER_MAMBA_WIRELESS_RECEIVER:
        case USB_DEVICE_ID_RAZER_MAMBA_WIRELESS_WIRED:
        case USB_DEVICE_ID_RAZER_ABYSSUS_ELITE_DVA_EDITION:
        case USB_DEVICE_ID_RAZER_ABYSSUS_ESSENTIAL:
        case USB_DEVICE_ID_RAZER_VIPER:
        case USB_DEVICE_ID_RAZER_VIPER_MINI:
        case USB_DEVICE_ID_RAZER_VIPER_ULTIMATE_WIRED:
        case USB_DEVICE_ID_RAZER_VIPER_ULTIMATE_WIRELESS:
        case USB_DEVICE_ID_RAZER_BASILISK:
        case USB_DEVICE_ID_RAZER_DEATHADDER_V2:
        case USB_DEVICE_ID_RAZER_DEATHADDER_V2_PRO_WIRED:
        case USB_DEVICE_ID_RAZER_DEATHADDER_V2_PRO_WIRELESS:
        case USB_DEVICE_ID_RAZER_DEATHADDER_V2_MINI:
            report = razer_chroma_extended_matrix_get_brightness(VARSTORE, LOGO_LED);
            break;

        default:
            report = razer_chroma_standard_get_led_brightness(VARSTORE, LOGO_LED);
            break;
    }

    response = razer_send_payload(usb_dev, &report);

    ushort brightness = response.arguments[2];
    brightness = round(brightness / 2.55);
    return brightness;
}

/**
 * Write device file "logo_led_brightness"
 */
void razer_attr_write_logo_led_brightness(IOUSBDeviceInterface **usb_dev, unsigned char brightness)
{
    struct razer_report report = {0};

    UInt16 product = -1;
    (*usb_dev)->GetDeviceProduct(usb_dev, &product);

    switch(product) {
        case USB_DEVICE_ID_RAZER_NAGA_HEX_V2:
            report = razer_chroma_standard_set_led_brightness(VARSTORE, LOGO_LED, brightness);
            report.transaction_id.id = 0x3F;
            break;

        case USB_DEVICE_ID_RAZER_NAGA_LEFT_HANDED_2020:
        case USB_DEVICE_ID_RAZER_MAMBA_ELITE:
        case USB_DEVICE_ID_RAZER_BASILISK_V2:
            report = razer_chroma_extended_matrix_brightness(VARSTORE, LOGO_LED, brightness);
            report.transaction_id.id = 0x1f;
            break;

        case USB_DEVICE_ID_RAZER_DEATHADDER_ELITE:
        case USB_DEVICE_ID_RAZER_LANCEHEAD_WIRED:
        case USB_DEVICE_ID_RAZER_LANCEHEAD_WIRELESS:
        case USB_DEVICE_ID_RAZER_LANCEHEAD_TE_WIRED:
        case USB_DEVICE_ID_RAZER_LANCEHEAD_WIRELESS_RECEIVER:
        case USB_DEVICE_ID_RAZER_LANCEHEAD_WIRELESS_WIRED:
        case USB_DEVICE_ID_RAZER_DEATHADDER_ESSENTIAL:
        case USB_DEVICE_ID_RAZER_DEATHADDER_ESSENTIAL_WHITE_EDITION:
        case USB_DEVICE_ID_RAZER_MAMBA_WIRELESS_RECEIVER:
        case USB_DEVICE_ID_RAZER_MAMBA_WIRELESS_WIRED:
        case USB_DEVICE_ID_RAZER_ABYSSUS_ELITE_DVA_EDITION:
        case USB_DEVICE_ID_RAZER_ABYSSUS_ESSENTIAL:
        case USB_DEVICE_ID_RAZER_VIPER:
        case USB_DEVICE_ID_RAZER_VIPER_MINI:
        case USB_DEVICE_ID_RAZER_VIPER_ULTIMATE_WIRED:
        case USB_DEVICE_ID_RAZER_VIPER_ULTIMATE_WIRELESS:
        case USB_DEVICE_ID_RAZER_BASILISK:
        case USB_DEVICE_ID_RAZER_DEATHADDER_V2:
        case USB_DEVICE_ID_RAZER_DEATHADDER_V2_PRO_WIRED:
        case USB_DEVICE_ID_RAZER_DEATHADDER_V2_PRO_WIRELESS:
        case USB_DEVICE_ID_RAZER_DEATHADDER_V2_MINI:
            report = razer_chroma_extended_matrix_brightness(VARSTORE, LOGO_LED, brightness);
            break;

        default:
            report = razer_chroma_standard_set_led_brightness(VARSTORE, LOGO_LED, brightness);
            break;
    }

    razer_send_payload(usb_dev, &report);
}

ushort razer_attr_read_side_led_brightness(IOUSBDeviceInterface **usb_dev, int side)
{
    struct razer_report report = {0};
    struct razer_report response = {0};

    UInt16 product = -1;
    (*usb_dev)->GetDeviceProduct(usb_dev, &product);

    switch(product) {
        case USB_DEVICE_ID_RAZER_LANCEHEAD_WIRED:
        case USB_DEVICE_ID_RAZER_LANCEHEAD_WIRELESS:
        case USB_DEVICE_ID_RAZER_LANCEHEAD_TE_WIRED:
        case USB_DEVICE_ID_RAZER_LANCEHEAD_WIRELESS_RECEIVER:
        case USB_DEVICE_ID_RAZER_LANCEHEAD_WIRELESS_WIRED:
            report = razer_chroma_extended_matrix_get_brightness(VARSTORE, side);
            break;

        case USB_DEVICE_ID_RAZER_NAGA_LEFT_HANDED_2020:
        case USB_DEVICE_ID_RAZER_MAMBA_ELITE:
            report = razer_chroma_extended_matrix_get_brightness(VARSTORE, side);
            report.transaction_id.id = 0x1f;
            break;

        default:
            report = razer_chroma_standard_get_led_brightness(VARSTORE, side);
            break;
    }

    response = razer_send_payload(usb_dev, &report);

    ushort brightness = response.arguments[2];
    brightness = round(brightness / 2.55);
    return brightness;
}

void razer_attr_write_side_led_brightness(IOUSBDeviceInterface **usb_dev, unsigned char brightness, int side)
{
    struct razer_report report = {0};

    UInt16 product = -1;
    (*usb_dev)->GetDeviceProduct(usb_dev, &product);

    switch(product) {
        case USB_DEVICE_ID_RAZER_LANCEHEAD_WIRED:
        case USB_DEVICE_ID_RAZER_LANCEHEAD_WIRELESS:
        case USB_DEVICE_ID_RAZER_LANCEHEAD_TE_WIRED:
        case USB_DEVICE_ID_RAZER_LANCEHEAD_WIRELESS_RECEIVER:
        case USB_DEVICE_ID_RAZER_LANCEHEAD_WIRELESS_WIRED:
            report = razer_chroma_extended_matrix_brightness(VARSTORE, side, brightness);
            break;

        case USB_DEVICE_ID_RAZER_NAGA_LEFT_HANDED_2020:
        case USB_DEVICE_ID_RAZER_MAMBA_ELITE:
            report = razer_chroma_extended_matrix_brightness(VARSTORE, side, brightness);
            report.transaction_id.id = 0x1f;
            break;

        default:
            report = razer_chroma_standard_set_led_brightness(VARSTORE, side, brightness);
            break;
    }

    razer_send_payload(usb_dev, &report);
}

/**
 * Read device file "left_led_brightness"
 */
ushort razer_attr_read_left_led_brightness(IOUSBDeviceInterface **usb_dev)
{
    return razer_attr_read_side_led_brightness(usb_dev, LEFT_SIDE_LED);
}

/**
 * Write device file "left_led_brightness"
 */
void razer_attr_write_left_led_brightness(IOUSBDeviceInterface **usb_dev, unsigned char brightness)
{
    return razer_attr_write_side_led_brightness(usb_dev, brightness, LEFT_SIDE_LED);
}

/**
 * Read device file "right_led_brightness"
 */
ushort razer_attr_read_right_led_brightness(IOUSBDeviceInterface **usb_dev)
{
    return razer_attr_read_side_led_brightness(usb_dev, RIGHT_SIDE_LED);
}

/**
 * Write device file "right_led_brightness"
 */
void razer_attr_write_right_led_brightness(IOUSBDeviceInterface **usb_dev, unsigned char brightness)
{
    return razer_attr_write_side_led_brightness(usb_dev, brightness, RIGHT_SIDE_LED);
}
