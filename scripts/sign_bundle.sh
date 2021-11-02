#!/bin/bash

set -x

if [ "$1" == "" ] || [ "$2" == "" ] || [ "$3" == "" ]; then
    echo "Usage: $0 BUNDLEPATH SOURCEROOT CONFIGURATION"
    exit 1
fi

set -eu

BUNDLE_PATH="$1"
SRCROOT="$2"
CONFIGURATION="$3"

CODESIGN="/usr/bin/codesign"
TOKENPATH="${HAMMERSPOON_TOKEN_PATH:-..}"

if [ -f "${TOKENPATH}/token-codesign" ] ; then
    echo "SIGNING CODE"
    source "${TOKENPATH}/token-codesign"

    if [ "${CONFIGURATION}" == "Debug" ]; then
        CODESIGN_OPTS="--timestamp=none"
    elif [ "${CONFIGURATION}" == "Release" ]; then
        CODESIGN_OPTS="--timestamp"
    else
        CODESIGN_OPTS=""
    fi

    FRAMEWORKS="${BUNDLE_PATH}/Contents/Frameworks/"

    # sign Sparkle.framework if this is a release build
    if [ -e "${FRAMEWORKS}/Sparkle.framework/Versions/A" ] ; then
        "${CODESIGN}" ${CODESIGN_OPTS} -o runtime --verbose --force --sign "$CODESIGN_IDENTITY" "${FRAMEWORKS}/Sparkle.framework/Versions/A/Resources/Autoupdate.app/Contents/MacOS/fileop"
        "${CODESIGN}" ${CODESIGN_OPTS} -o runtime --verbose --force --sign "$CODESIGN_IDENTITY" "${FRAMEWORKS}/Sparkle.framework/Versions/A/Resources/Autoupdate.app/Contents/MacOS/Autoupdate"
        "${CODESIGN}" ${CODESIGN_OPTS} --verbose --force --sign "$CODESIGN_IDENTITY" "${FRAMEWORKS}/Sparkle.framework/Versions/A"
    fi

    # sign Hammerspoon Tests.xctest if this is a test build
    if [ -e "${BUNDLE_PATH}/Contents/PlugIns/Hammerspoon Tests.xctest" ] ; then
        "${CODESIGN}" ${CODESIGN_OPTS} --verbose --force --sign "$CODESIGN_IDENTITY" "${BUNDLE_PATH}/Contents/PlugIns/Hammerspoon Tests.xctest"
    fi

    # sign LuaSkin.framework
    "${CODESIGN}" ${CODESIGN_OPTS} --verbose --force --sign "$CODESIGN_IDENTITY" "${FRAMEWORKS}/LuaSkin.framework/Versions/A"

    # sign the modules
    find "${BUNDLE_PATH}" -type f -name '*.so' -exec "${CODESIGN}" ${CODESIGN_OPTS} --verbose --force --sign "$CODESIGN_IDENTITY" {} \;

    # sign the CLI app
    "${CODESIGN}" ${CODESIGN_OPTS} -o runtime --verbose --force --sign "$CODESIGN_IDENTITY" "${BUNDLE_PATH}/Contents/Resources/extensions/hs/ipc/bin/hs"

    # sign the Hammerspoon binary
    ENTITLEMENTS="${SRCROOT}/Hammerspoon/Hammerspoon.entitlements"
    if [ "${CONFIGURATION}" == "Debug" ]; then
        ENTITLEMENTS="${SRCROOT}/Hammerspoon/Hammerspoon-dev.entitlements"
    fi

"${CODESIGN}" ${CODESIGN_OPTS} -o runtime --verbose --force --entitlements "${ENTITLEMENTS}" --sign "$CODESIGN_IDENTITY" "${BUNDLE_PATH}"
else
    echo "SKIPPING CODE SIGNING"
fi

