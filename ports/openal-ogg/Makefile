# Copyright (c) 2011 The Native Client Authors. All rights reserved.
# Use of this source code is governed by a BSD-style license that can be
# found in the LICENSE file.
#
# Build OpenAL/ogg demo with Pepper in C

NACL_ARCH ?= x86_64
NACLCC ?= $(NACH_ARCH)-nacl-g++
NACLPORTS_ROOT ?= ../..
NACL_EXEEXT ?= ".nexe"
PUBLISH_DIR = $(NACLPORTS_ROOT)/out/publish/openal-ogg
CFLAGS += -O3 -std=gnu99 -Werror -I${NACL_SDK_ROOT}/include
LIBS += -lppapi -lopenal -lvorbisfile -lvorbis -logg -lm -lpthread

all: publish

BIN = openal_ogg_$(NACL_ARCH)$(NACL_EXEEXT)

$(BIN): openal_ogg.c ogg_buffer_reader.c
	$(NACLCC) -o $@ $^ $(CFLAGS) $(LDFLAGS) $(LIBS)

publish: $(BIN) index.html openal_ogg.nmf sample.ogg
	mkdir -p $(PUBLISH_DIR)
	cp $^ $(PUBLISH_DIR)

clean:
	rm -f *.o *$(NACL_EXEEXT)

run:
	cd $(PUBLISH_DIR) && $(NACL_SDK_ROOT)/tools/httpd.py --no_dir_check

.PHONY: all clean publish
