#!/bin/bash

if [ "$1" == "" ]; then
    echo "Usage: $0 VERSION"
    exit 1
fi

# Early sanity check that we have everything we need
if [ "$(which greadlink)" == "" ]; then
    echo "ERROR: Unable to find greadlink. Maybe 'brew install coreutils'?"
    exit 1
fi

# Store some variables for later
export VERSION="$1"
export CWD=$PWD
export SCRIPT_NAME="$(basename "$0")"
export SCRIPT_HOME="$(dirname "$(greadlink -f "$0")")"
export HAMMERSPOON_HOME="$(greadlink -f "${SCRIPT_HOME}/../")"
export XCODE_BUILT_PRODUCTS_DIR="$(xcodebuild -workspace Hammerspoon.xcworkspace -scheme 'Release' -configuration 'Release' -showBuildSettings | sort | uniq | grep ' BUILT_PRODUCTS_DIR =' | awk '{ print $3 }')"

export CODESIGN_AUTHORITY_TOKEN_FILE="${HAMMERSPOON_HOME}/../token-codesign-authority"
export GITHUB_TOKEN_FILE="${HAMMERSPOON_HOME}/../token-github-release"
export GITHUB_USER="hammerspoon"
export GITHUB_REPO="hammerspoon"

# Import our function library
source "${SCRIPT_HOME}/librelease.sh"

assert
build
validate
localtest
prepare_upload
archive
upload
announce

echo "Appcast zip length is: ${ZIPLEN}"

echo "Finished."
