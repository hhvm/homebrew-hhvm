#!/bin/bash
#
# Copyright (c) Facebook, Inc. and its affiliates. All Rights Reserved
#
# This source code is licensed under the MIT license found in the
# LICENSE file in the root directory of this source tree.
#

set -ex

source set-build-variables.sh

git checkout master
git pull --rebase

PLATFORM="$PLATFORM" SKIP_IF_DONE="$SKIP_IF_DONE" \
  ./azure-build-release.sh "$VERSION"
