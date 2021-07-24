//
//  razercommon.h
//  RazerBlade
//
//

#ifndef DRIVER_RAZERCOMMON_H_
#define DRIVER_RAZERCOMMON_H_

#include <IOKit/usb/IOUSBLib.h>

// Linux pre-process defintions
#define HID_REQ_GET_REPORT 0x01
#define HID_REQ_SET_REPORT 0x09

#define USB_TYPE_CLASS (0x01 << 5)
#define USB_RECIP_INTERFACE 0x01
#define USB_DIR_OUT 0
#define USB_DIR_IN  0x80

/* Each USB report has 90 bytes*/
#define RAZER_USB_REPORT_LEN 0x5A

// LED STATE
#define OFF 0x00
#define ON  0x01

// LED definitions
#define ZERO_LED          0x00
#define SCROLL_WHEEL_LED  0x01
#define BATTERY_LED       0x03
#define LOGO_LED          0x04
#define BACKLIGHT_LED     0x05
#define MACRO_LED         0x07
#define GAME_LED          0x08
#define RED_PROFILE_LED   0x0C
#define GREEN_PROFILE_LED 0x0D
#define BLUE_PROFILE_LED  0x0E
#define RIGHT_SIDE_LED    0x10
#define LEFT_SIDE_LED     0x11

// LED STORAGE Options
#define NOSTORE          0x00
#define VARSTORE         0x01

// LED Effect definitions
#define LED_STATIC           0x00
#define LED_BLINKING         0x01
#define LED_PULSATING        0x02
#define LED_SPECTRUM_CYCLING 0x04


// Report Responses
#define RAZER_CMD_BUSY          0x01
#define RAZER_CMD_SUCCESSFUL    0x02
#define RAZER_CMD_FAILURE       0x03
#define RAZER_CMD_TIMEOUT       0x04
#define RAZER_CMD_NOT_SUPPORTED 0x05

struct razer_rgb {
    unsigned char r,g,b;
};

union transaction_id_union {
    unsigned char id;
    struct transaction_parts {
        unsigned char device : 3;
        unsigned char id : 5;
    } parts;
};

union command_id_union {
    unsigned char id;
    struct command_id_parts {
        unsigned char direction : 1;
        unsigned char id : 7;
    } parts;
};

/* Status:
 * 0x00 New Command
 * 0x01 Command Busy
 * 0x02 Command Successful
 * 0x03 Command Failure
 * 0x04 Command No Response / Command Timeout
 * 0x05 Command Not Support
 *
 * Transaction ID used to group request-response, device useful when multiple devices are on one usb
 * Remaining Packets is the number of remaining packets in the sequence
 * Protocol Type is always 0x00
 * Data Size is the size of payload, cannot be greater than 80. 90 = header (8B) + data + CRC (1B) + Reserved (1B)
 * Command Class is the type of command being issued
 * Command ID is the type of command being send. Direction 0 is Host->Device, Direction 1 is Device->Host. AKA Get LED 0x80, Set LED 0x00
 *
 * */

struct razer_report {
    unsigned char status;
    union transaction_id_union transaction_id; /* */
    unsigned short remaining_packets; /* Big Endian */
    unsigned char protocol_type; /*0x0*/
    unsigned char data_size;
    unsigned char command_class;
    union command_id_union command_id;
    unsigned char arguments[80];
    unsigned char crc;/*xor'ed bytes of report*/
    unsigned char reserved; /*0x0*/
};

IOReturn razer_send_control_msg(IOUSBDeviceInterface **dev, void const *data, uint report_index);
IOReturn razer_send_control_msg_old_device(IOUSBDeviceInterface **dev, void const *data, uint report_value, uint report_index, uint report_size);
IOReturn razer_get_usb_response(IOUSBDeviceInterface **dev, uint report_index, struct razer_report* request_report, uint response_index, struct razer_report* response_report, int wait_us);
unsigned char razer_calculate_crc(struct razer_report *report);
struct razer_report get_razer_report(unsigned char command_class, unsigned char command_id, unsigned char data_size);
struct razer_report get_empty_razer_report(void);


// Convenience functions
unsigned char clamp_u8(unsigned char value, unsigned char min, unsigned char max);
unsigned short clamp_u16(unsigned short value, unsigned short min, unsigned short max);

#endif