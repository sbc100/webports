# Copyright (c) 2014 The Native Client Authors. All rights reserved.
# Use of this source code is governed by a BSD-style license that can be
# found in the LICENSE file.

import os
import sys

import naclports
from naclports import Trace, Log, Warn, Error
from naclports import configuration

EXTRA_KEYS = ['BUILD_CONFIG', 'BUILD_ARCH', 'BUILD_TOOLCHAIN',
              'BUILD_SDK_VERSION', 'BUILD_NACLPORTS_REVISION']

sys.path.append(naclports.TOOLS_DIR)


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
      self.ParseInfo(f.read())

  def ParseInfo(self, info_string):
    valid_keys = naclports.VALID_KEYS + self.extra_keys
    required_keys = naclports.REQUIRED_KEYS + self.extra_keys

    for key in valid_keys:
      setattr(self, key, None)
    self.DEPENDS = []
    self.CONFLICTS = []

    # Parse pkg_info file
    info = naclports.ParsePkgInfo(info_string,
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

  def __str__(self):
    return '<Package %s %s %s>' % (self.NAME, self.VERSION, self.config)

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

  def Uninstall(self):
    Log("Uninstalling %s" % self.InfoString())
    self.DoUninstall()

  def Files(self):
    """Yields the list of files currently installed by this package."""
    with open(self.GetListFile()) as f:
      for line in f:
        yield line.strip()

  def RemoveFile(self, filename):
    os.remove(filename)
    RemoveEmptyDirs(os.path.dirname(filename))

  def DoUninstall(self):
    with naclports.InstallLock(self.config):
      self.RemoveFile(self.GetInstallStamp())

      root = naclports.GetInstallRoot(self.config)
      for filename in self.Files():
        filename = os.path.join(root, filename)
        if not os.path.lexists(filename):
          Warn('File not found while uninstalling: %s' % filename)
          continue
        Trace('rm %s' % filename)
        self.RemoveFile(filename)

      self.RemoveFile(self.GetListFile())


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
