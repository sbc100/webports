// Copyright (c) 2014 The Native Client Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

#include "library_dependencies.h"

#include <assert.h>
#include <errno.h>
#include <fcntl.h>
#include <stdio.h>
#include <stdlib.h>
#include <unistd.h>

#include <set>

#include "elf_reader.h"
#include "path_util.h"

static bool GetLibraryPaths(std::vector<std::string>* paths) {
  const char* path_env = getenv("LD_LIBRARY_PATH");
  GetPaths(path_env, paths);
  if (paths->empty()) {
    fprintf(stderr, "LD_LIBRARY_PATH is not set\n");
    errno = ENOENT;
    return false;
  }
  return true;
}

static bool FindLibraryDependenciesImpl(
  const std::string& filename,
  const std::vector<std::string>& paths,
  std::set<std::string>* dependencies) {
  if (!dependencies->insert(filename).second) {
    // We have already added this file.
    return true;
  }

  ElfReader elf_reader(filename.c_str());
  if (!elf_reader.is_valid()) {
    errno = ENOEXEC;
    return false;
  }

  if (elf_reader.is_static()) {
    assert(!dependencies->empty());
    if (dependencies->size() == 1) {
      // The main binary is statically linked.
      dependencies->clear();
      return true;
    } else {
      fprintf(stderr, "%s: unexpected static binary\n", filename.c_str());
      errno = ENOEXEC;
      return false;
    }
  }

  for (size_t i = 0; i < elf_reader.neededs().size(); i++) {
    const std::string& needed_name = elf_reader.neededs()[i];
    std::string needed_path;
    if (GetFileInPaths(needed_name, paths, &needed_path)) {
      if (!FindLibraryDependenciesImpl(needed_path, paths, dependencies))
        return false;
    } else {
      fprintf(stderr, "%s: library not found\n", needed_name.c_str());
      errno = ENOENT;
      return false;
    }
  }
  return true;
}

bool FindLibraryDependencies(const std::string& filename,
                             std::vector<std::string>* dependencies) {
  std::vector<std::string> paths;
  GetLibraryPaths(&paths);

  std::set<std::string> dep_set;
  if (!FindLibraryDependenciesImpl(filename.c_str(), paths, &dep_set))
    return false;
  dependencies->assign(dep_set.begin(), dep_set.end());

  // If we find any, also add runnable-ld.so, which we will also need.
  if (!dependencies->empty()) {
    std::string needed_path;
    if (GetFileInPaths("runnable-ld.so", paths, &needed_path)) {
      dependencies->push_back(needed_path);
    }
  }

  return true;
}

#if defined(DEFINE_LIBRARY_DEPENDENCIES_MAIN)

// When we run this under sel_ldr, we need to provide a valid
// definition of access.
#if defined(__native_client__)
int access(const char* pathname, int mode) {
  int fd = open(pathname, O_RDONLY);
  if (fd < 0)
    return -1;
  close(fd);
  return 0;
}
#endif

int main(int argc, char* argv[]) {
  if (argc < 2) {
    fprintf(stderr, "Usage: %s <elf>\n", argv[0]);
    return 1;
  }

  // For test.
  setenv("LD_LIBRARY_PATH", ".", 0);

  std::vector<std::string> dependencies;
  if (!FindLibraryDependencies(argv[1], &dependencies)) {
    perror("failed");
    return 1;
  }

  for (size_t i = 0; i < dependencies.size(); i++) {
    if (i)
      printf(" ");
    printf("%s", dependencies[i].c_str());
  }
}

#endif  // DEFINE_LIBRARY_DEPENDENCIES_MAIN
