#!/bin/bash
# Prepare GitHub Actions environment for testing

gem install trainer

/usr/bin/python3 -m pip install --user -r requirements.txt

brew install hub github-release gpg coreutils gawk xcbeautify

