#!/bin/bash
set -ex

git pull --rebase
NIGHTLY=true ./build-release $(date +%Y.m.%d)
