#!/bin/bash
#
# Copyright (c) Facebook, Inc. and its affiliates. All Rights Reserved
#
# This source code is licensed under the MIT license found in the
# LICENSE file in the root directory of this source tree.
#

set -x

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
