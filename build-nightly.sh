#!/bin/bash
#
# Copyright (c) Facebook, Inc. and its affiliates. All Rights Reserved
#
# This source code is licensed under the MIT license found in the
# LICENSE file in the root directory of this source tree.
#
set -ex

git pull --rebase
NIGHTLY=true ./build-release.sh $(date +%Y.%m.%d)
