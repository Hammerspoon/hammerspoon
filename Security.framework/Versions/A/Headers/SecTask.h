/*
 * Copyright (c) 2008-2009,2011 Apple Inc. All Rights Reserved.
 * 
 * @APPLE_LICENSE_HEADER_START@
 * 
 * This file contains Original Code and/or Modifications of Original Code
 * as defined in and that are subject to the Apple Public Source License
 * Version 2.0 (the 'License'). You may not use this file except in
 * compliance with the License. Please obtain a copy of the License at
 * http://www.opensource.apple.com/apsl/ and read it before using this
 * file.
 * 
 * The Original Code and all software distributed under the License are
 * distributed on an 'AS IS' basis, WITHOUT WARRANTY OF ANY KIND, EITHER
 * EXPRESS OR IMPLIED, AND APPLE HEREBY DISCLAIMS ALL SUCH WARRANTIES,
 * INCLUDING WITHOUT LIMITATION, ANY WARRANTIES OF MERCHANTABILITY,
 * FITNESS FOR A PARTICULAR PURPOSE, QUIET ENJOYMENT OR NON-INFRINGEMENT.
 * Please see the License for the specific language governing rights and
 * limitations under the License.
 * 
 * @APPLE_LICENSE_HEADER_END@
 */

#ifndef _SECURITY_SECTASK_H_
#define _SECURITY_SECTASK_H_

#include <CoreFoundation/CoreFoundation.h>
#include <mach/message.h>
#include <Security/SecCode.h>

#if defined(__cplusplus)
extern "C" {
#endif

CF_ASSUME_NONNULL_BEGIN
CF_IMPLICIT_BRIDGING_ENABLED

/*!
    @typedef SecTaskRef
    @abstract CFType used for representing a task
*/
typedef struct CF_BRIDGED_TYPE(id) __SecTask *SecTaskRef;

/*!
    @function SecTaskGetTypeID
    @abstract Returns the type ID for CF instances of SecTask.
    @result A CFTypeID for SecTask
*/
CFTypeID SecTaskGetTypeID(void);

/*!
    @function SecTaskCreateWithAuditToken
    @abstract Create a SecTask object for the task that sent the mach message
    represented by the audit token.
    @param token The audit token of a mach message
    @result The newly created SecTask object or NULL on error.  The caller must
    CFRelease the returned object.
*/
__nullable
SecTaskRef SecTaskCreateWithAuditToken(CFAllocatorRef __nullable allocator, audit_token_t token);

/*!
    @function SecTaskCreateFromSelf
    @abstract Create a SecTask object for the current task.
    @result The newly created SecTask object or NULL on error.  The caller must
    CFRelease the returned object.
*/
__nullable
SecTaskRef SecTaskCreateFromSelf(CFAllocatorRef __nullable allocator);

/*!
    @function SecTaskCopyValueForEntitlement
    @abstract Returns the value of a single entitlement for the represented 
    task.
    @param task A previously created SecTask object
    @param entitlement The name of the entitlement to be fetched
    @param error On a NULL return, this may be contain a CFError describing
    the problem.  This argument may be NULL if the caller is not interested in
    detailed errors.
    @result The value of the specified entitlement for the process or NULL if
    the entitlement value could not be retrieved.  The type of the returned
    value will depend on the entitlement specified.  The caller must release
    the returned object.
    @discussion A NULL return may indicate an error, or it may indicate that
    the entitlement is simply not present.  In the latter case, no CFError is
    returned.
*/
__nullable
CFTypeRef SecTaskCopyValueForEntitlement(SecTaskRef task, CFStringRef entitlement, CFErrorRef *error);

/*!
    @function SecTaskCopyValuesForEntitlements
    @abstract Returns the values of multiple entitlements for the represented 
    task.
    @param task A previously created SecTask object
    @param entitlements An array of entitlement names to be fetched
    @param error On a NULL return, this will contain a CFError describing
    the problem.  This argument may be NULL if the caller is not interested in
    detailed errors.  If a requested entitlement is not present for the 
    returned dictionary, the entitlement is not set on the task.  The caller
    must CFRelease the returned value
*/
__nullable
CFDictionaryRef SecTaskCopyValuesForEntitlements(SecTaskRef task, CFArrayRef entitlements, CFErrorRef *error);


   
/*!
    @function SecTaskCopySigningIdentifier
    @abstract Return the value of the codesigning identifier.
    @param task A previously created SecTask object
    @param error On a NULL return, this will contain a CFError describing
    the problem.  This argument may be NULL if the caller is not interested in
    detailed errors. The caller must CFRelease the returned value.
 */

__nullable
CFStringRef
SecTaskCopySigningIdentifier(SecTaskRef task, CFErrorRef *error);

CF_IMPLICIT_BRIDGING_DISABLED
CF_ASSUME_NONNULL_END

#if defined(__cplusplus)
}
#endif

#endif /* !_SECURITY_SECTASK_H_ */
