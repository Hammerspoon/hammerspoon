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

export CODESIGN_AUTHORITY_TOKEN_FILE="${HAMMERSPOON_HOME}/../token-codesign-authority"
export GITHUB_TOKEN_FILE="${HAMMERSPOON_HOME}/../token-github-release"
export GITHUB_USER="hammerspoon"
export GITHUB_REPO="hammerspoon"

# Import our function library
source "${SCRIPT_HOME}/librelease.sh"

echo "******** CHECKING SANITY:"

assert_github_hub
assert_github_release_token && export GITHUB_TOKEN="$(cat "${GITHUB_TOKEN_FILE}")"
assert_codesign_authority_token && export CODESIGN_AUTHORITY_TOKEN="$(cat "${CODESIGN_AUTHORITY_TOKEN_FILE}")"
assert_version_in_xcode
assert_version_in_git_tags
assert_version_not_in_github_releases
assert_docs_bundle_complete
assert_cocoapods_state
assert_website_repo

echo "******** BUILDING:"

build_hammerspoon_app

echo "******** VALIDATING:"

assert_valid_code_signature
assert_valid_code_signing_entity
assert_gatekeeper_acceptance

echo "******** PREPARING FOR UPLOAD:"

compress_hammerspoon_app

echo "******** ARCHIVING MATERIALS:"

archive_hammerspoon_app
archive_dSYMs
archive_dSYM_UUIDs
archive_docs

echo "******** UPLOADING:"

release_add_to_github
release_upload_binary
release_upload_docs
release_submit_dash_docs
release_update_appcast

echo "Appcast zip length is: ${ZIPLEN}"

echo "******** TWEETING:"

release_tweet

echo "Done. Congratulations!"
