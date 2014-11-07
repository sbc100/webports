# Copyright (c) 2014 The Native Client Authors. All rights reserved.
# Use of this source code is governed by a BSD-style license that can be
# found in the LICENSE file.

import os
import shutil
import subprocess
import sys
import tempfile
import time
import urlparse

import binary_package
import configuration
import naclports
import package
import package_index
import sha1check
from naclports import Log, Error, Trace, DisabledError, PkgFormatError

MIRROR_URL = '%s%s/mirror' % (naclports.GS_URL, naclports.GS_BUCKET)
CACHE_ROOT = os.path.join(naclports.OUT_DIR, 'cache')


class PkgConflictError(Error):
  pass


def FormatTimeDelta(delta):
  """Converts a duration in seconds to a human readable string.

  Args:
    delta: the amount of time in seconds.

  Returns: A string desribing the ammount of time passed in.
  """
  rtn = ''
  if delta >= 60:
    mins = delta / 60
    rtn += '%dm' % mins
    delta -= mins * 60

  if delta:
    rtn += '%.0fs' % delta
  return rtn


def ExtractArchive(archive, destination):
  ext = os.path.splitext(archive)[1]
  if ext in ('.gz', '.tgz', '.bz2'):
    cmd = ['tar', 'xf', archive, '-C', destination]
  elif ext in ('.zip',):
    cmd = ['unzip', '-q', '-d', destination, archive]
  else:
    raise Error('unhandled extension: %s' % ext)
  Trace(cmd)
  subprocess.check_call(cmd)


class SourcePackage(package.Package):
  """Representation of a single naclports source package.

  Package objects correspond to folders on disk which
  contain a 'pkg_info' file.
  """

  def __init__(self, pkg_root, config=None):
    if config is None:
      config = configuration.Configuration()
    self.config = config

    self.root = os.path.abspath(pkg_root)
    info_file = os.path.join(self.root, 'pkg_info')
    if not os.path.isdir(self.root) or not os.path.exists(info_file):
      raise Error('Invalid package folder: %s' % pkg_root)

    super(SourcePackage, self).__init__(info_file)
    if self.NAME != os.path.basename(self.root):
      raise Error('%s: package NAME must match directory name' % self.info)

  def GetBasename(self):
    basename = os.path.splitext(self.GetArchiveFilename())[0]
    if basename.endswith('.tar'):
      basename = os.path.splitext(basename)[0]
    return basename

  def GetBuildLocation(self):
    package_dir = self.ARCHIVE_ROOT or '%s-%s' % (self.NAME, self.VERSION)
    return os.path.join(naclports.BUILD_ROOT, self.NAME, package_dir)

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
    return os.path.join(CACHE_ROOT, archive)

  def IsInstalled(self):
    return naclports.IsInstalled(self.NAME, self.config,
                                 self.InstalledInfoContents())

  def InstallDeps(self, force, from_source=False):
    for dep in self.Dependencies():
      if not dep.IsAnyVersionInstalled() or force == 'all':
        dep.Install(True, force, from_source)

  def PackageFile(self):
    fullname = [os.path.join(naclports.PACKAGES_ROOT, self.NAME)]
    fullname.append(self.VERSION)
    fullname.append(naclports.arch_to_pkgarch[self.config.arch])
    # for pnacl toolchain and arch are the same
    if self.config.toolchain != self.config.arch:
      fullname.append(self.config.toolchain)
    if os.environ.get('NACL_DEBUG') == '1':
      fullname.append('debug')
    return '_'.join(fullname) + '.tar.bz2'

  def InstalledInfoContents(self):
    """Generate content of the .info file to install based on source
    pkg_info file and current build configuration."""
    with open(self.info) as f:
      info_content = f.read()
    info_content += 'BUILD_CONFIG=%s\n' % self.config.config_name
    info_content += 'BUILD_ARCH=%s\n' % self.config.arch
    info_content += 'BUILD_TOOLCHAIN=%s\n' % self.config.toolchain
    info_content += 'BUILD_SDK_VERSION=%s\n' % naclports.GetSDKVersion()
    return info_content

  def IsBuilt(self):
    package_file = self.PackageFile()
    if not os.path.exists(package_file):
      return False
    try:
      package = binary_package.BinaryPackage(package_file)
    except naclports.PkgFormatError as e:
      # If the package is malformed in some way or in some old format
      # then treat it as not built.
      return False
    return package.IsInstallable()

  def Install(self, build_deps, force=None, from_source=False):
    self.CheckInstallable()

    if force is None and self.IsInstalled():
      Log("Already installed %s" % self.InfoString())
      return

    if build_deps:
      self.InstallDeps(force, from_source)

    if force:
      from_source = True

    package_file = self.PackageFile()
    if not self.IsBuilt() and not from_source:
      index = package_index.GetCurrentIndex()
      if index.Installable(self.NAME, self.config):
        package_file = index.Download(self.NAME, self.config)
      else:
        from_source = True

    if from_source:
      self.Build(build_deps, force)

    if self.IsAnyVersionInstalled():
      Log("Uninstalling existing %s" % self.InfoString())
      self.GetInstalledPackage().DoUninstall()

    binary_package.BinaryPackage(package_file).Install()

  def GetInstalledPackage(self):
    return package.CreateInstalledPackage(self.NAME, self.config)

  def Build(self, build_deps, force=None):
    self.CheckBuildable()

    if build_deps:
      self.InstallDeps(force)

    if not force and self.IsBuilt():
      Log("Already built %s" % self.InfoString())
      return

    log_root = os.path.join(naclports.OUT_DIR, 'logs')
    if not os.path.isdir(log_root):
      os.makedirs(log_root)

    stdout = os.path.join(log_root, '%s.log' % self.NAME)
    if os.path.exists(stdout):
      os.remove(stdout)

    if naclports.verbose:
      prefix = '*** '
    else:
      prefix = ''
    Log("%sBuilding %s" % (prefix, self.InfoString()))

    start = time.time()
    with naclports.BuildLock():
      self.RunBuildSh(stdout)

    duration = FormatTimeDelta(time.time() - start)
    Log("Build complete %s [took %s]" % (self.InfoString(), duration))

  def RunBuildSh(self, stdout, args=None):
    build_port = os.path.join(naclports.TOOLS_DIR, 'build_port.sh')
    cmd = [build_port]
    if args is not None:
      cmd += args

    env = os.environ.copy()
    env['TOOLCHAIN'] = self.config.toolchain
    env['NACL_ARCH'] = self.config.arch
    env['NACL_DEBUG'] = self.config.debug and '1' or '0'
    if naclports.verbose:
      rtn = subprocess.call(cmd, cwd=self.root, env=env)
      if rtn != 0:
        raise Error("Building %s: failed." % (self.NAME))
    else:
      with open(stdout, 'a+') as log_file:
        rtn = subprocess.call(cmd,
                              cwd=self.root,
                              env=env,
                              stdout=log_file,
                              stderr=subprocess.STDOUT)
      if rtn != 0:
        with open(stdout) as log_file:
          sys.stdout.write(log_file.read())
        raise Error("Building '%s' failed." % (self.NAME))

  def Verify(self):
    """Download upstream source and verify hash."""
    archive = self.DownloadLocation()
    if not archive:
      Log("no archive: %s" % self.NAME)
      return True

    if self.SHA1 is None:
      Log("missing SHA1 attribute: %s" % self.info)
      return False

    self.Download()
    try:
      sha1check.VerifyHash(archive, self.SHA1)
      Log("verified: %s" % archive)
    except sha1check.Error as e:
      Log("verification failed: %s: %s" % (archive, str(e)))
      return False

    return True

  def Clean(self):
    pkg = self.PackageFile()
    Log('removing %s' % pkg)
    if os.path.exists(pkg):
      os.remove(pkg)

    stamp_dir = os.path.join(naclports.STAMP_DIR, self.NAME)
    Log('removing %s' % stamp_dir)
    if os.path.exists(stamp_dir):
      shutil.rmtree(stamp_dir)

  def Extract(self):
    self.ExtractInto(os.path.join(naclports.BUILD_ROOT, self.NAME))

  def ExtractInto(self, output_path):
    """Extract the package archive into the given location.

    This method assumes the package has already been downloaded.
    """
    archive = self.DownloadLocation()
    if not archive:
      return

    if not os.path.exists(output_path):
      os.makedirs(output_path)

    new_foldername = os.path.basename(self.GetBuildLocation())
    dest = os.path.join(output_path, new_foldername)
    if os.path.exists(dest):
      Trace('Already exists: %s' % dest)
      return

    tmp_output_path = tempfile.mkdtemp(dir=naclports.OUT_DIR)
    Log("Extracting '%s'" % self.NAME)
    try:
      ExtractArchive(archive, tmp_output_path)
      src = os.path.join(tmp_output_path, new_foldername)
      if not os.path.isdir(src):
        raise Error('Archive contents not found: %s' % src)
      Trace("renaming '%s' -> '%s'" % (src, dest))
      os.rename(src, dest)
    finally:
      shutil.rmtree(tmp_output_path)

  def GetMirrorURL(self):
    return MIRROR_URL + '/' + self.GetArchiveFilename()

  def CheckInstallable(self):
    if self.LIBC is not None and self.LIBC != self.config.libc:
      raise DisabledError('%s: cannot be built with %s'
                          % (self.NAME, self.config.libc))

    if self.DISABLED_LIBC is not None:
      if self.config.libc in self.DISABLED_LIBC:
        raise DisabledError('%s: cannot be built with %s'
                            % (self.NAME, self.config.libc))

    if self.ARCH is not None:
      if self.config.arch not in self.ARCH:
        raise DisabledError('%s: disabled for current arch: %s'
                            % (self.NAME, self.config.arch))

    if self.DISABLED_ARCH is not None:
      if self.config.arch in self.DISABLED_ARCH:
        raise DisabledError('%s: disabled for current arch: %s'
                            % (self.NAME, self.config.arch))

    for conflicting_package in self.CONFLICTS:
      if naclports.IsInstalled(conflicting_package, self.config):
        raise PkgConflictError("%s: conflicts with installed package: %s" %
            (self.NAME, conflicting_package))

    for dep in self.Dependencies():
      try:
        dep.CheckInstallable()
      except DisabledError as e:
        raise DisabledError('%s depends on %s; %s' % (self.NAME, dep.NAME, e))

  def Conflicts(self):
    """Yields the set of SourcePackages that directly conflict with this one"""
    for dep_name in self.CONFLICTS:
      yield CreatePackage(dep_name, self.config)

  def TransitiveConflicts(self):
    rtn = set(self.Conflicts())
    for dep in self.TransitiveDependencies():
      rtn |= set(dep.Conflicts())
    return rtn

  def Dependencies(self):
    """Yields the set of SourcePackages that this package directly depends on"""
    for dep_name in self.DEPENDS:
      yield CreatePackage(dep_name, self.config)

  def TransitiveDependencies(self):
    """Yields the set of packages that this package transitively depends on"""
    rtn = set(self.Dependencies())
    for dep in set(rtn):
      rtn |= dep.TransitiveDependencies()
    return rtn

  def CheckBuildable(self):
    self.CheckInstallable()

    if self.BUILD_OS is not None:
      import getos
      if getos.GetPlatform() != self.BUILD_OS:
        raise DisabledError('%s: can only be built on %s'
                            % (self.NAME, self.BUILD_OS))

  def Download(self, mirror=True):
    filename = self.DownloadLocation()
    if not filename or os.path.exists(filename):
      return
    if not os.path.exists(os.path.dirname(filename)):
      os.makedirs(os.path.dirname(filename))

    if mirror:
      # First try downloading form the mirror URL and silently fall
      # back to the original if this fails.
      mirror_url = self.GetMirrorURL()
      try:
        naclports.DownloadFile(filename, mirror_url)
        return
      except Error:
        pass

    naclports.DownloadFile(filename, self.URL)


def SourcePackageIterator():
  """Iterator which yields a Package object for each naclport package."""
  ports_root = os.path.join(naclports.NACLPORTS_ROOT, 'ports')
  for root, _, files in os.walk(ports_root):
    if 'pkg_info' in files:
      yield SourcePackage(root)

DEFAULT_LOCATIONS = ('ports', 'ports/python_modules')

def CreatePackage(package_name, config=None):
  """Create a Package object given a package name or path.

  Returns:
    Package object
  """
  if os.path.isdir(package_name):
    return SourcePackage(package_name, config)

  for subdir in DEFAULT_LOCATIONS:
    pkg_root = os.path.join(naclports.NACLPORTS_ROOT, subdir, package_name)
    info = os.path.join(pkg_root, 'pkg_info')
    if os.path.exists(info):
      return SourcePackage(pkg_root, config)

  raise Error("Package not found: %s" % package_name)
