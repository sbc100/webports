#!/usr/bin/env python
# Copyright (c) 2014 The Native Client Authors. All rights reserved.
# Use of this source code is governed by a BSD-style license that can be
# found in the LICENSE file.
"""Tool for generating port dependencies for use in naclport Makefile.

This script reads the dependency information for each port and
generates make rules based on these.
"""

import optparse
import os
import sys

import naclports

SCRIPT_DIR = os.path.dirname(os.path.abspath(__file__))
NACLPORT_ROOT = os.path.dirname(SCRIPT_DIR)

def WriteDeps(output_file):
  for package in naclports.PackageIterator():
    deps = getattr(package, 'DEPENDS', None)
    if deps is None:
      continue
    output_file.write('\n$(SENT)/ports/%s:' % os.path.basename(package.root))
    for dep in deps:
      output_file.write(' \\\n  $(SENT)/ports/%s' % dep)
    output_file.write('\n')

  output_file.write('\n')

  # Write out shortcut/alias target for each port
  for package in naclports.PackageIterator():
    dep_name = os.path.relpath(package.root, NACLPORT_ROOT)
    output_file.write('%s: %s\n' % (os.path.basename(package.root), dep_name))
    output_file.write('.PHONY: %s\n' % os.path.basename(package.root))


def main(args):
  global options
  parser = optparse.OptionParser(description=__doc__)
  parser.add_option('-v', '--verbose', action='store_true',
                    help='Output extra information.')
  options, _ = parser.parse_args(args)

  WriteDeps(sys.stdout)


if __name__ == '__main__':
  try:
    sys.exit(main(sys.argv[1:]))
  except naclports.Error as e:
    sys.stderr.write('%s\n' % str(e))
    sys.exit(1)
