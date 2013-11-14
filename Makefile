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
     ports/agg \
     ports/boost \
     ports/box2d \
     ports/bullet \
     ports/bzip2 \
     ports/cairo \
     ports/cfitsio \
     ports/curl \
     ports/DevIL \
     ports/dreadthread \
     ports/expat \
     ports/faac \
     ports/faad2 \
     ports/ffmpeg \
     ports/fftw \
     ports/flac \
     ports/fontconfig \
     ports/freealut \
     ports/FreeImage \
     ports/freetype \
     ports/gc \
     ports/giflib \
     ports/glib \
     ports/glibc-compat \
     ports/gsl \
     ports/ImageMagick \
     ports/jpeg6b \
     ports/jpeg8d \
     ports/jsoncpp \
     ports/lame \
     ports/lcms \
     ports/libav \
     ports/libhangul \
     ports/libmikmod \
     ports/libmng \
     ports/libmodplug \
     ports/libogg \
     ports/libpng \
     ports/libtar \
     ports/libtheora \
     ports/libtomcrypt \
     ports/libtommath \
     ports/libvorbis \
     ports/libxml2 \
     ports/lua5.1 \
     ports/lua5.2 \
     ports/metakit \
     ports/Mesa \
     ports/mpg123 \
     ports/nacl-mounts \
     ports/ncurses \
     ports/openal-soft \
     ports/OpenSceneGraph \
     ports/openssl \
     ports/pango \
     ports/physfs \
     ports/pixman \
     ports/protobuf \
     ports/python \
     ports/readline \
     ports/Regal \
     ports/ruby \
     ports/SDL \
     ports/SDL_image \
     ports/SDL_mixer \
     ports/SDL_net \
     ports/SDL_ttf \
     ports/speex \
     ports/sqlite \
     ports/tiff \
     ports/tinyxml \
     ports/webp \
     ports/x264 \
     ports/yajl \
     ports/zlib

EXAMPLES = \
     ports/bash \
     ports/bochs \
     ports/civetweb \
     ports/dosbox \
     ports/drod \
     ports/gdb \
     ports/lua_ppapi \
     ports/mesagl \
     ports/mongoose \
     ports/nano \
     ports/nethack \
     ports/openal-ogg \
     ports/openssh \
     ports/python_ppapi \
     ports/ruby_ppapi \
     ports/scummvm \
     ports/snes9x \
     ports/thttpd \
     ports/vim \
     ports/xaos \

ALL_PACKAGES := $(LIBRARIES) $(EXAMPLES)
PACKAGES := $(LIBRARIES) $(EXAMPLES)

SENTINELS_DIR = $(NACL_OUT)/sentinels
SENT := $(SENTINELS_DIR)/$(NACL_ARCH)
ifneq ($(NACL_ARCH), pnacl)
  SENT := $(SENT)_$(NACL_LIBC)
endif
ifeq ($(NACL_DEBUG), 1)
  SENT := $(SENT)_debug
endif

default: libraries
libraries: $(LIBRARIES)
examples: $(EXAMPLES)
all: $(PACKAGES)
# The subset of libraries that are shipped as part of the
# official NaCl SDK
SDK_LIBS = freealut freetype jpeg lua5.2 modplug ogg openal png theora tiff tinyxml
SDK_LIBS += vorbis webp xml2 zlib
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
$(SENT)/ports/libvorbis: ports/libogg
$(SENT)/ports/libtheora: ports/libogg
$(SENT)/ports/flac: ports/libogg
$(SENT)/ports/speex: ports/libogg
$(SENT)/ports/fontconfig: ports/expat ports/freetype
$(SENT)/ports/libtar: ports/zlib
$(SENT)/ports/libpng: ports/zlib
$(SENT)/ports/agg: ports/freetype
$(SENT)/ports/cairo: ports/pixman ports/fontconfig ports/libpng
$(SENT)/ports/ffmpeg: ports/lame ports/libvorbis ports/libtheora \
    ports/glibc-compat
$(SENT)/ports/webp: ports/tiff ports/jpeg8d
$(SENT)/ports/libav: ports/lame ports/libvorbis
$(SENT)/ports/libtar: ports/zlib
ifeq ($(LUA_NO_READLINE),)
$(SENT)/ports/lua5.1: ports/readline
$(SENT)/ports/lua5.2: ports/readline
endif
$(SENT)/ports/python: ports/readline ports/zlib
$(SENT)/ports/ruby: ports/readline ports/zlib
$(SENT)/ports/sqlite: ports/readline
$(SENT)/ports/nethack: ports/ncurses ports/libtar
$(SENT)/ports/bash: ports/ncurses ports/libtar
$(SENT)/ports/nano: ports/ncurses ports/libtar
$(SENT)/ports/vim: ports/ncurses ports/libtar
$(SENT)/ports/thttpd: ports/jsoncpp
$(SENT)/ports/openssh: ports/zlib ports/openssl ports/jsoncpp
$(SENT)/ports/python_ppapi: ports/python ports/libtar
$(SENT)/ports/lua_ppapi: ports/lua5.2 ports/libtar
$(SENT)/ports/ruby_ppapi: ports/ruby ports/libtar ports/glibc-compat
$(SENT)/ports/scummvm: ports/SDL ports/libvorbis ports/libtar
$(SENT)/ports/bochs: ports/nacl-mounts ports/SDL
$(SENT)/ports/dosbox: ports/nacl-mounts ports/SDL ports/zlib ports/libpng
$(SENT)/ports/snes9x: ports/nacl-mounts
$(SENT)/ports/drod: ports/SDL ports/SDL_mixer ports/SDL_ttf ports/zlib \
    ports/metakit ports/libtar ports/expat
$(SENT)/ports/mesagl: ports/Mesa
$(SENT)/ports/glib: ports/zlib
$(SENT)/ports/pango: ports/glib ports/cairo
$(SENT)/ports/Regal: ports/libpng
ifneq ($(NACL_ARCH), pnacl)
$(SENT)/ports/SDL: ports/Regal
endif
$(SENT)/ports/SDL_mixer: ports/SDL ports/libogg ports/libvorbis ports/libmikmod
$(SENT)/ports/SDL_image: ports/SDL ports/libpng ports/jpeg8d
$(SENT)/ports/SDL_net: ports/SDL
$(SENT)/ports/SDL_ttf: ports/SDL ports/freetype
$(SENT)/ports/boost: ports/zlib ports/bzip2
$(SENT)/ports/freealut: ports/openal-soft
$(SENT)/ports/openal-ogg: ports/openal-soft ports/libvorbis
$(SENT)/ports/readline: ports/ncurses
ifneq ($(NACL_GLIBC), 1)
  $(SENT)/ports/readline: ports/glibc-compat
  $(SENT)/ports/openssl: ports/glibc-compat
  $(SENT)/ports/ncurses: ports/glibc-compat
endif
$(SENT)/ports/libmng: ports/zlib ports/jpeg8d
$(SENT)/ports/lcms: ports/zlib ports/jpeg8d ports/tiff
$(SENT)/ports/DevIL: ports/libpng ports/jpeg8d ports/libmng ports/tiff \
    ports/lcms
$(SENT)/ports/physfs: ports/zlib
$(SENT)/ports/mpg123: ports/openal-soft
$(SENT)/ports/ImageMagick: ports/libpng ports/jpeg8d ports/bzip2 ports/zlib
$(SENT)/ports/gdb: ports/ncurses ports/expat ports/readline

# shortcuts libraries (alphabetical)
agg: ports/agg ;
boost: ports/boost ;
box2d: ports/box2d ;
bullet: ports/bullet ;
bzip2: ports/bzip2 ;
cairo: ports/cairo ;
cfitsio: ports/cfitsio ;
curl: ports/curl ;
DevIL: ports/DevIL ;
dreadthread: ports/dreadthread ;
expat: ports/expat ;
faac: ports/faac ;
faad faad2: ports/faad2 ;
ffmpeg: ports/ffmpeg ;
fftw: ports/fftw ;
flac: ports/flac ;
fontconfig: ports/fontconfig ;
freealut: ports/freealut ;
freeimage FreeImage: ports/FreeImage ;
freetype: ports/freetype ;
gc: ports/gc ;
gif giflib: ports/giflib ;
glib: ports/glib ;
glibc-compat: ports/glibc-compat ;
gsl: ports/gsl ;
hangul libhangul: ports/libhangul ;
imagemagick ImageMagick: ports/ImageMagick ;
jpeg jpeg8d: ports/jpeg8d ;
jpeg6b: ports/jpeg6b ;
jsoncpp: ports/jsoncpp ;
lame: ports/lame ;
lcms: ports/lcms ;
libav: ports/libav ;
lua5.1: ports/lua5.1 ;
lua5.2: ports/lua5.2 ;
lua: ports/lua5.2 ;
mesa Mesa: ports/Mesa ;
metakit: ports/metakit ;
mikmod libmikmod: ports/libmikmod ;
mng libmng: ports/libmng ;
modplug libmodplug: ports/libmodplug ;
mpg123: ports/mpg123 ;
nacl-mounts: ports/nacl-mounts ;
ncurses: ports/ncurses ;
ogg libogg: ports/libogg ;
openal openal-soft: ports/openal-soft ;
openscenegraph OpenSceneGraph: ports/OpenSceneGraph ;
openssl: ports/openssl ;
pango: ports/pango ;
physfs: ports/physfs ;
pixman: ports/pixman ;
png libpng: ports/libpng ;
protobuf: ports/protobuf ;
python: ports/python ;
readline: ports/readline ;
regal Regal: ports/Regal ;
ruby: ports/ruby ;
sdl SDL: ports/SDL ;
sdl_image SDL_image: ports/SDL_image ;
sdl_mixer SDL_mixer: ports/SDL_mixer ;
sdl_net SDL_net: ports/SDL_net ;
sdl_ttf SDL_ttf: ports/SDL_ttf ;
speex: ports/speex ;
sqlite: ports/sqlite ;
tar libtar: ports/libtar ;
theora libtheora: ports/libtheora ;
tiff: ports/tiff ;
tinyxml: ports/tinyxml ;
tomcrypt libtomcrypt: ports/libtomcrypt ;
tommath libtommath: ports/libtommath ;
vorbis libvorbis: ports/libvorbis ;
webp: ports/webp ;
x264: ports/x264 ;
xml2 libxml2: ports/libxml2 ;
yajl: ports/yajl ;
zlib: ports/zlib ;

# shortcuts examples (alphabetical)
bash: ports/bash ;
bochs: ports/bochs ;
civetweb: ports/civetweb ;
dosbox: ports/dosbox ;
drod: ports/drod ;
gdb: ports/gdb ;
git: ports/git ;
mesagl: ports/mesagl ;
mongoose: ports/mongoose ;
nano: ports/nano ;
nethack: ports/nethack ;
openal-ogg: ports/openal-ogg ;
lua_ppapi: ports/lua_ppapi ;
python_ppapi: ports/python_ppapi ;
ruby_ppapi: ports/ruby_ppapi ;
scummvm: ports/scummvm ;
snes9x: ports/snes9x ;
thttpd: ports/thttpd ;
openssh: ports/openssh ;
# Deliberate space after vim target to avoid detection
# as modeline string.
vim : ports/vim ;
xaos: ports/xaos ;
