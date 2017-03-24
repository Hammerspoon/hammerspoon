/*
 * Copyright (c) 2003-2006,2008,2010-2012 Apple Inc. All Rights Reserved.
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
 *
 * SecAsn1Templates.h - Common ASN1 primitive templates for use with SecAsn1Coder.
 */

#ifndef	_SEC_ASN1_TEMPLATES_H_
#define _SEC_ASN1_TEMPLATES_H_

#include <Security/SecAsn1Types.h>

#ifdef  __cplusplus
extern "C" {
#endif

CF_ASSUME_NONNULL_BEGIN

/************************************************************************/

/*
 * Generic Templates
 * One for each of the simple types, plus a special one for ANY, plus:
 *	- a pointer to each one of those
 *	- a set of each one of those
 *	- a sequence of each one of those
 */

extern const SecAsn1Template kSecAsn1AnyTemplate[];
extern const SecAsn1Template kSecAsn1BitStringTemplate[];
extern const SecAsn1Template kSecAsn1BMPStringTemplate[];
extern const SecAsn1Template kSecAsn1BooleanTemplate[];
extern const SecAsn1Template kSecAsn1EnumeratedTemplate[];
extern const SecAsn1Template kSecAsn1GeneralizedTimeTemplate[];
extern const SecAsn1Template kSecAsn1IA5StringTemplate[];
extern const SecAsn1Template kSecAsn1IntegerTemplate[];
extern const SecAsn1Template kSecAsn1UnsignedIntegerTemplate[];
extern const SecAsn1Template kSecAsn1NullTemplate[];
extern const SecAsn1Template kSecAsn1ObjectIDTemplate[];
extern const SecAsn1Template kSecAsn1OctetStringTemplate[];
extern const SecAsn1Template kSecAsn1PrintableStringTemplate[];
extern const SecAsn1Template kSecAsn1T61StringTemplate[];
extern const SecAsn1Template kSecAsn1UniversalStringTemplate[];
extern const SecAsn1Template kSecAsn1UTCTimeTemplate[];
extern const SecAsn1Template kSecAsn1UTF8StringTemplate[];
extern const SecAsn1Template kSecAsn1VisibleStringTemplate[];
extern const SecAsn1Template kSecAsn1TeletexStringTemplate[];

extern const SecAsn1Template kSecAsn1PointerToAnyTemplate[];
extern const SecAsn1Template kSecAsn1PointerToBitStringTemplate[];
extern const SecAsn1Template kSecAsn1PointerToBMPStringTemplate[];
extern const SecAsn1Template kSecAsn1PointerToBooleanTemplate[];
extern const SecAsn1Template kSecAsn1PointerToEnumeratedTemplate[];
extern const SecAsn1Template kSecAsn1PointerToGeneralizedTimeTemplate[];
extern const SecAsn1Template kSecAsn1PointerToIA5StringTemplate[];
extern const SecAsn1Template kSecAsn1PointerToIntegerTemplate[];
extern const SecAsn1Template kSecAsn1PointerToNullTemplate[];
extern const SecAsn1Template kSecAsn1PointerToObjectIDTemplate[];
extern const SecAsn1Template kSecAsn1PointerToOctetStringTemplate[];
extern const SecAsn1Template kSecAsn1PointerToPrintableStringTemplate[];
extern const SecAsn1Template kSecAsn1PointerToT61StringTemplate[];
extern const SecAsn1Template kSecAsn1PointerToUniversalStringTemplate[];
extern const SecAsn1Template kSecAsn1PointerToUTCTimeTemplate[];
extern const SecAsn1Template kSecAsn1PointerToUTF8StringTemplate[];
extern const SecAsn1Template kSecAsn1PointerToVisibleStringTemplate[];
extern const SecAsn1Template kSecAsn1PointerToTeletexStringTemplate[];

extern const SecAsn1Template kSecAsn1SequenceOfAnyTemplate[];
extern const SecAsn1Template kSecAsn1SequenceOfBitStringTemplate[];
extern const SecAsn1Template kSecAsn1SequenceOfBMPStringTemplate[];
extern const SecAsn1Template kSecAsn1SequenceOfBooleanTemplate[];
extern const SecAsn1Template kSecAsn1SequenceOfEnumeratedTemplate[];
extern const SecAsn1Template kSecAsn1SequenceOfGeneralizedTimeTemplate[];
extern const SecAsn1Template kSecAsn1SequenceOfIA5StringTemplate[];
extern const SecAsn1Template kSecAsn1SequenceOfIntegerTemplate[];
extern const SecAsn1Template kSecAsn1SequenceOfNullTemplate[];
extern const SecAsn1Template kSecAsn1SequenceOfObjectIDTemplate[];
extern const SecAsn1Template kSecAsn1SequenceOfOctetStringTemplate[];
extern const SecAsn1Template kSecAsn1SequenceOfPrintableStringTemplate[];
extern const SecAsn1Template kSecAsn1SequenceOfT61StringTemplate[];
extern const SecAsn1Template kSecAsn1SequenceOfUniversalStringTemplate[];
extern const SecAsn1Template kSecAsn1SequenceOfUTCTimeTemplate[];
extern const SecAsn1Template kSecAsn1SequenceOfUTF8StringTemplate[];
extern const SecAsn1Template kSecAsn1SequenceOfVisibleStringTemplate[];
extern const SecAsn1Template kSecAsn1SequenceOfTeletexStringTemplate[];

extern const SecAsn1Template kSecAsn1SetOfAnyTemplate[];
extern const SecAsn1Template kSecAsn1SetOfBitStringTemplate[];
extern const SecAsn1Template kSecAsn1SetOfBMPStringTemplate[];
extern const SecAsn1Template kSecAsn1SetOfBooleanTemplate[];
extern const SecAsn1Template kSecAsn1SetOfEnumeratedTemplate[];
extern const SecAsn1Template kSecAsn1SetOfGeneralizedTimeTemplate[];
extern const SecAsn1Template kSecAsn1SetOfIA5StringTemplate[];
extern const SecAsn1Template kSecAsn1SetOfIntegerTemplate[];
extern const SecAsn1Template kSecAsn1SetOfNullTemplate[];
extern const SecAsn1Template kSecAsn1SetOfObjectIDTemplate[];
extern const SecAsn1Template kSecAsn1SetOfOctetStringTemplate[];
extern const SecAsn1Template kSecAsn1SetOfPrintableStringTemplate[];
extern const SecAsn1Template kSecAsn1SetOfT61StringTemplate[];
extern const SecAsn1Template kSecAsn1SetOfUniversalStringTemplate[];
extern const SecAsn1Template kSecAsn1SetOfUTCTimeTemplate[];
extern const SecAsn1Template kSecAsn1SetOfUTF8StringTemplate[];
extern const SecAsn1Template kSecAsn1SetOfVisibleStringTemplate[];
extern const SecAsn1Template kSecAsn1SetOfTeletexStringTemplate[];

/*
 * Template for skipping a subitem; only used when decoding.
 */
extern const SecAsn1Template kSecAsn1SkipTemplate[];

CF_ASSUME_NONNULL_END

#ifdef  __cplusplus
}
#endif

#endif	/* _SEC_ASN1_TEMPLATES_H_ */
