#!/bin/bash
# Lint and build docs

set -eu
set -o pipefail

export IS_CI=1

./scripts/build.sh docs -l
./scripts/build.sh docs
