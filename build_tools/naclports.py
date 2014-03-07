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
import time

import sha1check

MIRROR_URL = 'http://storage.googleapis.com/naclports/mirror/'
SCRIPT_DIR = os.path.dirname(os.path.abspath(__file__))
NACLPORTS_ROOT = os.path.dirname(SCRIPT_DIR)
OUT_DIR = os.path.join(NACLPORTS_ROOT, 'out')
STAMP_DIR = os.path.join(OUT_DIR, 'stamp')
BUILD_ROOT = os.path.join(OUT_DIR, 'repository')
ARCHIVE_ROOT = os.path.join(OUT_DIR, 'tarballs')
SENTINELS_ROOT = os.path.join(OUT_DIR, 'sentinels')

NACL_SDK_ROOT = os.environ.get('NACL_SDK_ROOT')

if NACL_SDK_ROOT:
  sys.path.append(os.path.join(NACL_SDK_ROOT, 'tools'))

# TODO(sbc): use this code to replace the bash logic in build_tools/common.sh

class Error(Exception):
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


def Touch(filename):
  Trace('touch %s' % filename)
  open(filename, 'w').close()


def Log(message):
  sys.stdout.write(message + '\n')
  sys.stdout.flush()


def Trace(message):
  if Trace.verbose:
    Log(message)
Trace.verbose = False


def GetCurrentArch():
  return os.environ.get('NACL_ARCH') or 'x86_64'


def GetCurrentLibc():
  if os.environ.get('NACL_GLIBC') == '1':
    return 'glibc'
  else:
    return 'newlib'


def GetDebug():
  if os.environ.get('NACL_DEBUG') == '1':
    return 'debug'
  else:
    return 'release'


def GetInstallRoot():
  import getos
  platform = getos.GetPlatform()
  if GetCurrentArch() == 'pnacl':
    tc_dir = '%s_pnacl' % platform
    subdir = 'sdk'
  else:
    arch = {
      'arm': 'arm',
      'i686': 'x86',
      'x86_64': 'x86'
    }[GetCurrentArch()]
    tc_dir = '%s_%s_%s' % (platform, arch, GetCurrentLibc())
    subdir = os.path.join('%s-nacl' % GetCurrentArch(), 'usr')

  return os.path.join(NACL_SDK_ROOT, 'toolchain', tc_dir, subdir)


def SentinelFile(pkg_basename):
  arch = GetCurrentArch()
  sentinel_dir = os.path.join(SENTINELS_ROOT, arch)
  if arch != 'pnacl':
    sentinel_dir += '_' + GetCurrentLibc()
  sentinel_dir += '_' + GetDebug()
  if not os.path.isdir(sentinel_dir):
    os.makedirs(sentinel_dir)
  return os.path.join(sentinel_dir, pkg_basename)


class Package(object):
  """Representation of a single naclports package.

  Package objects correspond to folders on disk which
  contain a 'pkg_info' file.
  """
  VALID_KEYS = ('URL', 'PACKAGE_NAME', 'LICENSE', 'DEPENDS', 'MIN_SDK_VERSION',
                'LIBC', 'DISABLED_ARCH', 'URL_FILENAME', 'PACKAGE_DIR',
                'BUILD_OS', 'SHA1', 'DISABLED')

  def __init__(self, pkg_root):
    self.root = os.path.abspath(pkg_root)
    self.basename = os.path.basename(self.root)
    self.info = os.path.join(pkg_root, 'pkg_info')
    keys = []
    for key in Package.VALID_KEYS:
      setattr(self, key, None)
    self.DEPENDS = []
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
    if key not in Package.VALID_KEYS:
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
    package_dir = self.PACKAGE_DIR or self.PACKAGE_NAME
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

  def Build(self, verbose, build_deps, force=None):
    if build_deps:
      for dep in self.DEPENDS:
        if force == 'all' or not os.path.exists(SentinelFile(dep)):
          dep_dir = os.path.join(os.path.dirname(self.root), dep)
          dep = Package(dep_dir)
          try:
            dep.Build(verbose, build_deps, force)
          except DisabledError as e:
            Log(str(e))

    annotate = os.environ.get('NACLPORTS_ANNOTATE') == '1'
    arch = GetCurrentArch()

    # When the annotator is enabled we print log the start of the build
    # early, so that even if the package is disabled, or already built
    # we see a BUILD_STEP for each package.
    if annotate:
      Log('@@@BUILD_STEP %s %s %s@@@' % (arch, GetCurrentLibc(),
          self.basename))

    self.CheckEnabled()

    sentinel = SentinelFile(self.basename)
    if force is None:
      if os.path.exists(sentinel):
        Log("Already built '%s' [%s]" % (self.PACKAGE_NAME, arch))
        return

    log_root = os.path.join(OUT_DIR, 'logs')
    if not os.path.isdir(log_root):
      os.makedirs(log_root)

    stdout = os.path.join(log_root, '%s.log' % self.PACKAGE_NAME)
    if os.path.exists(stdout):
      os.remove(stdout)

    if not annotate:
      if verbose:
        prefix = '*** '
      else:
        prefix = ''
      Log("%sBuilding '%s' [%s]" % (prefix, self.PACKAGE_NAME, arch))

    # Remove the sentinel file before building. If the build fails and the
    # sentinel already exists, the next build should not have to be forced.
    if os.path.exists(sentinel):
      os.remove(sentinel)

    start = time.time()
    self.RunBuildSh(verbose, stdout)

    # Build successful, write sentinel
    Touch(sentinel)

    duration = FormatTimeDelta(time.time() - start)
    Log("Build complete '%s' [%s] [took %s]"
        % (self.PACKAGE_NAME, arch, duration))

  def RunBuildSh(self, verbose, stdout, args=None):
    build_port = os.path.join(SCRIPT_DIR, 'build_port.sh')
    cmd = [build_port]
    if args is not None:
      cmd += args

    if verbose:
      rtn = subprocess.call(cmd, cwd=self.root)
      if rtn != 0:
        raise Error("Building %s: failed." % (self.PACKAGE_NAME))
    else:
      with open(stdout, 'a+') as log_file:
        rtn = subprocess.call(cmd,
                              cwd=self.root,
                              stdout=log_file,
                              stderr=subprocess.STDOUT)
      if rtn != 0:
        with open(stdout) as log_file:
          sys.stdout.write(log_file.read())
        raise Error("Building '%s' failed." % (self.PACKAGE_NAME))


  def Verify(self, verbose=False):
    """Download upstream source and verify hash."""
    archive = self.DownloadLocation()
    if not archive:
      Log("no archive: %s" % self.PACKAGE_NAME)
      return True

    if self.SHA1 is None:
      Log("missing SHA1 attribute: %s" % self.info)
      return False

    self.Download()
    olddir = os.getcwd()
    sha1file = os.path.join(self.root, self.PACKAGE_NAME + '.sha1')

    try:
      sha1check.VerifyHash(archive, self.SHA1)
      Log("verified: %s" % archive)
    except sha1check.Error as e:
      Log("verification failed: %s: %s" % (archive, str(e)))
      return False

    return True

  def Clean(self):
    sentinel = SentinelFile(self.basename)
    Log('removing %s' % sentinel)
    if os.path.exists(sentinel):
      os.remove(sentinel)

    stamp_dir = os.path.join(STAMP_DIR, self.basename)
    Log('removing %s' % stamp_dir)
    if os.path.exists(stamp_dir):
      shutil.rmtree(stamp_dir)

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
      Log(cmd)
      subprocess.check_call(cmd)
      src = os.path.join(tmp_output_path, new_foldername)
      dest = os.path.join(output_path, new_foldername)
      os.rename(src, dest)
    finally:
      shutil.rmtree(tmp_output_path)

  def GetMirrorURL(self):
    return MIRROR_URL + '/' + self.GetArchiveFilename()

  def CheckEnabled(self):
    if self.LIBC is not None and self.LIBC != GetCurrentLibc():
      raise DisabledError('%s: cannot be built with %s.'
                          % (self.PACKAGE_NAME, GetCurrentLibc()))

    if self.DISABLED_ARCH is not None:
      arch = GetCurrentArch()
      if arch == self.DISABLED_ARCH:
        raise DisabledError('%s: disabled for current arch: %s.'
                            % (self.PACKAGE_NAME, arch))

    if self.BUILD_OS is not None:
      import getos
      if getos.GetPlatform() != self.BUILD_OS:
        raise DisabledError('%s: can only be built on %s.'
                            % (self.PACKAGE_NAME, self.BUILD_OS))

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
        Log('Downloading: %s [%s]' % (mirror, temp_filename))
        cmd = ['wget', '-O', temp_filename, mirror]
        subprocess.check_call(cmd)
        mirror_download_successfull = True
      except subprocess.CalledProcessError:
        pass

    if not mirror_download_successfull:
      Log('Downloading: %s [%s]' % (self.URL, temp_filename))
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
    usage = "Usage: %prog [options] <command> [<package_dir>]"
    parser = optparse.OptionParser(description=__doc__, usage=usage)
    parser.add_option('-v', '--verbose', action='store_true',
                      help='Output extra information.')
    parser.add_option('--all', action='store_true',
                      help='Perform action on all known ports.')
    parser.add_option('-f', '--force', action='store_const', const='target',
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
    options, args = parser.parse_args(args)
    if not args:
      parser.error("You must specify a sub-command. See --help.")

    command = args[0]
    package_dirs = ['.']
    if len(args) > 1:
      if options.all:
        parser.error('Package name and --all cannot be specified together')
      package_dirs = args[1:]

    if not NACL_SDK_ROOT:
      raise Error("$NACL_SDK_ROOT not set")

    verbose = options.verbose or os.environ.get('VERBOSE') == '1'
    Trace.verbose = verbose

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
        rmtree(SENTINELS_ROOT)
        rmtree(BUILD_ROOT)
        if GetCurrentArch() != 'pnacl':
          # The install root in the PNaCl toolchain is currently shared with
          # system libraries and headers so we cant' remove it completely
          # without breaking the toolchain
          rmtree(GetInstallRoot())
      else:
        for p in PackageIterator():
          if not p.DISABLED:
            DoCmd(p)
    else:
      for package_dir in package_dirs:
        p = Package(package_dir)
        DoCmd(p)

  except Error as e:
    sys.stderr.write('naclports: %s\n' % e)
    return 1

  return 0


if __name__ == '__main__':
  sys.exit(main(sys.argv[1:]))
