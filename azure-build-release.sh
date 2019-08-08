#!/bin/bash
set -ex

echo "Attempting to build version: $1"

brew upgrade
brew install gnu-sed
brew tap hhvm/hhvm
brew install $(brew deps --include-build hhvm-nightly)

exec ./build-release.sh "$1"
