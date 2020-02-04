#!/bin/bash
#
# Copyright (c) Facebook, Inc. and its affiliates. All Rights Reserved
#
# This source code is licensed under the MIT license found in the
# LICENSE file in the root directory of this source tree.

OS_VERSION=$(sw_vers -productVersion | cut -d . -f 1,2)

case "$OS_VERSION" in
  10.13) OS_CODENAME="high_sierra";;
  10.14) OS_CODENAME="mojave";;
  10.15) OS_CODENAME="catalina";;
  *)
    echo "Unable to determine codename for Mac OS X $OS_VERSION." >&2
    exit 1
esac
