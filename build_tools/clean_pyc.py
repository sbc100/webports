#!/usr/bin/env python
# Copyright (c) 2014 The Native Client Authors. All rights reserved.
# Use of this source code is governed by a BSD-style license that can be
# found in the LICENSE file.
"""Script to cleanup stale .pyc files.

This script is run by gclient run-hooks (see DEPS)
"""

import os
import sys

def main(args):
  for directory in args:
    assert(os.path.isdir(directory))
    for root, dirs, files in os.walk(directory):
      for filename in files:
        basename, ext = os.path.splitext(filename)
        if ext == '.pyc':
          py_file = os.path.join(root, basename + '.py')
          if not os.path.exists(py_file):
            pyc_file = os.path.join(root, filename)
            print 'Removing stale pyc file: %s' % pyc_file
            os.remove(pyc_file)


if __name__ == '__main__':
  main(sys.argv[1:])
