# Copyright (c) 2012 The Native Client Authors. All rights reserved.
# Use of this source code is governed by a BSD-style license that can be
# found in the LICENSE file.
#
# Makefile
#
# usage: 'make [package]'
#
# This makefile builds all of the Native Client packages listed below
# in $(PACKAGES). Each package has a dependency on its own sentinel
# file, which can be found at naclports/src/out/sentinels/*
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

ifndef NACL_ARCH
   NACL_ARCH := x86_64
endif

ifndef NACL_SDK_ROOT
  $(error NACL_SDK_ROOT not set, see README.txt)
endif

ifeq ($(NACL_GLIBC), 1)
  ifeq ($(NACL_ARCH), arm)
    $(error NACL_GLIBC does not work with arm)
  endif
  ifeq ($(NACL_ARCH), pnacl)
    $(error NACL_GLIBC does not work with pnacl)
  endif
endif

ifeq ($(NACL_ARCH), arm)
  NACL_TOOLCHAIN_ROOT = $(NACL_SDK_ROOT)/toolchain/$(OS_SUBDIR)_arm_newlib
  NACL_LIBC = newlib
else
ifeq ($(NACL_GLIBC), 1)
  NACL_TOOLCHAIN_ROOT = $(NACL_SDK_ROOT)/toolchain/$(OS_SUBDIR)_x86_glibc
  NACL_LIBC = glibc
else
  NACL_TOOLCHAIN_ROOT = $(NACL_SDK_ROOT)/toolchain/$(OS_SUBDIR)_x86_newlib
  NACL_LIBC = newlib
endif
endif

NACL_OUT = out
NACLPORTS_PREFIX ?= $(NACL_TOOLCHAIN_ROOT)/$(NACL_ARCH)-nacl/usr

NACL_DIRS_BASE = $(NACL_OUT)/tarballs \
                 $(NACL_OUT)/publish \
                 $(NACLPORTS_PREFIX)

NACL_DIRS_TO_REMOVE = $(NACL_OUT) \
                      $(NACLPORTS_PREFIX) \

NACL_DIRS_TO_MAKE = $(NACL_DIRS_BASE) \
                    $(NACLPORTS_PREFIX)/include \
                    $(NACLPORTS_PREFIX)/lib

LIBRARIES = \
     libraries/agg \
     libraries/boost \
     libraries/box2d \
     libraries/bzip2 \
     libraries/cairo \
     libraries/cfitsio \
     libraries/DevIL \
     libraries/dreadthread \
     libraries/expat \
     libraries/faac \
     libraries/faad2 \
     libraries/ffmpeg \
     libraries/fftw \
     libraries/flac \
     libraries/fontconfig \
     libraries/freealut \
     libraries/FreeImage \
     libraries/freetype \
     libraries/gc \
     libraries/glib \
     libraries/glibc-compat \
     libraries/gsl \
     libraries/gtest \
     libraries/ImageMagick \
     libraries/jpeg \
     libraries/jsoncpp \
     libraries/lame \
     libraries/lcms \
     libraries/libmikmod \
     libraries/libmng \
     libraries/libmodplug \
     libraries/libogg \
     libraries/libpng \
     libraries/libtheora \
     libraries/libtomcrypt \
     libraries/libtommath \
     libraries/libvorbis \
     libraries/libxml2 \
     libraries/lua \
     libraries/Mesa \
     libraries/mpg123 \
     libraries/nacl-mounts \
     libraries/ncurses \
     libraries/openal-soft \
     libraries/OpenSceneGraph \
     libraries/openssl \
     libraries/pango \
     libraries/physfs \
     libraries/pixman \
     libraries/protobuf \
     libraries/Regal \
     libraries/SDL \
     libraries/SDL_image \
     libraries/SDL_mixer \
     libraries/SDL_net \
     libraries/SDL_ttf \
     libraries/speex \
     libraries/tiff \
     libraries/tinyxml \
     libraries/webp \
     libraries/x264 \
     libraries/yajl \
     libraries/zlib

ifeq ($(NACL_ARCH), pnacl)
DISABLED += libraries/Regal
endif

ifeq ($(NACL_ARCH), arm)
# Libraries that currently fail to build with ARM gcc.
# TODO(sbc): remove this conditional once this bug gets fixed:
# https://code.google.com/p/nativeclient/issues/detail?id=3205
DISABLED += \
     libraries/libtheora \
     libraries/ffmpeg
endif

ifneq ($(NACL_GLIBC), 1)
DISABLED += \
     libraries/SDL_net \
     libraries/glib \
     libraries/ncurses \
     libraries/pango
endif

ifeq ($(NACL_GLIBC), 1)
# TODO: Re-enable regal glibc build once the fix lands upstream
# to invoke create_nmf correctly.
DISABLED += libraries/glibc-compat \
     libraries/Regal
endif

ifneq ($(OS_NAME), Linux)
DISABLED += libraries/openssl
endif

EXAMPLES = \
     examples/games/scummvm \
     examples/systems/bochs \
     examples/systems/dosbox \
     examples/graphics/xaos \
     examples/games/nethack \
     examples/tools/thttpd \
     examples/games/snes9x \
     examples/audio/openal-ogg

ifeq ($(NACL_GLIBC), 1)
DISABLED += \
     examples/games/snes9x \
     examples/audio/openal-ogg
else
DISABLED += \
     examples/games/nethack \
     examples/tools/thttpd
endif

LIBRARIES := $(filter-out $(DISABLED),$(LIBRARIES))
EXAMPLES := $(filter-out $(DISABLED),$(EXAMPLES))
PACKAGES := $(LIBRARIES) $(EXAMPLES)

SENTINELS_DIR = $(NACL_OUT)/sentinels
ifeq ($(NACL_DEBUG), 1)
  SENT = $(SENTINELS_DIR)/$(NACL_ARCH)_$(NACL_LIBC)_debug
else
  SENT = $(SENTINELS_DIR)/$(NACL_ARCH)_$(NACL_LIBC)
endif

default: libraries
libraries: $(LIBRARIES)
examples: $(EXAMPLES)
all: $(PACKAGES)
# The subset of libraries that are shipped as part of the
# official NaCl SDK
SDK_LIBS = freealut freetype jpeg lua modplug ogg openal png theora tiff tinyxml
SDK_LIBS += vorbis webp xml2 zlib
sdklibs: $(SDK_LIBS)

package_list:
	@echo $(PACKAGES)

sdklibs_list:
	@echo $(SDK_LIBS)

run:
	./httpd.py

.PHONY: all run default libraries examples clean sdklibs sdklibs_list $(DISABLED)

clean:
	rm -rf $(NACL_DIRS_TO_REMOVE)

$(NACL_DIRS_TO_MAKE):
	mkdir -p $@

$(PACKAGES): %: $(NACL_DIRS_TO_MAKE) $(SENT)/%

ifdef NACLPORTS_NO_ANNOTATE
  START_BUILD=echo "*** Building $(NACL_ARCH) $(notdir $*) ***"
else
  START_BUILD=echo "@@@BUILD_STEP $(NACL_ARCH) $(NACL_LIBC) $(notdir $*)@@@"
endif

$(DISABLED):
	@echo "$@ is disabled for this configuration [NACL_LIBC=$(NACL_LIBC) NACL_ARCH=$(NACL_ARCH)]"

$(PACKAGES:%=$(SENT)/%): $(SENT)/%:
	@$(START_BUILD)
	cd $* && NACL_ARCH=$(NACL_ARCH) NACL_GLIBC=$(NACL_GLIBC) ./nacl-$(notdir $*).sh
	mkdir -p $(@D)
	touch $@

# packages with dependencies
$(SENT)/libraries/libvorbis: libraries/libogg
$(SENT)/libraries/libtheora: libraries/libogg
$(SENT)/libraries/flac: libraries/libogg
$(SENT)/libraries/speex: libraries/libogg
$(SENT)/libraries/fontconfig: libraries/expat \
    libraries/freetype
$(SENT)/libraries/libpng: libraries/zlib
$(SENT)/libraries/agg: libraries/freetype
$(SENT)/libraries/cairo: \
    libraries/pixman libraries/fontconfig libraries/libpng
$(SENT)/libraries/ffmpeg: \
    libraries/lame libraries/libvorbis libraries/libtheora
$(SENT)/examples/games/nethack: libraries/nacl-mounts
ifeq ($(NACL_GLIBC), 1)
  $(SENT)/examples/games/nethack: libraries/ncurses
endif
$(SENT)/examples/tools/thttpd: libraries/nacl-mounts \
    libraries/jsoncpp
$(SENT)/examples/games/scummvm: \
    libraries/nacl-mounts libraries/SDL libraries/libvorbis
$(SENT)/examples/systems/bochs: \
    libraries/nacl-mounts libraries/SDL
$(SENT)/examples/systems/dosbox: \
    libraries/nacl-mounts libraries/SDL libraries/zlib \
    libraries/libpng
$(SENT)/examples/games/snes9x: libraries/nacl-mounts
$(SENT)/libraries/glib: libraries/zlib
$(SENT)/libraries/pango: libraries/glib libraries/cairo
$(SENT)/libraries/SDL_mixer: libraries/SDL \
    libraries/libogg libraries/libvorbis libraries/libmikmod
$(SENT)/libraries/SDL_image: libraries/SDL \
    libraries/libpng libraries/jpeg
$(SENT)/libraries/SDL_net: libraries/SDL
$(SENT)/libraries/SDL_ttf: libraries/SDL \
    libraries/freetype
$(SENT)/libraries/boost: libraries/zlib libraries/bzip2
$(SENT)/libraries/freealut: libraries/openal-soft
$(SENT)/examples/audio/openal-ogg: \
    libraries/openal-soft libraries/libvorbis
$(SENT)/libraries/nacl-mounts: libraries/gtest
ifneq ($(NACL_GLIBC), 1)
  $(SENT)/libraries/openssl: libraries/glibc-compat
endif
$(SENT)/libraries/libmng: libraries/zlib libraries/jpeg
$(SENT)/libraries/lcms: libraries/zlib libraries/jpeg libraries/tiff
$(SENT)/libraries/DevIL: libraries/libpng libraries/jpeg libraries/libmng \
    libraries/tiff libraries/lcms
$(SENT)/libraries/physfs: libraries/zlib
$(SENT)/libraries/mpg123: libraries/openal-soft

# shortcuts libraries (alphabetical)
agg: libraries/agg ;
boost: libraries/boost ;
box2d: libraries/box2d ;
bzip2: libraries/bzip2 ;
cairo: libraries/cairo ;
cfitsio: libraries/cfitsio ;
DevIL: libraries/DevIL ;
expat: libraries/expat ;
faac: libraries/faac ;
faad: libraries/faad2 ;
ffmpeg: libraries/ffmpeg ;
fftw: libraries/fftw ;
flac: libraries/flac ;
fontconfig: libraries/fontconfig ;
freeimage: libraries/FreeImage ;
freetype: libraries/freetype ;
gc: libraries/gc ;
glib: libraries/glib ;
glibc-compat: libraries/glibc-compat ;
gtest: libraries/gtest ;
gsl: libraries/gsl ;
imagemagick: libraries/ImageMagick ;
jpeg: libraries/jpeg ;
jsoncpp: libraries/jsoncpp ;
lame: libraries/lame ;
lcms: libraries/lcms ;
lua: libraries/lua ;
mesa: libraries/Mesa ;
mikmod: libraries/libmikmod ;
mng: libraries/libmng ;
modplug: libraries/libmodplug ;
mpg123: libraries/mpg123 ;
nacl-mounts: libraries/nacl-mounts ;
ogg: libraries/libogg ;
openal: libraries/openal-soft ;
freealut: libraries/freealut ;
openscenegraph: libraries/OpenSceneGraph ;
openssl: libraries/openssl ;
pango: libraries/pango ;
physfs: libraries/physfs ;
pixman: libraries/pixman ;
png: libraries/libpng ;
webp: libraries/webp ;
protobuf: libraries/protobuf ;
sdl: libraries/SDL ;
sdl_image: libraries/SDL_image ;
sdl_mixer: libraries/SDL_mixer ;
sdl_net: libraries/SDL_net ;
sdl_ttf: libraries/SDL_ttf ;
speex: libraries/speex ;
theora: libraries/libtheora ;
tiff: libraries/tiff ;
regal: libraries/Regal ;
tinyxml: libraries/tinyxml ;
tomcrypt: libraries/libtomcrypt ;
tommath: libraries/libtommath ;
vorbis: libraries/libvorbis ;
x264: libraries/x264 ;
xml2: libraries/libxml2 ;
yajl: libraries/yajl ;
zlib: libraries/zlib ;
ncurses: libraries/ncurses ;

# shortcuts examples (alphabetical)
bochs: examples/systems/bochs ;
dosbox: examples/systems/dosbox ;
openal-ogg: examples/audio/openal-ogg ;
nethack: examples/games/nethack ;
scummvm: examples/games/scummvm ;
snes9x: examples/games/snes9x ;
xaos: examples/graphics/xaos ;
thttpd: examples/tools/thttpd ;
