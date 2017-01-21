#!/bin/bash

killall Hammerspoon

make clean
make
make docs

rm -fr `xcodebuild -workspace Hammerspoon.xcworkspace -scheme Hammerspoon -configuration DEBUG -showBuildSettings | sort | uniq | grep " BUILT_PRODUCTS_DIR =" | awk '{ print $3 }'`/Hammerspoon.app

#
# Copy FCPX Hacks Files:
#
DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
cp -R $DIR/../fcpxhacks/* $DIR/../build/Hammerspoon.app/Contents/Resources/extensions/hs/
mv $DIR/../build/Hammerspoon.app $DIR/../build/'FCPX Hacks.app'

#
# Signing with self-signed cert so I no longer have to reset accessibility all the time:
#
codesign --verbose --sign "Internal Code Signing" "build/FCPX Hacks.app/Contents/Frameworks/LuaSkin.framework/Versions/A"
codesign --verbose --sign "Internal Code Signing" "build/FCPX Hacks.app"