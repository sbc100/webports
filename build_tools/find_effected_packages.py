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
  parser.add_argument('--deps', action='store_true',
                      help='include dependencies of effected packages.')
  parser.add_argument('files', nargs='+', help='Changes files.')
  options = parser.parse_args(args)
  naclports.SetVerbose(options.verbose)

  print '\n'.join(find_effected_packages(options.files, options.deps))
  return 0


def find_effected_packages(files, include_deps):
  packages = []
  to_resolve = []

  def AddPackage(package):
    if package.NAME not in packages:
      if include_deps:
        for dep in package.TransitiveDependencies():
          if dep.NAME not in packages:
            packages.append(dep.NAME)
      packages.append(package.NAME)
      to_resolve.append(package)

  for filename in files:
    parts = filename.split(os.path.sep)
    if parts[0] != 'ports':
      return ['all']

    package_name = parts[1]
    pkg = naclports.source_package.CreatePackage(package_name)
    AddPackage(pkg)

  while to_resolve:
    pkg = to_resolve.pop()
    for r in pkg.ReverseDependencies():
      AddPackage(r)

  return packages


if __name__ == '__main__':
  try:
    sys.exit(main(sys.argv[1:]))
  except naclports.Error as e:
    sys.stderr.write('%s\n' % e)
    sys.exit(-1)
