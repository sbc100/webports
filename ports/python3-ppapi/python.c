/* Copyright (c) 2013 The Native Client Authors. All rights reserved.
 * Use of this source code is governed by a BSD-style license that can be
 * found in the LICENSE file. */

#include <Python.h>
#include <locale.h>
#include <stdio.h>
#include <stdlib.h>

#include "nacl_main.h"

#ifdef __arm__
#define DATA_FILE "_platform_specific/arm/pydata_arm.tar"
#elif defined __i386__
#define DATA_FILE "_platform_specific/x86_32/pydata_x86_32.tar"
#elif defined __x86_64__
#define DATA_FILE "_platform_specific/x86_64/pydata_x86_64.tar"
#elif defined __pnacl__
#define DATA_FILE "pydata_pnacl.tar"
#else
#error "Unknown arch"
#endif

int nacl_main(int argc, char **argv) {
    if (nacl_startup_untar(argv[0], DATA_FILE, "/"))
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
