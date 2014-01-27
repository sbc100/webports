#!/usr/bin/env python
# Copyright (c) 2013 The Native Client Authors. All rights reserved.
# Use of this source code is governed by a BSD-style license that can be
# found in the LICENSE file.
"""Tool that checks the LICENSE field of all packages.

Currently it preforms the following simple check:
 - LICENSE field exists
 - LICENSE field contains only known licenses
 - Where a custom files is specified check that the file
   exists in the archive
"""

import optparse
import os
import sys

import naclports

KNOWN_LICENSES = ['GPL', 'GPL2', 'LGPL', 'LGPL2', 'ISC',
                  'MPL', 'BSD', 'MIT', 'ZLIB', 'CUSTOM']


options = None

def CheckLicense(package):
  if not package.LICENSE:
    print '%-27s: missing license field' % package.PACKAGE_NAME
    package.Download()
    package.Extract()
    return 1

  rtn = 0
  licenses = package.LICENSE.split(',')
  if options.verbose:
    print '%-27s: %s' % (package.PACKAGE_NAME, licenses)
  licenses = [license.split(':') for license in licenses]
  for license in licenses:
    if license[0] not in KNOWN_LICENSES:
      print 'Invalid license: %s' % license
      rtn = 1
    if len(license) > 1:
      package.Download()
      package.Extract()
      filename = os.path.join(package.GetBuildLocation(), license[1])
      if not os.path.exists(filename):
        print 'Missing license file: %s' % filename
        rtn = 1

  return rtn


def main(args):
  global options
  parser = optparse.OptionParser()
  parser.add_option('-v', '--verbose', action='store_true',
                    help='Output extra information.')
  options, _ = parser.parse_args(args)
  rtn = 0

  for package in naclports.PackageIterator():
    rtn |= CheckLicense(package)

  return rtn

if __name__ == '__main__':
  sys.exit(main(sys.argv[1:]))
