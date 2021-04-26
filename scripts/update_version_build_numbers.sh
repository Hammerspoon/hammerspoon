#!/bin/bash
# This script should be called after Copy Bundle Resources in any target you want to have an automatic version number.
#
# The main version is taken from your git tag, which must be in the form 0.0.0
# The build number is the number of commits on the current branch

set -eux

git=$(sh /etc/profile; which git)

# Use the latest tag for short version (You'll have to make sure that all your tags are of the format 0.0.0,
# this is to satisfy Apple's rule that short version be three integers separated by dots)
# using git tag for version also encourages you to create tags that match your releases
versionNumber=$("$git" describe --tags --always --abbrev=0 | sed -e 's/^v//' -e 's/g//')
buildNumber=$("$git" rev-list $("git" describe --tags --always) --count)

echo "Updating version info to ${versionNumber} (${buildNumber}) in ${TARGET_BUILD_DIR}/${INFOPLIST_PATH}"
/usr/libexec/PlistBuddy -c "Set :CFBundleVersion ${buildNumber}" "${TARGET_BUILD_DIR}/${INFOPLIST_PATH}"
/usr/libexec/PlistBuddy -c "Set :CFBundleShortVersionString ${versionNumber}" "${TARGET_BUILD_DIR}/${INFOPLIST_PATH}"

if [ -f "${BUILT_PRODUCTS_DIR}/${WRAPPER_NAME}.dSYM/Contents/Info.plist" ]; then
  /usr/libexec/PlistBuddy -c "Set :CFBundleVersion ${buildNumber}" "${BUILT_PRODUCTS_DIR}/${WRAPPER_NAME}.dSYM/Contents/Info.plist"
  /usr/libexec/PlistBuddy -c "Set :CFBundleShortVersionString ${versionNumber}" "${BUILT_PRODUCTS_DIR}/${WRAPPER_NAME}.dSYM/Contents/Info.plist"
fi

exit 0

