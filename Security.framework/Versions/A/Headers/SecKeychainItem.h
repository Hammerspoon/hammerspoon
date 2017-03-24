/* * Copyright (c) 2000-2008,2011-2014 Apple Inc. All Rights Reserved.
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
	@header SecKeychainItem
	SecKeychainItem implements an item which may be stored in a SecKeychain, with publicly
	visible attributes and encrypted data. Access to the data of an item is protected
	using strong cryptographic algorithms.
*/

#ifndef _SECURITY_SECKEYCHAINITEM_H_
#define _SECURITY_SECKEYCHAINITEM_H_

#include <AvailabilityMacros.h>
#include <CoreFoundation/CFData.h>
#include <Security/SecBase.h>
#include <Security/cssmapple.h>

#if defined(__cplusplus)
extern "C" {
#endif

CF_ASSUME_NONNULL_BEGIN

/*!
	@enum ItemClassConstants
	@abstract Specifies a keychain item's class code.
	@constant kSecInternetPasswordItemClass Indicates that the item is an Internet password.
	@constant kSecGenericPasswordItemClass Indicates that the item is a generic password.
	@constant kSecAppleSharePasswordItemClass Indicates that the item is an AppleShare password.
		Note: AppleShare passwords are no longer used by OS X, starting in Leopard (10.5). Use of this item class is deprecated in OS X 10.9 and later; kSecInternetPasswordItemClass should be used instead when storing or looking up passwords for an Apple Filing Protocol (AFP) server.
	@constant kSecCertificateItemClass Indicates that the item is a digital certificate.
	@constant kSecPublicKeyItemClass Indicates that the item is a public key.
	@constant kSecPrivateKeyItemClass Indicates that the item is a private key.
	@constant kSecSymmetricKeyItemClass Indicates that the item is a symmetric key.
	@discussion The SecItemClass enumeration defines constants your application can use to specify the type of the keychain item you wish to create, dispose, add, delete, update, copy, or locate. You can also use these constants with the tag constant SecItemAttr.
*/
typedef CF_ENUM(FourCharCode, SecItemClass)
{
    kSecInternetPasswordItemClass   = 'inet',
    kSecGenericPasswordItemClass    = 'genp',
    kSecAppleSharePasswordItemClass   CF_ENUM_DEPRECATED(10_0, 10_9, NA, NA) = 'ashp',
    kSecCertificateItemClass        = 0x80001000,
    kSecPublicKeyItemClass          = 0x0000000F,
    kSecPrivateKeyItemClass         = 0x00000010,
    kSecSymmetricKeyItemClass       = 0x00000011
};

/*!
	@enum ItemAttributeConstants
	@abstract Specifies keychain item attributes.
	@constant kSecCreationDateItemAttr (read-only) Identifies the creation date attribute. You use this tag to get a value of type string that represents the date the item was created, expressed in Zulu Time format ("YYYYMMDDhhmmSSZ"). This format is identical to CSSM_DB_ATTRIBUTE_FORMAT_TIME_DATE (cssmtype.h). When specifying the creation date as input to a function (e.g. SecKeychainSearchCreateFromAttributes), you may alternatively provide a numeric value of type UInt32 or SInt64, expressed as seconds since 1/1/1904 (DateTimeUtils.h).
	@constant kSecModDateItemAttr (read-only) Identifies the modification date attribute. You use this tag to get a value of type string that represents the last time the item was updated, expressed in Zulu Time format ("YYYYMMDDhhmmSSZ"). This format is identical to CSSM_DB_ATTRIBUTE_FORMAT_TIME_DATE (cssmtype.h). When specifying the modification date as input to a function (e.g. SecKeychainSearchCreateFromAttributes), you may alternatively provide a numeric value of type UInt32 or SInt64, expressed as seconds since 1/1/1904 (DateTimeUtils.h).
	@constant kSecDescriptionItemAttr Identifies the description attribute. You use this tag to set or get a value of type string that represents a user-visible string describing this particular kind of item (e.g. "disk image password").
	@constant kSecCommentItemAttr Identifies the comment attribute. You use this tag to set or get a value of type string that represents a user-editable string containing comments for this item.
	@constant kSecCreatorItemAttr Identifies the creator attribute. You use this tag to set or get a value of type FourCharCode that represents the item's creator.
	@constant kSecTypeItemAttr Identifies the type attribute. You use this tag to set or get a value of type FourCharCode that represents the item's type.
	@constant kSecScriptCodeItemAttr Identifies the script code attribute. You use this tag to set or get a value of type ScriptCode that represents the script code for all strings. (Note: use of this attribute is deprecated; string attributes should always be stored in UTF-8 encoding.)
	@constant kSecLabelItemAttr Identifies the label attribute. You use this tag to set or get a value of type string that represents a user-editable string containing the label for this item.
	@constant kSecInvisibleItemAttr Identifies the invisible attribute. You use this tag to set or get a value of type Boolean that indicates whether the item is invisible (i.e. should not be displayed).
	@constant kSecNegativeItemAttr Identifies the negative attribute. You use this tag to set or get a value of type Boolean that indicates whether there is a valid password associated with this keychain item. This is useful if your application doesn't want a password for some particular service to be stored in the keychain, but prefers that it always be entered by the user. The item (typically invisible and with zero-length data) acts as a placeholder to say "don't use me."
	@constant kSecCustomIconItemAttr Identifies the custom icon attribute. You use this tag to set or get a value of type Boolean that indicates whether the item has an application-specific icon. To do this, you must also set the attribute value identified by the tag kSecTypeItemAttr to a file type for which there is a corresponding icon in the desktop database, and set the attribute value identified by the tag kSecCreatorItemAttr to an appropriate application creator type. If a custom icon corresponding to the item's type and creator can be found in the desktop database, it will be displayed by Keychain Access. Otherwise, default icons are used. (Note: use of this attribute is deprecated; custom icons for keychain items are not supported in Mac OS X.)
	@constant kSecAccountItemAttr Identifies the account attribute. You use this tag to set or get a string that represents the user account. This attribute applies to generic, Internet, and AppleShare password items.
	@constant kSecServiceItemAttr Identifies the service attribute. You use this tag to set or get a string that represents the service associated with this item. This attribute is unique to generic password items.
	@constant kSecGenericItemAttr Identifies the generic attribute. You use this tag to set or get a value of untyped bytes that represents a user-defined attribute.  This attribute is unique to generic password items.
	@constant kSecSecurityDomainItemAttr Identifies the security domain attribute. You use this tag to set or get a value that represents the Internet security domain. This attribute is unique to Internet password items.
	@constant kSecServerItemAttr Identifies the server attribute. You use this tag to set or get a value of type string that represents the Internet server's domain name or IP address. This attribute is unique to Internet password items.
	@constant kSecAuthenticationTypeItemAttr Identifies the authentication type attribute. You use this tag to set or get a value of type SecAuthenticationType that represents the Internet authentication scheme. This attribute is unique to Internet password items.
	@constant kSecPortItemAttr Identifies the port attribute. You use this tag to set or get a value of type UInt32 that represents the Internet port number. This attribute is unique to Internet password items.
	@constant kSecPathItemAttr Identifies the path attribute. You use this tag to set or get a string value that represents the path. This attribute is unique to Internet password items.
	@constant kSecVolumeItemAttr Identifies the volume attribute. You use this tag to set or get a string value that represents the AppleShare volume. This attribute is unique to AppleShare password items. Note: AppleShare passwords are no longer used by OS X as of Leopard (10.5); Internet password items are used instead.
	@constant kSecAddressItemAttr Identifies the address attribute. You use this tag to set or get a string value that represents the AppleTalk zone name, or the IP or domain name that represents the server address. This attribute is unique to AppleShare password items. Note: AppleShare passwords are no longer used by OS X as of Leopard (10.5); Internet password items are used instead.
	@constant kSecSignatureItemAttr Identifies the server signature attribute. You use this tag to set or get a value of type SecAFPServerSignature that represents the server signature block. This attribute is unique to AppleShare password items. Note: AppleShare passwords are no longer used by OS X as of Leopard (10.5); Internet password items are used instead.
	@constant kSecProtocolItemAttr Identifies the protocol attribute. You use this tag to set or get a value of type SecProtocolType that represents the Internet protocol. This attribute applies to AppleShare and Internet password items.
	@constant kSecCertificateType Indicates a CSSM_CERT_TYPE type.
	@constant kSecCertificateEncoding Indicates a CSSM_CERT_ENCODING type.
	@constant kSecCrlType Indicates a CSSM_CRL_TYPE type.
	@constant kSecCrlEncoding Indicates a CSSM_CRL_ENCODING type.
	@constant kSecAlias Indicates an alias.
	@discussion To obtain information about a certificate, use the CDSA Certificate Library (CL) API. To obtain information about a key, use the SecKeyGetCSSMKey function and the CDSA Cryptographic Service Provider (CSP) API.
*/
typedef CF_ENUM(FourCharCode, SecItemAttr)
{
    kSecCreationDateItemAttr		= 'cdat',
    kSecModDateItemAttr				= 'mdat',
    kSecDescriptionItemAttr			= 'desc',
    kSecCommentItemAttr				= 'icmt',
    kSecCreatorItemAttr				= 'crtr',
    kSecTypeItemAttr				= 'type',
    kSecScriptCodeItemAttr			= 'scrp',
    kSecLabelItemAttr				= 'labl',
    kSecInvisibleItemAttr			= 'invi',
    kSecNegativeItemAttr			= 'nega',
    kSecCustomIconItemAttr			= 'cusi',
    kSecAccountItemAttr				= 'acct',
    kSecServiceItemAttr				= 'svce',
    kSecGenericItemAttr				= 'gena',
    kSecSecurityDomainItemAttr		= 'sdmn',
    kSecServerItemAttr				= 'srvr',
    kSecAuthenticationTypeItemAttr	= 'atyp',
    kSecPortItemAttr				= 'port',
    kSecPathItemAttr				= 'path',
    kSecVolumeItemAttr				= 'vlme',
    kSecAddressItemAttr				= 'addr',
    kSecSignatureItemAttr			= 'ssig',
    kSecProtocolItemAttr			= 'ptcl',
	kSecCertificateType				= 'ctyp',
	kSecCertificateEncoding			= 'cenc',
	kSecCrlType						= 'crtp',
	kSecCrlEncoding					= 'crnc',
	kSecAlias						= 'alis'
};

/*!
	@typedef SecAFPServerSignature
	@abstract Represents a 16-byte Apple File Protocol server signature block.
*/
typedef UInt8	SecAFPServerSignature[16];

/*!
	@typedef SecPublicKeyHash
	@abstract Represents a 20-byte public key hash.
*/
typedef UInt8	SecPublicKeyHash[20];

#pragma mark ---- Keychain Item Management ----
/*!
	@function SecKeychainItemGetTypeID
	@abstract Returns the type identifier of SecKeychainItem instances.
	@result The CFTypeID of SecKeychainItem instances.
*/
CFTypeID SecKeychainItemGetTypeID(void);

/*!
	@function SecKeychainItemModifyAttributesAndData
	@abstract Updates an existing keychain item after changing its attributes or data.
	@param itemRef A reference to the keychain item to modify.
	@param attrList The list of attributes to modify, along with their new values. Pass NULL if you don't need to modify any attributes.
	@param length The length of the buffer pointed to by data.
	@param data Pointer to a buffer containing the data to store. Pass NULL if you don't need to modify the data.
    @result A result code. See "Security Error Codes" (SecBase.h).
	@discussion The keychain item is written to the keychain's permanent data store. If the keychain item has not previously been added to a keychain, a call to the SecKeychainItemModifyContent function does nothing and returns errSecSuccess.
*/
OSStatus SecKeychainItemModifyAttributesAndData(SecKeychainItemRef itemRef, const SecKeychainAttributeList * __nullable attrList, UInt32 length, const void * __nullable data);

/*!
	@function SecKeychainItemCreateFromContent
	@abstract Creates a new keychain item from the supplied parameters.
	@param itemClass A constant identifying the class of item to create.
	@param attrList The list of attributes of the item to create.
	@param length The length of the buffer pointed to by data.
	@param data A pointer to a buffer containing the data to store.
	@param initialAccess A reference to the access for this keychain item.
    @param keychainRef A reference to the keychain in which to add the item.
	@param itemRef On return, a pointer to a reference to the newly created keychain item (optional). When the item reference is no longer required, call CFRelease to deallocate memory occupied by the item.
    @result A result code. See "Security Error Codes" (SecBase.h). In addition, errSecParam (-50) may be returned if not enough valid parameters are supplied, or errSecAllocate (-108) if there is not enough memory in the current heap zone to create the object.
*/
OSStatus SecKeychainItemCreateFromContent(SecItemClass itemClass, SecKeychainAttributeList *attrList,
		UInt32 length, const void * __nullable data, SecKeychainRef __nullable keychainRef,
		SecAccessRef __nullable initialAccess, SecKeychainItemRef * __nullable CF_RETURNS_RETAINED itemRef);

/*!
	@function SecKeychainItemModifyContent
	@abstract Updates an existing keychain item after changing its attributes or data. This call should only be used in conjunction with SecKeychainItemCopyContent().
	@param itemRef A reference to the keychain item to modify.
	@param attrList The list of attributes to modify, along with their new values. Pass NULL if you don't need to modify any attributes.
	@param length The length of the buffer pointed to by data.
	@param data A pointer to a buffer containing the data to store. Pass NULL if you don't need to modify the data.
    @result A result code.  See "Security Error Codes" (SecBase.h).
*/
OSStatus SecKeychainItemModifyContent(SecKeychainItemRef itemRef, const SecKeychainAttributeList * __nullable attrList, UInt32 length, const void * __nullable data);

/*!
	@function SecKeychainItemCopyContent
	@abstract Copies the data and/or attributes stored in the given keychain item. It is recommended that you use SecKeychainItemCopyAttributesAndData(). You must call SecKeychainItemFreeContent when you no longer need the attributes and data. If you want to modify the attributes returned here, use SecKeychainModifyContent().
	@param itemRef A reference to the keychain item to modify.
	@param itemClass On return, the item's class. Pass NULL if you don't require this information.
	@param attrList On input, the list of attributes to retrieve. On output, the attributes are filled in. Pass NULL if you don't need to retrieve any attributes. You must call SecKeychainItemFreeContent when you no longer need the attributes.
	@param length On return, the length of the buffer pointed to by outData.
	@param outData On return, a pointer to a buffer containing the data in this item. Pass NULL if you don't need to retrieve the data. You must call SecKeychainItemFreeContent when you no longer need the data.
    @result A result code. See "Security Error Codes" (SecBase.h). In addition, errSecParam (-50) may be returned if not enough valid parameters are supplied.
*/
OSStatus SecKeychainItemCopyContent(SecKeychainItemRef itemRef, SecItemClass * __nullable itemClass, SecKeychainAttributeList * __nullable attrList, UInt32 * __nullable length, void * __nullable * __nullable outData);

/*!
	@function SecKeychainItemFreeContent
	@abstract Releases the memory used by the keychain attribute list and the keychain data retrieved in a previous call to SecKeychainItemCopyContent.
	@param attrList A pointer to the attribute list to release. Pass NULL to ignore this parameter.
    @param data A pointer to the data buffer to release. Pass NULL to ignore this parameter.
*/
OSStatus SecKeychainItemFreeContent(SecKeychainAttributeList * __nullable attrList, void * __nullable data);

/*!
	@function SecKeychainItemCopyAttributesAndData
	@abstract Copies the data and/or attributes stored in the given keychain item. You must call SecKeychainItemFreeAttributesAndData when you no longer need the attributes and data. If you want to modify the attributes returned here, use SecKeychainModifyAttributesAndData.
	@param itemRef A reference to the keychain item to copy.
	@param info A list of tags and formats of the attributes you wish to retrieve. Pass NULL if you don't need to retrieve any attributes. You can call SecKeychainAttributeInfoForItemID to obtain a list with all possible attribute tags and formats for the item's class.
	@param itemClass On return, the item's class. Pass NULL if you don't require this information.
	@param attrList On return, a pointer to the list of retrieved attributes. Pass NULL if you don't need to retrieve any attributes. You must call SecKeychainItemFreeAttributesAndData when you no longer need this list.
	@param length On return, the length of the buffer pointed to by outData.
	@param outData On return, a pointer to a buffer containing the data in this item. Pass NULL if you don't need to retrieve the data. You must call SecKeychainItemFreeAttributesAndData when you no longer need the data.
    @result A result code. See "Security Error Codes" (SecBase.h). In addition, errSecParam (-50) may be returned if not enough valid parameters are supplied.
*/
OSStatus SecKeychainItemCopyAttributesAndData(SecKeychainItemRef itemRef, SecKeychainAttributeInfo * __nullable info, SecItemClass * __nullable itemClass, SecKeychainAttributeList * __nullable * __nullable attrList, UInt32 * __nullable length, void * __nullable * __nullable outData);

/*!
	@function SecKeychainItemFreeAttributesAndData
	@abstract Releases the memory used by the keychain attribute list and the keychain data retrieved in a previous call to SecKeychainItemCopyAttributesAndData.
	@param attrList A pointer to the attribute list to release. Pass NULL to ignore this parameter.
    @param data A pointer to the data buffer to release. Pass NULL to ignore this parameter.
    @result A result code. See "Security Error Codes" (SecBase.h).
*/
OSStatus SecKeychainItemFreeAttributesAndData(SecKeychainAttributeList * __nullable attrList, void * __nullable data);

/*!
	@function SecKeychainItemDelete
	@abstract Deletes a keychain item from the default keychain's permanent data store.
	@param itemRef A keychain item reference of the item to delete.
    @result A result code. See "Security Error Codes" (SecBase.h).
	@discussion If itemRef has not previously been added to the keychain, SecKeychainItemDelete does nothing and returns errSecSuccess. IMPORTANT: SecKeychainItemDelete does not dispose the memory occupied by the item reference itself; use the CFRelease function when you are completely finished with an item.
*/
OSStatus SecKeychainItemDelete(SecKeychainItemRef itemRef);

/*!
	@function SecKeychainItemCopyKeychain
	@abstract Copies an existing keychain reference from a keychain item.
	@param itemRef A keychain item reference.
	@param keychainRef On return, the keychain reference for the specified item. Release this reference by calling the CFRelease function.
    @result A result code. See "Security Error Codes" (SecBase.h).
*/
OSStatus SecKeychainItemCopyKeychain(SecKeychainItemRef itemRef, SecKeychainRef * __nonnull CF_RETURNS_RETAINED keychainRef);

/*!
	@function SecKeychainItemCreateCopy
	@abstract Copies a keychain item.
	@param itemRef A reference to the keychain item to copy.
	@param destKeychainRef A reference to the keychain in which to insert the copied keychain item.
	@param initialAccess The initial access for the copied keychain item.
	@param itemCopy On return, a reference to the copied keychain item.
    @result A result code. See "Security Error Codes" (SecBase.h).
*/
OSStatus SecKeychainItemCreateCopy(SecKeychainItemRef itemRef, SecKeychainRef __nullable destKeychainRef,
	SecAccessRef __nullable initialAccess, SecKeychainItemRef * __nonnull CF_RETURNS_RETAINED itemCopy);

/*!
    @function SecKeychainItemCreatePersistentReference
    @abstract Returns a CFDataRef which can be used as a persistent reference to the given keychain item. The data obtained can be turned back into a SecKeychainItemRef later by calling SecKeychainItemCopyFromPersistentReference().
    @param itemRef A reference to a keychain item.
    @param persistentItemRef On return, a CFDataRef containing a persistent reference. You must release this data reference by calling the CFRelease function.
    @result A result code. See "Security Error Codes" (SecBase.h).
*/
OSStatus SecKeychainItemCreatePersistentReference(SecKeychainItemRef itemRef, CFDataRef * __nonnull CF_RETURNS_RETAINED persistentItemRef);


/*!
    @function SecKeychainItemCopyFromPersistentReference
    @abstract Returns a SecKeychainItemRef, given a persistent reference previously obtained by calling SecKeychainItemCreatePersistentReference().
    @param persistentItemRef A CFDataRef containing a persistent reference to a keychain item.
    @param itemRef On return, a SecKeychainItemRef for the keychain item described by the persistent reference. You must release this item reference by calling the CFRelease function.
    @result A result code. See "Security Error Codes" (SecBase.h).
*/
OSStatus SecKeychainItemCopyFromPersistentReference(CFDataRef persistentItemRef, SecKeychainItemRef * __nonnull CF_RETURNS_RETAINED itemRef);


#pragma mark ---- CSSM Bridge Functions ----
/*!
    @function SecKeychainItemGetDLDBHandle
    @abstract Returns the CSSM_DL_DB_HANDLE for a given keychain item reference.
    @param keyItemRef A keychain item reference.
    @param dldbHandle On return, a CSSM_DL_DB_HANDLE for the keychain database containing the given item. The handle is valid until the keychain reference is released.
    @result A result code. See "Security Error Codes" (SecBase.h).
	@discussion This API is deprecated for 10.7. It should no longer be needed.
*/
OSStatus SecKeychainItemGetDLDBHandle(SecKeychainItemRef keyItemRef, CSSM_DL_DB_HANDLE * __nonnull dldbHandle)
	DEPRECATED_IN_MAC_OS_X_VERSION_10_7_AND_LATER;

/*!
	@function SecKeychainItemGetUniqueRecordID
	@abstract Returns a CSSM_DB_UNIQUE_RECORD for the given keychain item reference.
	@param itemRef A keychain item reference.
    @param uniqueRecordID On return, a pointer to a CSSM_DB_UNIQUE_RECORD structure for the given item. The unique record is valid until the item reference is released.
    @result A result code. See "Security Error Codes" (SecBase.h).
	@discussion This API is deprecated for 10.7. It should no longer be needed.
*/
OSStatus SecKeychainItemGetUniqueRecordID(SecKeychainItemRef itemRef, const CSSM_DB_UNIQUE_RECORD * __nullable * __nonnull uniqueRecordID)
	DEPRECATED_IN_MAC_OS_X_VERSION_10_7_AND_LATER;

#pragma mark ---- Keychain Item Access Management ----
/*!
	@function SecKeychainItemCopyAccess
	@abstract Copies the access of a given keychain item.
	@param itemRef A reference to a keychain item.
    @param access On return, a reference to the keychain item's access.
    @result A result code. See "Security Error Codes" (SecBase.h).
*/
OSStatus SecKeychainItemCopyAccess(SecKeychainItemRef itemRef, SecAccessRef * __nonnull CF_RETURNS_RETAINED access);

/*!
	@function SecKeychainItemSetAccess
	@abstract Sets the access of a given keychain item.
	@param itemRef A reference to a keychain item.
    @param access A reference to an access to replace the keychain item's current access.
    @result A result code. See "Security Error Codes" (SecBase.h).
*/
OSStatus SecKeychainItemSetAccess(SecKeychainItemRef itemRef, SecAccessRef access);

CF_ASSUME_NONNULL_END

#if defined(__cplusplus)
}
#endif

#endif /* !_SECURITY_SECKEYCHAINITEM_H_ */
