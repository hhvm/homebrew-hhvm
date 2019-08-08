#!/bin/bash
set -e

if [ ! -e Aliases/hhvm ]; then
  echo "Run from root of homebrew-hhvm checkout."
  exit 1
fi

VERSION="$1"
MAJ_MIN=$(echo "${VERSION}" | cut -f1,2 -d.)
if [ -z "$VERSION" ]; then
	echo "Usage: $0 VERSION"
	echo "Example: $0 3.27.2"
	exit 1
fi
RECIPE="$(realpath "Formula/hhvm-${MAJ_MIN}.rb")"
if [ ! -e "$RECIPE" ]; then
  if [ "${VERSION}" != "${MAJ_MIN}.0" ]; then
    echo "${RECIPE} does not exist, and ${VERSION} is not a .0 release"
    exit 1
  fi
  sed "s/class HhvmNightly /class Hhvm${MAJ_MIN//.} /" \
    "$(dirname "$RECIPE")/hhvm-nightly.rb" \
    > "$RECIPE" 
  ln -sf "../Formula/hhvm-${MAJ_MIN}.rb" Aliases/hhvm
  git add "$RECIPE"
  git add Aliases/hhvm
  RECIPE_COMMIT_MESSAGE="Added recipe for ${VERSION}"
else
  RECIPE_COMMIT_MESSAGE="Updated hhvm-${MAJ_MIN} recipe to ${VERSION}"
fi
set -x

DLDIR=$(mktemp -d)

PREV_VERSION=$(awk -F / '/^  url/{print $NF}' "$RECIPE" | gsed 's/^.\+-\([0-9].\+\)\.tar.\+/\1/')

aws s3 cp "s3://hhvm-scratch/hhvm-${VERSION}.tar.gz" "$DLDIR/"
aws s3 cp "s3://hhvm-scratch/hhvm-${VERSION}.tar.gz.sig" "$DLDIR/"
gpg --verify "$DLDIR"/*.sig
SHA="$(openssl sha256 "$DLDIR"/*.tar.gz | awk '{print $NF}')"

# Delete existing bottle references
gsed -i '/sha256.\+ => :/d' "${RECIPE}"
if [ "$PREV_VERSION" = "$VERSION" ]; then
  # no changes, this is a rebuild, or recipe-only changes
  PREVIOUS_REVISION=$(awk '/^  revision /{print $2}' "$RECIPE")
  REVISION=$(($PREVIOUS_REVISION + 1))
  gsed -i "s,^  revision [0-9]\+,  revision $REVISION," "$RECIPE"
  git commit -m "Update build revision for ${VERSION}" "$RECIPE"
else
  # version number changed!
  # --dry-run: no git actions...
  # --write: ... but write to the local repo anyway
  brew bump-formula-pr \
    --dry-run \
    --write \
    --sha256="${SHA}" \
    --url="file://${DLDIR}/hhvm-${VERSION}.tar.gz" \
    "$RECIPE"
  git commit -m "${RECIPE_COMMIT_MESSAGE}" "$RECIPE"
fi

# clean up
brew list | grep hhvm | xargs brew uninstall --force || true
rm -f *.bottle *.json

# build
brew upgrade
cd Formula
brew install --bottle-arch=nehalem --build-bottle "$(basename "$RECIPE")"
# Update the source-bump commit to reference dl.hhvm.com instead
gsed -E -i 's,"file://.+/(hhvm-.+\.tar\.gz)"$,"https://dl.hhvm.com/source/\1",' "$RECIPE"
git commit --amend "$RECIPE" --reuse-message HEAD

brew bottle --force-core-tap --root-url=https://dl.hhvm.com/homebrew-bottles --json "$RECIPE"
# local naming != download naming
for file in *--*.bottle.tar.gz; do
  mv "$file" "$(echo "$file" | sed s/--/-/)"
done
aws s3 sync ./ s3://hhvm-downloads/homebrew-bottles/ --exclude '*' --include '*.bottle.tar.gz'

function commit_and_push_bottle() {
  brew bottle --merge --keep-old --write --no-commit *.json
  git add "$RECIPE"
  git commit -m "Added bottle for ${VERSION} on $(sw_vers -productVersion)"
  git push
}

if !(git pull --rebase && commit_and_push_bottle); then
  git rebase --abort || true
  git reset --hard origin/master
  commit_and_push_bottle
fi
rm -rf $DLDIR *.bottle.{tar.gz,json}
