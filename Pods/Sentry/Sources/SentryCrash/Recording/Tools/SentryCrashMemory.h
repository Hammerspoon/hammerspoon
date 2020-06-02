//
//  SentryCrashMemory.h
//
//  Created by Karl Stenerud on 2012-01-29.
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


/* Utility functions for querying the mach kernel.
 */


#ifndef HDR_sentrycrashmemory_h
#define HDR_sentrycrashmemory_h

#ifdef __cplusplus
extern "C" {
#endif


#include <stdbool.h>


/** Test if the specified memory is safe to read from.
 *
 * @param memory A pointer to the memory to test.
 * @param byteCount The number of bytes to test.
 *
 * @return True if the memory can be safely read.
 */
bool sentrycrashmem_isMemoryReadable(const void* const memory, const int byteCount);

/** Test how much memory is readable from the specified pointer.
 *
 * @param memory A pointer to the memory to test.
 * @param tryByteCount The number of bytes to test.
 *
 * @return The number of bytes that are readable from that address.
 */
int sentrycrashmem_maxReadableBytes(const void* const memory, const int tryByteCount);

/** Copy memory safely. If the memory is not accessible, returns false
 * rather than crashing.
 *
 * @param src The source location to copy from.
 *
 * @param dst The location to copy to.
 *
 * @param byteCount The number of bytes to copy.
 *
 * @return true if successful.
 */
bool sentrycrashmem_copySafely(const void* restrict const src, void* restrict const dst, int byteCount);

/** Copies up to numBytes of data from src to dest, stopping if memory
 * becomes inaccessible.
 *
 * @param src The source location to copy from.
 *
 * @param dst The location to copy to.
 *
 * @param byteCount The number of bytes to copy.
 *
 * @return The number of bytes actually copied.
 */
int sentrycrashmem_copyMaxPossible(const void* restrict const src, void* restrict const dst, int byteCount);

#ifdef __cplusplus
}
#endif

#endif // HDR_sentrycrashmemory_h
