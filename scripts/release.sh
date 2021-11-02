#!/bin/bash

NIGHTLY=0
if [ "$1" == "--nightly" ]; then
    NIGHTLY=1
fi
export NIGHTLY

set -eu
set -o pipefail

# Early sanity check that we have everything we need
if [ "$(which greadlink)" == "" ]; then
    echo "ERROR: Unable to find greadlink. Maybe 'brew install coreutils'?"
    exit 1
fi

# Store some variables for later
VERSION_GITOPTS=""
if [ "$NIGHTLY" == "0" ]; then
    VERSION_GITOPTS="--abbrev=0"
fi
VERSION="$(git describe $VERSION_GITOPTS)"
export VERSION

echo "Building $VERSION (isNightly: $NIGHTLY)"

export CWD=$PWD
export SCRIPT_NAME
export SCRIPT_HOME
export HAMMERSPOON_HOME
export XCODE_BUILT_PRODUCTS_DIR

SCRIPT_NAME="$(basename "$0")"
SCRIPT_HOME="$(dirname "$(greadlink -f "$0")")"
HAMMERSPOON_HOME="$(greadlink -f "${SCRIPT_HOME}/../")"
XCODE_BUILT_PRODUCTS_DIR="$(xcodebuild -workspace Hammerspoon.xcworkspace -scheme 'Release' -configuration 'Release' -showBuildSettings | sort | uniq | grep ' BUILT_PRODUCTS_DIR =' | awk '{ print $3 }')"

export TOKENPATH
TOKENPATH="${HAMMERSPOON_HOME}/.."
if [ -d ~/Desktop/hammerspoon-tokens ]; then
  TOKENPATH="~/Desktop/hammerspoon-tokens"
fi

export CODESIGN_AUTHORITY_TOKEN_FILE="${TOKENPATH}/token-codesign-authority"
export GITHUB_TOKEN_FILE="${TOKENPATH}/token-github-release"
export GITHUB_USER="hammerspoon"
export GITHUB_REPO="hammerspoon"
export SENTRY_TOKEN_API_FILE="${TOKENPATH}/token-sentry-api"
export SENTRY_TOKEN_AUTH_FILE="${TOKENPATH}/token-sentry-auth"
export NOTARIZATION_TOKEN_FILE="${TOKENPATH}/token-notarization"

# Import our function library
# shellcheck source=scripts/librelease.sh disable=SC1091
source "${SCRIPT_HOME}/librelease.sh"

assert
build
validate
notarize
prepare_upload
archive
if [ "$NIGHTLY" == "0" ]; then
  localtest
  upload
  announce
fi

echo "Appcast zip length is: ${ZIPLEN}"

echo "Finished."
