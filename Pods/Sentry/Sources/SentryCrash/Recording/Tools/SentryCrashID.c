// Adapted from: https://github.com/kstenerud/KSCrash
//
//  SentryCrashID.c
//
//  Copyright (c) 2016 Karl Stenerud. All rights reserved.
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

#include <stdio.h>
#include <uuid/uuid.h>

void
sentrycrashid_generate(char *destinationBuffer37Bytes)
{
    uuid_t uuid;
    uuid_generate(uuid);
    snprintf(destinationBuffer37Bytes, 37,
        "%02X%02X%02X%02X-%02X%02X-%02X%02X-%02X%02X-%02X%02X%02X%02X%02X%02X", (unsigned)uuid[0],
        (unsigned)uuid[1], (unsigned)uuid[2], (unsigned)uuid[3], (unsigned)uuid[4],
        (unsigned)uuid[5], (unsigned)uuid[6], (unsigned)uuid[7], (unsigned)uuid[8],
        (unsigned)uuid[9], (unsigned)uuid[10], (unsigned)uuid[11], (unsigned)uuid[12],
        (unsigned)uuid[13], (unsigned)uuid[14], (unsigned)uuid[15]);
}
