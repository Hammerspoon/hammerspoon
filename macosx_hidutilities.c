/*
 * Support for Mac OS X via the HID Utilities example code. HID Utilities
 *  talks to very low-level parts of the HID Manager API, which are deprecated
 *  in OS X 10.5. Please see macosx_hidmanager.c for the 10.5 implementation.
 *
 * Please see the file LICENSE.txt in the source's root directory.
 *
 *  This file written by Ryan C. Gordon.
 */

#include "manymouse.h"

/*
 * These APIs exist on x86_64 in 10.6, but don't actually work (they'll work
 *  for 32-bit x86 binaries in 10.6, though!). HID Utilities is for legacy
 *  Macs, going forward you want macosx_hidmanager.c instead.
 */
#if ( (defined(__APPLE__)) && (defined(i386) || defined(__POWERPC__)) )

/*
 * This source is almost entirely lifted from Apple's HID Utilities
 *  example source code, written by George Warner:
 *
 * http://developer.apple.com/library/mac/#samplecode/HID_Utilities_Source/Introduction/Intro.html
 *
 * The source license to HID Utilities allows this sort of blatant stealing.
 *
 * Patches to HID Utilities have comments like "ryan added this", otherwise,
 *  I just tried to cut down that package to the smallest set of functions
 *  I needed.
 *
 * Scroll down for "-- END HID UTILITIES --" to see the ManyMouse glue code.
 */

#include <Carbon/Carbon.h>

#include <IOKit/IOTypes.h>
// 10.0.x
//#include <IOKit/IOUSBHIDParser.h>
// 10.1.x
#include <IOKit/hid/IOHIDUsageTables.h>
#include <IOKit/hid/IOHIDLib.h>
#include <IOKit/IOCFPlugIn.h>
#include <IOKit/IOKitLib.h>
#include <IOKit/IOMessage.h>

#define USE_NOTIFICATIONS 1

#define HIDREPORTERRORNUM(s,n)	do {} while (false)
#define HIDREPORTERROR(s)		do {} while (false)

typedef enum HIDElementTypeMask
{
	kHIDElementTypeInput				= 1 << 1,
	kHIDElementTypeOutput            	= 1 << 2,
	kHIDElementTypeFeature           	= 1 << 3,
	kHIDElementTypeCollection        	= 1 << 4,
	kHIDElementTypeIO					= kHIDElementTypeInput | kHIDElementTypeOutput | kHIDElementTypeFeature,
	kHIDElementTypeAll					= kHIDElementTypeIO | kHIDElementTypeCollection
}HIDElementTypeMask;

enum
{
    kDefaultUserMin = 0,					// default user min and max used for scaling
    kDefaultUserMax = 255
};

enum
{
    kDeviceQueueSize = 50	// this is wired kernel memory so should be set to as small as possible
							// but should account for the maximum possible events in the queue
							// USB updates will likely occur at 100 Hz so one must account for this rate of
							// if states change quickly (updates are only posted on state changes)
};

struct recElement
{
    unsigned long type;						// the type defined by IOHIDElementType in IOHIDKeys.h
    long usagePage;							// usage page from IOUSBHIDParser.h which defines general usage
    long usage;								// usage within above page from IOUSBHIDParser.h which defines specific usage
    void * cookie;				 			// unique value (within device of specific vendorID and productID) which identifies element, will NOT change
    long min;								// reported min value possible
    long max;								// reported max value possible
    long scaledMin;							// reported scaled min value possible
    long scaledMax;							// reported scaled max value possible
    long size;								// size in bits of data return from element
    unsigned char relative;					// are reports relative to last report (deltas)
    unsigned char wrapping;					// does element wrap around (one value higher than max is min)
    unsigned char nonLinear;				// are the values reported non-linear relative to element movement
    unsigned char preferredState;			// does element have a preferred state (such as a button)
    unsigned char nullState;				// does element have null state
    long units;								// units value is reported in (not used very often)
    long unitExp;							// exponent for units (also not used very often)
    char name[256];							// name of element (c string)

// runtime variables
    long calMin; 							// min returned value
    long calMax; 							// max returned value (calibrate call)
    long userMin; 							// user set value to scale to (scale call)
    long userMax;							
    
	struct recElement * pPrevious;			// previous element (NULL at list head)
    struct recElement * pChild;				// next child (only of collections)
    struct recElement * pSibling;			// next sibling (for elements and collections)

	long depth;
};
typedef struct recElement recElement;
typedef recElement* pRecElement;

// ryan added this.
typedef enum
{
    DISCONNECT_CONNECTED,
    DISCONNECT_TELLUSER,
    DISCONNECT_COMPLETE
} DisconnectState;

struct recDevice
{
    void * interface;						// interface to device, NULL = no interface
    void * queue;							// device queue, NULL = no queue
	void * queueRunLoopSource;				// device queue run loop source, NULL == no source
	void * transaction;						// output transaction interface, NULL == no interface
	void * notification;					// notifications
    char transport[256];					// device transport (c string)
    long vendorID;							// id for device vendor, unique across all devices
    long productID;							// id for particular product, unique across all of a vendors devices
    long version;							// version of product
    char manufacturer[256];					// name of manufacturer
    char product[256];						// name of product
    char serial[256];						// serial number of specific product, can be assumed unique across specific product or specific vendor (not used often)
    long locID;								// long representing location in USB (or other I/O) chain which device is pluged into, can identify specific device on machine
    long usage;								// usage page from IOUSBHID Parser.h which defines general usage
    long usagePage;							// usage within above page from IOUSBHID Parser.h which defines specific usage
    long totalElements;						// number of total elements (should be total of all elements on device including collections) (calculated, not reported by device)
	long features;							// number of elements of type kIOHIDElementTypeFeature
	long inputs;							// number of elements of type kIOHIDElementTypeInput_Misc or kIOHIDElementTypeInput_Button or kIOHIDElementTypeInput_Axis or kIOHIDElementTypeInput_ScanCodes
	long outputs;							// number of elements of type kIOHIDElementTypeOutput
	long collections;						// number of elements of type kIOHIDElementTypeCollection
    long axis;								// number of axis (calculated, not reported by device)
    long buttons;							// number of buttons (calculated, not reported by device)
    long hats;								// number of hat switches (calculated, not reported by device)
    long sliders;							// number of sliders (calculated, not reported by device)
    long dials;								// number of dials (calculated, not reported by device)
    long wheels;							// number of wheels (calculated, not reported by device)
    recElement* pListElements; 				// head of linked list of elements 
    DisconnectState disconnect; // (ryan added this.)
    AbsoluteTime lastScrollTime;  // (ryan added this.)
    int logical;  // (ryan added this.)
    struct recDevice* pNext; 				// next device
};
typedef struct recDevice recDevice;
typedef recDevice* pRecDevice;


#if USE_NOTIFICATIONS
static IONotificationPortRef	gNotifyPort;
static io_iterator_t		gAddedIter;
static CFRunLoopRef		gRunLoop;
#endif USE_NOTIFICATIONS

// for element retrieval
static pRecDevice gCurrentGetDevice = NULL;
static Boolean gAddAsChild = false;
static int gDepth = false;

static pRecDevice gpDeviceList = NULL;
static UInt32 gNumDevices = 0;

static Boolean HIDIsValidDevice(const pRecDevice pSearchDevice);
static pRecElement HIDGetFirstDeviceElement (pRecDevice pDevice, HIDElementTypeMask typeMask);
static pRecElement HIDGetNextDeviceElement (pRecElement pElement, HIDElementTypeMask typeMask);
static pRecDevice HIDGetFirstDevice (void);
static pRecDevice HIDGetNextDevice (pRecDevice pDevice);
static void HIDReleaseDeviceList (void);
static unsigned long  HIDDequeueDevice (pRecDevice pDevice);
static void hid_GetElements (CFTypeRef refElementCurrent, pRecElement *ppCurrentElement);


static void HIDReportError(const char *err) {}
static void HIDReportErrorNum(const char *err, int num) {}


static void hid_GetCollectionElements (CFMutableDictionaryRef deviceProperties, pRecElement *ppCurrentCollection)
{
    CFTypeRef refElementTop = CFDictionaryGetValue (deviceProperties, CFSTR(kIOHIDElementKey));
    if (refElementTop)
        hid_GetElements (refElementTop, ppCurrentCollection);
    else
        HIDReportError ("hid_GetCollectionElements: CFDictionaryGetValue error when creating CFTypeRef for kIOHIDElementKey.");
}


// extracts actual specific element information from each element CF dictionary entry
static void hid_GetElementInfo (CFTypeRef refElement, pRecElement pElement)
{
	long number;
	CFTypeRef refType;
	// type, usagePage, usage already stored
	refType = CFDictionaryGetValue (refElement, CFSTR(kIOHIDElementCookieKey));
	if (refType && CFNumberGetValue (refType, kCFNumberLongType, &number))
		pElement->cookie = (IOHIDElementCookie) number;
	else
		pElement->cookie = (IOHIDElementCookie) 0;

	refType = CFDictionaryGetValue (refElement, CFSTR(kIOHIDElementMinKey));
	if (refType && CFNumberGetValue (refType, kCFNumberLongType, &number))
		pElement->min = number;
	else
		pElement->min = 0;

	pElement->calMax = pElement->min;
	pElement->userMin = kDefaultUserMin;

	refType = CFDictionaryGetValue (refElement, CFSTR(kIOHIDElementMaxKey));
	if (refType && CFNumberGetValue (refType, kCFNumberLongType, &number))
		pElement->max = number;
	else
		pElement->max = 0;

	pElement->calMin = pElement->max;
	pElement->userMax = kDefaultUserMax;

	refType = CFDictionaryGetValue (refElement, CFSTR(kIOHIDElementScaledMinKey));
	if (refType && CFNumberGetValue (refType, kCFNumberLongType, &number))
		pElement->scaledMin = number;
	else
		pElement->scaledMin = 0;

	refType = CFDictionaryGetValue (refElement, CFSTR(kIOHIDElementScaledMaxKey));
	if (refType && CFNumberGetValue (refType, kCFNumberLongType, &number))
		pElement->scaledMax = number;
	else
		pElement->scaledMax = 0;

	refType = CFDictionaryGetValue (refElement, CFSTR(kIOHIDElementSizeKey));
	if (refType && CFNumberGetValue (refType, kCFNumberLongType, &number))
		pElement->size = number;
	else
		pElement->size = 0;

	refType = CFDictionaryGetValue (refElement, CFSTR(kIOHIDElementIsRelativeKey));
	if (refType)
		pElement->relative = CFBooleanGetValue (refType);
	else
		pElement->relative = 0;

	refType = CFDictionaryGetValue (refElement, CFSTR(kIOHIDElementIsWrappingKey));
	if (refType)
		pElement->wrapping = CFBooleanGetValue (refType);
	else
		pElement->wrapping = false;

	refType = CFDictionaryGetValue (refElement, CFSTR(kIOHIDElementIsNonLinearKey));
	if (refType)
		pElement->nonLinear = CFBooleanGetValue (refType);
	else
		pElement->wrapping = false;

#ifdef kIOHIDElementHasPreferredStateKey
	refType = CFDictionaryGetValue (refElement, CFSTR(kIOHIDElementHasPreferredStateKey));
#else // Mac OS X 10.0 has spelling error
	refType = CFDictionaryGetValue (refElement, CFSTR(kIOHIDElementHasPreferedStateKey));
#endif
	if (refType)
		pElement->preferredState = CFBooleanGetValue (refType);
	else
		pElement->preferredState = false;

	refType = CFDictionaryGetValue (refElement, CFSTR(kIOHIDElementHasNullStateKey));
	if (refType)
		pElement->nullState = CFBooleanGetValue (refType);
	else
		pElement->nullState = false;

	refType = CFDictionaryGetValue (refElement, CFSTR(kIOHIDElementUnitKey));
	if (refType && CFNumberGetValue (refType, kCFNumberLongType, &number))
		pElement->units = number;
	else
		pElement->units = 0;

	refType = CFDictionaryGetValue (refElement, CFSTR(kIOHIDElementUnitExponentKey));
	if (refType && CFNumberGetValue (refType, kCFNumberLongType, &number))
		pElement->unitExp = number;
	else
		pElement->unitExp = 0;

	refType = CFDictionaryGetValue (refElement, CFSTR(kIOHIDElementNameKey));
	if (refType)
		if (!CFStringGetCString (refType, pElement->name, 256, CFStringGetSystemEncoding ()))
			HIDReportError ("CFStringGetCString error retrieving pElement->name.");

    #if 0
	if (!*pElement->name)
	{
		// set name from vendor id, product id & usage info look up
		if (!HIDGetElementNameFromVendorProductUsage (gCurrentGetDevice->vendorID, gCurrentGetDevice->productID, pElement->usagePage, pElement->usage, pElement->name))
		{
			// set name from vendor id/product id look up
			HIDGetElementNameFromVendorProductCookie (gCurrentGetDevice->vendorID, gCurrentGetDevice->productID, (long) pElement->cookie, pElement->name);
			if (!*pElement->name) { // if no name
				HIDGetUsageName (pElement->usagePage, pElement->usage, pElement->name);
				if (!*pElement->name) // if not usage
					sprintf (pElement->name, "Element");
			}
		}
	}
    #endif
}


static void hid_AddElement (CFTypeRef refElement, pRecElement * ppElementCurrent)
{
	pRecDevice pDevice = gCurrentGetDevice;
    pRecElement pElement = NULL;
    long elementType, usagePage, usage;
    CFTypeRef refElementType = CFDictionaryGetValue (refElement, CFSTR(kIOHIDElementTypeKey));
    CFTypeRef refUsagePage = CFDictionaryGetValue (refElement, CFSTR(kIOHIDElementUsagePageKey));
    CFTypeRef refUsage = CFDictionaryGetValue (refElement, CFSTR(kIOHIDElementUsageKey));

    if (refElementType)
		CFNumberGetValue (refElementType, kCFNumberLongType, &elementType);
	if (refUsagePage)
		CFNumberGetValue (refUsagePage, kCFNumberLongType, &usagePage);
	if (refUsage)
		CFNumberGetValue (refUsage, kCFNumberLongType, &usage);

	if (NULL == pDevice)
		return;

    if (elementType)
    {
        // look at types of interest
        if (elementType != kIOHIDElementTypeCollection)
		{
            if (usagePage && usage) // if valid usage and page
			{
				switch (usagePage) // only interested in kHIDPage_GenericDesktop and  kHIDPage_Button
				{
					case kHIDPage_GenericDesktop:
					{
						switch (usage) // look at usage to determine function
						{
							case kHIDUsage_GD_X:
							case kHIDUsage_GD_Y:
							case kHIDUsage_GD_Z:
							case kHIDUsage_GD_Rx:
							case kHIDUsage_GD_Ry:
							case kHIDUsage_GD_Rz:
								pElement = (pRecElement) malloc (sizeof (recElement));
								if (pElement) pDevice->axis++;
									break;
							case kHIDUsage_GD_Slider:
								pElement = (pRecElement) malloc (sizeof (recElement));
								if (pElement) pDevice->sliders++;
									break;
							case kHIDUsage_GD_Dial:
								pElement = (pRecElement) malloc (sizeof (recElement));
								if (pElement) pDevice->dials++;
									break;
							case kHIDUsage_GD_Wheel:
								pElement = (pRecElement) malloc (sizeof (recElement));
								if (pElement) pDevice->wheels++;
									break;
							case kHIDUsage_GD_Hatswitch:
								pElement = (pRecElement) malloc (sizeof (recElement));
								if (pElement) pDevice->hats++;
									break;
							default:
								pElement = (pRecElement) malloc (sizeof (recElement));
								break;
						}
					}
						break;
					case kHIDPage_Button:
						pElement = (pRecElement) malloc (sizeof (recElement));
						if (pElement) pDevice->buttons++;
							break;
					default:
						// just add a generic element
						pElement = (pRecElement) malloc (sizeof (recElement));
						break;
				}
			}
#if 0
            else
                HIDReportError ("CFNumberGetValue error when getting value for refUsage or refUsagePage.");
#endif 0
        }
        else // collection
			pElement = (pRecElement) malloc (sizeof (recElement));
    }
    else
        HIDReportError ("CFNumberGetValue error when getting value for refElementType.");

    if (pElement) // add to list
    {
		// this code builds a binary tree based on the collection hierarchy of inherent in the device element layout
		// it preserves the structure of the lements as collections have children and elements are siblings to each other

		// clear record
		bzero(pElement,sizeof(recElement));

		// get element info
        pElement->type = elementType;
        pElement->usagePage = usagePage;
        pElement->usage = usage;
        pElement->depth = 0;		// assume root object
        hid_GetElementInfo (refElement, pElement);

		// count elements
		pDevice->totalElements++;

		switch (pElement->type)
		{
			case kIOHIDElementTypeInput_Misc:
			case kIOHIDElementTypeInput_Button:
			case kIOHIDElementTypeInput_Axis:
			case kIOHIDElementTypeInput_ScanCodes:
				pDevice->inputs++;
				break;
			case kIOHIDElementTypeOutput:
				pDevice->outputs++;
				break;
			case kIOHIDElementTypeFeature:
				pDevice->features++;
				break;
			case kIOHIDElementTypeCollection:
				pDevice->collections++;
				break;
			default:
				HIDReportErrorNum ("Unknown element type : ", pElement->type);
		}

        if (NULL == *ppElementCurrent) // if at list head
		{
            pDevice->pListElements = pElement; // add current element
			*ppElementCurrent = pElement; // set current element to element we just added
		}
		else // have exsiting structure
		{
			if (gAddAsChild) // if the previous element was a collection, let's add this as a child of the previous
			{
				// this iteration should not be needed but there maybe some untested degenerate case which this code will ensure works
				while ((*ppElementCurrent)->pChild) // step down tree until free child node found
					*ppElementCurrent = (*ppElementCurrent)->pChild;
				(*ppElementCurrent)->pChild = pElement; // insert there
				pElement->depth = (*ppElementCurrent)->depth + 1;
			}
			else // add as sibling
			{
				// this iteration should not be needed but there maybe some untested degenerate case which this code will ensure works
				while ((*ppElementCurrent)->pSibling) // step down tree until free sibling node found
					*ppElementCurrent = (*ppElementCurrent)->pSibling;
				(*ppElementCurrent)->pSibling = pElement; // insert there
				pElement->depth = (*ppElementCurrent)->depth;
			}
			pElement->pPrevious = *ppElementCurrent; // point to previous
			*ppElementCurrent = pElement; // set current to our collection
		}

		if (elementType == kIOHIDElementTypeCollection) // if this element is a collection of other elements
		{
			gAddAsChild = true; // add next set as children to this element
			gDepth++;
			hid_GetCollectionElements ((CFMutableDictionaryRef) refElement, &pElement); // recursively process the collection
			gDepth--;
		}
		gAddAsChild = false; // add next as this elements sibling (when return from a collection or with non-collections)
    }
#if 0
    else
        HIDReportError ("hid_AddElement - no element added.");
#endif
}


static void hid_GetElementsCFArrayHandler (const void * value, void * parameter)
{
    if (CFGetTypeID (value) == CFDictionaryGetTypeID ())
        hid_AddElement ((CFTypeRef) value, (pRecElement *) parameter);
}

// ---------------------------------
// handles retrieval of element information from arrays of elements in device IO registry information

static void hid_GetElements (CFTypeRef refElementCurrent, pRecElement *ppCurrentElement)
{
    CFTypeID type = CFGetTypeID (refElementCurrent);
    if (type == CFArrayGetTypeID()) // if element is an array
    {
        CFRange range = {0, CFArrayGetCount (refElementCurrent)};
        // CountElementsCFArrayHandler called for each array member
        CFArrayApplyFunction (refElementCurrent, range, hid_GetElementsCFArrayHandler, ppCurrentElement);
    }
}

static void hid_TopLevelElementHandler (const void * value, void * parameter)
{
    CFTypeRef refCF = 0;
    if ((NULL == value) || (NULL == parameter))
        return;	// (kIOReturnBadArgument)
    if (CFGetTypeID (value) != CFDictionaryGetTypeID ())
        return;	// (kIOReturnBadArgument)
    refCF = CFDictionaryGetValue (value, CFSTR(kIOHIDElementUsagePageKey));
    if (!CFNumberGetValue (refCF, kCFNumberLongType, &((pRecDevice) parameter)->usagePage))
        HIDReportError ("CFNumberGetValue error retrieving pDevice->usagePage.");
    refCF = CFDictionaryGetValue (value, CFSTR(kIOHIDElementUsageKey));
    if (!CFNumberGetValue (refCF, kCFNumberLongType, &((pRecDevice) parameter)->usage))
        HIDReportError ("CFNumberGetValue error retrieving pDevice->usage.");
}


static void hid_GetDeviceInfo (io_object_t hidDevice, CFMutableDictionaryRef hidProperties, pRecDevice pDevice)
{
	CFMutableDictionaryRef usbProperties = 0;
	io_registry_entry_t parent1, parent2;

    // Mac OS X currently is not mirroring all USB properties to HID page so need to look at USB device page also
    // get dictionary for usb properties: step up two levels and get CF dictionary for USB properties
    if ((KERN_SUCCESS == IORegistryEntryGetParentEntry (hidDevice, kIOServicePlane, &parent1)) &&
        (KERN_SUCCESS == IORegistryEntryGetParentEntry (parent1, kIOServicePlane, &parent2)) &&
        (KERN_SUCCESS == IORegistryEntryCreateCFProperties (parent2, &usbProperties, kCFAllocatorDefault, kNilOptions)))
    {
        if (usbProperties)
        {
            CFTypeRef refCF = 0;
            // get device info
            // try hid dictionary first, if fail then go to usb dictionary

            // get transport
            refCF = CFDictionaryGetValue (hidProperties, CFSTR(kIOHIDTransportKey));
            if (refCF)
            {
				if (!CFStringGetCString (refCF, pDevice->transport, 256, CFStringGetSystemEncoding ()))
                    HIDReportError ("CFStringGetCString error retrieving pDevice->transport.");
            }

            // get vendorID
            refCF = CFDictionaryGetValue (hidProperties, CFSTR(kIOHIDVendorIDKey));
            if (!refCF)
                refCF = CFDictionaryGetValue (usbProperties, CFSTR("idVendor"));
            if (refCF)
            {
                if (!CFNumberGetValue (refCF, kCFNumberLongType, &pDevice->vendorID))
                    HIDReportError ("CFNumberGetValue error retrieving pDevice->vendorID.");
            }

            // get product ID
            refCF = CFDictionaryGetValue (hidProperties, CFSTR(kIOHIDProductIDKey));
            if (!refCF)
                refCF = CFDictionaryGetValue (usbProperties, CFSTR("idProduct"));
            if (refCF)
            {
                if (!CFNumberGetValue (refCF, kCFNumberLongType, &pDevice->productID))
                    HIDReportError ("CFNumberGetValue error retrieving pDevice->productID.");
            }

            // get product version
            refCF = CFDictionaryGetValue (hidProperties, CFSTR(kIOHIDVersionNumberKey));
            if (refCF)
            {
                if (!CFNumberGetValue (refCF, kCFNumberLongType, &pDevice->version))
                    HIDReportError ("CFNumberGetValue error retrieving pDevice->version.");
            }

            // get manufacturer name
            refCF = CFDictionaryGetValue (hidProperties, CFSTR(kIOHIDManufacturerKey));
            if (!refCF)
                refCF = CFDictionaryGetValue (usbProperties, CFSTR("USB Vendor Name"));
            if (refCF)
            {
                if (!CFStringGetCString (refCF, pDevice->manufacturer, 256, CFStringGetSystemEncoding ()))
                    HIDReportError ("CFStringGetCString error retrieving pDevice->manufacturer.");
            }

            // get product name
            refCF = CFDictionaryGetValue (hidProperties, CFSTR(kIOHIDProductKey));
            if (!refCF)
                refCF = CFDictionaryGetValue (usbProperties, CFSTR("USB Product Name"));
            if (refCF)
            {
                // ryan forced this to UTF-8.
                //if (!CFStringGetCString (refCF, pDevice->product, 256, CFStringGetSystemEncoding ()))
                if (!CFStringGetCString (refCF, pDevice->product, 256, kCFStringEncodingUTF8))
                    HIDReportError ("CFStringGetCString error retrieving pDevice->product.");
            }

            // get serial
            refCF = CFDictionaryGetValue (hidProperties, CFSTR(kIOHIDSerialNumberKey));
            if (refCF)
            {
                if (!CFStringGetCString (refCF, pDevice->serial, 256, CFStringGetSystemEncoding ()))
                    HIDReportError ("CFStringGetCString error retrieving pDevice->serial.");
            }

            // get location ID
            refCF = CFDictionaryGetValue (hidProperties, CFSTR(kIOHIDLocationIDKey));
            if (!refCF)
                refCF = CFDictionaryGetValue (usbProperties, CFSTR("locationID"));
            if (refCF)
            {
                if (!CFNumberGetValue (refCF, kCFNumberLongType, &pDevice->locID))
                    HIDReportError ("CFNumberGetValue error retrieving pDevice->locID.");
            }

            // get usage page and usage
            refCF = CFDictionaryGetValue (hidProperties, CFSTR(kIOHIDPrimaryUsagePageKey));
            if (refCF)
            {
                if (!CFNumberGetValue (refCF, kCFNumberLongType, &pDevice->usagePage))
                    HIDReportError ("CFNumberGetValue error retrieving pDevice->usagePage.");
                refCF = CFDictionaryGetValue (hidProperties, CFSTR(kIOHIDPrimaryUsageKey));
                if (refCF)
                    if (!CFNumberGetValue (refCF, kCFNumberLongType, &pDevice->usage))
                        HIDReportError ("CFNumberGetValue error retrieving pDevice->usage.");
            }
            if (NULL == refCF) // get top level element HID usage page or usage
            {
                // use top level element instead
                CFTypeRef refCFTopElement = 0;
                refCFTopElement = CFDictionaryGetValue (hidProperties, CFSTR(kIOHIDElementKey));
                {
                    // refCFTopElement points to an array of element dictionaries
                    CFRange range = {0, CFArrayGetCount (refCFTopElement)};
                    CFArrayApplyFunction (refCFTopElement, range, hid_TopLevelElementHandler, NULL);
                }
            }
        }
        else
            HIDReportError ("IORegistryEntryCreateCFProperties failed to create usbProperties.");

        CFRelease (usbProperties);
        if (kIOReturnSuccess != IOObjectRelease (parent2))
            HIDReportError ("IOObjectRelease error with parent2.");
        if (kIOReturnSuccess != IOObjectRelease (parent1))
            HIDReportError ("IOObjectRelease error with parent1.");
    }
}


static Boolean hid_MatchElementTypeMask (IOHIDElementType type, HIDElementTypeMask typeMask)
{
	if (typeMask & kHIDElementTypeInput)
		if ((type == kIOHIDElementTypeInput_Misc) || (type == kIOHIDElementTypeInput_Button) || (type == kIOHIDElementTypeInput_Axis) || (type == kIOHIDElementTypeInput_ScanCodes))
			return true;
	if (typeMask & kHIDElementTypeOutput)
		if (type == kIOHIDElementTypeOutput)
			return true;
	if (typeMask & kHIDElementTypeFeature)
		if (type == kIOHIDElementTypeFeature)
			return true;
	if (typeMask & kHIDElementTypeCollection)
		if (type == kIOHIDElementTypeCollection)
			return true;
	return false;
}

static pRecElement hid_GetDeviceElement (pRecElement pElement, HIDElementTypeMask typeMask)
{
	// we are asking for this element
    if (NULL != pElement)
	{
		if (hid_MatchElementTypeMask (pElement->type, typeMask)) // if the type match what we are looking for
			return pElement; // return the element
		else
			return HIDGetNextDeviceElement (pElement, typeMask); // else get the next one
	}
	return NULL;
}

static unsigned long HIDCloseReleaseInterface (pRecDevice pDevice)
{
	IOReturn result = kIOReturnSuccess;
	
	if (HIDIsValidDevice(pDevice) && (NULL != pDevice->interface))
	{
		// close the interface
		result = (*(IOHIDDeviceInterface**) pDevice->interface)->close (pDevice->interface);
		if (kIOReturnNotOpen == result)
		{
			//  do nothing as device was not opened, thus can't be closed
		}
		else if (kIOReturnSuccess != result)
			HIDREPORTERRORNUM ("HIDCloseReleaseInterface - Failed to close IOHIDDeviceInterface.", result);
		//release the interface
		result = (*(IOHIDDeviceInterface**) pDevice->interface)->Release (pDevice->interface);
		if (kIOReturnSuccess != result)
			HIDREPORTERRORNUM ("HIDCloseReleaseInterface - Failed to release interface.", result);
		pDevice->interface = NULL;
	}	
	return result;
}      


// ---------------------------------
// count number of devices in global device list (gpDeviceList)
static UInt32 hid_CountCurrentDevices (void)
{
    pRecDevice pDevice = gpDeviceList;
    UInt32 devices = 0;
    while (pDevice)
    {
        devices++;
        pDevice = pDevice->pNext;
    }
    return devices;
}

static UInt32 HIDCountDevices (void)
{
	gNumDevices = hid_CountCurrentDevices ();

    return gNumDevices;
}

static void hid_DisposeDeviceElements (pRecElement pElement)
{
	if (pElement)
	{
		if (pElement->pChild)
			hid_DisposeDeviceElements (pElement->pChild);
		if (pElement->pSibling)
			hid_DisposeDeviceElements (pElement->pSibling);
		free (pElement);
	}
}

static pRecDevice hid_DisposeDevice (pRecDevice pDevice)
{
    kern_return_t result = KERN_SUCCESS;
    pRecDevice pDeviceNext = NULL;

    if (HIDIsValidDevice(pDevice))
    {
        // save next device prior to disposing of this device
        pDeviceNext = pDevice->pNext;

		result = HIDDequeueDevice (pDevice);
#if 0
		if (kIOReturnSuccess != result)
			HIDReportErrorNum ("hid_DisposeDevice: HIDDequeueDevice error: 0x%8.8X.", result);
#endif 1

        hid_DisposeDeviceElements (pDevice->pListElements);
		pDevice->pListElements = NULL;

		result = HIDCloseReleaseInterface (pDevice); // function sanity checks interface value (now application does not own device)
		if (kIOReturnSuccess != result)
			HIDReportErrorNum ("hid_DisposeDevice: HIDCloseReleaseInterface error: 0x%8.8X.", result);

#if USE_NOTIFICATIONS
        if (pDevice->interface)
        {
			// replace (*pDevice->interface)->Release(pDevice->interface);
			result = IODestroyPlugInInterface (pDevice->interface);
			if (kIOReturnSuccess != result)
				HIDReportErrorNum ("hid_DisposeDevice: IODestroyPlugInInterface error: 0x%8.8X.", result);
        }

        if (pDevice->notification)
		{
			result = IOObjectRelease((io_object_t) pDevice->notification);
			if (kIOReturnSuccess != result)
				HIDReportErrorNum ("hid_DisposeDevice: IOObjectRelease error: 0x%8.8X.", result);
		}
#endif USE_NOTIFICATIONS

		// remove this device from the device list
		if (gpDeviceList == pDevice)	// head of list?
			gpDeviceList = pDeviceNext;
		else
		{
			pRecDevice pDeviceTemp = pDeviceNext = gpDeviceList;	// we're going to return this if we don't find ourselfs in the list
			while (pDeviceTemp)
			{
				if (pDeviceTemp->pNext == pDevice) // found us!
				{
					// take us out of linked list
					pDeviceTemp->pNext = pDeviceNext = pDevice->pNext;
					break;
				}
				pDeviceTemp = pDeviceTemp->pNext;
			}
		}
        free (pDevice);
    }

	// update device count
	gNumDevices = hid_CountCurrentDevices ();

    return pDeviceNext;
}


// ---------------------------------
// disposes and releases queue, sets queue to NULL,.
// Note: will have no effect if device or queue do not exist

static IOReturn hid_DisposeReleaseQueue (pRecDevice pDevice)
{
    IOReturn result = kIOReturnError;	// assume failure (pessimist!)

	if (HIDIsValidDevice(pDevice))	// need valid device
	{
		if (pDevice->queue) // and queue
		{
			// stop queue
			result = (*(IOHIDQueueInterface**) pDevice->queue)->stop (pDevice->queue);
			if (kIOReturnSuccess != result)
				HIDREPORTERRORNUM ("hid_DisposeReleaseQueue - Failed to stop queue.", result);
			// dispose of queue
			result = (*(IOHIDQueueInterface**) pDevice->queue)->dispose (pDevice->queue);
			if (kIOReturnSuccess != result)
				HIDREPORTERRORNUM ("hid_DisposeReleaseQueue - Failed to dipose queue.", result);
			// release the queue
			result = (*(IOHIDQueueInterface**) pDevice->queue)->Release (pDevice->queue);
			if (kIOReturnSuccess != result)
				HIDREPORTERRORNUM ("hid_DisposeReleaseQueue - Failed to release queue.", result);

			pDevice->queue = NULL;
		}
		else
			HIDREPORTERROR ("hid_DisposeReleaseQueue - no queue.");
	}
	else
		HIDREPORTERROR ("hid_DisposeReleaseQueue - Invalid device.");
    return result;
}


// ---------------------------------
// completely removes all elements from queue and releases queue and closes device interface
// does not release device interfaces, application must call HIDReleaseDeviceList on exit

static unsigned long  HIDDequeueDevice (pRecDevice pDevice)
{
    IOReturn result = kIOReturnSuccess;

    if (HIDIsValidDevice(pDevice))
	{
		if ((pDevice->interface) && (pDevice->queue))
		{
			// iterate through elements and if queued, remove
			pRecElement pElement = HIDGetFirstDeviceElement (pDevice, kHIDElementTypeIO);
			while (pElement)
			{
				if ((*(IOHIDQueueInterface**) pDevice->queue)->hasElement (pDevice->queue, pElement->cookie))
				{
					result = (*(IOHIDQueueInterface**) pDevice->queue)->removeElement (pDevice->queue, pElement->cookie);
					if (kIOReturnSuccess != result)
						HIDREPORTERRORNUM ("HIDDequeueDevice - Failed to remove element from queue.", result);
				}
				pElement = HIDGetNextDeviceElement (pElement, kHIDElementTypeIO);
			}
		}
		// ensure queue is disposed and released
		// interface will be closed and released on call to HIDReleaseDeviceList
		result = hid_DisposeReleaseQueue (pDevice);
		if (kIOReturnSuccess != result)
			HIDREPORTERRORNUM ("removeElement - Failed to dispose and release queue.", result);
#if USE_ASYNC_EVENTS
		else if (NULL != pDevice->queueRunLoopSource)
		{
			if (CFRunLoopContainsSource(CFRunLoopGetCurrent(), pDevice->queueRunLoopSource, kCFRunLoopDefaultMode))
				CFRunLoopRemoveSource(CFRunLoopGetCurrent(), pDevice->queueRunLoopSource, kCFRunLoopDefaultMode);
			CFRelease(pDevice->queueRunLoopSource);
			pDevice->queueRunLoopSource = NULL;
		}
#endif USE_ASYNC_EVENTS
	}
	else
	{
		HIDREPORTERROR ("HIDDequeueDevice - Invalid device.");
		result = kIOReturnBadArgument;
	}
    return result;
}

// ---------------------------------
// releases all device queues for quit or rebuild (must be called)
// does not release device interfaces, application must call HIDReleaseDeviceList on exit

static unsigned long HIDReleaseAllDeviceQueues (void)
{
    IOReturn result = kIOReturnBadArgument;
    pRecDevice pDevice = HIDGetFirstDevice ();

    while (pDevice)
    {
        result = HIDDequeueDevice (pDevice);
        if (kIOReturnSuccess != result)
            HIDREPORTERRORNUM ("HIDReleaseAllDeviceQueues - Could not dequeue device.", result);
        pDevice = HIDGetNextDevice (pDevice);
    }
    return result;
}


// ---------------------------------
// Get the next event in the queue for a device
// elements or entire device should be queued prior to calling this with HIDQueueElement or HIDQueueDevice
// returns true if an event is avialable for the element and fills out *pHIDEvent structure, returns false otherwise
// Note: kIOReturnUnderrun returned from getNextEvent indicates an empty queue not an error condition
// Note: application should pass in a pointer to a IOHIDEventStruct cast to a void (for CFM compatibility)

static unsigned char HIDGetEvent (pRecDevice pDevice, void * pHIDEvent)
{
    IOReturn result = kIOReturnBadArgument;
    AbsoluteTime zeroTime = {0,0};

    if (HIDIsValidDevice(pDevice))
	{
		if (pDevice->queue)
		{
			result = (*(IOHIDQueueInterface**) pDevice->queue)->getNextEvent (pDevice->queue, (IOHIDEventStruct *)pHIDEvent, zeroTime, 0);
			if (kIOReturnUnderrun == result)
				return false;  // no events in queue not an error per say
			else if (kIOReturnSuccess != result) // actual error versus just an empty queue
				HIDREPORTERRORNUM ("HIDGetEvent - Could not get HID event via getNextEvent.", result);
			else
				return true;
		}
		else
			HIDREPORTERROR ("HIDGetEvent - queue does not exist.");
	}
	else
		HIDREPORTERROR ("HIDGetEvent - invalid device.");

    return false; // did not get event
}


static unsigned long HIDCreateOpenDeviceInterface (UInt32 hidDevice, pRecDevice pDevice)
{
    IOReturn result = kIOReturnSuccess;
    HRESULT plugInResult = S_OK;
    SInt32 score = 0;
    IOCFPlugInInterface ** ppPlugInInterface = NULL;

	if (NULL == pDevice->interface)
	{
		result = IOCreatePlugInInterfaceForService (hidDevice, kIOHIDDeviceUserClientTypeID,
											  kIOCFPlugInInterfaceID, &ppPlugInInterface, &score);
		if (kIOReturnSuccess == result)
		{
			// Call a method of the intermediate plug-in to create the device interface
			plugInResult = (*ppPlugInInterface)->QueryInterface (ppPlugInInterface,
														CFUUIDGetUUIDBytes (kIOHIDDeviceInterfaceID), (void *) &(pDevice->interface));
			if (S_OK != plugInResult)
				HIDReportErrorNum ("CouldnÕt query HID class device interface from plugInInterface", plugInResult);
			IODestroyPlugInInterface (ppPlugInInterface); // replace (*ppPlugInInterface)->Release (ppPlugInInterface)
		}
		else
			HIDReportErrorNum ("Failed to create **plugInInterface via IOCreatePlugInInterfaceForService.", result);
	}
	if (NULL != pDevice->interface)
	{
		result = (*(IOHIDDeviceInterface**)pDevice->interface)->open (pDevice->interface, 0);
		if (kIOReturnSuccess != result)
			HIDReportErrorNum ("Failed to open pDevice->interface via open.", result);
	}
    return result;
}


// ---------------------------------
// adds device to linked list of devices passed in (handles NULL lists properly)
// (returns where you just stored it)
static pRecDevice* hid_AddDevice (pRecDevice *ppListDeviceHead, pRecDevice pNewDevice)
{
	pRecDevice* result = NULL;
	
    if (NULL == *ppListDeviceHead)
        result = ppListDeviceHead;
    else
    {
        pRecDevice pDevicePrevious = NULL, pDevice = *ppListDeviceHead;
        while (pDevice)
        {
            pDevicePrevious = pDevice;
            pDevice = pDevicePrevious->pNext;
        }
        result = &pDevicePrevious->pNext;
    }
    pNewDevice->pNext = NULL;

	*result = pNewDevice;

	return result;
}

static pRecDevice hid_BuildDevice (io_object_t hidDevice)
{
    pRecDevice pDevice = (pRecDevice) malloc (sizeof (recDevice));

    if (NULL != pDevice)
    {
		// get dictionary for HID properties
        CFMutableDictionaryRef hidProperties = 0;
        kern_return_t result = IORegistryEntryCreateCFProperties (hidDevice, &hidProperties, kCFAllocatorDefault, kNilOptions);

		// clear record
		bzero(pDevice, sizeof(recDevice));

        if ((result == KERN_SUCCESS) && (NULL != hidProperties))
        {
			pRecElement pCurrentElement = NULL;
			// create device interface
			result = HIDCreateOpenDeviceInterface (hidDevice, pDevice);
			if (kIOReturnSuccess != result)
				HIDReportErrorNum ("HIDCreateOpenDeviceInterface failed.", result);
            hid_GetDeviceInfo (hidDevice, hidProperties, pDevice); // hidDevice used to find parents in registry tree
																   // set current device for use in getting elements
			gCurrentGetDevice = pDevice;
			// Add all elements
            hid_GetCollectionElements (hidProperties, &pCurrentElement);
			gCurrentGetDevice = NULL;
            CFRelease (hidProperties);
        }
        else
            HIDReportErrorNum ("IORegistryEntryCreateCFProperties error when creating deviceProperties.", result);
    }
    else
        HIDReportError ("malloc error when allocating pRecDevice.");
    return pDevice;
}



#if USE_NOTIFICATIONS
//================================================================================================
//
//	hid_DeviceNotification
//
//	This routine will get called whenever any kIOGeneralInterest notification happens.  We are
//	interested in the kIOMessageServiceIsTerminated message so that's what we look for.  Other
//	messages are defined in IOMessage.h.
//
//================================================================================================
//
static void hid_DeviceNotification( void *refCon,
									io_service_t service,
									natural_t messageType,
									void *messageArgument )
{
    pRecDevice pDevice = (pRecDevice) refCon;

    if (messageType == kIOMessageServiceIsTerminated)
    {
        //printf("Device 0x%08x \"%s\"removed.\n", service, pDevice->product);
        // ryan added this.
        if (pDevice->disconnect == DISCONNECT_CONNECTED)
    	    pDevice->disconnect = DISCONNECT_TELLUSER;

        // Free the data we're no longer using now that the device is going away
        // ryan commented this out.
		//hid_DisposeDevice (pDevice);
    }
}
#else

static void hid_RemovalCallbackFunction(void * target, IOReturn result, void * refcon, void * sender)
{
    // ryan commented this out.
	//hid_DisposeDevice ((pRecDevice) target);

    // ryan added this.
    pRecDevice = (pRecDevice) target;
    if (pDevice->disconnect == DISCONNECT_CONNECTED)
        pDevice->disconnect = DISCONNECT_TELLUSER;
}

#endif USE_NOTIFICATIONS



static void hid_AddDevices (void *refCon, io_iterator_t iterator)
{
	// NOTE: refcon passed in is used to point to the device list head
    pRecDevice* pListDeviceHead = (pRecDevice*) refCon;
    IOReturn result = kIOReturnSuccess;
    io_object_t ioHIDDeviceObject = 0;

    while ((ioHIDDeviceObject = IOIteratorNext (iterator)) != 0)
    {
		pRecDevice* pNewDeviceAt = NULL;
		pRecDevice pNewDevice = hid_BuildDevice (ioHIDDeviceObject);
		if (pNewDevice)
		{
#if 0	// set true for verbose output
			printf("\nhid_AddDevices: pNewDevice = {t: \"%s\", v: %ld, p: %ld, v: %ld, m: \"%s\", " \
		  "p: \"%s\", l: %ld, u: %4.4lX:%4.4lX, #e: %ld, #f: %ld, #i: %ld, #o: %ld, " \
		  "#c: %ld, #a: %ld, #b: %ld, #h: %ld, #s: %ld, #d: %ld, #w: %ld}.",
		  pNewDevice->transport,
		  pNewDevice->vendorID,
		  pNewDevice->productID,
		  pNewDevice->version,
		  pNewDevice->manufacturer,
		  pNewDevice->product,
		  pNewDevice->locID,
		  pNewDevice->usagePage,
		  pNewDevice->usage,
		  pNewDevice->totalElements,
		  pNewDevice->features,
		  pNewDevice->inputs,
		  pNewDevice->outputs,
		  pNewDevice->collections,
		  pNewDevice->axis,
		  pNewDevice->buttons,
		  pNewDevice->hats,
		  pNewDevice->sliders,
		  pNewDevice->dials,
		  pNewDevice->wheels
		  );
			fflush(stdout);
#elif	0	// otherwise output brief description
			printf("\nhid_AddDevices: pNewDevice = {m: \"%s\" p: \"%s\", vid: %ld, pid: %ld, loc: %8.8lX, usage: %4.4lX:%4.4lX}.",
		  pNewDevice->manufacturer,
		  pNewDevice->product,
		  pNewDevice->vendorID,
		  pNewDevice->productID,
		  pNewDevice->locID,
		  pNewDevice->usagePage,
		  pNewDevice->usage
		  );
			fflush(stdout);
#endif
			pNewDeviceAt = hid_AddDevice (pListDeviceHead, pNewDevice);
		}

#if USE_NOTIFICATIONS
        // Register for an interest notification of this device being removed. Use a reference to our
        // private data as the refCon which will be passed to the notification callback.
        result = IOServiceAddInterestNotification( gNotifyPort,					// notifyPort
												   ioHIDDeviceObject,			// service
												   kIOGeneralInterest,			// interestType
												   hid_DeviceNotification,		// callback
												   pNewDevice,					// refCon
												   (io_object_t*) &pNewDevice->notification);	// notification
		if (KERN_SUCCESS != result)
			HIDReportErrorNum ("hid_AddDevices: IOServiceAddInterestNotification error: x0%8.8lX.", result);
#else
		result = (*(IOHIDDeviceInterface**)pNewDevice->interface)->setRemovalCallback (pNewDevice->interface, hid_RemovalCallbackFunction,pNewDeviceAt,0);
#endif USE_NOTIFICATIONS

		// release the device object, it is no longer needed
		result = IOObjectRelease (ioHIDDeviceObject);
		if (KERN_SUCCESS != result)
			HIDReportErrorNum ("hid_AddDevices: IOObjectRelease error with ioHIDDeviceObject.", result);
    }
}


static Boolean HIDBuildDeviceList (UInt32 usagePage, UInt32 usage)
{
    IOReturn result = kIOReturnSuccess;
    mach_port_t masterPort = 0;

    if (NULL != gpDeviceList)
        HIDReleaseDeviceList ();

    result = IOMasterPort (bootstrap_port, &masterPort);
    if (kIOReturnSuccess != result)
        HIDReportErrorNum ("IOMasterPort error with bootstrap_port.", result);
    else
    {
		CFMutableDictionaryRef hidMatchDictionary = NULL;

		// Set up matching dictionary to search the I/O Registry for HID devices we are interested in. Dictionary reference is NULL if error.
		{
			CFNumberRef refUsage = NULL, refUsagePage = NULL;

			// Set up a matching dictionary to search I/O Registry by class name for all HID class devices.
			hidMatchDictionary = IOServiceMatching (kIOHIDDeviceKey);
			if (NULL != hidMatchDictionary)
			{
				if (usagePage)
				{
					// Add key for device type (joystick, in this case) to refine the matching dictionary.
					refUsagePage = CFNumberCreate (kCFAllocatorDefault, kCFNumberLongType, &usagePage);
					CFDictionarySetValue (hidMatchDictionary, CFSTR (kIOHIDPrimaryUsagePageKey), refUsagePage);
					CFRelease (refUsagePage);
					if (usage)
					{
						refUsage = CFNumberCreate (kCFAllocatorDefault, kCFNumberLongType, &usage);
						CFDictionarySetValue (hidMatchDictionary, CFSTR (kIOHIDPrimaryUsageKey), refUsage);
						CFRelease (refUsage);
					}
				}
				CFRetain(hidMatchDictionary);
			}
			else
				HIDReportError ("Failed to get HID CFMutableDictionaryRef via IOServiceMatching.");
		}

#if USE_NOTIFICATIONS
		// Create a notification port and add its run loop event source to our run loop
		// This is how async notifications get set up.
		{
			CFRunLoopSourceRef		runLoopSource;

			gNotifyPort = IONotificationPortCreate(masterPort);
			runLoopSource = IONotificationPortGetRunLoopSource(gNotifyPort);

			gRunLoop = CFRunLoopGetCurrent();
			CFRunLoopAddSource(gRunLoop, runLoopSource, kCFRunLoopDefaultMode);

			// Now set up a notification to be called when a device is first matched by I/O Kit.
			result = IOServiceAddMatchingNotification(gNotifyPort,			// notifyPort
											 kIOFirstMatchNotification,		// notificationType
											 hidMatchDictionary,			// matching
											 hid_AddDevices,				// callback
											 &gpDeviceList,					// refCon
											 &gAddedIter					// notification
											 );

			// call it now to add all existing devices
			hid_AddDevices(&gpDeviceList,gAddedIter);
            return true;
		}
#else
		{
			io_iterator_t hidObjectIterator = NULL;

			// Now search I/O Registry for matching devices.
			result = IOServiceGetMatchingServices (masterPort, hidMatchDictionary, &hidObjectIterator);
			if (kIOReturnSuccess != result)
				HIDReportErrorNum ("Failed to create IO object iterator, error:", result);
			else if (NULL == hidObjectIterator) // likely no HID devices which matched selection criteria are connected
				HIDReportError ("Warning: Could not find any matching devices, thus iterator creation failed.");

			if (NULL != hidObjectIterator)
			{
				hid_AddDevices(&gpDeviceList,hidObjectIterator);

				result = IOObjectRelease (hidObjectIterator); // release the iterator
				if (kIOReturnSuccess != result)
					HIDReportErrorNum ("IOObjectRelease error with hidObjectIterator.", result);

				gNumDevices = hid_CountCurrentDevices ();
				return true;
			}
		}
#endif USE_NOTIFICATIONS
		// IOServiceGetMatchingServices consumes a reference to the dictionary, so we don't need to release the dictionary ref.
		hidMatchDictionary = NULL;
    }
	return false;
}

// ---------------------------------
// release list built by above function
// MUST be called prior to application exit to properly release devices
// if not called (or app crashes) devices can be recovered by pluging into different location in USB chain

static void HIDReleaseDeviceList (void)
{
    while (NULL != gpDeviceList)
		gpDeviceList = hid_DisposeDevice (gpDeviceList); // dispose current device return next device will set gpDeviceList to NULL
    gNumDevices = 0;
}

// ---------------------------------
// get the first device in the device list
// returns NULL if no list exists

static pRecDevice HIDGetFirstDevice (void)
{
    return gpDeviceList;
}

// ---------------------------------
// get next device in list given current device as parameter
// returns NULL if end of list

static pRecDevice HIDGetNextDevice (pRecDevice pDevice)
{
    if (NULL != pDevice)
        return pDevice->pNext;
    else
        return NULL;
}

// ---------------------------------
// get the first element of device passed in as parameter
// returns NULL if no list exists or device does not exists or is NULL
static pRecElement HIDGetFirstDeviceElement (pRecDevice pDevice, HIDElementTypeMask typeMask)
{
    if (HIDIsValidDevice(pDevice))
	{
        if (hid_MatchElementTypeMask (pDevice->pListElements->type, typeMask)) // ensure first type matches
			return pDevice->pListElements;
		else
			return HIDGetNextDeviceElement (pDevice->pListElements, typeMask);
	}
    else
        return NULL;
}

// ---------------------------------
// get next element of given device in list given current element as parameter
// will walk down each collection then to next element or collection (depthwise traverse)
// returns NULL if end of list
// uses mask of HIDElementTypeMask to restrict element found
// use kHIDElementTypeIO to get previous HIDGetNextDeviceElement functionality
static pRecElement HIDGetNextDeviceElement (pRecElement pElement, HIDElementTypeMask typeMask)
{
	// should only have elements passed in (though someone could mix calls and pass us a collection)
	// collection means return the next child or sibling (in that order)
	// element means returnt he next sibling (as elements can't have children
    if (NULL != pElement)
	{
		if (pElement->pChild)
		{
			if (pElement->type != kIOHIDElementTypeCollection)
				HIDReportError ("Malformed element list: found child of element.");
			else
				return hid_GetDeviceElement (pElement->pChild, typeMask); // return the child of this element
		}
		else if (pElement->pSibling)
		{
			return hid_GetDeviceElement (pElement->pSibling, typeMask); //return the sibling of this element
		}
		else // at end back up correctly
		{
			pRecElement pPreviousElement = NULL;
			// malformed device ending in collection
			if (pElement->type == kIOHIDElementTypeCollection)
				HIDReportError ("Malformed device: found collection at end of element chain.");
			// walk back up tree to element prior to first collection ecountered and take next element
			while (NULL != pElement->pPrevious)
			{
				pPreviousElement = pElement;
				pElement = pElement->pPrevious; // look at previous element
									// if we have a collection and the previous element is the branch element (should have both a colection and next element attached to it)
		 // if we found a collection, which we are not at the sibling level that actually does have siblings
				if (((pElement->type == kIOHIDElementTypeCollection) && (pPreviousElement != pElement->pSibling) && pElement->pSibling) ||
		// or if we are at the top
		(NULL == pElement->pPrevious)) // at top of tree
					break;
			}
			if (NULL == pElement->pPrevious)
				return NULL; // got to top of list with only a collection as the first element
				 // now we must have been down the child route so go down the sibling route
			pElement = pElement->pSibling; // element of interest
			return hid_GetDeviceElement (pElement, typeMask); // otherwise return this element
		}
	}
	return NULL;
}


// return true if this is a valid device pointer
Boolean HIDIsValidDevice(const pRecDevice pSearchDevice)
{
	pRecDevice pDevice = gpDeviceList;

	while (pDevice)
	{
		if (pDevice == pSearchDevice)
			return true;
		pDevice = pDevice->pNext;
	}
	return false;
}


static IOReturn hid_CreateQueue (pRecDevice pDevice)
{
    IOReturn result = kIOReturnError;	// assume failure (pessimist!)

	if (HIDIsValidDevice(pDevice))
	{
		if (NULL == pDevice->queue) // do we already have a queue
		{
			if (NULL != pDevice->interface)
			{
				pDevice->queue = (void *) (*(IOHIDDeviceInterface**) pDevice->interface)->allocQueue (pDevice->interface); // alloc queue
				if (pDevice->queue)
				{
					result = (*(IOHIDQueueInterface**) pDevice->queue)->create (pDevice->queue, 0, kDeviceQueueSize); // create actual queue
					if (kIOReturnSuccess != result)
						HIDREPORTERRORNUM ("hid_CreateQueue - Failed to create queue via create", result);
				}
				else
				{
					HIDREPORTERROR ("hid_CreateQueue - Failed to alloc IOHIDQueueInterface ** via allocQueue");
					result = kIOReturnError; // synthesis error
				}
			}
			else
				HIDREPORTERRORNUM ("hid_CreateQueue - Device inteface does not exist for queue creation", result);
		}
	}
	else
		HIDREPORTERRORNUM ("hid_CreateQueue - Invalid Device", result);
    return result;
}

static unsigned long  HIDQueueDevice (pRecDevice pDevice)
{
    IOReturn result = kIOReturnError;	// assume failure (pessimist!)
    pRecElement pElement;

	if (HIDIsValidDevice(pDevice))
	{
		// error checking
		if (NULL == pDevice)
		{
			HIDREPORTERROR ("HIDQueueDevice - Device does not exist.");
			return kIOReturnBadArgument;
		}
		if (NULL == pDevice->interface) // must have interface
		{
			HIDREPORTERROR ("HIDQueueDevice - Device does not have interface.");
			return kIOReturnError;
		}
		if (NULL == pDevice->queue) // if no queue create queue
			result = hid_CreateQueue (pDevice);
		if ((kIOReturnSuccess != result) || (NULL == pDevice->queue))
		{
			HIDREPORTERRORNUM ("HIDQueueDevice - problem creating queue.", result);
			if (kIOReturnSuccess != result)
				return result;
			else
				return kIOReturnError;
		}

		// stop queue
		result = (*(IOHIDQueueInterface**) pDevice->queue)->stop (pDevice->queue);
		if (kIOReturnSuccess != result)
			HIDREPORTERRORNUM ("HIDQueueDevice - Failed to stop queue.", result);

		// queue element
  //¥ pElement = HIDGetFirstDeviceElement (pDevice, kHIDElementTypeIO);
		pElement = HIDGetFirstDeviceElement (pDevice, kHIDElementTypeInput | kHIDElementTypeFeature);

		while (pElement)
		{
			if (!(*(IOHIDQueueInterface**) pDevice->queue)->hasElement (pDevice->queue, pElement->cookie))
			{
				result = (*(IOHIDQueueInterface**) pDevice->queue)->addElement (pDevice->queue, pElement->cookie, 0);
				if (kIOReturnSuccess != result)
					HIDREPORTERRORNUM ("HIDQueueDevice - Failed to add element to queue.", result);
			}
			//¥ pElement = HIDGetNextDeviceElement (pElement, kHIDElementTypeIO);
			pElement = HIDGetNextDeviceElement (pElement, kHIDElementTypeInput | kHIDElementTypeFeature);
		}

		// start queue
		result = (*(IOHIDQueueInterface**) pDevice->queue)->start (pDevice->queue);
		if (kIOReturnSuccess != result)
			HIDREPORTERRORNUM ("HIDQueueDevice - Failed to start queue.", result);
		
	}
	else
		HIDREPORTERROR ("HIDQueueDevice - Invalid device.");

    return result;
}


/* -- END HID UTILITIES -- */


static int logical_mice = 0;
static int physical_mice = 0;
static pRecDevice *devices = NULL;

static inline int is_trackpad(const pRecDevice dev)
{
    /*
     * This stupid thing shows up as two logical devices. One does
     *  most of the mouse events, the other does the mouse wheel.
     */
    return (strcmp(dev->product, "Apple Internal Keyboard / Trackpad") == 0);
} /* is_trackpad */


/* returns non-zero if (a <= b). */
typedef unsigned long long ui64;
static inline int oldEvent(const AbsoluteTime *a, const AbsoluteTime *b)
{
#if 0  // !!! FIXME: doesn't work, timestamps aren't reliable.
    const ui64 a64 = (((unsigned long long) a->hi) << 32) | a->lo;
    const ui64 b64 = (((unsigned long long) b->hi) << 32) | b->lo;
#endif
    return 0;
} /* oldEvent */

static int poll_mouse(pRecDevice mouse, ManyMouseEvent *outevent)
{
    int unhandled = 1;
    while (unhandled)  /* read until failure or valid event. */
    {
        pRecElement recelem;
        IOHIDEventStruct event;

        if (!HIDGetEvent(mouse, &event))
            return 0;  /* no new event. */

        unhandled = 0;  /* will reset if necessary. */
        recelem = HIDGetFirstDeviceElement(mouse, kHIDElementTypeInput);
        while (recelem != NULL)
        {
            if (recelem->cookie == event.elementCookie)
                break;
            recelem = HIDGetNextDeviceElement(recelem, kHIDElementTypeInput);
        } /* while */

        if (recelem == NULL)
            continue;  /* unknown device element. Can this actually happen? */

        outevent->value = event.value;
        if (recelem->usagePage == kHIDPage_GenericDesktop)
        {
            /*
             * some devices (two-finger-scroll trackpads?) seem to give
             *  a flood of events with values of zero for every legitimate
             *  event. Throw these zero events out.
             */
            if (outevent->value == 0)
                unhandled = 1;
            else
            {
                switch (recelem->usage)
                {
                    case kHIDUsage_GD_X:
                    case kHIDUsage_GD_Y:
                        if (oldEvent(&event.timestamp, &mouse->lastScrollTime))
                            unhandled = 1;
                        else
                        {
                            outevent->type = MANYMOUSE_EVENT_RELMOTION;
                            if (recelem->usage == kHIDUsage_GD_X)
                                outevent->item = 0;
                            else
                                outevent->item = 1;
                        } /* else */
                        break;

                    case kHIDUsage_GD_Wheel:
                        memcpy(&mouse->lastScrollTime, &event.timestamp,
                               sizeof (AbsoluteTime));
                        outevent->type = MANYMOUSE_EVENT_SCROLL;
                        outevent->item = 0;  /* !!! FIXME: horiz scroll? */
                        break;

                    default:  /* !!! FIXME: absolute motion? */
                        unhandled = 1;
                } /* switch */
            } /* else */
        } /* if */

        else if (recelem->usagePage == kHIDPage_Button)
        {
            outevent->type = MANYMOUSE_EVENT_BUTTON;
            outevent->item = ((int) recelem->usage) - 1;
        } /* else if */

        else
        {
            unhandled = 1;
        } /* else */
    } /* while */

    return 1;  /* got a valid event */
} /* poll_mouse */


static void macosx_hidutilities_quit(void)
{
    HIDReleaseAllDeviceQueues();
    HIDReleaseDeviceList();
    free(devices);
    devices = NULL;
    logical_mice = 0;
    physical_mice = 0;
} /* macosx_hidutilities_quit */


static int macosx_hidutilities_init(void)
{
    macosx_hidutilities_quit();  /* just in case... */

    if (!HIDBuildDeviceList(kHIDPage_GenericDesktop, kHIDUsage_GD_Mouse))
        return -1;

    physical_mice = HIDCountDevices();
    if (physical_mice > 0)
    {
        pRecDevice dev = NULL;
        int trackpad = -1;
        int i;

        dev = HIDGetFirstDevice();
        devices = (pRecDevice *) malloc(sizeof (pRecDevice) * physical_mice);
        if ((devices == NULL) || (dev == NULL))
        {
            macosx_hidutilities_quit();
            return -1;
        } /* if */

        for (i = 0; i < physical_mice; i++)
        {
            if (dev == NULL)  /* what? list ended? Truncate final list... */
                physical_mice = i;

            if (HIDQueueDevice(dev) == kIOReturnSuccess)
            {
                if (!is_trackpad(dev))
                    dev->logical = logical_mice++;
                else
                {
                    if (trackpad < 0)
                        trackpad = logical_mice++;
                    dev->logical = trackpad;
                } /* else */
                devices[i] = dev;
            } /* if */

            else  /* failed? Chop this device from the list... */
            {
                i--;
                physical_mice--;
            } /* else */

            dev = HIDGetNextDevice(dev);
        } /* for */
    } /* if */

    return logical_mice;
} /* macosx_hidutilities_init */


/* returns the first physical device that backs a logical device. */
static pRecDevice map_logical_device(const unsigned int index)
{
    if (index < logical_mice)
    {
        unsigned int i;
        for (i = 0; i < physical_mice; i++)
        {
            if (devices[i]->logical == ((int) index))
                return devices[i];
        } /* for */
    } /* if */

    return NULL;  /* not found (maybe unplugged?) */
} /* map_logical_device */


static const char *macosx_hidutilities_name(unsigned int index)
{
    pRecDevice dev = map_logical_device(index);
    return (dev != NULL) ? dev->product : NULL;
} /* macosx_hidutilities_name */


static int macosx_hidutilities_poll(ManyMouseEvent *event)
{
    /*
     * (i) is static so we iterate through all mice round-robin. This
     *  prevents a chatty mouse from dominating the queue.
     */
    static unsigned int i = 0;

    if (i >= physical_mice)
        i = 0;  /* handle reset condition. */

    if (event != NULL)
    {
        while (i < physical_mice)
        {
            pRecDevice dev = devices[i];
            if ((dev) && (dev->disconnect != DISCONNECT_COMPLETE))
            {
                const int logical = dev->logical;
                event->device = logical;

                /* see if mouse was unplugged since last polling... */
                if (dev->disconnect == DISCONNECT_TELLUSER)
                {
                    int j;

                    /* disable physical devices backing this logical mouse. */
                    for (j = 0; j < physical_mice; j++)
                    {
                        if (devices[j]->logical == logical)
                        {
                            devices[j]->disconnect = DISCONNECT_COMPLETE;
                            devices[j]->logical = -1;
                        } /* if */
                    } /* for */

                    event->type = MANYMOUSE_EVENT_DISCONNECT;
                    return 1;
                } /* if */

                if (poll_mouse(dev, event))
                    return 1;
            } /* if */
            i++;
        } /* while */
    } /* if */

    return 0;  /* no new events */
} /* macosx_hidutilities_poll */

static const ManyMouseDriver ManyMouseDriver_interface =
{
    "Mac OS X Legacy HID Utilities",
    macosx_hidutilities_init,
    macosx_hidutilities_quit,
    macosx_hidutilities_name,
    macosx_hidutilities_poll
};

const ManyMouseDriver *ManyMouseDriver_hidutilities = &ManyMouseDriver_interface;

#else
const ManyMouseDriver *ManyMouseDriver_hidutilities = 0;
#endif  /* ifdef Mac OS X blocker */

/* end of macosx_hidutilities.c ... */

