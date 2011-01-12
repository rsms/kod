#!/bin/bash
cd "$(dirname $0)/node"

# synthesize Xcode env vars when running on our own
if [ "$CONFIGURATION_BUILD_DIR" = "" ]; then
  # TODO: query xcodebuild for the active build style
  BUILD_STYLE=$1
  if [ "$BUILD_STYLE" != "Debug" ] && [ "$BUILD_STYLE" != "Release" ]; then
    BUILD_STYLE=Debug
  fi
  PRODUCT_NAME=nodejs
  CONFIGURATION_BUILD_DIR=../../build/$BUILD_STYLE
  ARCHS=x64
fi

# Build dir. e.g. "/Users/rasmus/src/kod/build/Debug"
NODE_BUILD_DIR="${CONFIGURATION_BUILD_DIR}/${PRODUCT_NAME}"
NODE_LIBNODE_PRODUCT="${NODE_BUILD_DIR}/libnode.a"
NODE_LIBV8_PRODUCT="${NODE_BUILD_DIR}/libv8.a"
IS_DIRTY=0

# clean if requested
if [ "$ACTION" = "clean" ]; then
  make clean
  rm -rf "${NODE_BUILD_DIR}"
  exit 0
fi

# make sure the build directory exists
mkdir -p "$NODE_BUILD_DIR"

# check if a build product exists and is up-to-date
# TODO: check each product based on ARCHS
if [ .git/HEAD -nt "${NODE_LIBNODE_PRODUCT}" ] \
|| [ .git/HEAD -nt "${NODE_LIBV8_PRODUCT}" ]
then
  IS_DIRTY=1
fi

# Exit cleanly if everything is up-to-date
if [ $IS_DIRTY -eq 0 ]; then
  exit 0
fi

# path w/o MacPorts since we need node to link against system libraries in order
# to be portable. Node currently does not support specifying which openssl to
# use, which is why do do this "trick"
export PATH=/usr/local/bin:/usr/bin:/bin:/usr/sbin:/sbin

# let's build
WAF="python tools/waf-light --jobs=$(sysctl -n hw.ncpu)"
WAF_MAKE="$WAF --check-c-compiler=clang --product-type=cstaticlib --debug build"

# debug build is treated differently (_g suffix, debug subdir, etc) by WAF
if [ "$BUILD_STYLE" = "Debug" ]; then
  echo "info: Building debug"
  $WAF --without-snapshot "--blddir=${NODE_BUILD_DIR}" --debug configure
  $WAF_MAKE
  NODE_PICKUP_DIR="${NODE_BUILD_DIR}/debug"
  mv "${NODE_PICKUP_DIR}/libnode_g.a" "${NODE_LIBNODE_PRODUCT}"
  mv "${NODE_PICKUP_DIR}/libv8_g.a" "${NODE_LIBV8_PRODUCT}"
else
# release build
  echo "info: Building release for architectures $ARCHS"
  LAST_BUILT_ARCH=
  BUILT_ARCHS_COUNT=0
  NODE_LIBNODE_PRODUCTS=
  NODE_LIBV8_PRODUCTS=

  for arch in $ARCHS; do
    if [ "$arch" = "x86_64" ]; then arch=x64
    elif [ "$arch" = "i386" ]; then arch=ia32
    else
      echo "warning: Unsupported architecture \"$arch\"" >&2
      continue
    fi
    NODE_ARCH_BUILD_DIR="${NODE_BUILD_DIR}-${arch}"
    $WAF --without-snapshot "--blddir=${NODE_ARCH_BUILD_DIR}" \
         --dest-cpu=${arch} configure
    $WAF_MAKE
    NODE_LIBNODE_PRODUCTS="${NODE_LIBNODE_PRODUCTS} ${NODE_ARCH_BUILD_DIR}/default/libnode.a"
    NODE_LIBV8_PRODUCTS="${NODE_LIBV8_PRODUCTS} ${NODE_ARCH_BUILD_DIR}/default/libv8.a"
    LAST_BUILT_ARCH="$arch"
    BUILT_ARCHS_COUNT=$(expr $BUILT_ARCHS_COUNT + 1)
  done  # for each arch: make

  if [ $BUILT_ARCHS_COUNT -gt 1 ]; then
    # create universal binaries
    lipo -create ${NODE_LIBNODE_PRODUCTS} -output "${NODE_LIBNODE_PRODUCT}"
    lipo -create ${NODE_LIBV8_PRODUCTS} -output "${NODE_LIBV8_PRODUCT}"
    echo "created universal libraries: ${NODE_LIBNODE_PRODUCT} and ${NODE_LIBV8_PRODUCT}"
  elif [ $BUILT_ARCHS_COUNT -eq 1 ]; then
    mv -vf "${NODE_LIBNODE_PRODUCTS}" "${NODE_LIBNODE_PRODUCT}"
    mv -vf "${NODE_LIBV8_PRODUCTS}" "${NODE_LIBV8_PRODUCT}"
  else
    echo "warning: no product was built (no supported architectures)" >&2
  fi
fi
