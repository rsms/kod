#!/bin/bash
cd "$(dirname "$0")/gazelle"

# synthesize Xcode env vars when running on our own
if [ "$CONFIGURATION_BUILD_DIR" = "" ]; then
  # TODO: query xcodebuild for the active build style
  BUILD_STYLE=$1
  if [ "$BUILD_STYLE" != "Debug" ] && [ "$BUILD_STYLE" != "Release" ]; then
    BUILD_STYLE=Debug
  fi
  PRODUCT_NAME=gazelle
  CONFIGURATION_BUILD_DIR=../../build/$BUILD_STYLE
  ARCHS="$2"
  if [ "$ARCHS" == "" ]; then ARCHS=x86_64; fi
fi

# Build dir. e.g. "/Users/rasmus/src/kod/build/Debug"
GZ_BUILD_DIR="${CONFIGURATION_BUILD_DIR}/${PRODUCT_NAME}"
LIBGZ_PRODUCT="${GZ_BUILD_DIR}/libgazelle.a"
GZLC_PRODUCT="${GZ_BUILD_DIR}/gzlc"
IS_DIRTY=0

# clean if requested
if [ "$ACTION" = "clean" ]; then
  make clean
  rm -rfv "$GZ_BUILD_DIR"
  exit $?
fi

# check if a build product exists and is up-to-date
# TODO: check each product based on ARCHS
if [ .git/HEAD -nt "${LIBGZ_PRODUCT}" ]; then
  IS_DIRTY=1
fi

# Exit cleanly if everything is up-to-date
if [ $IS_DIRTY -eq 0 ]; then
  exit 0
fi

echo "info: Building $BUILD_STYLE for architectures $ARCHS"
BUILT_ARCHS_COUNT=0
LIBGZ_PRODUCTS=
GZLC_PRODUCTS=

for arch in $ARCHS; do
  make clean

  # important: the gazelle makefile is messed up so -j to make will break the
  # build, thus we do not paralellize make.
  CFLAGS="-arch $arch -g -I../lua/src" \
  CPPFLAGS="-arch $arch -g -I../lua/src" \
  LDFLAGS="-arch $arch -L../../build/$BUILD_STYLE/lua" \
    make
  
  mv -vf gzlc gzlc-$arch
  mv -vf runtime/libgazelle.a runtime/libgazelle-$arch.a

  if [ "${GZLC_PRODUCTS}" == "" ]; then GZLC_PRODUCTS="gzlc-$arch"
  else GZLC_PRODUCTS="${GZLC_PRODUCTS} gzlc-$arch"; fi
  
  if [ "${LIBGZ_PRODUCTS}" == "" ]; then LIBGZ_PRODUCTS="runtime/libgazelle-$arch.a"
  else LIBGZ_PRODUCTS="${LIBGZ_PRODUCTS} runtime/libgazelle-$arch.a"; fi

  BUILT_ARCHS_COUNT=$(expr $BUILT_ARCHS_COUNT + 1)
done

mkdir -p "$GZ_BUILD_DIR"
if [ $BUILT_ARCHS_COUNT -gt 1 ]; then
  # create universal binaries
  lipo -create ${LIBGZ_PRODUCTS} -output "${LIBGZ_PRODUCT}"
  lipo -create ${GZLC_PRODUCTS} -output "${GZLC_PRODUCT}"
  echo "created universal library: ${LIBGZ_PRODUCT}"
  echo "created universal binary: ${GZLC_PRODUCT}"
elif [ $BUILT_ARCHS_COUNT -eq 1 ]; then
  mv -vf "${LIBGZ_PRODUCTS}" "${LIBGZ_PRODUCT}"
  mv -vf "${GZLC_PRODUCTS}" "${GZLC_PRODUCT}"
else
  echo "warning: Nothing could be built (no supported architectures)" >&2
fi
  
