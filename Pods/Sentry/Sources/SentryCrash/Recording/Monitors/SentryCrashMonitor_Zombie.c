//
//  SentryCrashZombie.m
//
//  Created by Karl Stenerud on 2012-09-15.
//
//  Copyright (c) 2012 Karl Stenerud. All rights reserved.
//
// Permission is hereby granted, free of charge, to any person obtaining a copy
// of this software and associated documentation files (the "Software"), to deal
// in the Software without restriction, including without limitation the rights
// to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
// copies of the Software, and to permit persons to whom the Software is
// furnished to do so, subject to the following conditions:
//
// The above copyright notice and this permission notice shall remain in place
// in this source code.
//
// THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
// IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
// FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
// AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
// LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
// OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
// THE SOFTWARE.
//


#include "SentryCrashMonitor_Zombie.h"
#include "SentryCrashMonitorContext.h"
#include "SentryCrashObjC.h"
#include "SentryCrashLogger.h"

#include <objc/runtime.h>
#include <stdlib.h>


#define CACHE_SIZE 0x8000

// Compiler hints for "if" statements
#define likely_if(x) if(__builtin_expect(x,1))
#define unlikely_if(x) if(__builtin_expect(x,0))


typedef struct
{
    const void* object;
    const char* className;
} Zombie;

static volatile Zombie* g_zombieCache;
static unsigned g_zombieHashMask;

static volatile bool g_isEnabled = false;

static struct
{
    Class class;
    const void* address;
    char name[100];
    char reason[900];
} g_lastDeallocedException;

static inline unsigned hashIndex(const void* object)
{
    uintptr_t objPtr = (uintptr_t)object;
    objPtr >>= (sizeof(object)-1);
    return objPtr & g_zombieHashMask;
}

static bool copyStringIvar(const void* self, const char* ivarName, char* buffer, int bufferLength)
{
    Class class = object_getClass((id)self);
    SentryCrashObjCIvar ivar = {0};
    likely_if(sentrycrashobjc_ivarNamed(class, ivarName, &ivar))
    {
        void* pointer;
        likely_if(sentrycrashobjc_ivarValue(self, ivar.index, &pointer))
        {
            likely_if(sentrycrashobjc_isValidObject(pointer))
            {
                likely_if(sentrycrashobjc_copyStringContents(pointer, buffer, bufferLength) > 0)
                {
                    return true;
                }
                else
                {
                    SentryCrashLOG_DEBUG("sentrycrashobjc_copyStringContents %s failed", ivarName);
                }
            }
            else
            {
                SentryCrashLOG_DEBUG("sentrycrashobjc_isValidObject %s failed", ivarName);
            }
        }
        else
        {
            SentryCrashLOG_DEBUG("sentrycrashobjc_ivarValue %s failed", ivarName);
        }
    }
    else
    {
        SentryCrashLOG_DEBUG("sentrycrashobjc_ivarNamed %s failed", ivarName);
    }
    return false;
}

static void storeException(const void* exception)
{
    g_lastDeallocedException.address = exception;
    copyStringIvar(exception, "name", g_lastDeallocedException.name, sizeof(g_lastDeallocedException.name));
    copyStringIvar(exception, "reason", g_lastDeallocedException.reason, sizeof(g_lastDeallocedException.reason));
}

static inline void handleDealloc(const void* self)
{
    volatile Zombie* cache = g_zombieCache;
    likely_if(cache != NULL)
    {
        Zombie* zombie = (Zombie*)cache + hashIndex(self);
        zombie->object = self;
        Class class = object_getClass((id)self);
        zombie->className = class_getName(class);
        for(; class != nil; class = class_getSuperclass(class))
        {
            unlikely_if(class == g_lastDeallocedException.class)
            {
                storeException(self);
            }
        }
    }
}

#define CREATE_ZOMBIE_HANDLER_INSTALLER(CLASS) \
static IMP g_originalDealloc_ ## CLASS; \
static void handleDealloc_ ## CLASS(id self, SEL _cmd) \
{ \
    handleDealloc(self); \
    typedef void (*fn)(id,SEL); \
    fn f = (fn)g_originalDealloc_ ## CLASS; \
    f(self, _cmd); \
} \
static void installDealloc_ ## CLASS() \
{ \
    Method method = class_getInstanceMethod(objc_getClass(#CLASS), sel_registerName("dealloc")); \
    g_originalDealloc_ ## CLASS = method_getImplementation(method); \
    method_setImplementation(method, (IMP)handleDealloc_ ## CLASS); \
}
// TODO: Uninstall doesn't work.
//static void uninstallDealloc_ ## CLASS() \
//{ \
//    method_setImplementation(class_getInstanceMethod(objc_getClass(#CLASS), sel_registerName("dealloc")), g_originalDealloc_ ## CLASS); \
//}

CREATE_ZOMBIE_HANDLER_INSTALLER(NSObject)
CREATE_ZOMBIE_HANDLER_INSTALLER(NSProxy)

static void install()
{
    unsigned cacheSize = CACHE_SIZE;
    g_zombieHashMask = cacheSize - 1;
    g_zombieCache = calloc(cacheSize, sizeof(*g_zombieCache));
    if(g_zombieCache == NULL)
    {
        SentryCrashLOG_ERROR("Error: Could not allocate %u bytes of memory. SentryCrashZombie NOT installed!",
              cacheSize * sizeof(*g_zombieCache));
        return;
    }

    g_lastDeallocedException.class = objc_getClass("NSException");
    g_lastDeallocedException.address = NULL;
    g_lastDeallocedException.name[0] = 0;
    g_lastDeallocedException.reason[0] = 0;

    installDealloc_NSObject();
    installDealloc_NSProxy();
}

// TODO: Uninstall doesn't work.
//static void uninstall(void)
//{
//    uninstallDealloc_NSObject();
//    uninstallDealloc_NSProxy();
//
//    void* ptr = (void*)g_zombieCache;
//    g_zombieCache = NULL;
//    dispatch_time_t tenSeconds = dispatch_time(DISPATCH_TIME_NOW, (int64_t)(10.0 * NSEC_PER_SEC));
//    dispatch_after(tenSeconds, dispatch_get_main_queue(), ^
//    {
//        free(ptr);
//    });
//}

const char* sentrycrashzombie_className(const void* object)
{
    volatile Zombie* cache = g_zombieCache;
    if(cache == NULL || object == NULL)
    {
        return NULL;
    }

    Zombie* zombie = (Zombie*)cache + hashIndex(object);
    if(zombie->object == object)
    {
        return zombie->className;
    }
    return NULL;
}

static void setEnabled(bool isEnabled)
{
    if(isEnabled != g_isEnabled)
    {
        g_isEnabled = isEnabled;
        if(isEnabled)
        {
            install();
        }
        else
        {
            // TODO: Uninstall doesn't work.
            g_isEnabled = true;
//            uninstall();
        }
    }
}

static bool isEnabled()
{
    return g_isEnabled;
}

static void addContextualInfoToEvent(SentryCrash_MonitorContext* eventContext)
{
    if(g_isEnabled)
    {
        eventContext->ZombieException.address = (uintptr_t)g_lastDeallocedException.address;
        eventContext->ZombieException.name = g_lastDeallocedException.name;
        eventContext->ZombieException.reason = g_lastDeallocedException.reason;
    }
}

SentryCrashMonitorAPI* sentrycrashcm_zombie_getAPI()
{
    static SentryCrashMonitorAPI api =
    {
        .setEnabled = setEnabled,
        .isEnabled = isEnabled,
        .addContextualInfoToEvent = addContextualInfoToEvent
    };
    return &api;
}
