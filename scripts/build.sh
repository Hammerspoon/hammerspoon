#!/bin/bash
# Hammerspoon build system

# Check if we're in a CI system
export IS_CI=${IS_CI:-0}
# Check if we're doing a nightly build
export IS_NIGHTLY=${IS_NIGHTLY:-0}

# Make it easy to fork us
export APP_NAME="${APP_NAME:-"Hammerspoon"}"

# Set some defaults that we'll override based on command line arguments
XCODE_SCHEME="Hammerspoon"
XCODE_CONFIGURATION="Debug"
XCCONFIG_FILE=""
UPLOAD_DSYM=0
BUILD_FOR_TESTING=0
KEYCHAIN_PROFILE="HAMMERSPOON_BUILDSH"
P12_FILE=""
NOTARIZATION_CREDS_FILE=""
TWITTER_ACCOUNT="_hammerspoon"
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
    echo "  installdeps   - Install all ${APP_NAME} build dependencies"
    echo "  clean         - Erase build directory"
    echo "  build         - Build ${APP_NAME}.app"
    echo "  test          - Test ${APP_NAME}.app"
    echo "  validate      - Validate signature/gatekeeper/entitlements"
    echo "  docs          - Build documentation"
    echo "  keychain-prep - Prepare a new default Keychain with required secrets for signing/notarizing"
    echo "  notarize      - Notarize a ${APP_NAME}.app bundle with Apple (note that it must be signed first)"
    echo "  archive       - Archive the build/notarization artifacts"
    echo "  release       - Perform all the steps to upload a release"
    echo ""
    echo "GENERAL OPTIONS:"
    echo "  -h             - Show this help"
    echo "  -d             - Enable debugging"
    echo ""
    echo "BUILD OPTIONS:"
    echo "  -s             - Hammerspoon build scheme (Default: Hammerspoon)"
    echo "  -c             - Hammerspoon build configuration (Default: Debug)"
    echo "  -x             - Use extra build settings from a .xcconfig file (Default: None)"
    echo "  -u             - Upload debug symbols to crash reporting service (Default: No)"
    echo "  -e             - Build for testing"
    echo ""
    echo "DOCS OPTIONS:"
    echo "By default all docs are built. Only one of the following options can be supplied."
    echo "If more than one is present, only the last one will have an effect"
    echo "  -j             - Build only JSON documentation"
    echo "  -m             - Build only Markdown documentation"
    echo "  -t             - Build only HTML documentation"
    echo "  -q             - Build only SQLite documentation"
    echo "  -a             - Build only Dash documentation"
    echo "  -k             - Build only LuaSkin documentation"
    echo "  -l             - Only lint docs, don't build anything"
    echo ""
    echo "KEYCHAIN-PREP OPTIONS:"
    echo "Note: This command is primarily for use in CI. For local builds, manually import your Apple signing certificate"
    echo "       and see the suggested xcrun command in NOTARIZATION OPTIONS below"
    echo "  -s             - Hammerspoon build scheme (Default: Hammerspoon)"
    echo "  -c             - Hammerspoon build configuration (Default: Debug)"
    echo "  -x             - Use extrabuild settings from a .xcconfig file (Default: None)"
    echo "  -p             - Import a .p12 containing the signing certificate (usually issued by Apple)"
    echo "  -o             - Import Notarization credentials file. This should contain your developer"
    echo "                   Apple ID and an App Specific Password for it, in the format:"
    echo "                    NOTARIZATION_USERNAME=\"foo@bar.com\""
    echo "                    NOTARIZATION_PASSWORD=\"abcd-1234-efgh-5678\""
    echo "  -y             - Keychain profile name for notarization credentials (Default: HAMMERSPOON_BUILDSH)"
    echo ""
    echo "NOTARIZATION OPTIONS:"
    echo "Note: The keychain profile must be set up ahead of time using your developer Apple ID account and Team ID:"
    echo "  xcrun notarytool store-credentials -v --apple-id APPLE_ID --team-id TEAM_ID --password APP_SPECIFIC_PASSWORD"
    echo "  -y             - Keychain profile name (Default: HAMMERSPOON_BUILDSH)"
    echo ""
    echo "RELEASE OPTIONS:"
    echo "  -w             - Twitter account to announce release with (Default: _hammerspoon)"
    echo ""
    echo "ENVIRONMENT VARIABLES:"
    echo "  IS_CI          - Set to 1 to enable CI behaviours (Default: 0)"
    echo "  GITHUB_USER    - GitHub user/organization to upload releases to (Default: Hammerspoon)"
    echo "  GITHUB_REPO    - GitHub repository to upload releases to (Default: hammerspoon)"
    echo "  SENTRY_ORG     - Sentry organization to upload debugging symbols to (Default: hammerspoon)"
    echo "  SENTRY_PROJECT - Sentry project to upload debugging symbols to (Default hammerspoon)"

    exit 2
}

# Fetch the COMMAND we should perform
OPERATION=${1:-unknown};shift
if [ "${OPERATION}" == "-h" ] || [ "${OPERATION}" == "--help" ]; then
    usage
fi
#if [ "${OPERATION}" != "build" ] && [ "${OPERATION}" != "test" ] && [ "${OPERATION}" != "docs" ] && [ "${OPERATION}" != "installdeps" ] && [ "${OPERATION}" != "notarize" ] && [ "${OPERATION}" != "archive" ] && [ "${OPERATION}" != "release" ] && [ "${OPERATION}" != "clean" ] && [ "${OPERATION}" != "validate" ] && [ "${OPERATION}" != "keychain-prep" ] ; then
#    usage
#fi;

# Parse the rest of any arguments
PARSED_ARGUMENTS=$(getopt ds:c:x:ujmtqakly:w:ep:o: $*)
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
        -e)
            BUILD_FOR_TESTING=1
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
        -y)
            KEYCHAIN_PROFILE=${2}; shift
            shift;;
        -p)
            P12_FILE="${2}"; shift
            shift;;
        -o)
            NOTARIZATION_CREDS_FILE="${2}"; shift
            shift;;
        -w)
            TWITTER_ACCOUNT=${2}; shift
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
    echo "BUILD_FOR_TESTING is: ${BUILD_FOR_TESTING}"
    echo "KEYCHAIN_PROFILE is: ${KEYCHAIN_PROFILE}"
    echo "DEBUG is: ${DEBUG}"

    echo "DOCS_JSON is: ${DOCS_JSON}"
    echo "DOCS_MD is: ${DOCS_MD}"
    echo "DOCS_HTML is: ${DOCS_HTML}"
    echo "DOCS_SQL is: ${DOCS_SQL}"
    echo "DOCS_DASH is: ${DOCS_DASH}"
    echo "DOCS_LUASKIN is: ${DOCS_LUASKIN}"
    echo "DOCS_LINT_ONLY is: ${DOCS_LINT_ONLY}"

    # Enable script tracing, with timestamps
    #export PS4='+\t '
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
export BUILD_FOR_TESTING
export KEYCHAIN_PROFILE
export TWITTER_ACCOUNT
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
    echo "ERROR: Unable to find greadlink. Please run `brew install coreutils` and then `$0 installdeps`"
    exit 1
fi
# This silly which dancing is to ensure we don't trip over a zsh alias for 'grm' to 'git rm'
export RM ; RM="$(which -a grm | grep -v aliased | head -1) --one-file-system --preserve-root"

# Calculate some variables we need later
echo "Gathering info..."

export SCRIPT_NAME ; SCRIPT_NAME="$(basename "$0")"
export SCRIPT_HOME ; SCRIPT_HOME="$(dirname "$(greadlink -f "$0")")"
export HAMMERSPOON_HOME ; HAMMERSPOON_HOME="$(greadlink -f "${SCRIPT_HOME}/../")"
export WEBSITE_HOME ; WEBSITE_HOME="$(greadlink -f "${HAMMERSPOON_HOME}/../website")"
export BUILD_HOME="${HAMMERSPOON_HOME}/build"
export CI_ARTIFACTS_HOME="${HAMMERSPOON_HOME}/artifacts"

export HAMMERSPOON_BUNDLE_NAME="${APP_NAME}.app"
export HAMMERSPOON_BUNDLE_PATH="${BUILD_HOME}/${HAMMERSPOON_BUNDLE_NAME}"
export HAMMERSPOON_XCARCHIVE_PATH="${HAMMERSPOON_BUNDLE_PATH}.xcarchive"
export XCODE_BUILT_PRODUCTS_DIR ; XCODE_BUILT_PRODUCTS_DIR="$(xcodebuild -workspace Hammerspoon.xcworkspace -scheme "${XCODE_SCHEME}" -configuration "${XCODE_CONFIGURATION}" -destination "platform=macOS" -showBuildSettings | sort | uniq | grep ' BUILT_PRODUCTS_DIR =' | awk '{ print $3 }')"
export DOCS_SEARCH_DIRS=("${HAMMERSPOON_HOME}/Hammerspoon/" "${HAMMERSPOON_HOME}/extensions/")

# Calculate private token variables
export TOKENPATH ; TOKENPATH="$(greadlink -f "${HAMMERSPOON_HOME}/..")"
export GITHUB_TOKEN_FILE="${TOKENPATH}/token-github-release"
export GITHUB_USER="${GITHUB_USER:-hammerspoon}"
export GITHUB_REPO="${GITHUB_REPO:-hammerspoon}"
export SENTRY_TOKEN_API_FILE="${TOKENPATH}/token-sentry-api"
export SENTRY_TOKEN_AUTH_FILE="${TOKENPATH}/token-sentry-auth"
export NOTARIZATION_TOKEN_FILE="${TOKENPATH}/token-notarization"

# Calculate options for xcbeautify
export XCB_OPTS=(-q)
if [ "${IS_CI}" == "1" ] || [ "${DEBUG}" == "1" ]; then
    XCB_OPTS=()
fi

# Import our function library
# shellcheck source=scripts/libbuild.sh disable=SC1091
source "${SCRIPT_HOME}/libbuild.sh"

# Make sure our build directory exists
mkdir -p "${BUILD_HOME}"
if [ "${IS_CI}" == "1" ]; then
    mkdir -p "${CI_ARTIFACTS_HOME}"
fi

# Figure out which COMMAND we have been tasked with performing, and go do it
case "${OPERATION}" in
    "clean")
        op_clean
        ;;
    "build")
        op_build
        ;;
    "test")
        op_test
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
    "keychain-prep")
        op_keychain_prep
        ;;
    "notarize")
        op_notarize
        ;;
    "archive")
        op_archive
        ;;
    "release")
        op_release
        ;;
    *)
        echo "Unknown command: ${OPERATION}"
        usage
        ;;
esac

exit 0
