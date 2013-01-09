#!/bin/sh

function nacl_configure {
#  Copyright (c) 2011 Shinichiro Hamaji
  if [ -z "$1" ]; then
    PARAM=
  else
    PARAM=$1
  fi
  #echo $(ls -d $NACL_SDK_ROOT/toolchain/* | grep $PARAM _newlib)
  if [ "x$NACL_TOOLCHAIN_ROOT" = "x" ]; then
    SD=$NACL_SDK_ROOT/toolchain
    export NACL_TOOLCHAIN_ROOT="$(ls -d $SD/* | grep $PARAM _glibc)"
    if [ "x$NACL_TOOLCHAIN_ROOT" = "x" ]; then
      echo "Failed to detect NACL_TOOLCHAIN_ROOT in $NACL_SDK_ROOT/toolchain."
      echo "Set this environment variable manually."
      exit 1
    fi
    if echo $NACL_TOOLCHAIN_ROOT | grep ' '; then
      echo "Multiple NACL_TOOLCHAIN_ROOT detected ($NACL_TOOLCHAIN_ROOT)"
      echo "Set this environment manually."
      exit 1
    fi
  fi

  export NACL_ARCH=${NACL_ARCH:-"i686"}
  if [ $NACL_ARCH = "i686" ] ; then
    export ARCH=x86-32
    export LARCH=i686
    export NACL_LIBDIR=lib32
  elif [ $NACL_ARCH = "x86_64" ] ; then
    export LARCH=x86_64
    export ARCH=x86-64
    export NACL_LIBDIR=lib64
  else
    "Unknown value for NACL_ARCH: '$NACL_ARCH'"
    exit -1
  fi
}

nacl_configure
NACL_LIB_PATH=$NACL_TOOLCHAIN_ROOT/x86_64-nacl
$NACL_SDK_ROOT/tools/create_nmf.py \
  -L$NACL_LIB_PATH/usr/$NACL_LIBDIR \
  -L$NACL_LIB_PATH/$NACL_LIBDIR -o thttpd.nmf -s . \
  thttpd_$NACL_ARCH
