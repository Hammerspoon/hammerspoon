#!/bin/bash

set -eux
set -o pipefail

echo "== Using /usr/bin/openssl. PATH would use: $(which openssl)"
echo "== Generating a private key and using it to sign an x509:"
/usr/bin/openssl req -x509 -newkey rsa:2048 -outform DER -out cert.cer -config openssl.conf -set_serial 106 >/dev/null

echo ""

echo "== Dumping ASN.1 structure of cert.cer:"
/usr/bin/openssl asn1parse -inform DER -in cert.cer -dump -i >cert.cer.asn1

echo ""

echo "== Generating HammerspoonCertTemplate.h:"
INCLUDE_FILE="HammerspoonCertTemplate.h"

# Clear out the include file
> ${INCLUDE_FILE}

echo "=== Calculating offsets..."

SERIAL_OFFSET=$(( 2 + $(grep INTEGER cert.cer.asn1 | sed -n 2p | sed -e 's/:.*//') ))
ISSUEDATE_OFFSET=$(( 2 + $(grep UTCTIME cert.cer.asn1 | sed -n 1p | sed -e 's/:.*//') ))
EXPIRYDATE_OFFSET=$(( 2 + $(grep UTCTIME cert.cer.asn1 | sed -n 2p | sed -e 's/:.*//') ))
PUBLICKEY_OFFSET=$(( 5 + $(grep "BIT STRING" cert.cer.asn1 | sed -n 1p | sed -e 's/:.*//') ))
CSR_LENGTH=$(grep "BIT STRING" cert.cer.asn1 | sed -n 2p | sed -e 's/:.*//')

echo "#define kSerialOffset    ${SERIAL_OFFSET}" >>${INCLUDE_FILE}
echo "#define kIssueDateOffset ${ISSUEDATE_OFFSET}" >>${INCLUDE_FILE}
echo "#define kExpDateOffset   ${EXPIRYDATE_OFFSET}" >>${INCLUDE_FILE}
echo "#define kPublicKeyOffset ${PUBLICKEY_OFFSET}" >>${INCLUDE_FILE}
echo "#define kCSRLength     ${CSR_LENGTH}u" >>${INCLUDE_FILE}

echo "" >>${INCLUDE_FILE}

echo "=== Dumping template certificate bytes..."
/usr/bin/openssl x509 -C -inform DER -in cert.cer -noout | sed -n '/XXX_certificate/,$p' | sed -e 's/unsigned char XXX_certificate/static uint8_t const kCertTemplate/' >>${INCLUDE_FILE}

echo "=== Tidying..."
rm -rv cert.cer
rm -rv cert.cer.asn1

echo ""
echo "=== Header file contents:"
cat "${INCLUDE_FILE}"
echo "== Done"
