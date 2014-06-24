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
import posixpath
import shlex
import shutil
import subprocess
import sys
import tarfile
import tempfile
import time
import urlparse

import sha1check

MIRROR_URL = 'http://storage.googleapis.com/naclports/mirror'
SCRIPT_DIR = os.path.dirname(os.path.abspath(__file__))
NACLPORTS_ROOT = os.path.dirname(SCRIPT_DIR)
PORTS_DIR = os.path.join(NACLPORTS_ROOT, "ports")
OUT_DIR = os.path.join(NACLPORTS_ROOT, 'out')
STAMP_DIR = os.path.join(OUT_DIR, 'stamp')
BUILD_ROOT = os.path.join(OUT_DIR, 'build')
ARCHIVE_ROOT = os.path.join(OUT_DIR, 'tarballs')
PACKAGES_ROOT = os.path.join(OUT_DIR, 'packages')
PUBLISH_ROOT = os.path.join(OUT_DIR, 'publish')
PAYLOAD_DIR = 'payload'

NACL_SDK_ROOT = os.environ.get('NACL_SDK_ROOT')

if NACL_SDK_ROOT:
  sys.path.append(os.path.join(NACL_SDK_ROOT, 'tools'))

arch_to_pkgarch = {
  'x86_64': 'x86-64',
  'i686': 'i686',
  'arm': 'arm',
  'pnacl': 'pnacl',
}

# Inverse of arch_to_pkgarch
pkgarch_to_arch = {v:k for k, v in arch_to_pkgarch.items()}

# TODO(sbc): use this code to replace the bash logic in build_tools/common.sh

class Error(Exception):
  pass


class PkgFormatError(Error):
  pass


class DisabledError(Error):
  pass


def FormatTimeDelta(delta):
  rtn = ''
  if delta > 60:
    mins = delta / 60
    rtn += '%dm' % mins
    delta -= mins * 60

  if delta:
    rtn += '%.0fs' % delta
  return rtn


def ParsePkgInfo(info_file, filename, valid_keys, required_keys):
  """Parse the contents of the given file-object as a pkg_info file.
  """
  rtn = {}

  def ParsePkgInfoLine(line, line_no):
    if '=' not in line:
      raise PkgFormatError('Invalid info line %s:%d' % (line_no, filename,
                                                        line_no))
    key, value = line.split('=', 1)
    key = key.strip()
    if key not in valid_keys:
      raise PkgFormatError("Invalid key '%s' in info file %s:%d" % (key,
                                                                    filename,
                                                                    line_no))
    value = value.strip()
    if value[0] == '(':
      array_value = []
      if value[-1] != ')':
        raise PkgFormatError('Error parsing %s:%d: %s (%s)' % (filename,
                                                               line_no,
                                                               key,
                                                               value))
      value = value[1:-1].split()
    else:
      value = shlex.split(value)[0]
    return (key, value)

  for i, line in enumerate(info_file):
    if line[0] == '#':
      continue
    key, value = ParsePkgInfoLine(line, i+1)
    rtn[key] = value

  for required_key in required_keys:
    if required_key not in rtn:
      raise PkgFormatError("Required key '%s' missing from info file: '%s'" %
                           (required_key, filename))
  return rtn


def WriteFileList(package_name, file_names, config):
  filename = GetFileList(package_name, config)
  with open(filename, 'w') as f:
    for name in file_names:
      f.write(name + '\n')


def WriteStamp(package_name, config, contents=''):
  """Write a file with the give filename and contents."""
  filename = GetInstallStamp(package_name, config)
  dirname = os.path.dirname(filename)
  if not os.path.isdir(dirname):
    os.makedirs(dirname)
  Trace('stamp: %s' % filename)
  with open(filename, 'w') as f:
    f.write(contents)


def CheckStamp(filename, contents=None, timestamp=None):
  """Check that a given stamp file is up-to-date.

  Returns False is the file does not exists or is older
  that that given comparison file, or does not contain
  the given contents.

  Return True otherwise.
  """
  if not os.path.exists(filename):
    return False

  if contents is not None:
    with open(filename) as f:
      if not f.read().startswith(contents):
        return False

  return True


def Log(message):
  """Log a message to the console (stdout)."""
  sys.stdout.write(str(message) + '\n')
  sys.stdout.flush()


def Warn(message):
  Log('warning: ' + message)


def Trace(message):
  if Trace.verbose:
    Log(message)
Trace.verbose = False


def GetSDKVersion():
  getos = os.path.join(NACL_SDK_ROOT, 'tools', 'getos.py')
  version = subprocess.check_output([getos, '--sdk-version']).strip()
  return version


def GetToolchainRoot(config):
  """Returns the toolchain folder for a given NaCl toolchain."""
  import getos
  platform = getos.GetPlatform()
  if config.toolchain == 'pnacl':
    tc_dir = '%s_pnacl' % platform
  else:
    tc_arch = {
      'arm': 'arm',
      'i686': 'x86',
      'x86_64': 'x86'
    }[config.arch]
    tc_dir = '%s_%s_%s' % (platform, tc_arch, config.toolchain)
    tc_dir = os.path.join(tc_dir, '%s-nacl' % config.arch)

  return os.path.join(NACL_SDK_ROOT, 'toolchain', tc_dir)


def GetInstallRoot(config):
  """Returns the installation used by naclports within a given toolchain."""
  tc_root = GetToolchainRoot(config)
  if config.toolchain == 'pnacl':
    return os.path.join(tc_root, 'usr', 'local')
  else:
    return os.path.join(tc_root, 'usr')


def GetInstallStampRoot(config):
  """Returns the installation metadata folder for the give configuration."""
  tc_root = GetInstallRoot(config)
  return os.path.join(tc_root, 'var', 'lib', 'npkg')


def GetInstallStamp(package_name, config):
  """Returns the filename of the install stamp for for a given package.

  This file is written at install time and contains metadata
  about the installed package.
  """
  root = GetInstallStampRoot(config)
  return os.path.join(root, package_name + '.info')


def GetFileList(package_name, config):
  """Returns the filename of the list of installed files for a given package.

  This file is written at install time.
  """
  root = GetInstallStampRoot(config)
  return os.path.join(root, package_name + '.list')


def IsInstalled(package_name, config, stamp_content=None):
  """Returns True if the given package is installed."""
  stamp = GetInstallStamp(package_name, config)
  result = CheckStamp(stamp, stamp_content)
  Trace("IsInstalled: %s -> %s" % (package_name, result))
  return result


def RemoveEmptryDirs(dirname):
  """Recursively remove a directoy and its parents if they are empty."""
  while not os.listdir(dirname):
    os.rmdir(dirname)
    dirname = os.path.dirname(dirname)


class Configuration(object):
  """Class representing the build configuration for naclports packages.

  This consists of the following attributes:
    toolchain   - newlib, glibc, bionic, pnacl
    arch        - x86_64, x86_32, arm, pnacl
    debug       - True/False
    config_name - 'debug' or 'release'

  If not specified in the constructor these are read from the
  environment variables (TOOLCHAIN, NACL_ARCH, NACL_DEBUG).
  """
  default_toolchain = 'newlib'
  default_arch = 'x86_64'

  def __init__(self, arch=None, toolchain=None, debug=None):
    self.SetConfig(debug)

    if arch is None:
      arch = os.environ.get('NACL_ARCH')

    if toolchain is None:
      toolchain = os.environ.get('TOOLCHAIN')

    if not toolchain:
      if arch == 'pnacl':
        toolchain = 'pnacl'
      else:
        toolchain = self.default_toolchain
    self.toolchain = toolchain

    if not arch:
      if self.toolchain == 'pnacl':
        arch = 'pnacl'
      else:
        arch = self.default_arch
    self.arch = arch

    self.SetLibc()

  def SetConfig(self, debug):
    if debug is None:
      if os.environ.get('NACL_DEBUG') == '1':
        debug = True
      else:
        debug = False
    self.debug = debug
    if self.debug:
      self.config_name = 'debug'
    else:
      self.config_name = 'release'

  def SetLibc(self):
    if self.toolchain == 'pnacl':
      self.libc = 'newlib'
    else:
      self.libc = self.toolchain

  def __str__(self):
    return '%s/%s/%s' % (self.arch, self.libc, self.config_name)


class BinaryPackage(object):
  """Representation of binary package packge file.

  This class is initialised with the filename of a binary package
  and its attributes are set according the file name and contents.

  Operations such as installation can be performed on the package.
  """
  EXTRA_KEYS = ['BUILD_CONFIG', 'BUILD_ARCH', 'BUILD_TOOLCHAIN',
                'BUILD_SDK_VERSION', 'BUILD_NACLPORTS_REVISION']
  def __init__(self, filename):
    self.filename = filename
    if not os.path.exists(self.filename):
      raise Error('package not found: %s'% self.filename)
    basename, extension = os.path.splitext(os.path.basename(filename))
    basename = os.path.splitext(basename)[0]
    if extension != '.bz2':
      raise Error('invalid file extension: %s' % extension)

    try:
      with tarfile.open(self.filename) as tar:
        if './pkg_info' not in tar.getnames():
          raise PkgFormatError('package does not contain pkg_info file')
        info = tar.extractfile('./pkg_info')
        valid_keys = Package.VALID_KEYS + BinaryPackage.EXTRA_KEYS
        required_keys = Package.REQUIRED_KEYS + BinaryPackage.EXTRA_KEYS
        info = ParsePkgInfo(info, filename, valid_keys, required_keys)
        for key, value in info.iteritems():
          setattr(self, key, value)
    except tarfile.TarError as e:
      raise PkgFormatError(e)

    self.config = Configuration(self.BUILD_ARCH,
                                self.BUILD_TOOLCHAIN,
                                self.BUILD_CONFIG == 'debug')

  def IsInstallable(self):
    """Determine if a binary package can be installed in the
    currently configured SDK.

    Currently only packages built with the same SDK major version
    are installable.
    """
    return self.BUILD_SDK_VERSION == GetSDKVersion()

  def InstallFile(self, filename, old_root, new_root):
    oldname = os.path.join(old_root, filename)
    if os.path.isdir(oldname):
      return

    Trace('install: %s' % filename)

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
    # <foo>-config scripts that live in usr/bin
    if filename.startswith('bin') and filename.endswith('-config'):
      modify = True
    # libtool's .la files which can contain absolute paths to
    # dependencies.
    if filename.startswith('lib/') and filename.endswith('.la'):
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
      with open(filename, 'r+') as f:
        f.write(data.replace('/naclports-dummydir', dest))

  def Install(self):
    """Install binary package into toolchain directory."""
    dest = GetInstallRoot(self.config)
    dest_tmp = os.path.join(dest, 'install_tmp')
    if os.path.exists(dest_tmp):
      shutil.rmtree(dest_tmp)

    Log("Installing '%s' [%s]" % (self.NAME, self.config))
    os.makedirs(dest_tmp)

    try:
      with tarfile.open(self.filename) as tar:
        if './pkg_info' not in tar.getnames():
          raise PkgFormatError('package does not contain pkg_info file')

        names = []
        for info in tar:
          if info.isdir():
            continue
          name = posixpath.normpath(info.name)
          if name == 'pkg_info':
            continue
          if not name.startswith(PAYLOAD_DIR + '/'):
            raise PkgFormatError('invalid file in package: %s' % name)

          name = name[len(PAYLOAD_DIR) + 1:]
          names.append(name)

        tar.extractall(dest_tmp)

      payload_tree = os.path.join(dest_tmp, PAYLOAD_DIR)
      for name in names:
        self.InstallFile(name, payload_tree, dest)

      for name in names:
        self.RelocateFile(name, dest)

      with open(os.path.join(dest_tmp, 'pkg_info')) as f:
        pkg_info = f.read()
      WriteStamp(self.NAME, self.config, pkg_info)
      WriteFileList(self.NAME, names, self.config)
    finally:
      shutil.rmtree(dest_tmp)


class Package(object):
  """Representation of a single naclports source package.

  Package objects correspond to folders on disk which
  contain a 'pkg_info' file.
  """
  VALID_KEYS = ['NAME', 'VERSION', 'URL', 'ARCHIVE_ROOT', 'LICENSE', 'DEPENDS',
                'MIN_SDK_VERSION', 'LIBC', 'DISABLED_LIBC', 'ARCH',
                'DISABLED_ARCH', 'URL_FILENAME', 'BUILD_OS', 'SHA1', 'DISABLED']
  REQUIRED_KEYS = ['NAME', 'VERSION']
  VALID_SUBDIRS = ('', 'ports', 'python_modules')


  def __init__(self, pkg_root, config=None):
    if config is None:
      config = Configuration()
    self.config = config
    self.root = os.path.abspath(pkg_root)
    self.basename = os.path.basename(self.root)
    for key in Package.VALID_KEYS:
      setattr(self, key, None)
    self.DEPENDS = []
    self.info = os.path.join(self.root, 'pkg_info')
    if not os.path.exists(self.info):
      self.info = None
      for subdir in Package.VALID_SUBDIRS:
          info = os.path.join(PORTS_DIR, subdir, self.basename, 'pkg_info')
          if os.path.exists(info):
            self.info = info
            break
      if self.info is None:
        raise Error('Invalid package folder: %s' % pkg_root)
    self.root = os.path.dirname(self.info)

    # Parse pkg_info file
    with open(self.info) as f:
      info = ParsePkgInfo(f, self.info, Package.VALID_KEYS,
                          Package.REQUIRED_KEYS)

    # Set attributres based on pkg_info setttings.
    for key, value in info.items():
      setattr(self, key, value)

    if '_' in self.NAME:
      raise Error('%s: package NAME cannot contain underscores' % self.info)
    if '_' in self.VERSION:
      raise Error('%s: package VERSION cannot contain underscores' % self.info)
    if self.NAME != os.path.basename(self.root):
      raise Error('%s: package NAME must match directory name' % self.info)
    if self.DISABLED_ARCH is not None and self.ARCH is not None:
      raise Error('%s: contains both ARCH and DISABLED_ARCH' % self.info)
    if self.DISABLED_LIBC is not None and self.LIBC is not None:
      raise Error('%s: contains both LIBC and DISABLED_LIBC' % self.info)

  def __cmp__(self, other):
    return cmp(self.NAME, other.NAME)

  def CheckDeps(self, valid_dependencies):
    for dep in self.DEPENDS:
      if dep not in valid_dependencies:
        Log('%s: Invalid dependency: %s' % (self.info, dep))
        return False
    return True

  def GetBasename(self):
    basename = os.path.splitext(self.GetArchiveFilename())[0]
    if basename.endswith('.tar'):
      basename = os.path.splitext(basename)[0]
    return basename

  def GetBuildLocation(self):
    package_dir = self.ARCHIVE_ROOT or '%s-%s' % (self.NAME, self.VERSION)
    return os.path.join(BUILD_ROOT, self.NAME, package_dir)

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

  def InstallDeps(self, verbose, force):
    for dep in self.DEPENDS:
      if not IsInstalled(dep, self.config) or force == 'all':
        dep_dir = os.path.join(os.path.dirname(self.root), dep)
        dep = Package(dep_dir, self.config)
        try:
          dep.Install(verbose, True, force)
        except DisabledError as e:
          Log(str(e))

  def PackageFile(self):
    fullname = [os.path.join(PACKAGES_ROOT, self.NAME)]
    fullname.append(self.VERSION)
    fullname.append(arch_to_pkgarch[self.config.arch])
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
    info_content += 'BUILD_SDK_VERSION=%s\n' % GetSDKVersion()
    return info_content

  def IsInstalled(self):
    return IsInstalled(self.NAME, self.config, self.InstalledInfoContents())

  def IsBuilt(self):
    package_file = self.PackageFile()
    if not os.path.exists(package_file):
      return False
    try:
      package = BinaryPackage(package_file)
    except PkgFormatError as e:
      # If the package is malformed in some way or in some old format
      # then treat it as not built.
      return False
    return package.IsInstallable()

  def Install(self, verbose, build_deps, force=None):
    if force is None and self.IsInstalled():
      Log("Already installed '%s' [%s]" % (self.NAME, self.config))
      return

    if build_deps:
      self.InstallDeps(verbose, force)

    if not self.IsBuilt() or force:
      self.Build(verbose, build_deps, force)

    BinaryPackage(self.PackageFile()).Install()

  def Uninstall(self, ignore_missing):
    if not os.path.exists(GetInstallStamp(self.NAME, self.config)):
      if ignore_missing:
        return
      raise Error('Package not installed: %s [%s]' % (self.NAME, self.config))

    Log("Uninstalling '%s' [%s]" % (self.NAME, self.config))
    file_list = GetFileList(self.NAME, self.config)
    if not os.path.exists(file_list):
      Log('No files to uninstall')
    else:
      root = GetInstallRoot(self.config)
      with open(file_list) as f:
        for line in f:
          filename = os.path.join(root, line.strip())
          if not os.path.lexists(filename):
            Warn('File not found while uninstalling: %s' % filename)
            continue
          Trace('rm %s' % filename)
          os.remove(filename)
          RemoveEmptryDirs(os.path.dirname(filename))

      os.remove(file_list)
    os.remove(GetInstallStamp(self.NAME, self.config))

  def Build(self, verbose, build_deps, force=None):
    self.CheckEnabled()

    if build_deps:
      self.InstallDeps(verbose, force)

    if not force and self.IsBuilt():
      Log("Already built '%s' [%s]" % (self.NAME, self.config))
      return

    log_root = os.path.join(OUT_DIR, 'logs')
    if not os.path.isdir(log_root):
      os.makedirs(log_root)

    stdout = os.path.join(log_root, '%s.log' % self.NAME)
    if os.path.exists(stdout):
      os.remove(stdout)

    if verbose:
      prefix = '*** '
    else:
      prefix = ''
    Log("%sBuilding '%s' [%s]" % (prefix, self.NAME, self.config))

    start = time.time()
    self.RunBuildSh(verbose, stdout)

    duration = FormatTimeDelta(time.time() - start)
    Log("Build complete '%s' [%s] [took %s]"
        % (self.NAME, self.config, duration))

  def RunBuildSh(self, verbose, stdout, args=None):
    build_port = os.path.join(SCRIPT_DIR, 'build_port.sh')
    cmd = [build_port]
    if args is not None:
      cmd += args

    env = os.environ.copy()
    env['TOOLCHAIN'] = self.config.toolchain
    env['NACL_ARCH'] = self.config.arch
    env['NACL_DEBUG'] = self.config.debug and '1' or '0'
    if verbose:
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

  def Verify(self, verbose=False):
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

    stamp_dir = os.path.join(STAMP_DIR, self.NAME)
    Log('removing %s' % stamp_dir)
    if os.path.exists(stamp_dir):
      shutil.rmtree(stamp_dir)

  def Extract(self):
    self.ExtractInto(os.path.join(BUILD_ROOT, self.NAME))

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

    tmp_output_path = tempfile.mkdtemp(dir=OUT_DIR)
    try:
      ext = os.path.splitext(archive)[1]
      if ext in ('.gz', '.tgz', '.bz2'):
        cmd = ['tar', 'xf', archive, '-C', tmp_output_path]
      elif ext in ('.zip',):
        cmd = ['unzip', '-q', '-d', tmp_output_path, archive]
      else:
        raise Error('unhandled extension: %s' % ext)
      Log("Extracting '%s'" % self.NAME)
      Trace(cmd)
      subprocess.check_call(cmd)
      src = os.path.join(tmp_output_path, new_foldername)
      os.rename(src, dest)
    finally:
      shutil.rmtree(tmp_output_path)

  def GetMirrorURL(self):
    return MIRROR_URL + '/' + self.GetArchiveFilename()

  def CheckEnabled(self):
    if self.LIBC is not None and self.LIBC != self.config.libc:
      raise DisabledError('%s: cannot be built with %s.'
                          % (self.NAME, self.config.libc))

    if self.DISABLED_LIBC is not None:
      if self.config.libc in self.DISABLED_LIBC:
        raise DisabledError('%s: cannot be built with %s.'
                            % (self.NAME, self.config.libc))

    if self.ARCH is not None:
      if self.config.arch not in self.ARCH:
        raise DisabledError('%s: disabled for current arch: %s.'
                            % (self.NAME, self.config.arch))

    if self.DISABLED_ARCH is not None:
      if self.config.arch in self.DISABLED_ARCH:
        raise DisabledError('%s: disabled for current arch: %s.'
                            % (self.NAME, self.config.arch))

    if self.BUILD_OS is not None:
      import getos
      if getos.GetPlatform() != self.BUILD_OS:
        raise DisabledError('%s: can only be built on %s.'
                            % (self.NAME, self.BUILD_OS))

  def Download(self, mirror=True):
    filename = self.DownloadLocation()
    if not filename or os.path.exists(filename):
      return
    if not os.path.exists(os.path.dirname(filename)):
      os.makedirs(os.path.dirname(filename))

    temp_filename = filename + '.partial'
    mirror_download_successfull = False
    curl_cmd = ['curl', '--fail', '--location', '--stderr', '-',
                '-o', temp_filename]
    if os.isatty(sys.stdout.fileno()):
      # Add --progress-bar but only if stdout is a TTY device.
      curl_cmd.append('--progress-bar')
    else:
      # otherwise suppress all status output, since curl always
      # assumes a TTY and writes \r and \b characters.
      curl_cmd.append('--silent')

    if mirror:
      try:
        mirror_url = self.GetMirrorURL()
        Log('Downloading: %s [%s]' % (mirror_url, temp_filename))
        subprocess.check_call(curl_cmd + [mirror_url])
        mirror_download_successfull = True
      except subprocess.CalledProcessError:
        pass

    if not mirror_download_successfull:
      Log('Downloading: %s [%s]' % (self.URL, temp_filename))
      subprocess.check_call(curl_cmd + [self.URL])

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


def run_main(args):
  usage = "Usage: %prog [options] <command> [<package_dir>]"
  parser = optparse.OptionParser(description=__doc__, usage=usage)
  parser.add_option('-v', '--verbose', action='store_true',
                    help='Output extra information.')
  parser.add_option('-V', '--verbose-build', action='store_true',
                    help='Make the build itself version (e.g. pass V=1 to make')
  parser.add_option('--all', action='store_true',
                    help='Perform action on all known ports.')
  parser.add_option('-f', '--force', action='store_const', const='build',
                    dest='force', help='Force building specified targets, '
                    'even if timestamps would otherwise skip it.')
  parser.add_option('-F', '--force-all', action='store_const', const='all',
                    dest='force', help='Force building target and all '
                    'dependencies, even if timestamps would otherwise skip '
                    'them.')
  parser.add_option('--no-deps', dest='build_deps', action='store_false',
                    default=True,
                    help='Disable automatic building of dependencies.')
  parser.add_option('--ignore-disabled', action='store_true',
                    help='Ignore attempts to build disabled packages.\n'
                    'Normally attempts to build such packages will result\n'
                    'in an error being returned.')
  parser.add_option('--toolchain',
                    help='Set toolchain to use when building (newlib, glibc, or'
                    ' pnacl)"')
  parser.add_option('--debug',
                    help='Build debug configuration (release is the default)')
  parser.add_option('--arch',
                    help='Set architecture to use when building (x86_64,'
                    ' x86_32, arm, pnacl)')
  options, args = parser.parse_args(args)
  if not args:
    parser.error('You must specify a sub-command. See --help.')

  command = args[0]

  verbose = options.verbose or os.environ.get('VERBOSE') == '1'
  Trace.verbose = verbose
  if options.verbose_build:
    os.environ['VERBOSE'] = '1'
  else:
    os.environ['VERBOSE'] = '0'
    os.environ['V'] = '0'

  if not NACL_SDK_ROOT:
    raise Error('$NACL_SDK_ROOT not set')

  if not os.path.isdir(NACL_SDK_ROOT):
    raise Error('$NACL_SDK_ROOT does not exist: %s' % NACL_SDK_ROOT)

  config = Configuration(options.arch, options.toolchain, options.debug)

  if command == 'list':
    for filename in os.listdir(GetInstallStampRoot(config)):
      basename, ext = os.path.splitext(filename)
      if ext != '.info':
        continue
      Log(basename)
    return 0
  elif command == 'info':
    if len(args) != 2:
      parser.error('info command takes a single package name')
    package_name = args[1]
    info_file = GetInstallStamp(package_name, config)
    print "Install receipt: %s" % info_file
    if not os.path.exists(info_file):
      raise Error('package not installed: %s [%s]' % (package_name, config))
    with open(info_file) as f:
      sys.stdout.write(f.read())
    return 0
  elif command == 'contents':
    if len(args) != 2:
      parser.error('contents command takes a single package name')
    package_name = args[1]
    list_file = GetFileList(package_name, config)
    if not os.path.exists(list_file):
      raise Error('package not installed: %s [%s]' % (package_name, config))
    with open(list_file) as f:
      sys.stdout.write(f.read())
    return 0

  package_dirs = ['.']
  if len(args) > 1:
    if options.all:
      parser.error('Package name and --all cannot be specified together')
    package_dirs = args[1:]

  def DoCmd(package):
    try:
      if command == 'download':
        package.Download()
      elif command == 'check':
        # Fact that we've got this far means the pkg_info
        # is basically valid.  This final check verifies the
        # dependencies are valid.
        package_names = [os.path.basename(p.root) for p in PackageIterator()]
        package.CheckDeps(package_names)
      elif command == 'enabled':
        package.CheckEnabled()
      elif command == 'verify':
        package.Verify()
      elif command == 'clean':
        package.Clean()
      elif command == 'build':
        package.Build(verbose, options.build_deps, options.force)
      elif command == 'install':
        package.Install(verbose, options.build_deps, options.force)
      elif command == 'uninstall':
        package.Uninstall(options.all)
      else:
        parser.error("Unknown subcommand: '%s'\n"
                     "See --help for available commands." % command)
    except DisabledError as e:
      if options.ignore_disabled:
        Log('naclports: %s' % e)
      else:
        raise e

  def rmtree(path):
    Log('removing %s' % path)
    if os.path.exists(path):
      shutil.rmtree(path)

  if options.all:
    options.ignore_disabled = True
    if command == 'clean':
      rmtree(STAMP_DIR)
      rmtree(BUILD_ROOT)
      rmtree(PACKAGES_ROOT)
      rmtree(PUBLISH_ROOT)
      rmtree(GetInstallStampRoot(config))
      rmtree(GetInstallRoot(config))
    else:
      for p in PackageIterator():
        if not p.DISABLED:
          DoCmd(p)
  else:
    for package_dir in package_dirs:
      p = Package(package_dir, config)
      DoCmd(p)


def main(args):
  try:
    run_main(args)
  except Error as e:
    sys.stderr.write('naclports: %s\n' % e)
    return 1

  return 0

if __name__ == '__main__':
  sys.exit(main(sys.argv[1:]))
