#!/usr/bin/env python
# Copyright (c) 2014 The Native Client Authors. All rights reserved.
# Use of this source code is governed by a BSD-style license that can be
# found in the LICENSE file.

"""Scan online binary packages to produce new package index.

This script is indended to be run periodically and the
results checked into source control.  This script depends on
gsutil being installed.
"""

from __future__ import print_function

import argparse
import collections
import hashlib
import os
import subprocess
import sys

SCRIPT_DIR = os.path.dirname(os.path.abspath(__file__))
sys.path.append(os.path.join(os.path.dirname(SCRIPT_DIR), 'lib'))

import naclports
import naclports.package
import naclports.package_index

from naclports import Log, Trace


def FormatSize(num_bytes):
  """Create a human readable string from a byte count."""
  for x in ['bytes','KB','MB','GB','TB']:
    if num_bytes < 1024.0:
      return "%3.1f %s" % (num_bytes, x)
    num_bytes /= 1024.0


FileInfo = collections.namedtuple('FileInfo', ['name', 'size', 'url', 'etag'])

def ParseGsUtilLs(output):
  """Parse the output of gsutil -le.

  gsutil -le outputs one file per line with the following format:
  <size_in_bytes>  2014-07-01T00:21:05Z gs://bucket/file.txt etag=<sha1>

  Returns:
     List of FileInfo objects.
  """
  result = []
  for line in output.splitlines():
    if line.startswith("TOTAL"):
      continue
    size, data, filename, etag = line.split()
    etag = etag.split('=', 1)[1]
    filename = filename[len('gs://'):]
    url = naclports.GS_URL + filename
    if filename:
      result.append(FileInfo(filename, int(size), url, etag))
  return result


def CheckHash(filename, md5sum):
  """Return True is filename has the given md5sum, False otherwise."""
  with open(filename) as f:
    file_md5sum = hashlib.md5(f.read()).hexdigest()
  return md5sum == file_md5sum


def DownloadFiles(files, check_hashes=True):
  """Download one of more files to the local disk.

  Args:
    files: List of FileInfo objects to download.
    check_hashes: When False assume local files have the correct
    hash otherwise always check the hashes match the onces in the
    FileInfo ojects.

  Returns:
    List of (filename, url) tuples.
  """
  files_to_download = []
  filenames = []
  download_dir = naclports.package_index.PREBUILT_ROOT
  if not os.path.exists(download_dir):
    os.makedirs(download_dir)

  for file_info in files:
    basename = os.path.basename(file_info.url)
    fullname = os.path.join(download_dir, basename)
    filenames.append((fullname, file_info.url))
    if os.path.exists(fullname):
      if not check_hashes or CheckHash(fullname, file_info.etag):
        Log('Up-to-date: %s' % file_info.name)
        continue
    files_to_download.append(FileInfo(fullname, file_info.size, file_info.url,
      file_info.etag))

  if not files_to_download:
    Log('All files up-to-date')
  else:
    total_size = sum(f[1] for f in files_to_download)
    Log('Need to download %d/%d files [%s]' % (len(files_to_download),
         len(files), FormatSize(total_size)))

    for file_info in files_to_download:
      naclports.DownloadFile(file_info.name, file_info.url)
      if check_hashes and not CheckHash(file_info.name, file_info.etag):
        raise naclports.Error('Checksum failed: %s' % file_info.name)

  return filenames


def main(args):
  parser = argparse.ArgumentParser(description=__doc__)
  parser.add_argument('revision', metavar='REVISION',
                      help='naclports revision to to scan for.')
  parser.add_argument('-v', '--verbose', action='store_true',
                      help='Output extra information.')
  parser.add_argument('-l', '--cache-listing', action='store_true',
                      help='Cached output of gsutil -le (for testing).')
  parser.add_argument('--skip-md5', action='store_true',
                      help='Assume on-disk files are up-to-date (for testing).')
  args = parser.parse_args(args)
  if args.verbose:
    naclports.verbose = True

  sdk_version = naclports.GetSDKVersion()
  Log('Scanning packages built for pepper_%s at revsion %s' %
      (sdk_version, args.revision))
  base_path = '%s/builds/pepper_%s/%s/packages' % (naclports.GS_BUCKET,
                                                   sdk_version,
                                                   args.revision)
  gs_url = 'gs://' + base_path
  listing_file = os.path.join(naclports.NACLPORTS_ROOT, 'lib', 'listing.txt')
  if args.cache_listing and os.path.exists(listing_file):
    Log('Using pre-cached gs listing: %s' % listing_file)
    with open(listing_file) as f:
      listing = f.read()
  else:
    Log("Searching for packages at: %s" % gs_url)
    cmd = ['gsutil', 'ls', '-le', gs_url]
    Trace("Running: %s" % str(cmd))
    try:
      listing = subprocess.check_output(cmd)
    except subprocess.CalledProcessError as e:
      naclports.Error(e)
      return 1

  all_files = ParseGsUtilLs(listing)
  if args.cache_listing and not os.path.exists(listing_file):
    with open(listing_file, 'w') as f:
      f.write(listing)

  Log('Found %d packages [%s]' % (len(all_files),
                                  FormatSize(sum(f.size for f in all_files))))

  binaries = DownloadFiles(all_files, not args.skip_md5)
  index_file = os.path.join(naclports.NACLPORTS_ROOT, 'lib', 'prebuilt.txt')
  Log('Generating %s' % index_file)
  naclports.package_index.WriteIndex(index_file, binaries)
  Log('Done')
  return 0


if __name__ == '__main__':
  sys.exit(main(sys.argv[1:]))
