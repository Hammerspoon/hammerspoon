/*
 * Support for Linux evdevs...the /dev/input/event* devices.
 *
 * Please see the file LICENSE.txt in the source's root directory.
 *
 *  This file written by Ryan C. Gordon.
 */

#include "manymouse.h"

#ifdef __linux__

#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <unistd.h>
#include <dirent.h>
#include <errno.h>
#include <sys/types.h>
#include <unistd.h>
#include <sys/stat.h>
#include <fcntl.h>

#include <linux/input.h>  /* evdev interface...  */

#define test_bit(array, bit)    (array[bit/8] & (1<<(bit%8)))

/* linux allows 32 evdev nodes currently. */
#define MAX_MICE 32
typedef struct
{
    int fd;
    int min_x;
    int min_y;
    int max_x;
    int max_y;
    char name[64];
} MouseStruct;

static MouseStruct mice[MAX_MICE];
static unsigned int available_mice = 0;


static int poll_mouse(MouseStruct *mouse, ManyMouseEvent *outevent)
{
    int unhandled = 1;
    while (unhandled)  /* read until failure or valid event. */
    {
        struct input_event event;
        int br = read(mouse->fd, &event, sizeof (event));
        if (br == -1)
        {
            if (errno == EAGAIN)
                return 0;  /* just no new data at the moment. */

            /* mouse was unplugged? */
            close(mouse->fd);  /* stop reading from this mouse. */
            mouse->fd = -1;
            outevent->type = MANYMOUSE_EVENT_DISCONNECT;
            return 1;
        } /* if */

        if (br != sizeof (event))
            return 0;  /* oh well. */

        unhandled = 0;  /* will reset if necessary. */
        outevent->value = event.value;
        if (event.type == EV_REL)
        {
            outevent->type = MANYMOUSE_EVENT_RELMOTION;
            if ((event.code == REL_X) || (event.code == REL_DIAL))
                outevent->item = 0;
            else if (event.code == REL_Y)
                outevent->item = 1;

            else if (event.code == REL_WHEEL)
            {
                outevent->type = MANYMOUSE_EVENT_SCROLL;
                outevent->item = 0;
            } /* else if */

            else if (event.code == REL_HWHEEL)
            {
                outevent->type = MANYMOUSE_EVENT_SCROLL;
                outevent->item = 1;
            } /* else if */

            else
            {
                unhandled = 1;
            } /* else */
        } /* if */

        else if (event.type == EV_ABS)
        {
            outevent->type = MANYMOUSE_EVENT_ABSMOTION;
            if (event.code == ABS_X)
            {
                outevent->item = 0;
                outevent->minval = mouse->min_x;
                outevent->maxval = mouse->max_x;
            } /* if */
            else if (event.code == ABS_Y)
            {
                outevent->item = 1;
                outevent->minval = mouse->min_y;
                outevent->maxval = mouse->max_y;
            } /* if */
            else
            {
                unhandled = 1;
            } /* else */
        } /* else if */

        else if (event.type == EV_KEY)
        {
            outevent->type = MANYMOUSE_EVENT_BUTTON;
            if ((event.code >= BTN_LEFT) && (event.code <= BTN_BACK))
                outevent->item = event.code - BTN_MOUSE;

            /* just in case some device uses this block of events instead... */
            else if ((event.code >= BTN_MISC) && (event.code <= BTN_LEFT))
                outevent->item = (event.code - BTN_MISC);

            else if (event.code == BTN_TOUCH) /* tablet... */
                outevent->item = 0;
            else if (event.code == BTN_STYLUS) /* tablet... */
                outevent->item = 1;
            else if (event.code == BTN_STYLUS2) /* tablet... */
                outevent->item = 2;

            else
            {
                /*printf("unhandled mouse button: 0x%X\n", event.code);*/
                unhandled = 1;
            } /* else */
        } /* else if */
        else
        {
            unhandled = 1;
        } /* else */
    } /* while */

    return 1;  /* got a valid event */
} /* poll_mouse */


static int init_mouse(const char *fname, int fd)
{
    MouseStruct *mouse = &mice[available_mice];
    int has_absolutes = 0;
    int is_mouse = 0;
    unsigned char relcaps[(REL_MAX / 8) + 1];
    unsigned char abscaps[(ABS_MAX / 8) + 1];
    unsigned char keycaps[(KEY_MAX / 8) + 1];

    memset(relcaps, '\0', sizeof (relcaps));
    memset(abscaps, '\0', sizeof (abscaps));
    memset(keycaps, '\0', sizeof (keycaps));

    if (ioctl(fd, EVIOCGBIT(EV_KEY, sizeof (keycaps)), keycaps) == -1)
        return 0;  /* gotta have some buttons!  :)  */

    if (ioctl(fd, EVIOCGBIT(EV_REL, sizeof (relcaps)), relcaps) != -1)
    {
    	if ( (test_bit(relcaps, REL_X)) && (test_bit(relcaps, REL_Y)) )
        {
            if (test_bit(keycaps, BTN_MOUSE))
                is_mouse = 1;
        } /* if */

        #if ALLOW_DIALS_TO_BE_MICE
    	if (test_bit(relcaps, REL_DIAL))
            is_mouse = 1;  // griffin powermate?
        #endif
    } /* if */

    if (ioctl(fd, EVIOCGBIT(EV_ABS, sizeof (abscaps)), abscaps) != -1)
    {
        if ( (test_bit(abscaps, ABS_X)) && (test_bit(abscaps, ABS_Y)) )
        {
            /* might be a touchpad... */
            if (test_bit(keycaps, BTN_TOUCH))
            {
                is_mouse = 1;  /* touchpad, touchscreen, or tablet. */
                has_absolutes = 1;
            } /* if */
        } /* if */
    } /* if */

    if (!is_mouse)
        return 0;

    mouse->min_x = mouse->min_y = mouse->max_x = mouse->max_y = 0;
    if (has_absolutes)
    {
        struct input_absinfo absinfo;
        if (ioctl(fd, EVIOCGABS(ABS_X), &absinfo) == -1)
            return 0;
        mouse->min_x = absinfo.minimum;
        mouse->max_x = absinfo.maximum;

        if (ioctl(fd, EVIOCGABS(ABS_Y), &absinfo) == -1)
            return 0;
        mouse->min_y = absinfo.minimum;
        mouse->max_y = absinfo.maximum;
    } /* if */

    if (ioctl(fd, EVIOCGNAME(sizeof (mouse->name)), mouse->name) == -1)
        snprintf(mouse->name, sizeof (mouse->name), "Unknown device");

    mouse->fd = fd;

    return 1;  /* we're golden. */
} /* init_mouse */


/* Return a file descriptor if this is really a mouse, -1 otherwise. */
static int open_if_mouse(const char *fname)
{
    struct stat statbuf;
    int fd;
    int devmajor, devminor;

    if (stat(fname, &statbuf) == -1)
        return 0;

    if (S_ISCHR(statbuf.st_mode) == 0)
        return 0;  /* not a character device... */

    /* evdev node ids are major 13, minor 64-96. Is this safe to check? */
    devmajor = (statbuf.st_rdev & 0xFF00) >> 8;
    devminor = (statbuf.st_rdev & 0x00FF);
    if ( (devmajor != 13) || (devminor < 64) || (devminor > 96) )
        return 0;  /* not an evdev. */

    if ((fd = open(fname, O_RDONLY | O_NONBLOCK)) == -1)
        return 0;

    if (init_mouse(fname, fd))
        return 1;

    close(fd);
    return 0;
} /* open_if_mouse */


static int linux_evdev_init(void)
{
    DIR *dirp;
    struct dirent *dent;
    int i;

    for (i = 0; i < MAX_MICE; i++)
        mice[i].fd = -1;

    dirp = opendir("/dev/input");
    if (!dirp)
        return -1;

    while ((dent = readdir(dirp)) != NULL)
    {
        char fname[128];
        snprintf(fname, sizeof (fname), "/dev/input/%s", dent->d_name);
        if (open_if_mouse(fname))
            available_mice++;
    } /* while */

    closedir(dirp);

    return available_mice;
} /* linux_evdev_init */


static void linux_evdev_quit(void)
{
    while (available_mice)
    {
        int fd = mice[available_mice--].fd;
        if (fd != -1)
            close(fd);
    } /* while */
} /* linux_evdev_quit */


static const char *linux_evdev_name(unsigned int index)
{
    return (index < available_mice) ? mice[index].name : NULL;
} /* linux_evdev_name */


static int linux_evdev_poll(ManyMouseEvent *event)
{
    /*
     * (i) is static so we iterate through all mice round-robin. This
     *  prevents a chatty mouse from dominating the queue.
     */
    static unsigned int i = 0;

    if (i >= available_mice)
        i = 0;  /* handle reset condition. */

    if (event != NULL)
    {
        while (i < available_mice)
        {
            MouseStruct *mouse = &mice[i];
            if (mouse->fd != -1)
            {
                if (poll_mouse(mouse, event))
                {
                    event->device = i;
                    return 1;
                } /* if */
            } /* if */
            i++;
        } /* while */
    } /* if */

    return 0;  /* no new events */
} /* linux_evdev_poll */

static const ManyMouseDriver ManyMouseDriver_interface =
{
    "Linux /dev/input/event* interface",
    linux_evdev_init,
    linux_evdev_quit,
    linux_evdev_name,
    linux_evdev_poll
};

const ManyMouseDriver *ManyMouseDriver_evdev = &ManyMouseDriver_interface;

#else
const ManyMouseDriver *ManyMouseDriver_evdev = 0;
#endif  /* ifdef Linux blocker */

/* end of linux_evdev.c ... */

