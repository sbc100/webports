/* Copyright (c) 2013 The Native Client Authors. All rights reserved.
 * Use of this source code is governed by a BSD-style license that can be
 * found in the LICENSE file. */

#include <Python.h>
#include <libtar.h>
#include <locale.h>
#include <stdio.h>
#include <fcntl.h>
#include <sys/mount.h>

#include "nacl_io/nacl_io.h"
#include "ppapi_simple/ps_main.h"

#ifdef __arm__
#define DATA_FILE "pydata_arm.tar"
#elif defined __i386__
#define DATA_FILE "pydata_x86_32.tar"
#elif defined __x86_64__
#define DATA_FILE "pydata_x86_64.tar"
#elif defined __pnacl__
#define DATA_FILE "pydata_pnacl.tar"
#else
#error "Unknown arch"
#endif

static int setup_unix_environment(const char* tarfile) {
  // Extra tar achive from http filesystem.
  if (tarfile) {
    int ret;
    TAR* tar;
    char filename[PATH_MAX];
    strcpy(filename, "/mnt/http/");
    strcat(filename, tarfile);
    ret = tar_open(&tar, filename, NULL, O_RDONLY, 0, 0);
    if (ret) {
      printf("error opening %s\n", filename);
      return 1;
    }

    ret = tar_extract_all(tar, "/");
    if (ret) {
      printf("error extracting %s\n", filename);
      return 1;
    }

    ret = tar_close(tar);
    assert(ret == 0);
  }

  // Setup environment variables
  setenv("HOME", "/home", 1);
  setenv("PATH", "/bin", 1);
  setenv("USER", "user", 1);
  setenv("LOGNAME", "user", 1);

  setlocale(LC_CTYPE, "");
  return 0;
}

int nacl_main(int argc, char **argv) {
    printf("Extracting: %s ...\n", DATA_FILE);
    if (setup_unix_environment(DATA_FILE))
        return -1;

    wchar_t **argv_copy;
    /* We need a second copy, as Python might modify the first one. */
    wchar_t **argv_copy2;
    int i, res;
    char *oldloc;
#ifdef __FreeBSD__
    fp_except_t m;
#endif

    argv_copy = (wchar_t **)PyMem_RawMalloc(sizeof(wchar_t*) * (argc+1));
    argv_copy2 = (wchar_t **)PyMem_RawMalloc(sizeof(wchar_t*) * (argc+1));
    if (!argv_copy || !argv_copy2) {
        fprintf(stderr, "out of memory\n");
        return 1;
    }

    /* 754 requires that FP exceptions run in "no stop" mode by default,
     * and until C vendors implement C99's ways to control FP exceptions,
     * Python requires non-stop mode.  Alas, some platforms enable FP
     * exceptions by default.  Here we disable them.
     */
#ifdef __FreeBSD__
    m = fpgetmask();
    fpsetmask(m & ~FP_X_OFL);
#endif

    oldloc = _PyMem_RawStrdup(setlocale(LC_ALL, NULL));
    if (!oldloc) {
        fprintf(stderr, "out of memory\n");
        return 1;
    }

    setlocale(LC_ALL, "");
    for (i = 0; i < argc; i++) {
        argv_copy[i] = _Py_char2wchar(argv[i], NULL);
        if (!argv_copy[i]) {
            PyMem_RawFree(oldloc);
            fprintf(stderr, "Fatal Python error: "
                            "unable to decode the command line argument #%i\n",
                            i + 1);
            return 1;
        }
        argv_copy2[i] = argv_copy[i];
    }
    argv_copy2[argc] = argv_copy[argc] = NULL;

    setlocale(LC_ALL, oldloc);
    PyMem_RawFree(oldloc);
    res = Py_Main(argc, argv_copy);
    for (i = 0; i < argc; i++) {
        PyMem_RawFree(argv_copy2[i]);
    }
    PyMem_RawFree(argv_copy);
    PyMem_RawFree(argv_copy2);
    return res;
}
