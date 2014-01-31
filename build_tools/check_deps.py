#!/usr/bin/env python
# Copyright (c) 2013 The Native Client Authors. All rights reserved.
# Use of this source code is governed by a BSD-style license that can be
# found in the LICENSE file.
"""Tool which checks the dependencies of all packages.
"""

import optparse
import os
import sys

import naclports

def main(args):
  global options
  parser = optparse.OptionParser()
  parser.add_option('-v', '--verbose', action='store_true',
                    help='Output extra information.')
  options, _ = parser.parse_args(args)
  count = 0

  package_names = [os.path.basename(p.root)
                   for p in naclports.PackageIterator()]

  for package in naclports.PackageIterator():
    if not package.CheckDeps(package_names):
      return 1
    count += 1

  print "Verfied dependencies for %d packages" % count
  return 0

if __name__ == '__main__':
  sys.exit(main(sys.argv[1:]))
