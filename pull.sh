#!/bin/sh

if [[ $1 && $1 == upstream ]]; then
	echo "Fetching from upstream (https://github.com/rsms/kod.git)..."
	git fetch https://github.com/rsms/kod.git 
else
	echo "Fetching from origin..."
	git fetch origin
fi

echo "Updating submodules..."
git submodule update --init
