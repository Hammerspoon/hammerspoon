#!/bin/bash
# Hammerspoon build system

# Check if we're in a CI system
export IS_CI=${IS_CI:-0}

# Set some defaults that we'll override based on command line arguments
XCODE_SCHEME="Hammerspoon"
XCODE_CONFIGURATION="Debug"
XCCONFIG_FILE=""
UPLOAD_DSYM=0
DEBUG=0
DOCS_JSON=1
DOCS_MD=1
DOCS_HTML=1
DOCS_SQL=1
DOCS_DASH=1
DOCS_LUASKIN=1
DOCS_LINT_ONLY=0

# Print out friendly command line usage information
function usage() {
    echo "Usage $0 COMMAND [OPTIONS]"
    echo "COMMANDS:"
    echo "  clean         - Erase build directory"
    echo "  build         - Build Hammerspoon.app"
    echo "  validate      - Validate signature/gatekeeper/entitlements"
    echo "  docs          - Build documentation"
    echo "  installdeps   - Install all Hammerspoon build dependencies"
    echo "  notarize      - Notarize a Hammerspoon.app bundle with Apple (note that it must be signed first)"
    echo "  release       - Perform all the steps to upload a release"
    echo ""
    echo "GENERAL OPTIONS:"
    echo " -h             - Show this help"
    echo " -d             - Enable debugging"
    echo ""
    echo "BUILD OPTIONS:"
    echo " -s             - Hammerspoon build scheme (Default: Hammerspoon)"
    echo " -c             - Hammerspoon build configuration (Default: Debug)"
    echo " -x             - Use build settings from a .xcconfig file (Default: None)"
    echo " -u             - Upload debug symbols to crash reporting service (Default: No)"
    echo ""
    echo "DOCS OPTIONS:"
    echo "By default all docs are built. Only one of the following options can be supplied."
    echo "If more than one is present, only the last one will have an effect"
    echo " -j             - Build only JSON documentation"
    echo " -m             - Build only Markdown documentation"
    echo " -t             - Build only HTML documentation"
    echo " -q             - Build only SQLite documentation"
    echo " -a             - Build only Dash documentation"
    echo " -k             - Build only LuaSkin documentation"
    echo " -l             - Only lint docs, don't build anything"

    exit 2
}

# Fetch the COMMAND we should perform
OPERATION=${1:-unknown};shift
if [ "${OPERATION}" == "-h" ] || [ "${OPERATION}" == "--help" ]; then
    usage
fi
if [ "${OPERATION}" != "build" ] && [ "${OPERATION}" != "docs" ] && [ "${OPERATION}" != "installdeps" ] && [ "${OPERATION}" != "notarize" ] && [ "${OPERATION}" != "release" ] && [ "${OPERATION}" != "clean" ] && [ "${OPERATION}" != "validate" ]; then
    usage
fi;

# Parse the rest of any arguments
PARSED_ARGUMENTS=$(getopt ds:c:x:ujmtqakl $*)
if [ $? != 0 ]; then
    usage
fi
set -- $PARSED_ARGUMENTS

# Translate the parsed arguments into our defaults
for i
do
    case "$i" in
        -d)
            DEBUG=1
            shift;;
        -s)
            XCODE_SCHEME=${2}; shift
            shift;;
        -c)
            XCODE_CONFIGURATION=${2}; shift
            shift;;
        -x)
            XCCONFIG_FILE=${2}; shift
            shift;;
        -u)
            UPLOAD_DSYM=1
            shift;;
        -j)
            # JSON can be built without any of the others
            DOCS_MD=0
            DOCS_HTML=0
            DOCS_SQL=0
            DOCS_DASH=0
            DOCS_LUASKIN=0
            DOCS_LINT_ONLY=0
            shift;;
        -m)
            # Markdown requires JSON, so leave that enabled
            DOCS_HTML=0
            DOCS_SQL=0
            DOCS_DASH=0
            DOCS_LUASKIN=0
            DOCS_LINT_ONLY=0
            shift;;
        -t)
            # HTML requires JSON, so leave that enabled
            DOCS_MD=0
            DOCS_SQL=0
            DOCS_DASH=0
            DOCS_LUASKIN=0
            DOCS_LINT_ONLY=0
            shift;;
        -q)
            # SQLite requires JSON, so leave that enabled
            DOCS_MD=0
            DOCS_HTML=0
            DOCS_DASH=0
            DOCS_LUASKIN=0
            DOCS_LINT_ONLY=0
            shift;;
        -a)
            # Dash requires JSON, SQLite, LuaSkin and HTML
            DOCS_MD=0
            DOCS_LINT_ONLY=0
            shift;;
        -k)
            # LuaSkin requires nothing else
            DOCS_JSON=0
            DOCS_MD=0
            DOCS_HTML=0
            DOCS_SQL=0
            DOCS_DASH=0
            DOCS_LINT_ONLY=0
            shift;;
        -l)
            # Linting requires no other docs to be built
            DOCS_JSON=0
            DOCS_MD=0
            DOCS_HTML=0
            DOCS_SQL=0
            DOCS_DASH=0
            DOCS_LINT_ONLY=1
            shift;;
        --)
            shift; break;;
    esac
done

# If the user asked for debugging, print out some settings and enable bash tracing
if [ ${DEBUG} == 1 ]; then
    echo "OPERATION is: ${OPERATION}"
    echo "XCODE_SCHEME is: ${XCODE_SCHEME}"
    echo "XCCODE_CONFIGURATION is: ${XCODE_CONFIGURATION}"
    echo "XCCONFIG_FILE is: ${XCCONFIG_FILE:-None}"
    echo "UPLOAD_DSYM is: ${UPLOAD_DSYM}"
    echo "DEBUG is: ${DEBUG}"

    echo "DOCS_JSON is: ${DOCS_JSON}"
    echo "DOCS_MD is: ${DOCS_MD}"
    echo "DOCS_HTML is: ${DOCS_HTML}"
    echo "DOCS_SQL is: ${DOCS_SQL}"
    echo "DOCS_DASH is: ${DOCS_DASH}"
    echo "DOCS_LUASKIN is: ${DOCS_LUASKIN}"
    echo "DOCS_LINT_ONLY is: ${DOCS_LINT_ONLY}"

    set -x
fi

# Enable lots of safety
set -eu
set -o pipefail

# Export all the arguments we need later
export XCODE_SCHEME
export XCODE_CONFIGURATION
export XCCONFIG_FILE
export UPLOAD_DSYM
export DEBUG
export DOCS_JSON
export DOCS_MD
export DOCS_HTML
export DOCS_SQL
export DOCS_DASH
export DOCS_LINT_ONLY

# Early sanity check that we have everything we need
export PATH="$PATH:/opt/homebrew/bin"
if [ "$(which greadlink)" == "" ]; then
    echo "ERROR: Unable to find greadlink. Maybe '$0 installdeps'?"
    exit 1
fi

# Calculate some variables we need later
echo "Gathing info..."
export CWD=$PWD
export SCRIPT_NAME
export SCRIPT_HOME
export HAMMERSPOON_HOME
export XCODE_BUILT_PRODUCTS_DIR
SCRIPT_NAME="$(basename "$0")"
SCRIPT_HOME="$(dirname "$(greadlink -f "$0")")"
HAMMERSPOON_HOME="$(greadlink -f "${SCRIPT_HOME}/../")"
BUILD_HOME="${HAMMERSPOON_HOME}/build"
HAMMERSPOON_BUNDLE="Hammerspoon.app"
export HAMMERSPOON_APP="${BUILD_HOME}/${HAMMERSPOON_BUNDLE}"
XCODE_BUILT_PRODUCTS_DIR="$(xcodebuild -workspace Hammerspoon.xcworkspace -scheme "${XCODE_SCHEME}" -configuration "${XCODE_CONFIGURATION}" -destination "platform=macOS" -showBuildSettings | sort | uniq | grep ' BUILT_PRODUCTS_DIR =' | awk '{ print $3 }')"
export DOCS_SEARCH_DIRS=(${HAMMERSPOON_HOME}/Hammerspoon/ ${HAMMERSPOON_HOME}/extensions/)

# Calculate private token variables
export TOKENPATH
TOKENPATH="${HAMMERSPOON_HOME}/.."
export GITHUB_TOKEN_FILE="${TOKENPATH}/token-github-release"
export GITHUB_USER="hammerspoon"
export GITHUB_REPO="hammerspoon"
export SENTRY_TOKEN_API_FILE="${TOKENPATH}/token-sentry-api"
export SENTRY_TOKEN_AUTH_FILE="${TOKENPATH}/token-sentry-auth"
export NOTARIZATION_TOKEN_FILE="${TOKENPATH}/token-notarization"

# Import our function library
# shellcheck source=scripts/librelease.sh disable=SC1091
source "${SCRIPT_HOME}/libbuild.sh"

# Make sure our build directory exists
mkdir -p "${BUILD_HOME}"

echo ""

# Figure out which COMMAND we have been tasked with performing, and go do it
case "${OPERATION}" in
    "clean")
        op_clean
        ;;
    "build")
        op_build
        ;;
    "validate")
        op_validate
        ;;
    "docs")
        op_docs
        ;;
    "installdeps")
        op_installdeps
        ;;
    "notarize")
        op_notarize
        ;;
    "release")
        op_release
        ;;
esac

exit 0

####################### OLD STUFF BELOW ##############################

# Store some variables for later
# VERSION_GITOPTS=""
# if [ "$NIGHTLY" == "0" ] && [ "$LOCAL" == "0" ]; then
#     VERSION_GITOPTS="--abbrev=0"
# fi
# VERSION="$(git describe $VERSION_GITOPTS)"
# export VERSION

# echo "Building $VERSION (isNightly: $NIGHTLY, isLocal: $LOCAL)"



# assert
# build
# validate
# if [ "$LOCAL" == "0" ]; then
# notarize
# fi
# prepare_upload
# archive
# if [ "$NIGHTLY" == "0" ] || [ "$LOCAL" == "0" ]; then
#   localtest
#   upload
#   announce
# fi

# echo "Appcast zip length is: ${ZIPLEN}"

# echo "Finished."
