# Copyright (c) 2011 The Native Client Authors. All rights reserved.
# Use of this source code is governed by a BSD-style license that can be
# found in the LICENSE file.
#
# Build OpenAL/ogg demo with Pepper in C

NACLPORTS_ROOT ?= ../../..
PUBLISH_DIR = $(NACLPORTS_ROOT)/out/publish/openal-ogg
CFLAGS += -O3 -std=gnu99 -Werror -I${NACL_SDK_ROOT}/include
LIBS += -lppapi -lopenal -lvorbisfile -lvorbis -logg -lm -lpthread

all: publish

openal_ogg_$(NACL_ARCH).nexe: openal_ogg.c ogg_buffer_reader.c
	$(NACLCC) -o $@ $^ $(CFLAGS) $(LDFLAGS) $(LIBS)

publish: openal_ogg_$(NACL_ARCH).nexe openal_ogg.html openal_ogg.nmf sample.ogg
	mkdir -p $(PUBLISH_DIR)
	cp $^ $(PUBLISH_DIR)

clean:
	rm -f *.o *.nexe

