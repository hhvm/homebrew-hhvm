#!/bin/bash
set -ex
DATE=$(date +%Y.%m.%d)
URL="https://dl.hhvm.com/source/nightlies/hhvm-nightly-${DATE}.tar.gz"

MYTEMP=$(mktemp -d)
pushd $MYTEMP
wget "$URL"
wget "$URL.sig"
gpg --verify *.sig
SHA="$(openssl sha -sha256 -r *.tar.gz | awk '{print $1}')"
popd
rm -rf "$MYTEMP"

git pull --rebase
# --dry-run: no git actions...
# --write: ... but write to the local repo anyway
brew bump-formula-pr \
	--dry-run \
	--write \
	--url="${URL}" \
	--sha256="${SHA}" \
	./hhvm-nightly.rb
gsed -i '/sha256.\+ => :/' hhvm-nightly.rb
git add hhvm-nightly.rb
git commit -m 'Update nightly version'
git push
