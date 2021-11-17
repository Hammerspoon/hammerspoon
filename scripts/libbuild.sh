#!/bin/bash
# Helper functions for Hammerspoon build.sh

############################## ERROR FUNCTIONS ##############################

function fail() {
  echo "ERROR: $*" >/dev/stderr
  exit 1
}

############################# TOP LEVEL COMMANDS #############################

function op_clean() {
    echo "Cleaning build folder..."
    ${RM} -rf "${BUILD_HOME}"

    echo "Cleaning temporary build folders..."
    xcodebuild -workspace Hammerspoon.xcworkspace -scheme "${XCODE_SCHEME}" -configuration "${XCODE_CONFIGURATION}" -destination "platform=macOS" clean | xcbeautify ${XCB_OPTS[@]:-}
}

function op_build() {
    op_build_assert

    if [ "${UPLOAD_DSYM}" == "1" ]; then
        op_sentry_assert
        echo "Importing Sentry token from: ${TOKENPATH}/token-sentry-auth"
        # shellcheck disable=SC1090
        source "${SENTRY_TOKEN_AUTH_FILE}"
    fi

    echo "Building..."
    ${RM} -rf "${HAMMERSPOON_BUNDLE_PATH}"

    local BUILD_COMMAND="archive"
    if [ "${BUILD_FOR_TESTING}" == "1" ]; then
        BUILD_COMMAND="build-for-testing"
    fi

    # Build the app
    echo "-> xcodebuild -workspace Hammerspoon.xcworkspace -scheme ${XCODE_SCHEME} -configuration ${XCODE_CONFIGURATION} -destination \"platform=macOS\" -archivePath ${HAMMERSPOON_XCARCHIVE_PATH} archive | tee ${BUILD_HOME}/${XCODE_CONFIGURATION}-build.log"
    xcodebuild -workspace Hammerspoon.xcworkspace \
               -scheme "${XCODE_SCHEME}" \
               -configuration "${XCODE_CONFIGURATION}" \
               -destination "platform=macOS" \
               -archivePath "${HAMMERSPOON_XCARCHIVE_PATH}" \
               "${BUILD_COMMAND}" | tee "${BUILD_HOME}/${XCODE_CONFIGURATION}-build.log" | xcbeautify ${XCB_OPTS[@]:-}

    if [ "${BUILD_COMMAND}" == "archive" ]; then
        # Export the app bundle from the archive
        xcodebuild -exportArchive -archivePath "${HAMMERSPOON_XCARCHIVE_PATH}" \
                   -exportOptionsPlist Hammerspoon/Build\ Configs/Archive-Export-Options.plist \
                   -exportPath "${BUILD_HOME}"
    fi

    # Upload dSYMs to Sentry if so desired
    if [ "${UPLOAD_DSYM}" == "1" ]; then
        export SENTRY_ORG="${SENTRY_ORG:-hammerspoon}"
        export SENTRY_PROJECT="${SENTRY_PROJECT:-hammerspoon}"
        export SENTRY_LOG_LEVEL=error
        if [ "${DEBUG}" == "1" ]; then
            SENTRY_LOG_LEVEL=debug
        fi
        export SENTRY_AUTH_TOKEN
        "${HAMMERSPOON_HOME}/scripts/sentry-cli" upload-dif "${HAMMERSPOON_XCARCHIVE_PATH}/dSYMs/" 2>&1 | tee "${BUILD_HOME}/sentry-upload.log"
    fi
}

function op_test() {
    op_test_assert

    mkdir -p "${BUILD_HOME}/reports"

    # We have to allow things to fail, because test runs may fail and we want the output
    set +e
    set +o pipefail
#xcodebuild -workspace Hammerspoon.xcworkspace -scheme Release test-without-building

    xcodebuild -workspace Hammerspoon.xcworkspace \
               -scheme "${XCODE_SCHEME}" \
               -configuration "${XCODE_CONFIGURATION}" \
               -resultBundlePath "${BUILD_HOME}/TestResults" \
               test-without-building 2>&1 | tee "${BUILD_HOME}/test.log" | xcbeautify ${XCB_OPTS[@]:-}

    # Re-enable error capture
    set -e
    set -o pipefail
}

function op_validate() {
  echo "Validating ${HAMMERSPOON_BUNDLE_PATH}..."
  op_validate_assert

  # Obtain the relevant build settings
  local BUILD_SETTINGS ; BUILD_SETTINGS=$(xcodebuild -workspace Hammerspoon.xcworkspace -scheme Release -configuration Release -showBuildSettings 2>&1 | grep -E " CODE_SIGN_IDENTITY|DEVELOPMENT_TEAM|CODE_SIGN_ENTITLEMENTS")

  local SIGN_IDENTITY ; SIGN_IDENTITY=$(echo "${BUILD_SETTINGS}" | grep CODE_SIGN_IDENTITY | sed -e 's/.* = //')
  local SIGN_TEAM ; SIGN_TEAM=$(echo "${BUILD_SETTINGS}" | grep DEVELOPMENT_TEAM | sed -e 's/.* = //')
  local ENTITLEMENTS_FILE ; ENTITLEMENTS_FILE=$(echo "${BUILD_SETTINGS}" | grep CODE_SIGN_ENTITLEMENTS | sed -e 's/.* = //')

  # Validate that the app bundle has a correct signature at all
  if ! codesign --verify "${HAMMERSPOON_BUNDLE_PATH}" ; then
      codesign -dvv "${HAMMERSPOON_BUNDLE_PATH}"
      fail "Invalid signature"
  fi
  echo "  ✅ App bundle is signed"

  # Fetch the app bundle's relevant signature data
  local APP_SIGNATURE ; APP_SIGNATURE=$(codesign --display --verbose=4 "${HAMMERSPOON_BUNDLE_PATH}" 2>&1 | grep ^Authority | head -1)

  # Check that the signing team is correct (this is the bit that looks like ABCDEF123G)
  # shellcheck disable=SC2001
  if [ "$SIGN_TEAM" != "$(echo "${APP_SIGNATURE}" | sed -e 's/.*(\(.*\))/\1/')" ]; then
      fail "App is signed with the wrong key: $APP_SIGNATURE (expecting $SIGN_TEAM)"
  fi
  echo "  ✅ Signing team is correct (${SIGN_TEAM})"

  # Check that the signing identity is correct (typically this should be "Developer ID Application")
  # shellcheck disable=SC2001
  if [ "${SIGN_IDENTITY}" != "$(echo "${APP_SIGNATURE}" | sed -e 's/.*=\(.*\):.*/\1/')" ]; then
      fail "App is signed with the wrong identity: $APP_SIGNATURE (expecting $SIGN_IDENTITY)"
  fi
  echo "  ✅ Signing identity is correct (${SIGN_IDENTITY})"

  # Check that Gatekeepr accepts the app bundle
  if ! spctl --assess --type execute "${HAMMERSPOON_BUNDLE_PATH}" ; then
      spctl --verbose=4 --assess --type execute "${HAMMERSPOON_BUNDLE_PATH}"
      fail "Gatekeeper rejection:"
  fi
  echo "  ✅ Gatekeeper accepts the app bundle"

  # Check that the app bundle has the expected entitlements
  local EXPECTED_ENTITLEMENTS ; EXPECTED_ENTITLEMENTS=$(xmllint --c14n --format "${HAMMERSPOON_HOME}/${ENTITLEMENTS_FILE}" 2>/dev/null)
  # FIXME: the ':-' syntax is deprecated, when we stop caring about building on <Monterey machines, this is the correct new line
  #local ACTUAL_ENTITLEMENTS ; ACTUAL_ENTITLEMENTS=$(codesign --display --entitlements - --xml "${HAMMERSPOON_BUNDLE_PATH}" | xmllint --c14n --format -)
  local ACTUAL_ENTITLEMENTS ; ACTUAL_ENTITLEMENTS=$(codesign --display --entitlements :- "${HAMMERSPOON_BUNDLE_PATH}" | xmllint --c14n --format -)

  if [ "${EXPECTED_ENTITLEMENTS}" != "${ACTUAL_ENTITLEMENTS}" ]; then
      echo "***** EXPECTED ENTITLEMENTS (${ENTITLEMENTS_FILE}):"
      echo "${EXPECTED_ENTITLEMENTS}"
      echo "***** ACTUAL ENTITLEMENTS:"
      echo "${ACTUAL_ENTITLEMENTS}"
      echo "*****"
      fail "Entitlements did not apply correctly"
  fi
  echo "  ✅ Entitlements are as expected"

  echo ""
  echo "  🎉 ${HAMMERSPOON_BUNDLE_PATH} is fully valid"
}

function op_docs() {
    op_docs_assert

    local LSDOCSDIR="${BUILD_HOME}/html/LuaSkin"
    local DOCSCRIPT="${HAMMERSPOON_HOME}/scripts/docs/bin/build_docs.py"

    if [ "${DOCS_LINT_ONLY}" == 1 ]; then
        "${DOCSCRIPT}" -l ${DOCS_SEARCH_DIRS[*]}
        echo "Docs lint OK"
        return # We return here because this option cannot be used with any of the subsequent ones
    fi

    if [ "${DOCS_JSON}" == 1 ]; then
        echo "Building docs JSON..."
        "${DOCSCRIPT}" -o "${BUILD_HOME}" --json ${DOCS_SEARCH_DIRS[@]}
    fi

    if [ "${DOCS_MD}" == 1 ]; then
        echo "Building docs Markdown..."
        "${DOCSCRIPT}" -o "${BUILD_HOME}" --markdown ${DOCS_SEARCH_DIRS[@]}
    fi

    if [ "${DOCS_HTML}" == 1 ]; then
        echo "Building docs HTML..."
        "${DOCSCRIPT}" -o "${BUILD_HOME}" --html ${DOCS_SEARCH_DIRS[@]}
    fi

    if [ "${DOCS_SQL}" == 1 ]; then
        echo "Building docs SQLite..."
        "${DOCSCRIPT}" -o "${BUILD_HOME}" --sql ${DOCS_SEARCH_DIRS[@]}
    fi

    if [ "${DOCS_DASH}" == 1 ]; then
        echo "Building docs Dash..."
        local DASHDIR="${BUILD_HOME}/Hammerspoon.docset"
        ${RM} -rf "${DASHDIR}"
        ${RM} -rf "${LSDOCSDIR}"
        cp -R "${HAMMERSPOON_HOME}/scripts/docs/templates/Hammerspoon.docset" "${DASHDIR}"
        cp "${BUILD_HOME}/docs.sqlite" "${DASHDIR}/Contents/Resources/docSet.dsidx"
        cp "${HAMMERSPOON_HOME}"/build/html/* "${DASHDIR}/Contents/Resources/Documents/"
        tar -cvf "${BUILD_HOME}/Hammerspoon.tgz" -C "${BUILD_HOME}" Hammerspoon.docset >"${BUILD_HOME}/docset-tar.log" 2>&1
    fi

    if [ "${DOCS_LUASKIN}" == 1 ]; then
        echo "Building docs LuaSkin..."
        mkdir -p "${LSDOCSDIR}"
        headerdoc2html -u -o "${LSDOCSDIR}" "${HAMMERSPOON_HOME}/LuaSkin/LuaSkin/Skin.h" >"${BUILD_HOME}/luaskin-headerdoc.log" 2>&1
        resolveLinks "${LSDOCSDIR}" >"${BUILD_HOME}/luaskin-resolveLinks.log" 2>&1
        mv "${LSDOCSDIR}"/Skin_h/* "${LSDOCSDIR}"
        rmdir "${LSDOCSDIR}/Skin_h"
    fi

    echo "Docs built"
}

function op_installdeps() {
    echo "Installing dependencies..." 
    echo "  Homebrew packages..."
    brew install coreutils jq xcbeautify gawk cocoapods gh || fail "Unable to install Homebrew dependencies"

    echo "  Python packages..."
    /usr/bin/pip3 install --user --disable-pip-version-check -r "${HAMMERSPOON_HOME}/requirements.txt" || fail "Unable to install Python dependencies"

    echo "  Ruby packages..."
    /usr/bin/gem install --user t || fail "Unable to install Ruby dependencies"
}

function op_keychain_prep() {
    echo " Preparing keychain..."
    op_keychain_prep_assert

    local SECBIN="/usr/bin/security"
    local KEYCHAIN="build.keychain"

    # Note: This will fail if KEYCHAIN_PASSPHRASE isn't set in the environment.
    #  This is explicitly undocumented because this really shouldn't be called anywhere other than CI
    if [ "${P12_FILE}" != "" ]; then
        echo " Creating new default keychain: ${KEYCHAIN}"
        "${SECBIN}" create-keychain -p "${KEYCHAIN_PASSPHRASE}" "${KEYCHAIN}"
        "${SECBIN}" default-keychain -s "${KEYCHAIN}"

        echo " Unlocking keychain..."
        "${SECBIN}" unlock-keychain -p "${KEYCHAIN_PASSPHRASE}" "${KEYCHAIN}"

        echo " Importing signing certificate/key..."
        "${SECBIN}" import "${P12_FILE}" -f pkcs12 -k "${KEYCHAIN}" -P "${KEYCHAIN_PASSPHRASE}" -T /usr/bin/codesign -x

        echo " Removing keychain autolocking settings..."
        "${SECBIN}" set-keychain-settings -t 1200

        echo " Setting permissions for keychain..."
        "${SECBIN}" -q set-key-partition-list -S apple-tool:,apple:,codesign: -s -k "${KEYCHAIN_PASSPHRASE}" "${KEYCHAIN}"

        echo " Listing keychains:"
        "${SECBIN}" list-keychains -d user

        echo " Dumping keychain identity:"
        "${SECBIN}" find-identity -v
    fi

    if [ "${NOTARIZATION_CREDS_FILE}" != "" ]; then
        source "${NOTARIZATION_CREDS_FILE}"

        local SIGN_TEAM ; SIGN_TEAM=$(xcodebuild -workspace Hammerspoon.xcworkspace -scheme Release -configuration Release -showBuildSettings 2>&1 | grep -E " DEVELOPMENT_TEAM" | sed -e 's/.* = //')

        xcrun notarytool store-credentials --sync "${KEYCHAIN_PROFILE}" --apple-id "${NOTARIZATION_USERNAME}" --team-id "${SIGN_TEAM}" --password "${NOTARIZATION_PASSWORD}"

        unset NOTARIZATION_USERNAME
        unset NOTARIZATION_PASSWORD
    fi
}

function op_notarize() {
    echo " Notarizing ${HAMMERSPOON_BUNDLE_PATH}..."
    op_notarize_assert

    echo " Zipping..."
    local ZIP_PATH="${HAMMERSPOON_BUNDLE_PATH}.zip"
    create_zip "${HAMMERSPOON_BUNDLE_PATH}" "${ZIP_PATH}"

    echo " Uploading to Apple Notary Service (may take many minutes)..."
    local UPLOAD_OUTPUT ; UPLOAD_OUTPUT=$(xcrun notarytool submit "${ZIP_PATH}" --keychain-profile "${KEYCHAIN_PROFILE}" --wait -f json)
    local UPLOAD_ID ; UPLOAD_ID=$(echo "${UPLOAD_OUTPUT}" | jq -r .id)
    local UPLOAD_STATUS ; UPLOAD_STATUS=$(echo "${UPLOAD_OUTPUT}" | jq -r .status)
    local UPLOAD_MSG ; UPLOAD_MSG=$(echo "${UPLOAD_OUTPUT}" | jq -r .message)

    echo " Fetching notarization log..."
    xcrun notarytool log "${UPLOAD_ID}" --keychain-profile "${KEYCHAIN_PROFILE}" "${BUILD_HOME}/notarization-log.json"

    if [ "${UPLOAD_STATUS}" != "Accepted" ]; then
        echo "Notarization upload is in an unexpected state: ${UPLOAD_STATUS} (${UPLOAD_MSG})"
        echo "Upload log follows:"
        cat build/notarization-log.json
        fail "Unable to continue"
    fi

    echo " Stapling notarization ticket..."
    xcrun stapler staple "${HAMMERSPOON_BUNDLE_PATH}"

    echo " Validating notarization..."
    if ! xcrun stapler validate "${HAMMERSPOON_BUNDLE_PATH}" ; then
        fail "Notarization rejection"
    fi

    # Remove the zip we uploaded for Notarization
    ${RM} "${HAMMERSPOON_BUNDLE_PATH}.zip"

    # At this stage we don't know if this is a full release build or a CI build, so prepare a notarized zip for both
    create_zip "${HAMMERSPOON_BUNDLE_PATH}" "${HAMMERSPOON_BUNDLE_PATH}-$(release_version).zip"
    create_zip "${HAMMERSPOON_BUNDLE_PATH}" "${HAMMERSPOON_BUNDLE_PATH}-$(nightly_version).zip"

    echo " ✅ Notarization successful!"
}

function op_archive() {
    local VERSION ; VERSION="$(get_version)"
    local ARCHIVE_PATH="${HAMMERSPOON_HOME}/../archive/${VERSION}"

    echo "Archiving to ${ARCHIVE_PATH}..."
    mkdir -p "${ARCHIVE_PATH}"

    # Archive the final zip, the xcarchive, and all the build/notarization/sentry logfiles
    cp -a "${HAMMERSPOON_BUNDLE_PATH}-${VERSION}.zip" "${ARCHIVE_PATH}/"
    cp -a "${HAMMERSPOON_XCARCHIVE_PATH}" "${ARCHIVE_PATH}/"
    cp -a "${BUILD_HOME}"/*.log "${ARCHIVE_PATH}/"
    cp -a "${BUILD_HOME}"/*.plist "${ARCHIVE_PATH}/"

    # Dump dSYM UUIDs and archive them
    find "${HAMMERSPOON_XCARCHIVE_PATH}" -name '*.dSYM' -exec dwarfdump -u {} \; >"${ARCHIVE_PATH}/dSYM_UUID.txt"
    create_zip "${HAMMERSPOON_XCARCHIVE_PATH}/dSYMs" "${ARCHIVE_PATH}/${APP_NAME}-dSYM-${VERSION}.zip"

    # Archive the docs
    mkdir -p "${ARCHIVE_PATH}/docs"
    cp -a "${BUILD_HOME}/docs.json" "${ARCHIVE_PATH}/docs/"
    create_zip "${BUILD_HOME}/html" "${ARCHIVE_PATH}/docs/${VERSION}-docs.zip"
}

function op_release() {
    local VERSION ; VERSION="$(release_version)"
    op_release_assert

    # We always do a local test of the signed/notarized build, to ensure it runs
    echo "Opening Finder for a local test..."
    open -R "${HAMMERSPOON_BUNDLE_PATH}"
    echo -n "******** TEST THE BUILD PLEASE ('yes' to confirm it works):"
    local REPLY=""
    read -r REPLY

    if [ "${REPLY}" != "yes" ]; then
        fail "User rejected build"
    fi

    # Prepaer the release archive
    echo " Zipping..."
    local ZIP_PATH="${HAMMERSPOON_BUNDLE_PATH}.zip"
    create_zip "${HAMMERSPOON_BUNDLE_PATH}" "${ZIP_PATH}"

    echo " Creating release on GitHub..."
    gh release create "${VERSION}" "${ZIP_PATH}" --title "${VERSION}" --notes-file "${WEBSITE_HOME}/_posts/$(date "+%Y-%m-%d")-${VERSION}.md"

    echo " Uploading docs to website..."
    pushd "${WEBSITE_HOME}" >/dev/null || fail "Unable to access website repo at ${WEBSITE_HOME}"
    mkdir -p "docs/${VERSION}"
    ${RM} docs/*.html
    ${RM} -rf docs/LuaSkin
    cp -r "${BUILD_HOME}/html/" docs/
    cp -r "${BUILD_HOME}/html/" "docs/${VERSION}/"
    popd >/dev/null || fail "Unknown"

    echo " Creating PR for Dash docs..."
    pushd "${HAMMERSPOON_HOME}/../" >/dev/null || fail "Unable to access ${HAMMERSPOON_HOME}/../"
    ${RM} -rf dash
    git clone -q git@github.com:Kapeli/Dash-User-Contributions.git dash
    cp "${BUILD_HOME}/Hammerspoon.tgz" dash/docsets/Hammerspoon/
    pushd "dash" >/dev/null || fail "Unable to access dash repo at: ${HAMMERSPOON_HOME}/../dash"
    git remote add hammerspoon git@github.com:hammerspoon/Dash-User-Contributions.git
    cat >docsets/Hammerspoon/docset.json <<EOF
    {
       "name": "Hammerspoon",
       "version": "${VERSION}",
       "archive": "Hammerspoon.tgz",
       "author": {
           "name": "Hammerspoon Team",
           "link": "https://www.hammerspoon.org/"
       },
       "aliases": [],
       "specific_versions": [
       ]
   }
EOF
    git add docsets/Hammerspoon/Hammerspoon.tgz
    git commit -qam "Update Hammerspoon docset to ${VERSION}"
    git push -qfv hammerspoon master
    gh pr create "Update Hammerspoon docset to ${VERSION}"
    popd >/dev/null || fail "Unknown"
    popd >/dev/null || fail "Unknown"

    echo " Updating appcast.xml..."
    pushd "${HAMMERSPOON_HOME}/" >/dev/null || fail "Unable to access ${HAMMERSPOON_HOME}/"
    local BUILD_NUMBER ; BUILD_NUMBER=$(git rev-list "$(git symbolic-ref HEAD | sed -e 's,.*/\\(.*\\),\\1,')" --count)
    local NEWCHUNK ; NEWCHUNK="<!-- __UPDATE_MARKER__ -->
          <item>
              <title>Version ${VERSION}</title>
              <sparkle:releaseNotesLink>
                  https://www.hammerspoon.org/releasenotes/${VERSION}.html
              </sparkle:releaseNotesLink>
              <pubDate>$(date +"%a, %e %b %Y %H:%M:%S %z")</pubDate>
              <enclosure url=\"https://github.com/Hammerspoon/hammerspoon/releases/download/${VERSION}/Hammerspoon-${VERSION}.zip\"
                  sparkle:version=\"${BUILD_NUMBER}\"
                  sparkle:shortVersionString=\"${VERSION}\"
                  length=\"${ZIPLEN}\"
                  type=\"application/octet-stream\"
              />
              <sparkle:minimumSystemVersion>10.12</sparkle:minimumSystemVersion>
          </item>
  "
    gawk -i inplace -v s="<!-- __UPDATE_MARKER__ -->" -v r="${NEWCHUNK}" '{gsub(s,r)}1' appcast.xml
    git add appcast.xml
    git commit -qam "Update appcast.xml for ${VERSION}"
    git push
    popd >/dev/null || fail "Unknown"

    if [ "${TWITTER_ACCOUNT}" != "" ]; then
        echo " Tweeting release..."
        local CURRENT_T_ACCOUNT ; CURRENT_T_ACCOUNT=$(t accounts | grep -B1 active | head -1)
        t set active "${TWITTER_ACCOUNT}"
        t update "Just released ${VERSION} - https://www.hammerspoon.org/releasenotes/"
        t set acctive "${CURRENT_T_ACCOUNT}"
    fi
}

############################## COMMAND ASSERTIONS ##############################
function op_build_assert() {
    echo "Checking build environment..."
    assert_gawk
    assert_xcbeautify
    assert_cocoapods_state
    assert_docs_requirements

    if [ "${XCODE_CONFIGURATION}" == "Release" ]; then
        if [ ! -f "${SENTRY_TOKEN_API_FILE}" ]; then
            fail "Release build requested, but no Sentry API token exists at: ${SENTRY_TOKEN_API_FILE}"
        fi
    fi
}

function op_test_assert() {
    # Nothing to assert here for now
    return
}

function op_docs_assert() {
    echo "Checking docs environment..."
    assert_docs_requirements
}

function op_installdeps_assert() {
    echo "Checking environment..."
    if [ ! "$(which brew)" ]; then
        echo "Unable to continue without Homebrew installed, please see: https://brew.sh/"
        exit 1
    fi
}

function op_validate_assert() {
  if [ ! -e "${HAMMERSPOON_BUNDLE_PATH}" ]; then
    fail "Unable to validate ${HAMMERSPOON_BUNDLE_PATH}, it doesn't exist"
  fi
}

function op_keychain_prep_assert() {
    if [ "${IS_CI}" != "1" ]; then
        echo "You almost certainly don't want to do this keychain preparation outside of CI"
        echo "If you are absolutely sure that you do want to, export IS_CI=1"
        echo " BE WARNED: If you force this to run and give it a P12 file, it will create a new default keychain on your Mac"
        fail "Refusing to continue"
    fi

    if [ "${P12_FILE}" == "" ] && [ "${NOTARIZATION_CREDS_FILE}" == "" ]; then
        fail "Can't prepare a keychain without either a P12 file or a Notarization Credentials file (or both)"
    fi

    if [ "${P12_FILE}" != "" ] && [ ! -e "${P12_FILE}" ]; then
        fail "Unable to access P12 signing certificate: ${P12_FILE}"
    fi

    if [ "${NOTARIZATION_CREDS_FILE}" != "" ] && [ ! -e "${NOTARIZATION_CREDS_FILE}" ]; then
        fail "Unable to access Notarization credentials file: ${NOTARIZATION_CREDS_FILE}"
    fi
}

function op_notarize_assert() {
  # FIXME: Figure out a way to assert that the keychain profile exists
  return
}

function op_archive_assert() {
    if [ ! -e "${HAMMERSPOON_BUNDLE_PATH}-${VERSION}.zip" ]; then
        fail "Unable to archive: ${HAMMERSPOON_BUNDLE_PATH}-${VERSION}.zip is missing"
    fi

    if [ ! -e "${HAMMERSPOON_XCARCHIVE_PATH}" ]; then
        fail "Unable to archive: ${HAMMERSPOON_XCARCHIVE_PATH} is missing"
    fi

    if [ ! -e "${BUILD_HOME}/docs.json" ]; then
        fail "Unable to archive: ${BUILD_HOME}/docs.json is missing"
    fi

    if [ ! -e "${BUILD_HOME}/html" ]; then
        fail "Unable to archive: ${BUILD_HOME}/html is missing"
    fi
}

function op_sentry_assert() {
    if [ ! -f "${SENTRY_TOKEN_AUTH_FILE}" ]; then
        fail "You do not have a Sentry auth tokens in ${SENTRY_TOKEN_AUTH_FILE}"
    fi
}

function op_release_assert() {
    echo "Checking release notes exist..."
    local RNOTES ; RNOTES="${WEBSITE_HOME}/_posts/$(date "+%Y-%m-%d")-${VERSION}.md"
    if [ ! -f "${RNOTES}" ]; then
        fail "Unable to find expected release notes: ${RNOTES}"
    fi

    echo "Checking GitHub login status..."
    if ! gh auth status >/dev/null 2>&1 ; then
        echo " gh not logged in, trying with ${GITHUB_TOKEN_FILE}"
        # GitHub CLI client is not currently logged in, let's see if we have a token available and can fix it
        if [ ! -f "${GITHUB_TOKEN_FILE}" ]; then
            fail "You do not have a GitHub auth token in ${GITHUB_TOKEN_FILE}. Generate one with 'read:org, repo' permissions at: https://github.com/settings/tokens, or run 'gh auth login'"
        fi
        gh auth login --with-token <"${GITHUB_TOKEN_FILE}"

        if ! gh auth status >/dev/null 2>&1 ; then
            fail "Unable to login to GitHub with token in ${GITHUB_TOKEN_FILE}"
        fi
    fi

    # Ensure we have a full tag for the release
    echo "Checking release tag..."
    pushd "${HAMMERSPOON_HOME}" >/dev/null || fail "Unable to access ${HAMMERSPOON_HOME}"
    local TAGTYPE ; TAGTYPE="$(git cat-file -t "${VERSION}")"
    if [ "${TAGTYPE}" != "tag" ]; then
        fail "${VERSION} is not an annotated tag, it is either missing or is a lightweight tag. Use: git tag -a ${VERSION}"
    fi
    popd >/dev/null || fail "Unknown"

    # Ensure this tag is not already released
    if gh release view "${VERSION}" >/dev/null 2>&1 ; then
        fail "${VERSION} already exists on GitHub, cannot re-release"
    fi

    # Check that the website repo is present, has no uncommitted changes, and is in-sync with upstream
    pushd "${WEBSITE_HOME}" >/dev/null || fail "Website repo missing/inaccessible at: ${WEBSITE_HOME}"
    if ! git diff-index --quiet HEAD -- ; then
        fail "Website repo has uncommitted changes, please commit or stash them before releasing"
    fi
    git fetch origin
    local DESYNC
    DESYNC="$(git rev-list --left-right "@{upstream}"...HEAD)"
    if [ "${DESYNC}" != "" ]; then
        fail "Website repo is out of sync with GitHub, please sync before releasing"
    fi
    popd >/dev/null || fail "Unknown"
}

############################## ASSERTION HELPERS ###############################
function assert_gawk() {
  if [ "$(which gawk)" == "" ]; then
    fail "gawk doesn't seem to be in your PATH. Try $0 installdeps"
  fi
}

function assert_xcbeautify() {
  if [ "$(which xcbeautify)" == "" ]; then
    fail "xcbeautify is not in PATH. Try $0 installdeps"
  fi
}

function assert_docs_requirements() {
  echo "Checking Python requirements.txt is satisfied..."
  echo "import sys
import pkg_resources
from pkg_resources import DistributionNotFound, VersionConflict
dependencies = open('${HAMMERSPOON_HOME}/requirements.txt', 'r').readlines()
pkg_resources.require(dependencies)" | /usr/bin/python3
}

function assert_cocoapods_state() {
  echo "Checking Cocoapods state..."
  pushd "${HAMMERSPOON_HOME}" >/dev/null || fail "Unable to enter ${HAMMERSPOON_HOME}"
  if ! pod outdated >/dev/null 2>&1 ; then
    fail "cocoapods installation does not seem sane"
  fi
  popd >/dev/null || fail "Unknown"
}

############################## UTILITY HELPERS ###############################
function get_version() {
    if [ "${IS_NIGHTLY}" == "1" ]; then
        nightly_version
    else
        release_version
    fi
}

function release_version() {
    local VERSION ; VERSION=$(cd "${HAMMERSPOON_HOME}" || fail "Unable to enter ${HAMMERSPOON_HOME}" ; git describe --abbrev=0)
    echo "${VERSION}"
}

function nightly_version() {
    local VERSION ; VERSION=$(cd "${HAMMERSPOON_HOME}" || fail "Unable to enter ${HAMMERSPOON_HOME}" ; git describe)
    echo "${VERSION}"
}

function create_zip() {
    local SRC ; SRC="${1}"
    local DST ; DST="${2}"
    /usr/bin/ditto -c -k --keepParent "${SRC}" "${DST}"
}
