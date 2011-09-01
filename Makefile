# Copyright (c) 2011 The Native Client Authors. All rights reserved.
# Use of this source code is governed by a BSD-style license that can be
# found in the LICENSE file.
#
# Makefile
#
# usage: 'make [package]'
#
# This makefile builds all of the Native Client packages listed below
# in $(PACKAGES). Each package has a dependency on its own sentinel
# file, which can be found at naclports/src/out/sentinels/sentinel_file_*
#
# The makefile depends on the NACL_SDK_ROOT environment variable
#

OS_NAME := $(shell uname -s)

OS_SUBDIR := UNKNOWN
ifeq ($(OS_NAME), Darwin)
  OS_SUBDIR := mac
endif
ifeq ($(OS_NAME), Linux)
  OS_SUBDIR := linux
endif
ifneq (, $(filter CYGWIN%,$(OS_NAME)))
  OS_SUBDIR := win
endif

ifeq ($(OS_SUBDIR), UNKNOWN)
  $(error No support for the Operating System: $(OS_NAME))
endif

ifndef NACL_SDK_ROOT
  $(error NACL_SDK_ROOT not set, see README.txt)
endif

BITSIZE := 32
ifeq ($(NACL_PACKAGES_BITSIZE), 64)
  BITSIZE := 64
endif


NACL_TOOLCHAIN_ROOT = $(NACL_SDK_ROOT)/toolchain/$(OS_SUBDIR)_x86

NACL_OUT = out
NACL_DIRS_BASE = $(NACL_OUT)/tarballs \
                 $(NACL_OUT)/repository-i686 \
                 $(NACL_OUT)/repository-x86_64 \
                 $(NACL_OUT)/publish

NACL_SDK_USR32 = $(NACL_TOOLCHAIN_ROOT)/nacl/usr
NACL_SDK_USR64 = $(NACL_TOOLCHAIN_ROOT)/nacl64/usr

NACL_DIRS_TO_REMOVE = $(NACL_OUT) \
		      $(NACL_SDK_USR32) \
		      $(NACL_SDK_USR64)

NACL_DIRS_TO_MAKE = $(NACL_DIRS_BASE) \
		    $(NACL_SDK_USR32)/include \
		    $(NACL_SDK_USR64)/include \
		    $(NACL_SDK_USR32)/lib \
		    $(NACL_SDK_USR64)/lib

LIBRARIES = \
     libraries/nacl-mounts \
     libraries/SDL-1.2.14 \
     libraries/gc6.8 \
     libraries/fftw-3.2.2 \
     libraries/libtommath-0.41 \
     libraries/libtomcrypt-1.17 \
     libraries/zlib-1.2.3 \
     libraries/jpeg-6b \
     libraries/libpng-1.2.40 \
     libraries/tiff-3.9.1 \
     libraries/FreeImage-3.14.1 \
     libraries/libogg-1.1.4 \
     libraries/libvorbis-1.2.3 \
     libraries/lame-398-2 \
     libraries/faad2-2.7 \
     libraries/faac-1.28 \
     libraries/libtheora-1.1.1 \
     libraries/flac-1.2.1 \
     libraries/speex-1.2rc1 \
     libraries/x264-snapshot-20091023-2245 \
     libraries/lua-5.1.4 \
     libraries/tinyxml \
     libraries/expat-2.0.1 \
     libraries/pixman-0.16.2 \
     libraries/gsl-1.9 \
     libraries/freetype-2.1.10 \
     libraries/fontconfig-2.7.3 \
     libraries/agg-2.5 \
     libraries/cairo-1.8.8 \
     libraries/ImageMagick-6.5.4-10 \
     libraries/ffmpeg-0.5 \
     libraries/Mesa-7.6 \
     libraries/libmodplug-0.8.7 \
     libraries/OpenSceneGraph-2.9.7 \
     libraries/nethack-3.4.3 \
     libraries/cfitsio \
     libraries/boost_1_43_0 \
     libraries/protobuf-2.3.0 \
     libraries/dreadthread

EXAMPLES = \
     examples/games/scummvm-1.2.1 \
     examples/systems/bochs-2.4.6

PACKAGES = $(LIBRARIES) $(EXAMPLES)


SENTINELS_DIR = $(NACL_OUT)/sentinels
SENT = $(SENTINELS_DIR)/sentinel_file_$(BITSIZE)_

.PHONY: all clean

libraries: $(LIBRARIES)
examples: $(EXAMPLES)
all: $(PACKAGES)


clean:
	rm -rf $(NACL_DIRS_TO_REMOVE)

$(NACL_DIRS_TO_MAKE):
	mkdir -p $@

$(PACKAGES): %: $(NACL_DIRS_TO_MAKE) $(SENT)%

$(PACKAGES:%=$(SENT)%): $(SENT)%:
	echo "@@@BUILD_STEP $(BITSIZE)-bit $(notdir $*)@@@"
	cd $* && ./nacl-$(notdir $*).sh
	mkdir -p $(@D)
	touch $@

# packages with dependencies
$(SENT)libraries/libvorbis-1.2.3: ogg
$(SENT)libraries/libtheora-1.1.1: ogg
$(SENT)libraries/flac-1.2.1: ogg
$(SENT)libraries/speex-1.2rc1: ogg
$(SENT)libraries/fontconfig-2.7.3: expat freetype
$(SENT)libraries/libpng-1.2.40: zlib
$(SENT)libraries/agg-2.5: freetype
$(SENT)libraries/cairo-1.8.8: pixman fontconfig png
$(SENT)libraries/ffmpeg-0.5: lame vorbis theora
$(SENT)libraries/nethack-3.4.3: nacl-mounts
$(SENT)examples/games/scummvm-1.2.1: nacl-mounts sdl
$(SENT)examples/systems/bochs-2.4.6: nacl-mounts sdl

# shortcuts
nacl-mounts: libraries/nacl-mounts ;
cfitsio: libraries/cfitsio ;
tinyxml: libraries/tinyxml ;
sdl: libraries/SDL-1.2.14 ;
gc: libraries/gc6.8 ;
fftw: libraries/fftw-3.2.2 ;
tommath: libraries/libtommath-0.41 ;
tomcrypt: libraries/libtomcrypt-1.17 ;
zlib: libraries/zlib-1.2.3 ;
jpeg: libraries/jpeg-6b ;
png: libraries/libpng-1.2.40 ;
tiff: libraries/tiff-3.9.1 ;
freeimage: libraries/FreeImage-3.14.1 ;
ogg: libraries/libogg-1.1.4 ;
vorbis: libraries/libvorbis-1.2.3 ;
lame: libraries/lame-398-2 ;
faad: libraries/faad2-2.7 ;
faac: libraries/faac-1.28 ;
theora: libraries/libtheora-1.1.1 ;
flac: libraries/flac-1.2.1 ;
speex: libraries/speex-1.2rc1 ;
x264: libraries/x264-snapshot-20091023-2245 ;
lua: libraries/lua-5.1.4 ;
expat: libraries/expat-2.0.1 ;
pixman: libraries/pixman-0.16.2 ;
gsl: libraries/gsl-1.9 ;
freetype: libraries/freetype-2.1.10 ;
fontconfig: libraries/fontconfig-2.7.3 ;
agg: libraries/agg-2.5 ;
cairo: libraries/cairo-1.8.8 ;
imagemagick: libraries/ImageMagick-6.5.4-10 ;
ffmpeg: libraries/ffmpeg-0.5 ;
mesa: libraries/Mesa-7.6 ;
modplug: libraries/libmodplug-0.8.7 ;
openscenegraph: libraries/OpenSceneGraph-2.9.7 ;
nethack: libraries/nethack-3.4.3 ;
boost: libraries/boost_1_43_0 ;
protobuf: libraries/protobuf-2.3.0 ;
scummvm: examples/games/scummvm-1.2.1 ;
bochs: examples/systems/bochs-2.4.6 ;
