#!/bin/bash
set -ex

git pull --rebase
brew list | grep hhvm | xargs brew uninstall --force || true
brew upgrade
cd Formula
brew install --bottle-arch=nehalem --build-bottle ./hhvm-nightly.rb
rm *.json || true
brew bottle --force-core-tap --root-url=https://dl.hhvm.com/homebrew-bottles --json ./hhvm-nightly.rb
# FIXME: Unsure what's intended here for now
# See https://discourse.brew.sh/t/double-dash-bottle-naming-details/2712
for file in *--*.bottle.tar.gz; do
  mv "$file" "$(echo "$file" | sed s/--/-/)"
done
aws s3 sync ./ s3://hhvm-downloads/homebrew-bottles/ --exclude '*' --include '*.bottle.tar.gz'
git pull --rebase
brew bottle --merge --keep-old --write --no-commit *.json
git add hhvm-nightly.rb
git commit -m "update bottle for nightly on $(sw_vers -productVersion)"
git push
rm *.bottle.{tar.gz,json}
