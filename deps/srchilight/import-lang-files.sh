#!/bin/bash
cd "$(dirname "$0")"
cd src-highlite || exit $?
git pull origin master || exit $?
cd ../../.. || exit $?

for file in deps/srchilight/src-highlite/src/*.lang; do
  basename=$(basename "$file")
  file1="$file"
  file2="resources/lang/$basename"
  if [ -f "$file2" ]; then
    md51=$(md5 -q "$file1")
    md52=$(md5 -q "$file2")
    if [ "$md51" != "$md52" ]; then
      echo modified $file1 $file2
    fi
  else
    echo copy new $file1 "->" $file2
    cp "$file1" "$file2"
  fi
done

