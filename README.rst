naclports - Ports of open source software to Native Client
==========================================================

naclports is collection of open source libraries and applications that have
been ported to Native Client, along with set to tools for building and
maintaining them.

Packages can be built from source or prebuilt binaries packages can be
downloaded from the continuous build system.

The sources for the ports live in the ``ports`` directory.  Each one contains
at least the following file:

- pkg_info: a description of the package.

Most also contain the follow optional files:

- build.sh: a bash script for building it
- nacl.patch: an optional patch file.

The tools for building packages live in ``bin``.  The binary tool is simple
called ``naclports``.  To build and install a package into the toolchain run
``naclports install <package_dir>``.  This script will download, patch, build
and install the application or library.  By default it will first install any
dependencies that that the package has.


Links
-----

Project home: https://code.google.com/p/naclports/
Continuous builder: http://build.chromium.org/p/client.nacl.ports/
Continuous build artifacts: http://gsdview.appspot.com/naclports/builds/


Prerequistes
------------

The minimum requirements for using naclports are:

- python 2.7
- gclient (from depot_tools)
- Native Client SDK

For building packages from source the build scripts require that certain tools
are present in the host system:

- bash
- make
- curl
- sed
- git

To build all ports you will also need these:

- cmake
- texinfo
- gettext
- pkg-config
- autoconf, automake, libtool
- libglib2.0-dev >= 2.26.0 (if you want to build glib)
- xsltproc

On Mac OS X you can use homebrew to install these using the following command::

  brew install autoconf automake cmake gettext libtool pkg-config

The build system for some of the native Python modules relies on a 32-bit
host build of Python itself, which in turn relies on the development version
of zlib and libssl being available.  On 64-bit Ubuntu/Trusty this means
installing:

- zlib1g-dev:i386
- libssl-dev:i386

On older Debian/Ubuntu systems these packages were known as:

- lib32z1-dev
- libssl0.9.8:i386


Building
--------

Before you can build any of the package you must set the ``NACL_SDK_ROOT``
environment variable to top directory of a version of the Native Client SDK
(the directory containing toolchain/). This path should be absolute.

The top level Makefile can be used as a quick way to build one or more
packages. For example, ``make libvorbis`` will build ``libvorbis`` and
``libogg``. ``make all`` will build all the packages.

There are 4 possible architectures that NaCl modules can be compiled for: i686,
x86_64, arm, pnacl. The naclports build system will only build just one at at
time. You can control which one by setting the ``NACL_ARCH`` environment
variable. e.g.::

  $ NACL_ARCH=arm make openssl

For some architectures there is more than one toolchain available.  For example
for x86 you can choose between newlib and glibc.  The toolchain defaults to
newlib and can be specified by setting the ``TOOLCHAIN`` environment variable::

  $ NACL_ARCH=i686 TOOLCHAIN=glibc make openssl

If you want to build a certain package for all architectures and all toolchains
you can use the top level ``make_all.sh`` script. e.g.::

  $ ./make_all.sh openssl

Headers and libraries are installed into the toolchains directly so there is
not add extra -I or -L options in order to use the libraries.

The source code and build output for each package is placed in::

  out/build/<PACKAGE_NAME>

By default all builds are in release configuration.  If you want to build
debug packages set ``NACL_DEBUG=1`` or pass ``--debug`` to the naclports
script.

**Note**: Each package has its own license. Please read and understand these
licenses before using these packages in your projects.

**Note to Windows users**: These scripts are written in bash and must be
launched from a Cygwin shell. While many of the scripts should work under
Cygwin, naclports is only tested on Linux and Mac so YMMV.


Binary Packages
---------------

By default naclports will attempt to install binary packages rather than
building them from source. The binary packages are produced by the buildbots
and stored in Google cloud storage. The index of current binary packages
is stored in ``lib/prebuilt.txt`` and this is currently manually updated
by running ``build_tools/scan_packages.py``.

If the package version does not match the package will always be built from
source.

If you want to force a package to be built from source you can pass
``--from-source`` to the naclports script.


Emscripten Support
------------------

The build system contains very early alpha support for building packages
with Emscripten.  To do requires the Emscripten SDK to be installed and
configured (with the Emscripten tools in the PATH).  To build for Emscripten
build with ``TOOLCHAIN=emscripten``.


Running the examples
--------------------

Applications/Examples that build runnable web pages are published to
``out/publish``. To run them in chrome you need to serve them with a web
server.  The easiest way to do this is to run::

  $ make run

This will start a local web server serving the content of ``out/publish``
after which you can navigate to http://localhost:5103 to view the content.


Adding a new package
--------------------

To add a package:

1. If you are using svn, make sure you have a writable version of the
   repository::

     $ gclient config https://naclports.googlecode.com/svn/trunk/src

2. Add a directory to the ``ports`` directory using the name your new package.
   For example: ``ports/openssl``.
3. Add the build.sh script and pkg_info to that directory.
4. Optionally include the upstream tarball and add its sha1 checksum to
   pkg_info. You can do this using ``build_tools/sha1sum.py``.  Redirect the
   script to append to the pkg_info file.  e.g.::

     $ sha1sum.py mypkg.tar.gz >> ports/openssl/pkg_info

5. Optionally include a patch file (nacl.patch). See below for the
   recommended way to generate this patch.
6. Make sure your package builds for all architectures::

     $ ./make_all.sh <PACKAGE_NAME>


Writing build scripts
---------------------

Each port has an optional build script: ``build.sh``. Some ports, such as
those that are based on autotools+make don't need a build script at all. The
build script is run in a bash shell, it can set variables at the global scope
that override the default behaviour of various steps in the build process. The
most common steps that implement by package-specific scripts are:

- ConfigureStep()
- BuildStep()
- InstallStep()
- TestStep()

When implementing a given step the default step can be still invoked, e.g.
by calling DefaultBuildStep() from within BuildStep()

Each build is is run independently in a subshell, so variables set in one
step are not visible in others, and changing the working directory within a
step will not effect other steps.

A variety of shared variables and functions are available from with the build
scripts.  These are defined in build_tools/common.sh.

When modifying any shell scripts in naclports it is recommended that you
run ``shellcheck`` to catch common errors.  The recommended command line
for this is::

  shellcheck -e SC2044,SC2129,SC2046,SC2035,SC2034,SC2086,SC2148 \
    `git ls-files "*.sh"`


Modifying package sources / Working with patches
------------------------------------------------

When a package is first built, its source is downloaded and extracted to
``out/build/<pkg_name>``. A new git repository is then created in this
folder with the original archive contents on a branch called ``upstream``. The
optional ``nacl.patch`` file is then applied on the ``master`` branch. This
means that at any given time you can see the changes from upstream using ``git
diff upstream``.

To make changes to a package's patch file the recommended workflow is:

1. Directly modify the sources in ``out/build/<pkg_name>``.
2. Build the package and verify the changes.
3. Use ``naclports updatepatch <pkg_name>`` to (re)generate the patch file.

Whenever the upstream archive or patch file changes and you try to build the
package you will be prompted to remove the existing repository and start a new
one. This is to avoid deleting a repository that might contain unsaved changed.


Coding Style
------------

For code that is authored in the naclports repository (as opposed to patches)
we follow the Chromium style guide:
http://www.chromium.org/developers/coding-style.

C/C++ code can be automatically formatted with Chromium's clang-format:
https://code.google.com/p/chromium/wiki/ClangFormat. If you have checkout of
Chromium you can set CHROMIUM_BUILDTOOLS_PATH=<chromium>/src/buildtools
which will enable the clang-format script in depot_tools to find the binary.


Happy porting!
