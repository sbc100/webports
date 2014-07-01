#!/usr/bin/env python
# Copyright (c) 2013 The Native Client Authors. All rights reserved.
# Use of this source code is governed by a BSD-style license that can be
# found in the LICENSE file.
"""Tool which checks the sha1 sums of all packages.
"""

import optparse
import os
import sys

SCRIPT_DIR = os.path.dirname(os.path.abspath(__file__))
sys.path.append(os.path.join(os.path.dirname(SCRIPT_DIR), 'lib'))

import naclports

def main(args):
  global options
  parser = optparse.OptionParser()
  parser.add_option('-v', '--verbose', action='store_true',
                    help='Output extra information.')
  options, _ = parser.parse_args(args)
  count = 0

  for package in naclports.PackageIterator():
    package.Download()
    if not package.Verify(True):
      return 1

    count = count + 1

  print "Verfied checksums for %d packages" % count
  return 0

if __name__ == '__main__':
  sys.exit(main(sys.argv[1:]))
