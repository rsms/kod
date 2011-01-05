#!/bin/sh

if [[ $1 && $1 == upstream ]]; then
	echo "Pulling from upstream (https://github.com/rsms/kod.git)..."
	git pull https://github.com/rsms/kod.git 
else
	echo "Pulling from origin..."
	git pull
fi

echo "Updating submodules..."
git submodule update --init