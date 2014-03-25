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

MIRROR_URL = 'http://storage.googleapis.com/naclports/mirror/'
SCRIPT_DIR = os.path.dirname(os.path.abspath(__file__))
NACLPORTS_ROOT = os.path.dirname(SCRIPT_DIR)
OUT_DIR = os.path.join(NACLPORTS_ROOT, 'out')
STAMP_DIR = os.path.join(OUT_DIR, 'stamp')
BUILD_ROOT = os.path.join(OUT_DIR, 'repository')
ARCHIVE_ROOT = os.path.join(OUT_DIR, 'tarballs')
PACKAGES_ROOT = os.path.join(OUT_DIR, 'packages')
PUBLISH_ROOT = os.path.join(OUT_DIR, 'publish')
PAYLOAD_DIR = 'payload/'

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


def WriteStamp(filename, contents=''):
  """Write a file with the give filename and contents."""
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
      if f.read() != contents:
        return False

  return True


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


def GetToolchainRoot(arch=None, libc=None):
  """Returns the toolchain folder for a given NaCl toolchain."""
  import getos
  platform = getos.GetPlatform()
  if arch == 'pnacl':
    tc_dir = '%s_pnacl' % platform
  else:
    tc_arch = {
      'arm': 'arm',
      'i686': 'x86',
      'x86_64': 'x86'
    }[arch]
    tc_dir = '%s_%s_%s' % (platform, tc_arch, libc)
    tc_dir = os.path.join(tc_dir, '%s-nacl' % arch)

  return os.path.join(NACL_SDK_ROOT, 'toolchain', tc_dir)


def GetInstallRoot(arch, libc):
  """Returns the installation used by naclports within a given toolchain."""
  tc_root = GetToolchainRoot(arch, libc)
  return os.path.join(tc_root, 'usr')


def GetInstallStampRoot(arch, libc):
  tc_root = GetInstallRoot(arch, libc)
  return os.path.join(tc_root, 'var', 'lib', 'npkg')


def GetInstallStamp(pkg_basename):
  root = GetInstallStampRoot(GetCurrentArch(), GetCurrentLibc())
  return os.path.join(root, pkg_basename)


def IsInstalled(pkg_basename):
  stamp = GetInstallStamp(pkg_basename)
  return CheckStamp(stamp)


def PackageFile(pkg_basename):
  arch = GetCurrentArch()
  pkg_fullname = os.path.join(PACKAGES_ROOT, pkg_basename) + '-' + GetCurrentArch()
  if arch != 'pnacl':
    pkg_fullname += '-' + GetCurrentLibc()
  if os.environ.get('NACL_DEBUG') == '1':
    pkg_fullname += '-debug'
  return pkg_fullname + '.tar.bz2'



class BinaryPackage(object):
  def __init__(self, filename):
    self.filename = filename
    if not os.path.exists(self.filename):
      raise Error('package not found: %s'% self.filename)
    basename, extension = os.path.splitext(os.path.basename(filename))
    basename = os.path.splitext(basename)[0]
    if extension != '.bz2':
      raise Error('invalid file extension: %s' % extension)
    if '-' not in basename:
      raise Error('package filename must contain an hyphen: %s' % basename)
    parts = basename.split('-')
    if parts[-1] == 'debug':
      parts = parts[:-1]
    if parts[-1] in ('newlib', 'glibc'):
      self.libc = parts[-1]
      parts = parts[:-1]
    else:
      self.libc = 'newlib'
    self.arch = parts[-1]
    parts = parts[:-1]
    self.name = '-'.join(parts)

  def IsInstalled(self):
    GetInstallStamp(self.name)

  def InstallFile(self, filename, old_root, new_root):
    oldname = os.path.join(old_root, filename)
    if os.path.isdir(oldname):
      return

    if not filename.startswith(PAYLOAD_DIR):
      return

    newname = filename[len(PAYLOAD_DIR):]

    newname = os.path.join(new_root, newname)
    dirname = os.path.dirname(newname)
    if not os.path.isdir(dirname):
      os.makedirs(dirname)
    os.rename(oldname, newname)

  def RelocateFile(self, filename, dest):
    # Only relocate files in the payload.
    if not filename.startswith(PAYLOAD_DIR):
      return

    # Only relocate certain file types.
    filename = filename[len(PAYLOAD_DIR):]
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
    dest = GetInstallRoot(self.arch, self.libc)
    dest_tmp = os.path.join(dest, 'install_tmp')
    if os.path.exists(dest_tmp):
      shutil.rmtree(dest_tmp)

    Log("Installing '%s' [%s]" % (self.name, self.arch))
    os.makedirs(dest_tmp)

    try:
      with tarfile.open(self.filename) as t:
        names = [posixpath.normpath(name) for name in t.getnames()]
        if 'pkg_info' not in names:
          raise Error('package does not contain pkg_info file')
        for name in names:
          if name not in ('.', 'pkg_info', 'payload'):
            if not name.startswith(PAYLOAD_DIR):
              raise Error('invalid file in package: %s' % name)
        t.extractall(dest_tmp)

      for name in names:
        self.InstallFile(name, dest_tmp, dest)

      for name in names:
        self.RelocateFile(name, dest)

      with open(os.path.join(dest_tmp, 'pkg_info')) as f:
        pkg_info = f.read()
      WriteStamp(GetInstallStamp(self.name), pkg_info)
    finally:
      shutil.rmtree(dest_tmp)


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

  def InstallDeps(self, verbose, force):
    for dep in self.DEPENDS:
      if not IsInstalled(dep):
        dep_dir = os.path.join(os.path.dirname(self.root), dep)
        dep = Package(dep_dir)
        try:
          dep.Install(verbose, True, force)
        except DisabledError as e:
          Log(str(e))

  def PackageFile(self):
    return PackageFile(self.basename)

  def IsInstalled(self):
    return IsInstalled(self.basename)

  def IsBuilt(self):
    return os.path.exists(self.PackageFile())

  def Install(self, verbose, build_deps, force=None):
    force_install = force in ('build', 'install', 'all')

    if not force_install and self.IsInstalled():
      Log("Already installed '%s' [%s]" % (self.basename, GetCurrentArch()))
      return

    if not self.IsBuilt() or force:
      self.Build(verbose, build_deps, force)

    BinaryPackage(self.PackageFile()).Install()


  def Build(self, verbose, build_deps, force=None):
    if build_deps or force == 'all':
      self.InstallDeps(verbose, force)

    annotate = os.environ.get('NACLPORTS_ANNOTATE') == '1'
    arch = GetCurrentArch()

    # When the annotator is enabled we print log the start of the build
    # early, so that even if the package is disabled, or already built
    # we see a BUILD_STEP for each package.
    if annotate:
      Log('@@@BUILD_STEP %s %s %s@@@' % (arch, GetCurrentLibc(),
          self.basename))

    self.CheckEnabled()

    force_build = force in ('build', 'all')
    if not force_build and self.IsBuilt():
      Log("Already built '%s' [%s]" % (self.basename, arch))
      return

    log_root = os.path.join(OUT_DIR, 'logs')
    if not os.path.isdir(log_root):
      os.makedirs(log_root)

    stdout = os.path.join(log_root, '%s.log' % self.basename)
    if os.path.exists(stdout):
      os.remove(stdout)

    if not annotate:
      if verbose:
        prefix = '*** '
      else:
        prefix = ''
      Log("%sBuilding '%s' [%s]" % (prefix, self.basename, arch))

    start = time.time()
    self.RunBuildSh(verbose, stdout)

    duration = FormatTimeDelta(time.time() - start)
    Log("Build complete '%s' [%s] [took %s]"
        % (self.basename, arch, duration))


  def RunBuildSh(self, verbose, stdout, args=None):
    build_port = os.path.join(SCRIPT_DIR, 'build_port.sh')
    cmd = [build_port]
    if args is not None:
      cmd += args

    if verbose:
      rtn = subprocess.call(cmd, cwd=self.root)
      if rtn != 0:
        raise Error("Building %s: failed." % (self.basename))
    else:
      with open(stdout, 'a+') as log_file:
        rtn = subprocess.call(cmd,
                              cwd=self.root,
                              stdout=log_file,
                              stderr=subprocess.STDOUT)
      if rtn != 0:
        with open(stdout) as log_file:
          sys.stdout.write(log_file.read())
        raise Error("Building '%s' failed." % (self.basename))


  def Verify(self, verbose=False):
    """Download upstream source and verify hash."""
    archive = self.DownloadLocation()
    if not archive:
      Log("no archive: %s" % self.basename)
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
                          % (self.basename, GetCurrentLibc()))

    if self.DISABLED_ARCH is not None:
      arch = GetCurrentArch()
      if arch == self.DISABLED_ARCH:
        raise DisabledError('%s: disabled for current arch: %s.'
                            % (self.basename, arch))

    if self.BUILD_OS is not None:
      import getos
      if getos.GetPlatform() != self.BUILD_OS:
        raise DisabledError('%s: can only be built on %s.'
                            % (self.basename, self.BUILD_OS))

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


def run_main(args):
  usage = "Usage: %prog [options] <command> [<package_dir>]"
  parser = optparse.OptionParser(description=__doc__, usage=usage)
  parser.add_option('-v', '--verbose', action='store_true',
                    help='Output extra information.')
  parser.add_option('--all', action='store_true',
                    help='Perform action on all known ports.')
  parser.add_option('-f', '--force', action='store_const', const='build',
                    dest='force', help='Force building specified targets, '
                    'even if timestamps would otherwise skip it.')
  parser.add_option('-F', '--force-all', action='store_const', const='all',
                    dest='force', help='Force building target and all '
                    'dependencies, even if timestamps would otherwise skip '
                    'them.')
  parser.add_option('--force-install', action='store_const', const='install',
                    dest='force', help='Force installing of ports')
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
      elif command == 'install':
        package.Install(verbose, options.build_deps, options.force)
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
      rmtree(GetInstallStampRoot(GetCurrentArch(), GetCurrentLibc()))
      if GetCurrentArch() != 'pnacl':
        # The install root in the PNaCl toolchain is currently shared with
        # system libraries and headers so we cant' remove it completely
        # without breaking the toolchain
        rmtree(GetInstallRoot(GetCurrentArch(), GetCurrentLibc()))
    else:
      for p in PackageIterator():
        if not p.DISABLED:
          DoCmd(p)
  else:
    for package_dir in package_dirs:
      p = Package(package_dir)
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
