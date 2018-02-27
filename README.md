# HHVM Homebrew Formula

## Warning

HHVM's OS X support is still fairly experimental. It should be fine for
development, but Linux is still the recommended OS for production usage.

## Installation

```
brew tap hhvm/hhvm
# install the latest version of HHVM:
brew install hhvm
# ... or install the latest 3.21.z release:
brew install hhvm@3.21-lts
```

If you need to install multiple versions, look at the documentation for
`brew switch`, `brew link`, and `brew unlink`.

We currently provide bottles (binary packages) for Sierra and High Sierra. Earlier
versions of MacOS are not supported as HHVM requires recent XCode.

If you build from source, this will take anywhere from twenty minutes on a
beefy Mac Pro to a couple of hours on a MacBook Air.

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
