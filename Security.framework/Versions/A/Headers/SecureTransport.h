/*
 * Copyright (c) 1999-2002,2005-2016 Apple Inc. All Rights Reserved.
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

/*
 * SecureTransport.h - Public API for Apple SSL/TLS Implementation
 */

#ifndef _SECURITY_SECURETRANSPORT_H_
#define _SECURITY_SECURETRANSPORT_H_

/*
 * This file describes the public API for an implementation of the
 * Secure Socket Layer, V. 3.0, Transport Layer Security, V. 1.0 to V. 1.2
 * and Datagram Transport Layer Security V. 1.0
 *
 * There are no transport layer dependencies in this library;
 * it can be used with sockets, Open Transport, etc. Applications using
 * this library provide callback functions which do the actual I/O
 * on underlying network connections. Applications are also responsible
 * for setting up raw network connections; the application passes in
 * an opaque reference to the underlying (connected) entity at the
 * start of an SSL session in the form of an SSLConnectionRef.
 *
 * Some terminology:
 *
 * A "client" is the initiator of an SSL Session. The canonical example
 * of a client is a web browser, when it's talking to an https URL.
 *
 * A "server" is an entity which accepts requests for SSL sessions made
 * by clients. E.g., a secure web server.

 * An "SSL Session", or "session", is bounded by calls to SSLHandshake()
 * and SSLClose(). An "Active session" is in some state between these
 * two calls, inclusive.
 *
 * An SSL Session Context, or SSLContextRef, is an opaque reference in this
 * library to the state associated with one session. A SSLContextRef cannot
 * be reused for multiple sessions.
 */

#include <CoreFoundation/CFArray.h>
#include <Security/CipherSuite.h>
#include <Security/SecTrust.h>
#include <sys/types.h>
#include <Availability.h>

#ifdef __cplusplus
extern "C" {
#endif

CF_ASSUME_NONNULL_BEGIN
CF_IMPLICIT_BRIDGING_ENABLED

/***********************
 *** Common typedefs ***
 ***********************/

/* Opaque reference to an SSL session context */
struct                      SSLContext;
typedef struct CF_BRIDGED_TYPE(id) SSLContext *SSLContextRef;

/* Opaque reference to an I/O connection (socket, endpoint, etc.) */
typedef const void *		SSLConnectionRef;

/* SSL Protocol version */
typedef CF_ENUM(int, SSLProtocol) {
	kSSLProtocolUnknown = 0,                /* no protocol negotiated/specified; use default */
	kSSLProtocol3       = 2,				/* SSL 3.0 */
	kTLSProtocol1       = 4,				/* TLS 1.0 */
    kTLSProtocol11      = 7,				/* TLS 1.1 */
    kTLSProtocol12      = 8,				/* TLS 1.2 */
    kDTLSProtocol1      = 9,                /* DTLS 1.0 */

    /* DEPRECATED on iOS */
    kSSLProtocol2       = 1,				/* SSL 2.0 */
    kSSLProtocol3Only   = 3,                /* SSL 3.0 Only */
    kTLSProtocol1Only   = 5,                /* TLS 1.0 Only */
    kSSLProtocolAll     = 6,                /* All TLS supported protocols */

};

/* SSL session options */
typedef CF_ENUM(int, SSLSessionOption) {
	/*
	 * Set this option to enable returning from SSLHandshake (with a result of
	 * errSSLServerAuthCompleted) when the server authentication portion of the
	 * handshake is complete. This disable certificate verification and
	 * provides an opportunity to perform application-specific server
	 * verification before deciding to continue.
	 */
	kSSLSessionOptionBreakOnServerAuth = 0,
	/*
	 * Set this option to enable returning from SSLHandshake (with a result of
	 * errSSLClientCertRequested) when the server requests a client certificate.
	 */
	kSSLSessionOptionBreakOnCertRequested = 1,
    /*
     * This option is the same as kSSLSessionOptionBreakOnServerAuth but applies
     * to the case where SecureTransport is the server and the client has presented
     * its certificates allowing the server to verify whether these should be
     * allowed to authenticate.
     */
    kSSLSessionOptionBreakOnClientAuth = 2,
    /*
     * Enable/Disable TLS False Start
     * When enabled, False Start will only be performed if a adequate cipher-suite is
     * negotiated.
     */
    kSSLSessionOptionFalseStart = 3,
    /*
     * Enable/Disable 1/n-1 record splitting for BEAST attack mitigation.
     * When enabled, record splitting will only be performed for TLS 1.0 connections
     * using a block cipher.
     */
    kSSLSessionOptionSendOneByteRecord = 4,
    /*
     * Allow/Disallow server identity change on renegotiation. Disallow by default
     * to avoid Triple Handshake attack.
     */
    kSSLSessionOptionAllowServerIdentityChange = 5,
    /*
     * Enable fallback countermeasures. Use this option when retyring a SSL connection
     * with a lower protocol version because of failure to connect.
     */
    kSSLSessionOptionFallback = 6,
    /*
     * Set this option to break from a client hello in order to check for SNI
     */
    kSSLSessionOptionBreakOnClientHello = 7,
    /*
     * Set this option to Allow renegotations. False by default.
     */
    kSSLSessionOptionAllowRenegotiation = 8,

};

/* State of an SSLSession */
typedef CF_ENUM(int, SSLSessionState) {
	kSSLIdle,					/* no I/O performed yet */
	kSSLHandshake,				/* SSL handshake in progress */
	kSSLConnected,				/* Handshake complete, ready for normal I/O */
	kSSLClosed,					/* connection closed normally */
	kSSLAborted					/* connection aborted */
};

/*
 * Status of client certificate exchange (which is optional
 * for both server and client).
 */
typedef CF_ENUM(int, SSLClientCertificateState) {
	/* Server hasn't asked for a cert. Client hasn't sent one. */
	kSSLClientCertNone,
	/* Server has asked for a cert, but client didn't send it. */
	kSSLClientCertRequested,
	/*
	 * Server side: We asked for a cert, client sent one, we validated
	 *				it OK. App can inspect the cert via
	 *				SSLCopyPeerCertificates().
	 * Client side: server asked for one, we sent it.
	 */
	kSSLClientCertSent,
	/*
	 * Client sent a cert but failed validation. Server side only.
	 * Server app can inspect the cert via SSLCopyPeerCertificates().
	 */
	kSSLClientCertRejected
} ;

/*
 * R/W functions. The application using this library provides
 * these functions via SSLSetIOFuncs().
 *
 * Data's memory is allocated by caller; on entry to these two functions
 * the *length argument indicates both the size of the available data and the
 * requested byte count. Number of bytes actually transferred is returned in
 * *length.
 *
 * The application may configure the underlying connection to operate
 * in a non-blocking manner; in such a case, a read operation may
 * well return errSSLWouldBlock, indicating "I transferred less data than
 * you requested (maybe even zero bytes), nothing is wrong, except
 * requested I/O hasn't completed". This will be returned back up to
 * the application as a return from SSLRead(), SSLWrite(), SSLHandshake(),
 * etc.
 */
typedef OSStatus
(*SSLReadFunc) 				(SSLConnectionRef 	connection,
							 void 				*data, 			/* owned by
							 									 * caller, data
							 									 * RETURNED */
							 size_t 			*dataLength);	/* IN/OUT */
typedef OSStatus
(*SSLWriteFunc) 			(SSLConnectionRef 	connection,
							 const void 		*data,
							 size_t 			*dataLength);	/* IN/OUT */

/*************************************************
 *** OSStatus values unique to SecureTransport ***
 *************************************************/

/*
    Note: the comments that appear after these errors are used to create SecErrorMessages.strings.
    The comments must not be multi-line, and should be in a form meaningful to an end user. If
    a different or additional comment is needed, it can be put in the header doc format, or on a
    line that does not start with errZZZ.
*/

CF_ENUM(OSStatus) {
	errSSLProtocol				= -9800,	/* SSL protocol error */
	errSSLNegotiation			= -9801,	/* Cipher Suite negotiation failure */
	errSSLFatalAlert			= -9802,	/* Fatal alert */
	errSSLWouldBlock			= -9803,	/* I/O would block (not fatal) */
    errSSLSessionNotFound 		= -9804,	/* attempt to restore an unknown session */
    errSSLClosedGraceful 		= -9805,	/* connection closed gracefully */
    errSSLClosedAbort 			= -9806,	/* connection closed via error */
    errSSLXCertChainInvalid 	= -9807,	/* invalid certificate chain */
    errSSLBadCert				= -9808,	/* bad certificate format */
	errSSLCrypto				= -9809,	/* underlying cryptographic error */
	errSSLInternal				= -9810,	/* Internal error */
	errSSLModuleAttach			= -9811,	/* module attach failure */
    errSSLUnknownRootCert		= -9812,	/* valid cert chain, untrusted root */
    errSSLNoRootCert			= -9813,	/* cert chain not verified by root */
	errSSLCertExpired			= -9814,	/* chain had an expired cert */
	errSSLCertNotYetValid		= -9815,	/* chain had a cert not yet valid */
	errSSLClosedNoNotify		= -9816,	/* server closed session with no notification */
	errSSLBufferOverflow		= -9817,	/* insufficient buffer provided */
	errSSLBadCipherSuite		= -9818,	/* bad SSLCipherSuite */

	/* fatal errors detected by peer */
	errSSLPeerUnexpectedMsg		= -9819,	/* unexpected message received */
	errSSLPeerBadRecordMac		= -9820,	/* bad MAC */
	errSSLPeerDecryptionFail	= -9821,	/* decryption failed */
	errSSLPeerRecordOverflow	= -9822,	/* record overflow */
	errSSLPeerDecompressFail	= -9823,	/* decompression failure */
	errSSLPeerHandshakeFail		= -9824,	/* handshake failure */
	errSSLPeerBadCert			= -9825,	/* misc. bad certificate */
	errSSLPeerUnsupportedCert	= -9826,	/* bad unsupported cert format */
	errSSLPeerCertRevoked		= -9827,	/* certificate revoked */
	errSSLPeerCertExpired		= -9828,	/* certificate expired */
	errSSLPeerCertUnknown		= -9829,	/* unknown certificate */
	errSSLIllegalParam			= -9830,	/* illegal parameter */
	errSSLPeerUnknownCA 		= -9831,	/* unknown Cert Authority */
	errSSLPeerAccessDenied		= -9832,	/* access denied */
	errSSLPeerDecodeError		= -9833,	/* decoding error */
	errSSLPeerDecryptError		= -9834,	/* decryption error */
	errSSLPeerExportRestriction	= -9835,	/* export restriction */
	errSSLPeerProtocolVersion	= -9836,	/* bad protocol version */
	errSSLPeerInsufficientSecurity = -9837,	/* insufficient security */
	errSSLPeerInternalError		= -9838,	/* internal error */
	errSSLPeerUserCancelled		= -9839,	/* user canceled */
	errSSLPeerNoRenegotiation	= -9840,	/* no renegotiation allowed */

	/* non-fatal result codes */
	errSSLPeerAuthCompleted     = -9841,    /* peer cert is valid, or was ignored if verification disabled */
	errSSLClientCertRequested	= -9842,	/* server has requested a client cert */

	/* more errors detected by us */
	errSSLHostNameMismatch		= -9843,	/* peer host name mismatch */
	errSSLConnectionRefused		= -9844,	/* peer dropped connection before responding */
	errSSLDecryptionFail		= -9845,	/* decryption failure */
	errSSLBadRecordMac			= -9846,	/* bad MAC */
	errSSLRecordOverflow		= -9847,	/* record overflow */
	errSSLBadConfiguration		= -9848,	/* configuration error */
	errSSLUnexpectedRecord      = -9849,	/* unexpected (skipped) record in DTLS */
    errSSLWeakPeerEphemeralDHKey = -9850,	/* weak ephemeral dh key  */

    /* non-fatal result codes */
    errSSLClientHelloReceived   = -9851,    /* SNI */
};

/* DEPRECATED aliases for errSSLPeerAuthCompleted */
#define errSSLServerAuthCompleted	errSSLPeerAuthCompleted
#define errSSLClientAuthCompleted	errSSLPeerAuthCompleted

/* DEPRECATED alias for the end of the error range */
#define errSSLLast errSSLUnexpectedRecord

typedef CF_ENUM(int, SSLProtocolSide)
{
    kSSLServerSide,
    kSSLClientSide
};

typedef CF_ENUM(int, SSLConnectionType)
{
    kSSLStreamType,
    kSSLDatagramType
};

/*
 * Predefined TLS configurations constants
 */

/* Default configuration - currently same as kSSLSessionConfig_standard */
extern const CFStringRef kSSLSessionConfig_default;
/* ATS v1 Config: TLS v1.2, only PFS ciphersuites */
extern const CFStringRef kSSLSessionConfig_ATSv1;
/* ATS v1 Config without PFS: TLS v1.2, include non PFS ciphersuites */
extern const CFStringRef kSSLSessionConfig_ATSv1_noPFS;
/* TLS v1.2 to TLS v1.0, with default ciphersuites (no RC4) */
extern const CFStringRef kSSLSessionConfig_standard;
/* TLS v1.2 to TLS v1.0, with defaults ciphersuites + RC4 */
extern const CFStringRef kSSLSessionConfig_RC4_fallback;
/* TLS v1.0 only, with defaults ciphersuites + fallback SCSV */
extern const CFStringRef kSSLSessionConfig_TLSv1_fallback;
/* TLS v1.0, with defaults ciphersuites + RC4 + fallback SCSV */
extern const CFStringRef kSSLSessionConfig_TLSv1_RC4_fallback;
/* TLS v1.2 to TLS v1.0, defaults + RC4 + DHE ciphersuites */
extern const CFStringRef kSSLSessionConfig_legacy;
/* TLS v1.2 to TLS v1.0, defaults + RC4 + DHE ciphersuites */
extern const CFStringRef kSSLSessionConfig_legacy_DHE;
/* TLS v1.2, anonymous ciphersuites only */
extern const CFStringRef kSSLSessionConfig_anonymous;


/******************
 *** Public API ***
 ******************/

/*
 * Secure Transport APIs require a SSLContextRef, which is an opaque
 * reference to the SSL session and its parameters. On Mac OS X 10.7
 * and earlier versions, a new context is created using SSLNewContext,
 * and is disposed by calling SSLDisposeContext.
 *
 * On i0S 5.0 and later, as well as Mac OS X versions after 10.7, the
 * SSLContextRef is a true CFType object with retain-release semantics.
 * New code should create a new context using SSLCreateContext (instead
 * of SSLNewContext), and dispose the context by calling CFRelease
 * (instead of SSLDisposeContext) when finished with it.
 */

/*
 * Return the CFTypeID for SSLContext objects.
 */
CFTypeID
SSLContextGetTypeID(void)
	__OSX_AVAILABLE_STARTING(__MAC_10_8, __IPHONE_5_0);

/*
 * Create a new instance of an SSLContextRef using the specified allocator.
 */
__nullable
SSLContextRef
SSLCreateContext(CFAllocatorRef __nullable alloc, SSLProtocolSide protocolSide, SSLConnectionType connectionType)
	__OSX_AVAILABLE_STARTING(__MAC_10_8, __IPHONE_5_0);


#if (TARGET_OS_MAC && !(TARGET_OS_EMBEDDED || TARGET_OS_IPHONE))
/*
 * Create a new session context.
 *
 * ==========================
 * MAC OS X ONLY (DEPRECATED)
 * ==========================
 * NOTE: this function is not available on iOS, and should be considered
 * deprecated on Mac OS X. Your code should use SSLCreateContext instead.
 */
OSStatus
SSLNewContext				(Boolean 			isServer,
							 SSLContextRef 		* __nonnull CF_RETURNS_RETAINED contextPtr)	/* RETURNED */
	__OSX_AVAILABLE_BUT_DEPRECATED(__MAC_10_2,__MAC_10_9,__IPHONE_NA,__IPHONE_NA);

/*
 * Dispose of a session context.
 *
 * ==========================
 * MAC OS X ONLY (DEPRECATED)
 * ==========================
 * NOTE: this function is not available on iOS, and should be considered
 * deprecated on Mac OS X. Your code should use CFRelease to dispose a session
 * created with SSLCreateContext.
 */
OSStatus
SSLDisposeContext			(SSLContextRef		context)
	__OSX_AVAILABLE_BUT_DEPRECATED(__MAC_10_2,__MAC_10_9,__IPHONE_NA,__IPHONE_NA);

#endif /* MAC OS X */

/*
 * Determine the state of an SSL/DTLS session.
 */
OSStatus
SSLGetSessionState			(SSLContextRef		context,
							 SSLSessionState	*state)		/* RETURNED */
	__OSX_AVAILABLE_STARTING(__MAC_10_2, __IPHONE_5_0);

/*
 * Set options for an SSL session. Must be called prior to SSLHandshake();
 * subsequently cannot be called while session is active.
 */
OSStatus
SSLSetSessionOption			(SSLContextRef		context,
							 SSLSessionOption	option,
							 Boolean			value)
	__OSX_AVAILABLE_STARTING(__MAC_10_6, __IPHONE_5_0);

/*
 * Determine current value for the specified option in a given SSL session.
 */
OSStatus
SSLGetSessionOption			(SSLContextRef		context,
							 SSLSessionOption	option,
							 Boolean			*value)
	__OSX_AVAILABLE_STARTING(__MAC_10_6, __IPHONE_5_0);

/********************************************************************
 *** Session context configuration, common to client and servers. ***
 ********************************************************************/

/*
 * Specify functions which do the network I/O. Must be called prior
 * to SSLHandshake(); subsequently cannot be called while a session is
 * active.
 */
OSStatus
SSLSetIOFuncs				(SSLContextRef		context,
							 SSLReadFunc 		readFunc,
							 SSLWriteFunc		writeFunc)
	__OSX_AVAILABLE_STARTING(__MAC_10_2, __IPHONE_5_0);


/*
 * Set a predefined configuration for the SSL Session
 *
 * This currently affect enabled protocol versions,
 * enabled ciphersuites, and the kSSLSessionOptionFallback
 * session option.
 */
OSStatus
SSLSetSessionConfig(SSLContextRef context,
                    CFStringRef config)
    __OSX_AVAILABLE_STARTING(__MAC_10_12, __IPHONE_10_0);

/*
 * Set the minimum SSL protocol version allowed. Optional.
 * The default is the lower supported protocol.
 *
 * This can only be called when no session is active.
 *
 * For TLS contexts, legal values for minVersion are :
 *		kSSLProtocol3
 * 		kTLSProtocol1
 * 		kTLSProtocol11
 * 		kTLSProtocol12
 *
 * For DTLS contexts, legal values for minVersion are :
 *      kDTLSProtocol1
 */
OSStatus
SSLSetProtocolVersionMin  (SSLContextRef      context,
                           SSLProtocol        minVersion)
    __OSX_AVAILABLE_STARTING(__MAC_10_8, __IPHONE_5_0);

/*
 * Get minimum protocol version allowed
 */
OSStatus
SSLGetProtocolVersionMin  (SSLContextRef      context,
                           SSLProtocol        *minVersion)
    __OSX_AVAILABLE_STARTING(__MAC_10_8, __IPHONE_5_0);

/*
 * Set the maximum SSL protocol version allowed. Optional.
 * The default is the highest supported protocol.
 *
 * This can only be called when no session is active.
 *
 * For TLS contexts, legal values for maxVersion are :
 *		kSSLProtocol3
 * 		kTLSProtocol1
 * 		kTLSProtocol11
 * 		kTLSProtocol12
 *
 * For DTLS contexts, legal values for maxVersion are :
 *      kDTLSProtocol1
 */
OSStatus
SSLSetProtocolVersionMax  (SSLContextRef      context,
                           SSLProtocol        maxVersion)
    __OSX_AVAILABLE_STARTING(__MAC_10_8, __IPHONE_5_0);

/*
 * Get maximum protocol version allowed
 */
OSStatus
SSLGetProtocolVersionMax  (SSLContextRef      context,
                           SSLProtocol        *maxVersion)
    __OSX_AVAILABLE_STARTING(__MAC_10_8, __IPHONE_5_0);


#if (TARGET_OS_MAC && !(TARGET_OS_EMBEDDED || TARGET_OS_IPHONE))
/*
 * Set allowed SSL protocol versions. Optional.
 * Specifying kSSLProtocolAll for SSLSetProtocolVersionEnabled results in
 * specified 'enable' boolean to be applied to all supported protocols.
 * The default is "all supported protocols are enabled".
 * This can only be called when no session is active.
 *
 * Legal values for protocol are :
 *		kSSLProtocol2
 *		kSSLProtocol3
 * 		kTLSProtocol1
 *		kSSLProtocolAll
 *
 * ==========================
 * MAC OS X ONLY (DEPRECATED)
 * ==========================
 * NOTE: this function is not available on iOS, and should be considered
 * deprecated on Mac OS X. You can use SSLSetProtocolVersionMin and/or
 * SSLSetProtocolVersionMax to specify which protocols are enabled.
 */
OSStatus
SSLSetProtocolVersionEnabled (SSLContextRef 	context,
							 SSLProtocol		protocol,
							 Boolean			enable)
	__OSX_AVAILABLE_BUT_DEPRECATED(__MAC_10_2,__MAC_10_9,__IPHONE_NA,__IPHONE_NA);

/*
 * Obtain a value specified in SSLSetProtocolVersionEnabled.
 *
 * ==========================
 * MAC OS X ONLY (DEPRECATED)
 * ==========================
 * NOTE: this function is not available on iOS, and should be considered
 * deprecated on Mac OS X. You can use SSLGetProtocolVersionMin and/or
 * SSLGetProtocolVersionMax to check whether a protocol is enabled.
 */
OSStatus
SSLGetProtocolVersionEnabled(SSLContextRef 		context,
							 SSLProtocol		protocol,
							 Boolean			*enable)	/* RETURNED */
	__OSX_AVAILABLE_BUT_DEPRECATED(__MAC_10_2,__MAC_10_9,__IPHONE_NA,__IPHONE_NA);

/*
 * Get/set SSL protocol version; optional. Default is kSSLProtocolUnknown,
 * in which case the highest possible version is attempted, but a lower
 * version is accepted if the peer requires it.
 * SSLSetProtocolVersion cannot be called when a session is active.
 *
 * ==========================
 * MAC OS X ONLY (DEPRECATED)
 * ==========================
 * NOTE: this function is not available on iOS, and deprecated on Mac OS X 10.8.
 * Use SSLSetProtocolVersionMin and/or SSLSetProtocolVersionMax to specify
 * which protocols are enabled.
 */
OSStatus
SSLSetProtocolVersion		(SSLContextRef 		context,
							 SSLProtocol		version)
	__OSX_AVAILABLE_BUT_DEPRECATED(__MAC_10_2,__MAC_10_8,__IPHONE_NA,__IPHONE_NA);

/*
 * Obtain the protocol version specified in SSLSetProtocolVersion.
 * If SSLSetProtocolVersionEnabled() has been called for this session,
 * SSLGetProtocolVersion() may return errSecParam if the protocol enable
 * state can not be represented by the SSLProtocol enums (e.g.,
 * SSL2 and TLS1 enabled, SSL3 disabled).
 *
 * ==========================
 * MAC OS X ONLY (DEPRECATED)
 * ==========================
 * NOTE: this function is not available on iOS, and deprecated on Mac OS X 10.8.
 * Use SSLGetProtocolVersionMin and/or SSLGetProtocolVersionMax to check
 * whether a protocol is enabled.
 */
OSStatus
SSLGetProtocolVersion		(SSLContextRef		context,
							 SSLProtocol		*protocol)	/* RETURNED */
	__OSX_AVAILABLE_BUT_DEPRECATED(__MAC_10_2,__MAC_10_8,__IPHONE_NA,__IPHONE_NA);

#endif /* MAC OS X */

/*
 * Specify this connection's certificate(s). This is mandatory for
 * server connections, optional for clients. Specifying a certificate
 * for a client enables SSL client-side authentication. The end-entity
 * cert is in certRefs[0]. Specifying a root cert is optional; if it's
 * not specified, the root cert which verifies the cert chain specified
 * here must be present in the system-wide set of trusted anchor certs.
 *
 * The certRefs argument is a CFArray containing SecCertificateRefs,
 * except for certRefs[0], which is a SecIdentityRef.
 *
 * Must be called prior to SSLHandshake(), or immediately after
 * SSLHandshake has returned errSSLClientCertRequested (i.e. before the
 * handshake is resumed by calling SSLHandshake again.)
 *
 * SecureTransport assumes the following:
 *
 *  -- The certRef references remain valid for the lifetime of the session.
 *  -- The certificate specified in certRefs[0] is capable of signing.
 *  -- The required capabilities of the certRef[0], and of the optional cert
 *     specified in SSLSetEncryptionCertificate (see below), are highly
 *     dependent on the application. For example, to work as a server with
 *     Netscape clients, the cert specified here must be capable of both
 *     signing and encrypting.
 */
OSStatus
SSLSetCertificate			(SSLContextRef		context,
							 CFArrayRef			_Nullable certRefs)
	__OSX_AVAILABLE_STARTING(__MAC_10_2, __IPHONE_5_0);

/*
 * Specify I/O connection - a socket, endpoint, etc., which is
 * managed by caller. On the client side, it's assumed that communication
 * has been established with the desired server on this connection.
 * On the server side, it's assumed that an incoming client request
 * has been established.
 *
 * Must be called prior to SSLHandshake(); subsequently can only be
 * called when no session is active.
 */
OSStatus
SSLSetConnection			(SSLContextRef                  context,
							 SSLConnectionRef __nullable	connection)
	__OSX_AVAILABLE_STARTING(__MAC_10_2, __IPHONE_5_0);

OSStatus
SSLGetConnection			(SSLContextRef		context,
							 SSLConnectionRef	* __nonnull CF_RETURNS_NOT_RETAINED connection)
	__OSX_AVAILABLE_STARTING(__MAC_10_2, __IPHONE_5_0);

/*
 * Specify the fully qualified doman name of the peer, e.g., "store.apple.com."
 * Optional; used to verify the common name field in peer's certificate.
 * Name is in the form of a C string; NULL termination optional, i.e.,
 * peerName[peerNameLen+1] may or may not have a NULL. In any case peerNameLen
 * is the number of bytes of the peer domain name.
 */
OSStatus
SSLSetPeerDomainName		(SSLContextRef		context,
							 const char			* __nullable peerName,
							 size_t				peerNameLen)
	__OSX_AVAILABLE_STARTING(__MAC_10_2, __IPHONE_5_0);

/*
 * Determine the buffer size needed for SSLGetPeerDomainName().
 */
OSStatus
SSLGetPeerDomainNameLength	(SSLContextRef		context,
							 size_t				*peerNameLen)	// RETURNED
	__OSX_AVAILABLE_STARTING(__MAC_10_2, __IPHONE_5_0);

/*
 * Obtain the value specified in SSLSetPeerDomainName().
 */
OSStatus
SSLGetPeerDomainName		(SSLContextRef		context,
							 char				*peerName,		// returned here
							 size_t				*peerNameLen)	// IN/OUT
	__OSX_AVAILABLE_STARTING(__MAC_10_2, __IPHONE_5_0);


/*
 * Determine the buffer size needed for SSLCopyRequestedPeerNameLength().
 */
OSStatus
SSLCopyRequestedPeerName    (SSLContextRef      context,
                             char               *peerName,
                             size_t             *peerNameLen)
    __OSX_AVAILABLE_STARTING(__MAC_10_11, __IPHONE_9_0);

/*
 * Server Only: obtain the hostname specified by the client in the ServerName extension (SNI)
 */
OSStatus
SSLCopyRequestedPeerNameLength  (SSLContextRef  ctx,
                                 size_t         *peerNameLen)
    __OSX_AVAILABLE_STARTING(__MAC_10_11, __IPHONE_9_0);


/*
 * Specify the Datagram TLS Hello Cookie.
 * This is to be called for server side only and is optional.
 * The default is a zero len cookie. The maximum cookieLen is 32 bytes.
 */
OSStatus
SSLSetDatagramHelloCookie	(SSLContextRef		dtlsContext,
                             const void         * __nullable cookie,
                             size_t             cookieLen)
	__OSX_AVAILABLE_STARTING(__MAC_10_8, __IPHONE_5_0);

/*
 * Specify the maximum record size, including all DTLS record headers.
 * This should be set appropriately to avoid fragmentation
 * of Datagrams during handshake, as fragmented datagrams may
 * be dropped by some network.
 * This is for Datagram TLS only
 */
OSStatus
SSLSetMaxDatagramRecordSize (SSLContextRef		dtlsContext,
                             size_t             maxSize)
	__OSX_AVAILABLE_STARTING(__MAC_10_8, __IPHONE_5_0);

/*
 * Get the maximum record size, including all Datagram TLS record headers.
 * This is for Datagram TLS only
 */
OSStatus
SSLGetMaxDatagramRecordSize (SSLContextRef		dtlsContext,
                             size_t             *maxSize)
	__OSX_AVAILABLE_STARTING(__MAC_10_8, __IPHONE_5_0);

/*
 * Obtain the actual negotiated protocol version of the active
 * session, which may be different that the value specified in
 * SSLSetProtocolVersion(). Returns kSSLProtocolUnknown if no
 * SSL session is in progress.
 */
OSStatus
SSLGetNegotiatedProtocolVersion		(SSLContextRef		context,
									 SSLProtocol		*protocol)	/* RETURNED */
	__OSX_AVAILABLE_STARTING(__MAC_10_2, __IPHONE_5_0);

/*
 * Determine number and values of all of the SSLCipherSuites we support.
 * Caller allocates output buffer for SSLGetSupportedCiphers() and passes in
 * its size in *numCiphers. If supplied buffer is too small, errSSLBufferOverflow
 * will be returned.
 */
OSStatus
SSLGetNumberSupportedCiphers (SSLContextRef			context,
							  size_t				*numCiphers)
	__OSX_AVAILABLE_STARTING(__MAC_10_2, __IPHONE_5_0);

OSStatus
SSLGetSupportedCiphers		 (SSLContextRef			context,
							  SSLCipherSuite		*ciphers,		/* RETURNED */
							  size_t				*numCiphers)	/* IN/OUT */
	__OSX_AVAILABLE_STARTING(__MAC_10_2, __IPHONE_5_0);

/*
 * Specify a (typically) restricted set of SSLCipherSuites to be enabled by
 * the current SSLContext. Can only be called when no session is active. Default
 * set of enabled SSLCipherSuites is the same as the complete set of supported
 * SSLCipherSuites as obtained by SSLGetSupportedCiphers().
 */
OSStatus
SSLSetEnabledCiphers		(SSLContextRef			context,
							 const SSLCipherSuite	*ciphers,
							 size_t					numCiphers)
	__OSX_AVAILABLE_STARTING(__MAC_10_2, __IPHONE_5_0);

/*
 * Determine number and values of all of the SSLCipherSuites currently enabled.
 * Caller allocates output buffer for SSLGetEnabledCiphers() and passes in
 * its size in *numCiphers. If supplied buffer is too small, errSSLBufferOverflow
 * will be returned.
 */
OSStatus
SSLGetNumberEnabledCiphers 	(SSLContextRef			context,
							 size_t					*numCiphers)
	__OSX_AVAILABLE_STARTING(__MAC_10_2, __IPHONE_5_0);

OSStatus
SSLGetEnabledCiphers		(SSLContextRef			context,
							 SSLCipherSuite			*ciphers,		/* RETURNED */
							 size_t					*numCiphers)	/* IN/OUT */
	__OSX_AVAILABLE_STARTING(__MAC_10_2, __IPHONE_5_0);


#if (TARGET_OS_MAC && !(TARGET_OS_EMBEDDED || TARGET_OS_IPHONE))
/*
 * Enable/disable peer certificate chain validation. Default is enabled.
 * If caller disables, it is the caller's responsibility to call
 * SSLCopyPeerCertificates() upon successful completion of the handshake
 * and then to perform external validation of the peer certificate
 * chain before proceeding with data transfer.
 *
 * ==========================
 * MAC OS X ONLY (DEPRECATED)
 * ==========================
 * NOTE: this function is not available on iOS, and should be considered
 * deprecated on Mac OS X. To disable peer certificate chain validation, you
 * can instead use SSLSetSessionOption to set kSSLSessionOptionBreakOnServerAuth
 * to true. This will disable verification and cause SSLHandshake to return with
 * an errSSLServerAuthCompleted result when the peer certificates have been
 * received; at that time, you can choose to evaluate peer trust yourself, or
 * simply call SSLHandshake again to proceed with the handshake.
 */
OSStatus
SSLSetEnableCertVerify		(SSLContextRef 			context,
							 Boolean				enableVerify)
	__OSX_AVAILABLE_BUT_DEPRECATED(__MAC_10_2,__MAC_10_9,__IPHONE_NA,__IPHONE_NA);

/*
 * Check whether peer certificate chain validation is enabled.
 *
 * ==========================
 * MAC OS X ONLY (DEPRECATED)
 * ==========================
 * NOTE: this function is not available on iOS, and should be considered
 * deprecated on Mac OS X. To check whether peer certificate chain validation
 * is enabled in a context, call SSLGetSessionOption to obtain the value of
 * the kSSLSessionOptionBreakOnServerAuth session option flag. If the value
 * of this option flag is true, then verification is disabled.
 */
OSStatus
SSLGetEnableCertVerify		(SSLContextRef 			context,
							 Boolean				*enableVerify)	/* RETURNED */
	__OSX_AVAILABLE_BUT_DEPRECATED(__MAC_10_2,__MAC_10_9,__IPHONE_NA,__IPHONE_NA);

/*
 * Specify the option of ignoring certificates' "expired" times.
 * This is a common failure in the real SSL world. Default setting for this
 * flag is false, meaning expired certs result in an errSSLCertExpired error.
 *
 * ==========================
 * MAC OS X ONLY (DEPRECATED)
 * ==========================
 * NOTE: this function is not available on iOS, and should be considered
 * deprecated on Mac OS X. To ignore expired certificate errors, first disable
 * Secure Transport's automatic verification of peer certificates by calling
 * SSLSetSessionOption to set kSSLSessionOptionBreakOnServerAuth to true. When
 * SSLHandshake subsequently returns an errSSLServerAuthCompleted result,
 * your code should obtain the SecTrustRef for the peer's certificates and
 * perform a custom trust evaluation with SecTrust APIs (see SecTrust.h).
 * The SecTrustSetOptions function allows you to specify that the expiration
 * status of certificates should be ignored for this evaluation.
 *
 * Example:
 *
 *	status = SSLSetSessionOption(ctx, kSSLSessionOptionBreakOnServerAuth, true);
 *	do {
 *		status = SSLHandshake(ctx);
 *
 *		if (status == errSSLServerAuthCompleted) {
 *			SecTrustRef peerTrust = NULL;
 *			status = SSLCopyPeerTrust(ctx, &peerTrust);
 *			if (status == errSecSuccess) {
 *				SecTrustResultType trustResult;
 *				// set flag to allow expired certificates
 *				SecTrustSetOptions(peerTrust, kSecTrustOptionAllowExpired);
 *				status = SecTrustEvaluate(peerTrust, &trustResult);
 *				if (status == errSecSuccess) {
 *					// A "proceed" result means the cert is explicitly trusted,
 *					// e.g. "Always Trust" was clicked;
 *					// "Unspecified" means the cert has no explicit trust settings,
 *					// but is implicitly OK since it chains back to a trusted root.
 *					// Any other result means the cert is not trusted.
 *					//
 *					if (trustResult == kSecTrustResultProceed ||
 *						trustResult == kSecTrustResultUnspecified) {
 *						// certificate is trusted
 *						status = errSSLWouldBlock; // so we call SSLHandshake again
 *					} else if (trustResult == kSecTrustResultRecoverableTrustFailure) {
 *						// not trusted, for some reason other than being expired;
 *						// could ask the user whether to allow the connection here
 *						//
 *						status = errSSLXCertChainInvalid;
 *					} else {
 *						// cannot use this certificate (fatal)
 *						status = errSSLBadCert;
 *					}
 *				}
 *				if (peerTrust) {
 *					CFRelease(peerTrust);
 *				}
 *			}
 *		} // errSSLServerAuthCompleted
 *
 *	} while (status == errSSLWouldBlock);
 *
 */
OSStatus
SSLSetAllowsExpiredCerts	(SSLContextRef		context,
							 Boolean			allowsExpired)
	__OSX_AVAILABLE_BUT_DEPRECATED(__MAC_10_2,__MAC_10_9,__IPHONE_NA,__IPHONE_NA);

/*
 * Obtain the current value of an SSLContext's "allowExpiredCerts" flag.
 *
 * ==========================
 * MAC OS X ONLY (DEPRECATED)
 * ==========================
 * NOTE: this function is not available on iOS, and should be considered
 * deprecated on Mac OS X.
 */
OSStatus
SSLGetAllowsExpiredCerts	(SSLContextRef		context,
							 Boolean			*allowsExpired)	/* RETURNED */
	__OSX_AVAILABLE_BUT_DEPRECATED(__MAC_10_2,__MAC_10_9,__IPHONE_NA,__IPHONE_NA);

/*
 * Similar to SSLSetAllowsExpiredCerts, SSLSetAllowsExpiredRoots allows the
 * option of ignoring "expired" status for root certificates only.
 * Default setting is false, i.e., expired root certs result in an
 * errSSLCertExpired error.
 *
 * ==========================
 * MAC OS X ONLY (DEPRECATED)
 * ==========================
 * NOTE: this function is not available on iOS, and should be considered
 * deprecated on Mac OS X. To ignore expired certificate errors, first disable
 * Secure Transport's automatic verification of peer certificates by calling
 * SSLSetSessionOption to set kSSLSessionOptionBreakOnServerAuth to true. When
 * SSLHandshake subsequently returns an errSSLServerAuthCompleted result,
 * your code should obtain the SecTrustRef for the peer's certificates and
 * perform a custom trust evaluation with SecTrust APIs (see SecTrust.h).
 * The SecTrustSetOptions function allows you to specify that the expiration
 * status of certificates should be ignored for this evaluation.
 *
 * See the description of the SSLSetAllowsExpiredCerts function (above)
 * for a code example. The kSecTrustOptionAllowExpiredRoot option can be used
 * instead of kSecTrustOptionAllowExpired to allow expired roots only.
 */
OSStatus
SSLSetAllowsExpiredRoots	(SSLContextRef		context,
							 Boolean			allowsExpired)
	__OSX_AVAILABLE_BUT_DEPRECATED(__MAC_10_2,__MAC_10_9,__IPHONE_NA,__IPHONE_NA);

/*
 * Obtain the current value of an SSLContext's "allow expired roots" flag.
 *
 * ==========================
 * MAC OS X ONLY (DEPRECATED)
 * ==========================
 * NOTE: this function is not available on iOS, and should be considered
 * deprecated on Mac OS X.
 */
OSStatus
SSLGetAllowsExpiredRoots	(SSLContextRef		context,
							 Boolean			*allowsExpired)	/* RETURNED */
	__OSX_AVAILABLE_BUT_DEPRECATED(__MAC_10_2,__MAC_10_9,__IPHONE_NA,__IPHONE_NA);

/*
 * Specify option of allowing for an unknown root cert, i.e., one which
 * this software can not verify as one of a list of known good root certs.
 * Default for this flag is false, in which case one of the following two
 * errors may occur:
 *    -- The peer returns a cert chain with a root cert, and the chain
 *       verifies to that root, but the root is not one of our trusted
 *       roots. This results in errSSLUnknownRootCert on handshake.
 *    -- The peer returns a cert chain which does not contain a root cert,
 *       and we can't verify the chain to one of our trusted roots. This
 *       results in errSSLNoRootCert on handshake.
 *
 * Both of these error conditions are ignored when the AllowAnyRoot flag is
 * true, allowing connection to a totally untrusted peer.
 *
 * ==========================
 * MAC OS X ONLY (DEPRECATED)
 * ==========================
 * NOTE: this function is not available on iOS, and should be considered
 * deprecated on Mac OS X. To ignore unknown root cert errors, first disable
 * Secure Transport's automatic verification of peer certificates by calling
 * SSLSetSessionOption to set kSSLSessionOptionBreakOnServerAuth to true. When
 * SSLHandshake subsequently returns an errSSLServerAuthCompleted result,
 * your code should obtain the SecTrustRef for the peer's certificates and
 * perform a custom trust evaluation with SecTrust APIs (see SecTrust.h).
 *
 * See the description of the SSLSetAllowsExpiredCerts function (above)
 * for a code example. Note that an unknown root certificate will cause
 * SecTrustEvaluate to report kSecTrustResultRecoverableTrustFailure as the
 * trust result.
 */
OSStatus
SSLSetAllowsAnyRoot			(SSLContextRef		context,
							 Boolean			anyRoot)
	__OSX_AVAILABLE_BUT_DEPRECATED(__MAC_10_2,__MAC_10_9,__IPHONE_NA,__IPHONE_NA);

/*
 * Obtain the current value of an SSLContext's "allow any root" flag.
 *
 * ==========================
 * MAC OS X ONLY (DEPRECATED)
 * ==========================
 * NOTE: this function is not available on iOS, and should be considered
 * deprecated on Mac OS X.
 */
OSStatus
SSLGetAllowsAnyRoot			(SSLContextRef		context,
							 Boolean			*anyRoot) /* RETURNED */
	__OSX_AVAILABLE_BUT_DEPRECATED(__MAC_10_2,__MAC_10_9,__IPHONE_NA,__IPHONE_NA);

/*
 * Augment or replace the system's default trusted root certificate set
 * for this session. If replaceExisting is true, the specified roots will
 * be the only roots which are trusted during this session. If replaceExisting
 * is false, the specified roots will be added to the current set of trusted
 * root certs. If this function has never been called, the current trusted
 * root set is the same as the system's default trusted root set.
 * Successive calls with replaceExisting false result in accumulation
 * of additional root certs.
 *
 * The trustedRoots array contains SecCertificateRefs.
 *
 * ==========================
 * MAC OS X ONLY (DEPRECATED)
 * ==========================
 * NOTE: this function is not available on iOS, and should be considered
 * deprecated on Mac OS X. To trust specific roots in a session, first disable
 * Secure Transport's automatic verification of peer certificates by calling
 * SSLSetSessionOption to set kSSLSessionOptionBreakOnServerAuth to true. When
 * SSLHandshake subsequently returns an errSSLServerAuthCompleted result,
 * your code should obtain the SecTrustRef for the peer's certificates and
 * perform a custom trust evaluation with SecTrust APIs (see SecTrust.h).
 *
 * See the description of the SSLSetAllowsExpiredCerts function (above)
 * for a code example. You can call SecTrustSetAnchorCertificates to
 * augment the system's trusted root set, or SecTrustSetAnchorCertificatesOnly
 * to make these the only trusted roots, prior to calling SecTrustEvaluate.
 */
OSStatus
SSLSetTrustedRoots			(SSLContextRef 		context,
							 CFArrayRef 		trustedRoots,
							 Boolean 			replaceExisting)
	__OSX_AVAILABLE_BUT_DEPRECATED(__MAC_10_2,__MAC_10_9,__IPHONE_NA,__IPHONE_NA);

/*
 * Obtain an array of SecCertificateRefs representing the current
 * set of trusted roots. If SSLSetTrustedRoots() has never been called
 * for this session, this returns the system's default root set.
 *
 * Caller must CFRelease the returned CFArray.
 *
 * ==========================
 * MAC OS X ONLY (DEPRECATED)
 * ==========================
 * NOTE: this function is not available on iOS, and should be considered
 * deprecated on Mac OS X. To get the current set of trusted roots, call the
 * SSLCopyPeerTrust function to obtain the SecTrustRef for the peer certificate
 * chain, then SecTrustCopyCustomAnchorCertificates (see SecTrust.h).
 */
OSStatus
SSLCopyTrustedRoots			(SSLContextRef 		context,
							 CFArrayRef 		* __nonnull CF_RETURNS_RETAINED trustedRoots)	/* RETURNED */
	__OSX_AVAILABLE_BUT_DEPRECATED(__MAC_10_5,__MAC_10_9,__IPHONE_NA,__IPHONE_NA);

/*
 * Request peer certificates. Valid anytime, subsequent to a handshake attempt.
 *
 * The certs argument is a CFArray containing SecCertificateRefs.
 * Caller must CFRelease the returned array.
 *
 * The cert at index 0 of the returned array is the subject (end
 * entity) cert; the root cert (or the closest cert to it) is at
 * the end of the returned array.
 *
 * ==========================
 * MAC OS X ONLY (DEPRECATED)
 * ==========================
 * NOTE: this function is not available on iOS, and should be considered
 * deprecated on Mac OS X. To get peer certificates, call SSLCopyPeerTrust
 * to obtain the SecTrustRef for the peer certificate chain, then use the
 * SecTrustGetCertificateCount and SecTrustGetCertificateAtIndex functions
 * to retrieve individual certificates in the chain (see SecTrust.h).
 */
OSStatus
SSLCopyPeerCertificates		(SSLContextRef 		context,
							 CFArrayRef			* __nonnull CF_RETURNS_RETAINED certs)		/* RETURNED */
	__OSX_AVAILABLE_BUT_DEPRECATED(__MAC_10_5,__MAC_10_9,__IPHONE_NA,__IPHONE_NA);

#endif /* MAC OS X */

/*
 * Obtain a SecTrustRef representing peer certificates. Valid anytime,
 * subsequent to a handshake attempt. Caller must CFRelease the returned
 * trust reference.
 *
 * The returned trust reference will have already been evaluated for you,
 * unless one of the following is true:
 * - Your code has disabled automatic certificate verification, by calling
 *   SSLSetSessionOption to set kSSLSessionOptionBreakOnServerAuth to true.
 * - Your code has called SSLSetPeerID, and this session has been resumed
 *   from an earlier cached session.
 *
 * In these cases, your code should call SecTrustEvaluate prior to
 * examining the peer certificate chain or trust results (see SecTrust.h).
 *
 * NOTE: if you have not called SSLHandshake at least once prior to
 * calling this function, the returned trust reference will be NULL.
 */
OSStatus
SSLCopyPeerTrust			(SSLContextRef 		context,
							 SecTrustRef		* __nonnull CF_RETURNS_RETAINED trust)		/* RETURNED */
	__OSX_AVAILABLE_STARTING(__MAC_10_6, __IPHONE_5_0);

/*
 * Specify some data, opaque to this library, which is sufficient
 * to uniquely identify the peer of the current session. An example
 * would be IP address and port, stored in some caller-private manner.
 * To be optionally called prior to SSLHandshake for the current
 * session. This is mandatory if this session is to be resumable.
 *
 * SecureTransport allocates its own copy of the incoming peerID. The
 * data provided in *peerID, while opaque to SecureTransport, is used
 * in a byte-for-byte compare to other previous peerID values set by the
 * current application. Matching peerID blobs result in SecureTransport
 * attempting to resume an SSL session with the same parameters as used
 * in the previous session which specified the same peerID bytes.
 */
OSStatus
SSLSetPeerID				(SSLContextRef 		context,
							 const void 		* __nullable peerID,
							 size_t				peerIDLen)
	__OSX_AVAILABLE_STARTING(__MAC_10_2, __IPHONE_5_0);

/*
 * Obtain current PeerID. Returns NULL pointer, zero length if
 * SSLSetPeerID has not been called for this context.
 */
OSStatus
SSLGetPeerID				(SSLContextRef 		context,
							 const void 		* __nullable * __nonnull peerID,
							 size_t				*peerIDLen)
	__OSX_AVAILABLE_STARTING(__MAC_10_2, __IPHONE_5_0);

/*
 * Obtain the SSLCipherSuite (e.g., SSL_RSA_WITH_DES_CBC_SHA) negotiated
 * for this session. Only valid when a session is active.
 */
OSStatus
SSLGetNegotiatedCipher		(SSLContextRef 		context,
							 SSLCipherSuite 	*cipherSuite)
	__OSX_AVAILABLE_STARTING(__MAC_10_2, __IPHONE_5_0);


/********************************************************
 *** Session context configuration, server side only. ***
 ********************************************************/

/*
 * This function is deprecated in OSX 10.11 and iOS 9.0 and
 * has no effect on the TLS handshake since OSX 10.10 and
 * iOS 8.0. Using separate RSA certificates for encryption
 * and signing is no longer supported.
 */
OSStatus
SSLSetEncryptionCertificate	(SSLContextRef		context,
							 CFArrayRef			certRefs)
	__OSX_AVAILABLE_BUT_DEPRECATED(__MAC_10_2, __MAC_10_11, __IPHONE_5_0, __IPHONE_9_0);

/*
 * Specify requirements for client-side authentication.
 * Optional; Default is kNeverAuthenticate.
 *
 * Can only be called when no session is active.
 */
typedef CF_ENUM(int, SSLAuthenticate) {
	kNeverAuthenticate,			/* skip client authentication */
	kAlwaysAuthenticate,		/* require it */
	kTryAuthenticate			/* try to authenticate, but not an error
								 * if client doesn't have a cert */
};

OSStatus
SSLSetClientSideAuthenticate 	(SSLContextRef		context,
								 SSLAuthenticate	auth)
	__OSX_AVAILABLE_STARTING(__MAC_10_2, __IPHONE_5_0);

/*
 * Add a DER-encoded distinguished name to list of acceptable names
 * to be specified in requests for client certificates.
 */
OSStatus
SSLAddDistinguishedName		(SSLContextRef 		context,
							 const void 		* __nullable derDN,
							 size_t 			derDNLen)
	__OSX_AVAILABLE_STARTING(__MAC_10_4, __IPHONE_5_0);


#if (TARGET_OS_MAC && !(TARGET_OS_EMBEDDED || TARGET_OS_IPHONE))
/*
 * Add a SecCertificateRef, or a CFArray of them, to a server's list
 * of acceptable Certificate Authorities (CAs) to present to the client
 * when client authentication is performed.
 *
 * If replaceExisting is true, the specified certificate(s) will replace
 * a possible existing list of acceptable CAs. If replaceExisting is
 * false, the specified certificate(s) will be appended to the existing
 * list of acceptable CAs, if any.
 *
 * Returns errSecParam if this is called on a SSLContextRef which
 * is configured as a client, or when a session is active.
 *
 * NOTE: this function is currently not available on iOS.
 */
OSStatus
SSLSetCertificateAuthorities(SSLContextRef		context,
							 CFTypeRef			certificateOrArray,
							 Boolean 			replaceExisting)
	__OSX_AVAILABLE_STARTING(__MAC_10_5, __IPHONE_NA);

/*
 * Obtain the certificates specified in SSLSetCertificateAuthorities(),
 * if any. Returns a NULL array if SSLSetCertificateAuthorities() has not
 * been called.
 * Caller must CFRelease the returned array.
 *
 * NOTE: this function is currently not available on iOS.
 */
OSStatus
SSLCopyCertificateAuthorities(SSLContextRef		context,
							  CFArrayRef		* __nonnull CF_RETURNS_RETAINED certificates)	/* RETURNED */
	__OSX_AVAILABLE_STARTING(__MAC_10_5, __IPHONE_NA);

#endif /* MAC OS X */

/*
 * Obtain the list of acceptable distinguished names as provided by
 * a server (if the SSLContextRef is configured as a client), or as
 * specified by SSLSetCertificateAuthorities (if the SSLContextRef
 * is configured as a server).
 * The returned array contains CFDataRefs, each of which represents
 * one DER-encoded RDN.
 *
 * Caller must CFRelease the returned array.
 */
OSStatus
SSLCopyDistinguishedNames	(SSLContextRef		context,
							 CFArrayRef			* __nonnull CF_RETURNS_RETAINED names)
	__OSX_AVAILABLE_STARTING(__MAC_10_5, __IPHONE_5_0);

/*
 * Obtain client certificate exchange status. Can be called
 * any time. Reflects the *last* client certificate state change;
 * subsequent to a renegotiation attempt by either peer, the state
 * is reset to kSSLClientCertNone.
 */
OSStatus
SSLGetClientCertificateState	(SSLContextRef				context,
								 SSLClientCertificateState	*clientState)
	__OSX_AVAILABLE_STARTING(__MAC_10_3, __IPHONE_5_0);


#if (TARGET_OS_MAC && !(TARGET_OS_EMBEDDED || TARGET_OS_IPHONE))
/*
 * Specify Diffie-Hellman parameters. Optional; if we are configured to allow
 * for D-H ciphers and a D-H cipher is negotiated, and this function has not
 * been called, a set of process-wide parameters will be calculated. However
 * that can take a long time (30 seconds).
 *
 * NOTE: this function is currently not available on iOS.
 */
OSStatus SSLSetDiffieHellmanParams	(SSLContextRef			context,
									 const void 			* __nullable dhParams,
									 size_t					dhParamsLen)
	__OSX_AVAILABLE_STARTING(__MAC_10_2, __IPHONE_NA);

/*
 * Return parameter block specified in SSLSetDiffieHellmanParams.
 * Returned data is not copied and belongs to the SSLContextRef.
 *
 * NOTE: this function is currently not available on iOS.
 */
OSStatus SSLGetDiffieHellmanParams	(SSLContextRef			context,
									 const void 			* __nullable * __nonnull dhParams,
									 size_t					*dhParamsLen)
	__OSX_AVAILABLE_STARTING(__MAC_10_2, __IPHONE_NA);

/*
 * Enable/Disable RSA blinding. This feature thwarts a known timing
 * attack to which RSA keys are vulnerable; enabling it is a tradeoff
 * between performance and security. The default for RSA blinding is
 * enabled.
 *
 * ==========================
 * MAC OS X ONLY (DEPRECATED)
 * ==========================
 * NOTE: this function is not available on iOS, and should be considered
 * deprecated on Mac OS X. RSA blinding is enabled unconditionally, as
 * it prevents a known way for an attacker to recover the private key,
 * and the performance gain of disabling it is negligible.
 */
OSStatus SSLSetRsaBlinding			(SSLContextRef			context,
									 Boolean				blinding)
	__OSX_AVAILABLE_BUT_DEPRECATED(__MAC_10_2,__MAC_10_9,__IPHONE_NA,__IPHONE_NA);

OSStatus SSLGetRsaBlinding			(SSLContextRef			context,
									 Boolean				*blinding)
	__OSX_AVAILABLE_BUT_DEPRECATED(__MAC_10_2,__MAC_10_9,__IPHONE_NA,__IPHONE_NA);

#endif /* MAC OS X */

/*******************************
 ******** I/O Functions ********
 *******************************/

/*
 * Note: depending on the configuration of the underlying I/O
 * connection, all SSL I/O functions can return errSSLWouldBlock,
 * indicating "not complete, nothing is wrong, except required
 * I/O hasn't completed". Caller may need to repeat I/Os as necessary
 * if the underlying connection has been configured to behave in
 * a non-blocking manner.
 */

/*
 * Perform the SSL handshake. On successful return, session is
 * ready for normal secure application I/O via SSLWrite and SSLRead.
 *
 * Interesting error returns:
 *
 *  errSSLUnknownRootCert: Peer had a valid cert chain, but the root of
 *      the chain is unknown.
 *
 *  errSSLNoRootCert: Peer had a cert chain which did not end in a root.
 *
 *  errSSLCertExpired: Peer's cert chain had one or more expired certs.
 *
 *  errSSLXCertChainInvalid: Peer had an invalid cert chain (i.e.,
 *      signature verification within the chain failed, or no certs
 *      were found).
 *
 *  In all of the above errors, the handshake was aborted; the peer's
 *  cert chain is available via SSLCopyPeerTrust or SSLCopyPeerCertificates.
 *
 *  Other interesting result codes:
 *
 *  errSSLPeerAuthCompleted: Peer's cert chain is valid, or was ignored if
 *      cert verification was disabled via SSLSetEnableCertVerify. The application
 *      may decide to continue with the handshake (by calling SSLHandshake
 *      again), or close the connection at this point.
 *
 *  errSSLClientCertRequested: The server has requested a client certificate.
 *      The client may choose to examine the server's certificate and
 *      distinguished name list, then optionally call SSLSetCertificate prior
 *      to resuming the handshake by calling SSLHandshake again.
 *
 * A return value of errSSLWouldBlock indicates that SSLHandshake has to be
 * called again (and again and again until something else is returned).
 */
OSStatus
SSLHandshake				(SSLContextRef		context)
	__OSX_AVAILABLE_STARTING(__MAC_10_2, __IPHONE_5_0);

/*
 * Server Only: Request renegotation.
 * This will return an error if the server is already renegotiating, or if the session is closed.
 * After this return without error, the application should call SSLHandshake() and/or SSLRead() as
 * for the original handshake.
 */
OSStatus
SSLReHandshake				(SSLContextRef		context)
    __OSX_AVAILABLE_STARTING(__MAC_10_12, __IPHONE_10_0);


/*
 * Normal application-level read/write. On both of these, a errSSLWouldBlock
 * return and a partially completed transfer - or even zero bytes transferred -
 * are NOT mutually exclusive.
 */
OSStatus
SSLWrite					(SSLContextRef		context,
							 const void *		__nullable data,
							 size_t				dataLength,
							 size_t 			*processed)		/* RETURNED */
	__OSX_AVAILABLE_STARTING(__MAC_10_2, __IPHONE_5_0);

/*
 * data is mallocd by caller; available size specified in
 * dataLength; actual number of bytes read returned in
 * *processed.
 */
OSStatus
SSLRead						(SSLContextRef		context,
							 void *				data,			/* RETURNED */
							 size_t				dataLength,
							 size_t 			*processed)		/* RETURNED */
	__OSX_AVAILABLE_STARTING(__MAC_10_2, __IPHONE_5_0);

/*
 * Determine how much data the client can be guaranteed to
 * obtain via SSLRead() without blocking or causing any low-level
 * read operations to occur.
 */
OSStatus
SSLGetBufferedReadSize		(SSLContextRef context,
							 size_t *bufSize)					/* RETURNED */
	__OSX_AVAILABLE_STARTING(__MAC_10_2, __IPHONE_5_0);

/*
 * Determine how much data the application can be guaranteed to write
 * with SSLWrite() without causing fragmentation. The value is based on
 * the maximum Datagram Record size defined by the application with
 * SSLSetMaxDatagramRecordSize(), minus the DTLS Record header size.
 */
OSStatus
SSLGetDatagramWriteSize		(SSLContextRef dtlsContext,
							 size_t *bufSize)
	__OSX_AVAILABLE_STARTING(__MAC_10_8, __IPHONE_5_0);

/*
 * Terminate current SSL session.
 */
OSStatus
SSLClose					(SSLContextRef		context)
	__OSX_AVAILABLE_STARTING(__MAC_10_2, __IPHONE_5_0);

CF_IMPLICIT_BRIDGING_DISABLED
CF_ASSUME_NONNULL_END

#ifdef __cplusplus
}
#endif

#endif /* !_SECURITY_SECURETRANSPORT_H_ */
