naclports - Ports of open source software to Native Client
==========================================================

naclports is collection of open source libraries and applications that have
been ported to Native Client, along with set to tools for building and
maintaining them.

The ports themselves live in the ``ports`` directory.  Each one contains of
three main file:

- pkg_info: a description of the package.
- build.sh: a bash script for building it
- nacl.patch: an optional patch file.

The tools for building packages live in ``build_tools``.  To build and install
a package into the toolchain run ``naclports.py install <package_dir>``.  This
script will download, patch, build and install the application or library.  By
default it will first build any dependencies that that the package has.


Prerequistes
------------

The build scripts require that certain tools are present in the host system.
You will need at least these:

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

On Mac OS X you can use homebrew to install these using the following command::

  brew install autoconf automake cmake gettext libtool pkg-config

The build system for some of the native Python modules relies on a 32-bit
host build of Python itself, which in turn relies on the development version
of zlib being available.  On 64-bit Ubuntu/Precise this means installing the
following package: ``lib32z1-dev``.


Building
--------

Before you can build any of the package you must set the NACL_SDK_ROOT
environment variable to top directory of a version of the Native Client SDK
(the directory containing toolchain/). This path should be absolute.

The top level Makefile can be used as a quick way to build one or more
packages. For example, ``make vorbis`` will build ``libvorbis-1.2.3`` and
``libogg-1.1.4``. ``make all`` will build all the packages.

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
not add extra -I or -L options in order to use the libraries. (Currently,
the naclports scripts will generate a gcc "specs" file to add the required
paths.)

The source code and build output for each package is placed in::

  out/build/<PACKAGE_NAME>

**Note**: Each package has its own license. Please read and understand these
licenses before using these packages in your projects.

**Note to Windows users**: These scripts are written in bash and must be
launched from a Cygwin shell. While many of the scripts should work under
Cygwin naclports is only tested on Linux and Mac so YMMV.


Binary Packages
---------------

Binary packages for naclports, which will allow packages to be installed
without having to build from source, are currently being worked on.
Currently a binary archive is built for each package as part of the standard
package build process.  The packages live in the ``out/packages`` directory.
In the future we hope to allow packages to be downloaded and installed from
external archives, such as the continuous builders.


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


Modifying package sources / Working with patches
------------------------------------------------

When a package is first built, its source is downloaded and extracted to
``out/build/<PKG_NAME>``. A new git repository is then created in this
folder with the original archive contents on a branch called ``upstream``. The
optional ``nacl.patch`` file is then applied on the ``master`` branch. This
means that at any given time you can see the changes from upstream using ``git
diff upstream``.

To make changes to a package's patch file the recommended workflow is:

1. Directly modify the sources in ``out/build/PKG_NAME``.
2. Build the package and verify the changes.
3. Use ``git diff upstream.. > ../path/to/nacl.patch`` to regenerate
   the patch file.

Whenever the upstream archive or patch file changes and you try to build the
package you will be prompted to remove the existing repository and start a new
one. This is to avoid deleting a repository that might have unsaved changed.

Happy porting!
