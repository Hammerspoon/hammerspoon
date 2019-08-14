#!/bin/bash
# Helper functions for Hammerspoon release.sh

############################## UTILITY FUNCTIONS ##############################

function fail() {
  echo "ERROR: $*" >/dev/stderr
  exit 1
}

############################# TOP LEVEL FUNCTIONS #############################

function assert() {
  echo "******** CHECKING SANITY:"

  export GITHUB_TOKEN
  export CODESIGN_AUTHORITY_TOKEN
  assert_gawk
  assert_github_hub
  assert_github_release_token && GITHUB_TOKEN="$(cat "${GITHUB_TOKEN_FILE}")"
  assert_codesign_authority_token && CODESIGN_AUTHORITY_TOKEN="$(cat "${CODESIGN_AUTHORITY_TOKEN_FILE}")"
  assert_notarization_token && source "${NOTARIZATION_TOKEN_FILE}"
  # shellcheck source=../token-crashlytics disable=SC1091
  assert_fabric_token && source "${FABRIC_TOKEN_FILE}"
  assert_version_in_xcode
  assert_version_in_git_tags
  assert_version_not_in_github_releases
  assert_docs_bundle_complete
  assert_cocoapods_state
  assert_website_repo
}

function build() {
  echo "******** BUILDING:"

  build_hammerspoon_app
}

function validate() {
  echo "******** VALIDATING:"

  assert_valid_code_signature
  assert_valid_code_signing_entity
  assert_gatekeeper_acceptance
}

function notarize() {
  echo "******** NOTARIZING:"

  compress_hammerspoon_app
  upload_to_notary_service
  wait_for_notarization
  staple_notarization
  assert_notarization_acceptance
}

function localtest() {
  echo -n "******** TEST THE BUILD PLEASE ('yes' to confirm it works): "
  open -R build/Hammerspoon.app

  REPLY=""
  read -r REPLY

  if [ "${REPLY}" != "yes" ]; then
    echo "ERROR: User did not confirm testing, exiting."
    exit 1
  fi
}

function prepare_upload() {
  echo "******** PREPARING FOR UPLOAD:"

  compress_hammerspoon_app
}

function archive() {
  echo "******** ARCHIVING MATERIALS:"

  archive_hammerspoon_app
  archive_dSYMs
  archive_dSYM_UUIDs
  archive_docs
}

function upload() {
  echo "******** UPLOADING:"

  release_add_to_github
  release_upload_binary
  release_upload_docs
  release_submit_dash_docs
  release_update_appcast
  upload_dSYMs
}

function announce() {
  echo "******** TWEETING:"

  release_tweet
}

############################### SANITY CHECKERS ###############################

function assert_gawk() {
  if [ "$(which gawk)" == "" ]; then
    fail "gawk doesn't seem to be in your PATH. brew install gawk"
  fi
}

function assert_github_hub() {
  echo "Checking hub(1) works..."
  pushd "${HAMMERSPOON_HOME}" >/dev/null
  if ! hub release </dev/null >/dev/null 2>&1 ; then
    fail "hub(1) doesn't seem to have access to the Hammerspoon repo"
  fi
  popd >/dev/null
}

function assert_github_release_token() {
  echo "Checking for GitHub release token..."
  if [ ! -f "${GITHUB_TOKEN_FILE}" ]; then
    fail "You do not have a github token in ${GITHUB_TOKEN_FILE}"
  fi
  GITHUB_TOKEN=$(cat "${GITHUB_TOKEN_FILE}")
  if ! github-release info >/dev/null 2>&1 ; then
    fail "Your github-release token doesn't seem to work"
  fi
}

function assert_codesign_authority_token() {
  echo "Checking for codesign authority token..."
  if [ ! -f "${CODESIGN_AUTHORITY_TOKEN_FILE}" ]; then
    fail "You do not have a code signing authority token in ${CODESIGN_AUTHORITY_TOKEN_FILE} (hint, it should look like 'Authority=Developer ID Application: Foo Bar (ABC123)'"
  fi
}

function assert_notarization_token() {
  echo "Checking for notarization token..."
  if [ ! -f "${NOTARIZATION_TOKEN_FILE}" ]; then
    fail "You do not have a notarization token in ${NOTARIZATION_TOKEN_FILE}"
  fi
}

function assert_fabric_token() {
  echo "Checking for Fabric API tokens..."
  if [ ! -f "${FABRIC_TOKEN_FILE}" ]; then
    fail "You do not have Fabric API tokens in ${FABRIC_TOKEN_FILE}"
  fi
}

function assert_version_in_xcode() {
  echo "Checking Xcode build version..."
  XCODEVER="$(defaults read "${HAMMERSPOON_HOME}/Hammerspoon/Hammerspoon-Info" CFBundleVersion)"

  if [ "$VERSION" != "$XCODEVER" ]; then
      fail "You asked for $VERSION to be released, but Xcode will build $XCODEVER"
  fi
}

function assert_version_in_git_tags() {
  echo "Checking git tag..."
  pushd "${HAMMERSPOON_HOME}" >/dev/null
  local GITVER
  GITVER="$(git tag | grep "$VERSION")"
  popd >/dev/null

  if [ "$VERSION" != "$GITVER" ]; then
      pushd "${HAMMERSPOON_HOME}" >/dev/null
      git tag
      popd >/dev/null
      fail "You asked for $VERSION to be released, but git does not know about it"
  fi
}

function assert_version_not_in_github_releases() {
  echo "Checking GitHub for pre-existing releases..."
  if github-release info -t "$VERSION" >/dev/null 2>&1 ; then
      github-release info -t "$VERSION"
      fail "github already seems to have version $VERSION"
  fi
}

function assert_docs_bundle_complete() {
  echo "Checking docs bundle..."
  echo "WARNING: This check does nothing, if you have not met requirements.txt with pip/other, doc building will fail"
}

function assert_cocoapods_state() {
  echo "Checking Cocoapods state..."
  pushd "${HAMMERSPOON_HOME}" >/dev/null
  if ! pod outdated >/dev/null 2>&1 ; then
    fail "cocoapods installation does not seem sane"
  fi
  popd >/dev/null
}

function assert_website_repo() {
  echo "Checking website repo..."
  pushd "${HAMMERSPOON_HOME}/../" >/dev/null
  if [ ! -d website/.git ]; then
    fail "website repo does not exist. git clone git@github.com:Hammerspoon/hammerspoon.github.io.git"
  fi
  pushd website >/dev/null
  if ! git diff-index --quiet HEAD -- ; then
    fail "website repo has uncommitted changes"
  fi
  git fetch origin
  local DESYNC
  DESYNC=$(git rev-list --left-right "@{upstream}"...HEAD)
  if [ "${DESYNC}" != "" ]; then
    echo "$DESYNC"
    fail "website repo is not in sync with upstream"
  fi
  popd >/dev/null
  popd >/dev/null
}

function assert_valid_code_signature() {
  echo "Ensuring valid code signature..."
  if ! codesign --verify --verbose=4 "${HAMMERSPOON_HOME}/build/Hammerspoon.app" ; then
      codesign -dvv "${HAMMERSPOON_HOME}/build/Hammerspoon.app"
      fail "Invalid signature"
  fi
}

function assert_valid_code_signing_entity() {
  echo "Ensuring valid signing entity..."
  local SIGNER
  SIGNER=$(codesign --display --verbose=4 "${HAMMERSPOON_HOME}/build/Hammerspoon.app" 2>&1 | grep ^Authority | head -1)
  if [ "$SIGNER" != "$CODESIGN_AUTHORITY_TOKEN" ]; then
      fail "App is signed with the wrong key: $SIGNER"
      exit 1
  fi
}

function assert_gatekeeper_acceptance() {
  echo "Ensuring Gatekeeper acceptance..."
  if ! spctl --verbose=4 --assess --type execute "${HAMMERSPOON_HOME}/build/Hammerspoon.app" ; then
      fail "Gatekeeper rejection"
      exit 1
  fi
}

############################### BUILD FUNCTIONS ###############################

function build_hammerspoon_app() {
  echo "Building Hammerspoon.app..."
  pushd "${HAMMERSPOON_HOME}" >/dev/null
  make clean
  make release
  rm build/docs.json
  make docs
  make build/html/LuaSkin
  popd >/dev/null
  if [ ! -e "${HAMMERSPOON_HOME}"/build/Hammerspoon.app ]; then
      fail "Looks like the build failed. sorry!"
  fi
}

############################ NOTARIZATION FUNCTIONS ###########################

function assert_notarization_acceptance() {
    echo "Ensuring Notarization acceptance..."
    if ! xcrun stapler validate "${HAMMERSPOON_HOME}/build/Hammerspoon.app" ; then
        fail "Notarization rejection"
        exit 1
    fi
}

function upload_to_notary_service() {
    echo "Uploading to Apple Notarization Service..."
    pushd "${HAMMERSPOON_HOME}" >/dev/null
    mkdir -p "../archive/${VERSION}"
    local OUTPUT=""
    OUTPUT=$(xcrun altool --notarize-app \
                --primary-bundle-id "org.hammerspoon.Hammerspoon" \
                --file "build/Hammerspoon-${VERSION}.zip" \
                --username "${NOTARIZATION_USERNAME}" \
                --password "${NOTARIZATION_PASSWORD}" \
                2>&1 | tee "../archive/${VERSION}/notarization-upload.log" \
    )
    if [ "$?" != "0" ]; then
        echo "$OUTPUT"
        fail "Notarization upload failed."
    fi
    NOTARIZATION_REQUEST_UUID=$(echo ${OUTPUT} | sed -e 's/.*RequestUUID = //')
    echo "Notarization request UUID: ${NOTARIZATION_REQUEST_UUID}"
    popd >/dev/null
}

function wait_for_notarization() {
    echo -n "Waiting for Notarization..."
    while true ; do
        local OUTPUT=""
        OUTPUT=$(check_notarization_status)
        if [ "${OUTPUT}" == "Success" ] ; then
            echo ""
            break
        elif [ "${OUTPUT}" == "Working" ]; then
            echo -n "."
        else
            echo ""
            fail "Unknown output: ${OUTPUT}"
        fi
        sleep 60
    done
    echo ""
}

function check_notarization_status() {
    local OUTPUT=""
    OUTPUT=$(xcrun altool --notarization-info "${NOTARIZATION_REQUEST_UUID}" \
                --username "${NOTARIZATION_USERNAME}" \
                --password "${NOTARIZATION_PASSWORD}" \
                2>&1 \
    )
    local RESULT=""
    RESULT=$(echo "${OUTPUT}" | grep "Status: " | sed -e 's/.*Status: //')
    if [ "${RESULT}" == "in progress" ]; then
        echo "Working"
        return
    fi

    local NOTARIZATION_LOG_URL=""
    NOTARIZATION_LOG_URL=$(echo "${OUTPUT}" | grep "LogFileURL: " | awk '{ print $2 }')
    echo "Fetching Notarization log: ${NOTARIZATION_LOG_URL}" >/dev/stderr
    local STATUS=""
    STATUS=$(curl "${NOTARIZATION_LOG_URL}")
    RESULT=$(echo "${STATUS}" | jq -r .status)

    case "${RESULT}" in
        "Accepted")
            echo "Success"
            ;;
        "in progress")
            echo "Working"
            ;;
        *)
            echo "${STATUS}" | tee "../archive/${VERSION}/notarization.log"
            echo "Notarization failed: ${RESULT}"
            ;;
    esac
}

function staple_notarization() {
    echo "Stapling notarization to app bundle..."
    pushd "${HAMMERSPOON_HOME}/build" >/dev/null
    rm "Hammerspoon-${VERSION}.zip"
    xcrun stapler staple "Hammerspoon.app"
    popd >/dev/null
}

############################ POST-BUILD FUNCTIONS #############################

function compress_hammerspoon_app() {
  echo "Compressing release..."
  pushd "${HAMMERSPOON_HOME}/build" >/dev/null
  zip -yqr "Hammerspoon-${VERSION}.zip" Hammerspoon.app/
  export ZIPLEN
  ZIPLEN="$(find . -name Hammerspoon-"${VERSION}".zip -ls | awk '{ print $7 }')"
  popd >/dev/null
}

function archive_hammerspoon_app() {
  echo "Archiving binary..."
  pushd "${HAMMERSPOON_HOME}/../" >/dev/null
  mkdir -p "archive/${VERSION}"
  cp -a "${HAMMERSPOON_HOME}/build/Hammerspoon-${VERSION}.zip" "archive/${VERSION}/"
  cp -a "${HAMMERSPOON_HOME}/build/release-build.log" "archive/${VERSION}/"
  popd >/dev/null
}

function archive_dSYMs() {
  echo "Archiving .dSYM files..."
  pushd "${HAMMERSPOON_HOME}/../" >/dev/null
  mkdir -p "archive/${VERSION}/dSYM"
  rsync -arx --include '*/' --include='*.dSYM/**' --exclude='*' "${XCODE_BUILT_PRODUCTS_DIR}/" "archive/${VERSION}/dSYM/"
  popd >/dev/null
}

function upload_dSYMs() {
  echo "Uploading .dSYM files to Fabric..."
  pushd "${HAMMERSPOON_HOME}/../" >/dev/null
  if [ ! -d "archive/${VERSION}/dSYM" ]; then
    echo "ERROR: dSYM archive does not exist yet, can't upload it to Fabric. You need to fix this"
  else
    "${HAMMERSPOON_HOME}/Pods/Fabric/upload-symbols" -p mac -a "${CRASHLYTICS_API_KEY}" "archive/${VERSION}/dSYM/" >"archive/${VERSION}/dSYM-upload.log" 2>&1
  fi
  popd >/dev/null
}

function archive_docs() {
  echo "Archiving docs..."
  pushd "${HAMMERSPOON_HOME}/../" >/dev/null
  mkdir -p "archive/${VERSION}/docs"
  cp -a "${HAMMERSPOON_HOME}/build/html" "archive/${VERSION}/docs/"
  popd >/dev/null
}

function archive_dSYM_UUIDs() {
  echo "Archiving dSYM UUIDs..."
  pushd "${HAMMERSPOON_HOME}/../archive/${VERSION}/dSYM/" >/dev/null
  find . -name '*.dSYM' -exec dwarfdump -u {} \; >../dSYM_UUID.txt
  popd >/dev/null
}

############################# RELEASE FUNCTIONS ###############################

function release_add_to_github() {
  echo "Adding release..."
  github-release release --tag "$VERSION"
}

function release_upload_binary() {
  echo "Uploading binary..."
  github-release upload --tag "$VERSION" -n "Hammerspoon-${VERSION}.zip" -f "${HAMMERSPOON_HOME}/build/Hammerspoon-${VERSION}.zip"
}

function release_upload_docs() {
  echo "Uploading docs to github..."
  pushd "${HAMMERSPOON_HOME}/../" >/dev/null
  mv "${HAMMERSPOON_HOME}/build/html" "website/docs/${VERSION}"
  rm website/docs/*.html
  cp website/docs/"${VERSION}"/*.{html,css,json,js} website/docs/
  cp -r website/docs/"${VERSION}"/LuaSkin website/docs/
  pushd website >/dev/null
  git add --all "docs/"
  git commit -qam "Add docs for ${VERSION}"
  git push -q
  popd >/dev/null
  popd >/dev/null
}

function release_submit_dash_docs() {
  echo "Uploading docs to Dash..."
  pushd "${HAMMERSPOON_HOME}/../" >/dev/null
  rm -rf dash
  git clone -q git@github.com:Kapeli/Dash-User-Contributions.git dash
  cp "${HAMMERSPOON_HOME}/build/Hammerspoon.tgz" dash/docsets/Hammerspoon/
  pushd dash >/dev/null
  git remote add hammerspoon git@github.com:hammerspoon/Dash-User-Contributions.git
  cat > docsets/Hammerspoon/docset.json <<EOF
  {
      "name": "Hammerspoon",
      "version": "${VERSION}",
      "archive": "Hammerspoon.tgz",
      "author": {
          "name": "Hammerspoon Team",
          "link": "http://www.hammerspoon.org/"
      },
      "aliases": [],

      "specific_versions": [
      ]
  }
EOF
  git add docsets/Hammerspoon/Hammerspoon.tgz
  git commit -qam "Update Hammerspoon docset to ${VERSION}"
  git push -qfv hammerspoon master
  hub pull-request -f -m "Update Hammerspoon docset to ${VERSION}" -h hammerspoon:master || true
  popd >/dev/null
  popd >/dev/null
}

function release_update_appcast() {
  echo "Updating appcast.xml..."
  local NEWCHUNK="<!-- __UPDATE_MARKER__ -->
        <item>
            <title>Version ${VERSION}</title>
            <sparkle:releaseNotesLink>
                http://www.hammerspoon.org/releasenotes/${VERSION}.html
            </sparkle:releaseNotesLink>
            <pubDate>$(date +"%a, %e %b %Y %H:%M:%S %z")</pubDate>
            <enclosure url=\"https://github.com/Hammerspoon/hammerspoon/releases/download/${VERSION}/Hammerspoon-${VERSION}.zip\"
                sparkle:version=\"${VERSION}\"
                length=\"${ZIPLEN}\"
                type=\"application/octet-stream\"
            />
            <sparkle:minimumSystemVersion>10.10</sparkle:minimumSystemVersion>
        </item>
"
  gawk -i inplace -v s="<!-- __UPDATE_MARKER__ -->" -v r="${NEWCHUNK}" '{gsub(s,r)}1' appcast.xml
  git add appcast.xml
  git commit -qam "Update appcast.xml for ${VERSION}"
  git push
}

function release_tweet() {
  echo "Tweeting release..."
  local CURRENT
  CURRENT=$(t accounts | grep -B1 active | head -1)
  t set active hammerspoon1
  t update "Just released ${VERSION} - http://www.hammerspoon.org/releasenotes/"
  t set active "$CURRENT"
}

