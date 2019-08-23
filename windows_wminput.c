/*
 * Support for Windows via the WM_INPUT message.
 *
 * Please see the file LICENSE.txt in the source's root directory.
 *
 *  This file written by Ryan C. Gordon.
 */

#include "manymouse.h"

#if (defined(_WIN32) || defined(_WINDOWS) || defined(__CYGWIN__))

/* WinUser.h won't include rawinput stuff without this... */
#if (_WIN32_WINNT < 0x0501)
#undef _WIN32_WINNT
#define _WIN32_WINNT 0x0501
#endif

#define WIN32_LEAN_AND_MEAN 1
#include <windows.h>
#include <setupapi.h>
#include <malloc.h>  /* needed for alloca(). */

/* Cygwin's headers don't have WM_INPUT right now... */
#ifndef WM_INPUT
#define WM_INPUT 0x00FF
#endif

/* that should be enough, knock on wood. */
#define MAX_MICE 32

/*
 * Just trying to avoid malloc() here...we statically allocate a buffer
 *  for events and treat it as a ring buffer.
 */
/* !!! FIXME: tweak this? */
#define MAX_EVENTS 1024
static ManyMouseEvent input_events[MAX_EVENTS];
static volatile int input_events_read = 0;
static volatile int input_events_write = 0;
static int available_mice = 0;
static int did_api_lookup = 0;
static HWND raw_hwnd = NULL;
static const char *class_name = "ManyMouseRawInputCatcher";
static const char *win_name = "ManyMouseRawInputMsgWindow";
static ATOM class_atom = 0;
static CRITICAL_SECTION mutex;

typedef struct
{
    HANDLE handle;
    char name[256];
} MouseStruct;
static MouseStruct mice[MAX_MICE];


/*
 * The RawInput APIs only exist in Windows XP and later, so you want this
 *  to fail gracefully on earlier systems instead of refusing to start the
 *  process due to missing symbols. To this end, we do a symbol lookup on
 *  User32.dll, etc to get the entry points.
 *
 * A lot of these are available all the way back to the start of win32 in
 *  Windows 95 and WinNT 3.1, but just so you don't have to track down any
 *  import libraries, I've added those here, too. That fits well with the
 *  idea of just adding the sources to your build and going forward.
 */
static UINT (WINAPI *pGetRawInputDeviceList)(PRAWINPUTDEVICELIST,PUINT,UINT);
/* !!! FIXME: use unicode version */
static UINT (WINAPI *pGetRawInputDeviceInfoA)(HANDLE,UINT,LPVOID,PUINT);
static BOOL (WINAPI *pRegisterRawInputDevices)(PCRAWINPUTDEVICE,UINT,UINT);
static LRESULT (WINAPI *pDefRawInputProc)(PRAWINPUT *,INT,UINT);
static UINT (WINAPI *pGetRawInputBuffer)(PRAWINPUT,PUINT,UINT);
static UINT (WINAPI *pGetRawInputData)(HRAWINPUT,UINT,LPVOID,PUINT,UINT);
static HWND (WINAPI *pCreateWindowExA)(DWORD,LPCTSTR,LPCTSTR,DWORD,int,int,int,int,HWND,HMENU,HINSTANCE,LPVOID);
static ATOM (WINAPI *pRegisterClassExA)(CONST WNDCLASSEX *);
static LRESULT (WINAPI *pDefWindowProcA)(HWND,UINT,WPARAM,LPARAM);
static BOOL (WINAPI *pUnregisterClassA)(LPCTSTR,HINSTANCE);
static HMODULE (WINAPI *pGetModuleHandleA)(LPCTSTR);
static BOOL (WINAPI *pPeekMessageA)(LPMSG,HWND,UINT,UINT,UINT);
static BOOL (WINAPI *pTranslateMessage)(const MSG *);
static LRESULT (WINAPI *pDispatchMessageA)(const MSG *);
static BOOL (WINAPI *pDestroyWindow)(HWND);
static void (WINAPI *pInitializeCriticalSection)(LPCRITICAL_SECTION);
static void (WINAPI *pEnterCriticalSection)(LPCRITICAL_SECTION);
static void (WINAPI *pLeaveCriticalSection)(LPCRITICAL_SECTION);
static void (WINAPI *pDeleteCriticalSection)(LPCRITICAL_SECTION);
static DWORD (WINAPI *pGetLastError)(void);
static HDEVINFO (WINAPI *pSetupDiGetClassDevsA)(LPGUID, LPCTSTR, HWND, DWORD);
static BOOL (WINAPI *pSetupDiEnumDeviceInfo)(HDEVINFO, DWORD, PSP_DEVINFO_DATA);
static BOOL (WINAPI *pSetupDiGetDeviceInstanceIdA)(HDEVINFO, PSP_DEVINFO_DATA, PTSTR, DWORD, PDWORD);
static BOOL (WINAPI *pSetupDiGetDeviceRegistryPropertyA)(HDEVINFO, PSP_DEVINFO_DATA, DWORD, PDWORD, PBYTE, DWORD, PDWORD);
static BOOL (WINAPI *pSetupDiDestroyDeviceInfoList)(HDEVINFO);

static int symlookup(HMODULE dll, void **addr, const char *sym)
{
    *addr = GetProcAddress(dll, sym);
    if (*addr == NULL)
    {
        FreeLibrary(dll);
        return 0;
    } /* if */

    return 1;
} /* symlookup */

static int find_api_symbols(void)
{
    HMODULE dll;

    if (did_api_lookup)
        return 1;

    #define LOOKUP(x) { if (!symlookup(dll, (void **) &p##x, #x)) return 0; }
    dll = LoadLibrary(TEXT("user32.dll"));
    if (dll == NULL)
        return 0;

    LOOKUP(GetRawInputDeviceInfoA);
    LOOKUP(RegisterRawInputDevices);
    LOOKUP(GetRawInputDeviceList);
    LOOKUP(DefRawInputProc);
    LOOKUP(GetRawInputBuffer);
    LOOKUP(GetRawInputData);
    LOOKUP(CreateWindowExA);
    LOOKUP(RegisterClassExA);
    LOOKUP(UnregisterClassA);
    LOOKUP(DefWindowProcA);
    LOOKUP(PeekMessageA);
    LOOKUP(TranslateMessage);
    LOOKUP(DispatchMessageA);
    LOOKUP(DestroyWindow);

    dll = LoadLibrary(TEXT("kernel32.dll"));
    if (dll == NULL)
        return 0;

    LOOKUP(GetModuleHandleA);
    LOOKUP(GetLastError);
    LOOKUP(InitializeCriticalSection);
    LOOKUP(EnterCriticalSection);
    LOOKUP(LeaveCriticalSection);
    LOOKUP(DeleteCriticalSection);

    dll = LoadLibrary(TEXT("setupapi.dll"));
    if (dll == NULL)
        return 0;

    LOOKUP(SetupDiGetClassDevsA);
    LOOKUP(SetupDiEnumDeviceInfo);
    LOOKUP(SetupDiGetDeviceInstanceIdA);
    LOOKUP(SetupDiGetDeviceRegistryPropertyA);
    LOOKUP(SetupDiDestroyDeviceInfoList);

    #undef LOOKUP

    did_api_lookup = 1;
    return 1;
} /* find_api_symbols */


/* Some simple functions to avoid C runtime dependency... */

static char make_upper(const char a)
{
    return ((a >= 'a') && (a <= 'z')) ? (a - ('a' - 'A')) : a;
} /* make_upper */

static void make_string_upper(char *str)
{
    char *ptr;
    for (ptr = str; *ptr; ptr++)
        *ptr = make_upper(*ptr);
} /* make_string_upper */

static int string_compare(const char *a, const char *b)
{
    while (1)
    {
        const char cha = *(a++);
        const char chb = *(b++);
        if (cha < chb)
            return -1;
        else if (cha > chb)
            return 1;
        else if (cha == '\0')
            return 0;
    } /* while */

    return 0;
} /* string_compare */

static size_t string_length(const char *a)
{
    size_t retval;
    for (retval = 0; *(a++); retval++) { /* spin. */ }
    return retval;
} /* string_length */


static void queue_event(const ManyMouseEvent *event)
{
    /* copy the event info. We'll process it in ManyMouse_PollEvent(). */
    CopyMemory(&input_events[input_events_write], event, sizeof (ManyMouseEvent));

    input_events_write = ((input_events_write + 1) % MAX_EVENTS);

    /* Ring buffer full? Lose oldest event. */
    if (input_events_write == input_events_read)
    {
        /* !!! FIXME: we need to not lose mouse buttons here. */
        input_events_read = ((input_events_read + 1) % MAX_EVENTS);
    } /* if */
} /* queue_event */


static void queue_from_rawinput(const RAWINPUT *raw)
{
    int i;
    const RAWINPUTHEADER *header = &raw->header;
    const RAWMOUSE *mouse = &raw->data.mouse;
    ManyMouseEvent event;

    if (raw->header.dwType != RIM_TYPEMOUSE)
        return;

    for (i = 0; i < available_mice; i++)  /* find the device for event. */
    {
        if (mice[i].handle == header->hDevice)
            break;
    } /* for */

    if (i == available_mice)
        return;  /* not found?! */

    /*
     * RAWINPUT packs a bunch of events into one, so we split it up into
     *  a bunch of ManyMouseEvents here and store them in an internal queue.
     *  Then ManyMouse_PollEvent() just shuffles items off that queue
     *  without any complicated processing.
     */

    event.device = i;

    pEnterCriticalSection(&mutex);

    if (mouse->usFlags & MOUSE_MOVE_ABSOLUTE)
    {
        /* !!! FIXME: How do we get the min and max values for absmotion? */
        event.type = MANYMOUSE_EVENT_ABSMOTION;
        event.item = 0;
        event.value = mouse->lLastX;
        queue_event(&event);
        event.item = 1;
        event.value = mouse->lLastY;
        queue_event(&event);
    } /* if */

    else /*if (mouse->usFlags & MOUSE_MOVE_RELATIVE)*/
    {
        event.type = MANYMOUSE_EVENT_RELMOTION;
        if (mouse->lLastX != 0)
        {
            event.item = 0;
            event.value = mouse->lLastX;
            queue_event(&event);
        } /* if */

        if (mouse->lLastY != 0)
        {
            event.item = 1;
            event.value = mouse->lLastY;
            queue_event(&event);
        } /* if */
    } /* else if */

    event.type = MANYMOUSE_EVENT_BUTTON;

    #define QUEUE_BUTTON(x) { \
        if (mouse->usButtonFlags & RI_MOUSE_BUTTON_##x##_DOWN) { \
            event.item = x-1; \
            event.value = 1; \
            queue_event(&event); \
        } \
        if (mouse->usButtonFlags & RI_MOUSE_BUTTON_##x##_UP) { \
            event.item = x-1; \
            event.value = 0; \
            queue_event(&event); \
        } \
    }

    QUEUE_BUTTON(1);
    QUEUE_BUTTON(2);
    QUEUE_BUTTON(3);
    QUEUE_BUTTON(4);
    QUEUE_BUTTON(5);

    #undef QUEUE_BUTTON

    if (mouse->usButtonFlags & RI_MOUSE_WHEEL)
    {
        if (mouse->usButtonData != 0)  /* !!! FIXME: can this ever be zero? */
        {
            event.type = MANYMOUSE_EVENT_SCROLL;
            event.item = 0;  /* !!! FIXME: horizontal wheel? */
            event.value = ( ((SHORT) mouse->usButtonData) > 0) ? 1 : -1;
            queue_event(&event);
        } /* if */
    } /* if */

    pLeaveCriticalSection(&mutex);
} /* queue_from_rawinput */


static void wminput_handler(WPARAM wParam, LPARAM lParam)
{
    UINT dwSize = 0;
    LPBYTE lpb;

    pGetRawInputData((HRAWINPUT) lParam, RID_INPUT, NULL, &dwSize,
                      sizeof (RAWINPUTHEADER));

    if (dwSize < sizeof (RAWINPUT))
        return;  /* unexpected packet? */

    lpb = (LPBYTE) alloca(dwSize);
    if (lpb == NULL) 
        return;
    if (pGetRawInputData((HRAWINPUT) lParam, RID_INPUT, lpb, &dwSize,
                          sizeof (RAWINPUTHEADER)) != dwSize)
        return;

    queue_from_rawinput((RAWINPUT *) lpb);
} /* wminput_handler */


static LRESULT CALLBACK RawWndProc(HWND hWnd, UINT Msg, WPARAM wParam, LPARAM lParam)
{
    if (Msg == WM_INPUT)
        wminput_handler(wParam, lParam);

    else if (Msg == WM_DESTROY)
        return 0;

    return pDefWindowProcA(hWnd, Msg, wParam, lParam);
} /* RawWndProc */


static int init_event_queue(void)
{
    HINSTANCE hInstance = pGetModuleHandleA(NULL);
    WNDCLASSEX wce;
    RAWINPUTDEVICE rid;

    ZeroMemory(input_events, sizeof (input_events));
    input_events_read = input_events_write = 0;

    ZeroMemory(&wce, sizeof (wce));
    wce.cbSize = sizeof(WNDCLASSEX);
    wce.lpfnWndProc = RawWndProc;
    wce.lpszClassName = class_name;
    wce.hInstance = hInstance;
    class_atom = pRegisterClassExA(&wce);
    if (class_atom == 0)
        return 0;

    raw_hwnd = pCreateWindowExA(0, class_name, win_name, WS_OVERLAPPEDWINDOW,
                        CW_USEDEFAULT, CW_USEDEFAULT, CW_USEDEFAULT,
                        CW_USEDEFAULT, HWND_MESSAGE, NULL, hInstance, NULL);

    if (raw_hwnd == NULL)
        return 0;

    pInitializeCriticalSection(&mutex);

    ZeroMemory(&rid, sizeof (rid));
    rid.usUsagePage = 1; /* GenericDesktop page */
    rid.usUsage = 2; /* GeneralDestop Mouse usage. */
    rid.dwFlags = RIDEV_INPUTSINK;
    rid.hwndTarget = raw_hwnd;
    if (!pRegisterRawInputDevices(&rid, 1, sizeof (rid)))
    {
        pDeleteCriticalSection(&mutex);
        return 0;
    } /* if */

    return 1;
} /* init_event_queue */


static void cleanup_window(void)
{
    if (raw_hwnd)
    {
        MSG Msg;
        pDestroyWindow(raw_hwnd);
        while (pPeekMessageA(&Msg, raw_hwnd, 0, 0, PM_REMOVE))
        {
            pTranslateMessage(&Msg);
            pDispatchMessageA(&Msg);
        } /* while */
        raw_hwnd = 0;
    } /* if */

    if (class_atom)
    {
        pUnregisterClassA(class_name, pGetModuleHandleA(NULL));
        class_atom = 0;
    } /* if */
} /* cleanup_window */


static int get_devinfo_data(HDEVINFO devinfo, const char *devinstance,
                            SP_DEVINFO_DATA *data)
{
    DWORD i = 0;
    const DWORD bufsize = string_length(devinstance) + 1;
    char *buf = (char *) alloca(bufsize);
    if (buf == NULL)
        return 0;

    while (1)
    {
        ZeroMemory(data, sizeof (SP_DEVINFO_DATA));
        data->cbSize = sizeof (SP_DEVINFO_DATA);
        if (!pSetupDiEnumDeviceInfo(devinfo, i++, data))
        {
            if (pGetLastError() == ERROR_NO_MORE_ITEMS)
                break;
            else
                continue;
        } /* if */

        if (!pSetupDiGetDeviceInstanceIdA(devinfo, data, buf, bufsize, NULL))
            continue;

        make_string_upper(buf);
        if (string_compare(devinstance, buf) == 0)
            return 1;  /* found it! */
    } /* while */

    return 0;  /* not found. */
} /* get_devinfo_data */


static void get_dev_name_by_instance(const char *devinstance, char *name,
                                     size_t namesize)
{
    SP_DEVINFO_DATA devdata;
    const DWORD flags = DIGCF_ALLCLASSES | DIGCF_PRESENT;
    HDEVINFO devinfo = pSetupDiGetClassDevsA(NULL, NULL, NULL, flags);
    if (devinfo == INVALID_HANDLE_VALUE)
        return;

    if (get_devinfo_data(devinfo, devinstance, &devdata))
    {
        pSetupDiGetDeviceRegistryPropertyA(devinfo, &devdata, SPDRP_DEVICEDESC,
                                           NULL, (PBYTE) name, namesize, NULL);
    } /* if */

    pSetupDiDestroyDeviceInfoList(devinfo);
} /* get_dev_name_by_instance */


static void get_device_product_name(char *name, size_t namesize, char *devname)
{
    const char default_device_name[] = "Unidentified input device";

    *name = '\0';  /* really insane default. */
    if (sizeof (default_device_name) >= namesize)
        return;

    /* in case we can't stumble upon something better... */
    CopyMemory(name, default_device_name, sizeof (default_device_name));

    /* okay, we're got the device instance. Now find the data for it. */
    get_dev_name_by_instance(devname, name, namesize);
} /* get_device_product_name */


static void init_mouse(const RAWINPUTDEVICELIST *dev)
{
    const char rdp_ident[] = "ROOT\\RDP_MOU\\";
    MouseStruct *mouse = &mice[available_mice];
    char *buf = NULL;
    char *ptr = NULL;
    UINT ct = 0;

    if (dev->dwType != RIM_TYPEMOUSE)
        return;  /* keyboard or some other fruity thing. */

    if (pGetRawInputDeviceInfoA(dev->hDevice, RIDI_DEVICENAME, NULL, &ct) < 0)
        return;

    /* ct == is chars, not bytes, but we used the ASCII version. */
    buf = (char *) alloca(ct+1);
    if (buf == NULL)
        return;

    if (pGetRawInputDeviceInfoA(dev->hDevice, RIDI_DEVICENAME, buf, &ct) < 0)
        return;

    buf[ct] = '\0';  /* make sure it's null-terminated. */

    /* XP starts these strings with "\\??\\" ... Vista does "\\\\?\\".  :/ */
    while ((*buf == '?') || (*buf == '\\'))
    {
        buf++;
        ct--;
    } /* while */

    /* This string tap dancing gets us the device instance id. */
    for (ptr = buf; *ptr; ptr++)  /* convert '#' to '\\' ... */
    {
        char ch = *ptr;
        if (ch == '#')
            *ptr = '\\';
        else if (ch == '{')  /* hit the GUID part of the string. */
        {
            if (*(ptr-1) == '\\')
                ptr--;
            break;
        } /* else if */
    } /* for */

    *ptr = '\0';

    make_string_upper(buf);

    /*
     * Apparently there's a fake "RDP" device...I guess this is
     *  "Remote Desktop Protocol" for controlling the system pointer
     *  remotely via Windows Remote Desktop, but that's just a guess.
     * At any rate, we don't want that device, so skip it if detected.
     *
     * Idea for this found here:
     *   http://link.mywwwserver.com/~jstookey/arcade/rawmouse/raw_mouse.c
     */

    /* avoiding memcmp here so we don't get a C runtime dependency... */
    if (ct >= sizeof (rdp_ident) - 1)
    {
        int i;
        for (i = 0; i < sizeof (rdp_ident) - 1; i++)
        {
            if (buf[i] != rdp_ident[i])
                break;
        } /* for */

        if (i == sizeof (rdp_ident) - 1)
            return;  /* this is an RDP thing. Skip this device. */
    } /* if */

    /* accept this mouse! */
    ZeroMemory(mouse, sizeof (MouseStruct));
    get_device_product_name(mouse->name, sizeof (mouse->name), buf);
    mouse->handle = dev->hDevice;
    available_mice++;
} /* init_mouse */


static int windows_wminput_init(void)
{
    RAWINPUTDEVICELIST *devlist = NULL;
    UINT ct = 0;
    UINT i;

    available_mice = 0;

    if (!find_api_symbols())  /* only supported on WinXP and later. */
        return -1;

    pGetRawInputDeviceList(NULL, &ct, sizeof (RAWINPUTDEVICELIST));
    if (ct == 0)  /* no devices. */
        return 0;

    devlist = (PRAWINPUTDEVICELIST) alloca(sizeof (RAWINPUTDEVICELIST) * ct);
    pGetRawInputDeviceList(devlist, &ct, sizeof (RAWINPUTDEVICELIST));
    for (i = 0; i < ct; i++)
        init_mouse(&devlist[i]);

    if (!init_event_queue())
    {
        cleanup_window();
        available_mice = 0;
    } /* if */

    return available_mice;
} /* windows_wminput_init */


static void windows_wminput_quit(void)
{
    /* unregister WM_INPUT devices... */
    RAWINPUTDEVICE rid;
    ZeroMemory(&rid, sizeof (rid));
    rid.usUsagePage = 1; /* GenericDesktop page */
    rid.usUsage = 2; /* GeneralDestop Mouse usage. */
    rid.dwFlags |= RIDEV_REMOVE;
    pRegisterRawInputDevices(&rid, 1, sizeof (rid));
    cleanup_window();
    available_mice = 0;
    pDeleteCriticalSection(&mutex);
} /* windows_wminput_quit */


static const char *windows_wminput_name(unsigned int index)
{
    return (index < available_mice) ? mice[index].name : NULL;
} /* windows_wminput_name */


/*
 * Windows doesn't send a WM_INPUT event when you unplug a mouse,
 *  so we try to do a basic query by device handle here; if the
 *  query fails, we assume the device has vanished and generate a
 *  disconnect.
 */
static int check_for_disconnects(ManyMouseEvent *ev)
{
    /*
     * (i) is static so we iterate through all mice round-robin and check
     *  one mouse per call to ManyMouse_PollEvent(). This makes this test O(1).
     */
    static unsigned int i = 0;
    MouseStruct *mouse = NULL;

    if (++i >= available_mice)  /* check first in case of redetect */
        i = 0;

    mouse = &mice[i];
    if (mouse->handle != NULL)  /* not NULL == still plugged in. */
    {
        UINT size = 0;
        UINT rc = pGetRawInputDeviceInfoA(mouse->handle, RIDI_DEVICEINFO,
                                          NULL, &size);
        if (rc == (UINT) -1)  /* failed...probably unplugged... */
        {
            mouse->handle = NULL;
            ev->type = MANYMOUSE_EVENT_DISCONNECT;
            ev->device = i;
            return 1;
        } /* if */
    } /* if */

    return 0;  /* no disconnect event this time. */
} /* check_for_disconnects */


static int windows_wminput_poll(ManyMouseEvent *ev)
{
    MSG Msg;  /* run the queue for WM_INPUT messages, etc ... */
    int found = 0;

    /* ...favor existing events in the queue... */
    pEnterCriticalSection(&mutex);
    if (input_events_read != input_events_write)  /* no events if equal. */
    {
        CopyMemory(ev, &input_events[input_events_read], sizeof (*ev));
        input_events_read = ((input_events_read + 1) % MAX_EVENTS);
        found = 1;
    } /* if */
    pLeaveCriticalSection(&mutex);

    if (!found)
    {
        /* pump Windows for new hardware events... */
        while (pPeekMessageA(&Msg, raw_hwnd, 0, 0, PM_REMOVE))
        {
            pTranslateMessage(&Msg);
            pDispatchMessageA(&Msg);
        } /* while */

        /* In case something new came in, give it to the app... */
        pEnterCriticalSection(&mutex);
        if (input_events_read != input_events_write)  /* no events if equal. */
        {
            CopyMemory(ev, &input_events[input_events_read], sizeof (*ev));
            input_events_read = ((input_events_read + 1) % MAX_EVENTS);
            found = 1;
        } /* if */
        pLeaveCriticalSection(&mutex);
    } /* if */

    /*
     * Check for disconnects if queue is totally empty and Windows didn't
     *  report anything new at this time. This ensures that we don't send a
     *  disconnect event through ManyMouse and then later give a valid
     *  event to the app for a device that is now missing.
     */
    if (!found)
        found = check_for_disconnects(ev);

    return found;
} /* windows_wminput_poll */

static const ManyMouseDriver ManyMouseDriver_interface =
{
    "Windows XP and later WM_INPUT interface",
    windows_wminput_init,
    windows_wminput_quit,
    windows_wminput_name,
    windows_wminput_poll
};

const ManyMouseDriver *ManyMouseDriver_windows = &ManyMouseDriver_interface;

#else
const ManyMouseDriver *ManyMouseDriver_windows = 0;
#endif  /* ifdef Windows blocker */

/* end of windows_wminput.c ... */

