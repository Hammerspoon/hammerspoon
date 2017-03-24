/*
 * The contents of this file are subject to the Mozilla Public
 * License Version 1.1 (the "License"); you may not use this file
 * except in compliance with the License. You may obtain a copy of
 * the License at http://www.mozilla.org/MPL/
 * 
 * Software distributed under the License is distributed on an "AS
 * IS" basis, WITHOUT WARRANTY OF ANY KIND, either express or
 * implied. See the License for the specific language governing
 * rights and limitations under the License.
 * 
 * The Original Code is the Netscape security libraries.
 * 
 * The Initial Developer of the Original Code is Netscape
 * Communications Corporation.  Portions created by Netscape are 
 * Copyright (C) 1994-2000 Netscape Communications Corporation.  All
 * Rights Reserved.
 * 
 * Contributor(s):
 * 
 * Alternatively, the contents of this file may be used under the
 * terms of the GNU General Public License Version 2 or later (the
 * "GPL"), in which case the provisions of the GPL are applicable 
 * instead of those above.  If you wish to allow use of your 
 * version of this file only under the terms of the GPL and not to
 * allow others to use your version of this file under the MPL,
 * indicate your decision by deleting the provisions above and
 * replace them with the notice and other provisions required by
 * the GPL.  If you do not delete the provisions above, a recipient
 * may use your version of this file under either the MPL or the
 * GPL.
 */

/*
 * Types for encoding/decoding of ASN.1 using BER/DER (Basic/Distinguished
 * Encoding Rules).
 */

#ifndef _SEC_ASN1_TYPES_H_
#define _SEC_ASN1_TYPES_H_

#include <CoreFoundation/CFBase.h>		/* Boolean */
#include <sys/types.h>
#include <stdint.h>

#include <TargetConditionals.h>

#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wdeprecated-declarations"

#if TARGET_OS_EMBEDDED || TARGET_IPHONE_SIMULATOR
/* @@@ We need something that tells us which platform we are building
   for that let's us distinguish if we are doing an emulator build. */

typedef struct {
    size_t Length;
    uint8_t * __nullable Data;
} SecAsn1Item, SecAsn1Oid;

typedef struct {
    SecAsn1Oid algorithm;
    SecAsn1Item parameters;
} SecAsn1AlgId;

typedef struct {
    SecAsn1AlgId algorithm;
    SecAsn1Item subjectPublicKey;
} SecAsn1PubKeyInfo;

#else
#include <Security/cssmtype.h>
#include <Security/x509defs.h>

typedef CSSM_DATA SecAsn1Item;
typedef CSSM_OID SecAsn1Oid;
typedef CSSM_X509_ALGORITHM_IDENTIFIER SecAsn1AlgId;
typedef CSSM_X509_SUBJECT_PUBLIC_KEY_INFO SecAsn1PubKeyInfo;

#endif          

CF_ASSUME_NONNULL_BEGIN

/*
 * An array of these structures defines a BER/DER encoding for an object.
 *
 * The array usually starts with a dummy entry whose kind is SEC_ASN1_SEQUENCE;
 * such an array is terminated with an entry where kind == 0.  (An array
 * which consists of a single component does not require a second dummy
 * entry -- the array is only searched as long as previous component(s)
 * instruct it.)
 */
typedef struct SecAsn1Template_struct {
    /*
     * Kind of item being decoded/encoded, including tags and modifiers.
     */
    uint32_t kind;

    /*
     * This value is the offset from the base of the structure (i.e., the 
	 * (void *) passed as 'src' to SecAsn1EncodeItem, or the 'dst' argument
	 * passed to SecAsn1CoderRef()) to the field that holds the value being 
	 * decoded/encoded.
     */
    uint32_t offset;

    /*
     * When kind suggests it (e.g., SEC_ASN1_POINTER, SEC_ASN1_GROUP, 
	 * SEC_ASN1_INLINE, or a component that is *not* a SEC_ASN1_UNIVERSAL), 
	 * this points to a sub-template for nested encoding/decoding.
     * OR, iff SEC_ASN1_DYNAMIC is set, then this is a pointer to a pointer
     * to a function which will return the appropriate template when called
     * at runtime.  NOTE! that explicit level of indirection, which is
     * necessary because ANSI does not allow you to store a function
     * pointer directly as a "void *" so we must store it separately and
     * dereference it to get at the function pointer itself.
     */
    const void *sub;

    /*
     * In the first element of a template array, the value is the size
     * of the structure to allocate when this template is being referenced
     * by another template via SEC_ASN1_POINTER or SEC_ASN1_GROUP.
     * In all other cases, the value is ignored.
     */
    uint32_t size;
} SecAsn1Template;


/*
 * BER/DER values for ASN.1 identifier octets.
 */
#define SEC_ASN1_TAG_MASK		0xff

/*
 * BER/DER universal type tag numbers.
 */
#define SEC_ASN1_TAGNUM_MASK		0x1f
#define SEC_ASN1_BOOLEAN			0x01
#define SEC_ASN1_INTEGER			0x02
#define SEC_ASN1_BIT_STRING			0x03
#define SEC_ASN1_OCTET_STRING		0x04
#define SEC_ASN1_NULL				0x05
#define SEC_ASN1_OBJECT_ID			0x06
#define SEC_ASN1_OBJECT_DESCRIPTOR  0x07
/* External type and instance-of type   0x08 */
#define SEC_ASN1_REAL               0x09
#define SEC_ASN1_ENUMERATED			0x0a
#define SEC_ASN1_EMBEDDED_PDV       0x0b
#define SEC_ASN1_UTF8_STRING		0x0c
/* not used                         0x0d */
/* not used                         0x0e */
/* not used                         0x0f */
#define SEC_ASN1_SEQUENCE			0x10
#define SEC_ASN1_SET				0x11
#define SEC_ASN1_NUMERIC_STRING     0x12
#define SEC_ASN1_PRINTABLE_STRING	0x13
#define SEC_ASN1_T61_STRING			0x14
#define SEC_ASN1_VIDEOTEX_STRING	0x15
#define SEC_ASN1_IA5_STRING			0x16
#define SEC_ASN1_UTC_TIME			0x17
#define SEC_ASN1_GENERALIZED_TIME	0x18
#define SEC_ASN1_GRAPHIC_STRING		0x19
#define SEC_ASN1_VISIBLE_STRING		0x1a
#define SEC_ASN1_GENERAL_STRING		0x1b
#define SEC_ASN1_UNIVERSAL_STRING	0x1c
/* not used							0x1d */
#define SEC_ASN1_BMP_STRING			0x1e
#define SEC_ASN1_HIGH_TAG_NUMBER	0x1f
#define SEC_ASN1_TELETEX_STRING SEC_ASN1_T61_STRING

/*
 * Modifiers to type tags.  These are also specified by a/the
 * standard, and must not be changed.
 */
#define SEC_ASN1_METHOD_MASK		0x20
#define SEC_ASN1_PRIMITIVE			0x00
#define SEC_ASN1_CONSTRUCTED		0x20

#define SEC_ASN1_CLASS_MASK			0xc0
#define SEC_ASN1_UNIVERSAL			0x00
#define SEC_ASN1_APPLICATION		0x40
#define SEC_ASN1_CONTEXT_SPECIFIC	0x80
#define SEC_ASN1_PRIVATE			0xc0

/*
 * Our additions, used for templates.
 * These are not defined by any standard; the values are used internally only.
 * Just be careful to keep them out of the low 8 bits.
 */
#define SEC_ASN1_OPTIONAL	0x00100
#define SEC_ASN1_EXPLICIT	0x00200
#define SEC_ASN1_ANY		0x00400
#define SEC_ASN1_INLINE		0x00800
#define SEC_ASN1_POINTER	0x01000
#define SEC_ASN1_GROUP		0x02000	/* with SET or SEQUENCE means 
									 * SET OF or SEQUENCE OF */
#define SEC_ASN1_DYNAMIC	0x04000 /* subtemplate is found by calling
									 * a function at runtime */
#define SEC_ASN1_SKIP		0x08000 /* skip a field; only for decoding */
#define SEC_ASN1_INNER		0x10000	/* with ANY means capture the
									 * contents only (not the id, len,
									 * or eoc); only for decoding */
#define SEC_ASN1_SAVE		0x20000 /* stash away the encoded bytes first;
									 * only for decoding */
#define SEC_ASN1_SKIP_REST	0x80000	/* skip all following fields;
									 * only for decoding */
#define SEC_ASN1_CHOICE     0x100000 /* pick one from a template */

/* 
 * Indicate that a type SEC_ASN1_INTEGER is actually signed.
 * The default is unsigned, which causes a leading zero to be 
 * encoded if the MS bit of the source data is 1.
 */
#define SEC_ASN1_SIGNED_INT	0X800000
                                          
/* Shorthand/Aliases */
#define SEC_ASN1_SEQUENCE_OF	(SEC_ASN1_GROUP | SEC_ASN1_SEQUENCE)
#define SEC_ASN1_SET_OF			(SEC_ASN1_GROUP | SEC_ASN1_SET)
#define SEC_ASN1_ANY_CONTENTS	(SEC_ASN1_ANY | SEC_ASN1_INNER)

/*
 * Function used for SEC_ASN1_DYNAMIC.
 * "arg"  is a pointer to the top-level structure being encoded or
 *        decoded.
 *
 * "enc"  when true, means that we are encoding (false means decoding)
 *
 * "buf"  For decode only; points to the start of the decoded data for 
 *        the current template. Callee can use the tag at this location 
 *        to infer the returned template. Not used on encode.
 *
 * "len"  For decode only; the length of buf.
 *
 * "Dest" points to the template-specific item being decoded to 
 *        or encoded from. (This is as opposed to arg, which 
 *        points to the start of the struct associated with the 
 *        current array of templates). 
 */

typedef const SecAsn1Template * SecAsn1TemplateChooser(
	void *arg, 
	Boolean enc,
	const char *buf,
	size_t len,
	void *dest);

typedef SecAsn1TemplateChooser * SecAsn1TemplateChooserPtr;

CF_ASSUME_NONNULL_END

#pragma clang diagnostic pop

#endif /* _SEC_ASN1_TYPES_H_ */
