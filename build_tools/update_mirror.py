#!/usr/bin/env python
# Copyright (c) 2011 The Native Client Authors. All rights reserved.
# Use of this source code is governed by a BSD-style license that can be
# found in the LICENSE file.

"""Script to synchronise the naclports mirror of upstream archives.

This script verifies that the URL for every package is mirrored on
Google Cloud Storage.  If it finds missing URLs it downloads them to
the local machine and then pushes them up using gsutil.

gsutil is required the run this script and if any mirroring operations are
required then the correct gsutil credentials will be required.
"""

from __future__ import print_function

import argparse
import os
import shlex
import subprocess
import sys
import urllib
import urlparse

SCRIPT_DIR = os.path.dirname(os.path.abspath(__file__))
NACLPORTS_ROOT = os.path.dirname(SCRIPT_DIR)
sys.path.append(os.path.join(NACLPORTS_ROOT, 'lib'))

import naclports
import naclports.source_package

MIRROR_GS = 'gs://naclports/mirror'


def main(args):
  parser = argparse.ArgumentParser(description=__doc__)
  parser.add_argument('-n', '--dry-run', action='store_true',
                      help="Don't actually upload anything")
  parser.add_argument('--check', action='store_true',
                      help='Verify that the mirror is up-to-date.')
  parser.add_argument('-v', '--verbose', action='store_true',
                      help='Enable verbose output.')
  options = parser.parse_args(args)
  naclports.verbose = options.verbose

  ports_root = os.path.dirname(SCRIPT_DIR)
  listing = subprocess.check_output(['gsutil', 'ls', MIRROR_GS])
  listing = listing.splitlines()
  listing = [os.path.basename(l) for l in listing]

  def CheckMirror(package):
    naclports.Trace('Checking %s' % package.NAME)
    basename = package.GetArchiveFilename()
    if not basename:
      return

    if basename in listing:
      # already mirrored
      return

    if options.check:
      naclports.Log('update_mirror: Archive missing from mirror: %s' % basename)
      sys.exit(1)

    # Download upstream URL
    package.Download(mirror=False)

    # Upload to gs
    url = '%s/%s' % (MIRROR_GS, basename)
    naclports.Log("Uploading to mirror: %s" % url)
    cmd = ['gsutil', 'cp', '-a', 'public-read', package.DownloadLocation(), url]
    if options.dry_run:
      naclports.Log(cmd)
    else:
      subprocess.check_call(cmd)

  count = 0
  for package in naclports.source_package.SourcePackageIterator():
    CheckMirror(package)
    count += 1

  if options.check:
    naclports.Log("Verfied mirroring for %d packages" % count)
  return 0


if __name__ == '__main__':
  try:
    sys.exit(main(sys.argv[1:]))
  except naclports.Error as e:
    sys.stderr.write('%s\n' % e)
    sys.exit(-1)
