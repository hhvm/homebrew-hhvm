#!/bin/bash
set -ex

git pull --rebase
brew list | grep hhvm | xargs brew uninstall --force || true
brew upgrade
brew install --build-bottle ./hhvm-nightly.rb
rm *.json || true
brew bottle --force-core-tap --root-url=https://dl.hhvm.com/homebrew-bottles --json ./hhvm-nightly.rb
aws s3 sync ./ s3://hhvm-downloads/homebrew-bottles/ --exclude '*' --include '*.bottle.tar.gz'
git pull --rebase
brew bottle --merge --keep-old --write --no-commit *.json
git add hhvm-nightly.rb
git commit -m "update bottle for nightly on $(sw_vers -productVersion)"
git push
rm *.bottle.{tar.gz,json}
