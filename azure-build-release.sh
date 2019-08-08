#!/bin/bash
set -ex

brew upgrade
brew unlink md5sha1sum # conflicts with coreutils
brew install gnu-sed coreutils
brew tap hhvm/hhvm
brew install $(brew deps --include-build hhvm-nightly)

exec ./build-release.sh "$1"
