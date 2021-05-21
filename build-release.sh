#!/bin/bash
#
# Copyright (c) Facebook, Inc. and its affiliates. All Rights Reserved
#
# This source code is licensed under the MIT license found in the
# LICENSE file in the root directory of this source tree.
#
if [ ! -e Aliases/hhvm ]; then
  echo "Run from root of homebrew-hhvm checkout."
  exit 1
fi

VERSION="$1"
REBUILD_NUM="$2"

if [ -z "$VERSION" ]; then
  echo "Usage: $0 VERSION [REBUILD_NUM]"
  echo "Example: $0 3.27.2"
  echo "Example: $0 3.27.2 1"
  exit 1
fi

if [[ "$VERSION" =~ ^20[0-9]{2}(\.[0-9]{2}){2}$ ]]; then
  NIGHTLY=true
else
  NIGHTLY=false
fi

BOTTLE_FLAGS=""

set -ex

DLDIR=$(mktemp -d)

if [ -n "$SKIP_PUBLISH" ]; then
  ALLOW_MISSING_SIG=true
else
  ALLOW_MISSING_SIG=false
fi

if $NIGHTLY; then
  REAL_URL="https://dl.hhvm.com/source/nightlies/hhvm-nightly-${VERSION}.tar.gz"
  (
    cd $DLDIR
    wget "$REAL_URL"
    wget "$REAL_URL.sig"
  )
  URL="file://${DLDIR}/hhvm-nightly-${VERSION}.tar.gz"
else
  aws s3 cp "s3://hhvm-scratch/hhvm-${VERSION}.tar.gz" "$DLDIR/" || \
    aws s3 cp "s3://hhvm-downloads/source/hhvm-${VERSION}.tar.gz" "$DLDIR/"
  aws s3 cp "s3://hhvm-scratch/hhvm-${VERSION}.tar.gz.sig" "$DLDIR/" || \
    aws s3 cp "s3://hhvm-downloads/source/hhvm-${VERSION}.tar.gz.sig" "$DLDIR/" || \
    $ALLOW_MISSING_SIG
  REAL_URL="https://dl.hhvm.com/source/hhvm-${VERSION}.tar.gz"
  URL="file://${DLDIR}/hhvm-${VERSION}.tar.gz"
fi
gpg --verify "$DLDIR"/*.sig || $ALLOW_MISSING_SIG
SHA="$(openssl sha256 "$DLDIR"/*.tar.gz | awk '{print $NF}')"

# realpath is not available on MacOS
abspath() {
  if [[ "$1" = /* ]]; then
    echo "$1"
  else
    echo "$(pwd)/$1"
  fi
}

if $NIGHTLY; then
  RECIPE=$(abspath "Formula/hhvm-nightly.rb")
else
  MAJ_MIN=$(echo "${VERSION}" | cut -f1,2 -d.)
  if [ "${MAJ_MIN}" = "3.30" ]; then
    # Obsolete format not used for new releases
    RECIPE="$(abspath "Formula/hhvm@3.30-lts.rb")"
  elif [ "${MAJ_MIN}" = "3.27" ]; then
    # Obsolete format not used for new releases
    RECIPE="$(abspath "Formula/hhvm@3.27-lts.rb")"
  else
    RECIPE="$(abspath "Formula/hhvm-${MAJ_MIN}.rb")"
  fi
fi

# delete any existing bottle references for the current OS version (from any
# potential previous bad/outdated builds)
source os-metadata.inc.sh
function delete_existing_bottles_and_rebuild_num() {
  gsed -i "/sha256.* :$OS_CODENAME/d" "${RECIPE}"
  gsed -i "/sha256.* $OS_CODENAME:/d" "${RECIPE}"
  # Remove old rebuild number if present
  gsed -i '/^ *rebuild/d' "${RECIPE}"
  # || true in case there were no bottles (the common case)
  git commit -m "Deleting stale bottles for ${VERSION}" "$RECIPE" || true
  git show
}

if [ ! -e "$RECIPE" ]; then
  if [ "${VERSION}" != "${MAJ_MIN}.0" ]; then
    echo "${RECIPE} does not exist, and ${VERSION} is not a .0 release"
    exit 1
  fi
  if [ -n "$REBUILD_NUM" ]; then
    echo "$VERSION is a new release, rebuild number ($REBUILD_NUM) must be empty"
    exit 1
  fi
  URL_LINE="  url \"${URL}\""
  SHA_LINE="  sha256 \"${SHA}\""
  sed "s/class HhvmNightly /class Hhvm${MAJ_MIN//.} /" \
    "$(dirname "$RECIPE")/hhvm-nightly.rb" \
    | gsed '/sha256 .*:/d' \
    | gsed "s#^\s*url \".\+\"\$#${URL_LINE}#" \
    | gsed "s#^\s*sha256 \".\+\"\$#${SHA_LINE}#" \
    | gsed '/^ *rebuild/d' \
    > "$RECIPE"
  # sanity check that the gsed replacements above were correctly applied
  if [ "$(grep -c "^${URL_LINE}\$" "$RECIPE")" != 1 -o \
       "$(grep -c "^${SHA_LINE}\$" "$RECIPE")" != 1 ]; then
    echo "Failed to create new recipe for ${VERSION}"
    exit 1
  fi
  ln -sf "../Formula/hhvm-${MAJ_MIN}.rb" Aliases/hhvm
  git add "$RECIPE"
  git add Aliases/hhvm
  git commit -m "Added recipe for ${VERSION}"
  git show | head -n 50
else
  PREV_VERSION=$(awk -F / '/^  url/{print $NF}' "$RECIPE" | gsed 's/^.\+-\([0-9].\+\)\.tar.\+/\1/')
  if [ "$PREV_VERSION" = "$VERSION" ]; then
    # recipe already exists and has the correct HHVM version (presumably because
    # a package for at least one other OS version was already built); no need to
    # bump-formula, but we still need to delete any existing bottle references
    # for the current OS version (from any potential previous bad/outdated
    # builds)
    delete_existing_bottles_and_rebuild_num
  else
    # version number changed!
    if [ -n "$REBUILD_NUM" ]; then
      echo "$VERSION is a new version, rebuild number ($REBUILD_NUM) must be empty"
      exit 1
    fi
    # FIXME: This brew command is currently broken, but if it gets fixed we
    # should use it again instead of the gsed commands below.
    # --write: Make the expected file modifications without taking any Git actions.
    # brew bump-formula-pr \
    #  --write \
    #  --no-audit \
    #  --url="${URL}" \
    #  --sha256="${SHA}" \
    #  "$RECIPE"
    NEW_LINE="  url \"$URL\""
    gsed -i 's,^  url "[^"]*"$,'"$NEW_LINE", "$RECIPE"
    # fail if gsed above didn't replace anything
    grep -q "$NEW_LINE" "$RECIPE"
    NEW_LINE="  sha256 \"$SHA\""
    gsed -i 's,^  sha256 "[0-9a-f]*"$,'"$NEW_LINE", "$RECIPE"
    grep -q "$NEW_LINE" "$RECIPE"
    # Delete existing bottle references
    gsed -i '/sha256 .*:/d' "${RECIPE}"
    # Remove rebuild number if present
    gsed -i '/^ *rebuild/d' "${RECIPE}"
    git commit -m "Updated $(basename "$RECIPE") recipe to ${VERSION}" "$RECIPE"
    git show
  fi
fi

set -x

# clean up
brew list | grep hhvm | xargs brew uninstall --force || true
rm -f *.bottle *.json

# build
brew upgrade
cd Formula
brew install --bottle-arch=sandybridge --build-bottle "$(basename "$RECIPE" .rb)"
# Update the source-bump commit to reference dl.hhvm.com instead
gsed -E -i 's,"file://.+/(hhvm-.+\.tar\.gz)"$,"'"${REAL_URL}"'",' "$RECIPE"
git commit --amend "$RECIPE" --reuse-message HEAD
git show | head -n 50

brew bottle \
  $BOTTLE_FLAGS \
  --root-url=https://dl.hhvm.com/homebrew-bottles \
  --json \
  "$(basename "$RECIPE" .rb)"
# local naming != download naming
for file in *--*.bottle*.tar.gz; do
  mv "$file" "$(echo "$file" | sed s/--/-/)"
done

if [ -z "$SKIP_PUBLISH" ]; then
  aws s3 sync ./ s3://hhvm-downloads/homebrew-bottles/ --exclude '*' --include '*.bottle*.tar.gz'
fi

PRE_BOTTLE_REV="$(git rev-parse HEAD)"

function commit_and_push_bottle() {
  set -e
  git reset --hard "${PRE_BOTTLE_REV}"
  git pull origin master --rebase || (git rebase --abort; git reset --hard origin/master)

  # we've done this above, but that commit may get lost during the rebase if
  # there are merge conflicts
  delete_existing_bottles_and_rebuild_num

  brew bottle --keep-old --merge --write --no-commit *.json

  # Manually update the rebuild number because brew cannot handle rebuild
  # numbers in formulas without taps.
  # https://github.com/Homebrew/brew/blob/3.0.0/Library/Homebrew/dev-cmd/bottle.rb#L273
  if [ -n "$REBUILD_NUM" ]; then
    gsed -i '/^ *bottle do$/a \    rebuild '"$REBUILD_NUM" "$RECIPE"
  fi

  git add "$RECIPE"
  git commit -m "Added bottle for ${VERSION} on $(sw_vers -productVersion)"
  git show
  if [ -z "$SKIP_PUBLISH" ]; then
    git push origin HEAD:master
  fi
}

PUSHED=false
for i in $(seq 1 5); do
  if commit_and_push_bottle; then
    PUSHED=true
    break
  fi
  sleep $(($RANDOM % 10))
done

if ! $PUSHED; then
  sleep  $(($RANDOM % 60))
  commit_and_push_bottle
fi
rm -rf $DLDIR
git clean -ffdx
