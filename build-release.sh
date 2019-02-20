#!/bin/bash
set -e

VERSION="$1"
RECIPE="$2"
if [ -z "$VERSION" -o -z "$RECIPE" ]; then
	echo "Usage: $0 VERSION RECIPE"
	echo "Example: $0 3.27.2 hhvm.rb"
	exit 1
fi
if [ ! -f "$RECIPE" ]; then
	echo "Usage: $0 VERSION RECIPE"
	echo "Provided recipe is not a .rb file."
	exit 1
fi
RECIPE="$(realpath "$RECIPE")"

# Make sure people don't fire-and-forget this
echo "This script create and uploads the binaries, but you will need to create a commit "
echo "updating the metadata. A diff will be output at the end."
echo
echo "Press enter to continue."
read

set -x

DLDIR=$(mktemp -d)

aws s3 cp "s3://hhvm-scratch/hhvm-${VERSION}.tar.gz" "$DLDIR/"
aws s3 cp "s3://hhvm-scratch/hhvm-${VERSION}.tar.gz.sig" "$DLDIR/"
gpg --verify "$DLDIR"/*.sig
SHA="$(openssl sha256 "$DLDIR"/*.tar.gz | awk '{print $NF}')"

gsed -i "s,^  url .\+\$,  url \"file://${DLDIR}/hhvm-${VERSION}.tar.gz\"," "$RECIPE"
gsed -i "s,^  sha256 .\+\$,  sha256 \"${SHA}\"," "$RECIPE"
gsed -i "s,^  revision [0-9]\+,  revision 0," "$RECIPE"
# delete existing bottle references
gsed -i '/sha256.\+ => :/d' "${RECIPE}"

# clean up
brew list | grep hhvm | xargs brew uninstall --force || true
rm -f *.bottle *.json

# build
brew upgrade
brew install --bottle-arch=nehalem --build-bottle "$RECIPE"
brew bottle --force-core-tap --root-url=https://dl.hhvm.com/homebrew-bottles --json "$RECIPE"
# local naming != download naming
for file in *--*.bottle.tar.gz; do
  mv "$file" "$(echo "$file" | sed s/--/-/)"
done
aws s3 sync ./ s3://hhvm-downloads/homebrew-bottles/ --exclude '*' --include '*.bottle.tar.gz'
brew bottle --merge --keep-old --write --no-commit *.json
rm -rf $DLDIR
gsed -E -i 's,"file://.+/(hhvm-.+\.tar\.gz)"$,"https://dl.hhvm.com/source/\1",' "$RECIPE"
echo "Merge this change:"
git diff "$RECIPE"
