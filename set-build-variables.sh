#!/bin/bash
#
# Copyright (c) Facebook, Inc. and its affiliates. All Rights Reserved
#
# This source code is licensed under the MIT license found in the
# LICENSE file in the root directory of this source tree.
#

set -x

count() {
  echo $#
}

FILES=$(
  git diff --name-only HEAD^ HEAD | grep ^builds/ | xargs ls 2>/dev/null || true
)

if [ $(count $FILES) != 1 ]; then
  echo "Invalid commit. Expected 1 file, got $(count $FILES) files."
  exit 1
fi

source $FILES

if [ -z "$VERSION" ]; then
  echo "Committed file must set VERSION."
  exit 1
fi
