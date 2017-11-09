# HHVM Homebrew Formula

## Warning

HHVM's OS X support is still fairly experimental. It should be fine for
development, but Linux is still the recommended OS for production usage.

## Installation

To install the latest version:

```
brew tap hhvm/hhvm
brew install hhvm
```

We currently provide bottles (binary packages) for Sierra and High Sierra. Earlier
versions of MacOS are not supported as HHVM requires recent XCode.

If you build from source, this will take anywhere from twenty minutes on a
beefy Mac Pro to a couple of hours on a MacBook Air.

## Other versions

A 'preview' release is also available (with bottles), and sporadically updated; we hope to replace this with nightlies in the future.

```
brew tap hhvm/hhvm
brew install hhvm-preview
```

You can also install older versions by checking out the repository at a revision other than master, for example:

```
$ git clone https://github.com/hhvm/homebrew-hhvm.git
$ cd homebrew-hhvm
$ git checkout hhvm-3.21
$ brew install ./hhvm.rb
Warning: hhvm 3.22.0_1 is available and more recent than version 3.21.3_1.
==> Downloading https://dl2.hhvm.com/homebrew-bottles/hhvm-3.21.3_1.high_sierra.bottle.tar.gz
######################################################################## 100.0%
==> Pouring hhvm-3.21.3_1.high_sierra.bottle.tar.gz
==> Caveats
To have launchd start hhvm now and restart at login:
  brew services start hhvm
Or, if you don't want/need a background service you can just run:
  hhvm -m daemon -c /usr/local/etc/hhvm/php.ini -c /usr/local/etc/hhvm/server.ini
==> Summary
🍺  /usr/local/Cellar/hhvm/3.21.3_1: 4,098 files, 107MB
```

## Reporting Issues

- Only issues with the packaging itself which don't require a change to HHVM
should be reported here. This includes things like missing dependencies or an
out-of-date formula.
- Most issues should be reported
[directly to the HHVM project](https://github.com/facebook/hhvm/issues) since
they will need to be fixed there. This includes everything from "this code
doesn't work on OS X" to "`--HEAD` doesn't build".

## More Information

- [HHVM homepage](http://hhvm.com)
- [HHVM github project](https://github.com/facebook/hhvm)
- [Homebrew homepage](http://brew.sh/)
