#!/bin/sh

if [[ $1 && $1 == origin ]]; then
	echo "Fetching from origin..."
        git fetch origin

else
	echo "Fetching from upstream (https://github.com/rsms/kod.git)..."
        git fetch upstream
fi

echo "Updating submodules..."
git submodule update --init
