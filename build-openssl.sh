#!/bin/bash
#
# This script is based on a script by Claudiu-Vlad Ursache and thus licensed as below:
#
#  Copyright (c) 2013 Claudiu-Vlad Ursache <claudiu@cvursache.com>
#  MIT License (see LICENSE.md file)
#
#  Based on work by Felix Schulze:
#
#  Automatic build script for libssl and libcrypto 
#  for iPhoneOS and iPhoneSimulator
#
#  Created by Felix Schulze on 16.12.10.
#  Copyright 2010 Felix Schulze. All rights reserved.
#
#  Licensed under the Apache License, Version 2.0 (the "License");
#  you may not use this file except in compliance with the License.
#  You may obtain a copy of the License at
#
#  http://www.apache.org/licenses/LICENSE-2.0
#
#  Unless required by applicable law or agreed to in writing, software
#  distributed under the License is distributed on an "AS IS" BASIS,
#  WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
#  See the License for the specific language governing permissions and
#  limitations under the License.
set -e
cd "$(dirname "$0")"

if [ "$1" == "-h" ] || [ "$1" == "--help" ]; then
  echo "Usage: $0      -- Build openssl for all supported platforms and architectures."
  echo "       $0 fix  -- Only build what hasn't been built yet. Useful for resuming stopped builds."
  exit -1
fi

# Setup architectures, library name and other vars + cleanup from previous runs
ARCHS=("arm64"    "armv7s"   "armv7"    "i386"            "x86_64"             "x86_64")
SDKS=( "iphoneos" "iphoneos" "iphoneos" "iphonesimulator" "iphonesimulator8.0" "macosx")
#                                                                              macosx10.9
LIB_NAME="openssl-1.0.1h"
TEMP_DIR=$(pwd)/.build
TEMP_LIB_PATH="${TEMP_DIR}/${LIB_NAME}"
HEADER_DEST_DIR="include"

if ! [ -f "${LIB_NAME}.tar.gz" ]; then
  echo "Missing ${LIB_NAME}.tar.gz — Remedy:" >&2
  echo "  (cd '$(pwd)' && wget https://www.openssl.org/source/openssl-1.0.1h.tar.gz && $0)" >&2
  exit -1
fi

# -------------------------------------------------------------------------------------------------

if [ "$1" != "fix" ]; then
  echo "Have a cup of ☕️  or a 🍺  — this is going to take a while..."
  rm -rf "${TEMP_DIR}"
fi
mkdir -p "${TEMP_DIR}"

# Unarchive library, then configure and make for specified architectures
configure_make() {
  SDK=$1; ARCH=$2; GCC=$3; SDK_PATH=$4;
  DSTDIR=${TEMP_LIB_PATH}-${SDK}-${ARCH}

  if ! [ -d "${DSTDIR}" ]; then
    echo "Building ${SDK}-${ARCH}"
    
    rm -rf "${LIB_NAME}"
    tar xfz "${LIB_NAME}.tar.gz"
    pushd "${LIB_NAME}" >/dev/null
    OPENSSL_TARGET=iphoneos-cross
    EXTRA_CFLAGS=
    # OPENSSL_TARGET=BSD-generic32
    if [ "$ARCH" == "x86_64" ] && [ "$SDK" == "macosx" ]; then
      OPENSSL_TARGET=darwin64-x86_64-cc
      EXTRA_CFLAGS=-mmacosx-version-min=10.7
    elif [ "$SDK" == "iphonesimulator" ]; then
      if [ "$ARCH" == "i386" ]; then
        OPENSSL_TARGET=BSD-generic32
      elif [ "$ARCH" == "x86_64" ]; then
        OPENSSL_TARGET=BSD-generic64
      fi
    fi

    if [ "$SDK" == "iphoneos" ] || [ "$SDK" == "iphonesimulator" ]; then
      EXTRA_CFLAGS=-miphoneos-version-min=7.0
    fi

    export PATH="$(dirname "$(xcrun -sdk ${SDK} --find ld)"):$PATH"
    export CC="$GCC -arch ${ARCH}"
    export LD="$(xcrun -sdk ${SDK} --find ld)"
    set -x
    ./Configure $OPENSSL_TARGET --openssldir="${DSTDIR}"

    make \
      CC="${GCC} -arch ${ARCH}" \
      CFLAG="$EXTRA_CFLAGS -isysroot ${SDK_PATH}"

    make install -j2
    set +x
    popd >/dev/null
    rm -rf "${LIB_NAME}"
  fi
}

for ((i=0; i < ${#ARCHS[@]}; i++)); do
  if (xcrun -sdk ${SDKS[i]} --show-sdk-path >/dev/null 2>/dev/null); then
    SDK_PATH=$(xcrun -sdk ${SDKS[i]} --show-sdk-path)
    GCC=$(xcrun -sdk ${SDKS[i]} -find gcc)
    configure_make "${SDKS[i]}" "${ARCHS[i]}" "${GCC}" "${SDK_PATH}"
  fi
done


# -------------------------------------------------------------------------------------------------

libs_for_sdks() {
  local LIB_FILENAME=$1; shift
  local INCLUDE_SDKS=($@)
  local LIBS=()
  for ((i=0; i < ${#ARCHS[@]}; i++)); do
    SDK=${SDKS[i]}
    if (xcrun -sdk "$SDK" --show-sdk-path >/dev/null 2>/dev/null); then
      for ((x=0; x < ${#INCLUDE_SDKS[@]}; x++)); do
        if [ "$SDK" == "${INCLUDE_SDKS[x]}" ]; then
          LIBS+=( "${TEMP_LIB_PATH}-$SDK-${ARCHS[i]}/${LIB_FILENAME}" )
        fi
      done
    fi
  done
  declare -p LIBS
}

create_lib_for_sdks() {
  local DST_FILENAME=$1; shift
  local LIBS; eval $(libs_for_sdks $@)
  if [ ${#LIBS[@]} == 1 ]; then
    echo cp -fa "${LIBS[0]}" "${DST_FILENAME}"
         cp -fa "${LIBS[0]}" "${DST_FILENAME}"
  else
    echo rm -rf "${DST_FILENAME}"
         rm -rf "${DST_FILENAME}"
    echo lipo ${LIBS[@]} -create -output "${DST_FILENAME}"
         lipo ${LIBS[@]} -create -output "${DST_FILENAME}"
  fi
}

mkdir -p lib-ios lib-osx

create_lib_for_sdks  lib-ios/libcrypto.a  lib/libcrypto.a   iphoneos iphonesimulator iphonesimulator8.0
create_lib_for_sdks  lib-osx/libcrypto.a  lib/libcrypto.a   macosx
create_lib_for_sdks  lib-ios/libssl.a     lib/libssl.a      iphoneos iphonesimulator iphonesimulator8.0
create_lib_for_sdks  lib-osx/libssl.a     lib/libssl.a      macosx

# Copy header files + final cleanups
mkdir -p include-ios/openssl include-osx/openssl
cp -R "${TEMP_LIB_PATH}-${SDKS[0]}-${ARCHS[0]}"/include/openssl/* include-ios/openssl/
cp -R "${TEMP_LIB_PATH}-${SDKS[${#SDKS[@]}-1]}-${ARCHS[${#ARCHS[@]}-1]}"/include/openssl/* include-osx/openssl/

# rm -rf "$TEMP_DIR"
