#!/usr/bin/env python
# Copyright (c) 2013 The Native Client Authors. All rights reserved.
# Use of this source code is governed by a BSD-style license that can be
# found in the LICENSE file.
"""Library for manipulating naclports packages in python.

This library can be used to build tools for working with naclports
packages.  For example, it is used by 'update_mirror.py' to iterate
through all packages and mirror them on commondatastorage.
"""
import optparse
import os
import urlparse
import shlex
import shutil
import subprocess
import sys
import tempfile

import sha1check

MIRROR_URL = 'http://commondatastorage.googleapis.com/nativeclient-mirror/nacl'
SCRIPT_DIR = os.path.dirname(os.path.abspath(__file__))
NACLPORTS_ROOT = os.path.dirname(SCRIPT_DIR)
OUT_DIR = os.path.join(NACLPORTS_ROOT, 'out')
ARCH = os.environ.get('NACL_ARCH', 'i686')
BUILD_ROOT = os.path.join(OUT_DIR, 'repository')
ARCHIVE_ROOT = os.path.join(OUT_DIR, 'tarballs')


# TODO(sbc): use this code to replace the bash logic in build_tools/common.sh


class Error(Exception):
  pass


class Package(object):
  """Representation of a single naclports package.

  Package objects correspond to folders on disk which
  contain a 'pkg_info' file.
  """
  def __init__(self, pkg_root):
    self.root = os.path.abspath(pkg_root)
    info = os.path.join(pkg_root, 'pkg_info')
    keys = []
    self.URL_FILENAME = None
    self.LICENSE = None
    if not os.path.exists(info):
      raise Error('Invalid package folder: %s' % pkg_root)
    with open(info) as f:
      for line in f:
        key, value = line.split('=', 1)
        key = key.strip()
        value = shlex.split(value.strip())[0]
        keys.append(key)
        setattr(self, key, value)
    assert 'URL' in keys
    assert 'PACKAGE_NAME' in keys

  def GetBasename(self):
    basename = os.path.splitext(self.GetArchiveFilename())[0]
    if basename.endswith('.tar'):
      basename = os.path.splitext(basename)[0]
    return basename

  def GetBuildLocation(self):
    package_dir = getattr(self, 'PACKAGE_DIR', self.PACKAGE_NAME)
    return os.path.join(BUILD_ROOT, package_dir)

  def GetArchiveFilename(self):
    if self.URL_FILENAME:
      return self.URL_FILENAME
    else:
      return os.path.basename(urlparse.urlparse(self.URL)[2])

  def DownloadLocation(self):
    return os.path.join(ARCHIVE_ROOT, self.GetArchiveFilename())

  def Verify(self, verbose=False):
    self.Download()
    olddir = os.getcwd()
    sha1file = os.path.join(self.root, self.PACKAGE_NAME + '.sha1')
    try:
      os.chdir(ARCHIVE_ROOT)
      with open(sha1file) as f:
        try:
          filenames = sha1check.VerifyFile(f, False)
          print "verified: %s" % (filenames)
        except sha1check.Error as e:
          print "verification failed: %s: %s" % (sha1file, str(e))
          return False
    finally:
      os.chdir(olddir)

    return True

  def Extract(self):
    self.ExtractInto(BUILD_ROOT)

  def ExtractInto(self, output_path):
    """Extract the package archive into the given location.

    This method assumes the package has already been downloaded.
    """
    if not os.path.exists(output_path):
      os.makedirs(output_path)

    new_foldername = os.path.dirname(self.GetBuildLocation())
    if os.path.exists(os.path.join(output_path, new_foldername)):
      return

    tmp_output_path = tempfile.mkdtemp(dir=OUT_DIR)
    try:
      archive = self.DownloadLocation()
      ext = os.path.splitext(archive)[1]
      if ext in ('.gz', '.tgz', '.bz2'):
        cmd = ['tar', 'xf', archive, '-C', tmp_output_path]
      elif ext in ('.zip',):
        cmd = ['unzip', '-q', '-d', tmp_output_path, archive]
      else:
        raise Error('unhandled extension: %s' % ext)
      print cmd
      subprocess.check_call(cmd)
      src = os.path.join(tmp_output_path, new_foldername)
      dest = os.path.join(output_path, new_foldername)
      os.rename(src, dest)
    finally:
      shutil.rmtree(tmp_output_path)

  def GetMirrorURL(self):
    return MIRROR_URL + '/' + self.GetArchiveFilename()

  def Download(self):
    filename = self.DownloadLocation()
    if os.path.exists(filename):
      return
    if not os.path.exists(os.path.dirname(filename)):
      os.makedirs(os.path.dirname(filename))
    try:
      mirror = self.GetMirrorURL()
      print 'Downloading: %s [%s]' % (mirror, filename)
      cmd = ['wget', '-O', filename, mirror]
      subprocess.check_call(cmd)
    except subprocess.CalledProcessError:
      print 'Downloading: %s [%s]' % (self.URL, filename)
      cmd = ['wget', '-O', filename, self.URL]
      subprocess.check_call(cmd)


def PackageIterator(folders=None):
  """Iterator which yield a Package object for each
  naclport package."""
  if not folders:
    folders = [os.path.join(NACLPORTS_ROOT, 'examples'),
               os.path.join(NACLPORTS_ROOT, 'libraries')]

  for folder in folders:
    for root, dirs, files in os.walk(folder):
      if 'pkg_info' in files:
        yield Package(root)


def main(args):
  try:
    parser = optparse.OptionParser()
    parser.add_option('-v', '--verbose', action='store_true',
                      help='Output extra information.')
    parser.add_option('-C', dest='dirname', default='.',
                      help='Change directory before executing commands.')
    options, args = parser.parse_args(args)
    if not args:
      parser.error("You must specify a build command")
    if len(args) > 1:
      parser.error("More than one command specified")

    command = args[0]

    if options.dirname:
      os.chdir(options.dirname)

    p = Package('.')
    if command == 'download':
      p.Download()
    elif command == 'verify':
      p.Verify()
  except Error as e:
    sys.stderr.write('naclports: %s\n' % e)
    return 1

  return 0


if __name__ == '__main__':
  sys.exit(main(sys.argv[1:]))
