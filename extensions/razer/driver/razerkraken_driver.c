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
#include <string.h>

#include "razerkraken_driver.h"
#include "razercommon.h"

/**
 * Send USB control report to the keyboard
 * USUALLY index = 0x02
 * FIREFLY is 0
 */
IOReturn razer_kraken_send_control_msg(IOUSBDeviceInterface **dev, struct razer_kraken_request_report* data, unsigned char skip) {
    IOUSBDevRequest request;

    request.bRequest = HID_REQ_SET_REPORT; // 0x09
    request.bmRequestType = USB_TYPE_CLASS | USB_RECIP_INTERFACE | USB_DIR_OUT;
    request.wValue = 0x0204;
    request.wIndex = 0x0003;
    request.wLength = 37;
    request.pData = (void*)data;

    IOReturn result = (*dev)->DeviceRequest(dev, &request);

    // Wait
    if(skip != 1) {
        usleep(data->length * 15 * 1000);
    }
    return result;
}

static struct razer_kraken_device get_kraken_device(IOUSBDeviceInterface **dev)
{
    UInt16 product = -1;
    (*dev)->GetDeviceProduct(dev, &product);

    struct razer_kraken_device device;
    device.usb_pid = product;

    switch (product)
    {
        case USB_DEVICE_ID_RAZER_KRAKEN_V2:
            device.led_mode_address = KYLIE_SET_LED_ADDRESS;
            device.custom_address = KYLIE_CUSTOM_ADDRESS_START;
            device.breathing_address[0] = KYLIE_BREATHING1_ADDRESS_START;
            device.breathing_address[1] = KYLIE_BREATHING2_ADDRESS_START;
            device.breathing_address[2] = KYLIE_BREATHING3_ADDRESS_START;
            break;
    }

    return device;
}

/**
 * Get a request report
 *
 * report_id - The type of report
 * destination - where data is going (like ram)
 * length - amount of data
 * address - where to write data to
 */
static struct razer_kraken_request_report get_kraken_request_report(unsigned char report_id, unsigned char destination, unsigned char length, unsigned short address)
{
    struct razer_kraken_request_report report;
    memset(&report, 0, sizeof(struct razer_kraken_request_report));

    report.report_id = report_id;
    report.destination = destination;
    report.length = length;
    report.addr_h = (address >> 8);
    report.addr_l = (address & 0xFF);

    return report;
}

/**
 * Get a union containing the effect bitfield
 */
static union razer_kraken_effect_byte get_kraken_effect_byte(void)
{
    union razer_kraken_effect_byte effect_byte;
    memset(&effect_byte, 0, sizeof(union razer_kraken_effect_byte));

    return effect_byte;
}

/**
 * Write device file "mode_spectrum"
 *
 * Specrum effect mode is activated whenever the file is written to
 */
ssize_t razer_kraken_attr_write_mode_spectrum(IOUSBDeviceInterface **dev, const char *buf, size_t count)
{
    struct razer_kraken_device device = get_kraken_device(dev);
    struct razer_kraken_request_report report = get_kraken_request_report(0x04, 0x40, 0x01, device.led_mode_address);
    union razer_kraken_effect_byte effect_byte = get_kraken_effect_byte();

    // Spectrum Cycling | ON
    effect_byte.bits.on_off_static = 1;
    effect_byte.bits.spectrum_cycling = 1;

    report.arguments[0] = effect_byte.value;

    // Lock access to sending USB as adhering to the razer len*15ms delay
    razer_kraken_send_control_msg(dev, &report, 0);

    return count;
}

/**
 * Write device file "mode_none"
 *
 * None effect mode is activated whenever the file is written to
 */
ssize_t razer_kraken_attr_write_mode_none(IOUSBDeviceInterface **dev, const char *buf, size_t count)
{
    struct razer_kraken_device device = get_kraken_device(dev);
    struct razer_kraken_request_report report = get_kraken_request_report(0x04, 0x40, 0x01, device.led_mode_address);
    union razer_kraken_effect_byte effect_byte = get_kraken_effect_byte();

    // Spectrum Cycling | OFF
    effect_byte.bits.on_off_static = 0;
    effect_byte.bits.spectrum_cycling = 0;

    report.arguments[0] = effect_byte.value;

    // Lock access to sending USB as adhering to the razer len*15ms delay
    razer_kraken_send_control_msg(dev, &report, 0);

    return count;
}


/**
 * Write device file "mode_static"
 *
 * Static effect mode is activated whenever the file is written to with 3 bytes
 */
ssize_t razer_kraken_attr_write_mode_static(IOUSBDeviceInterface **dev, const char *buf, size_t count)
{
    struct razer_kraken_device device = get_kraken_device(dev);
    struct razer_kraken_request_report rgb_report = get_kraken_request_report(0x04, 0x40, count, device.breathing_address[0]);
    struct razer_kraken_request_report effect_report = get_kraken_request_report(0x04, 0x40, 0x01, device.led_mode_address);
    union razer_kraken_effect_byte effect_byte = get_kraken_effect_byte();

    if(count == 3 || count == 4) {

        rgb_report.arguments[0] = buf[0];
        rgb_report.arguments[1] = buf[1];
        rgb_report.arguments[2] = buf[2];

        if(count == 4) {
            rgb_report.arguments[3] = buf[3];
        }

        // ON/Static
        effect_byte.bits.on_off_static = 1;
        effect_report.arguments[0] = effect_byte.value;

        // Basically Kraken Classic doesn't take RGB arguments so only do it for the KrakenV1,V2,Ultimate
        switch(device.usb_pid) {
            case USB_DEVICE_ID_RAZER_KRAKEN_V2:
                razer_kraken_send_control_msg(dev, &rgb_report, 0);
                break;
        }
        // Send Set static command
        razer_kraken_send_control_msg(dev, &effect_report, 0);

    } else {
        printf("razerkraken: Static mode only accepts RGB (3byte) or RGB with intensity (4byte)\n");
    }

    return count;
}

/**
 * Write device file "mode_custom"
 *
 * Custom effect mode is activated whenever the file is written to with 3 bytes
 */
ssize_t razer_kraken_attr_write_mode_custom(IOUSBDeviceInterface **dev, const char *buf, size_t count)
{
    struct razer_kraken_device device = get_kraken_device(dev);
    struct razer_kraken_request_report rgb_report = get_kraken_request_report(0x04, 0x40, count, device.custom_address);
    struct razer_kraken_request_report effect_report = get_kraken_request_report(0x04, 0x40, 0x01, device.led_mode_address);
    union razer_kraken_effect_byte effect_byte = get_kraken_effect_byte();

    if(count == 3 || count == 4) {

        rgb_report.arguments[0] = buf[0];
        rgb_report.arguments[1] = buf[1];
        rgb_report.arguments[2] = buf[2];

        if(count == 4) {
            rgb_report.arguments[3] = buf[3];
        }

        // ON/Static
        effect_byte.bits.on_off_static = 1;
        effect_report.arguments[0] = 1; //effect_byte.value;

        // Lock sending of the 2 commands
        razer_kraken_send_control_msg(dev, &rgb_report, 1);
        razer_kraken_send_control_msg(dev, &effect_report, 1);

    } else {
        printf("razerkraken: Custom mode only accepts RGB (3byte) or RGB with intensity (4byte)\n");
    }

    return count;
}


/**
 * Write device file "mode_breath"
 *
 * Breathing effect mode is activated whenever the file is written to with 3,6 or 9 bytes
 */
ssize_t razer_kraken_attr_write_mode_breath(IOUSBDeviceInterface **dev, const char *buf, size_t count)
{
    struct razer_kraken_device device = get_kraken_device(dev);
    struct razer_kraken_request_report effect_report = get_kraken_request_report(0x04, 0x40, 0x01, device.led_mode_address);
    union razer_kraken_effect_byte effect_byte = get_kraken_effect_byte();

    // Short circuit here as rainie only does breathing1
    if(device.usb_pid == USB_DEVICE_ID_RAZER_KRAKEN && count != 3) {
        printf("razerkraken: Breathing mode only accepts RGB (3byte)\n");
        return count;
    }

    if(count == 3) {
        struct razer_kraken_request_report rgb_report = get_kraken_request_report(0x04, 0x40, 0x03, device.breathing_address[0]);

        rgb_report.arguments[0] = buf[0];
        rgb_report.arguments[1] = buf[1];
        rgb_report.arguments[2] = buf[2];

        // ON/Static
        effect_byte.bits.on_off_static = 1;
        effect_byte.bits.single_colour_breathing = 1;
        effect_byte.bits.sync = 1;
        effect_report.arguments[0] = effect_byte.value;

        // Lock sending of the 2 commands
        razer_kraken_send_control_msg(dev, &rgb_report, 0);

        razer_kraken_send_control_msg(dev, &effect_report, 0);
    } else if(count == 6) {
        struct razer_kraken_request_report rgb_report  = get_kraken_request_report(0x04, 0x40, 0x03, device.breathing_address[1]);
        struct razer_kraken_request_report rgb_report2 = get_kraken_request_report(0x04, 0x40, 0x03, device.breathing_address[1]+4); // Address the 2nd set of colours

        rgb_report.arguments[0] = buf[0];
        rgb_report.arguments[1] = buf[1];
        rgb_report.arguments[2] = buf[2];
        rgb_report2.arguments[0] = buf[3];
        rgb_report2.arguments[1] = buf[4];
        rgb_report2.arguments[2] = buf[5];

        // ON/Static
        effect_byte.bits.on_off_static = 1;
        effect_byte.bits.two_colour_breathing = 1;
        effect_byte.bits.sync = 1;
        effect_report.arguments[0] = effect_byte.value;

        // Lock sending of the 2 commands
        razer_kraken_send_control_msg(dev, &rgb_report, 0);

        razer_kraken_send_control_msg(dev, &rgb_report2, 0);

        razer_kraken_send_control_msg(dev, &effect_report, 0);

    } else if(count == 9) {
        struct razer_kraken_request_report rgb_report  = get_kraken_request_report(0x04, 0x40, 0x03, device.breathing_address[2]);
        struct razer_kraken_request_report rgb_report2 = get_kraken_request_report(0x04, 0x40, 0x03, device.breathing_address[2]+4); // Address the 2nd set of colours
        struct razer_kraken_request_report rgb_report3 = get_kraken_request_report(0x04, 0x40, 0x03, device.breathing_address[2]+8); // Address the 3rd set of colours

        rgb_report.arguments[0] = buf[0];
        rgb_report.arguments[1] = buf[1];
        rgb_report.arguments[2] = buf[2];
        rgb_report2.arguments[0] = buf[3];
        rgb_report2.arguments[1] = buf[4];
        rgb_report2.arguments[2] = buf[5];
        rgb_report3.arguments[0] = buf[6];
        rgb_report3.arguments[1] = buf[7];
        rgb_report3.arguments[2] = buf[8];

        // ON/Static
        effect_byte.bits.on_off_static = 1;
        effect_byte.bits.three_colour_breathing = 1;
        effect_byte.bits.sync = 1;
        effect_report.arguments[0] = effect_byte.value;

        // Lock sending of the 2 commands
        razer_kraken_send_control_msg(dev, &rgb_report, 0);

        razer_kraken_send_control_msg(dev, &rgb_report2, 0);

        razer_kraken_send_control_msg(dev, &rgb_report3, 0);

        razer_kraken_send_control_msg(dev, &effect_report, 0);

    } else {
        printf("razerkraken: Breathing mode only accepts RGB (3byte), RGB RGB (6byte) or RGB RGB RGB (9byte)\n");
    }

    return count;
}