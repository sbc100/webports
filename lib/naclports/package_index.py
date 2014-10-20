# Copyright (c) 2014 The Native Client Authors. All rights reserved.
# Use of this source code is governed by a BSD-style license that can be
# found in the LICENSE file.

import os
import hashlib

import configuration
import naclports
import package

DEFAULT_INDEX = os.path.join(naclports.NACLPORTS_ROOT, 'lib', 'prebuilt.txt')
EXTRA_KEYS = naclports.package.EXTRA_KEYS + ['BIN_URL', 'BIN_SIZE', 'BIN_SHA1']
PREBUILT_ROOT = os.path.join(naclports.PACKAGES_ROOT, 'prebuilt')


def VerifyHash(filename, sha1):
  """Return True if the sha1 of the given file match the sha1 passed in."""
  with open(filename) as f:
    file_sha1 = hashlib.sha1(f.read()).hexdigest()
  return sha1 == file_sha1


def WriteIndex(index_filename, binaries):
  """Create a package index file from set of binaries on disk.

  Returns:
    A PackageIndex object based on the contents of the newly written file.
  """
  # Write index to a temporary file and then rename it, to avoid
  # leaving a partial index file on disk.
  tmp_name = index_filename + '.tmp'
  with open(tmp_name, 'w') as output_file:
    for i, (filename, url) in enumerate(binaries):
      package = naclports.binary_package.BinaryPackage(filename)
      with open(filename) as f:
        sha1 = hashlib.sha1(f.read()).hexdigest()
      if i != 0:
        output_file.write('\n')
      output_file.write(package.GetPkgInfo())
      output_file.write('BIN_URL=%s\n' % url)
      output_file.write('BIN_SIZE=%s\n' % os.path.getsize(filename))
      output_file.write('BIN_SHA1=%s\n' % sha1)

  os.rename(tmp_name, index_filename)

  return IndexFromFile(index_filename)


def IndexFromFile(filename):
    with open(filename) as f:
      contents = f.read()
    return PackageIndex(filename, contents)


def GetCurrentIndex():
  return IndexFromFile(DEFAULT_INDEX)


class PackageIndex(object):
  """In memory representation of a package index file.

  This class is used to read a package index of disk and stores
  it in memory as dictionary keys on package name + configuration.
  """
  valid_keys = naclports.VALID_KEYS + EXTRA_KEYS
  required_keys = naclports.REQUIRED_KEYS + EXTRA_KEYS

  def __init__(self, filename, index_data):

    self.filename = filename
    self.packages = {}
    self.ParseIndex(index_data)

  def Contains(self, package_name, config):
    """Returns True if the index contains the given package in the given
    configuration, False otherwise."""
    return (package_name, config) in self.packages

  def Installable(self, package_name, config):
    """Returns True if the index contains the given package and it is
    installable in the currently configured SDK."""
    info = self.packages.get((package_name, config))
    if not info:
      return False
    version = naclports.GetSDKVersion()
    if info['BUILD_SDK_VERSION'] != version:
      naclports.Trace('Prebuilt package was built with different SDK version: '
                      '%s vs %s' % (info['BUILD_SDK_VERSION'], version))
      return False
    return True

  def Download(self, package_name, config):
    if not os.path.exists(PREBUILT_ROOT):
      os.makedirs(PREBUILT_ROOT)
    info = self.packages[(package_name, config)]
    filename = os.path.join(PREBUILT_ROOT, os.path.basename(info['BIN_URL']))
    if os.path.exists(filename):
      if VerifyHash(filename, info['BIN_SHA1']):
        return filename
    naclports.Log('Downloading prebuilt binary ...')
    naclports.DownloadFile(filename, info['BIN_URL'])
    if not VerifyHash(filename, info['BIN_SHA1']):
      raise naclports.Error('Unexepected SHA1: %s' % filename)
    return filename

  def ParseIndex(self, index_data):
    if not index_data:
      return

    for pkg_info in index_data.split('\n\n'):
      info = naclports.ParsePkgInfo(pkg_info, self.filename,
                                    self.valid_keys, self.required_keys)
      debug = info['BUILD_CONFIG'] == 'debug'
      config = configuration.Configuration(info['BUILD_ARCH'],
                                           info['BUILD_TOOLCHAIN'],
                                           debug)
      key = (info['NAME'], config)
      if key in self.packages:
        naclports.Error('package index contains duplicate: %s' % str(key))
      self.packages[key] = info
