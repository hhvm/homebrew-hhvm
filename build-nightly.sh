#!/bin/bash
set -ex

git pull --rebase
NIGHTLY=true ./build-release.sh $(date +%Y.%m.%d)
