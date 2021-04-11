#!/bin/bash

set -eux
set -o pipefail

SECURITY="/usr/bin/security"
KEYCHAIN="build.keychain"
P12="./ci-secrets/Cleartext/Hammerspoon-Nightly-Certificates.p12"

"${SECURITY}" create-keychain -p "${NIGHTLY_KEYCHAIN_PASSPHRASE}" "${KEYCHAIN}"
"${SECURITY}" default-keychain -s "${KEYCHAIN}"

"${SECURITY}" unlock-keychain -p "${NIGHTLY_KEYCHAIN_PASSPHRASE}" "${KEYCHAIN}"
"${SECURITY}" import "${P12}" -f pkcs12 -k "${KEYCHAIN}" -P "${NIGHTLY_KEYCHAIN_PASSPHRASE}"  -T /usr/bin/codesign -x

"${SECURITY}" set-keychain-settings -t 1200
"${SECURITY}" set-key-partition-list -S apple-tool:,apple:,codesign: -s -k "${NIGHTLY_KEYCHAIN_PASSPHRASE}" "${KEYCHAIN}"

"${SECURITY}" show-keychain-info
"${SECURITY}" list-keychains -d user
"${SECURITY}" find-identity -v
