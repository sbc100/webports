# Copyright (c) 2012 The Native Client Authors. All rights reserved.
# Use of this source code is governed by a BSD-style license that can be
# found in the LICENSE file.
#
# A Makefile for building sel_ldr-based nacl-mounts tests

SRC_DIR = $(dir $(lastword $(MAKEFILE_LIST)))

CFLAGS += -I/usr/local/google/home/vissi/oogle/naclports/src/libraries/nacl-mounts -I/usr/local/google/home/vissi/oogle/naclports/src/libraries/nacl-mounts/include -g -Wall -Werror

TEST_SOURCES = \
  SimpleTest.cc \
  DevTest.cc \
  test_main.cc

SOURCES = $(TEST_SOURCES)
OBJECTS = $(SOURCES:.cc=.o)

.PHONY: all
all: nacl_mounts_sel_ldr_tests


%.o: $(SRC_DIR)/%.cc
	$(CXX) $(CFLAGS) -c $< -o $@

nacl_mounts_sel_ldr_tests: $(OBJECTS)
	$(CXX) $(LDFLAGS) $^ -o $@ -lgtest -lnacl-mounts -lpthread
