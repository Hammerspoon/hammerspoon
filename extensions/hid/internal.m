#import <Cocoa/Cocoa.h>
#import <LuaSkin/LuaSkin.h>

#import <IOKit/IOKitLib.h>
#import <IOKit/hidsystem/IOHIDLib.h>
#import <IOKit/hidsystem/IOHIDParameter.h>
#import <CoreFoundation/CoreFoundation.h>

#define CAPSLOCK_OFF    0
#define CAPSLOCK_ON     1
#define CAPSLOCK_TOGGLE -1
#define CAPSLOCK_QUERY  9

// Source: https://discussions.apple.com/thread/7094207

static int access_capslock(int op){
	kern_return_t kr = -1;
	io_service_t ios;
	io_connect_t ioc;
	CFMutableDictionaryRef mdict;
	bool state = false;

	mdict = IOServiceMatching(kIOHIDSystemClass);
	ios = IOServiceGetMatchingService(kIOMasterPortDefault, (CFDictionaryRef) mdict);
	if (!ios)
	{
		// fprintf(stderr, "IOServiceGetMatchingService() failed: %x\n", kr);
		return (int) kr;
	}

	kr = IOServiceOpen(ios, mach_task_self(), kIOHIDParamConnectType, &ioc);
	IOObjectRelease(ios);
	if (kr != KERN_SUCCESS)
	{
		// fprintf(stderr, "IOServiceOpen() failed: %x\n", kr);
		return (int) kr;
	}

	switch (op)
	{
	case CAPSLOCK_ON:
	case CAPSLOCK_OFF:
		state = (op == CAPSLOCK_ON);
		kr = IOHIDSetModifierLockState(ioc, kIOHIDCapsLockState, state);
		if (kr != KERN_SUCCESS)
		{
			IOServiceClose(ioc);
			fprintf(stderr, "IOHIDSetModifierLockState() failed: %x\n", kr);
			return (int) kr;
		}
		break;
   case CAPSLOCK_TOGGLE:
		kr = IOHIDGetModifierLockState(ioc, kIOHIDCapsLockState, &state);
		if (kr != KERN_SUCCESS)
		{
			IOServiceClose(ioc);
			fprintf(stderr, "IOHIDGetModifierLockState() failed: %x\n", kr);
			return (int) kr;
		}
		state = !state;
		kr = IOHIDSetModifierLockState(ioc, kIOHIDCapsLockState, state);
		if (kr != KERN_SUCCESS)
		{
			IOServiceClose(ioc);
			fprintf(stderr, "IOHIDSetModifierLockState() failed: %x\n", kr);
			return (int) kr;
		}
		break;
   case CAPSLOCK_QUERY:
		kr = IOHIDGetModifierLockState(ioc, kIOHIDCapsLockState, &state);
		if (kr != KERN_SUCCESS)
		{
			IOServiceClose(ioc);
			//fprintf(stderr, "IOHIDGetModifierLockState() failed: %x\n", kr);
			return (int) kr;
		}
		break;
	}

	IOServiceClose(ioc);
	return (bool) state;
}

// hs.hid.capslock.get() -> bool
// Function
// Checks the state of the caps lock via HID
static int hid_capslock_query(lua_State* L) {
	bool state = access_capslock(CAPSLOCK_QUERY);
	lua_pushboolean(L, state);
	return 1;
}

// hs.hid.capslock.toggle() -> bool
// Function
// Toggles the state of caps lock via HID
static int hid_capslock_toggle(lua_State* L) {
	bool state = access_capslock(CAPSLOCK_TOGGLE);
	lua_pushboolean(L, state);
	return 1;
}

// hs.hid.capslock.set(true) -> bool
// Function
// Assigns capslock to the desired state
static int hid_capslock_on(lua_State* L) {
	bool state = access_capslock(CAPSLOCK_ON);
	lua_pushboolean(L, state);
	return 1;
}

// hs.hid.capslock.set(false) -> bool
// Function
// Assigns capslock to the desired state
static int hid_capslock_off(lua_State* L) {
	bool state = access_capslock(CAPSLOCK_OFF);
	lua_pushboolean(L, state);
	return 1;
}


static const luaL_Reg hid_lib[] = {
    {"_capslock_query", hid_capslock_query},
    {"_capslock_toggle", hid_capslock_toggle},
    {"_capslock_on", hid_capslock_on},
    {"_capslock_off", hid_capslock_off},
    {NULL,      NULL}
};

int luaopen_hs_hid_internal(lua_State* L __unused) {
    LuaSkin *skin = [LuaSkin shared];
    [skin registerLibrary:hid_lib metaFunctions:nil];

    return 1;
}
