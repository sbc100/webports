// Copyright (c) 2014 The Native Client Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

#ifndef NACL_SPAWN_ELF_READER_
#define NACL_SPAWN_ELF_READER_

#include <elf.h>
#include <stdio.h>

#include <string>
#include <vector>

// We cannot run 32bit NaCl binary on 64bit Chrome or vise versa, so
// we assume the input file is for the same CPU as this binary is
// built for.
#if defined(__x86_64__)
# define ElfW(type) Elf64_ ## type
# define ELF_MACHINE EM_X86_64
#else
# define ElfW(type) Elf32_ ## type
# if defined(__i686__)
#  define ELF_MACHINE EM_386
# elif defined(__arm__)
#  define ELF_MACHINE EM_ARM
# else
#  error "Unknown architecture"
# endif
#endif

// An ELF reader which extracts shared objects which are necessary to
// run the specified binary (DT_NEEDED). As no NaCl binary in the NaCl
// SDK does not have DT_RPATH and DT_RUNPATH (as of Jan. 2014), we do
// not support them.
class ElfReader {
 public:
  explicit ElfReader(const char* filename);

  bool is_valid() const { return is_valid_; }
  bool is_static() const { return is_static_; }
  const std::vector<std::string>& neededs() const { return neededs_; }

 private:
  bool ReadPhdrs(FILE* fp, std::vector<ElfW(Phdr)>* phdrs);
  bool ReadDynamic(FILE* fp, const std::vector<ElfW(Phdr)>& phdrs,
                   ElfW(Addr)* straddr, size_t* strsize,
                   std::vector<int>* neededs);
  bool ReadStrtab(FILE* fp, const std::vector<ElfW(Phdr)>& phdrs,
                  ElfW(Addr) straddr, size_t strsize,
                  std::string* strtab);
  void PrintError(const char* fmt, ...);

  const char* filename_;
  bool is_valid_;
  bool is_static_;
  std::vector<std::string> neededs_;
};

#endif  // NACL_SPAWN_ELF_READER_
