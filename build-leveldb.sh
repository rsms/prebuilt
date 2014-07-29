#!/bin/bash
set -e
cd "$(dirname "$0")"
set -x

mkdir -p .build

if ! [ -d .build/leveldb ]; then
  echo git clone https://code.google.com/p/leveldb/ .build/leveldb
       git clone https://code.google.com/p/leveldb/ .build/leveldb
  pushd .build/leveldb >/dev/null

  # Checkout release 1.17
  git checkout --quiet e353fbc7ea81f12a5694991b708f8f45343594b1

  # Make sure we don't attempt to compile w/ snappy. If you for instance installed something via
  # Homebrew that depended on snappy, snappy would exist but only being built for x86, so ARM/iOS
  # build would fail.
  cp -a build_detect_platform build_detect_platform.orig
  sed 's/#include <snappy\.h>/#include <snappy-does-not-exist.h>/' \
    build_detect_platform.orig > build_detect_platform

  rm -rf .git
  popd >/dev/null
fi

pushd .build/leveldb >/dev/null

make clean
make -j4 TARGET_OS=IOS PLATFORM=IOS
mkdir -p ../../lib-ios ../../include-ios/leveldb
cp -af libleveldb.a      ../../lib-ios/libleveldb.a
cp -af include/leveldb/* ../../include-ios/leveldb/

make clean
make -j4
mkdir -p ../../lib-osx ../../include-osx/leveldb
cp -af libleveldb.a      ../../lib-osx/libleveldb.a
cp -af include/leveldb/* ../../include-osx/leveldb/

popd >/dev/null
