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

if [ -z "$VERSION" ]; then
	echo "Usage: $0 VERSION"
	echo "Example: $0 3.27.2"
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
    aws s3 cp "s3://hhvm-downloads/source/hhvm-${VERSION}.tar.gz.sig" "$DLDIR/"
  REAL_URL="https://dl.hhvm.com/source/hhvm-${VERSION}.tar.gz"
  URL="file://${DLDIR}/hhvm-${VERSION}.tar.gz"
fi
gpg --verify "$DLDIR"/*.sig
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

if [ ! -e "$RECIPE" ]; then
  if [ "${VERSION}" != "${MAJ_MIN}.0" ]; then
    echo "${RECIPE} does not exist, and ${VERSION} is not a .0 release"
    exit 1
  fi
  URL_LINE="  url \"${URL}\""
  SHA_LINE="  sha256 \"${SHA}\""
  sed "s/class HhvmNightly /class Hhvm${MAJ_MIN//.} /" \
    "$(dirname "$RECIPE")/hhvm-nightly.rb" \
    | gsed '/sha256.\+ => :/d' \
    | gsed "s#^\s*url \".\+\"\$#${URL_LINE}#" \
    | gsed "s#^\s*sha256 \".\+\"\$#${SHA_LINE}#" \
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
else
  PREV_VERSION=$(awk -F / '/^  url/{print $NF}' "$RECIPE" | gsed 's/^.\+-\([0-9].\+\)\.tar.\+/\1/')
  if [ "$PREV_VERSION" = "$VERSION" ]; then
    # if 1, other version was built; no recipe changes needed.
    if [ "$(grep -c 'sha256.\+ => :' "$RECIPE")" != 1 ]; then
      # TODO: fix this and uncomment
      # Delete existing bottle references
      #gsed -i '/sha256.\+ => :/d' "${RECIPE}"
      # ...  in case there were no bottles
      #git commit -m "Deleting stale bottles for ${VERSION}" "$RECIPE" || true
      echo "Would have deleted stale bottles but this is temporarily disabled."
    fi
  else
    # version number changed!
    # --dry-run: no git actions...
    # --write: ... but write to the local repo anyway
    brew bump-formula-pr \
      --dry-run \
      --write \
      --url="${URL}" \
      --sha256="${SHA}" \
      "$RECIPE"
    # Delete existing bottle references
    gsed -i '/sha256.\+ => :/d' "${RECIPE}"
    git commit -m "Updated $(basename "$RECIPE") recipe to ${VERSION}" "$RECIPE"
  fi
fi

set -x

# clean up
brew list | grep hhvm | xargs brew uninstall --force || true
rm -f *.bottle *.json

# build
brew upgrade
cd Formula
brew install --bottle-arch=nehalem --build-bottle "$(basename "$RECIPE")"
# Update the source-bump commit to reference dl.hhvm.com instead
gsed -E -i 's,"file://.+/(hhvm-.+\.tar\.gz)"$,"'"${REAL_URL}"'",' "$RECIPE"
git commit --amend "$RECIPE" --reuse-message HEAD

brew bottle \
  $BOTTLE_FLAGS \
  --force-core-tap \
  --root-url=https://dl.hhvm.com/homebrew-bottles \
  --json \
  "$RECIPE"
# local naming != download naming
for file in *--*.bottle.tar.gz; do
  mv "$file" "$(echo "$file" | sed s/--/-/)"
done
aws s3 sync ./ s3://hhvm-downloads/homebrew-bottles/ --exclude '*' --include '*.bottle.tar.gz'

PRE_BOTTLE_REV="$(git rev-parse HEAD)"

function commit_and_push_bottle() {
  set -e
  git reset --hard "${PRE_BOTTLE_REV}"
  git pull origin master --rebase || (git rebase --abort; git reset --hard origin/master)
  brew bottle --keep-old --merge --write --no-commit *.json
  git add "$RECIPE"
  git commit -m "Added bottle for ${VERSION} on $(sw_vers -productVersion)"
  git push origin HEAD:master
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
