#!/bin/bash
cd "$(dirname '$0')"
(cd src-highlite && git pull origin)
rm -rf upstream-lang
mkdir upstream-lang
cd upstream-lang
ln -sv ../src-highlite/src/*.lang .
