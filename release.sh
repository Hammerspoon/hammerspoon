#!/usr/bin/env bash

set -e

PRIVKEYFILE=$1

if [ -z "$PRIVKEYFILE" ];
then
    echo "Usage: $0 <priv_key_file>"
    exit 1
fi

# build app
xcodebuild clean build
VERSION=$(defaults read $(pwd)/Hydra/Hydra-Info CFBundleVersion)
FILENAME="Builds/Hydra-$VERSION.app.tar.gz"
LATEST="Builds/Hydra-LATEST.app.tar.gz"

# build .zip
rm -rf $FILENAME
tar -zcf $FILENAME -C build/Release Hydra.app
echo "Created $FILENAME"

# make "latest" version for the link in the readme
rm -f $LATEST
cp $FILENAME $LATEST
echo "Created $LATEST"

# sign update
SIGNATURE=$(openssl dgst -sha1 -binary < $FILENAME | openssl dgst -dss1 -sign $PRIVKEYFILE | openssl enc -base64)
FILESIZE=$(stat -f %z $FILENAME)

cat <<EOF > version.txt
$(date +%s)
$VERSION
$SIGNATURE
$FILESIZE
EOF
