#!/bin/bash
# Copyright (c) 2011 The Native Client Authors. All rights reserved.
# Use of this source code is governed by a BSD-style license that can be
# found in the LICENSE file.

#@ xaos_tool.sh
#@
#@ usage:  xaos_tool.sh <mode>
#@
#@ this script bootstraps a nacl module for the xaos fractal rendering
#@ engine off the web including the gsl package it depends on.
#@
#@ This works on linux only, assumes you have web access
#@ and that you have the typical linux tools installed
#@ See README.nacl for more detail
#@
set -o nounset
set -o errexit

readonly SAVE_PWD=$(pwd)


# Pick platform directory for compiler.
readonly OS_NAME=$(uname -s)
if [ $OS_NAME = "Darwin" ]; then
  readonly OS_SUBDIR="mac"
  readonly OS_SUBDIR_SHORT="mac"
elif [ $OS_NAME = "Linux" ]; then
  readonly OS_SUBDIR="linux"
  readonly OS_SUBDIR_SHORT="linux"
else
  readonly OS_SUBDIR="windows"
  readonly OS_SUBDIR_SHORT="win"
fi

readonly NACL_TOOLCHAIN_ROOT=${NACL_TOOLCHAIN_ROOT:-\
${NACL_SDK_ROOT}/toolchain/${OS_SUBDIR_SHORT}_x86}

readonly URL_XAOS=http://downloads.sourceforge.net/xaos/xaos-3.5.tar.gz
readonly PATCH_XAOS=${SAVE_PWD}/xaos-3.5.patch
readonly TARBALL_XAOS=${SAVE_PWD}/xaos-3.5.tar.gz
readonly DIRNAME_XAOS=xaos-3.5

readonly NACLCC=${NACL_TOOLCHAIN_ROOT}/bin/nacl-gcc
readonly NACLAR=${NACL_TOOLCHAIN_ROOT}/bin/nacl-ar
readonly NACLRANLIB=${NACL_TOOLCHAIN_ROOT}/bin/nacl-ranlib


######################################################################
# Helper functions
######################################################################

Banner() {
  echo "######################################################################"
  echo $*
  echo "######################################################################"
}

Usage() {
  help
}

#@
#@ help
#@
#@   Prints help for all modes.
help() {
  egrep "^#@" $0 | cut -c 3-
}


ReadKey() {
  read
}


Download() {
  if which wget ; then
    wget $1 -O $2
  elif which curl ; then
    curl --location --url $1 -o $2
  else
     Banner "Problem encountered"
     echo "Please install curl or wget and rerun this script"
     echo "or manually download $1 to $2"
     echo
     echo "press any key when done"
     ReadKey
  fi

  if [ ! -s $2 ] ; then
    echo "ERROR: could not find $2"
    exit -1
  fi
}

# On Linux with GNU readlink, "readlink -f" would be a quick way
# of getting an absolute path, but MacOS has BSD readlink.
GetAbsolutePath() {
  local relpath=$1
  local reldir
  local relname
  if [ -d "${relpath}" ]; then
    reldir="${relpath}"
    relname=""
  else
    reldir="$(dirname "${relpath}")"
    relname="/$(basename "${relpath}")"
  fi

  local absdir="$(cd "${reldir}" && pwd)"
  echo "${absdir}${relname}"
}

#@
#@ create_xaos-patch <hg-dir>
#@
#@   create the patch file from a mercurial repo
create-xaos-patch() {
  cd $1
  hg diff -r 0 src/ configure.in config.sub > ${PATCH_XAOS}
}

#@
#@ download-xaos
#@
#@  download xaos source tarball
download-xaos() {
  Banner "downloading xaos"
  Download  ${URL_XAOS}  ${TARBALL_XAOS}
}

#@
#@ prepare-src-xaos
#@
#@  untar xaos tarball and apply local patches
prepare-src-xaos() {
  Banner "untaring"
  rm -rf ${DIRNAME_XAOS}
  tar zxf ${TARBALL_XAOS}
  cp -r nacl-ui-driver/ ${DIRNAME_XAOS}/src/ui/ui-drv/nacl
  pushd ${DIRNAME_XAOS}
  Banner "patching"
  patch -p1 < ${PATCH_XAOS}
  Banner "autoconf"
  autoconf
  popd
}


#@
#@ build-xaos <dir> <nexe-name> <build-opts>
#@
#@
build-xaos() {
  pushd $(pwd)
  local dir=$1
  local nexe=$(GetAbsolutePath $2)
  local cflags="$3"
  rm -rf  ${dir}-build
  # sadly xaos seem wants to be built in-place
  cp -r  ${dir} ${dir}-build

  Banner "configure xaos"
  cd ${dir}-build
  export CC=${NACLCC}
  export AR=${NACLAR}
  export RANLIB=${NACLRANLIB}
  export LDFLAGS="-static"
  export CFLAGS="${cflags}"
  export LIBS="-lppapi -lpthread -lstdc++ -lm -u PPP_GetInterface -u PPP_ShutdownModule -u PPP_InitializeModule -u original_main"

  ./configure\
      --with-png=no\
      --host=nacl\
      --with-x11-driver=no\
      --with-sffe=no

  Banner "building xaos"
  make

  Banner "install xaos as ${nexe}"
  cp bin/xaos ${nexe}
  popd
}

#@
#@ build
#@
#@  Build all the nexes
build() {
  build-xaos  ${DIRNAME_XAOS} ./xaos_x86_32.nexe "-m32"
  build-xaos  ${DIRNAME_XAOS} ./xaos_x86_64.nexe "-m64"
  echo "build complete"
}

#@
#@ build-all
#@
#@  Unpack the src and build all the nexes
build-all() {
  prepare-src-xaos
  # currently not used
  cp ${DIRNAME_XAOS}/help/xaos.hlp .
  build
  echo "build complete"
}

#@
#@ clean
#@
#@  remove generated files
clean() {
  rm -f ./xaos_x86_32.nexe ./xaos_x86_64.nexe ./xaos.hlp
  rm -rf *-build/ ${DIRNAME_XAOS}
}

######################################################################
# MAIN
######################################################################
[ $# = 0 ] && set -- help  # Avoid reference to undefined $1.
if [ "$(type -t $1)" != "function" ]; then
  Usage
  echo "ERROR: unknown mode '$1'." >&2
  exit 1
fi


eval "$@"
