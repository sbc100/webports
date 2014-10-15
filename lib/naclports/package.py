# Copyright (c) 2014 The Native Client Authors. All rights reserved.
# Use of this source code is governed by a BSD-style license that can be
# found in the LICENSE file.

import os
import sys

import naclports
from naclports import Trace, Log, Warn, Error
from naclports import configuration

CACHE_ROOT = os.path.join(naclports.OUT_DIR, 'cache')
MIRROR_URL = '%s%s/mirror' % (naclports.GS_URL, naclports.GS_BUCKET)
EXTRA_KEYS = ['BUILD_CONFIG', 'BUILD_ARCH', 'BUILD_TOOLCHAIN',
              'BUILD_SDK_VERSION', 'BUILD_NACLPORTS_REVISION']

sys.path.append(naclports.TOOLS_DIR)

import sha1check


def RemoveEmptyDirs(dirname):
  """Recursively remove a directoy and its parents if they are empty."""
  while not os.listdir(dirname):
    os.rmdir(dirname)
    dirname = os.path.dirname(dirname)


class Package(object):
  extra_keys = []

  def __init__(self, info_file):
    self.info = info_file
    with open(self.info) as f:
      self.ParseInfo(f)

  def ParseInfo(self, info_stream):
    valid_keys = naclports.VALID_KEYS + self.extra_keys
    required_keys = naclports.REQUIRED_KEYS + self.extra_keys

    for key in valid_keys:
      setattr(self, key, None)
    self.DEPENDS = []
    self.CONFLICTS = []

    # Parse pkg_info file
    info = naclports.ParsePkgInfo(info_stream.read(),
                                  self.info,
                                  valid_keys,
                                  required_keys)

    # Set attributres based on pkg_info setttings.
    for key, value in info.items():
      setattr(self, key, value)

    if '_' in self.NAME:
      raise Error('%s: package NAME cannot contain underscores' % self.info)
    if self.NAME != self.NAME.lower():
      raise Error('%s: package NAME cannot contain uppercase characters' % self.info)
    if '_' in self.VERSION:
      raise Error('%s: package VERSION cannot contain underscores' % self.info)
    if self.DISABLED_ARCH is not None and self.ARCH is not None:
      raise Error('%s: contains both ARCH and DISABLED_ARCH' % self.info)
    if self.DISABLED_LIBC is not None and self.LIBC is not None:
      raise Error('%s: contains both LIBC and DISABLED_LIBC' % self.info)

  def __cmp__(self, other):
    return cmp(self.NAME, other.NAME)

  def InfoString(self):
    return "'%s' [%s]" % (self.NAME, self.config)

  def CheckDeps(self, valid_packages):
    for package in self.DEPENDS:
      if package not in valid_packages:
        Log('%s: Invalid dependency: %s' % (self.info, package))
        return False

    for package in self.CONFLICTS:
      if package not in valid_packages:
        Log('%s: Invalid conflict: %s' % (self.info, package))
        return False

    return True

  def IsAnyVersionInstalled(self):
    return naclports.IsInstalled(self.NAME, self.config)

  def GetInstallStamp(self):
    """Returns the name of install stamp for this package."""
    return naclports.GetInstallStamp(self.NAME, self.config)

  def GetListFile(self):
    """Returns the name of the installed file list for this package."""
    return naclports.GetListFile(self.NAME, self.config)


class InstalledPackage(Package):
  extra_keys = EXTRA_KEYS

  def __init__(self, info_file):
    super(InstalledPackage, self).__init__(info_file)
    self.config = configuration.Configuration(self.BUILD_ARCH,
                                              self.BUILD_TOOLCHAIN,
                                              self.BUILD_CONFIG == 'debug')

  def Uninstall(self, ignore_missing=False):
    if not os.path.exists(self.GetInstallStamp()):
      if ignore_missing:
        return
      raise Error('Package not installed: %s' % self.InfoString())

    Log("Uninstalling %s" % self.InfoString())
    self.DoUninstall()

  def DoUninstall(self):
    os.remove(self.GetInstallStamp())
    file_list = self.GetListFile()
    if not os.path.exists(file_list):
      Trace('No files to uninstall')
      return

    root = naclports.GetInstallRoot(self.config)
    with open(file_list) as f:
      for line in f:
        filename = os.path.join(root, line.strip())
        if not os.path.lexists(filename):
          Warn('File not found while uninstalling: %s' % filename)
          continue
        Trace('rm %s' % filename)
        os.remove(filename)
        RemoveEmptyDirs(os.path.dirname(filename))

    os.remove(file_list)


def InstalledPackageIterator(config):
  stamp_root = naclports.GetInstallStampRoot(config)
  if not os.path.exists(stamp_root):
    return

  for filename in os.listdir(stamp_root):
    if os.path.splitext(filename)[1] != '.info':
      continue
    yield InstalledPackage(os.path.join(stamp_root, filename))


def CreateInstalledPackage(package_name, config=None):
  stamp_root = naclports.GetInstallStampRoot(config)
  info_file = os.path.join(stamp_root, package_name + '.info')
  if not os.path.exists(info_file):
    raise Error('package not installed: %s [%s]' % (package_name, config))
  return InstalledPackage(info_file)
