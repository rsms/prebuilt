#!/bin/bash
set -u
set -e
cd "$(dirname "$0")"
 
# Setup architectures, library name and other vars + cleanup from previous runs
ARCHS=("arm64"    "armv7s"   "armv7"    "i386"            "x86_64"             "x86_64")
SDKS=( "iphoneos" "iphoneos" "iphoneos" "iphonesimulator" "iphonesimulator8.0" "macosx")
LIB_NAME="libevent-2.1.4-alpha"

TEMP_DIR=$(mktemp -d -t libevent-ios)
TEMP_LIB_PATH="$TEMP_DIR/${LIB_NAME}"
SELFDIR=$(pwd)

if ! [ -f "${LIB_NAME}.tar.gz" ]; then
  echo "Missing ${LIB_NAME}.tar.gz — Remedy:" >&2
  echo "  wget -O ${LIB_NAME}.tar.gz https://sourceforge.net/projects/levent/files/libevent/libevent-2.1/${LIB_NAME}.tar.gz/download" >&2
  exit -1
fi

rm -rf "${TEMP_LIB_PATH}*" "${LIB_NAME}"

# Unarchive, setup temp folder and run ./configure, 'make' and 'make install'
configure_make() {
  SDK=$1; ARCH=$2; GCC=$3; SDK_PATH=$4;
  tar xfz "${LIB_NAME}.tar.gz";
  echo "Building ${SDK}-${ARCH}"

  pushd "${LIB_NAME}" >/dev/null

  # Configure and make

  if [ "${ARCH}" == "x86_64" ]; then
    HOST_FLAG="--host=x86_64-apple-darwin11"
  elif [ "${ARCH}" == "i386" ]; then
    HOST_FLAG="--host=i386-apple-darwin11"
  else
    HOST_FLAG="--host=arm-apple-darwin11"
  fi

  EXTRA_CFLAGS=
  if [ "$SDK" == "iphoneos" ] || [ "$SDK" == "iphonesimulator" ]; then
    EXTRA_CFLAGS=-miphoneos-version-min=7.0
  elif [ "$SDK" == "iphonesimulator8.0" ]; then
    EXTRA_CFLAGS=-miphoneos-version-min=8.0
  else
    EXTRA_CFLAGS=-mmacosx-version-min=10.7
  fi

  if [ "$SDK" == "iphoneos" ] || [ "$SDK" == "iphonesimulator" ] || [ "$SDK" == "iphonesimulator8.0" ]; then
    LIBDIR="${SELFDIR}/lib-ios"
    INCDIR="${SELFDIR}/include-ios"
  else
    LIBDIR="${SELFDIR}/lib-osx"
    INCDIR="${SELFDIR}/include-osx"
  fi

  DSTDIR=${TEMP_LIB_PATH}-${SDK}-${ARCH}
  mkdir -p "${DSTDIR}"

  ./configure \
    --disable-shared \
    --enable-static \
    --disable-debug-mode \
    --disable-dependency-tracking \
    --disable-thread-support \
    ${HOST_FLAG} \
    --prefix="${DSTDIR}" \
    CC="${GCC} " \
    LDFLAGS="-L${LIBDIR}" \
    CFLAGS=" -DNDEBUG=1 -g -arch ${ARCH} -isysroot ${SDK_PATH} -I${INCDIR} ${EXTRA_CFLAGS}" \
    CPPLAGS=" -DNDEBUG=1 -g -arch ${ARCH} -isysroot ${SDK_PATH} -I${INCDIR} ${EXTRA_CFLAGS} "

  make -j2
  make -j32 install

  popd >/dev/null
  rm -rf "${LIB_NAME}"
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

LIBS=("event" "event_core" "event_extra" "event_openssl") # event_pthreads if building w/ threads
for ((i=0; i < ${#LIBS[@]}; i++)); do
  LIB=${LIBS[i]}
  create_lib_for_sdks  lib-ios/lib${LIB}.a  lib/lib${LIB}.a  iphoneos iphonesimulator iphonesimulator8.0
  create_lib_for_sdks  lib-osx/lib${LIB}.a  lib/lib${LIB}.a  macosx
done
 
# Copy header files + final cleanups
mkdir -p include-ios/event2 include-osx/event2
cp -Rf "${TEMP_LIB_PATH}-${SDKS[0]}-${ARCHS[0]}"/include/event2/* include-ios/event2/
cp -Rf "${TEMP_LIB_PATH}-${SDKS[${#SDKS[@]}-1]}-${ARCHS[${#ARCHS[@]}-1]}"/include/event2/* include-osx/event2/
rm -rf "${TEMP_DIR}"

