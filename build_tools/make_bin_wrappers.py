#!/usr/bin/env python
# Copyright (c) 2014 The Native Client Authors. All rights reserved.
# Use of this source code is governed by a BSD-style license that can be
# found in the LICENSE file.
"""Script for creating launcher scripts in the 'bin' folder.

Rather than maintaining these script in source control we
create them dynamically as part of runhooks."""

import os
import sys
import stat


SCRIPT_DIR = os.path.dirname(os.path.abspath(__file__))
BIN_DIR = os.path.join(os.path.dirname(SCRIPT_DIR), 'bin')
SCRIPTS = [
  'naclports.py',
  'nacl-env.sh',
  'nacl-make.sh',
  'nacl-configure.sh'
]


def create_wrapper(script):
  bin_wrapper = os.path.join(BIN_DIR, os.path.splitext(script)[0])
  with open(bin_wrapper, 'w') as f:
    f.write('''\
#!/bin/bash
# Wrapper script created automatically by make_bin_wrappers.py
SCRIPT_DIR=$(dirname "$BASH_SOURCE")

exec "$SCRIPT_DIR/../build_tools/%s" $*\n''' % script)
  st = os.stat(bin_wrapper)
  os.chmod(bin_wrapper, st.st_mode | stat.S_IXUSR | stat.S_IXGRP)


def main(args):
  if args:
    sys.stderr.write("%s: does not take any arguments" % __file__)
    sys.exit(1)

  if not os.path.exists(BIN_DIR):
    os.mkdir(BIN_DIR)

  for script in SCRIPTS:
    create_wrapper(script)

  print('For convenient access to naclports utilities add the following\n'
        'directory to your $PATH:\n %s' % BIN_DIR)

if __name__ == '__main__':
  sys.exit(main(sys.argv[1:]))
