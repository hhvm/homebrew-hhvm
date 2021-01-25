#!/bin/bash
#
# Copyright (c) Facebook, Inc. and its affiliates. All Rights Reserved
#
# This source code is licensed under the MIT license found in the
# LICENSE file in the root directory of this source tree.
#

set -x

source set-build-variables.sh

# Note: We don't want Azure to report a failed build if only this script fails,
# so everything is "exit 0" here.

if [ -z "$TASK_TOKEN" ]; then
  "Missing TASK_TOKEN, unable to report $1."
  exit 0
fi

try_really_hard() {
  for I in $(seq 5); do
    "$@" && return 0
    sleep 10
  done
  exit 0
}

try_really_hard sudo apt-get update
try_really_hard sudo apt-get install awscli

TIME_SEC=$(( $(date +%s) - $(git log -1 --pretty=format:%ct) ))
METADATA="{\"azure_build_id\":\"$AZURE_BUILD_ID\",\"time_sec\":\"$TIME_SEC\"}"

case "$1" in
  success)
    try_really_hard aws stepfunctions send-task-success \
      --task-token "$TASK_TOKEN" \
      --task-output "$METADATA"
    ;;

  failure)
    try_really_hard aws stepfunctions send-task-failure \
      --task-token "$TASK_TOKEN" \
      --cause "$METADATA" \
      $FAIL_ARGS
    ;;

  *)
    echo "You must specify 'success' or 'failure' as an argument (got '$1')."
esac
