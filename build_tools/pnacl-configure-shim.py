#!/usr/bin/env python
# Copyright (c) 2014 The Native Client Authors. All rights reserved.
# Use of this source code is governed by a BSD-style license that can be
# found in the LICENSE file.

"""Autoconf builds lots of small executables.
This wreaks havock with pnacl's slow -O2 build time.
Additionally linking nacl_io + ppapi_simple slows things down even more.

This script is injected for CC to speed up configure by:
- When configuring:
  - Drop -O2 and -O3
  - Add -O0
  - Drop nacl_spawn + nacl_io and their dependencies.
- When configuring and using -Dmain=nacl_main + -lcli_main, drop them.

Determine if we're configuring and if -Dmain=nacl_main is passed.
"""

from __future__ import print_function

import subprocess
import sys

cmd = sys.argv[1:]
configuring = False
nacl_main = False
for arg in cmd:
  if arg == 'conftest.c':
    configuring = True
  if arg == '-Dmain=nacl_main':
    nacl_main = True

DROP_FLAGS = set([
    '-O2',
    '-O3',
    '-Dmain=nacl_main',
    '-lnacl_io',
    '-lnacl_spawn',
    '-lppapi_simple',
    '-lppapi_cpp',
    '-lppapi',
])

if configuring:
  cmd = [i for i in cmd if i not in DROP_FLAGS]
  if nacl_main:
    cmd = [i for i in cmd if i != '-lcli_main']
  cmd += ['-O0']

sys.exit(subprocess.call(cmd))
