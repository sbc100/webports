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

VALID_LICENSES = ['GPL', 'GPL2', 'GPL3', 'LGPL', 'LGPL2', 'LGPL3', 'ISC',
                  'MPL', 'BSD', 'MIT', 'ZLIB', 'CUSTOM', 'APACHE']


options = None

def CheckLicense(package):
  if not package.LICENSE:
    print '%-27s: missing license field' % package.NAME
    package.Download()
    package.Extract()
    return 1

  rtn = 0
  licenses = package.LICENSE.split(',')
  if options.verbose:
    print '%-27s: %s' % (package.NAME, licenses)
  licenses = [license.split(':') for license in licenses]
  for license in licenses:
    if license[0] not in VALID_LICENSES:
      print '%s: Invalid license: %s' % (package.root, license)
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
  rtn = False

  count = 0
  for package in naclports.PackageIterator():
    rtn |= CheckLicense(package)
    count += 1

  if not rtn:
    print "Verfied licenses for %d packages" % count

  return rtn

if __name__ == '__main__':
  sys.exit(main(sys.argv[1:]))
