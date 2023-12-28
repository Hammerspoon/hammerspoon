// Adapted from: https://github.com/kstenerud/KSCrash
//
//  SentryCrashString.m
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

#include "SentryCrashString.h"
#include "SentryCrashSystemCapabilities.h"
#include <stdlib.h>
#include <string.h>

// Compiler hints for "if" statements
#define likely_if(x) if (__builtin_expect(x, 1))
#define unlikely_if(x) if (__builtin_expect(x, 0))

static const int g_printableControlChars[0x20] = {
    // Only tab, CR, and LF are considered printable
    // 1  2  3  4  5  6  7  8  9  a  b  c  d  e  f
    0,
    0,
    0,
    0,
    0,
    0,
    0,
    0,
    0,
    1,
    1,
    0,
    0,
    1,
    0,
    0,
    0,
    0,
    0,
    0,
    0,
    0,
    0,
    0,
    0,
    0,
    0,
    0,
    0,
    0,
    0,
    0,
};

static const int g_continuationByteCount[0x40] = {
    /*
     --0xxxxx = 1 (00-1f)
     --10xxxx = 2 (20-2f)
     --110xxx = 3 (30-37)
     --1110xx = 4 (38-3b)
     --11110x = 5 (3c-3d)
     */
    // 1  2  3  4  5  6  7  8  9  a  b  c  d  e  f
    1,
    1,
    1,
    1,
    1,
    1,
    1,
    1,
    1,
    1,
    1,
    1,
    1,
    1,
    1,
    1,
    1,
    1,
    1,
    1,
    1,
    1,
    1,
    1,
    1,
    1,
    1,
    1,
    1,
    1,
    1,
    1,
    2,
    2,
    2,
    2,
    2,
    2,
    2,
    2,
    2,
    2,
    2,
    2,
    2,
    2,
    2,
    2,
    3,
    3,
    3,
    3,
    3,
    3,
    3,
    3,
    4,
    4,
    4,
    4,
    5,
    5,
    0,
    0,
};

bool
sentrycrashstring_isNullTerminatedUTF8String(const void *memory, int minLength, int maxLength)
{
    const unsigned char *ptr = memory;
    const unsigned char *const end = ptr + maxLength;

    for (; ptr < end; ptr++) {
        unsigned char ch = *ptr;
        unlikely_if(ch == 0) { return (ptr - (const unsigned char *)memory) >= minLength; }
        unlikely_if(ch & 0x80)
        {
            unlikely_if((ch & 0xc0) != 0xc0) { return false; }
            int continuationBytes = g_continuationByteCount[ch & 0x3f];
            unlikely_if(continuationBytes == 0 || ptr + continuationBytes >= end) { return false; }
            for (int i = 0; i < continuationBytes; i++) {
                ptr++;
                unlikely_if((*ptr & 0xc0) != 0x80) { return false; }
            }
        }
        else unlikely_if(ch < 0x20 && !g_printableControlChars[ch])
        {
            return false;
        }
    }
    return false;
}

#define INV 0xff

/** Lookup table for converting hex values to integers.
 * INV (0x11111) is used to mark invalid characters so that any attempted
 * invalid nybble conversion is always > 0xffff.
 */
static const unsigned int g_hexConversion[] = {
    INV,
    INV,
    INV,
    INV,
    INV,
    INV,
    INV,
    INV,
    INV,
    INV,
    INV,
    INV,
    INV,
    INV,
    INV,
    INV,
    INV,
    INV,
    INV,
    INV,
    INV,
    INV,
    INV,
    INV,
    INV,
    INV,
    INV,
    INV,
    INV,
    INV,
    INV,
    INV,
    INV,
    INV,
    INV,
    INV,
    INV,
    INV,
    INV,
    INV,
    INV,
    INV,
    INV,
    INV,
    INV,
    INV,
    INV,
    INV,
    0x0,
    0x1,
    0x2,
    0x3,
    0x4,
    0x5,
    0x6,
    0x7,
    0x8,
    0x9,
    INV,
    INV,
    INV,
    INV,
    INV,
    INV,
    INV,
    0xa,
    0xb,
    0xc,
    0xd,
    0xe,
    0xf,
    INV,
    INV,
    INV,
    INV,
    INV,
    INV,
    INV,
    INV,
    INV,
    INV,
    INV,
    INV,
    INV,
    INV,
    INV,
    INV,
    INV,
    INV,
    INV,
    INV,
    INV,
    INV,
    INV,
    INV,
    INV,
    INV,
    0xa,
    0xb,
    0xc,
    0xd,
    0xe,
    0xf,
    INV,
    INV,
    INV,
    INV,
    INV,
    INV,
    INV,
    INV,
    INV,
    INV,
    INV,
    INV,
    INV,
    INV,
    INV,
    INV,
    INV,
    INV,
    INV,
    INV,
    INV,
    INV,
    INV,
    INV,
    INV,
    INV,
    INV,
    INV,
    INV,
    INV,
    INV,
    INV,
    INV,
    INV,
    INV,
    INV,
    INV,
    INV,
    INV,
    INV,
    INV,
    INV,
    INV,
    INV,
    INV,
    INV,
    INV,
    INV,
    INV,
    INV,
    INV,
    INV,
    INV,
    INV,
    INV,
    INV,
    INV,
    INV,
    INV,
    INV,
    INV,
    INV,
    INV,
    INV,
    INV,
    INV,
    INV,
    INV,
    INV,
    INV,
    INV,
    INV,
    INV,
    INV,
    INV,
    INV,
    INV,
    INV,
    INV,
    INV,
    INV,
    INV,
    INV,
    INV,
    INV,
    INV,
    INV,
    INV,
    INV,
    INV,
    INV,
    INV,
    INV,
    INV,
    INV,
    INV,
    INV,
    INV,
    INV,
    INV,
    INV,
    INV,
    INV,
    INV,
    INV,
    INV,
    INV,
    INV,
    INV,
    INV,
    INV,
    INV,
    INV,
    INV,
    INV,
    INV,
    INV,
    INV,
    INV,
    INV,
    INV,
    INV,
    INV,
    INV,
    INV,
    INV,
    INV,
    INV,
    INV,
    INV,
    INV,
    INV,
    INV,
    INV,
    INV,
    INV,
    INV,
    INV,
    INV,
    INV,
    INV,
    INV,
    INV,
    INV,
    INV,
    INV,
    INV,
    INV,
    INV,
    INV,
    INV,
    INV,
    INV,
};

bool
sentrycrashstring_extractHexValue(const char *string, int stringLength, uint64_t *const result)
{
    if (stringLength > 0) {
        const unsigned char *current = (const unsigned char *)string;
        const unsigned char *const end = current + stringLength;
        for (;;) {
#if SentryCrashCRASH_HAS_STRNSTR
            current = (const unsigned char *)strnstr(
                (const char *)current, "0x", (unsigned)(end - current));
#else
            current = (const unsigned char *)strstr((const char *)current, "0x");
            unlikely_if(current >= end) { return false; }
#endif
            unlikely_if(!current) { return false; }
            current += 2;

            // Must have at least one valid digit after "0x".
            unlikely_if(g_hexConversion[*current] == INV) { continue; }

            uint64_t accum = 0;
            unsigned int nybble = 0;
            while (current < end) {
                nybble = g_hexConversion[*current++];
                unlikely_if(nybble == INV) { break; }
                accum <<= 4;
                accum += nybble;
            }
            *result = accum;
            return true;
        }
    }
    return false;
}
