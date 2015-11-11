#!/bin/bash
# Helper functions for Hammerspoon release.sh

############################## UTILITY FUNCTIONS ##############################

function fail() {
  echo "ERROR: $*"
  exit 1
}

############################### SANITY CHECKERS ###############################

function assert_github_hub() {
  echo "Checking hub(1) works..."
  pushd "${HAMMERSPOON_HOME}" >/dev/null
  hub release </dev/null >/dev/null 2>&1
  if [ "$?" != "0" ]; then
    fail "ERROR: hub(1) doesn't seem to have access to the Hammerspoon repo"
  fi
}

function assert_github_release_token() {
  echo "Checking for GitHub release token..."
  if [ ! -f "${GITHUB_TOKEN_FILE}" ]; then
    fail "ERROR: You do not have a github token in ${GITHUB_TOKEN_FILE}"
  fi
  GITHUB_TOKEN=$(cat ${GITHUB_TOKEN_FILE}) github-release info >/dev/null 2>&1
  if [ "$?" != "0" ]; then
    fail "ERROR: Your github-release token doesn't seem to work"
  fi
}

function assert_codesign_authority_token() {
  echo "Checking for codesign authority token..."
  if [ ! -f "${CODESIGN_AUTHORITY_TOKEN_FILE}" ]; then
    fail "ERROR: You do not have a code signing authority token in ${CODESIGN_AUTHORITY_TOKEN_FILE} (hint, it should look like 'Authority=Developer ID Application: Foo Bar (ABC123)'"
  fi
}

function assert_version_in_xcode() {
  echo "Checking Xcode build version..."
  XCODEVER="$(defaults read "${HAMMERSPOON_HOME}/Hammerspoon/Hammerspoon-Info" CFBundleVersion)"

  if [ "$VERSION" != "$XCODEVER" ]; then
      fail "ERROR: You asked for $VERSION to be released, but Xcode will build $XCODEVER"
  fi
}

function assert_version_in_git_tags() {
  echo "Checking git tag..."
  pushd "${HAMMERSPOON_HOME}" >/dev/null
  local GITVER="$(git tag | grep "$VERSION")"
  popd >/dev/null

  if [ "$VERSION" != "$GITVER" ]; then
      pushd "${HAMMERSPOON_HOME}" >/dev/null
      git tag
      popd >/dev/null
      fail "ERROR: You asked for $VERSION to be released, but git does not know about it"
  fi
}

function assert_version_not_in_github_releases() {
  echo "Checking GitHub for pre-existing releases..."
  github-release info -t "$VERSION" >/dev/null 2>&1
  if [ "$?" == "0" ]; then
      github-release info -t "$VERSION"
      fail "ERROR: github already seems to have version $VERSION"
  fi
}

function assert_docs_bundle_complete() {
  echo "Checking docs bundle..."
  pushd "${HAMMERSPOON_HOME}/scripts/docs" >/dev/null
  bundle check >/dev/null 2>&1
  if [ "$?" != "0" ]; then
    fail "ERROR: docs bundle is incomplete. Ensure 'bundle' is installed and run 'bundle install' in hammerspoon/scripts/docs/"
  fi
  popd >/dev/null
}

function assert_cocoapods_state() {
  echo "Checking Cocoapods state..."
  pushd "${HAMERSPOON_HOME}" >/dev/null
  pod outdated >/dev/null 2>&1
  if [ "$?" != "0" ]; then
    fail "ERROR: cocoapods installation does not seem sane"
  fi
  popd >/dev/null
}

function assert_website_repo() {
  echo "Checking website repo..."
  pushd "${HAMMERSPOON_HOME}/../" >/dev/null
  if [ ! -d website/.git ]; then
    fail "ERROR: website repo does not exist. git clone git@github.com:Hammerspoon/hammerspoon.github.io.git"
  fi
  pushd website >/dev/null
  git diff-index --quiet HEAD --
  if [ "$?" != "0" ]; then
    fail "ERROR: website repo has uncommitted changes"
  fi
  git fetch origin
  local DESYNC=$(git rev-list --left-right "@{upstream}"...HEAD)
  if [ "${DESYNC}" != "" ]; then
    echo "$DESYNC"
    fail "ERROR: website repo is not in sync with upstream"
  fi
  popd >/dev/null
  popd >/dev/null
}

function assert_valid_code_signature() {
  echo "Ensuring valid code signature..."
  codesign --verify --verbose=4 "${HAMMERSPOON_HOME}/build/Hammerspoon.app"
  if [ "$?" != "0" ]; then
      codesign -dvv "${HAMMERSPOON_HOME}/build/Hammerspoon.app"
      fail "ERROR: Invalid signature"
  fi
}

function assert_valid_code_signing_entity() {
  echo "Ensuring valid signing entity..."
  local SIGNER=$(codesign --display --verbose=4 "${HAMMERSPOON_HOME}/build/Hammerspoon.app" 2>&1 | grep ^Authority | head -1)
  if [ "$SIGNER" != "$CODESIGN_AUTHORITY_TOKEN" ]; then
      fail "ERROR: App is signed with the wrong key: $SIGNER"
      exit 1
  fi
}

function assert_gatekeeper_acceptance() {
  echo "Ensuring Gatekeeper acceptance..."
  spctl --verbose=4 --assess --type execute "${HAMMERSPOON_HOME}/build/Hammerspoon.app"
  if [ "$?" != "0" ]; then
      fail "ERROR: Gatekeeper rejection"
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
      fail "ERROR: Looks like the build failed. sorry!"
  fi
}

############################ POST-BUILD FUNCTIONS #############################

function compress_hammerspoon_app() {
  echo "Compressing release..."
  pushd "${HAMMERSPOON_HOME}/build" >/dev/null
  zip -yqr "Hammerspoon-${VERSION}.zip" Hammerspoon.app/
  export ZIPLEN="$(find . -name Hammerspoon-"${VERSION}".zip -ls | awk '{ print $7 }')"
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
  cp website/docs/"${VERSION}"/*.html website/docs/
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
  git push -qf hammerspoon
  hub pull-request -m "Update Hammerspoon docset to ${VERSION}" -h hammerspoon:master
  popd >/dev/null
  popd >/dev/null
}

function release_update_appcast() {
  echo "Updating appcast.xml..."
  echo "Add this manually, for now:"
  cat <<EOF
         <item>
            <title>Version ${VERSION}</title>
            <sparkle:releaseNotesLink>
                http://www.hammerspoon.org/releasenotes/${VERSION}/
            </sparkle:releaseNotesLink>
            <pubDate>$(date +"%a, %e %b %Y %H:%M:%S %z")</pubDate>
            <enclosure url="https://github.com/Hammerspoon/hammerspoon/releases/download/${VERSION}/Hammerspoon-${VERSION}.zip"
                sparkle:version="${VERSION}"
                length="${ZIPLEN}"
                type="application/octet-stream"
            />
            <sparkle:minimumSystemVersion>10.8</sparkle:minimumSystemVersion>
        </item>
EOF
}

function release_tweet() {
  echo "Tweeting release..."
  local CURRENT=$(t accounts | grep -B1 active | head -1)
  t set active hammerspoon1
  t update "Just released ${VERSION} - http://www.hammerspoon.org/releasenotes/"
  t set active "$CURRENT"
}

