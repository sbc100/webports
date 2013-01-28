# Copyright (c) 2011 The Native Client Authors. All rights reserved.
# Use of this source code is governed by a BSD-style license that can be
# found in the LICENSE file.
#
# A Makefile for running nacl-mounts tests
# usage: 'make all'
#        './tests_out/nacl_mounts_tests'

# location of gtest
GTEST_DIR = ../../testing/gtest

CXXFLAGS += -pthread -g -Wall -Werror

# All gtest headers
GTEST_HEADERS = $(GTEST_DIR)/include/gtest/*.h \
                $(GTEST_DIR)/include/gtest/internal/*.h

# Add root of nacl-mounts to the include path
CPPFLAGS += -I. -I$(GTEST_DIR)

UTIL_SOURCES = $(addprefix util/, Path.cc)
BASE_SOURCES = $(addprefix base/, MountManager.cc KernelProxy.cc \
                 MainThreadRunner.cc)
MEM_SOURCES = $(addprefix memory/, MemMount.cc MemNode.cc)
CONSOLE_SOURCES = $(addprefix console/, ConsoleMount.cc JSPipeMount.cc)
BUFFER_SOURCES = $(addprefix buffer/, BufferMount.cc)
DEV_SOURCES = $(addprefix dev/, DevMount.cc RandomDevice.cc NullDevice.cc)
TEST_SOURCES = $(addprefix test/, SlotAllocatorTest.cc \
                 PathTest.cc BaseMountTest.cc MemMountTest.cc \
                 MemNodeTest.cc MountManagerTest.cc KernelProxyTest.cc \
                 JSPipeMountTest.cc MainThreadRunnerTest.cc \
                 DevMountTest.cc BufferMountTest.cc MockMount.cc)

SOURCES = $(UTIL_SOURCES) $(BASE_SOURCES) $(MEM_SOURCES) \
          $(CONSOLE_SOURCES) $(BUFFER_SOURCES) $(DEV_SOURCES) $(TEST_SOURCES)
TESTS_OUT = tests_out
OBJECTS = $(addprefix $(TESTS_OUT)/, $(SOURCES:.cc=.o))
OUTPUT = $(addprefix $(TESTS_OUT)/, base buffer util test memory console)

# House-keeping build targets
all: $(TESTS_OUT)/nacl_mounts_tests

clean:
	rm -rf $(TESTS_OUT)

# gtest sources
GTEST_SRCS_ = $(GTEST_DIR)/src/*.cc $(GTEST_DIR)/src/*.h $(GTEST_HEADERS)

# gtest targets
$(TESTS_OUT)/gtest-all.o: $(GTEST_SRCS_)
	mkdir -p $(dir $@)
	$(CXX) $(CPPFLAGS) $(CXXFLAGS) -c $(GTEST_DIR)/src/gtest-all.cc -o $@

$(TESTS_OUT)/gtest_main.o: $(GTEST_SRCS_)
	mkdir -p $(dir $@)
	$(CXX) $(CPPFLAGS) $(CXXFLAGS) -c $(GTEST_DIR)/src/gtest_main.cc -o $@

$(TESTS_OUT)/gtest.a: $(TESTS_OUT)/gtest-all.o
	mkdir -p $(dir $@)
	$(AR) $(ARFLAGS) $@ $^

$(TESTS_OUT)/gtest_main.a: $(TESTS_OUT)/gtest-all.o $(TESTS_OUT)/gtest_main.o
	mkdir -p $(dir $@)
	$(AR) $(ARFLAGS) $@ $^

$(TESTS_OUT)/%.o: %.cc
	mkdir -p $(dir $@)
	$(CXX) $(CPPFLAGS) $(CXXFLAGS) -c $< -o $@

$(TESTS_OUT)/nacl_mounts_tests: $(OBJECTS) $(TESTS_OUT)/gtest_main.a
	mkdir -p $(dir $@)
	$(CXX) $(CPPFLAGS) $(CXXFLAGS) -lpthread $^ -o $@
