# Copyright (c) 2014 The Native Client Authors. All rights reserved.
# Use of this source code is governed by a BSD-style license that can be
# found in the LICENSE file.

import os
import posixpath
import shutil
import tarfile

import naclports
import configuration

PAYLOAD_DIR = 'payload'
EXTRA_KEYS = ['BUILD_CONFIG', 'BUILD_ARCH', 'BUILD_TOOLCHAIN',
              'BUILD_SDK_VERSION', 'BUILD_NACLPORTS_REVISION']
VALID_KEYS = naclports.VALID_KEYS + EXTRA_KEYS
REQUIRED_KEYS = naclports.REQUIRED_KEYS + EXTRA_KEYS


class BinaryPackage(object):
  """Representation of binary package packge file.

  This class is initialised with the filename of a binary package
  and its attributes are set according the file name and contents.

  Operations such as installation can be performed on the package.
  """

  def __init__(self, filename):
    self.filename = filename
    if not os.path.exists(self.filename):
      raise naclports.Error('package not found: %s'% self.filename)
    basename, extension = os.path.splitext(os.path.basename(filename))
    basename = os.path.splitext(basename)[0]
    if extension != '.bz2':
      raise naclports.Error('invalid file extension: %s' % extension)

    try:
      with tarfile.open(self.filename) as tar:
        if './pkg_info' not in tar.getnames():
          raise PkgFormatError('package does not contain pkg_info file')
        info = tar.extractfile('./pkg_info')
        info = naclports.ParsePkgInfo(info.read(), filename,
                                      VALID_KEYS, REQUIRED_KEYS)
        for key, value in info.iteritems():
          setattr(self, key, value)
    except tarfile.TarError as e:
      raise naclports.PkgFormatError(e)

    self.config = configuration.Configuration(self.BUILD_ARCH,
                                              self.BUILD_TOOLCHAIN,
                                              self.BUILD_CONFIG == 'debug')

  def IsInstallable(self):
    """Determine if a binary package can be installed in the
    currently configured SDK.

    Currently only packages built with the same SDK major version
    are installable.
    """
    return self.BUILD_SDK_VERSION == naclports.GetSDKVersion()

  def InstallFile(self, filename, old_root, new_root):
    oldname = os.path.join(old_root, filename)
    if os.path.isdir(oldname):
      return

    naclports.Trace('install: %s' % filename)

    newname = os.path.join(new_root, filename)
    dirname = os.path.dirname(newname)
    if not os.path.isdir(dirname):
      os.makedirs(dirname)
    os.rename(oldname, newname)

  def RelocateFile(self, filename, dest):
    # Only relocate certain file types.
    modify = False

    # boost build scripts
    # TODO(sbc): move this to the boost package metadata
    if filename.startswith('build-1'):
      modify = True
    # pkg_config (.pc) files
    if filename.startswith('lib/pkgconfig'):
      modify = True
    if filename.startswith('share/pkgconfig'):
      modify = True
    # <foo>-config scripts that live in usr/bin
    if filename.startswith('bin') and filename.endswith('-config'):
      modify = True
    # libtool's .la files which can contain absolute paths to
    # dependencies.
    if filename.endswith('.la'):
      modify = True
    # headers can sometimes also contain absolute paths.
    if filename.startswith('include/') and filename.endswith('.h'):
      modify = True

    filename = os.path.join(dest, filename)
    if os.path.isdir(filename):
      return

    if modify:
      with open(filename) as f:
        data = f.read()
      mode = os.stat(filename).st_mode
      os.chmod(filename, 0777)
      with open(filename, 'r+') as f:
        f.write(data.replace('/naclports-dummydir', dest))
      os.chmod(filename, mode)

  def GetPkgInfo(self):
    with tarfile.open(self.filename) as tar:
      return tar.extractfile('./pkg_info').read()

  def Install(self):
    """Install binary package into toolchain directory."""
    dest = naclports.GetInstallRoot(self.config)
    dest_tmp = os.path.join(dest, 'install_tmp')
    if os.path.exists(dest_tmp):
      shutil.rmtree(dest_tmp)

    naclports.Log("Installing '%s' [%s]" % (self.NAME, self.config))
    os.makedirs(dest_tmp)

    try:
      with tarfile.open(self.filename) as tar:
        names = []
        for info in tar:
          if info.isdir():
            continue
          name = posixpath.normpath(info.name)
          if name == 'pkg_info':
            continue
          if not name.startswith(PAYLOAD_DIR + '/'):
            raise naclports.PkgFormatError('invalid file in package: %s' % name)

          name = name[len(PAYLOAD_DIR) + 1:]
          names.append(name)

        tar.extractall(dest_tmp)

      payload_tree = os.path.join(dest_tmp, PAYLOAD_DIR)
      for name in names:
        self.InstallFile(name, payload_tree, dest)

      for name in names:
        self.RelocateFile(name, dest)

      self.WriteFileList(names)
      self.WriteStamp()
    finally:
      shutil.rmtree(dest_tmp)

  def WriteStamp(self):
    """Write stamp file containing pkg_info."""
    filename = naclports.GetInstallStamp(self.NAME, self.config)
    naclports.Trace('stamp: %s' % filename)
    pkg_info = self.GetPkgInfo()
    with open(filename, 'w') as f:
      f.write(pkg_info)

  def WriteFileList(self, file_names):
    filename = naclports.GetFileList(self.NAME, self.config)
    dirname = os.path.dirname(filename)
    if not os.path.isdir(dirname):
      os.makedirs(dirname)
    with open(filename, 'w') as f:
      for name in file_names:
        f.write(name + '\n')
