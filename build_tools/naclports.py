#!/usr/bin/env python
# Copyright (c) 2013 The Native Client Authors. All rights reserved.
# Use of this source code is governed by a BSD-style license that can be
# found in the LICENSE file.
"""Tool for manipulating naclports packages in python.

This tool can be used to for working with naclports packages.
It can also be incorporated into other tools that need to
work with packages (e.g. 'update_mirror.py' uses it to iterate
through all packages and mirror them on Google Cloud Storage).
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

MIRROR_URL = 'http://storage.googleapis.com/naclports/mirror/'
SCRIPT_DIR = os.path.dirname(os.path.abspath(__file__))
NACLPORTS_ROOT = os.path.dirname(SCRIPT_DIR)
OUT_DIR = os.path.join(NACLPORTS_ROOT, 'out')
ARCH = os.environ.get('NACL_ARCH', 'i686')
BUILD_ROOT = os.path.join(OUT_DIR, 'repository')
ARCHIVE_ROOT = os.path.join(OUT_DIR, 'tarballs')

NACL_SDK_ROOT = os.environ.get('NACL_SDK_ROOT')

# TODO(sbc): use this code to replace the bash logic in build_tools/common.sh


class Error(Exception):
  pass


class Package(object):
  """Representation of a single naclports package.

  Package objects correspond to folders on disk which
  contain a 'pkg_info' file.
  """
  VALUE_KEYS = ('URL', 'PACKAGE_NAME', 'LICENSE', 'DEPENDS', 'MIN_SDK_VERSION',
                'LIBC', 'DISABLED_ARCH', 'URL_FILENAME', 'PACKAGE_DIR',
                'BUILD_OS')

  def __init__(self, pkg_root):
    self.root = os.path.abspath(pkg_root)
    self.info = os.path.join(pkg_root, 'pkg_info')
    keys = []
    self.URL_FILENAME = None
    self.URL = None
    self.LICENSE = None
    if not os.path.exists(self.info):
      raise Error('Invalid package folder: %s' % pkg_root)

    with open(self.info) as f:
      for i, line in enumerate(f):
        if line[0] == '#':
          continue
        key, value = self.ParsePkgInfoLine(line, i+1)
        keys.append(key)
        setattr(self, key, value)
    assert 'PACKAGE_NAME' in keys

  def __cmp__(self, other):
    return cmp(self.PACKAGE_NAME, other.PACKAGE_NAME)

  def ParsePkgInfoLine(self, line, line_no):
    if '=' not in line:
      raise Error('Invalid pkg_info line %d: %s' % (line_no, self.info))
    key, value = line.split('=', 1)
    key = key.strip()
    if key not in Package.VALUE_KEYS:
      raise Error("Invalid key '%s' in pkg_info: %s" % (key, self.info))
    value = value.strip()
    if value[0] == '(':
      array_value = []
      if value[-1] != ')':
        raise Error('Error parsing %s: %s (%s)' % (self.info, key, value))
      value = value[1:-1]
      for single_value in value.split():
        array_value.append(single_value)
      value = array_value
    else:
      value = shlex.split(value)[0]
    return (key, value)

  def CheckDeps(self, valid_dependencies):
    for dep in getattr(self, 'DEPENDS', []):
      if dep not in valid_dependencies:
        print '%s: Invalid dependency: %s' % (self.info, dep)
        return False
    return True

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

    if self.URL and '.git' not in self.URL:
      return os.path.basename(urlparse.urlparse(self.URL)[2])

    return None

  def DownloadLocation(self):
    archive = self.GetArchiveFilename()
    if not archive:
      return
    return os.path.join(ARCHIVE_ROOT, archive)

  def Verify(self, verbose=False):
    """Download upstream source and verify hash."""
    if not self.GetArchiveFilename():
      print "no archive: %s" % self.PACKAGE_NAME
      return True

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

  def Enabled(self):
    if hasattr(self, 'LIBC'):
      if os.environ.get('NACL_GLIBC') == '1':
        if self.LIBC != 'glibc':
          raise Error('Package cannot be built with glibc.')
      else:
        if self.LIBC != 'newlib':
          raise Error('Package cannot be built with newlib.')

    if hasattr(self, 'DISABLED_ARCH'):
      arch = os.environ.get('NACL_ARCH', 'x86_64')
      if arch == self.DISABLED_ARCH:
        raise Error('Package is disabled for current arch: %s.' % arch)

    if hasattr(self, 'BUILD_OS'):
      sys.path.append(os.path.join(NACL_SDK_ROOT, 'tools'))
      import getos
      if getos.GetPlatform() != self.BUILD_OS:
        raise Error('Package can only be built on: %s.' % self.BUILD_OS)

  def Download(self, mirror=True):
    filename = self.DownloadLocation()
    if not filename or os.path.exists(filename):
      return
    if not os.path.exists(os.path.dirname(filename)):
      os.makedirs(os.path.dirname(filename))

    temp_filename = filename + '.partial'
    mirror_download_successfull = False
    if mirror:
      try:
        mirror = self.GetMirrorURL()
        print 'Downloading: %s [%s]' % (mirror, temp_filename)
        cmd = ['wget', '-O', temp_filename, mirror]
        subprocess.check_call(cmd)
        mirror_download_successfull = True
      except subprocess.CalledProcessError:
        pass

    if not mirror_download_successfull:
      print 'Downloading: %s [%s]' % (self.URL, temp_filename)
      cmd = ['wget', '-O', temp_filename, self.URL]
      subprocess.check_call(cmd)

    os.rename(temp_filename, filename)


def PackageIterator(folders=None):
  """Iterator which yield a Package object for each
  naclport package."""
  if not folders:
    folders = [os.path.join(NACLPORTS_ROOT, 'ports')]

  for folder in folders:
    for root, dirs, files in os.walk(folder):
      if 'pkg_info' in files:
        yield Package(root)


def main(args):
  try:
    parser = optparse.OptionParser(description=__doc__)
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

    if not options.dirname:
      options.dirname = '.'

    if not NACL_SDK_ROOT:
      Error("$NACL_SDK_ROOT not set")

    p = Package(options.dirname)
    if command == 'download':
      p.Download()
    elif command == 'check':
      # Fact that we've got this far means the pkg_info
      # is basically valid.  This final check verifies the
      # dependencies are valid.
      package_names = [os.path.basename(p.root) for p in PackageIterator()]
      p.CheckDeps(package_names)
    elif command == 'enabled':
      p.Enabled()
    elif command == 'verify':
      p.Verify()
  except Error as e:
    sys.stderr.write('naclports: %s\n' % e)
    return 1

  return 0


if __name__ == '__main__':
  sys.exit(main(sys.argv[1:]))
