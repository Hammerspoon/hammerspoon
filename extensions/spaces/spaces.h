
/************************************************************************************************/

typedef int CGSConnection;
typedef int CGSWindow;
typedef int CGSValue;
extern CGSConnection _CGSDefaultConnection(void);
extern OSStatus CGSGetWindowCount(const CGSConnection cid, CGSConnection targetCID, int* outCount);
extern OSStatus CGSGetWindowList(const CGSConnection cid, CGSConnection targetCID, int count, int* list, int* outCount);
extern OSStatus CGSGetOnScreenWindowCount(const CGSConnection cid, CGSConnection targetCID, int* outCount);
extern OSStatus CGSGetOnScreenWindowList(const CGSConnection cid, CGSConnection targetCID, int count, int* list, int* outCount);
extern OSStatus CGSGetWindowLevel(const CGSConnection cid, CGSWindow wid,  int *level);
extern OSStatus CGSGetScreenRectForWindow(const CGSConnection cid, CGSWindow wid, CGRect *outRect);
extern OSStatus CGSGetWindowOwner(const CGSConnection cid, const CGSWindow wid, CGSConnection *ownerCid);
extern OSStatus CGSConnectionGetPID(const CGSConnection cid, pid_t *pid, const CGSConnection ownerCid);
extern OSStatus CGSGetConnectionIDForPSN(const CGSConnection cid, ProcessSerialNumber *psn, CGSConnection *out);
typedef uint64_t CGSSpace;
typedef enum _CGSSpaceType {
    kCGSSpaceUser,
    kCGSSpaceFullscreen,
    kCGSSpaceSystem,
    kCGSSpaceUnknown
} CGSSpaceType;
typedef enum _CGSSpaceSelector {
    kCGSSpaceCurrent = 5,
    kCGSSpaceOther = 6,
    kCGSSpaceAll = 7
} CGSSpaceSelector;

extern CFArrayRef CGSCopySpaces(const CGSConnection cid, CGSSpaceSelector type);
extern CFArrayRef CGSCopySpacesForWindows(const CGSConnection cid, CGSSpaceSelector type, CFArrayRef windows);
extern CGSSpaceType CGSSpaceGetType(const CGSConnection cid, CGSSpace space);

extern CFNumberRef CGSWillSwitchSpaces(const CGSConnection cid, CFArrayRef a);
extern void CGSHideSpaces(const CGSConnection cid, NSArray* spaces);
extern void CGSShowSpaces(const CGSConnection cid, NSArray* spaces);

extern void CGSAddWindowsToSpaces(const CGSConnection cid, CFArrayRef windows, CFArrayRef spaces);
extern void CGSRemoveWindowsFromSpaces(const CGSConnection cid, CFArrayRef windows, CFArrayRef spaces);
extern OSStatus CGSMoveWorkspaceWindowList(const CGSConnection connection, CGSWindow *wids, int count, int toWorkspace);

typedef uint64_t CGSManagedDisplay;
extern CGSManagedDisplay kCGSPackagesMainDisplayIdentifier;
extern void CGSManagedDisplaySetCurrentSpace(const CGSConnection cid, CGSManagedDisplay display, CGSSpace space);
/************************************************************************************************/

