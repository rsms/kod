# Kod -- a programmers' editor for OS X

A modern and open universal text editor for programmers on Mac OS X.

If you want to use Kod, simply download the latest "stable" version from [http://kodapp.com/download/](http://kodapp.com/download/)

- General info: <http://kodapp.com/>
- Discussion forum: <http://groups.google.com/group/kod-app>
- Issue tracking and bug reporting: <http://hunch.lighthouseapp.com/projects/66522-kod/tickets>
- Mainline source code: <https://github.com/rsms/kod>
- Twitter: [@kod_app](http://twitter.com/kod_app)
- IRC: [irc://irc.freenode.net/#kod](irc://irc.freenode.net/#kod)
- Developer documentation: <https://github.com/rsms/kod/wiki>
- Daily development builds: <http://kod.sivel.net/daily/>

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


#### Creating and submitting a patch

As mentioned earlier in this article, we prefer that you send a [*pull request*](http://help.github.com/pull-requests/) on GitHub.

1. Create a fork of the upstream repository by visiting <https://github.com/rsms/kod/fork>. If you feel unsecure, here's a great guide: <http://help.github.com/forking/> 

2. Clone of your repository: `git clone https://yourusername@github.com/yourusername/kod.git`

3. This is important: Create a so-called *topic branch*: `git checkout -tb name-of-my-patch` where "name-of-my-patch" is a short but descriptive name of the patch you're about to create. Don't worry about the perfect name though -- you can change this name at any time later on.

4. Hack! Make your changes, additions, etc and commit them.

5. Send a pull request to the upstream repository's owner by visiting your repository's site at github (i.e. https://github.com/yourusername/kod) and press the "Pull Request" button. Here's a good guide on pull requests: <http://help.github.com/pull-requests/>

**Use one topic branch per feature** -- don't mix different kinds of patches in the same branch. Instead, merge them all together into your master branch (or develop everything in your master and then cherry-pick-and-merge into the different topic branches). Git provides for an extremely flexible workflow, which in many ways causes more confusion than it helps you when new to collaborative software development. The guides provided by GitHub at <http://help.github.com/> are a really good starting point and reference.


#### Contributor License Agreement

Before we can accept any contributions to Kod, you need to sign this [CLA](http://en.wikipedia.org/wiki/Contributor_License_Agreement):

[http://kodapp.com/cla.html](http://kodapp.com/cla.html)

> The purpose of this agreement is to clearly define the terms under which intellectual property has been contributed to Kod and thereby allow us to defend the project should there be a legal dispute regarding the software at some future time.

For a list of contributors, please see [AUTHORS](https://github.com/rsms/kod/blob/master/AUTHORS.md) and <https://github.com/rsms/kod/contributors>


## License

See the file `LICENSE`
