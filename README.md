# Kod -- a programmers' editor for OS X

A modern and open universal text editor for programmers on Mac OS X.

If you want to use Kod, simply download the latest "stable" version from [http://kodapp.com/download/](http://kodapp.com/download/)

- General info: [http://kodapp.com/](http://kodapp.com/)
- Discussion forum: [http://groups.google.com/group/kod-app](http://groups.google.com/group/kod-app)
- Issue tracking and bug reporting: [http://kodapp.com/support/](http://kodapp.com/support/)
- Mainline source code: [https://github.com/rsms/kod](https://github.com/rsms/kod)
- Twitter: [@kod_app](http://twitter.com/kod_app)

## Development

### 1. Get the source

It's recommended you clone the repository `git://github.com/rsms/kod.git`:

    git clone --recursive https://github.com/rsms/kod.git

### 2. Build node

    deps/node-build.sh

### 3. Build libcss

    deps/libcss/checkout-deps.sh
    deps/libcss/build.sh

### 4. Configure Source Highlight

This currently requires MacPorts. Sorry.

    port install source-highlight +universal
    deps/srchilight/import-from-macports.sh
    deps/srchilight/import-lang-files.sh

### 5. Check out chromium-tabs

    git clone git://github.com/rsms/chromium-tabs.git

### 6. Start hacking

    open kod.xcodeproj


## License

See the file `LICENSE`
