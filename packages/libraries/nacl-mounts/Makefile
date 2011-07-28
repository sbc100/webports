# Copyright (c) 2011 The Native Client Authors. All rights reserved.
# Use of this source code is governed by a BSD-style license that can be
# found in the LICENSE file.
#
# A Makefile for running nacl-mounts tests
# usage: 'make all'
#        './tests_out/nacl_mounts_tests'

# location of gtest
GTEST_DIR = ../../../testing/gtest

CPPFLAGS += -I$(GTEST_DIR) -I$(GTEST_DIR)/include
CXXFLAGS += -g -Wall -Werror -lpthread -I$(GTEST_DIR)

# All gtest headers
GTEST_HEADERS = $(GTEST_DIR)/include/gtest/*.h \
                $(GTEST_DIR)/include/gtest/internal/*.h

UTIL_SOURCES = $(addprefix util/, Path.cc SimpleAutoLock.cc)
BASE_SOURCES = $(addprefix base/, MountManager.cc KernelProxy.cc)
MEM_SOURCES = $(addprefix memory/, MemMount.cc MemNode.cc)
TEST_SOURCES = $(addprefix test/, SlotAllocatorTest.cc \
            PathTest.cc BaseMountTest.cc MemMountTest.cc \
            MemNodeTest.cc MountManagerTest.cc KernelProxyTest.cc)

SOURCES = $(UTIL_SOURCES) $(BASE_SOURCES) $(MEM_SOURCES) $(TEST_SOURCES)
OBJECTS = $(SOURCES:.cc=.o)
TESTS_OUT = tests_out
OUTPUT = $(addprefix $(TESTS_OUT)/, base util test memory)

# House-keeping build targets
all: nacl_mounts_tests

clean: 
	rm -rf $(TESTS_OUT)

# gtest sources
GTEST_SRCS_ = $(GTEST_DIR)/src/*.cc $(GTEST_DIR)/src/*.h $(GTEST_HEADERS)

# gtest targets
gtest-all.o: $(GTEST_SRCS_)
	$(CXX) $(CPPFLAGS) $(CXXFLAGS) -c $(GTEST_DIR)/src/gtest-all.cc \
        -o $(TESTS_OUT)/$@

gtest_main.o: $(GTEST_SRCS_)
	$(CXX) $(CPPFLAGS) $(CXXFLAGS) -c $(GTEST_DIR)/src/gtest_main.cc \
        -o $(TESTS_OUT)/$@

gtest.a: gtest-all.o
	$(AR) $(ARFLAGS) $(addprefix $(TESTS_OUT)/, $@ /$^)

gtest_main.a: gtest-all.o gtest_main.o
	$(AR) $(ARFLAGS) $(addprefix $(TESTS_OUT)/, $@ $^)

# nacl-mounts targets for tests using gtest_main.a
$(OUTPUT):
	mkdir -p $@

%.o : %.cc $(OUTPUT)
	$(CXX) $(CPPFLAGS) $(CXXFLAGS) -c $< -o $(TESTS_OUT)/$@

nacl_mounts_tests: $(OBJECTS) gtest_main.a
	$(CXX) $(CPPFLAGS) $(CXXFLAGS) $(addprefix $(TESTS_OUT)/, $^) \
        -o $(TESTS_OUT)/$@