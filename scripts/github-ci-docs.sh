#!/bin/bash

set -e
set -o pipefail

make docs
make build/html/LuaSkin
