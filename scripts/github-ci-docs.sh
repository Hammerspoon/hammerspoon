#!/bin/bash

set -e
set -o pipefail

make doclint
make docs
make build/html/LuaSkin
