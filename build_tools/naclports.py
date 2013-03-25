# Copyright (c) 2013 The Native Client Authors. All rights reserved.
# Use of this source code is governed by a BSD-style license that can be
# found in the LICENSE file.
"""Library for manipulating naclports packages in python.

This library can be used to build tools for working with naclports
packages.  For example, it is used by 'update_mirror.py' to iterate
through all packages and mirror them on commondatastorage.
"""
import subprocess
import os
import urlparse
import shlex
import shutil
import sys
import tempfile

MIRROR_URL = 'http://commondatastorage.googleapis.com/nativeclient-mirror/nacl'
SCRIPT_DIR = os.path.dirname(os.path.abspath(__file__))
NACLPORTS_ROOT = os.path.dirname(SCRIPT_DIR)
OUT_DIR = os.path.join(NACLPORTS_ROOT, 'out')
ARCH = os.environ.get('NACL_ARCH', 'i686')
BUILD_ROOT = os.path.join(OUT_DIR, 'repository-' + ARCH)


# TODO(sbc): use this code to replace the bash logic in build_tools/common.sh


class Error(Exception):
  pass


class Package(object):
  """Representation of a single naclports package.

  Package objects correspond to folders on disk which
  contain a 'pkg_info' file.
  """
  def __init__(self, pkg_root):
    info = os.path.join(pkg_root, 'pkg_info')
    keys = []
    self.URL_FILENAME = None
    self.LICENSE = None
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

  def BuildLocation(self):
    return os.path.join(BUILD_ROOT, self.PACKAGE_NAME)

  def GetArchiveFilename(self):
    if self.URL_FILENAME:
      return self.URL_FILENAME
    else:
      return os.path.basename(urlparse.urlparse(self.URL)[2])

  def DownloadLocation(self):
    return os.path.join(OUT_DIR, 'tarballs', self.GetArchiveFilename())

  def Extract(self):
    self.ExtractInto(BUILD_ROOT)

  def ExtractInto(self, output_path):
    """Extract the package archive into the given location.

    This method assumes the package has already been downloaded.
    """
    if not os.path.exists(output_path):
      os.makedirs(output_path)

    new_foldername = self.PACKAGE_NAME
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
