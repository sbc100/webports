#!/usr/bin/env python
# Copyright (c) 2016 The Native Client Authors. All rights reserved.
# Use of this source code is governed by a BSD-style license that can be
# found in the LICENSE file.

"""Compiler wrapper for injecting extra libs at the end of the link
line.

This is used rather than just setting LDFLAGS/LIBS becuase setting
LIBS/LDFLAGS will effect both host and target builds.
"""

import os
import subprocess
import sys

cmd = sys.argv[1:]

# Add extra libs when linking
if '-c' not in cmd:
  cmd += os.environ['EXTRA_LIBS'].split()

sys.exit(subprocess.call(cmd))
