#ifndef __SECURE_DOWNLOAD__
#define __SECURE_DOWNLOAD__

#if defined(__cplusplus)
extern "C" {
#endif

/*
 * Copyright (c) 2006,2011,2013-2014 Apple Inc. All Rights Reserved.
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
	@header SecureDownload
	@abstract Used by clients to implement Apple's Verified Download System.

	          Please note that a succesful check does not guarantee anything about
			  the safety of the file being downloaded. Rather, it simply checks to make sure
			  that the contents of the file being downloaded exactly matches the contents
			  of the file when the ticket was originally generated.

			  To use, do the following:
				1:  Download the secure download ticket.
				2:  Pass the ticket to SecureDownloadCreateWithTicket.  On error, call
					SecureDownloadGetTrustRef to return data that will help you figure
					out why the ticket was bad.
				3:  If SecureDownloadCreateWithTicket returns errSecSuccess, call SecureDownloadCopyURLs
					to return a list of data download locations.  Begin downloading data from
					the first URL in the list.  If that download fails, try downloading from
					the second URL, and so forth.
				4:	Each time you receive data, call SecureDownloadReceivedData.
				5:  Once all data has been received, call SecureDownloadFinished.
				6:  Release the SecureDownloadRef by calling SecureDownloadRelease.
*/



#include <CoreFoundation/CoreFoundation.h>
#include <Security/SecBase.h>



typedef struct OpaqueSecureDownload *SecureDownloadRef;

enum {
	errSecureDownloadInvalidTicket = -20052,
	errSecureDownloadInvalidDownload = -20053
};

/*!
	@enum _SecureDownloadSetupCallbackResult
	@discussion This type is used to indicate whether or not a
				signer should be evaluated.
	@constant kSecureDownloadDoNotEvaluateSigner Indicates that the signer should not be evaluated.
	@constant kSecureDownloadEvaluateSigner Indicates that the signer should be evaluated.
	@constant kSecureDownloadFailEvaluation Indicates that evaluation should fail immediately.
*/

typedef enum _SecureDownloadTrustCallbackResult 
{
	kSecureDownloadDoNotEvaluateSigner = 0,
	kSecureDownloadEvaluateSigner = 1,
	kSecureDownloadFailEvaluation = 2
} SecureDownloadTrustCallbackResult;

/*!
	@typedef SecureDownloadTrustSetupCallback
	@discussion This callback is used to determine whether trust for a particular
				signer should be evaluated.
	@param trustRef The trustRef for this evaluation
	@param setupContext user defined.
	@result A SecureDownloadTrustCallbackResult (see).
*/

typedef SecureDownloadTrustCallbackResult(*SecureDownloadTrustSetupCallback)
			(SecTrustRef trustRef, void* setupContext);

/*!
	@typedef SecureDownloadTrustEvaluateCallback
	@discussion This callback is used called after trust has been evaluated.
	@param trustRef The trustRef for this evaluation
	@param result The result of the evaluation (See the SecTrust documentation).
	@param evaluateContext user defined.
	@result A SecTrustResultType.  Return the value passed in result if you
			do not want to change the evaluation result.
*/

typedef SecTrustResultType(*SecureDownloadTrustEvaluateCallback)
			(SecTrustRef trustRef, SecTrustResultType result,
			 void *evaluateContext);

/*!
	@function SecureDownloadCreateWithTicket
	@abstract Create a SecureDownloadRef for use during the Secure Download process.
	@param ticket The download ticket.
	@param setupCallback Called before trust is verified for each signer of the ticket.
						 This allows the user to modify the SecTrustRef if needed
						 (see the SecTrust documentation).  Returns a SecureDownloadTrustCallbackResult (see).
	@param setupContext User defined.  Passed as a parameter to the setupCallback.
	@param evaluateCallback Called after SecTrustEvaluate has been called for a
							signer if the result was not trusted. This allows
							the developer to query the user as to whether or not
							to trust the signer.  Returns a SecTrustResultType
	@param evaluateContext User defined.  Passed as a parameter to the evaluate callback.
	@param downloadRef The returned reference.
	@result Returns errSecureDownloadInvalidTicket if the ticket was invalid.  Otherwise
			see "Security Error Codes" (SecBase.h).
.
*/

OSStatus SecureDownloadCreateWithTicket (CFDataRef ticket,
										 SecureDownloadTrustSetupCallback setup,
										 void* setupContext,
										 SecureDownloadTrustEvaluateCallback evaluate,
										 void* evaluateContext,
										 SecureDownloadRef* downloadRef);

/*!
	@function SecureDownloadCopyURLs
	@abstract Return a list of URL's from which the data can be downloaded.  The first
			  URL in the list is the preferred download location.  The other URL's are
			  backup locations in case earlier locations in the list could not be
			  accessed.
	@param downloadRef A SecureDownloadRef instance.
	@param urls On return, the list of URL's to download.  Format is a CFArray of CFURL's.
	@result A result code.  See "Security Error Codes" (SecBase.h).
*/

OSStatus SecureDownloadCopyURLs (SecureDownloadRef downloadRef, CFArrayRef* urls);

/*!
	@function SecureDownloadCopyName
	@abstract Return the printable name of this download ticket.
	@param downloadRef A SecureDownloadRef instance.
	@param name On output, the download name.
	@result A result code.  See "Security Error Codes" (SecBase.h).
*/

OSStatus SecureDownloadCopyName (SecureDownloadRef downloadRef, CFStringRef* name);

/*!
	@function SecureDownloadCopyCreationDate
	@abstract Return the date the downlooad ticket was created.
	@param downloadRef A SecureDownloadRef instance.
	@param name On output, the creation date.
	@result A result code.
*/

OSStatus SecureDownloadCopyCreationDate (SecureDownloadRef downloadRef, CFDateRef* date);

/*!
	@function SecureDownloadGetDownloadSize
	@abstract Return the size of the expected download.
	@param downloadRef A SecureDownloadRef instance.
	@param size On output, the size of the download.
	@result A result code.  See "Security Error Codes" (SecBase.h).
*/

OSStatus SecureDownloadGetDownloadSize (SecureDownloadRef downloadRef, SInt64 *downloadSize);

/*!
	@function SecureDownloadUpdateWithData
	@abstract Check data received during Secure Download for validity.
			  Call this function each time data is received.
	@param downloadRef A SecureDownloadRef instance.
	@param data The data to check.
	@result Returns errSecureDownloadInvalidDownload if data is invalid.  Otherwise
			see "Security Error Codes" (SecBase.h).
*/

OSStatus SecureDownloadUpdateWithData (SecureDownloadRef downloadRef, CFDataRef data);

/*!
	@function SecureDownloadFinished
	@abstract Concludes the secure download process.  Call this after all data has been received.
	@param downloadRef A SecureDownloadRef instance.
	@result Returns errSecureDownloadInvalidDownload if data is invalid.  Otherwise
			see "Security Error Codes" (SecBase.h).
*/

OSStatus SecureDownloadFinished (SecureDownloadRef downloadRef);

/*!
	@function SecureDownloadRelease
	@abstract Releases a SecureDownloadRef.
	@param downloadRef The SecureDownloadRef to release.
	@result A result code.  See "Security Error Codes" (SecBase.h).
*/

OSStatus SecureDownloadRelease (SecureDownloadRef downloadRef);

/*!
	@function SecureDownloadCopyTicketLocation
	@abstract Copies the ticket location from an x-securedownload URL.
	@param url The x-securedownload URL.
	@param ticketLocation On exit, the URL of the ticket.
	@result A result code.  See "Security Error Codes" (SecBase.h).
*/

OSStatus SecureDownloadCopyTicketLocation (CFURLRef url, CFURLRef *ticketLocation);

#if defined(__cplusplus)
};
#endif

#endif
