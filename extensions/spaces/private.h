#pragma once

// Most of these mirror similarly named functions in the CGS* name space used by my previous hs._asm.undocumented.spaces, but as the
// SkyLight Server framework seems to be cropping up more and more with new OS features (esp the virtual touchbar), I suspect it may
// be more "future proof"... I'm going to use these instead.

extern int SLSMainConnectionID(void) ;
extern CGError CoreDockSendNotification(CFStringRef notification, int unknown);

extern CFArrayRef SLSCopyManagedDisplaySpaces(int cid) ;
extern int SLSSpaceGetType(int cid, uint64_t sid);
extern CFArrayRef SLSCopyWindowsWithOptionsAndTags(int cid, uint32_t owner, CFArrayRef spaces, uint32_t options, uint64_t *set_tags, uint64_t *clear_tags);
extern void SLSMoveWindowsToManagedSpace(int cid, CFArrayRef window_list, uint64_t sid);
extern CFArrayRef SLSCopySpacesForWindows(int cid, int selector, CFArrayRef window_list);

// extern uint64_t SLSManagedDisplayGetCurrentSpace(int cid, CFStringRef uuid) ;
// extern CFStringRef SLSCopyManagedDisplayForSpace(int cid, uint64_t sid);
// extern CFStringRef SLSSpaceCopyName(int cid, uint64_t sid);
// extern CGError SLSProcessAssignToSpace(int cid, pid_t pid, uint64_t sid);
// extern CGError SLSProcessAssignToAllSpaces(int cid, pid_t pid);


// Not used in Yabai, but still potentially useful
extern uint64_t SLSGetActiveSpace(int cid) ;
extern bool SLSManagedDisplayIsAnimating(int cid, CFStringRef uuid) ;
