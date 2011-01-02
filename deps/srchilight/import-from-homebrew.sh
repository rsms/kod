#!/bin/bash
#
# This script imports and configures dynamic libraries build by homebrew:
#
#   brew install source-highlight
#
# Any dependencies to |LIB| will also be imported and processed.
#
CELLAR=`brew --cellar`
VERSION=`brew info source-highlight | grep "^source-highlight" | sed "s/.* \([0-9.]*\)$/\1/"`
LIB=$CELLAR/source-highlight/$VERSION/lib/libsource-highlight.dylib
#
# -----------------------------------------------------------------------------
#
cd "$(dirname "$0")"
LIB=$(python -c 'import os.path;print os.path.realpath("'"$LIB"'")')
deps=

function listdeps() {
	otool -L "$1" | awk '{print $1}' | grep -v "$1" | grep -v '^/usr/lib/'
}

function resolvedeps() {
	currpath="$1"
	currname=$(basename "$currpath")
	currname=$(echo "$currname" | sed -E 's/\.[0-9]+\.dylib$/.dylib/g')
	
	cp -fvp "$currpath" "$currname"
	chmod +w "$currname"
	echo install_name_tool -id "@rpath/$currname" "$currname"
	install_name_tool -id "@rpath/$currname" "$currname"
	
	for deppath in $(listdeps "$currpath"); do
		deps="$deps $deppath"
		depname=$(basename "$deppath")
		echo install_name_tool -change "$deppath" "@loader_path/$depname" "$currname"
		install_name_tool -change "$deppath" "@loader_path/$depname" "$currname"
		resolvedeps "$deppath"
	done
}

deps="$LIB"
resolvedeps "$LIB"

# ----------------------
# Step 2: Import headers

mkdir -vp include
rm -rf include/srchilite
cp -vpr $CELLAR/source-highlight/$VERSION/include/srchilite include/srchilite
sed 's/ branches build/ \/*branches build/g' \
  include/srchilite/highlightstatebuilder.h \
  > include/srchilite/highlightstatebuilder.h.2 || exit $?
sed 's/endbranches$/endbranches*\//g' \
  include/srchilite/highlightstatebuilder.h.2 \
  > include/srchilite/highlightstatebuilder.h || exit $?
rm -f include/srchilite/highlightstatebuilder.h.2

# Note: we use -I/usr/local/include instead of copying these ATM.
#mkdir -vp include/boost
#cp -vpr /usr/local/include/boost/regex* include/boost/
