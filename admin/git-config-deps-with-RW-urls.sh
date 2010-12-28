#!/bin/sh
(cd deps/libcss && git remote set-url origin git@github.com:rsms/libcss-osx.git)
(cd deps/hunch-cocoa && git remote set-url origin git@github.com:rsms/hunch-cocoa.git)
(cd deps/chromium-tabs && git remote set-url origin git@github.com:rsms/chromium-tabs.git)

echo Submodule upstream URLs are now configured as:
git submodule foreach git remote -v
