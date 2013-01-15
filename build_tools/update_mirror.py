#!/usr/bin/env python
# Copyright (c) 2011 The Native Client Authors. All rights reserved.
# Use of this source code is governed by a BSD-style license that can be
# found in the LICENSE file.

"""Script synchronise the naclports mirror of upstream archives.

This script verifies that the URL for every package in mirrored on
commondatastorage.  If it finds missing URLs it downloads them to
the local machine and then pushes them out using gsutil.

gsutil is required the run this script and if any mirroring
opterations are required then the correct gsutil credentials
will be required.
"""

import os
import subprocess
import sys
import urllib
import shlex

SCRIPT_DIR = os.path.dirname(os.path.abspath(__file__))
MIRROR_GS = 'gs://nativeclient-mirror/nacl'


def parse_info(info_filename):
  info = {}
  for line in open(info_filename):
    key, value = line.strip().split('=', 1)
    info[key] = shlex.split(value)[0]
  return info


def main():
  ports_root = os.path.dirname(SCRIPT_DIR)
  listing = subprocess.check_output(['gsutil', 'ls', MIRROR_GS])
  listing = listing.splitlines()
  listing = [os.path.basename(l) for l in listing]

  for root, dirs, files in os.walk(ports_root):
    if 'pkg_info' not in files:
      continue
    info = parse_info(os.path.join(root, 'pkg_info'))
    if 'URL' not in info:
      continue
    basename = info.get('URL_FILENAME')
    if not basename:
      basename = os.path.basename(info['URL'])
    if basename in listing:
      # already mirrored
      continue

    # Download upstream URL
    print 'Downloading: %s' % info['URL']
    remote = urllib.urlopen(info['URL'])
    with open(basename, 'w') as tmp:
      tmp.write(remote.read())

    # Upload to gs
    url = '%s/%s' % (MIRROR_GS, basename)
    print "Uploading to mirror: %s" % url
    cmd = ['gsutil', 'cp', '-a', 'public-read', basename, url]
    subprocess.check_call(cmd)


if __name__ == '__main__':
  sys.exit(main())
