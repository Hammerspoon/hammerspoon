#!/bin/bash

AUTHOR="cmsj"
MODULE="caffeinate"

if [ "$1" == "" ]; then
    echo "Usage: upload.sh VERSION"
    exit 1
fi

VERSION="$1"

luarocks pack hs.${AUTHOR}.${MODULE}
moonrocks upload --skip-pack hs.${AUTHOR}.${MODULE}-${VERSION}.rockspec
moonrocks upload hs.${AUTHOR}.${MODULE}-${VERSION}.macosx-x86_64.rock
