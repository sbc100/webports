# Copyright (c) 2013 The Native Client Authors. All rights reserved.
# Use of this source code is governed by a BSD-style license that can be
# found in the LICENSE file.

import fcntl
import os
import shlex
import shutil
import subprocess
import sys

SCRIPT_DIR = os.path.dirname(os.path.abspath(__file__))
NACLPORTS_ROOT = os.path.dirname(os.path.dirname(SCRIPT_DIR))

GS_BUCKET = 'naclports'
GS_URL = 'http://storage.googleapis.com/'
OUT_DIR = os.path.join(NACLPORTS_ROOT, 'out')
STAMP_DIR = os.path.join(OUT_DIR, 'stamp')
BUILD_ROOT = os.path.join(OUT_DIR, 'build')
PUBLISH_ROOT = os.path.join(OUT_DIR, 'publish')
TOOLS_DIR = os.path.join(NACLPORTS_ROOT, 'build_tools')
PACKAGES_ROOT = os.path.join(OUT_DIR, 'packages')

NACL_SDK_ROOT = os.environ.get('NACL_SDK_ROOT')
if sys.platform == "cygwin":
  NACL_SDK_ROOT = NACL_SDK_ROOT.replace('\\', '/')

VALID_KEYS = ['NAME', 'VERSION', 'URL', 'ARCHIVE_ROOT', 'LICENSE', 'DEPENDS',
              'MIN_SDK_VERSION', 'LIBC', 'DISABLED_LIBC', 'ARCH', 'CONFLICTS',
              'DISABLED_ARCH', 'URL_FILENAME', 'BUILD_OS', 'SHA1', 'DISABLED']
REQUIRED_KEYS = ['NAME', 'VERSION']

verbose = False

arch_to_pkgarch = {
  'x86_64': 'x86-64',
  'i686': 'i686',
  'arm': 'arm',
  'pnacl': 'pnacl',
}

# Inverse of arch_to_pkgarch
pkgarch_to_arch = {v:k for k, v in arch_to_pkgarch.items()}

if NACL_SDK_ROOT:
  sys.path.append(os.path.join(NACL_SDK_ROOT, 'tools'))


class Error(Exception):
  """General error used for all naclports-specific errors."""
  pass


class PkgFormatError(Error):
  """Error raised when package file is not valid."""
  pass


class DisabledError(Error):
  """Error raised when a package is cannot be built because it is disabled
  for the current configuration.
  """
  pass


def ParsePkgInfo(contents, filename, valid_keys=None, required_keys=None):
  """Parse the contents of the given file-object as a pkg_info file.

  Args:
    contents: pkg_info contents as a string.
    filename: name of file to use in error messages.
    valid_keys: list of keys that are valid in the file.
    required_keys: list of keys that are required in the file.

  Returns:
    A dictionary of the key, value pairs contained in the pkg_info file.

  Raises:
    PkgFormatError: if file is malformed, contains invalid keys, or does not
      contain all required keys.
  """
  rtn = {}
  if valid_keys is None:
    valid_keys = VALID_KEYS
  if required_keys is None:
    required_keys = REQUIRED_KEYS

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

  for i, line in enumerate(contents.splitlines()):
    if line[0] == '#':
      continue
    key, value = ParsePkgInfoLine(line, i+1)
    rtn[key] = value

  for required_key in required_keys:
    if required_key not in rtn:
      raise PkgFormatError("Required key '%s' missing from info file: '%s'" %
                           (required_key, filename))

  return rtn


def ParsePkgInfoFile(filename, valid_keys=None, required_keys=None):
  """Pasrse pkg_info from a file on disk."""
  with open(filename) as f:
    return ParsePkgInfo(f.read(), filename, valid_keys, required_keys)


def CheckStamp(filename, contents=None, timestamp=None):
  """Check that a given stamp file is up-to-date.

  Returns: False is the file does not exists or is older that that given
    comparison file, or does not contain the given contents. True otherwise.
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
  """Log a message to the console if running in verbose mode (-v)."""
  if verbose:
    Log(message)


def GetSDKVersion():
  """Returns the version of the currently configured Native Client SDK."""
  getos = os.path.join(NACL_SDK_ROOT, 'tools', 'getos.py')
  version = subprocess.check_output([getos, '--sdk-version']).strip()
  return version


def GetSDKRevision():
  """Returns the revision of the currently configured Native Client SDK."""
  getos = os.path.join(NACL_SDK_ROOT, 'tools', 'getos.py')
  version = subprocess.check_output([getos, '--sdk-revision']).strip()
  return int(version)


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

  rtn = os.path.join(NACL_SDK_ROOT, 'toolchain', tc_dir)

  # New PNaCl toolchains use 'le32-nacl'.
  # TODO: make this the default once pepper_39 hits stable.
  if config.toolchain == 'pnacl':
    pnacl_dir = os.path.join(rtn, 'le32-nacl')
    if os.path.exists(pnacl_dir):
      rtn = pnacl_dir
  return rtn


def GetInstallRoot(config):
  """Returns the installation used by naclports within a given toolchain."""
  tc_root = GetToolchainRoot(config)
  # TODO(sbc): drop the pnacl special case once 'le32-nacl/usr' is available
  # in the PNaCl default search path (should be once pepper_39 is stable).
  if config.toolchain == 'pnacl':
    if tc_root.endswith('le32-nacl'):
      if int(GetSDKVersion()) < 40:
        return os.path.join(tc_root, 'local')
      else:
        return os.path.join(tc_root, 'usr')
    else:
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


def GetListFile(package_name, config):
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


def FindInPath(command_name):
  """Search user's PATH for a given executable.

  Returns:
    Full path to executable.
  """
  if os.name == 'nt':
    extensions = ('.bat', '.com', '.exe')
  else:
    extensions = ('',)

  for path in os.environ.get('PATH', '').split(os.pathsep):
    for ext in extensions:
      full_name = os.path.join(path, command_name + ext)
      if os.path.exists(full_name):
        return full_name

  raise Error('command not found: %s' % command_name)


def DownloadFile(filename, url):
  """Download a file from a given URL.

  Args:
    filename: the name of the file to download the URL to.
    url: then URL to fetch.
  """
  temp_filename = filename + '.partial'
  # Ensure curl is in user's PATH
  FindInPath('curl')
  curl_cmd = ['curl', '--fail', '--location', '--stderr', '-',
              '-o', temp_filename]
  if os.isatty(sys.stdout.fileno()):
    # Add --progress-bar but only if stdout is a TTY device.
    curl_cmd.append('--progress-bar')
  else:
    # otherwise suppress all status output, since curl always
    # assumes a TTY and writes \r and \b characters.
    curl_cmd.append('--silent')
  curl_cmd.append(url)

  if verbose:
    Log('Downloading: %s [%s]' % (url, filename))
  else:
    Log('Downloading: %s' % url.replace(GS_URL, ''))
  try:
    subprocess.check_call(curl_cmd)
  except subprocess.CalledProcessError as e:
    raise Error('Error downloading file: %s' % str(e))

  os.rename(temp_filename, filename)


class Lock(object):
  """Per-directory flock()-based context manager

  This class will raise an exception if another process already holds the
  lock for the given directory.
  """
  def __init__(self, lock_dir):
    if not os.path.exists(lock_dir):
      os.makedirs(lock_dir)
    self.file_name = os.path.join(lock_dir, 'naclports.lock')
    self.fd = open(self.file_name, 'w')

  def __enter__(self):
    try:
      fcntl.flock(self.fd, fcntl.LOCK_EX | fcntl.LOCK_NB)
    except Exception as e:
      raise Error("Unable to acquire lock (%s): Is naclports already running?" %
          self.file_name)

  def __exit__(self, exc_type, exc_val, exc_tb):
    os.remove(self.file_name)
    self.fd.close()


class BuildLock(Lock):
  """Lock used when building a package (essentially a lock on OUT_DIR)"""
  def __init__(self):
    super(BuildLock, self).__init__(OUT_DIR)


class InstallLock(Lock):
  """Lock used when installing/uninstalling package"""
  def __init__(self, config):
    root = GetInstallRoot(config)
    super(InstallLock, self).__init__(root)
