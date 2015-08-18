#!/usr/bin/env python
# Copyright 2015 The Native Client Authors. All rights reserved.
# Use of this source code is governed by a BSD-style license that can be
# found in the LICENSE file.
"""Find which packages are effected by a given change.

Accepts a list of changed files and outputs a list of effected
packages.  Outputs 'all' if any shared/non-package-specific
file if changed."""

import argparse
import os
import sys

SCRIPT_DIR = os.path.dirname(os.path.abspath(__file__))
NACLPORTS_ROOT = os.path.dirname(SCRIPT_DIR)
sys.path.append(os.path.join(NACLPORTS_ROOT, 'lib'))

import naclports
import naclports.source_package

def main(args):
  parser = argparse.ArgumentParser(description=__doc__)
  parser.add_argument('-v', '--verbose', action='store_true')
  parser.add_argument('files', nargs='+', help='Changes files.')
  options = parser.parse_args(args)
  naclports.SetVerbose(options.verbose)

  packages = []
  to_resolve = []

  def AddPackage(package_name):
    packages.append(package_name)
    to_resolve.append(package_name)

  for filename in options.files:
    parts = filename.split(os.path.sep)
    if parts[0] != 'ports':
      print 'all'
      return 0

    package_name = parts[1]
    AddPackage(package_name)

  while to_resolve:
    package_name = to_resolve.pop()
    pkg = naclports.source_package.CreatePackage(package_name)
    for r in pkg.ReverseDependencies():
      if r.NAME not in packages:
        AddPackage(r.NAME)

  for p in packages:
    print p

  return 0


if __name__ == '__main__':
  try:
    sys.exit(main(sys.argv[1:]))
  except naclports.Error as e:
    sys.stderr.write('%s\n' % e)
    sys.exit(-1)
