/*
 * Support for Mac OS X via the HID Manager APIs that are new to OS X 10.5
 *  ("Leopard"). The technotes suggest that after 10.5, the code in
 *  macosx_hidutilities.c may stop working. We dynamically look up the 10.5
 *  symbols, and if they are there, we use them. If they aren't, we fail so
 *  the legacy code can do its magic.
 *
 * Please see the file LICENSE.txt in the source's root directory.
 *
 *  This file written by Ryan C. Gordon.
 */

#include "manymouse.h"

#if ( (defined(__MACH__)) && (defined(__APPLE__)) )
#  include <AvailabilityMacros.h>  // we need the 10.5 SDK headers here...
#  if MAC_OS_X_VERSION_MAX_ALLOWED >= MAC_OS_X_VERSION_10_5
#    define MANYMOUSE_DO_MAC_10_POINT_5_API 1
#  endif
#endif

#if MANYMOUSE_DO_MAC_10_POINT_5_API

#include <IOKit/hid/IOHIDLib.h>

#define ALLOCATOR kCFAllocatorDefault
#define RUNLOOPMODE (CFSTR("ManyMouse"))
#define HIDOPS kIOHIDOptionsTypeNone

typedef struct
{
    IOHIDDeviceRef device;
    char *name;
    int logical;  /* maps to what ManyMouse reports for an index. */
} MouseStruct;

static unsigned int logical_mice = 0;
static unsigned int physical_mice = 0;
static IOHIDManagerRef hidman = NULL;
static MouseStruct *mice = NULL;

static char *get_device_name(IOHIDDeviceRef device)
{
    char *buf = NULL;
    void *ptr = NULL;
    CFIndex len = 0;
    CFStringRef cfstr = (CFStringRef) IOHIDDeviceGetProperty(device,
                                                    CFSTR(kIOHIDProductKey));
    if (!cfstr)
    {
        /* Maybe we can't get "AwesomeMouse2000", but we can get "Logitech"? */
        cfstr = (CFStringRef) IOHIDDeviceGetProperty(device,
                                                 CFSTR(kIOHIDManufacturerKey));
    } /* if */

    if (!cfstr)
        return strdup("Unidentified mouse device");  /* oh well. */

    CFRetain(cfstr);
    len = (CFStringGetLength(cfstr)+1) * 12; /* 12 is overkill, but oh well. */

    buf = (char *) malloc(len);
    if (!buf)
    {
        CFRelease(cfstr);
        return NULL;
    } /* if */

    if (!CFStringGetCString(cfstr, buf, len, kCFStringEncodingUTF8))
    {
        free(buf);
        CFRelease(cfstr);
        return NULL;
    } /* if */

    CFRelease(cfstr);

    ptr = realloc(buf, strlen(buf) + 1);  /* shrink down our allocation. */
    if (ptr != NULL)
        buf = (char *) ptr;
    return buf;
} /* get_device_name */


static inline int is_trackpad(const MouseStruct *mouse)
{
    /*
     * This stupid thing shows up as two logical devices. One does
     *  most of the mouse events, the other does the mouse wheel.
     */
    return (strcmp(mouse->name, "Apple Internal Keyboard / Trackpad") == 0);
} /* is_trackpad */


/*
 * Just trying to avoid malloc() here...we statically allocate a buffer
 *  for events and treat it as a ring buffer.
 */
/* !!! FIXME: tweak this? */
#define MAX_EVENTS 1024
static ManyMouseEvent input_events[MAX_EVENTS];
static volatile int input_events_read = 0;
static volatile int input_events_write = 0;

static void queue_event(const ManyMouseEvent *event)
{
    /* copy the event info. We'll process it in ManyMouse_PollEvent(). */
    memcpy(&input_events[input_events_write], event, sizeof (ManyMouseEvent));

    input_events_write = ((input_events_write + 1) % MAX_EVENTS);

    /* Ring buffer full? Lose oldest event. */
    if (input_events_write == input_events_read)
    {
        /* !!! FIXME: we need to not lose mouse buttons here. */
        input_events_read = ((input_events_read + 1) % MAX_EVENTS);
    } /* if */
} /* queue_event */


static int dequeue_event(ManyMouseEvent *event)
{
    if (input_events_read != input_events_write)  /* no events if equal. */
    {
        memcpy(event, &input_events[input_events_read], sizeof (*event));
        input_events_read = ((input_events_read + 1) % MAX_EVENTS);
        return 1;
    } /* if */
    return 0;  /* no event. */
} /* dequeue_event */


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


/* Callback fires whenever a device is unplugged/lost/whatever. */
static void unplugged_callback(void *ctx, IOReturn res, void *sender)
{
    const unsigned int idx = (unsigned int) ((size_t) ctx);
    if ((idx < physical_mice) && (mice[idx].device) && (mice[idx].logical >= 0))
    {
        unsigned int i;
        const int logical = mice[idx].logical;
        ManyMouseEvent ev;
        memset(&ev, '\0', sizeof (ev));
        ev.type = MANYMOUSE_EVENT_DISCONNECT;
        ev.device = logical;
        queue_event(&ev);

        /* disable any physical devices that back the same logical mouse. */
        for (i = 0; i < physical_mice; i++)
        {
            if (mice[i].logical == logical)
            {
                mice[i].device = NULL;
                mice[i].logical = -1;
            } /* if */
        } /* for */
    } /* if */
} /* unplugged_callback */


/* Callback fires for new mouse input events. */
static void input_callback(void *ctx, IOReturn res,
                           void *sender, IOHIDValueRef val)
{
    const unsigned int idx = (unsigned int) ((size_t) ctx);
    const MouseStruct *mouse = NULL;
    if ((res == kIOReturnSuccess) && (idx < physical_mice))
        mouse = &mice[idx];

    if ((mouse != NULL) && (mouse->device != NULL) && (mouse->logical >= 0))
    {
        ManyMouseEvent ev;
        IOHIDElementRef elem = IOHIDValueGetElement(val);
        const CFIndex value = IOHIDValueGetIntegerValue(val);
        const uint32_t page = IOHIDElementGetUsagePage(elem);
        const uint32_t usage = IOHIDElementGetUsage(elem);

        memset(&ev, '\0', sizeof (ev));
        ev.value = (int) value;
        ev.device = mouse->logical;

        if (page == kHIDPage_GenericDesktop)
        {
            /*
             * some devices (two-finger-scroll trackpads?) seem to give
             *  a flood of events with values of zero for every legitimate
             *  event. Throw these zero events out.
             */
            if (value != 0)
            {
                switch (usage)
                {
                    case kHIDUsage_GD_X:
                    case kHIDUsage_GD_Y:
                        /*if (!oldEvent(&event.timestamp, &mouse->lastScrollTime))*/
                        {
                            ev.type = MANYMOUSE_EVENT_RELMOTION;
                            ev.item = (usage == kHIDUsage_GD_X) ? 0 : 1;
                            queue_event(&ev);
                        } /* if */
                        break;

                    case kHIDUsage_GD_Wheel:
                        /*memcpy(&mouse->lastScrollTime, &event.timestamp, sizeof (AbsoluteTime)); */
                        ev.type = MANYMOUSE_EVENT_SCROLL;
                        ev.item = 0;  /* !!! FIXME: horiz scroll? */
                        queue_event(&ev);
                        break;

                    /*default:  !!! FIXME: absolute motion? */
                } /* switch */
            } /* if */
        } /* if */

        else if (page == kHIDPage_Button)
        {
            ev.type = MANYMOUSE_EVENT_BUTTON;
            ev.item = ((int) usage) - 1;
            queue_event(&ev);
        } /* else if */
    } /* if */
} /* input_callback */


/* We ignore hotplugs...this callback is only for initial device discovery. */
static void enum_callback(void *ctx, IOReturn res,
                          void *sender, IOHIDDeviceRef device)
{
    if (res == kIOReturnSuccess)
    {
        const size_t len = sizeof (MouseStruct) * (physical_mice + 1);
        void *ptr = realloc(mice, len);
        if (ptr != NULL)  /* if realloc fails, we just drop the device. */
        {
            mice = (MouseStruct *) ptr;
            mice[physical_mice].device = device;
            mice[physical_mice].logical = -1;  /* filled in later. */
            mice[physical_mice].name = get_device_name(device);
            if (mice[physical_mice].name == NULL)
                return;  /* This is bad! Don't add this mouse, I guess. */

            physical_mice++;
        } /* if */
    } /* if */
} /* enum_callback */


static int config_hidmanager(CFMutableDictionaryRef dict)
{
    CFRunLoopRef runloop = CFRunLoopGetCurrent();
    int trackpad = -1;
    unsigned int i;

    IOHIDManagerRegisterDeviceMatchingCallback(hidman, enum_callback, NULL);
    IOHIDManagerScheduleWithRunLoop(hidman,CFRunLoopGetCurrent(),RUNLOOPMODE);
    IOHIDManagerSetDeviceMatching(hidman, dict);
    IOHIDManagerOpen(hidman, HIDOPS);

    while (CFRunLoopRunInMode(RUNLOOPMODE,0,TRUE)==kCFRunLoopRunHandledSource)
        /* no-op. Callback fires once per existing device. */ ;

    /* globals (physical_mice) and (mice) are now configured. */
    /* don't care about any hotplugged devices after the initial list. */
    IOHIDManagerRegisterDeviceMatchingCallback(hidman, NULL, NULL);
    IOHIDManagerUnscheduleFromRunLoop(hidman, runloop, RUNLOOPMODE);

    /* now put all those discovered devices into the runloop instead... */
    for (i = 0; i < physical_mice; i++)
    {
        MouseStruct *mouse = &mice[i];
        IOHIDDeviceRef dev = mouse->device;
        if (IOHIDDeviceOpen(dev, HIDOPS) != kIOReturnSuccess)
        {
            mouse->device = NULL;  /* oh well. */
            mouse->logical = -1;
        } /* if */
        else
        {
            void *ctx = (void *) ((size_t) i);

            if (!is_trackpad(mouse))
                mouse->logical = logical_mice++;
            else
            {
                if (trackpad < 0)
                    trackpad = logical_mice++;
                mouse->logical = trackpad;
            } /* else */

            IOHIDDeviceRegisterRemovalCallback(dev, unplugged_callback, ctx);
            IOHIDDeviceRegisterInputValueCallback(dev, input_callback, ctx);
            IOHIDDeviceScheduleWithRunLoop(dev, runloop, RUNLOOPMODE);
        } /* else */
    } /* for */

    return 1;  /* good to go. */
} /* config_hidmanager */


static int create_hidmanager(const UInt32 page, const UInt32 usage)
{
    int retval = -1;
    CFNumberRef num = NULL;
    CFMutableDictionaryRef dict = CFDictionaryCreateMutable(ALLOCATOR, 0,
                                        &kCFTypeDictionaryKeyCallBacks,
                                        &kCFTypeDictionaryValueCallBacks);
    if (dict != NULL)
    {
        num = CFNumberCreate(ALLOCATOR, kCFNumberIntType, &page);
        if (num != NULL)
        {
            CFDictionarySetValue(dict, CFSTR(kIOHIDDeviceUsagePageKey), num);
            CFRelease(num);
            num = CFNumberCreate(ALLOCATOR, kCFNumberIntType, &usage);
            if (num != NULL)
            {
                CFDictionarySetValue(dict, CFSTR(kIOHIDDeviceUsageKey), num);
                CFRelease(num);
                hidman = IOHIDManagerCreate(ALLOCATOR, HIDOPS);
                if (hidman != NULL)
                    retval = config_hidmanager(dict);
            } /* if */
        } /* if */
        CFRelease(dict);
    } /* if */

    return retval;
} /* create_hidmanager */


/* ManyMouseDriver interface... */

static void macosx_hidmanager_quit(void)
{
    unsigned int i;
    for (i = 0; i < physical_mice; i++)
        free(mice[i].name);

    if (hidman != NULL)
    {
        /* closing (hidman) should close all open devices, too. */
        IOHIDManagerClose(hidman, HIDOPS);
        CFRelease(hidman);
        hidman = NULL;
    } /* if */

    logical_mice = 0;
    physical_mice = 0;
    free(mice);
    mice = NULL;

    memset(input_events, '\0', sizeof (input_events));
    input_events_read = input_events_write = 0;
} /* macosx_hidmanager_quit */


static int macosx_hidmanager_init(void)
{
    if (IOHIDManagerCreate == NULL)
        return -1;  /* weak symbol is NULL...we don't have OS X >= 10.5.0 */

    macosx_hidmanager_quit();  /* just in case... */

    /* Prepare global (hidman), (mice), (physical_mice), etc. */
    if (!create_hidmanager(kHIDPage_GenericDesktop, kHIDUsage_GD_Mouse))
        return -1;

    return (int) logical_mice;
} /* macosx_hidmanager_init */


/* returns the first physical device that backs a logical device. */
static MouseStruct *map_logical_device(const unsigned int index)
{
    if (index < logical_mice)
    {
        unsigned int i;
        for (i = 0; i < physical_mice; i++)
        {
            if (mice[i].logical == ((int) index))
                return &mice[i];
        } /* for */
    } /* if */

    return NULL;  /* not found (maybe unplugged?) */
} /* map_logical_device */

static const char *macosx_hidmanager_name(unsigned int index)
{
    const MouseStruct *mouse = map_logical_device(index);
    return mouse ? mouse->name : NULL;
} /* macosx_hidmanager_name */


static int macosx_hidmanager_poll(ManyMouseEvent *event)
{
    /* ...favor existing events in the queue... */
    if (dequeue_event(event))
        return 1;

    /* pump runloop for new hardware events... */
    while (CFRunLoopRunInMode(RUNLOOPMODE,0,TRUE)==kCFRunLoopRunHandledSource)
        /* no-op. We're filling our queue... !!! FIXME: stop if queue fills. */ ;

    return dequeue_event(event);  /* see if anything had shown up... */
} /* macosx_hidmanager_poll */


static const ManyMouseDriver ManyMouseDriver_interface =
{
    "Mac OS X 10.5+ HID Manager",
    macosx_hidmanager_init,
    macosx_hidmanager_quit,
    macosx_hidmanager_name,
    macosx_hidmanager_poll
};

const ManyMouseDriver *ManyMouseDriver_hidmanager = &ManyMouseDriver_interface;

#else
const ManyMouseDriver *ManyMouseDriver_hidmanager = 0;
#endif  /* ifdef Mac OS X blocker */

/* end of macosx_hidmanager.c ... */

