#include <stdio.h>
#include <stdlib.h>
#include <string.h>

#include "razerheadphone_driver.h"
#include "razercommon.h"
#include "razerchromacommon.h"
#include "razerkraken_driver.h"

/**
 * Send report to the headphone
 */
static int razer_get_report(IOUSBDeviceInterface **usb_dev, struct razer_report *request_report, struct razer_report *response_report)
{
    UInt16 product = -1;
    (*usb_dev)->GetDeviceProduct(usb_dev, &product);

    return razer_get_usb_response(usb_dev, 0x00, request_report, 0x00, response_report, RAZER_HEADPHONE_WAIT_MIN_US);
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
            printf("Response doesn't match request (headphone)\n");
        } else if (response_report.status == RAZER_CMD_FAILURE) {
            printf("Command failed (headphone)\n");
        } else if (response_report.status == RAZER_CMD_NOT_SUPPORTED) {
            printf("Command not supported (headphone)\n");
        } else if (response_report.status == RAZER_CMD_TIMEOUT) {
            printf("Command timed out (headphone)\n");
        }
    } else {
        printf("Invalid Report Length (headphone)\n");
    }

    return response_report;
}

/**
 * Write device file "mode_none"
 *
 * No effect is activated whenever this file is written to
 */
ssize_t razer_headphone_attr_write_mode_none(IOUSBDeviceInterface **usb_dev, const char *buf, size_t count)
{
    struct razer_report report = {0};

    UInt16 product = -1;
    (*usb_dev)->GetDeviceProduct(usb_dev, &product);

    switch(product) {
        case USB_DEVICE_ID_RAZER_KRAKEN_KITTY_EDITION:
        case USB_DEVICE_ID_RAZER_KRAKEN_ULTIMATE:
            report = razer_chroma_extended_matrix_effect_none(VARSTORE, ZERO_LED);
            report.transaction_id.id = 0x1F;
            break;
        case USB_DEVICE_ID_RAZER_KRAKEN_V2:
            return razer_kraken_attr_write_mode_none(usb_dev, buf, count);
        default:
            report = razer_chroma_standard_matrix_effect_none(VARSTORE, BACKLIGHT_LED);
            break;
    }

    razer_send_payload(usb_dev, &report);

    return count;
}

/**
 * Write device file "mode_breath"
 */
ssize_t razer_headphone_attr_write_mode_breath(IOUSBDeviceInterface **usb_dev, const char *buf, size_t count)
{
    struct razer_report report = {0};

    UInt16 product = -1;
    (*usb_dev)->GetDeviceProduct(usb_dev, &product);

    switch(product) {
        case USB_DEVICE_ID_RAZER_KRAKEN_KITTY_EDITION:
        case USB_DEVICE_ID_RAZER_KRAKEN_ULTIMATE:
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
        case USB_DEVICE_ID_RAZER_KRAKEN_V2:
            // "Random" colour mode
            if(count == 1) {
                count = 3;
                char color[3] = {(unsigned char)rand(), (unsigned char)rand(), (unsigned char)rand()};
                return razer_kraken_attr_write_mode_breath(usb_dev, color, count);
            }
            return razer_kraken_attr_write_mode_breath(usb_dev, buf, count);
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
 * Set the headphone to static mode when 3 RGB bytes are written
 */
ssize_t razer_headphone_attr_write_mode_static(IOUSBDeviceInterface **usb_dev, const char *buf, size_t count)
{
    struct razer_report report = {0};

    UInt16 product = -1;
    (*usb_dev)->GetDeviceProduct(usb_dev, &product);

    if(count == 3) {
        switch(product) {
            case USB_DEVICE_ID_RAZER_KRAKEN_KITTY_EDITION:
            case USB_DEVICE_ID_RAZER_KRAKEN_ULTIMATE:
                report = razer_chroma_extended_matrix_effect_static(VARSTORE, ZERO_LED, (struct razer_rgb *)&buf[0]);
                report.transaction_id.id = 0x1F;
                break;
            case USB_DEVICE_ID_RAZER_KRAKEN_V2:
                return razer_kraken_attr_write_mode_static(usb_dev, buf, count);
            default:
                report = razer_chroma_standard_matrix_effect_static(VARSTORE, BACKLIGHT_LED, (struct razer_rgb*)&buf[0]);
                break;
        }

        razer_send_payload(usb_dev, &report);
    } else {
        printf("razerheadphone: Static mode only accepts RGB (3byte)\n");
    }

    return count;
}

/**
 * Write device file "mode_static"
 *
 * ** NOSTORE version for efficiency in custom lighting configurations
 *
 * Set the headphone to static mode when 3 RGB bytes are written
 */
ssize_t razer_headphone_attr_write_mode_static_no_store(IOUSBDeviceInterface **usb_dev, const char *buf, size_t count)
{
    struct razer_report report = {0};

    UInt16 product = -1;
    (*usb_dev)->GetDeviceProduct(usb_dev, &product);

    if(count == 3) {
        switch(product) {
            case USB_DEVICE_ID_RAZER_KRAKEN_KITTY_EDITION:
            case USB_DEVICE_ID_RAZER_KRAKEN_ULTIMATE:
                report = razer_chroma_extended_matrix_effect_static(VARSTORE, ZERO_LED, (struct razer_rgb *)&buf[0]);
                report.transaction_id.id = 0x1F;
                break;
            case USB_DEVICE_ID_RAZER_KRAKEN_V2:
                return razer_kraken_attr_write_mode_static(usb_dev, buf, count);
            default:
                report = razer_chroma_standard_matrix_effect_static(NOSTORE, BACKLIGHT_LED, (struct razer_rgb*)&buf[0]);
                break;
        }

        razer_send_payload(usb_dev, &report);
    } else {
        printf("razerheadphone: Static mode only accepts RGB (3byte)\n");
    }

    return count;
}

ssize_t razer_headphone_attr_write_mode_spectrum(IOUSBDeviceInterface **usb_dev, const char *buf, size_t count)
{
    UInt16 product = -1;
    (*usb_dev)->GetDeviceProduct(usb_dev, &product);
    switch(product) {
        case USB_DEVICE_ID_RAZER_KRAKEN_V2:
            return razer_kraken_attr_write_mode_spectrum(usb_dev, buf, count);
    }
    return count;
}