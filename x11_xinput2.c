/*
 * Support for the X11 XInput extension.
 *
 * Please see the file LICENSE.txt in the source's root directory.
 *
 *  This file written by Ryan C. Gordon.
 */

#include "manymouse.h"

/* Try to use this on everything but Windows and Mac OS by default... */
#ifndef SUPPORT_XINPUT2
#if ( (defined(_WIN32) || defined(__CYGWIN__)) )
#define SUPPORT_XINPUT2 0
#elif ( (defined(__MACH__)) && (defined(__APPLE__)) )
#define SUPPORT_XINPUT2 0
#else
#define SUPPORT_XINPUT2 1
#endif
#endif

#if SUPPORT_XINPUT2

#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <dlfcn.h>
#include <X11/extensions/XInput2.h>

/* 32 is good enough for now. */
#define MAX_MICE 32
#define MAX_AXIS 16
typedef struct
{
    int device_id;
    int connected;
    int relative[MAX_AXIS];
    int minval[MAX_AXIS];
    int maxval[MAX_AXIS];
    char name[64];
} MouseStruct;

static MouseStruct mice[MAX_MICE];
static unsigned int available_mice = 0;

static Display *display = NULL;
static int xi2_opcode = 0;


/* !!! FIXME: this is cut-and-paste between a few targets now. Move it to
 * !!! FIXME:  manymouse.c ...
 */
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


/*
 * You _probably_ have Xlib on your system if you're on a Unix box where you
 *  are planning to plug in multiple mice. That being said, we don't want
 *  to force a project to add Xlib to their builds, or force the end-user to
 *  have Xlib installed if they are otherwise running a console app that the
 *  evdev driver would handle.
 *
 * We load all Xlib symbols at runtime, and fail gracefully if they aren't
 *  available for some reason...ManyMouse might be able to use the evdev
 *  driver or at least return a zero.
 *
 * On Linux (and probably others), you'll need to add -ldl to your link line,
 *  but it's part of glibc, so this is pretty much going to be there.
 */

static void *libx11 = NULL;
static void *libxext = NULL;
static void *libxi = NULL;

typedef int (*XExtErrHandler)(Display *, _Xconst char *, _Xconst char *);

static XExtErrHandler (*pXSetExtensionErrorHandler)(XExtErrHandler h) = 0;
static Display* (*pXOpenDisplay)(_Xconst char*) = 0;
static int (*pXCloseDisplay)(Display*) = 0;
static int (*pXISelectEvents)(Display*,Window,XIEventMask*,int) = 0;
static Bool (*pXQueryExtension)(Display*,_Xconst char*,int*,int*,int*) = 0;
static Status (*pXIQueryVersion)(Display*,int*,int*) = 0;
static XIDeviceInfo* (*pXIQueryDevice)(Display*,int,int*) = 0;
static void (*pXIFreeDeviceInfo)(XIDeviceInfo*) = 0;
static Bool (*pXGetEventData)(Display*,XGenericEventCookie*) = 0;
static void (*pXFreeEventData)(Display*,XGenericEventCookie*) = 0;
static int (*pXNextEvent)(Display*,XEvent*) = 0;
static int (*pXPending)(Display*) = 0;
static int (*pXFlush)(Display*) = 0;
static int (*pXEventsQueued)(Display*,int) = 0;

static int symlookup(void *dll, void **addr, const char *sym)
{
    *addr = dlsym(dll, sym);
    if (*addr == NULL)
        return 0;

    return 1;
} /* symlookup */

static int find_api_symbols(void)
{
    void *dll = NULL;

    #define LOOKUP(x) { if (!symlookup(dll, (void **) &p##x, #x)) return 0; }
    dll = libx11 = dlopen("libX11.so.6", RTLD_GLOBAL | RTLD_LAZY);
    if (dll == NULL)
        return 0;

    LOOKUP(XOpenDisplay);
    LOOKUP(XCloseDisplay);
    LOOKUP(XGetEventData);
    LOOKUP(XFreeEventData);
    LOOKUP(XQueryExtension);
    LOOKUP(XNextEvent);
    LOOKUP(XPending);
    LOOKUP(XFlush);
    LOOKUP(XEventsQueued);

    dll = libxext = dlopen("libXext.so.6", RTLD_GLOBAL | RTLD_LAZY);
    if (dll == NULL)
        return 0;

    LOOKUP(XSetExtensionErrorHandler);

    dll = libxi = dlopen("libXi.so.6", RTLD_GLOBAL | RTLD_LAZY);
    if (dll == NULL)
        return 0;

    LOOKUP(XISelectEvents);
    LOOKUP(XIQueryVersion);
    LOOKUP(XIQueryDevice);
    LOOKUP(XIFreeDeviceInfo);

    #undef LOOKUP

    return 1;
} /* find_api_symbols */


static void xinput2_cleanup(void)
{
    if (display != NULL)
    {
        pXCloseDisplay(display);
        display = NULL;
    } /* if */

    memset(mice, '\0', sizeof (mice));
    available_mice = 0;

    #define LIBCLOSE(lib) { if (lib != NULL) { dlclose(lib); lib = NULL; } }
    LIBCLOSE(libxi);
    LIBCLOSE(libxext);
    LIBCLOSE(libx11);
    #undef LIBCLOSE

    memset(input_events, '\0', sizeof (input_events));
    input_events_read = input_events_write = 0;
} /* xinput2_cleanup */


static int init_mouse(MouseStruct *mouse, const XIDeviceInfo *devinfo)
{
    XIAnyClassInfo **classes = devinfo->classes;
    int axis = 0;
    int i = 0;

    /*
     * we only look at "slave" devices. "Master" pointers are the logical
     *  cursors, "slave" pointers are the hardware that back them.
     *  "Floating slaves" are hardware that don't back a cursor.
     */

    if ((devinfo->use != XISlavePointer) && (devinfo->use != XIFloatingSlave))
        return 0;  /* not a device we care about. */
    else if (strstr(devinfo->name, "XTEST pointer") != NULL)
        return 0;  /* skip this nonsense. It's for the XTEST extension. */

    mouse->device_id = devinfo->deviceid;
    mouse->connected = 1;

    for (i = 0; i < devinfo->num_classes; i++)
    {
        if ((classes[i]->type == XIValuatorClass) && (axis < MAX_AXIS))
        {
            const XIValuatorClassInfo *v = (XIValuatorClassInfo*) classes[i];
            mouse->relative[axis] = (v->mode == XIModeRelative);
            mouse->minval[axis] = (int) v->min;
            mouse->maxval[axis] = (int) v->max;
            axis++;
        } /* if */
    } /* for */

    strncpy(mouse->name, devinfo->name, sizeof (mouse->name));
    mouse->name[sizeof (mouse->name) - 1] = '\0';
    return 1;
} /* init_mouse */


static int (*Xext_handler)(Display *, _Xconst char *, _Xconst char *) = NULL;
static int xext_errhandler(Display *d, _Xconst char *ext, _Xconst char *reason)
{
    /* prevent Xlib spew to stderr for missing extensions. */
    return (strcmp(reason, "missing") == 0) ? 0 : Xext_handler(d, ext, reason);
} /* xext_errhandler */


static int register_for_events(Display *dpy)
{
    XIEventMask evmask;
    unsigned char mask[3] = { 0, 0, 0 };

    XISetMask(mask, XI_HierarchyChanged);
    XISetMask(mask, XI_RawMotion);
    XISetMask(mask, XI_RawButtonPress);
    XISetMask(mask, XI_RawButtonRelease);

    evmask.deviceid = XIAllDevices;
    evmask.mask_len = sizeof (mask);
    evmask.mask = mask;

    /* !!! FIXME: retval? */
    pXISelectEvents(dpy, DefaultRootWindow(dpy), &evmask, 1);
    return 1;
} /* register_for_events */


static int x11_xinput2_init_internal(void)
{
    const char *ext = "XInputExtension";
    XIDeviceInfo *device_list = NULL;
    int device_count = 0;
    int available = 0;
    int event = 0;
    int error = 0;
    int major = 2;
    int minor = 0;
    int i = 0;

    xinput2_cleanup();  /* just in case... */

    if (getenv("MANYMOUSE_NO_XINPUT2") != NULL)
        return -1;

    if (!find_api_symbols())
        return -1;  /* couldn't find all needed symbols. */

    display = pXOpenDisplay(NULL);
    if (display == NULL)
        return -1;  /* no X server at all */

    Xext_handler = pXSetExtensionErrorHandler(xext_errhandler);
    available = (pXQueryExtension(display, ext, &xi2_opcode, &event, &error) &&
                 (pXIQueryVersion(display, &major, &minor) != BadRequest));
    pXSetExtensionErrorHandler(Xext_handler);
    Xext_handler = NULL;

    if (!available)
        return -1;  /* no XInput2 support. */

    /*
     * Register for events first, to prevent a race where we unplug a
     *  device between when we queried for the list and when we start
     *  listening for changes.
     */
    if (!register_for_events(display))
        return -1;

    device_list = pXIQueryDevice(display, XIAllDevices, &device_count);
    for (i = 0; i < device_count; i++)
    {
        MouseStruct *mouse = &mice[available_mice];
        if (init_mouse(mouse, &device_list[i]))
            available_mice++;
    } /* for */
    pXIFreeDeviceInfo(device_list);

    return available_mice;
} /* x11_xinput2_init_internal */


static int x11_xinput2_init(void)
{
    int retval = x11_xinput2_init_internal();
    if (retval < 0)
        xinput2_cleanup();
    return retval;
} /* x11_xinput2_init */


static void x11_xinput2_quit(void)
{
    xinput2_cleanup();
} /* x11_xinput2_quit */


static const char *x11_xinput2_name(unsigned int index)
{
    return (index < available_mice) ? mice[index].name : NULL;
} /* x11_xinput2_name */


static int find_mouse_by_devid(const int devid)
{
    int i;
    const MouseStruct *mouse = mice;

    for (i = 0; i < available_mice; i++, mouse++)
    {
        if (mouse->device_id == devid)
            return (mouse->connected) ? i : -1;
    } /* for */

    return -1;
} /* find_mouse_by_devid */


static int get_next_x11_event(XEvent *xev)
{
    int available = 0;

    pXFlush(display);
    if (pXEventsQueued(display, QueuedAlready))
        available = 1;
    else
    {
        /* XPending() blocks if there's no data, so select() first. */
        struct timeval nowait;
        const int fd = ConnectionNumber(display);
        fd_set fdset;
        FD_ZERO(&fdset);
        FD_SET(fd, &fdset);
        memset(&nowait, '\0', sizeof (nowait));
        if (select(fd+1, &fdset, NULL, NULL, &nowait) == 1)
            available = pXPending(display);
    } /* else */

    if (available)
    {
        memset(xev, '\0', sizeof (*xev));
        pXNextEvent(display, xev);
        return 1;
    } /* if */

    return 0;
} /* get_next_x11_event */


/* Everything else returns left (0), right (1), middle (2)...XI2 returns
   right and middle in reverse, so swap them ourselves. */
static inline int map_xi2_button(const int button)
{
    if (button == 2)
        return 3;
    else if (button == 3)
        return 2;
    return button;
} /* map_xi2_button */


static void pump_events(void)
{
    ManyMouseEvent event;
    const int opcode = xi2_opcode;
    const XIRawEvent *rawev = NULL;
    const XIHierarchyEvent *hierev = NULL;
    int mouse = 0;
    XEvent xev;
    int i = 0;

    while (get_next_x11_event(&xev))
    {
        /* All XI2 events are "cookie" events...which need extra tapdance. */
        if (xev.xcookie.type != GenericEvent)
            continue;
        else if (xev.xcookie.extension != opcode)
            continue;
        else if (!pXGetEventData(display, &xev.xcookie))
            continue;

        switch (xev.xcookie.evtype)
        {
            case XI_RawMotion:
                rawev = (const XIRawEvent *) xev.xcookie.data;
                mouse = find_mouse_by_devid(rawev->deviceid);
                if (mouse != -1)
                {
                    const double *values = rawev->raw_values;
                    int top = rawev->valuators.mask_len * 8;
                    if (top > MAX_AXIS)
                        top = MAX_AXIS;

                    for (i = 0; i < top; i++)
                    {
                        if (XIMaskIsSet(rawev->valuators.mask, i))
                        {
                            const int value = (int) *values;
                            if (mice[mouse].relative[i])
                                event.type = MANYMOUSE_EVENT_RELMOTION;
                            else
                                event.type = MANYMOUSE_EVENT_ABSMOTION;
                            event.device = mouse;
                            event.item = i;
                            event.value = value;
                            event.minval = mice[mouse].minval[i];
                            event.maxval = mice[mouse].maxval[i];
                            if ((!mice[mouse].relative[i]) || (value))
                                queue_event(&event);
                            values++;
                        } /* if */
                    } /* for */
                } /* if */
                break;

            case XI_RawButtonPress:
            case XI_RawButtonRelease:
                rawev = (const XIRawEvent *) xev.xcookie.data;
                mouse = find_mouse_by_devid(rawev->deviceid);
                if (mouse != -1)
                {
                    const int button = map_xi2_button(rawev->detail);
                    const int pressed = (xev.xcookie.evtype==XI_RawButtonPress);

                    /* gah, XInput2 still maps the wheel to buttons. */
                    if ((button >= 4) && (button <= 7))
                    {
                        if (pressed)  /* ignore "up" for these "buttons" */
                        {
                            event.type = MANYMOUSE_EVENT_SCROLL;
                            event.device = mouse;

                            if ((button == 4) || (button == 5))
                                event.item = 0;
                            else
                                event.item = 1;

                            if ((button == 4) || (button == 6))
                                event.value = 1;
                            else
                                event.value = -1;

                            queue_event(&event);
                        } /* if */
                    } /* if */
                    else
                    {
                        event.type = MANYMOUSE_EVENT_BUTTON;
                        event.device = mouse;
                        event.item = button-1;
                        event.value = pressed;
                        queue_event(&event);
                    } /* else */
                } /* if */
                break;

            case XI_HierarchyChanged:
                hierev = (const XIHierarchyEvent *) xev.xcookie.data;
                for (i = 0; i < hierev->num_info; i++)
                {
                    if (hierev->info[i].flags & XISlaveRemoved)
                    {
                        mouse = find_mouse_by_devid(hierev->info[i].deviceid);
                        if (mouse != -1)
                        {
                            mice[mouse].connected = 0;
                            event.type = MANYMOUSE_EVENT_DISCONNECT;
                            event.device = mouse;
                            queue_event(&event);
                        } /* if */
                    } /* if */
                } /* for */
                break;
        } /* switch */

        pXFreeEventData(display, &xev.xcookie);
    } /* while */
} /* pump_events */

static int x11_xinput2_poll(ManyMouseEvent *event)
{
    if (dequeue_event(event))  /* ...favor existing events in the queue... */
        return 1;

    pump_events();  /* pump runloop for new hardware events... */
    return dequeue_event(event);  /* see if anything had shown up... */
} /* x11_xinput2_poll */

static const ManyMouseDriver ManyMouseDriver_interface =
{
    "X11 XInput2 extension",
    x11_xinput2_init,
    x11_xinput2_quit,
    x11_xinput2_name,
    x11_xinput2_poll
};

const ManyMouseDriver *ManyMouseDriver_xinput2 = &ManyMouseDriver_interface;

#else
const ManyMouseDriver *ManyMouseDriver_xinput2 = 0;
#endif /* SUPPORT_XINPUT2 blocker */

/* end of x11_xinput2.c ... */

