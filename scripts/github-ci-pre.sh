#!/bin/bash
# Prepare GitHub Actions environment for testing

gem install xcpretty
gem install xcpretty-actions-formatter

/usr/bin/python3 -m pip install --user -r requirements.txt

brew install hub github-release gpg coreutils gawk

