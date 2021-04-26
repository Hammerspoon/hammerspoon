#!/bin/bash

set -eu
set -o pipefail

SECURITY="/usr/bin/security"
KEYCHAIN="build.keychain"
P12="./ci-secrets/Cleartext/Hammerspoon-Nightly-Certificates.p12"

echo "Creating new default keychain: ${KEYCHAIN}"
"${SECURITY}" create-keychain -p "${NIGHTLY_KEYCHAIN_PASSPHRASE}" "${KEYCHAIN}"
"${SECURITY}" default-keychain -s "${KEYCHAIN}"

echo "Unlocking keychain..."
"${SECURITY}" unlock-keychain -p "${NIGHTLY_KEYCHAIN_PASSPHRASE}" "${KEYCHAIN}"

echo "Importing signing certificate/key..."
"${SECURITY}" import "${P12}" -f pkcs12 -k "${KEYCHAIN}" -P "${NIGHTLY_KEYCHAIN_PASSPHRASE}"  -T /usr/bin/codesign -x

echo "Removing keychain autolocking settings..."
"${SECURITY}" set-keychain-settings -t 1200

echo "Setting permissions for keychain..."
"${SECURITY}" -q set-key-partition-list -S apple-tool:,apple:,codesign: -s -k "${NIGHTLY_KEYCHAIN_PASSPHRASE}" "${KEYCHAIN}"

#"${SECURITY}" show-keychain-info
echo "Listing keychains:"
"${SECURITY}" list-keychains -d user

echo "Dumping keychain identity:"
"${SECURITY}" find-identity -v
