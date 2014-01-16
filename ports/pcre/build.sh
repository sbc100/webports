#!/bin/bash
# Copyright (c) 2013 The Native Client Authors. All rights reserved.
# Use of this source code is governed by a BSD-style license that can be
# found in the LICENSE file.

# There are two additional tests (RunGrepTest and RunTest shell scripts) that
# make check does but it would be hard to run it here. Especially the first one.
TestStep() {
  # test only pnacl and if target and host architectures match
  if [ "${NACL_ARCH}" = "pnacl" ]; then
    for test in pcre_scanner_unittest.* pcre_stringpiece_unittest.* pcrecpp_unittest.*; do
        RunSelLdrCommand ${test}
    done
    echo "Tests OK"
  elif [ `uname -m` == "${NACL_ARCH_ALT}" ]; then
    for test in pcre_scanner_unittest.* pcre_stringpiece_unittest.* pcrecpp_unittest.*; do
        # use the binary in .libs instead if there is any
        if [ -e .libs/${test} ]; then
          (cd .libs;
            WriteSelLdrScript run_${test} ${test};
            ./run_${test})
        else
          WriteSelLdrScript run_${test} ${test}
          ./run_${test}
        fi
    done
    echo "Tests OK"
  fi
}
