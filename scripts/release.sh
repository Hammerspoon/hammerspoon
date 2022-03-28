#!/bin/bash

set -eu

echo "*** RELEASE PROCESS BEGINS..."

echo "*** CLEANING BUILD DIR..."
./scripts/build.sh clean

echo "*** GENERATING DOCS..."
./scripts/build.sh docs

echo "*** BUILDING..."
./scripts/build.sh build -s Release -c Release -u

echo "*** VALIDATING..."
./scripts/build.sh validate

echo "*** NOTARIZING..."
./scripts/build.sh notarize

echo "*** ARCHIVING..."
./scripts/build.sh archive

echo "*** ALL DONE. TO RUN THE FINAL RELEASE:"
echo "./scripts/build.sh release"

