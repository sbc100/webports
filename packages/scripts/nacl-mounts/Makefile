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

# Output directory
TESTS_OUT = tests_out

# House-keeping build targets
all: output nacl_mounts_tests

clean:
	rm -rf $(TESTS_OUT)

# gtest sources
GTEST_SRCS_ = $(GTEST_DIR)/src/*.cc $(GTEST_DIR)/src/*.h $(GTEST_HEADERS)

# gtest targets
$(TESTS_OUT)/gtest-all.o: $(GTEST_SRCS_)
	$(CXX) $(CPPFLAGS) $(CXXFLAGS) -c $(GTEST_DIR)/src/gtest-all.cc -o $@

$(TESTS_OUT)/gtest_main.o: $(GTEST_SRCS_)
	$(CXX) $(CPPFLAGS) $(CXXFLAGS) -c $(GTEST_DIR)/src/gtest_main.cc -o $@

$(TESTS_OUT)/gtest.a: $(TESTS_OUT)/gtest-all.o
	$(AR) $(ARFLAGS) $@ $^

$(TESTS_OUT)/gtest_main.a: $(TESTS_OUT)/gtest-all.o $(TESTS_OUT)/gtest_main.o
	$(AR) $(ARFLAGS) $@ $^

# nacl-mounts targets for tests using gtest_main.a
$(TESTS_OUT)/PathTest.o: PathTest.cc $(GTEST_HEADERS)
	$(CXX) $(CPPFLAGS) $(CXXFLAGS) -c PathTest.cc -o $@

$(TESTS_OUT)/Path.o: Path.cc Path.h
	$(CXX) $(CPPFLAGS) $(CXXFLAGS) -c Path.cc -o $@

$(TESTS_OUT)/SlotAllocatorTest.o: SlotAllocatorTest.cc $(GTEST_HEADERS)
	$(CXX) $(CPPFLAGS) $(CXXFLAGS) -c SlotAllocatorTest.cc -o $@

output:
	test -d $(TESTS_OUT) || mkdir $(TESTS_OUT)

nacl_mounts_tests: $(TESTS_OUT)/Path.o $(TESTS_OUT)/PathTest.o \
          $(TESTS_OUT)/SlotAllocatorTest.o $(TESTS_OUT)/gtest_main.a
	$(CXX) $(CPPFLAGS) $(CXXFLAGS) $^ -o $(TESTS_OUT)/$@