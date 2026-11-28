/*
 * Copyright (C) 2020 Apple Inc. All rights reserved.
 *
 * Redistribution and use in source and binary forms, with or without
 * modification, are permitted provided that the following conditions
 * are met:
 * 1. Redistributions of source code must retain the above copyright
 *    notice, this list of conditions and the following disclaimer.
 * 2. Redistributions in binary form must reproduce the above copyright
 *    notice, this list of conditions and the following disclaimer in the
 *    documentation and/or other materials provided with the distribution.
 *
 * THIS SOFTWARE IS PROVIDED BY APPLE INC. AND ITS CONTRIBUTORS ``AS IS''
 * AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO,
 * THE IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR
 * PURPOSE ARE DISCLAIMED. IN NO EVENT SHALL APPLE INC. OR ITS CONTRIBUTORS
 * BE LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR
 * CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF
 * SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS
 * INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN
 * CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE)
 * ARISING IN ANY WAY OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF
 * THE POSSIBILITY OF SUCH DAMAGE.
 */

#ifndef _IOHIDEVENT_H
#define _IOHIDEVENT_H

#include "IOHIDEventTypes.h"

typedef struct __IOHIDEvent * IOHIDEventRef;

IOHIDEventRef _Nullable CGEventCopyIOHIDEvent(CGEventRef _Nonnull);

CFDataRef _Nullable IOHIDEventCreateData(CFAllocatorRef _Nullable, IOHIDEventRef _Nonnull);
IOHIDEventRef _Nullable IOHIDEventCreateWithData(CFAllocatorRef _Nullable, CFDataRef _Nonnull);
CFStringRef _Nullable IOHIDEventCopyDescription(IOHIDEventRef _Nonnull event);
IOHIDEventType IOHIDEventGetType(IOHIDEventRef _Nonnull event);
uint32_t IOHIDEventGetEventFlags(IOHIDEventRef _Nonnull event);
void IOHIDEventSetEventFlags(IOHIDEventRef _Nonnull event, uint32_t flags);
CFIndex IOHIDEventGetIntegerValue(IOHIDEventRef _Nonnull, IOHIDEventField);
void IOHIDEventSetIntegerValue(IOHIDEventRef _Nonnull, IOHIDEventField, CFIndex);
IOHIDFloat IOHIDEventGetFloatValue(IOHIDEventRef _Nonnull, IOHIDEventField);
void IOHIDEventSetFloatValue(IOHIDEventRef _Nonnull, IOHIDEventField, IOHIDFloat);
CFArrayRef _Nullable IOHIDEventGetChildren(IOHIDEventRef _Nonnull);
void IOHIDEventAppendEvent(IOHIDEventRef _Nonnull, IOHIDEventRef _Nonnull, IOOptionBits);
void IOHIDEventRemoveEvent(IOHIDEventRef _Nonnull, IOHIDEventRef _Nonnull, IOOptionBits);


#endif
