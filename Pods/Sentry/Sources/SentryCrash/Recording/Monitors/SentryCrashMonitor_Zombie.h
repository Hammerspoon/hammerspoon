//
//  SentryCrashMonitor_Zombie.h
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


/* Poor man's zombie tracking.
 *
 * Benefits:
 * - Very low CPU overhead.
 * - Low memory overhead.
 *
 * Limitations:
 * - Not guaranteed to catch all zombies.
 * - Can generate false positives or incorrect class names.
 * - SentryCrashZombie itself must be compiled with ARC disabled. You can enable ARC in
 *   your app, but SentryCrashZombie must be compiled in a separate library if you do.
 */

#ifndef HDR_SentryCrashZombie_h
#define HDR_SentryCrashZombie_h

#ifdef __cplusplus
extern "C" {
#endif

#include "SentryCrashMonitor.h"
#include <stdbool.h>


/** Get the class of a deallocated object pointer, if it was tracked.
 *
 * @param object A pointer to a deallocated object.
 *
 * @return The object's class name, or NULL if it wasn't found.
 */
const char* sentrycrashzombie_className(const void* object);

/** Access the Monitor API.
 */
SentryCrashMonitorAPI* sentrycrashcm_zombie_getAPI(void);


#ifdef __cplusplus
}
#endif

#endif // HDR_SentryCrashZombie_h
