# Copyright 2014 The Native Client Authors. All rights reserved.
# Use of this source code is governed by a BSD-style license that can be
# found in the LICENSE file.

import fcntl
import hashlib
import os
import shutil
import subprocess
import sys

from naclports import error, paths

GS_URL = 'http://storage.googleapis.com/'
GS_BUCKET = 'naclports'
GS_MIRROR_URL = '%s%s/mirror' % (GS_URL, GS_BUCKET)

arch_to_pkgarch = {
  'x86_64': 'x86-64',
  'i686': 'i686',
  'arm': 'arm',
  'pnacl': 'pnacl',
}

# Inverse of arch_to_pkgarch
pkgarch_to_arch = {v:k for k, v in arch_to_pkgarch.items()}

verbose = False


def Memoize(f):
  """Memoization decorator for functions taking one or more arguments."""
  class Memo(dict):
    def __init__(self, f):
      super(Memo, self).__init__()
      self.f = f

    def __call__(self, *args):
      return self[args]

    def __missing__(self, key):
      ret = self[key] = self.f(*key)
      return ret

  return Memo(f)


def SetVerbose(verbosity):
  global verbose
  verbose = verbosity


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

  raise error.Error('command not found: %s' % command_name)


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
  if hasattr(sys.stdout, 'fileno') and os.isatty(sys.stdout.fileno()):
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
    raise error.Error('Error downloading file: %s' % str(e))

  os.rename(temp_filename, filename)



def CheckStamp(filename, contents=None):
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


@Memoize
def GetSDKRoot():
  """Returns the root of the currently configured Native Client SDK."""
  root = os.environ.get('NACL_SDK_ROOT')
  if sys.platform == "cygwin":
    root = root.replace('\\', '/')
  return root


@Memoize
def GetSDKVersion():
  """Returns the version of the currently configured Native Client SDK."""
  getos = os.path.join(GetSDKRoot(), 'tools', 'getos.py')
  version = subprocess.check_output([getos, '--sdk-version']).strip()
  return version


@Memoize
def GetSDKRevision():
  """Returns the revision of the currently configured Native Client SDK."""
  getos = os.path.join(GetSDKRoot(), 'tools', 'getos.py')
  version = subprocess.check_output([getos, '--sdk-revision']).strip()
  return int(version)


@Memoize
def GetPlatform():
  """Returns the current platform name according getos.py."""
  getos = os.path.join(GetSDKRoot(), 'tools', 'getos.py')
  platform = subprocess.check_output([getos]).strip()
  return platform


@Memoize
def GetToolchainRoot(config):
  """Returns the toolchain folder for a given NaCl toolchain."""
  platform = GetPlatform()
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

  rtn = os.path.join(GetSDKRoot(), 'toolchain', tc_dir)

  # New PNaCl toolchains use 'le32-nacl'.
  # TODO: make this the default once pepper_39 hits stable.
  if config.toolchain == 'pnacl':
    pnacl_dir = os.path.join(rtn, 'le32-nacl')
    if os.path.exists(pnacl_dir):
      rtn = pnacl_dir
  return rtn


@Memoize
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


@Memoize
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


def CheckSDKRoot():
  """Check validity of NACL_SDK_ROOT."""
  root = GetSDKRoot()
  if not root:
    raise error.Error('$NACL_SDK_ROOT not set')

  if not os.path.isdir(root):
    raise error.Error('$NACL_SDK_ROOT does not exist: %s' % root)

  sentinel = os.path.join(root, 'tools', 'getos.py')
  if not os.path.exists(sentinel):
    raise error.Error("$NACL_SDK_ROOT (%s) doesn't look right. "
                      "Couldn't find sentinel file (%s)" % (root, sentinel))


def HashFile(filename):
  """Return the SHA1 (in hex format) of the contents of the given file."""
  block_size = 100 * 1024
  sha1 = hashlib.sha1()
  with open(filename) as f:
    while True:
      data = f.read(block_size)
      if not data:
        break
      sha1.update(data)
  return sha1.hexdigest()


class HashVerificationError(error.Error):
  pass


def VerifyHash(filename, sha1):
  """Return True if the sha1 of the given file match the sha1 passed in."""
  file_sha1 = HashFile(filename)
  if sha1 != file_sha1:
    raise HashVerificationError(
        'verification failed: %s\nExpected: %s\nActual: %s' %
            (filename, sha1, file_sha1))



def RemoveTree(directory):
  """Recursively remove a directory and its contents."""
  if not os.path.exists(directory):
    return
  if not os.path.isdir(directory):
    raise error.Error('RemoveTree: not a directory: %s', directory)
  shutil.rmtree(directory)


def RelPath(filename):
  """Return a pathname relative to the root the naclports src tree.

  This is used mostly to make output more readable when printing filenames."""
  return os.path.relpath(filename, paths.NACLPORTS_ROOT)


def Makedirs(directory):
  if os.path.isdir(directory):
    return
  if os.path.exists(directory):
    raise error.Error('mkdir: File exists and is not a directory: %s'
                      % directory)
  Log("mkdir: %s" % directory)
  os.makedirs(directory)


class Lock(object):
  """Per-directory flock()-based context manager

  This class will raise an exception if another process already holds the
  lock for the given directory.
  """
  def __init__(self, lock_dir):
    if not os.path.exists(lock_dir):
      Makedirs(lock_dir)
    self.file_name = os.path.join(lock_dir, 'naclports.lock')
    self.fd = open(self.file_name, 'w')

  def __enter__(self):
    try:
      fcntl.flock(self.fd, fcntl.LOCK_EX | fcntl.LOCK_NB)
    except Exception:
      raise error.Error("Unable to acquire lock (%s): Is naclports already "
                        "running?" % self.file_name)

  def __exit__(self, exc_type, exc_val, exc_tb):
    os.remove(self.file_name)
    self.fd.close()


class BuildLock(Lock):
  """Lock used when building a package (essentially a lock on OUT_DIR)"""
  def __init__(self):
    super(BuildLock, self).__init__(paths.OUT_DIR)


class InstallLock(Lock):
  """Lock used when installing/uninstalling package"""
  def __init__(self, config):
    root = GetInstallRoot(config)
    super(InstallLock, self).__init__(root)
