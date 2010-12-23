#!/bin/bash
cd "$(dirname $0)/node"

# path w/o MacPorts since we need node to link against system libraries in order
# to be portable. Node currently does not support specifying which openssl to
# use, which is why do do this "trick"
export PATH=/usr/local/bin:/usr/bin:/bin:/usr/sbin:/sbin

make clean
./configure --dest-cpu=ia32
make
mv build/default/node build/default/node-ia32

make clean
./configure --dest-cpu=x64
make
mv build/default/node build/default/node-x64

lipo -create build/default/node-ia32 build/default/node-x64 -output build/default/node
