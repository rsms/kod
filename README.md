# Kod -- a programmers' editor for OS X

A modern and open universal text editor for programmers on Mac OS X.

If you want to use Kod, simply download the latest "stable" version from [http://kodapp.com/download/](http://kodapp.com/download/)

- General info: [http://kodapp.com/](http://kodapp.com/)
- Discussion forum: [http://groups.google.com/group/kod-app](http://groups.google.com/group/kod-app)
- Issue tracking and bug reporting: [http://kodapp.com/support/](http://kodapp.com/support/)
- Mainline source code: [https://github.com/rsms/kod](https://github.com/rsms/kod)
- Twitter: [@kod_app](http://twitter.com/kod_app)
- IRC: [irc://irc.freenode.net/#kod](irc://irc.freenode.net/#kod)
- Developer documentation: [https://github.com/rsms/kod/wiki](https://github.com/rsms/kod/wiki)

## Development

**Get the source:**

    git clone --recursive https://github.com/rsms/kod.git

**Build dependencies:**

    deps/node-build.sh
    deps/libcss/build.sh

**Setup Source Highlight:**

This currently requires [MacPorts](http://www.macports.org/) or [Homebrew](http://mxcl.github.com/homebrew/).

Via MacPorts:

    port install source-highlight +universal
    deps/srchilight/import-from-macports.sh

Via Homebrew:

    brew install source-highlight
    deps/srchilight/import-from-homebrew.sh

**Start hacking:**

    open kod.xcodeproj


### Refreshing your clone

Since Kod is made up of a main repository as well as a few sub-repositories (git submodules) a simple `git pull` is not sufficient to update your source tree clone. Use the `pull.sh` shell script for this:

    ./pull.sh


### Contributing

The main Kod source tree is hosted on git (a popular [DVCS](http://en.wikipedia.org/wiki/Distributed_revision_control)), thus you should create a fork of the repository in which you perform development. See <http://help.github.com/forking/>.

We prefer that you send a [*pull request* here on GitHub](http://help.github.com/pull-requests/) which will then be merged into the official main line repository. You need to sign the Kod CLA to be able to contribute (see below).

Also, in your first contribution, add yourself to the end of `AUTHORS.md` (which of course is optional).


#### Contributor License Agreement

Before we can accept any contributions to Kod, you need to sign this [CLA](http://en.wikipedia.org/wiki/Contributor_License_Agreement):

[http://kodapp.com/cla.html](http://kodapp.com/cla.html)

> The purpose of this agreement is to clearly define the terms under which intellectual property has been contributed to Kod and thereby allow us to defend the project should there be a legal dispute regarding the software at some future time.

For a list of contributors, please see [AUTHORS](https://github.com/rsms/kod/blob/master/AUTHORS.md) and <https://github.com/rsms/kod/contributors>


## License

See the file `LICENSE`
