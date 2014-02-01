// Copyright (c) 2014 The Native Client Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

#include "elf_reader.h"

#include <assert.h>
#include <elf.h>
#include <errno.h>
#include <stdarg.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>

#include <string>
#include <vector>

class ScopedFile {
 public:
  explicit ScopedFile(FILE* fp) : fp_(fp) {}
  ~ScopedFile() {
    if (fp_)
      fclose(fp_);
  }

  FILE* get() { return fp_; }

 private:
  FILE* fp_;
};

ElfReader::ElfReader(const char* filename)
    : filename_(filename), is_valid_(false), is_static_(false) {
  ScopedFile fp(fopen(filename, "rb"));
  if (!fp.get()) {
    PrintError("failed to open file");
    return;
  }

  std::vector<ElfW(Phdr)> phdrs;
  if (!ReadPhdrs(fp.get(), &phdrs))
    return;

  bool dynamic_found = false;
  ElfW(Addr) straddr = 0;
  size_t strsize = 0;
  std::vector<int> neededs;
  if (!ReadDynamic(fp.get(), phdrs, &straddr, &strsize, &neededs))
    return;

  std::string strtab;
  if (!ReadStrtab(fp.get(), phdrs, straddr, strsize, &strtab))
    return;

  for (size_t i = 0; i < neededs.size(); i++)
    neededs_.push_back(strtab.data() + neededs[i]);

  is_valid_= true;
}

bool ElfReader::ReadPhdrs(FILE* fp, std::vector<ElfW(Phdr)>* phdrs) {
  ElfW(Ehdr) ehdr;
  if (fread(&ehdr, sizeof(ehdr), 1, fp) != 1) {
    PrintError("failed to read ELF header");
    return false;
  }

  if (memcmp(ELFMAG, ehdr.e_ident, SELFMAG)) {
    PrintError("invalid ELF header");
    return false;
  }

  if (ehdr.e_machine != ELF_MACHINE) {
    PrintError("unsupported architecture: e_machine=%d", ehdr.e_machine);
    return false;
  }

  if (fseek(fp, ehdr.e_phoff, SEEK_SET) < 0) {
    PrintError("failed to seek to program header");
    return false;
  }

  for (int i = 0; i < ehdr.e_phnum; i++) {
    ElfW(Phdr) phdr;
    if (fread(&phdr, sizeof(phdr), 1, fp) != 1) {
      PrintError("failed to read a program header %d", i);
      return false;
    }
    phdrs->push_back(phdr);
  }
  return true;
}

bool ElfReader::ReadDynamic(FILE* fp, const std::vector<ElfW(Phdr)>& phdrs,
                            ElfW(Addr)* straddr, size_t* strsize,
                            std::vector<int>* neededs) {
  bool dynamic_found = false;
  for (size_t i = 0; i < phdrs.size(); i++) {
    const ElfW(Phdr)& phdr = phdrs[i];
    if (phdr.p_type != PT_DYNAMIC)
      continue;

    // NaCl glibc toolchain creates a dynamic segment with no contents
    // for statically linked binaries.
    if (phdr.p_filesz == 0) {
      PrintError("dynamic segment without no content");
      return false;
    }

    dynamic_found = true;

    if (fseek(fp, phdr.p_offset, SEEK_SET) < 0) {
      PrintError("failed to seek to dynamic segment");
      return false;
    }

    for (;;) {
      ElfW(Dyn) dyn;
      if (fread(&dyn, sizeof(dyn), 1, fp) != 1) {
        PrintError("failed to read a dynamic entry");
        return false;
      }

      if (dyn.d_tag == DT_NULL)
        break;
      if (dyn.d_tag == DT_STRTAB)
        *straddr = dyn.d_un.d_ptr;
      else if (dyn.d_tag == DT_STRSZ)
        *strsize = dyn.d_un.d_val;
      else if (dyn.d_tag == DT_NEEDED)
        neededs->push_back(dyn.d_un.d_val);
    }
  }

  if (!dynamic_found) {
    is_valid_ = true;
    is_static_ = true;
    return false;
  }
  if (!strsize) {
    PrintError("DT_STRSZ does not exist");
    return false;
  }
  if (!straddr) {
    PrintError("DT_STRTAB does not exist");
    return false;
  }
  return true;
}

bool ElfReader::ReadStrtab(FILE* fp, const std::vector<ElfW(Phdr)>& phdrs,
                           ElfW(Addr) straddr, size_t strsize,
                           std::string* strtab) {
  // DT_STRTAB is specified by a pointer to a virtual address
  // space. We need to convert this value to a file offset. To do
  // this, we find a PT_LOAD segment which contains the address.
  ElfW(Addr) stroff = 0;
  for (size_t i = 0; i < phdrs.size(); i++) {
    const ElfW(Phdr)& phdr = phdrs[i];
    if (phdr.p_type == PT_LOAD &&
        phdr.p_vaddr <= straddr && straddr < phdr.p_vaddr + phdr.p_filesz) {
      stroff = straddr - phdr.p_vaddr + phdr.p_offset;
      break;
    }
  }
  if (!stroff) {
    PrintError("no segment which contains DT_STRTAB");
    return false;
  }

  strtab->resize(strsize);
  if (fseek(fp, stroff, SEEK_SET) < 0) {
    PrintError("failed to seek to dynamic strtab");
    return false;
  }
  if (fread(&(*strtab)[0], 1, strsize, fp) != strsize) {
    PrintError("failed to read dynamic strtab");
    return false;
  }
  return true;
}

void ElfReader::PrintError(const char* fmt, ...) {
  static const int kBufSize = 256;
  char buf[kBufSize];
  va_list ap;
  va_start(ap, fmt);
  int written = vsnprintf(buf, kBufSize - 1, fmt, ap);
  assert(written < kBufSize);

  if (errno)
    fprintf(stderr, "%s: %s: %s\n", filename_, buf, strerror(errno));
  else
    fprintf(stderr, "%s: %s\n", filename_, buf);
}

#if defined(DEFINE_ELF_READER_MAIN)

int main(int argc, char* argv[]) {
  if (argc < 2) {
    fprintf(stderr, "Usage: %s <elf>\n", argv[0]);
    return 1;
  }

  // For test.
  if (!getenv("LD_LIBRARY_PATH"))
    setenv("LD_LIBRARY_PATH", ".", 1);

  ElfReader elf_reader(argv[1]);
  if (!elf_reader.is_valid())
    return 1;

  for (size_t i = 0; i < elf_reader.neededs().size(); i++) {
    if (i)
      printf(" ");
    printf("%s", elf_reader.neededs()[i].c_str());
  }
}

#endif  // DEFINE_ELF_READER_MAIN
