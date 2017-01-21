#!/bin/bash

#
# Compile FCPX Hacks:
#
make clean
make
make docs

rm -fr `xcodebuild -workspace Hammerspoon.xcworkspace -scheme Hammerspoon -configuration DEBUG -showBuildSettings | sort | uniq | grep " BUILT_PRODUCTS_DIR =" | awk '{ print $3 }'`/FCPXHacks.app

#
# Copy FCPX Hacks Files:
#
DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
cp -R $DIR/../fcpxhacks/* $DIR/../build/FCPXHacks.app/Contents/Resources/extensions/hs/

#
# Rename FCPXHacks.app to 'FCPX Hacks.app':
#
mv $DIR/../build/FCPXHacks.app $DIR/../build/'FCPX Hacks.app'

#
# Remove all extended attributes from App Bundle (https://developer.apple.com/library/content/qa/qa1940/_index.html):
#
xattr -cr $DIR/../build/FCPXHacks.app $DIR/../build/'FCPX Hacks.app'

#
# Signing with self-signed cert so I no longer have to reset accessibility all the time:
#
codesign --verbose --sign "Internal Code Signing" "build/FCPX Hacks.app/Contents/Frameworks/LuaSkin.framework/Versions/A"
codesign --verbose --sign "Internal Code Signing" "build/FCPX Hacks.app"