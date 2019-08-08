#!/bin/bash
set -ex

brew upgrade
brew install gnu-sed coreutils
brew tap hhvm/hhvm
brew install $(brew deps --include-build hhvm-nightly)

exec ./build-release.sh "$1"
