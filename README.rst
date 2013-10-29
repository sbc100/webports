naclports - Ports of open source software to Native Client
==========================================================

naclports is collection of open source libraries and applications that have
been ported to Native Client, along with set to tools for building and maintain
them.

The packages themselves live in the ``libraries`` and ``examples`` directories.
Each one contains a description of the package (pkg_info), a bash script for
building it (build.sh) and an optional patch file (nacl.patch).  The build
script will download, patch, build and install the application or library.

The scripts require that certain tools are present in the host system.
You will need at least these (but probably more):

- bash
- make
- sed
- git
- autoconf, automake
- pkg-config
- gettext
- libglib2.0-dev >= 2.26.0 (if you want to build nacl-glib)

Before you can build any of the package you must set the NACL_SDK_ROOT
environment variable to top directory of a version of the Native Client SDK
(the directory containing toolchain/).  This path should be absolute.

The top level Makefile can be used to build one of more of the packages.
Package dependencies are built into this Makefile. For example, ``make vorbis``
will build ``libvorbis-1.2.3`` and ``libogg-1.1.4``.  ``make all`` will build
all of the libraries.

There are 4 possible architectures that NaCl modules can be compiled for: i686,
x86_64, arm, pnacl.  The naclports build system will build just one at at time.
You can control which one by setting the ``NACL_ARCH`` environment variable.
E.g.::

  $ NACL_ARCH=arm make openssl

If you want to build a certain package for all architectures you can use the
top level ``make_all.sh`` script.  E.g.::

  $ ./make_all.sh openssl

Headers and libraries are installed into the toolchains themselves so there is
not add extra -I or -L options in order to use the libraries.  (Currently,
these scripts will generate a gcc "specs" file to add the required extra
paths.)

The source code and build output for each package is placed in::

  out/repository/<PACKAGE_NAME>

**Note**: Each package has its own license.  Please read and understand these
licenses before using these packages in your projects.

**Note to Windows users**:  These scripts are written in bash and must be
launched from a Cygwin shell.

Running the examples
--------------------

Applications/Examples are installed to ``out/publish``. To run them in chrome
you need to serve them with a webserver.  The easiest way to do this is to
run::

  $ make run

This will start a local webserver serving the content of ``out/publish``
after which you can navigate to http://localhost:5103 to view the content.

Adding a new package
--------------------

To add a package:

1. If you are using svn, make sure you have a writable version of the
   repository::

     $ gclient config https://naclports.googlecode.com/svn/trunk/src

2. Add a directory to the libraries directory using the name your new package.
   For example: ``libraries/openssl``.
3. Add the build.sh script and pkg_info to that directory.
4. Optionally include the upstream tarball and create a .sha1 checksum file.
   You can do this using ``build_tools/sha1sum.py``.  Redirect the script
   output to a .sha1 file so that the build system will find it.  E.g.::

     $ sha1sum.py mypkg.tar.gz > libraries/openssl/openssl-0.0.1.sha1

5. Optionally include a patch file (nacl.patch).  See below for the
   recommended way to generate this patch.
6. Add the invocation of your script, and any dependencies to the top level
   Makefile.
7. Make sure your package builds for all architectures::

     $ ./make_all.sh <PACKAGE_NAME>

Modifying package sources / Working with patches
------------------------------------------------

When a package is first built, its source is downloaded and extracted to
``out/repository/<PKG_NAME>``.  A new git repository is then created in this
folder with the original archive contents on a branch called ``upstream``.  The
optional ``nacl.patch`` file is then applied on the ``master`` branch.  This
means that at any given time you can see the changes from upstream using ``git
diff upstream``.

To make changes to a package's patch file the recommended workflow is:

1. Directly modify the sources in ``out/repository/PKG_NAME``.
2. Build the package and verify the changes.
3. Use ``git diff upstream.. > ../path/to/nacl.patch`` to regenerate
   the patch file.

Whenever the upstream archive or patch file changes and you try to build the
package you will be prompted to remove the existing repository and start a new
one. This is to avoid deleting a repository that might have unsaved changed.
