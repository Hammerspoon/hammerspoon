/*
 * Copyright (c) 2000-2014 Apple Inc. All Rights Reserved.
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
	@header SecBase
	SecBase contains common declarations for the Security functions.
*/

#ifndef _SECURITY_SECBASE_H_
#define _SECURITY_SECBASE_H_

#include <CoreFoundation/CFBase.h>
#include <AvailabilityMacros.h>

#if defined(__clang__)
#define SEC_DEPRECATED_ATTRIBUTE DEPRECATED_ATTRIBUTE
#else
#define SEC_DEPRECATED_ATTRIBUTE
#endif

#if defined(__cplusplus)
extern "C" {
#endif

CF_ASSUME_NONNULL_BEGIN
CF_IMPLICIT_BRIDGING_ENABLED

#ifndef __SEC_TYPES__
#define __SEC_TYPES__

/*!
    @typedef SecKeychainRef
    @abstract Contains information about a keychain.
*/
typedef struct CF_BRIDGED_TYPE(id) OpaqueSecKeychainRef *SecKeychainRef;

/*!
    @typedef SecKeychainItemRef
    @abstract Contains information about a keychain item.
*/
typedef struct CF_BRIDGED_TYPE(id) OpaqueSecKeychainItemRef *SecKeychainItemRef;

/*!
    @typedef SecKeychainSearchRef
    @abstract Contains information about a keychain search.
*/
typedef struct CF_BRIDGED_TYPE(id) OpaqueSecKeychainSearchRef *SecKeychainSearchRef;

/*!
    @typedef SecKeychainAttrType
    @abstract Represents a keychain attribute type.
*/
typedef OSType SecKeychainAttrType;

/*!
    @struct SecKeychainAttribute
    @abstract Contains keychain attributes.
    @field tag A 4-byte attribute tag.
    @field length The length of the buffer pointed to by data.
    @field data A pointer to the attribute data.
*/
struct SecKeychainAttribute
{
    SecKeychainAttrType	tag;
    UInt32 length;
    void *data;
};
typedef struct SecKeychainAttribute SecKeychainAttribute;

/*!
    @typedef SecKeychainAttributePtr
    @abstract Represents a pointer to a keychain attribute structure.
*/
typedef SecKeychainAttribute *SecKeychainAttributePtr;

/*!
    @typedef SecKeychainAttributeList
    @abstract Represents a list of keychain attributes.
    @field count An unsigned 32-bit integer that represents the number of keychain attributes in the array.
    @field attr A pointer to the first keychain attribute in the array.
*/
struct SecKeychainAttributeList
{
    UInt32 count;
    SecKeychainAttribute *attr;
};
typedef struct SecKeychainAttributeList  SecKeychainAttributeList;

/*!
    @typedef SecKeychainStatus
    @abstract Represents the status of a keychain.
*/
typedef UInt32 SecKeychainStatus;
#endif

/*!
    @typedef SecTrustedApplicationRef
    @abstract Contains information about a trusted application.
*/
typedef struct CF_BRIDGED_TYPE(id) OpaqueSecTrustedApplicationRef *SecTrustedApplicationRef;

/*!
    @typedef SecPolicyRef
    @abstract Contains information about a policy.
*/
typedef struct CF_BRIDGED_TYPE(id) OpaqueSecPolicyRef *SecPolicyRef;

/*!
    @typedef SecCertificateRef
    @abstract Contains information about a certificate.
*/
typedef struct CF_BRIDGED_TYPE(id) OpaqueSecCertificateRef *SecCertificateRef;

/*!
    @typedef SecAccessRef
    @abstract Contains information about an access.
*/
typedef struct CF_BRIDGED_TYPE(id) OpaqueSecAccessRef *SecAccessRef;

/*!
    @typedef SecIdentityRef
    @abstract Contains information about an identity.
*/
typedef struct CF_BRIDGED_TYPE(id) OpaqueSecIdentityRef *SecIdentityRef;

/*!
    @typedef SecKeyRef
    @abstract Contains information about a key.
*/
typedef struct CF_BRIDGED_TYPE(id) OpaqueSecKeyRef *SecKeyRef;

/*!
    @typedef SecACLRef
    @abstract Contains information about an access control list (ACL) entry.
*/
typedef struct CF_BRIDGED_TYPE(id) OpaqueSecTrustRef *SecACLRef;

/*!
    @typedef SecAccessControlRef
    @abstract CFType representing access control for an item.
*/
typedef struct CF_BRIDGED_TYPE(id) OpaqueSecAccessControl *SecAccessControlRef;

/*!
    @typedef SecPasswordRef
    @abstract Contains information about a password.
*/
typedef struct CF_BRIDGED_TYPE(id) OpaqueSecPasswordRef *SecPasswordRef;

/*!
    @typedef SecKeychainAttributeInfo
    @abstract Represents an attribute.
    @field count The number of tag-format pairs in the respective arrays.
    @field tag A pointer to the first attribute tag in the array.
    @field format A pointer to the first CSSM_DB_ATTRIBUTE_FORMAT in the array.
    @discussion Each tag and format item form a pair.
*/
struct SecKeychainAttributeInfo
{
    UInt32 count;
    UInt32 *tag;
	UInt32 *format;
};
typedef struct SecKeychainAttributeInfo  SecKeychainAttributeInfo;

/*!
    @function SecCopyErrorMessageString
    @abstract Returns a string describing the specified error result code.
    @param status An error result code of type OSStatus or CSSM_RETURN, as returned by a Security or CSSM function.
    @reserved Reserved for future use. Your code should pass NULL in this parameter.
    @result A reference to an error string, or NULL if no error string is available for the specified result code. Your code must release this reference by calling the CFRelease function.
*/
__nullable
CFStringRef SecCopyErrorMessageString(OSStatus status, void * __nullable reserved)
    __OSX_AVAILABLE_STARTING(__MAC_10_3, __IPHONE_NA);
/*!
@enum Security Error Codes
@abstract Result codes returned from Security framework functions.
@constant errSecSuccess No error.
@constant errSecUnimplemented Function or operation not implemented.
@constant errSecDskFull Disk Full error.
@constant errSecIO I/O error.
@constant errSecParam One or more parameters passed to a function were not valid.
@constant errSecWrPerm	Write permissions error.
@constant errSecAllocate Failed to allocate memory.
@constant errSecUserCanceled User canceled the operation.
@constant errSecBadReq Bad parameter or invalid state for operation.
@constant errSecInternalComponent
@constant errSecCoreFoundationUnknown
@constant errSecNotAvailable No keychain is available.
@constant errSecReadOnly Read only error.
@constant errSecAuthFailed Authorization/Authentication failed.
@constant errSecNoSuchKeychain The keychain does not exist.
@constant errSecInvalidKeychain The keychain is not valid.
@constant errSecDuplicateKeychain A keychain with the same name already exists.
@constant errSecDuplicateCallback The specified callback is already installed.
@constant errSecInvalidCallback The specified callback is not valid.
@constant errSecDuplicateItem The item already exists.
@constant errSecItemNotFound The item cannot be found.
@constant errSecBufferTooSmall The buffer is too small.
@constant errSecDataTooLarge The data is too large.
@constant errSecNoSuchAttr The attribute does not exist.
@constant errSecInvalidItemRef The item reference is invalid.
@constant errSecInvalidSearchRef The search reference is invalid.
@constant errSecNoSuchClass The keychain item class does not exist.
@constant errSecNoDefaultKeychain A default keychain does not exist.
@constant errSecInteractionNotAllowed User interaction is not allowed.
@constant errSecReadOnlyAttr The attribute is read only.
@constant errSecWrongSecVersion The version is incorrect.
@constant errSecKeySizeNotAllowed The key size is not allowed.
@constant errSecNoStorageModule There is no storage module available.
@constant errSecNoCertificateModule There is no certificate module available.
@constant errSecNoPolicyModule There is no policy module available.
@constant errSecInteractionRequired User interaction is required.
@constant errSecDataNotAvailable The data is not available.
@constant errSecDataNotModifiable The data is not modifiable.
@constant errSecCreateChainFailed The attempt to create a certificate chain failed.
@constant errSecACLNotSimple The access control list is not in standard simple form.
@constant errSecPolicyNotFound The policy specified cannot be found.
@constant errSecInvalidTrustSetting The specified trust setting is invalid.
@constant errSecNoAccessForItem The specified item has no access control.
@constant errSecInvalidOwnerEdit Invalid attempt to change the owner of this item.
@constant errSecTrustNotAvailable No trust results are available.
@constant errSecUnsupportedFormat Import/Export format unsupported.
@constant errSecUnknownFormat Unknown format in import.
@constant errSecKeyIsSensitive Key material must be wrapped for export.
@constant errSecMultiplePrivKeys An attempt was made to import multiple private keys.
@constant errSecPassphraseRequired Passphrase is required for import/export.
@constant errSecInvalidPasswordRef The password reference was invalid.
@constant errSecInvalidTrustSettings The Trust Settings Record was corrupted.
@constant errSecNoTrustSettings No Trust Settings were found.
@constant errSecPkcs12VerifyFailure MAC verification failed during PKCS12 Import.
@constant errSecDecode Unable to decode the provided data.

@discussion The assigned error space is discontinuous: e.g. -25240..-25279, -25290..-25329, -68608..-67585, and so on.
*/

/*
    Note: the comments that appear after these errors are used to create SecErrorMessages.strings.
    The comments must not be multi-line, and should be in a form meaningful to an end user. If
    a different or additional comment is needed, it can be put in the header doc format, or on a
    line that does not start with errZZZ.
*/

CF_ENUM(OSStatus)
{
    errSecSuccess                = 0,       /* No error. */
    errSecUnimplemented          = -4,      /* Function or operation not implemented. */
    errSecDskFull                = -34,
    errSecIO                     = -36,     /*I/O error (bummers)*/

    errSecParam                  = -50,     /* One or more parameters passed to a function were not valid. */
    errSecWrPerm                 = -61,     /* write permissions error*/
    errSecAllocate               = -108,    /* Failed to allocate memory. */
    errSecUserCanceled           = -128,    /* User canceled the operation. */
    errSecBadReq                 = -909,    /* Bad parameter or invalid state for operation. */

    errSecInternalComponent      = -2070,
    errSecCoreFoundationUnknown  = -4960,

    errSecNotAvailable           = -25291,	/* No keychain is available. You may need to restart your computer. */
    errSecReadOnly               = -25292,	/* This keychain cannot be modified. */
    errSecAuthFailed             = -25293,	/* The user name or passphrase you entered is not correct. */
    errSecNoSuchKeychain         = -25294,	/* The specified keychain could not be found. */
    errSecInvalidKeychain        = -25295,	/* The specified keychain is not a valid keychain file. */
    errSecDuplicateKeychain      = -25296,	/* A keychain with the same name already exists. */
    errSecDuplicateCallback      = -25297,	/* The specified callback function is already installed. */
    errSecInvalidCallback        = -25298,	/* The specified callback function is not valid. */
    errSecDuplicateItem          = -25299,	/* The specified item already exists in the keychain. */
    errSecItemNotFound           = -25300,	/* The specified item could not be found in the keychain. */
    errSecBufferTooSmall         = -25301,	/* There is not enough memory available to use the specified item. */
    errSecDataTooLarge           = -25302,	/* This item contains information which is too large or in a format that cannot be displayed. */
    errSecNoSuchAttr             = -25303,	/* The specified attribute does not exist. */
    errSecInvalidItemRef         = -25304,	/* The specified item is no longer valid. It may have been deleted from the keychain. */
    errSecInvalidSearchRef       = -25305,	/* Unable to search the current keychain. */
    errSecNoSuchClass            = -25306,	/* The specified item does not appear to be a valid keychain item. */
    errSecNoDefaultKeychain      = -25307,	/* A default keychain could not be found. */
    errSecInteractionNotAllowed  = -25308,	/* User interaction is not allowed. */
    errSecReadOnlyAttr           = -25309,	/* The specified attribute could not be modified. */
    errSecWrongSecVersion        = -25310,	/* This keychain was created by a different version of the system software and cannot be opened. */
    errSecKeySizeNotAllowed      = -25311,	/* This item specifies a key size which is too large. */
    errSecNoStorageModule        = -25312,	/* A required component (data storage module) could not be loaded. You may need to restart your computer. */
    errSecNoCertificateModule    = -25313,	/* A required component (certificate module) could not be loaded. You may need to restart your computer. */
    errSecNoPolicyModule         = -25314,	/* A required component (policy module) could not be loaded. You may need to restart your computer. */
    errSecInteractionRequired    = -25315,	/* User interaction is required, but is currently not allowed. */
    errSecDataNotAvailable       = -25316,	/* The contents of this item cannot be retrieved. */
    errSecDataNotModifiable      = -25317,	/* The contents of this item cannot be modified. */
    errSecCreateChainFailed      = -25318,	/* One or more certificates required to validate this certificate cannot be found. */
    errSecInvalidPrefsDomain     = -25319,	/* The specified preferences domain is not valid. */
    errSecInDarkWake             = -25320,	/* In dark wake, no UI possible */

	errSecACLNotSimple           = -25240,	/* The specified access control list is not in standard (simple) form. */
	errSecPolicyNotFound         = -25241,	/* The specified policy cannot be found. */
	errSecInvalidTrustSetting    = -25242,	/* The specified trust setting is invalid. */
	errSecNoAccessForItem        = -25243,	/* The specified item has no access control. */
	errSecInvalidOwnerEdit       = -25244,	/* Invalid attempt to change the owner of this item. */
	errSecTrustNotAvailable      = -25245,	/* No trust results are available. */
	errSecUnsupportedFormat      = -25256,	/* Import/Export format unsupported. */
	errSecUnknownFormat          = -25257,	/* Unknown format in import. */
	errSecKeyIsSensitive         = -25258,	/* Key material must be wrapped for export. */
	errSecMultiplePrivKeys       = -25259,	/* An attempt was made to import multiple private keys. */
	errSecPassphraseRequired     = -25260,	/* Passphrase is required for import/export. */
	errSecInvalidPasswordRef     = -25261,	/* The password reference was invalid. */
	errSecInvalidTrustSettings   = -25262,	/* The Trust Settings Record was corrupted. */
	errSecNoTrustSettings        = -25263,	/* No Trust Settings were found. */
	errSecPkcs12VerifyFailure    = -25264,	/* MAC verification failed during PKCS12 import (wrong password?) */
	errSecNotSigner              = -26267,	/* A certificate was not signed by its proposed parent. */

	errSecDecode                 = -26275,	/* Unable to decode the provided data. */

	errSecServiceNotAvailable			= -67585,	/* The required service is not available. */
	errSecInsufficientClientID			= -67586,	/* The client ID is not correct. */
	errSecDeviceReset						= -67587,	/* A device reset has occurred. */
	errSecDeviceFailed					= -67588,	/* A device failure has occurred. */
	errSecAppleAddAppACLSubject			= -67589,	/* Adding an application ACL subject failed. */
	errSecApplePublicKeyIncomplete		= -67590,	/* The public key is incomplete. */
	errSecAppleSignatureMismatch		= -67591,	/* A signature mismatch has occurred. */
	errSecAppleInvalidKeyStartDate		= -67592,	/* The specified key has an invalid start date. */
	errSecAppleInvalidKeyEndDate		= -67593,	/* The specified key has an invalid end date. */
	errSecConversionError				= -67594,	/* A conversion error has occurred. */
	errSecAppleSSLv2Rollback			= -67595,	/* A SSLv2 rollback error has occurred. */
	errSecDiskFull						= -34,		/* The disk is full. */
	errSecQuotaExceeded					= -67596,	/* The quota was exceeded. */
	errSecFileTooBig						= -67597,	/* The file is too big. */
	errSecInvalidDatabaseBlob			= -67598,	/* The specified database has an invalid blob. */
	errSecInvalidKeyBlob					= -67599,	/* The specified database has an invalid key blob. */
	errSecIncompatibleDatabaseBlob		= -67600,	/* The specified database has an incompatible blob. */
	errSecIncompatibleKeyBlob			= -67601,	/* The specified database has an incompatible key blob. */
	errSecHostNameMismatch				= -67602,	/* A host name mismatch has occurred. */
	errSecUnknownCriticalExtensionFlag	= -67603,	/* There is an unknown critical extension flag. */
	errSecNoBasicConstraints			= -67604,	/* No basic constraints were found. */
	errSecNoBasicConstraintsCA			= -67605,	/* No basic CA constraints were found. */
	errSecInvalidAuthorityKeyID			= -67606,	/* The authority key ID is not valid. */
	errSecInvalidSubjectKeyID			= -67607,	/* The subject key ID is not valid. */
	errSecInvalidKeyUsageForPolicy		= -67608,	/* The key usage is not valid for the specified policy. */
	errSecInvalidExtendedKeyUsage		= -67609,	/* The extended key usage is not valid. */
	errSecInvalidIDLinkage				= -67610,	/* The ID linkage is not valid. */
	errSecPathLengthConstraintExceeded	= -67611,	/* The path length constraint was exceeded. */
	errSecInvalidRoot						= -67612,	/* The root or anchor certificate is not valid. */
	errSecCRLExpired						= -67613,	/* The CRL has expired. */
	errSecCRLNotValidYet					= -67614,	/* The CRL is not yet valid. */
	errSecCRLNotFound						= -67615,	/* The CRL was not found. */
	errSecCRLServerDown					= -67616,	/* The CRL server is down. */
	errSecCRLBadURI						= -67617,	/* The CRL has a bad Uniform Resource Identifier. */
	errSecUnknownCertExtension			= -67618,	/* An unknown certificate extension was encountered. */
	errSecUnknownCRLExtension			= -67619,	/* An unknown CRL extension was encountered. */
	errSecCRLNotTrusted					= -67620,	/* The CRL is not trusted. */
	errSecCRLPolicyFailed				= -67621,	/* The CRL policy failed. */
	errSecIDPFailure						= -67622,	/* The issuing distribution point was not valid. */
	errSecSMIMEEmailAddressesNotFound	= -67623,	/* An email address mismatch was encountered. */
	errSecSMIMEBadExtendedKeyUsage		= -67624,	/* The appropriate extended key usage for SMIME was not found. */
	errSecSMIMEBadKeyUsage				= -67625,	/* The key usage is not compatible with SMIME. */
	errSecSMIMEKeyUsageNotCritical		= -67626,	/* The key usage extension is not marked as critical. */
	errSecSMIMENoEmailAddress			= -67627,	/* No email address was found in the certificate. */
	errSecSMIMESubjAltNameNotCritical	= -67628,	/* The subject alternative name extension is not marked as critical. */
	errSecSSLBadExtendedKeyUsage		= -67629,	/* The appropriate extended key usage for SSL was not found. */
	errSecOCSPBadResponse				= -67630,	/* The OCSP response was incorrect or could not be parsed. */
	errSecOCSPBadRequest					= -67631,	/* The OCSP request was incorrect or could not be parsed. */
	errSecOCSPUnavailable				= -67632,	/* OCSP service is unavailable. */
	errSecOCSPStatusUnrecognized		= -67633,	/* The OCSP server did not recognize this certificate. */
	errSecEndOfData							= -67634,	/* An end-of-data was detected. */
	errSecIncompleteCertRevocationCheck	= -67635,	/* An incomplete certificate revocation check occurred. */
	errSecNetworkFailure						= -67636,	/* A network failure occurred. */
	errSecOCSPNotTrustedToAnchor			= -67637,	/* The OCSP response was not trusted to a root or anchor certificate. */
	errSecRecordModified						= -67638,	/* The record was modified. */
	errSecOCSPSignatureError				= -67639,	/* The OCSP response had an invalid signature. */
	errSecOCSPNoSigner						= -67640,	/* The OCSP response had no signer. */
	errSecOCSPResponderMalformedReq		= -67641,	/* The OCSP responder was given a malformed request. */
	errSecOCSPResponderInternalError		= -67642,	/* The OCSP responder encountered an internal error. */
	errSecOCSPResponderTryLater				= -67643,	/* The OCSP responder is busy, try again later. */
	errSecOCSPResponderSignatureRequired	= -67644,	/* The OCSP responder requires a signature. */
	errSecOCSPResponderUnauthorized		= -67645,	/* The OCSP responder rejected this request as unauthorized. */
	errSecOCSPResponseNonceMismatch		= -67646,	/* The OCSP response nonce did not match the request. */
	errSecCodeSigningBadCertChainLength	= -67647,	/* Code signing encountered an incorrect certificate chain length. */
	errSecCodeSigningNoBasicConstraints	= -67648,	/* Code signing found no basic constraints. */
	errSecCodeSigningBadPathLengthConstraint= -67649,	/* Code signing encountered an incorrect path length constraint. */
	errSecCodeSigningNoExtendedKeyUsage		= -67650,	/* Code signing found no extended key usage. */
	errSecCodeSigningDevelopment			= -67651,	/* Code signing indicated use of a development-only certificate. */
	errSecResourceSignBadCertChainLength	= -67652,	/* Resource signing has encountered an incorrect certificate chain length. */
	errSecResourceSignBadExtKeyUsage		= -67653,	/* Resource signing has encountered an error in the extended key usage. */
	errSecTrustSettingDeny					= -67654,	/* The trust setting for this policy was set to Deny. */
	errSecInvalidSubjectName				= -67655,	/* An invalid certificate subject name was encountered. */
	errSecUnknownQualifiedCertStatement	= -67656,	/* An unknown qualified certificate statement was encountered. */
	errSecMobileMeRequestQueued				= -67657,	/* The MobileMe request will be sent during the next connection. */
	errSecMobileMeRequestRedirected		= -67658,	/* The MobileMe request was redirected. */
	errSecMobileMeServerError				= -67659,	/* A MobileMe server error occurred. */
	errSecMobileMeServerNotAvailable		= -67660,	/* The MobileMe server is not available. */
	errSecMobileMeServerAlreadyExists		= -67661,	/* The MobileMe server reported that the item already exists. */
	errSecMobileMeServerServiceErr			= -67662,	/* A MobileMe service error has occurred. */
	errSecMobileMeRequestAlreadyPending	= -67663,	/* A MobileMe request is already pending. */
	errSecMobileMeNoRequestPending			= -67664,	/* MobileMe has no request pending. */
	errSecMobileMeCSRVerifyFailure			= -67665,	/* A MobileMe CSR verification failure has occurred. */
	errSecMobileMeFailedConsistencyCheck	= -67666,	/* MobileMe has found a failed consistency check. */
	errSecNotInitialized						= -67667,	/* A function was called without initializing CSSM. */
	errSecInvalidHandleUsage				= -67668,	/* The CSSM handle does not match with the service type. */
	errSecPVCReferentNotFound				= -67669,	/* A reference to the calling module was not found in the list of authorized callers. */
	errSecFunctionIntegrityFail				= -67670,	/* A function address was not within the verified module. */
	errSecInternalError						= -67671,	/* An internal error has occurred. */
	errSecMemoryError							= -67672,	/* A memory error has occurred. */
	errSecInvalidData							= -67673,	/* Invalid data was encountered. */
	errSecMDSError							= -67674,	/* A Module Directory Service error has occurred. */
	errSecInvalidPointer						= -67675,	/* An invalid pointer was encountered. */
	errSecSelfCheckFailed					= -67676,	/* Self-check has failed. */
	errSecFunctionFailed						= -67677,	/* A function has failed. */
	errSecModuleManifestVerifyFailed		= -67678,	/* A module manifest verification failure has occurred. */
	errSecInvalidGUID							= -67679,	/* An invalid GUID was encountered. */
	errSecInvalidHandle						= -67680,	/* An invalid handle was encountered. */
	errSecInvalidDBList						= -67681,	/* An invalid DB list was encountered. */
	errSecInvalidPassthroughID				= -67682,	/* An invalid passthrough ID was encountered. */
	errSecInvalidNetworkAddress				= -67683,	/* An invalid network address was encountered. */
	errSecCRLAlreadySigned					= -67684,	/* The certificate revocation list is already signed. */
	errSecInvalidNumberOfFields				= -67685,	/* An invalid number of fields were encountered. */
	errSecVerificationFailure				= -67686,	/* A verification failure occurred. */
	errSecUnknownTag							= -67687,	/* An unknown tag was encountered. */
	errSecInvalidSignature					= -67688,	/* An invalid signature was encountered. */
	errSecInvalidName							= -67689,	/* An invalid name was encountered. */
	errSecInvalidCertificateRef				= -67690,	/* An invalid certificate reference was encountered. */
	errSecInvalidCertificateGroup			= -67691,	/* An invalid certificate group was encountered. */
	errSecTagNotFound							= -67692,	/* The specified tag was not found. */
	errSecInvalidQuery						= -67693,	/* The specified query was not valid. */
	errSecInvalidValue						= -67694,	/* An invalid value was detected. */
	errSecCallbackFailed						= -67695,	/* A callback has failed. */
	errSecACLDeleteFailed					= -67696,	/* An ACL delete operation has failed. */
	errSecACLReplaceFailed					= -67697,	/* An ACL replace operation has failed. */
	errSecACLAddFailed						= -67698,	/* An ACL add operation has failed. */
	errSecACLChangeFailed					= -67699,	/* An ACL change operation has failed. */
	errSecInvalidAccessCredentials			= -67700,	/* Invalid access credentials were encountered. */
	errSecInvalidRecord						= -67701,	/* An invalid record was encountered. */
	errSecInvalidACL							= -67702,	/* An invalid ACL was encountered. */
	errSecInvalidSampleValue				= -67703,	/* An invalid sample value was encountered. */
	errSecIncompatibleVersion				= -67704,	/* An incompatible version was encountered. */
	errSecPrivilegeNotGranted				= -67705,	/* The privilege was not granted. */
	errSecInvalidScope						= -67706,	/* An invalid scope was encountered. */
	errSecPVCAlreadyConfigured				= -67707,	/* The PVC is already configured. */
	errSecInvalidPVC							= -67708,	/* An invalid PVC was encountered. */
	errSecEMMLoadFailed						= -67709,	/* The EMM load has failed. */
	errSecEMMUnloadFailed					= -67710,	/* The EMM unload has failed. */
	errSecAddinLoadFailed					= -67711,	/* The add-in load operation has failed. */
	errSecInvalidKeyRef						= -67712,	/* An invalid key was encountered. */
	errSecInvalidKeyHierarchy				= -67713,	/* An invalid key hierarchy was encountered. */
	errSecAddinUnloadFailed					= -67714,	/* The add-in unload operation has failed. */
	errSecLibraryReferenceNotFound			= -67715,	/* A library reference was not found. */
	errSecInvalidAddinFunctionTable		= -67716,	/* An invalid add-in function table was encountered. */
	errSecInvalidServiceMask				= -67717,	/* An invalid service mask was encountered. */
	errSecModuleNotLoaded					= -67718,	/* A module was not loaded. */
	errSecInvalidSubServiceID				= -67719,	/* An invalid subservice ID was encountered. */
	errSecAttributeNotInContext				= -67720,	/* An attribute was not in the context. */
	errSecModuleManagerInitializeFailed	= -67721,	/* A module failed to initialize. */
	errSecModuleManagerNotFound				= -67722,	/* A module was not found. */
	errSecEventNotificationCallbackNotFound	= -67723,	/* An event notification callback was not found. */
	errSecInputLengthError					= -67724,	/* An input length error was encountered. */
	errSecOutputLengthError					= -67725,	/* An output length error was encountered. */
	errSecPrivilegeNotSupported				= -67726,	/* The privilege is not supported. */
	errSecDeviceError							= -67727,	/* A device error was encountered. */
	errSecAttachHandleBusy					= -67728,	/* The CSP handle was busy. */
	errSecNotLoggedIn							= -67729,	/* You are not logged in. */
	errSecAlgorithmMismatch					= -67730,	/* An algorithm mismatch was encountered. */
	errSecKeyUsageIncorrect					= -67731,	/* The key usage is incorrect. */
	errSecKeyBlobTypeIncorrect				= -67732,	/* The key blob type is incorrect. */
	errSecKeyHeaderInconsistent				= -67733,	/* The key header is inconsistent. */
	errSecUnsupportedKeyFormat				= -67734,	/* The key header format is not supported. */
	errSecUnsupportedKeySize				= -67735,	/* The key size is not supported. */
	errSecInvalidKeyUsageMask				= -67736,	/* The key usage mask is not valid. */
	errSecUnsupportedKeyUsageMask			= -67737,	/* The key usage mask is not supported. */
	errSecInvalidKeyAttributeMask			= -67738,	/* The key attribute mask is not valid. */
	errSecUnsupportedKeyAttributeMask		= -67739,	/* The key attribute mask is not supported. */
	errSecInvalidKeyLabel					= -67740,	/* The key label is not valid. */
	errSecUnsupportedKeyLabel				= -67741,	/* The key label is not supported. */
	errSecInvalidKeyFormat					= -67742,	/* The key format is not valid. */
	errSecUnsupportedVectorOfBuffers		= -67743,	/* The vector of buffers is not supported. */
	errSecInvalidInputVector				= -67744,	/* The input vector is not valid. */
	errSecInvalidOutputVector				= -67745,	/* The output vector is not valid. */
	errSecInvalidContext						= -67746,	/* An invalid context was encountered. */
	errSecInvalidAlgorithm					= -67747,	/* An invalid algorithm was encountered. */
	errSecInvalidAttributeKey				= -67748,	/* A key attribute was not valid. */
	errSecMissingAttributeKey				= -67749,	/* A key attribute was missing. */
	errSecInvalidAttributeInitVector		= -67750,	/* An init vector attribute was not valid. */
	errSecMissingAttributeInitVector		= -67751,	/* An init vector attribute was missing. */
	errSecInvalidAttributeSalt				= -67752,	/* A salt attribute was not valid. */
	errSecMissingAttributeSalt				= -67753,	/* A salt attribute was missing. */
	errSecInvalidAttributePadding			= -67754,	/* A padding attribute was not valid. */
	errSecMissingAttributePadding			= -67755,	/* A padding attribute was missing. */
	errSecInvalidAttributeRandom			= -67756,	/* A random number attribute was not valid. */
	errSecMissingAttributeRandom			= -67757,	/* A random number attribute was missing. */
	errSecInvalidAttributeSeed				= -67758,	/* A seed attribute was not valid. */
	errSecMissingAttributeSeed				= -67759,	/* A seed attribute was missing. */
	errSecInvalidAttributePassphrase		= -67760,	/* A passphrase attribute was not valid. */
	errSecMissingAttributePassphrase		= -67761,	/* A passphrase attribute was missing. */
	errSecInvalidAttributeKeyLength		= -67762,	/* A key length attribute was not valid. */
	errSecMissingAttributeKeyLength		= -67763,	/* A key length attribute was missing. */
	errSecInvalidAttributeBlockSize		= -67764,	/* A block size attribute was not valid. */
	errSecMissingAttributeBlockSize		= -67765,	/* A block size attribute was missing. */
	errSecInvalidAttributeOutputSize		= -67766,	/* An output size attribute was not valid. */
	errSecMissingAttributeOutputSize		= -67767,	/* An output size attribute was missing. */
	errSecInvalidAttributeRounds			= -67768,	/* The number of rounds attribute was not valid. */
	errSecMissingAttributeRounds			= -67769,	/* The number of rounds attribute was missing. */
	errSecInvalidAlgorithmParms				= -67770,	/* An algorithm parameters attribute was not valid. */
	errSecMissingAlgorithmParms				= -67771,	/* An algorithm parameters attribute was missing. */
	errSecInvalidAttributeLabel				= -67772,	/* A label attribute was not valid. */
	errSecMissingAttributeLabel				= -67773,	/* A label attribute was missing. */
	errSecInvalidAttributeKeyType			= -67774,	/* A key type attribute was not valid. */
	errSecMissingAttributeKeyType			= -67775,	/* A key type attribute was missing. */
	errSecInvalidAttributeMode				= -67776,	/* A mode attribute was not valid. */
	errSecMissingAttributeMode				= -67777,	/* A mode attribute was missing. */
	errSecInvalidAttributeEffectiveBits	= -67778,	/* An effective bits attribute was not valid. */
	errSecMissingAttributeEffectiveBits	= -67779,	/* An effective bits attribute was missing. */
	errSecInvalidAttributeStartDate		= -67780,	/* A start date attribute was not valid. */
	errSecMissingAttributeStartDate		= -67781,	/* A start date attribute was missing. */
	errSecInvalidAttributeEndDate			= -67782,	/* An end date attribute was not valid. */
	errSecMissingAttributeEndDate			= -67783,	/* An end date attribute was missing. */
	errSecInvalidAttributeVersion			= -67784,	/* A version attribute was not valid. */
	errSecMissingAttributeVersion			= -67785,	/* A version attribute was missing. */
	errSecInvalidAttributePrime				= -67786,	/* A prime attribute was not valid. */
	errSecMissingAttributePrime				= -67787,	/* A prime attribute was missing. */
	errSecInvalidAttributeBase				= -67788,	/* A base attribute was not valid. */
	errSecMissingAttributeBase				= -67789,	/* A base attribute was missing. */
	errSecInvalidAttributeSubprime			= -67790,	/* A subprime attribute was not valid. */
	errSecMissingAttributeSubprime			= -67791,	/* A subprime attribute was missing. */
	errSecInvalidAttributeIterationCount	= -67792,	/* An iteration count attribute was not valid. */
	errSecMissingAttributeIterationCount	= -67793,	/* An iteration count attribute was missing. */
	errSecInvalidAttributeDLDBHandle		= -67794,	/* A database handle attribute was not valid. */
	errSecMissingAttributeDLDBHandle		= -67795,	/* A database handle attribute was missing. */
	errSecInvalidAttributeAccessCredentials	= -67796,	/* An access credentials attribute was not valid. */
	errSecMissingAttributeAccessCredentials	= -67797,	/* An access credentials attribute was missing. */
	errSecInvalidAttributePublicKeyFormat		= -67798,	/* A public key format attribute was not valid. */
	errSecMissingAttributePublicKeyFormat		= -67799,	/* A public key format attribute was missing. */
	errSecInvalidAttributePrivateKeyFormat	= -67800,	/* A private key format attribute was not valid. */
	errSecMissingAttributePrivateKeyFormat	= -67801,	/* A private key format attribute was missing. */
	errSecInvalidAttributeSymmetricKeyFormat	= -67802,	/* A symmetric key format attribute was not valid. */
	errSecMissingAttributeSymmetricKeyFormat	= -67803,	/* A symmetric key format attribute was missing. */
	errSecInvalidAttributeWrappedKeyFormat	= -67804,	/* A wrapped key format attribute was not valid. */
	errSecMissingAttributeWrappedKeyFormat	= -67805,	/* A wrapped key format attribute was missing. */
	errSecStagedOperationInProgress			= -67806,	/* A staged operation is in progress. */
	errSecStagedOperationNotStarted			= -67807,	/* A staged operation was not started. */
	errSecVerifyFailed							= -67808,	/* A cryptographic verification failure has occurred. */
	errSecQuerySizeUnknown						= -67809,	/* The query size is unknown. */
	errSecBlockSizeMismatch						= -67810,	/* A block size mismatch occurred. */
	errSecPublicKeyInconsistent					= -67811,	/* The public key was inconsistent. */
	errSecDeviceVerifyFailed					= -67812,	/* A device verification failure has occurred. */
	errSecInvalidLoginName						= -67813,	/* An invalid login name was detected. */
	errSecAlreadyLoggedIn						= -67814,	/* The user is already logged in. */
	errSecInvalidDigestAlgorithm				= -67815,	/* An invalid digest algorithm was detected. */
	errSecInvalidCRLGroup						= -67816,	/* An invalid CRL group was detected. */
	errSecCertificateCannotOperate				= -67817,	/* The certificate cannot operate. */
	errSecCertificateExpired					= -67818,	/* An expired certificate was detected. */
	errSecCertificateNotValidYet				= -67819,	/* The certificate is not yet valid. */
	errSecCertificateRevoked					= -67820,	/* The certificate was revoked. */
	errSecCertificateSuspended					= -67821,	/* The certificate was suspended. */
	errSecInsufficientCredentials				= -67822,	/* Insufficient credentials were detected. */
	errSecInvalidAction							= -67823,	/* The action was not valid. */
	errSecInvalidAuthority						= -67824,	/* The authority was not valid. */
	errSecVerifyActionFailed					= -67825,	/* A verify action has failed. */
	errSecInvalidCertAuthority					= -67826,	/* The certificate authority was not valid. */
	errSecInvaldCRLAuthority					= -67827,	/* The CRL authority was not valid. */
	errSecInvalidCRLEncoding					= -67828,	/* The CRL encoding was not valid. */
	errSecInvalidCRLType							= -67829,	/* The CRL type was not valid. */
	errSecInvalidCRL								= -67830,	/* The CRL was not valid. */
	errSecInvalidFormType						= -67831,	/* The form type was not valid. */
	errSecInvalidID								= -67832,	/* The ID was not valid. */
	errSecInvalidIdentifier						= -67833,	/* The identifier was not valid. */
	errSecInvalidIndex							= -67834,	/* The index was not valid. */
	errSecInvalidPolicyIdentifiers				= -67835,	/* The policy identifiers are not valid. */
	errSecInvalidTimeString						= -67836,	/* The time specified was not valid. */
	errSecInvalidReason							= -67837,	/* The trust policy reason was not valid. */
	errSecInvalidRequestInputs					= -67838,	/* The request inputs are not valid. */
	errSecInvalidResponseVector					= -67839,	/* The response vector was not valid. */
	errSecInvalidStopOnPolicy					= -67840,	/* The stop-on policy was not valid. */
	errSecInvalidTuple							= -67841,	/* The tuple was not valid. */
	errSecMultipleValuesUnsupported			= -67842,	/* Multiple values are not supported. */
	errSecNotTrusted								= -67843,	/* The trust policy was not trusted. */
	errSecNoDefaultAuthority					= -67844,	/* No default authority was detected. */
	errSecRejectedForm							= -67845,	/* The trust policy had a rejected form. */
	errSecRequestLost								= -67846,	/* The request was lost. */
	errSecRequestRejected						= -67847,	/* The request was rejected. */
	errSecUnsupportedAddressType				= -67848,	/* The address type is not supported. */
	errSecUnsupportedService					= -67849,	/* The service is not supported. */
	errSecInvalidTupleGroup						= -67850,	/* The tuple group was not valid. */
	errSecInvalidBaseACLs						= -67851,	/* The base ACLs are not valid. */
	errSecInvalidTupleCredendtials				= -67852,	/* The tuple credentials are not valid. */
	errSecInvalidEncoding						= -67853,	/* The encoding was not valid. */
	errSecInvalidValidityPeriod					= -67854,	/* The validity period was not valid. */
	errSecInvalidRequestor						= -67855,	/* The requestor was not valid. */
	errSecRequestDescriptor						= -67856,	/* The request descriptor was not valid. */
	errSecInvalidBundleInfo						= -67857,	/* The bundle information was not valid. */
	errSecInvalidCRLIndex						= -67858,	/* The CRL index was not valid. */
	errSecNoFieldValues							= -67859,	/* No field values were detected. */
	errSecUnsupportedFieldFormat				= -67860,	/* The field format is not supported. */
	errSecUnsupportedIndexInfo					= -67861,	/* The index information is not supported. */
	errSecUnsupportedLocality					= -67862,	/* The locality is not supported. */
	errSecUnsupportedNumAttributes				= -67863,	/* The number of attributes is not supported. */
	errSecUnsupportedNumIndexes					= -67864,	/* The number of indexes is not supported. */
	errSecUnsupportedNumRecordTypes			= -67865,	/* The number of record types is not supported. */
	errSecFieldSpecifiedMultiple				= -67866,	/* Too many fields were specified. */
	errSecIncompatibleFieldFormat				= -67867,	/* The field format was incompatible. */
	errSecInvalidParsingModule					= -67868,	/* The parsing module was not valid. */
	errSecDatabaseLocked							= -67869,	/* The database is locked. */
	errSecDatastoreIsOpen						= -67870,	/* The data store is open. */
	errSecMissingValue							= -67871,	/* A missing value was detected. */
	errSecUnsupportedQueryLimits				= -67872,	/* The query limits are not supported. */
	errSecUnsupportedNumSelectionPreds			= -67873,	/* The number of selection predicates is not supported. */
	errSecUnsupportedOperator					= -67874,	/* The operator is not supported. */
	errSecInvalidDBLocation						= -67875,	/* The database location is not valid. */
	errSecInvalidAccessRequest					= -67876,	/* The access request is not valid. */
	errSecInvalidIndexInfo						= -67877,	/* The index information is not valid. */
	errSecInvalidNewOwner						= -67878,	/* The new owner is not valid. */
	errSecInvalidModifyMode						= -67879,	/* The modify mode is not valid. */
	errSecMissingRequiredExtension					= -67880,	/* A required certificate extension is missing. */
	errSecExtendedKeyUsageNotCritical				= -67881,	/* The extended key usage extension was not marked critical. */
	errSecTimestampMissing						= -67882,	/* A timestamp was expected but was not found. */
	errSecTimestampInvalid						= -67883,	/* The timestamp was not valid. */
	errSecTimestampNotTrusted					= -67884,	/* The timestamp was not trusted. */
	errSecTimestampServiceNotAvailable			= -67885,	/* The timestamp service is not available. */
	errSecTimestampBadAlg						= -67886,	/* An unrecognized or unsupported Algorithm Identifier in timestamp. */
	errSecTimestampBadRequest					= -67887,	/* The timestamp transaction is not permitted or supported. */
	errSecTimestampBadDataFormat				= -67888,	/* The timestamp data submitted has the wrong format. */
	errSecTimestampTimeNotAvailable			= -67889,	/* The time source for the Timestamp Authority is not available. */
	errSecTimestampUnacceptedPolicy			= -67890,	/* The requested policy is not supported by the Timestamp Authority. */
	errSecTimestampUnacceptedExtension			= -67891,	/* The requested extension is not supported by the Timestamp Authority. */
	errSecTimestampAddInfoNotAvailable			= -67892,	/* The additional information requested is not available. */
	errSecTimestampSystemFailure				= -67893,	/* The timestamp request cannot be handled due to system failure. */
	errSecSigningTimeMissing					= -67894,	/* A signing time was expected but was not found. */
	errSecTimestampRejection					= -67895,	/* A timestamp transaction was rejected. */
	errSecTimestampWaiting                      = -67896,	/* A timestamp transaction is waiting. */
	errSecTimestampRevocationWarning            = -67897,	/* A timestamp authority revocation warning was issued. */
	errSecTimestampRevocationNotification       = -67898,	/* A timestamp authority revocation notification was issued. */
};

CF_IMPLICIT_BRIDGING_DISABLED
CF_ASSUME_NONNULL_END

#if defined(__cplusplus)
}
#endif

#endif /* !_SECURITY_SECBASE_H_ */
