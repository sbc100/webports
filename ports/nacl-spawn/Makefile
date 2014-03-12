# Copyright (c) 2014 The Native Client Authors. All rights reserved.
# Use of this source code is governed by a BSD-style license that can be
# found in the LICENSE file.

# TODO(hamaji): include $NACL_SDK_ROOT/tools/common.mk.

NACL_SPAWN_OBJS=nacl_spawn.o path_util.o
# For now, we do not support spawning a new glibc process from newlib.
ifeq ($(TOOLCHAIN),glibc)
NACL_SPAWN_OBJS+=elf_reader.o library_dependencies.o
endif

TEST_EXES=test/elf_reader test/library_dependencies
TEST_BINARIES=test/test_exe test/libtest1.so test/libtest2.so test/libtest3.so

all: test

# Targets for libcli_main

libcli_main.a: cli_main.o
	-rm $@
	$(NACLAR) rcs $@ $^

cli_main.o: cli_main.c
	$(NACLCC) $(CFLAGS) -c $< -o $@

# Targets for libnacl_spawn

libnacl_spawn.so: $(NACL_SPAWN_OBJS)
	$(NACLCXX) $(LDFLAGS) -shared $^ -o $@

libnacl_spawn.a: $(NACL_SPAWN_OBJS)
	-rm $@
	$(NACLAR) rcs $@ $^

%.o: %.cc
	$(NACLCXX) $(CXXFLAGS) -c $< -o $@

# Targets for tests

test: $(TEST_EXES) $(TEST_BINARIES)
	./test/run_test.sh

test/elf_reader: elf_reader.cc
	$(NACLCXX) -DDEFINE_ELF_READER_MAIN $< -o $@
test/library_dependencies: elf_reader.o path_util.o library_dependencies.cc
	$(NACLCXX) -DDEFINE_LIBRARY_DEPENDENCIES_MAIN $^ -o $@

# We use -nostdlib not to have libc.so in their dependencies.
test/test_exe: test/test_exe.c test/libtest1.so test/libtest2.so
	$(NACLCC) $< -nostdlib -Wl,-rpath-link=test -Ltest -ltest1 -ltest2 -o $@
test/libtest1.so: test/libtest1.c test/libtest3.so
	$(NACLCC) $< -fPIC -nostdlib -shared -Ltest -ltest3 -o $@
test/libtest2.so: test/libtest2.c test/libtest3.so
	$(NACLCC) $< -fPIC -nostdlib -shared -Ltest -ltest3 -o $@
test/libtest3.so: test/libtest3.c
	$(NACLCC) $< -fPIC -nostdlib -shared -o $@

clean:
	rm -f *.a *.o *.so $(TEST_EXES) $(TEST_BINARIES)
