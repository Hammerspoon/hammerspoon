#!/usr/bin/env bash

set -e

# build app
xcodebuild clean build
VERSION=$(defaults read $(pwd)/Phoenix/Phoenix-Info CFBundleVersion)
FILENAME="Builds/Phoenix-$VERSION.app.tar.gz"
LATEST="Builds/Phoenix-LATEST.app.tar.gz"

# build .zip
rm -rf $FILENAME
tar -zcf $FILENAME -C build/Release Phoenix.app
echo "Created $FILENAME"

# make "latest" version for the link in the readme
rm -f $LATEST
cp $FILENAME $LATEST
echo "Created $LATEST"

# # sign update
# SIG=$(ruby ./AutoUpdating/sign_update.rb $FILENAME ~/Dropbox/STEVEN/zeph-keys/dsa_priv.pem)
# FILESIZE=$(stat -f %z $FILENAME)
# APPCASTITEM=$(cat AutoUpdating/template.xml \
#     | perl -i -pe "s|<%version%>|$VERSION|g" \
#     | perl -i -pe "s|<%signature%>|$SIG|g" \
#     | perl -i -pe "s|<%date%>|$(date)|g" \
#     | perl -i -pe "s|<%filesize%>|$FILESIZE|g")

# LINES=$(cat appcast.xml | wc -l)
# TAILPOS=$(($LINES - 7))
# TOPHALF=$(head -n 7 appcast.xml)
# BOTTOMHALF=$(tail -n $TAILPOS appcast.xml)

# echo $TOPHALF $APPCASTITEM $BOTTOMHALF | xmllint --format - > appcast.xml
# echo "New contents of appcast.xml are:"
# cat appcast.xml
# echo "Updated appcast.xml"




# TODO: write to latest_version.txt, date (unix is fine), and version number (human readable)
