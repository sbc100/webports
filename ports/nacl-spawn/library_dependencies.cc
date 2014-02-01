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

static bool GetLibraryPaths(std::vector<std::string>* paths) {
  const char* path_env = getenv("LD_LIBRARY_PATH");
  if (!path_env || !*path_env) {
    fprintf(stderr, "LD_LIBRARY_PATH is not set\n");
    errno = ENOENT;
    return false;
  }

  for (const char* p = path_env; *p; p++) {
    if (*p == ':') {
      if (p == path_env)
        paths->push_back(".");
      else
        paths->push_back(std::string(path_env, p));
      path_env = p + 1;
    }
  }
  paths->push_back(path_env);
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
    bool found = false;
    for (size_t j = 0; j < paths.size(); j++) {
      const std::string needed_path = paths[j] + '/' + needed_name;
      if (access(needed_path.c_str(), R_OK) == 0) {
        if (!FindLibraryDependenciesImpl(needed_path, paths, dependencies))
          return false;
        found = true;
        break;
      }
    }

    if (!found) {
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
  if (!getenv("LD_LIBRARY_PATH"))
    setenv("LD_LIBRARY_PATH", ".", 1);

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
