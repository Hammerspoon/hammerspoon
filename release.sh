#!/usr/bin/env bash

set -e

# build app
xcodebuild clean build
VERSION=$(defaults read $(pwd)/Hydra/Hydra-Info CFBundleVersion)
FILENAME="Hydra-$VERSION.app.tar.gz"

# build .zip
rm -rf $FILENAME
tar -zcf $FILENAME -C build/Release Hydra.app
echo "Created $FILENAME"
