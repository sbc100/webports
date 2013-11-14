# Copyright (c) 2011 The Native Client Authors. All rights reserved.
# Use of this source code is governed by a BSD-style license that can be
# found in the LICENSE file.
#
# Build OpenAL/ogg demo with Pepper in C

NACL_ARCH ?= x86_64
NACLCC ?= $(NACL_ARCH)-nacl-gcc
NACLCXX ?= $(NACL_ARCH)-nacl-g++
NACLPORTS_ROOT ?= ../..
PUBLISH_DIR = $(NACLPORTS_ROOT)/out/publish/alut_hello_world
CFLAGS += -O3 -Werror -I$(NACL_SDK_ROOT)/include
CCFLAGS += -std=gnu99
LIBS += -lppapi_main -lnacl_mounts -lppapi -lppapi_cpp -lalut -lopenal -lvorbisfile -lvorbis -logg -lm
LDFLAGS += -L$(NACL_SDK_ROOT)/lib/newlib_$(NACL_ARCH)/Debug -pthread

all: publish

NEXE = $(PUBLISH_DIR)/alut_hello_world_$(NACL_ARCH)$(NACL_EXEEXT}

%.o: %.c
	$(NACLCC) -o $@ -c $< $(CFLAGS)

$(NEXE): alut_hello_world.o
	mkdir -p $(PUBLISH_DIR)
	$(NACLCXX) -o $@ $< $(CFLAGS) $(LDFLAGS) $(LIBS)

ASSETS = index.html alut_hello_world.nmf

publish: $(NEXE)
	cp $(ASSETS) $(PUBLISH_DIR)

clean:
	rm -f *.o $(NEXE)

run:
	cd $(PUBLISH_DIR) && $(NACL_SDK_ROOT)/tools/httpd.py --no_dir_check

.PHONY: clean publish all run
