#!/bin/bash
cd "$(dirname $0)/node"

# path w/o MacPorts since we need node to link against system libraries in order
# to be portable. Node currently does not support specifying which openssl to
# use, which is why do do this "trick"
export PATH=/usr/local/bin:/usr/bin:/bin:/usr/sbin:/sbin

rm -rf build
make clean
./configure --dest-cpu=ia32 --without-snapshot
make staticlib
mv build/default/libnode.a build/default/libnode-ia32.a
mv build/default/libv8.a build/default/libv8-ia32.a

make clean
./configure --dest-cpu=x64 --without-snapshot
make staticlib
mv build/default/libnode.a build/default/libnode-x64.a
mv build/default/libv8.a build/default/libv8-x64.a

lipo -create build/default/libnode-ia32.a build/default/libnode-x64.a \
     -output build/default/libnode.a
lipo -create build/default/libv8-ia32.a build/default/libv8-x64.a \
     -output build/default/libv8.a
