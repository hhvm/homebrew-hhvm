#!/bin/bash
#
# Copyright (c) Facebook, Inc. and its affiliates. All Rights Reserved
#
# This source code is licensed under the MIT license found in the
# LICENSE file in the root directory of this source tree.
#

set -ex

NUM_FILES="$(git diff --name-only HEAD^ HEAD | grep -c ^builds/)"
if [ "$NUM_FILES" != "1" ]; then
  echo "Invalid commit. Expected 1 file, got $NUM_FILES files."
  exit 1
fi

FILE="$(git diff --name-only HEAD^ HEAD | grep ^builds/)"
source "$FILE"

if [ -z "$VERSION" ]; then
  echo "Committed file must set VERSION."
  exit 1
fi

CURRENT=$(sw_vers -productVersion | cut -d . -f 1,2)
if [ -n "$PLATFORM" -a "$PLATFORM" != "$CURRENT" ]; then
  echo "Requested build for Mac OS X $PLATFORM but we are on $CURRENT."
  echo "Nothing to do here, good bye."
  # TODO: exit 0
fi

git checkout master
git pull --rebase

# TODO
echo ./azure-build-release.sh "$VERSION"

echo "DEBUG OUTPUT:"
echo
git show
echo
echo
cat ./azure-build-release.sh
