#!/bin/bash
cd "$(dirname "$0")/lua"
#ARCHS "x86_64 i386 ppc"

# synthesize Xcode env vars when running on our own
if [ "$CONFIGURATION_BUILD_DIR" = "" ]; then
  # TODO: query xcodebuild for the active build style
  BUILD_STYLE=$1
  if [ "$BUILD_STYLE" != "Debug" ] && [ "$BUILD_STYLE" != "Release" ]; then
    BUILD_STYLE=Debug
  fi
  PRODUCT_NAME=lua
  CONFIGURATION_BUILD_DIR=../../build/$BUILD_STYLE
  ARCHS="$2"
  if [ "$ARCHS" == "" ]; then ARCHS=x86_64; fi
fi

# Build dir. e.g. "/Users/rasmus/src/kod/build/Debug"
LUA_BUILD_DIR="${CONFIGURATION_BUILD_DIR}/${PRODUCT_NAME}"
LUA_LIBLUA_PRODUCT="${LUA_BUILD_DIR}/liblua.a"
IS_DIRTY=0

# clean if requested
if [ "$ACTION" = "clean" ]; then
  make clean
  rm -rfv "$LUA_BUILD_DIR"
  exit $?
fi

# check if a build product exists and is up-to-date
# TODO: check each product based on ARCHS
if [ ! -f "${LUA_LIBLUA_PRODUCT}" ] || \
   [ "$(find src \! -name '*.o' -newer "${LUA_LIBLUA_PRODUCT}")" != "" ]
then
  IS_DIRTY=1
fi

# Exit cleanly if everything is up-to-date
if [ $IS_DIRTY -eq 0 ]; then
  exit 0
fi

LUA_CFLAGS='-Wall'
if [ "$BUILD_STYLE" = "Debug" ]; then
  LUA_CFLAGS="${LUA_CFLAGS} -g -O0"
else
  LUA_CFLAGS="${LUA_CFLAGS} -O2"
fi

echo "info: Building $BUILD_STYLE for architectures $ARCHS"
BUILT_ARCHS_COUNT=0
LUA_LIBLUA_PRODUCTS=

for arch in $ARCHS; do
  make clean
  CFLAGS="$LUA_CFLAGS -arch $arch" MYLDFLAGS="-arch $arch" CC=clang \
    make -e -j macosx
  mv -vf src/liblua.a src/liblua-$arch.a
  if [ "${LUA_LIBLUA_PRODUCTS}" == "" ]; then
    LUA_LIBLUA_PRODUCTS="src/liblua-$arch.a"
  else
    LUA_LIBLUA_PRODUCTS="${LUA_LIBLUA_PRODUCTS} src/liblua-$arch.a"
  fi
  BUILT_ARCHS_COUNT=$(expr $BUILT_ARCHS_COUNT + 1)
done

mkdir -p "$LUA_BUILD_DIR"
if [ $BUILT_ARCHS_COUNT -gt 1 ]; then
  # create universal binaries
  lipo -create ${LUA_LIBLUA_PRODUCTS} -output "${LUA_LIBLUA_PRODUCT}"
  echo "created universal library: ${LUA_LIBLUA_PRODUCT}"
elif [ $BUILT_ARCHS_COUNT -eq 1 ]; then
  mv -vf "${LUA_LIBLUA_PRODUCTS}" "${LUA_LIBLUA_PRODUCT}"
else
  echo "warning: Nothing was built (no supported architectures)" >&2
fi
  
