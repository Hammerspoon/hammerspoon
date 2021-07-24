//
//  razerdevice.h
//  Razer device query functions
//
//

#ifndef DRIVER_RAZERDEVICE_H_
#define DRIVER_RAZERDEVICE_H_

#include <IOKit/usb/IOUSBLib.h>
#include <IOKit/IOCFPlugIn.h>
#include <stdio.h>

#include "razerkbd_driver.h"
#include "razermouse_driver.h"
#include "razermousedock_driver.h"
#include "razermousemat_driver.h"
#include "razerheadphone_driver.h"
#include "razeregpu_driver.h"
#include "razerkraken_driver.h"
#include "razeraccessory_driver.h"

#define TYPE_KEYBOARD 0
#define TYPE_BLADE 1
#define TYPE_MOUSE 2
#define TYPE_MOUSE_DOCK 3
#define TYPE_MOUSE_MAT 4
#define TYPE_EGPU 5
#define TYPE_HEADPHONE 6
#define TYPE_ACCESSORY 7

#ifndef USB_VENDOR_ID_RAZER
#define USB_VENDOR_ID_RAZER 0x1532
#endif

typedef struct {
    IOUSBDeviceInterface **usbDevice;
    UInt16 productId;
    int internalDeviceId;
} RazerDevice;

typedef struct {
    RazerDevice *devices;
    int size;
} RazerDevices;

IOUSBDeviceInterface **getRazerUSBDeviceInterface(int type);
void closeRazerUSBDeviceInterface(IOUSBDeviceInterface **dev);

RazerDevices getAllRazerDevices();
void closeAllRazerDevices(RazerDevices devices);

#endif