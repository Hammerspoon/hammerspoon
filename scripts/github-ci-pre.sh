#!/bin/bash
# Prepare GitHub Actions environment for testing

set -eu
set -o pipefail

export IS_CI=1

# Remove the pre-installed Cocoapods binary
if [ -f /usr/local/bin/pod ]; then
    rm /usr/local/bin/pod
fi

# We need coreutils before the rest of this script can proceed, so we're going to cheat and install everything even though installdeps will do this again shortly
brew bundle install

# Install build dependencies
./scripts/build.sh installdeps

# Install additional CI dependencies
gem install trainer
