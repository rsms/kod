# Kod -- a programmers' editor for OS X

A modern and open universal text editor for programmers on Mac OS X.

If you want to use Kod, simply download the latest "stable" version from [http://kodapp.com/download/](http://kodapp.com/download/)

- General info: [http://kodapp.com/](http://kodapp.com/)
- Discussion forum: [http://groups.google.com/group/kod-app](http://groups.google.com/group/kod-app)
- Issue tracking and bug reporting: [http://kodapp.com/support/](http://kodapp.com/support/)
- Mainline source code: [https://github.com/rsms/kod](https://github.com/rsms/kod)
- Twitter: [@kod_app](http://twitter.com/kod_app)
- IRC: [irc://irc.freenode.net/#kod](irc://irc.freenode.net/#kod)

## Development

**Get the source:**

    git clone --recursive https://github.com/rsms/kod.git

**Build dependencies:**

    deps/node-build.sh
    deps/libcss/build.sh

**Setup Source Highlight:**

Note: This currently requires [MacPorts](http://www.macports.org/).

    port install source-highlight +universal
    deps/srchilight/import-from-macports.sh
    deps/srchilight/import-lang-files.sh

**Start hacking:**

    open kod.xcodeproj


### Refreshing your clone

Since Kod is made up of a main repositroy as well as a few sub-repositories (git submodules) a simple `git pull` is not sufficient to update your source tree clone. Use the `pull.sh` shell script for this:

    ./pull.sh


## License

See the file `LICENSE`
