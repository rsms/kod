#!/bin/bash
cd "$(dirname $0)/node"

make clean
./configure --dest-cpu=ia32
make
mv build/default/node build/default/node-ia32

make clean
./configure --dest-cpu=x64
make
mv build/default/node build/default/node-x64

lipo -create build/default/node-ia32 build/default/node-x64 -output build/default/node
