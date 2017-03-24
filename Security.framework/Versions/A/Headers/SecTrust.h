/*
 * Copyright (c) 2002-2016 Apple Inc. All Rights Reserved.
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

/*!
    @header SecTrust
    The functions and data types in SecTrust implement trust computation
    and allow the caller to apply trust decisions to the evaluation.
 */

#ifndef _SECURITY_SECTRUST_H_
#define _SECURITY_SECTRUST_H_

#include <Security/SecBase.h>
#include <CoreFoundation/CoreFoundation.h>
#include <AvailabilityMacros.h>

__BEGIN_DECLS

CF_ASSUME_NONNULL_BEGIN
CF_IMPLICIT_BRIDGING_ENABLED

/*!
    @typedef SecTrustResultType
    @abstract Specifies the trust result type.
    @discussion SecTrustResultType results have two dimensions.  They specify
    both whether evaluation suceeded and whether this is because of a user
    decision.  The commonly expected result is kSecTrustResultUnspecified,
    which indicates a positive result that wasn't decided by the user.  The
    common failure is kSecTrustResultRecoverableTrustFailure, which means a
    negative result.  kSecTrustResultProceed and kSecTrustResultDeny are the
    positive and negative result respectively when decided by the user.  User
    decisions are persisted through the use of SecTrustCopyExceptions() and
    SecTrustSetExceptions().  Finally, kSecTrustResultFatalTrustFailure is a
    negative result that must not be circumvented.
    @constant kSecTrustResultInvalid Indicates an invalid setting or result.
    This result usually means that SecTrustEvaluate has not yet been called.
    @constant kSecTrustResultProceed Indicates you may proceed.  This value
    may be returned by the SecTrustEvaluate function or stored as part of
    the user trust settings.
    @constant kSecTrustResultConfirm Indicates confirmation with the user
    is required before proceeding.  Important: this value is no longer returned
    or supported by SecTrustEvaluate or the SecTrustSettings API starting in
    OS X 10.5; its use is deprecated in OS X 10.9 and later, as well as in iOS.
    @constant kSecTrustResultDeny Indicates a user-configured deny; do not
    proceed. This value may be returned by the SecTrustEvaluate function
    or stored as part of the user trust settings.
    @constant kSecTrustResultUnspecified Indicates the evaluation succeeded
    and the certificate is implicitly trusted, but user intent was not
    explicitly specified.  This value may be returned by the SecTrustEvaluate
    function or stored as part of the user trust settings.
    @constant kSecTrustResultRecoverableTrustFailure Indicates a trust policy
    failure which can be overridden by the user.  This value may be returned
    by the SecTrustEvaluate function but not stored as part of the user
    trust settings.
    @constant kSecTrustResultFatalTrustFailure Indicates a trust failure
    which cannot be overridden by the user.  This value may be returned by the
    SecTrustEvaluate function but not stored as part of the user trust
    settings.
    @constant kSecTrustResultOtherError Indicates a failure other than that
    of trust evaluation. This value may be returned by the SecTrustEvaluate
    function but not stored as part of the user trust settings.
 */
typedef CF_ENUM(uint32_t, SecTrustResultType) {
    kSecTrustResultInvalid  CF_ENUM_AVAILABLE(10_3, 2_0) = 0,
    kSecTrustResultProceed  CF_ENUM_AVAILABLE(10_3, 2_0) = 1,
    kSecTrustResultConfirm  CF_ENUM_DEPRECATED(10_3, 10_9, 2_0, 7_0) = 2,
    kSecTrustResultDeny  CF_ENUM_AVAILABLE(10_3, 2_0) = 3,
    kSecTrustResultUnspecified  CF_ENUM_AVAILABLE(10_3, 2_0) = 4,
    kSecTrustResultRecoverableTrustFailure  CF_ENUM_AVAILABLE(10_3, 2_0) = 5,
    kSecTrustResultFatalTrustFailure  CF_ENUM_AVAILABLE(10_3, 2_0) = 6,
    kSecTrustResultOtherError  CF_ENUM_AVAILABLE(10_3, 2_0) = 7
};

/*!
    @typedef SecTrustRef
    @abstract CFType used for performing X.509 certificate trust evaluations.
 */
typedef struct CF_BRIDGED_TYPE(id) __SecTrust *SecTrustRef;

/*!
    @enum Trust Property Constants
    @discussion Predefined key constants used to obtain values in a
        per-certificate dictionary of trust evaluation results,
        as retrieved from a call to SecTrustCopyProperties.
    @constant kSecPropertyTypeTitle Specifies a key whose value is a
        CFStringRef containing the title (display name) of this certificate.
    @constant kSecPropertyTypeError Specifies a key whose value is a
        CFStringRef containing the reason for a trust evaluation failure.
 */
extern const CFStringRef kSecPropertyTypeTitle
    __OSX_AVAILABLE_STARTING(__MAC_10_7, __IPHONE_7_0);
extern const CFStringRef kSecPropertyTypeError
    __OSX_AVAILABLE_STARTING(__MAC_10_7, __IPHONE_7_0);

/*!
    @enum Trust Result Constants
    @discussion Predefined key constants used to obtain values in a
        dictionary of trust evaluation results for a certificate chain,
        as retrieved from a call to SecTrustCopyResult.
    @constant kSecTrustEvaluationDate
        This key will be present if a trust evaluation has been performed
        and results are available. Its value is a CFDateRef representing
        when the evaluation for this trust object took place.
    @constant kSecTrustExtendedValidation
        This key will be present and have a value of kCFBooleanTrue
        if this chain was validated for EV.
    @constant kSecTrustOrganizationName
        Organization name field of subject of leaf certificate. This
        field is meant to be displayed to the user as the validated
        name of the company or entity that owns the certificate if the
        kSecTrustExtendedValidation key is present.
    @constant kSecTrustResultValue
        This key will be present if a trust evaluation has been performed.
        Its value is a CFNumberRef representing the SecTrustResultType result
        for the evaluation.
    @constant kSecTrustRevocationChecked
        This key will be present iff this chain had its revocation checked.
        The value will be a kCFBooleanTrue if revocation checking was
        successful and none of the certificates in the chain were revoked.
        The value will be kCFBooleanFalse if no current revocation status
        could be obtained for one or more certificates in the chain due
        to connection problems or timeouts.  This is a hint to a client
        to retry revocation checking at a later time.
    @constant kSecTrustRevocationValidUntilDate
        This key will be present iff kSecTrustRevocationChecked has a
        value of kCFBooleanTrue. The value will be a CFDateRef representing
        the earliest date at which the revocation info for one of the
        certificates in this chain might change.
    @constant kSecTrustCertificateTransparency
        This key will be present and have a value of kCFBooleanTrue
        if this chain is CT qualified.
    @constant kSecTrustCertificateTransparencyWhiteList
        This key will be present and have a value of kCFBooleanTrue
        if this chain is EV, not CT qualified, but included of the CT WhiteList.
 */
extern const CFStringRef kSecTrustEvaluationDate
    __OSX_AVAILABLE_STARTING(__MAC_10_9, __IPHONE_7_0);
extern const CFStringRef kSecTrustExtendedValidation
    __OSX_AVAILABLE_STARTING(__MAC_10_9, __IPHONE_7_0);
extern const CFStringRef kSecTrustOrganizationName
    __OSX_AVAILABLE_STARTING(__MAC_10_9, __IPHONE_7_0);
extern const CFStringRef kSecTrustResultValue
    __OSX_AVAILABLE_STARTING(__MAC_10_9, __IPHONE_7_0);
extern const CFStringRef kSecTrustRevocationChecked
    __OSX_AVAILABLE_STARTING(__MAC_10_9, __IPHONE_7_0);
extern const CFStringRef kSecTrustRevocationValidUntilDate
    __OSX_AVAILABLE_STARTING(__MAC_10_9, __IPHONE_7_0);
extern const CFStringRef kSecTrustCertificateTransparency
    __OSX_AVAILABLE_STARTING(__MAC_10_11, __IPHONE_9_0);
extern const CFStringRef kSecTrustCertificateTransparencyWhiteList
    __OSX_AVAILABLE_STARTING(__MAC_10_12, __IPHONE_10_0);

#ifdef __BLOCKS__
/*!
    @typedef SecTrustCallback
    @abstract Delivers the result from an asynchronous trust evaluation.
    @param trustRef A reference to the trust object which has been evaluated.
    @param trustResult The trust result of the evaluation. Additional status
    information can be obtained by calling SecTrustCopyProperties().
 */
typedef void (^SecTrustCallback)(SecTrustRef trustRef, SecTrustResultType trustResult);
#endif /* __BLOCKS__ */


/*!
    @function SecTrustGetTypeID
    @abstract Returns the type identifier of SecTrust instances.
    @result The CFTypeID of SecTrust instances.
 */
CFTypeID SecTrustGetTypeID(void)
    __OSX_AVAILABLE_STARTING(__MAC_10_3, __IPHONE_2_0);

/*!
    @function SecTrustCreateWithCertificates
    @abstract Creates a trust object based on the given certificates and
    policies.
    @param certificates The group of certificates to verify.  This can either
    be a CFArrayRef of SecCertificateRef objects or a single SecCertificateRef
    @param policies An array of one or more policies. You may pass a
    SecPolicyRef to represent a single policy.
    @param trust On return, a pointer to the trust management reference.
    @result A result code.  See "Security Error Codes" (SecBase.h).
    @discussion If multiple policies are passed in, all policies must verify
    for the chain to be considered valid.
 */
OSStatus SecTrustCreateWithCertificates(CFTypeRef certificates,
    CFTypeRef __nullable policies, SecTrustRef * __nonnull CF_RETURNS_RETAINED trust)
    __OSX_AVAILABLE_STARTING(__MAC_10_3, __IPHONE_2_0);

/*!
    @function SecTrustSetPolicies
    @abstract Set the policies for which trust should be verified.
    @param trust A trust reference.
    @param policies An array of one or more policies. You may pass a
    SecPolicyRef to represent a single policy.
    @result A result code. See "Security Error Codes" (SecBase.h).
    @discussion This function will invalidate the existing trust result,
    requiring a fresh evaluation for the newly-set policies.
 */
OSStatus SecTrustSetPolicies(SecTrustRef trust, CFTypeRef policies)
    __OSX_AVAILABLE_STARTING(__MAC_10_3, __IPHONE_6_0);

/*!
    @function SecTrustCopyPolicies
    @abstract Returns an array of policies used for this evaluation.
    @param trust  A reference to a trust object.
    @param policies On return, an array of policies used by this trust.
    Call the CFRelease function to release this reference.
    @result A result code. See "Security Error Codes" (SecBase.h).
 */
OSStatus SecTrustCopyPolicies(SecTrustRef trust, CFArrayRef * __nonnull CF_RETURNS_RETAINED policies)
    __OSX_AVAILABLE_STARTING(__MAC_10_3, __IPHONE_7_0);

/*!
    @function SecTrustSetNetworkFetchAllowed
    @abstract Specifies whether a trust evaluation is permitted to fetch missing
    intermediate certificates from the network.
    @param trust A trust reference.
    @param allowFetch If true, and a certificate's issuer is not present in the
    trust reference but its network location is known, the evaluation is permitted
    to attempt to download it automatically. Pass false to disable network fetch
    for this trust evaluation.
    @result A result code. See "Security Error Codes" (SecBase.h).
    @discussion By default, network fetch of missing certificates is enabled if
    the trust evaluation includes the SSL policy, otherwise it is disabled.
 */
OSStatus SecTrustSetNetworkFetchAllowed(SecTrustRef trust,
    Boolean allowFetch)
    __OSX_AVAILABLE_STARTING(__MAC_10_9, __IPHONE_7_0);

/*!
    @function SecTrustGetNetworkFetchAllowed
    @abstract Returns whether a trust evaluation is permitted to fetch missing
    intermediate certificates from the network.
    @param trust A trust reference.
    @param allowFetch On return, the boolean pointed to by this parameter is
    set to true if the evaluation is permitted to download missing certificates.
    @result A result code. See "Security Error Codes" (SecBase.h).
    @discussion By default, network fetch of missing certificates is enabled if
    the trust evaluation includes the SSL policy, otherwise it is disabled.
 */
OSStatus SecTrustGetNetworkFetchAllowed(SecTrustRef trust,
    Boolean *allowFetch)
    __OSX_AVAILABLE_STARTING(__MAC_10_9, __IPHONE_7_0);

/*!
    @function SecTrustSetAnchorCertificates
    @abstract Sets the anchor certificates for a given trust.
    @param trust A reference to a trust object.
    @param anchorCertificates An array of anchor certificates.
    @result A result code.  See "Security Error Codes" (SecBase.h).
    @discussion Calling this function without also calling
    SecTrustSetAnchorCertificatesOnly() will disable trusting any
    anchors other than the ones in anchorCertificates.
 */
OSStatus SecTrustSetAnchorCertificates(SecTrustRef trust,
    CFArrayRef anchorCertificates)
    __OSX_AVAILABLE_STARTING(__MAC_10_3, __IPHONE_2_0);

/*!
    @function SecTrustSetAnchorCertificatesOnly
    @abstract Reenables trusting anchor certificates in addition to those
    passed in via the SecTrustSetAnchorCertificates API.
    @param trust A reference to a trust object.
    @param anchorCertificatesOnly If true, disables trusting any anchors other
    than the ones passed in via SecTrustSetAnchorCertificates().  If false,
    the built in anchor certificates are also trusted.
    @result A result code.  See "Security Error Codes" (SecBase.h).
 */
OSStatus SecTrustSetAnchorCertificatesOnly(SecTrustRef trust,
    Boolean anchorCertificatesOnly)
    __OSX_AVAILABLE_STARTING(__MAC_10_6, __IPHONE_2_0);

/*!
    @function SecTrustCopyCustomAnchorCertificates
    @abstract Returns an array of custom anchor certificates used by a given
    trust, as set by a prior call to SecTrustSetAnchorCertificates, or NULL if
    no custom anchors have been specified.
    @param trust  A reference to a trust object.
    @param anchors On return, an array of custom anchor certificates (roots)
    used by this trust, or NULL if no custom anchors have been specified. Call
    the CFRelease function to release this reference.
    @result A result code. See "Security Error Codes" (SecBase.h).
 */
OSStatus SecTrustCopyCustomAnchorCertificates(SecTrustRef trust,
    CFArrayRef * __nonnull CF_RETURNS_RETAINED anchors)
    __OSX_AVAILABLE_STARTING(__MAC_10_5, __IPHONE_7_0);

/*!
    @function SecTrustSetVerifyDate
    @abstract Set the date for which the trust should be verified.
    @param trust A reference to a trust object.
    @param verifyDate The date for which to verify trust.
    @result A result code.  See "Security Error Codes" (SecBase.h).
    @discussion This function lets you evaluate certificate validity for a
    given date (for example, to determine if a signature was valid on the date
    it was signed, even if the certificate has since expired.) If this function
    is not called, the time at which SecTrustEvaluate() is called is used
    implicitly as the verification time.
 */
OSStatus SecTrustSetVerifyDate(SecTrustRef trust, CFDateRef verifyDate)
    __OSX_AVAILABLE_STARTING(__MAC_10_3, __IPHONE_2_0);

/*!
    @function SecTrustGetVerifyTime
    @abstract Returns the verify time.
    @param trust A reference to the trust object being verified.
    @result A CFAbsoluteTime value representing the time at which certificates
    should be checked for validity.
    @discussion This function retrieves the verification time for the given
    trust reference, as set by a prior call to SecTrustSetVerifyDate(). If the
    verification time has not been set, this function returns a value of 0,
    indicating that the current date/time is implicitly used for verification.
 */
CFAbsoluteTime SecTrustGetVerifyTime(SecTrustRef trust)
    __OSX_AVAILABLE_STARTING(__MAC_10_6, __IPHONE_2_0);

/*!
    @function SecTrustEvaluate
    @abstract Evaluates a trust reference synchronously.
    @param trust A reference to the trust object to evaluate.
    @param result A pointer to a result type.
    @result A result code. See "Security Error Codes" (SecBase.h).
    @discussion This function will completely evaluate trust before returning,
    possibly including network access to fetch intermediate certificates or to
    perform revocation checking. Since this function can block during those
    operations, you should call it from within a function that is placed on a
    dispatch queue, or in a separate thread from your application's main
    run loop. Alternatively, you can use the SecTrustEvaluateAsync function.
 */
OSStatus SecTrustEvaluate(SecTrustRef trust, SecTrustResultType * __nullable result)
    __OSX_AVAILABLE_STARTING(__MAC_10_3, __IPHONE_2_0);

#ifdef __BLOCKS__
/*!
    @function SecTrustEvaluateAsync
    @abstract Evaluates a trust reference asynchronously.
    @param trust A reference to the trust object to evaluate.
    @param queue A dispatch queue on which the result callback should be
    executed. Pass NULL to use the current dispatch queue.
    @param result A SecTrustCallback block which will be executed when the
    trust evaluation is complete.
    @result A result code. See "Security Error Codes" (SecBase.h).
 */
OSStatus SecTrustEvaluateAsync(SecTrustRef trust,
    dispatch_queue_t __nullable queue, SecTrustCallback result)
    __OSX_AVAILABLE_STARTING(__MAC_10_7, __IPHONE_7_0);
#endif

/*!
    @function SecTrustGetTrustResult
    @param trust A reference to a trust object.
    @param result A pointer to the result from the most recent call to
    SecTrustEvaluate for this trust reference. If SecTrustEvaluate has not been
    called or trust parameters have changed, the result is kSecTrustResultInvalid.
    @result A result code. See "Security Error Codes" (SecBase.h).
    @discussion This function replaces SecTrustGetResult for the purpose of
    obtaining the current evaluation result of a given trust reference.
 */
OSStatus SecTrustGetTrustResult(SecTrustRef trust,
    SecTrustResultType *result)
    __OSX_AVAILABLE_STARTING(__MAC_10_7, __IPHONE_7_0);

/*!
    @function SecTrustCopyPublicKey
    @abstract Return the public key for a leaf certificate after it has
    been evaluated.
    @param trust A reference to the trust object which has been evaluated.
    @result The certificate's public key, or NULL if it the public key could
    not be extracted (this can happen with DSA certificate chains if the
    parameters in the chain cannot be found).  The caller is responsible
    for calling CFRelease on the returned key when it is no longer needed.
 */
__nullable
SecKeyRef SecTrustCopyPublicKey(SecTrustRef trust)
    __OSX_AVAILABLE_STARTING(__MAC_10_7, __IPHONE_2_0);

/*!
    @function SecTrustGetCertificateCount
    @abstract Returns the number of certificates in an evaluated certificate
    chain.
    @param trust A reference to a trust object.
    @result The number of certificates in the trust chain, including the anchor.
    @discussion Important: if the trust reference has not yet been evaluated,
    this function will evaluate it first before returning. If speed is critical,
    you may want to call SecTrustGetTrustResult first to make sure that a
    result other than kSecTrustResultInvalid is present for the trust object.
 */
CFIndex SecTrustGetCertificateCount(SecTrustRef trust)
    __OSX_AVAILABLE_STARTING(__MAC_10_7, __IPHONE_2_0);

/*!
    @function SecTrustGetCertificateAtIndex
    @abstract Returns a certificate from the trust chain.
    @param trust Reference to a trust object.
    @param ix The index of the requested certificate.  Indices run from 0
    (leaf) to the anchor (or last certificate found if no anchor was found).
    The leaf cert (index 0) is always present regardless of whether the trust
    reference has been evaluated or not.
    @result A SecCertificateRef for the requested certificate.
 */
__nullable
SecCertificateRef SecTrustGetCertificateAtIndex(SecTrustRef trust, CFIndex ix)
    __OSX_AVAILABLE_STARTING(__MAC_10_7, __IPHONE_2_0);

/*!
    @function SecTrustCopyExceptions
    @abstract Returns an opaque cookie which will allow future evaluations
    of the current certificate to succeed.
    @param trust A reference to an evaluated trust object.
    @result An opaque cookie which when passed to SecTrustSetExceptions() will
    cause a call to SecTrustEvaluate() return kSecTrustResultProceed.  This
    will happen upon subsequent evaluation of the current certificate unless
    some new error starts happening that wasn't being reported when the cookie
    was returned from this function (for example, if the certificate expires
    then evaluation will start failing again until a new cookie is obtained.)
    @discussion Normally this API should only be called once the errors have
    been presented to the user and the user decided to trust the current
    certificate chain regardless of the errors being presented, for the
    current application/server/protocol combination.
 */
CFDataRef SecTrustCopyExceptions(SecTrustRef trust)
    __OSX_AVAILABLE_STARTING(__MAC_10_9, __IPHONE_4_0);

/*!
    @function SecTrustSetExceptions
    @abstract Set a trust cookie to be used for evaluating this certificate chain.
    @param trust A reference to a trust object.
    @param exceptions An exceptions cookie as returned by a call to
    SecTrustCopyExceptions() in the past.  You may pass NULL to clear any
    exceptions which have been previously set on this trust reference.
    @result Upon calling SecTrustEvaluate(), any failures that were present at the
    time the exceptions object was created are ignored, and instead of returning
    kSecTrustResultRecoverableTrustFailure, kSecTrustResultProceed will be returned
    (if the certificate for which exceptions was created matches the current leaf
    certificate).
    @result Returns true if the exceptions cookies was valid and matches the current
    leaf certificate, false otherwise.  This function will invalidate the existing
    trust result, requiring a subsequent evaluation for the newly-set exceptions.
    Note that this function returning true doesn't mean the caller can skip calling
    SecTrustEvaluate, as there may be new errors since the exceptions cookie was
    created (for example, a certificate may have subsequently expired.)
    @discussion Clients of this interface will need to establish the context of this
    exception to later decide when this exception cookie is to be used.
    Examples of this context would be the server we are connecting to, the ssid
    of the wireless network for which this cert is needed, the account for which
    this cert should be considered valid, and so on.
 */
bool SecTrustSetExceptions(SecTrustRef trust, CFDataRef __nullable exceptions)
    __OSX_AVAILABLE_STARTING(__MAC_10_9, __IPHONE_4_0);

/*!
    @function SecTrustCopyProperties
    @abstract Return a property array for this trust evaluation.
    @param trust A reference to a trust object. If the trust has not been
    evaluated, the returned property array will be empty.
    @result A property array. It is the caller's responsibility to CFRelease
    the returned array when it is no longer needed.
    @discussion This function returns an ordered array of CFDictionaryRef
    instances for each certificate in the chain. Indices run from 0 (leaf) to
    the anchor (or last certificate found if no anchor was found.) See the
    "Trust Property Constants" section for a list of currently defined keys.
 */
__nullable
CFArrayRef SecTrustCopyProperties(SecTrustRef trust)
    __OSX_AVAILABLE_STARTING(__MAC_10_7, __IPHONE_2_0);

/*!
    @function SecTrustCopyResult
    @abstract Returns a dictionary containing information about the
    evaluated certificate chain for use by clients.
    @param trust A reference to a trust object.
    @result A dictionary with various fields that can be displayed to the user,
    or NULL if no additional info is available or the trust has not yet been
    validated.  The caller is responsible for calling CFRelease on the value
    returned when it is no longer needed.
    @discussion Returns a dictionary for the overall trust evaluation. See the
    "Trust Result Constants" section for a list of currently defined keys.
 */
__nullable
CFDictionaryRef SecTrustCopyResult(SecTrustRef trust)
    __OSX_AVAILABLE_STARTING(__MAC_10_9, __IPHONE_7_0);

/*!
    @function SecTrustSetOCSPResponse
    @abstract Attach OCSPResponse data to a trust object.
    @param trust A reference to a trust object.
    @param responseData This may be either a CFData object containing a single
    DER-encoded OCSPResponse (per RFC 2560), or a CFArray of these.
    @result A result code. See "Security Error Codes" (SecBase.h).
    @discussion Allows the caller to provide OCSPResponse data (which may be
    obtained during a TLS/SSL handshake, per RFC 3546) as input to a trust
    evaluation. If this data is available, it can obviate the need to contact
    an OCSP server for current revocation information.
 */
OSStatus SecTrustSetOCSPResponse(SecTrustRef trust, CFTypeRef __nullable responseData)
    __OSX_AVAILABLE_STARTING(__MAC_10_9, __IPHONE_7_0);

CF_IMPLICIT_BRIDGING_DISABLED
CF_ASSUME_NONNULL_END

/*
 *  Legacy functions (OS X only)
 */
#if TARGET_OS_MAC && !TARGET_OS_IPHONE
#include <Security/cssmtype.h>
#include <Security/cssmapple.h>

CF_ASSUME_NONNULL_BEGIN
CF_IMPLICIT_BRIDGING_ENABLED

/*!
    @typedef SecTrustUserSetting
    @abstract Specifies a user-specified trust setting value.
    @discussion Deprecated in OS X 10.9. User trust settings are managed by
    functions in SecTrustSettings.h (starting with OS X 10.5), and by the
    SecTrustCopyExceptions and SecTrustSetExceptions functions (starting with
    iOS 4 and OS X 10.9). The latter two functions are recommended for both OS X
    and iOS, as they avoid the need to explicitly specify these values.
 */
typedef SecTrustResultType SecTrustUserSetting
    __OSX_AVAILABLE_BUT_DEPRECATED(__MAC_10_2, __MAC_10_9, __IPHONE_NA, __IPHONE_NA);

/*!
    @typedef SecTrustOptionFlags
    @abstract Options for customizing trust evaluation.
    @constant kSecTrustOptionAllowExpired Allow expired certificates.
    @constant kSecTrustOptionLeafIsCA Allow CA as leaf certificate.
    @constant kSecTrustOptionFetchIssuerFromNet Allow network fetch of CA cert.
    @constant kSecTrustOptionAllowExpiredRoot Allow expired roots.
    @constant kSecTrustOptionRequireRevPerCert Require positive revocation
    check per certificate.
    @constant kSecTrustOptionUseTrustSettings Use TrustSettings instead of
    anchors.
    @constant kSecTrustOptionImplicitAnchors Properly self-signed certs are
    treated as anchors implicitly.
 */
typedef CF_OPTIONS(uint32_t, SecTrustOptionFlags)
{
    kSecTrustOptionAllowExpired       = 0x00000001,
    kSecTrustOptionLeafIsCA           = 0x00000002,
    kSecTrustOptionFetchIssuerFromNet = 0x00000004,
    kSecTrustOptionAllowExpiredRoot   = 0x00000008,
    kSecTrustOptionRequireRevPerCert  = 0x00000010,
    kSecTrustOptionUseTrustSettings   = 0x00000020,
    kSecTrustOptionImplicitAnchors    = 0x00000040
};

/*!
    @function SecTrustSetOptions
    @abstract Sets optional flags for customizing a trust evaluation.
    @param trustRef A trust reference.
    @param options Flags to change evaluation behavior for this trust.
    @result A result code. See "Security Error Codes" (SecBase.h).
    @discussion This function is not available on iOS. Use SecTrustSetExceptions
    and SecTrustCopyExceptions to modify default trust results, and
    SecTrustSetNetworkFetchAllowed to specify whether missing CA certificates
    can be fetched from the network.
 */
OSStatus SecTrustSetOptions(SecTrustRef trustRef, SecTrustOptionFlags options)
    __OSX_AVAILABLE_STARTING(__MAC_10_7, __IPHONE_NA);

/*!
    @function SecTrustSetParameters
    @abstract Sets the action and action data for a trust object.
    @param trustRef The reference to the trust to change.
    @param action A trust action.
    @param actionData A reference to data associated with this action.
    @result A result code. See "Security Error Codes" (SecBase.h).
    @discussion This function is deprecated in OS X 10.7 and later, where it
    was replaced by SecTrustSetOptions, and is not available on iOS. Your code
    should use SecTrustSetExceptions and SecTrustCopyExceptions to modify default
    trust results, and SecTrustSetNetworkFetchAllowed to specify whether missing
    CA certificates can be fetched from the network.
 */
OSStatus SecTrustSetParameters(SecTrustRef trustRef,
    CSSM_TP_ACTION action, CFDataRef actionData)
    __OSX_AVAILABLE_BUT_DEPRECATED(__MAC_10_2, __MAC_10_7, __IPHONE_NA, __IPHONE_NA);

/*!
    @function SecTrustSetKeychains
    @abstract Sets the keychains for a given trust object.
    @param trust A reference to a trust object.
    @param keychainOrArray A reference to an array of keychains to search, a
    single keychain, or NULL to use the default keychain search list.
    @result A result code. See "Security Error Codes" (SecBase.h).
    @discussion By default, the user's keychain search list and the system
    anchors keychain are searched for certificates to complete the chain. You
    can specify a zero-element array if you do not want any keychains searched.
    Note: this function is not applicable to iOS.
 */
OSStatus SecTrustSetKeychains(SecTrustRef trust, CFTypeRef __nullable keychainOrArray)
    __OSX_AVAILABLE_STARTING(__MAC_10_3, __IPHONE_NA);

/*!
    @function SecTrustGetResult
    @abstract Returns detailed information on the outcome of an evaluation.
    @param trustRef A reference to a trust object.
    @param result A pointer to the result from the call to SecTrustEvaluate.
    @param certChain On return, a pointer to the certificate chain used to
    validate the input certificate. Call the CFRelease function to release
    this pointer.
    @param statusChain On return, a pointer to the status of the certificate
    chain. Do not attempt to free this pointer; it remains valid until the
    trust is destroyed or the next call to SecTrustEvaluate.
    @result A result code. See "Security Error Codes" (SecBase.h).
    @discussion This function is deprecated in OS X 10.7 and later,
    and is not available on iOS.
    To get the complete certificate chain, use SecTrustGetCertificateCount and
    SecTrustGetCertificateAtIndex. To get detailed status information for each
    certificate, use SecTrustCopyProperties. To get the overall trust result
    for the evaluation, use SecTrustGetTrustResult.
 */
OSStatus SecTrustGetResult(SecTrustRef trustRef, SecTrustResultType * __nullable result,
    CFArrayRef * __nullable CF_RETURNS_RETAINED certChain, CSSM_TP_APPLE_EVIDENCE_INFO * __nullable * __nullable statusChain)
    __OSX_AVAILABLE_BUT_DEPRECATED(__MAC_10_2, __MAC_10_7, __IPHONE_NA, __IPHONE_NA);

/*!
    @function SecTrustGetCssmResult
    @abstract Gets the CSSM trust result.
    @param trust A reference to a trust.
    @param result On return, a pointer to the CSSM trust result.
    @result A result code. See "Security Error Codes" (SecBase.h).
    @discussion This function is deprecated in OS X 10.7 and later,
    and is not available on iOS.
    To get detailed status information for each certificate, use
    SecTrustCopyProperties. To get the overall trust result for the evaluation,
    use SecTrustGetTrustResult.
 */
OSStatus SecTrustGetCssmResult(SecTrustRef trust,
    CSSM_TP_VERIFY_CONTEXT_RESULT_PTR __nullable * __nonnull result)
    __OSX_AVAILABLE_BUT_DEPRECATED(__MAC_10_2, __MAC_10_7, __IPHONE_NA, __IPHONE_NA);

/*!
    @function SecTrustGetCssmResultCode
    @abstract Gets the result code from the most recent call to SecTrustEvaluate
    for the specified trust.
    @param trust A reference to a trust.
    @param resultCode On return, the result code produced by the most recent
    evaluation of the given trust (cssmerr.h). The value of resultCode is
    undefined if SecTrustEvaluate has not been called.
    @result A result code. See "Security Error Codes" (SecBase.h). Returns
    errSecTrustNotAvailable if SecTrustEvaluate has not been called for the
    specified trust.
    @discussion This function is deprecated in OS X 10.7 and later,
    and is not available on iOS.
    To get detailed status information for each certificate, use
    SecTrustCopyProperties. To get the overall trust result for the evaluation,
    use SecTrustGetTrustResult.
 */
OSStatus SecTrustGetCssmResultCode(SecTrustRef trust, OSStatus *resultCode)
    __OSX_AVAILABLE_BUT_DEPRECATED(__MAC_10_2, __MAC_10_7, __IPHONE_NA, __IPHONE_NA);

/*!
    @function SecTrustGetTPHandle
    @abstract Gets the CSSM trust handle
    @param trust A reference to a trust.
    @param handle On return, a CSSM trust handle.
    @result A result code. See "Security Error Codes" (SecBase.h).
    @discussion This function is deprecated in OS X 10.7 and later.
 */
OSStatus SecTrustGetTPHandle(SecTrustRef trust, CSSM_TP_HANDLE *handle)
    __OSX_AVAILABLE_BUT_DEPRECATED(__MAC_10_2, __MAC_10_7, __IPHONE_NA, __IPHONE_NA);

/*!
    @function SecTrustCopyAnchorCertificates
    @abstract Returns an array of default anchor (root) certificates used by
    the system.
    @param anchors On return, an array containing the system's default anchors
    (roots). Call the CFRelease function to release this pointer.
    @result A result code. See "Security Error Codes" (SecBase.h).
    @discussion This function is not available on iOS, as certificate data
    for system-trusted roots is currently unavailable on that platform.
 */
OSStatus SecTrustCopyAnchorCertificates(CFArrayRef * __nonnull CF_RETURNS_RETAINED anchors)
    __OSX_AVAILABLE_STARTING(__MAC_10_3, __IPHONE_NA);

CF_IMPLICIT_BRIDGING_DISABLED
CF_ASSUME_NONNULL_END

#endif /* TARGET_OS_MAC && !TARGET_OS_IPHONE */

__END_DECLS

#endif /* !_SECURITY_SECTRUST_H_ */
