#!/bin/bash
#
# Copyright (c) Facebook, Inc. and its affiliates. All Rights Reserved
#
# This source code is licensed under the MIT license found in the
# LICENSE file in the root directory of this source tree.
#

VERSION="$1"
if [ -z "${VERSION}" ]; then
  VERSION="$(date +%Y.%m.%d)"
fi
echo "Attempting to build version: $VERSION"

set -ex

if [ -n "$PLATFORM" ]; then
  source os-metadata.inc.sh
  if [ "$PLATFORM" != "$OS_VERSION" ] && [ "$PLATFORM" != "$OS_CODENAME" ]; then
    echo "Requested build for Mac OS X $PLATFORM" \
      "but we are on $OS_VERSION ($OS_CODENAME)."
    echo "Nothing to do here, good bye."
    exit 0
  fi
fi

if [ -n "$SKIP_IF_DONE" ]; then
  source os-metadata.inc.sh
  brew upgrade
  brew install jq
  if (
    curl --retry 5 "https://hhvm.com/api/build-status/$VERSION" \
      | jq .succeeded | grep "\"macos-$OS_CODENAME\""
  ); then
    echo "Package for Mac OS X $OS_VERSION ($OS_CODENAME)" \
      "has already been successfully built."
    echo "Nothing to do here, good bye."
    exit 0
  fi
fi

# Azure High Sierra workers have python@2, which causes issues installing
# python 3
brew uninstall python@2 || true
brew update
brew upgrade
brew install gnu-sed awscli gnupg

WORKDIR="$(pwd)"
(
  # This patch makes it possible to build bottles with -march=sandybridge,
  # which gets us a 20x speedup on realistic workloads, at the cost of
  # slightly worse compatibility (and having to maintain this patch).
  #
  # /usr/local/Homebrew is just a checkout of
  # https://github.com/Homebrew/brew
  #
  # In case of issues applying this patch:
  # - on a mac, run `brew upgrade`, and then try in your /usr/local/Homebrew
  # - if not on a mac, you can try working in a fresh checkout of that
  #   repository; you'll need a mac to test, but for trivial issues that
  #   might not be needed.
  cd /usr/local/Homebrew
  patch -p1 < "$WORKDIR/homebrew-support-sandybridge.patch"
)

brew tap hhvm/hhvm
DEPS=$(brew deps --include-build hhvm-nightly)
brew install $DEPS || brew link --overwrite $DEPS

gpg --import <<ENDKEY
-----BEGIN PGP PUBLIC KEY BLOCK-----

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
=3DTP
-----END PGP PUBLIC KEY BLOCK-----
ENDKEY

git config remote.origin.url git@github.com:hhvm/homebrew-hhvm.git
git config user.name "HHVM Homebrew Bot (Azure)"
git config user.email opensource+hhvm-homebrew-bot@fb.com

exec ./build-release.sh "$VERSION"
