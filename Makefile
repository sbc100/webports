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
ifeq ($(OS_NAME), Darwin)
   NACL_ARCH := i686
else
   NACL_ARCH := x86_64
endif
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
NACL_DIRS_TO_REMOVE = $(NACL_OUT)/sentinels $(NACL_OUT)/stamp $(NACL_OUT)/repository

ifneq ($(NACL_ARCH),pnacl)
# The toolchain's 'usr' folder is reserved for naclports and we
# remove it completely on clean.  Except under 'pnacl' where the
# toolchain itself uses 'usr' so we can't currenctly cleanup
# fully.
NACLPORTS_PREFIX ?= $(NACL_TOOLCHAIN_ROOT)/$(NACL_ARCH)-nacl/usr
NACL_DIRS_TO_REMOVE += $(NACLPORTS_PREFIX)
else
NACLPORTS_PREFIX ?= $(NACL_TOOLCHAIN_ROOT)/usr
endif

LIBRARIES = \
     libraries/agg \
     libraries/boost \
     libraries/box2d \
     libraries/bullet \
     libraries/bzip2 \
     libraries/cairo \
     libraries/cfitsio \
     libraries/curl \
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
     libraries/giflib \
     libraries/glib \
     libraries/glibc-compat \
     libraries/gsl \
     libraries/ImageMagick \
     libraries/jpeg \
     libraries/jsoncpp \
     libraries/lame \
     libraries/lcms \
     libraries/libav \
     libraries/libhangul \
     libraries/libmikmod \
     libraries/libmng \
     libraries/libmodplug \
     libraries/libogg \
     libraries/libpng \
     libraries/libtar \
     libraries/libtheora \
     libraries/libtomcrypt \
     libraries/libtommath \
     libraries/libvorbis \
     libraries/libxml2 \
     libraries/lua \
     libraries/metakit \
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
     libraries/python \
     libraries/readline \
     libraries/Regal \
     libraries/ruby \
     libraries/SDL \
     libraries/SDL_image \
     libraries/SDL_mixer \
     libraries/SDL_net \
     libraries/SDL_ttf \
     libraries/speex \
     libraries/sqlite \
     libraries/tiff \
     libraries/tinyxml \
     libraries/webp \
     libraries/x264 \
     libraries/yajl \
     libraries/zlib

EXAMPLES = \
     examples/audio/openal-ogg \
     examples/editors/nano \
     examples/editors/vim \
     examples/games/drod \
     examples/games/nethack \
     examples/games/scummvm \
     examples/games/snes9x \
     examples/graphics/mesagl \
     examples/graphics/xaos \
     examples/systems/bochs \
     examples/systems/dosbox \
     examples/tools/bash \
     examples/tools/civetweb \
     examples/tools/gdb \
     examples/tools/mongoose \
     examples/tools/lua_ppapi \
     examples/tools/python_ppapi \
     examples/tools/ruby_ppapi \
     examples/tools/thttpd

ALL_PACKAGES := $(LIBRARIES) $(EXAMPLES)
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
#SDK_LIBS = freealut freetype jpeg lua modplug ogg openal png theora tiff tinyxml
#SDK_LIBS += vorbis webp xml2 zlib
SDK_LIBS = lua
sdklibs: $(SDK_LIBS)

package_list:
	@echo $(notdir $(ALL_PACKAGES))

sdklibs_list:
	@echo $(SDK_LIBS)

run:
	./httpd.py

.PHONY: all run default libraries examples clean sdklibs sdklibs_list reallyclean

clean:
	rm -rf $(NACL_DIRS_TO_REMOVE)

reallyclean: clean
	rm -rf $(NACL_OUT)

ifdef PRINT_DEPS
# Defining PRINT_DEPS means that we don't actually build anything
# but only echo the names of the packages that would have been built.
# In this case we use a dummy sentinal directory which will always
# be empty.
SENT = $(NACL_OUT)/dummy_location
$(ALL_PACKAGES): %: $(SENT)/%
else
$(PACKAGES): %: $(SENT)/%
endif

ifdef NACLPORTS_NO_ANNOTATE
  START_BUILD=echo "*** Building $(NACL_ARCH) $(notdir $*) ***"
else
  START_BUILD=echo "@@@BUILD_STEP $(NACL_ARCH) $(NACL_LIBC) $(notdir $*)@@@"
endif

ifdef CLEAN
.PHONY: $(PACKAGES:%=$(SENT)/%)
$(PACKAGES:%=$(SENT)/%):
	@rm $@
else
ifdef PRINT_DEPS
$(ALL_PACKAGES:%=$(SENT)/%): $(SENT)/%:
	@echo $(notdir $(subst $(SENT)/,,$@))
else
$(PACKAGES:%=$(SENT)/%): $(SENT)/%:
	@$(START_BUILD)
	python build_tools/naclports.py check -C $*
	if python build_tools/naclports.py enabled -C $*; then \
	cd $* && NACL_ARCH=$(NACL_ARCH) NACL_GLIBC=$(NACL_GLIBC) ./build.sh; fi
	mkdir -p $(@D)
	touch $@
endif
endif

# packages with dependencies
$(SENT)/libraries/libvorbis: libraries/libogg
$(SENT)/libraries/libtheora: libraries/libogg
$(SENT)/libraries/flac: libraries/libogg
$(SENT)/libraries/speex: libraries/libogg
$(SENT)/libraries/fontconfig: libraries/expat libraries/freetype
$(SENT)/libraries/libtar: libraries/zlib
$(SENT)/libraries/libpng: libraries/zlib
$(SENT)/libraries/agg: libraries/freetype
$(SENT)/libraries/cairo: \
    libraries/pixman libraries/fontconfig libraries/libpng
$(SENT)/libraries/ffmpeg: \
    libraries/lame libraries/libvorbis libraries/libtheora \
    libraries/glibc-compat
$(SENT)/libraries/webp: libraries/tiff libraries/jpeg
$(SENT)/libraries/libav: libraries/lame libraries/libvorbis
$(SENT)/libraries/libtar: libraries/zlib
ifeq ($(LUA_NO_READLINE),)
$(SENT)/libraries/lua: libraries/readline
else
$(SENT)/libraries/lua: libraries/glibc-compat
endif
$(SENT)/libraries/python: libraries/readline libraries/zlib
$(SENT)/libraries/ruby: libraries/readline libraries/zlib
$(SENT)/libraries/sqlite: libraries/readline
$(SENT)/examples/games/nethack: libraries/ncurses libraries/libtar
$(SENT)/examples/tools/bash: libraries/ncurses libraries/libtar
$(SENT)/examples/editors/nano: libraries/ncurses libraries/libtar
$(SENT)/examples/editors/vim: libraries/ncurses libraries/libtar
$(SENT)/examples/tools/thttpd: libraries/jsoncpp
$(SENT)/examples/tools/python_ppapi: libraries/python libraries/libtar
$(SENT)/examples/tools/lua_ppapi: libraries/lua libraries/libtar
$(SENT)/examples/tools/ruby_ppapi: \
    libraries/ruby libraries/libtar libraries/glibc-compat
$(SENT)/examples/games/scummvm: libraries/SDL libraries/libvorbis \
    libraries/libtar
$(SENT)/examples/systems/bochs: \
    libraries/nacl-mounts libraries/SDL
$(SENT)/examples/systems/dosbox: \
    libraries/nacl-mounts libraries/SDL libraries/zlib \
    libraries/libpng
$(SENT)/examples/games/snes9x: libraries/nacl-mounts
$(SENT)/examples/games/drod: libraries/SDL libraries/SDL_mixer \
    libraries/SDL_ttf libraries/zlib libraries/metakit libraries/libtar \
    libraries/expat
$(SENT)/examples/graphics/mesagl: libraries/Mesa
$(SENT)/libraries/glib: libraries/zlib
$(SENT)/libraries/pango: libraries/glib libraries/cairo
$(SENT)/libraries/Regal: libraries/libpng
ifneq ($(NACL_ARCH), pnacl)
$(SENT)/libraries/SDL: libraries/Regal
endif
$(SENT)/libraries/SDL_mixer: libraries/SDL \
    libraries/libogg libraries/libvorbis libraries/libmikmod
$(SENT)/libraries/SDL_image: libraries/SDL \
    libraries/libpng libraries/jpeg
$(SENT)/libraries/SDL_net: libraries/SDL
$(SENT)/libraries/SDL_ttf: libraries/SDL libraries/freetype
$(SENT)/libraries/boost: libraries/zlib libraries/bzip2
$(SENT)/libraries/freealut: libraries/openal-soft
$(SENT)/examples/audio/openal-ogg: \
    libraries/openal-soft libraries/libvorbis
$(SENT)/libraries/readline: libraries/ncurses
ifneq ($(NACL_GLIBC), 1)
  $(SENT)/libraries/readline: libraries/glibc-compat
  $(SENT)/libraries/openssl: libraries/glibc-compat
  $(SENT)/libraries/ncurses: libraries/glibc-compat
endif
$(SENT)/libraries/libmng: libraries/zlib libraries/jpeg
$(SENT)/libraries/lcms: libraries/zlib libraries/jpeg libraries/tiff
$(SENT)/libraries/DevIL: libraries/libpng libraries/jpeg libraries/libmng \
    libraries/tiff libraries/lcms
$(SENT)/libraries/physfs: libraries/zlib
$(SENT)/libraries/mpg123: libraries/openal-soft
$(SENT)/libraries/ImageMagick: libraries/libpng libraries/jpeg \
    libraries/bzip2 libraries/zlib
$(SENT)/examples/tools/gdb: \
    libraries/ncurses libraries/expat libraries/readline

# shortcuts libraries (alphabetical)
agg: libraries/agg ;
boost: libraries/boost ;
box2d: libraries/box2d ;
bullet: libraries/bullet ;
bzip2: libraries/bzip2 ;
cairo: libraries/cairo ;
cfitsio: libraries/cfitsio ;
curl: libraries/curl ;
DevIL: libraries/DevIL ;
dreadthread: libraries/dreadthread ;
expat: libraries/expat ;
faac: libraries/faac ;
faad faad2: libraries/faad2 ;
ffmpeg: libraries/ffmpeg ;
fftw: libraries/fftw ;
flac: libraries/flac ;
fontconfig: libraries/fontconfig ;
freealut: libraries/freealut ;
freeimage FreeImage: libraries/FreeImage ;
freetype: libraries/freetype ;
gc: libraries/gc ;
gif giflib: libraries/giflib ;
glib: libraries/glib ;
glibc-compat: libraries/glibc-compat ;
gsl: libraries/gsl ;
hangul libhangul: libraries/libhangul ;
imagemagick ImageMagick: libraries/ImageMagick ;
jpeg: libraries/jpeg ;
jsoncpp: libraries/jsoncpp ;
lame: libraries/lame ;
lcms: libraries/lcms ;
libav: libraries/libav ;
lua: libraries/lua ;
mesa Mesa: libraries/Mesa ;
metakit: libraries/metakit ;
mikmod libmikmod: libraries/libmikmod ;
mng libmng: libraries/libmng ;
modplug libmodplug: libraries/libmodplug ;
mpg123: libraries/mpg123 ;
nacl-mounts: libraries/nacl-mounts ;
ncurses: libraries/ncurses ;
ogg libogg: libraries/libogg ;
openal openal-soft: libraries/openal-soft ;
openscenegraph OpenSceneGraph: libraries/OpenSceneGraph ;
openssl: libraries/openssl ;
pango: libraries/pango ;
physfs: libraries/physfs ;
pixman: libraries/pixman ;
png libpng: libraries/libpng ;
protobuf: libraries/protobuf ;
python: libraries/python ;
readline: libraries/readline ;
regal Regal: libraries/Regal ;
ruby: libraries/ruby ;
sdl SDL: libraries/SDL ;
sdl_image SDL_image: libraries/SDL_image ;
sdl_mixer SDL_mixer: libraries/SDL_mixer ;
sdl_net SDL_net: libraries/SDL_net ;
sdl_ttf SDL_ttf: libraries/SDL_ttf ;
speex: libraries/speex ;
sqlite: libraries/sqlite ;
tar libtar: libraries/libtar ;
theora libtheora: libraries/libtheora ;
tiff: libraries/tiff ;
tinyxml: libraries/tinyxml ;
tomcrypt libtomcrypt: libraries/libtomcrypt ;
tommath libtommath: libraries/libtommath ;
vorbis libvorbis: libraries/libvorbis ;
webp: libraries/webp ;
x264: libraries/x264 ;
xml2 libxml2: libraries/libxml2 ;
yajl: libraries/yajl ;
zlib: libraries/zlib ;

# shortcuts examples (alphabetical)
bash: examples/tools/bash ;
bochs: examples/systems/bochs ;
civetweb: examples/tools/civetweb ;
dosbox: examples/systems/dosbox ;
drod: examples/games/drod ;
gdb: examples/tools/gdb ;
git: examples/tools/git ;
mesagl: examples/graphics/mesagl ;
mongoose: examples/tools/mongoose ;
nano: examples/editors/nano ;
nethack: examples/games/nethack ;
openal-ogg: examples/audio/openal-ogg ;
lua_ppapi: examples/tools/lua_ppapi ;
python_ppapi: examples/tools/python_ppapi ;
ruby_ppapi: examples/tools/ruby_ppapi ;
scummvm: examples/games/scummvm ;
snes9x: examples/games/snes9x ;
thttpd: examples/tools/thttpd ;
# Deliberate space after vim target to avoid detection
# as modeline string.
vim : examples/editors/vim ;
xaos: examples/graphics/xaos ;
