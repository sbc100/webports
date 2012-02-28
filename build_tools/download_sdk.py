#!/usr/bin/python
# Copyright (c) 2012 The Native Client Authors. All rights reserved.
# Use of this source code is governed by a BSD-style license that can be
# found in the LICENSE file.
#

"""Download all Native Client toolchains for this platform.

This module downloads toolchain bz2's and expands them. It requires
gsutil to be in the bin PATH and assumes if building on windows that
cygwin is installed to C:\cygwin
"""

import glob
import optparse
import os
import re
import shutil
import stat
import subprocess
import sys
import tarfile
import tempfile
import time
import urllib

SCRIPT_DIR = os.path.abspath(os.path.dirname(__file__))
SRC_DIR = os.path.dirname(SCRIPT_DIR)
NACL_BUILD_DIR = os.path.join(SRC_DIR, 'native_client', 'build')

sys.path.append(NACL_BUILD_DIR)

import cygtar

BOT_GSUTIL = '/b/build/scripts/slave/gsutil'
LOCAL_GSUTIL = 'gsutil'
# For local testing on Windows
#LOCAL_GSUTIL = 'python.exe C:\\bin\\gsutil\\gsutil'

GSTORE = 'http://commondatastorage.googleapis.com/'\
         'nativeclient-mirror/nacl/nacl_sdk/'

def DetermineSdkURL(flavor, base_url, version):
  """Download one Native Client toolchain and extract it.

  Arguments:
    flavor: flavor of the sdk to download
    base_url: base url to download toolchain tarballs from
    version: version directory to select tarballs from
  """
  if os.environ.get('BUILDBOT_BUILDERNAME', ''):
    gsutil = BOT_GSUTIL
  else:
    gsutil = LOCAL_GSUTIL

  path = flavor + '.bz2'

  if version == 'latest':
    print 'Looking for latest SDK upload...'
    # Resolve wildcards and pick the highest version
    p = subprocess.Popen(
        ' '.join(gsutil.split() + ['ls',
        base_url + 'trunk.*/' + path]),
        stdout=subprocess.PIPE,
        shell=True)
    (p_stdout, _) = p.communicate()
    assert p.returncode == 0
    versions = p_stdout.splitlines()
    newest = None
    for version in versions:
      m = re.match(base_url.replace(':', '\:').replace('/', '\/') +
                   'trunk\.(.*)/' + path, version)
      if m:
        rev = int(m.group(1))
        if not newest or rev > newest:
          newest = rev
    assert newest
    version = newest

  return GSTORE + 'trunk.' + str(version) + '/' + path


def DownloadAndInstallSDK(url):
  # Pick target directory.
  toolchain_dir = os.path.join(SRC_DIR, 'toolchain')

  bz2_dir = SCRIPT_DIR
  bz2_filename = os.path.join(bz2_dir, url.split('/')[-1])

  # Drop old versions.
  old_sdks = glob.glob(os.path.join(bz2_dir, 'pepper_*'))
  if len(old_sdks) > 0:
    print 'Cleaning up old SDKs...'
    if sys.platform in ['win32', 'cygwin']:
      cmd = r'C:\cygwin\bin\rm.exe -rf "%s"' % '" "'.join(old_sdks)
    else:
      cmd = 'rm -rf "%s"' % '" "'.join(old_sdks)
    p = subprocess.Popen(cmd, shell=True)
    p.communicate()
    assert p.returncode == 0

  print 'Downloading "%s" to "%s"...' % (url, bz2_filename)
  sys.stdout.flush()

  # Download it.
  urlret = urllib.urlretrieve(url, bz2_filename)
  assert urlret[0] == bz2_filename

  # Extract toolchain.
  old_cwd = os.getcwd()
  os.chdir(bz2_dir)
  tar_file = None
  try:
    print 'Unpacking tarball...'
    tar_file = cygtar.CygTar(bz2_filename, 'r:bz2')
    names = tar_file.tar.getnames()
    pepper_dir = os.path.commonprefix(names)
    tar_file.Extract()
  except Exception, err:
    print 'Error unpacking %s' % str(err)
    sys.exit(1)
  finally:
    if tar_file:
      tar_file.Close()

  os.chdir(old_cwd)

  actual_dir = os.path.join(bz2_dir, pepper_dir, 'toolchain')
  print 'Create toolchain symlink "%s" -> "%s"' % (actual_dir, toolchain_dir)
  if sys.platform in ['win32', 'cygwin']:
    cmd = (r'C:\cygwin\bin\rm.exe -rf ' + toolchain_dir + ' && ' +
           r'C:\cygwin\bin\ln.exe -fsn ' + actual_dir + ' ' +  toolchain_dir)
  else:
    cmd = ('rm -rf ' + toolchain_dir + ' && ' +
           'ln -fsn ' + actual_dir + ' ' + toolchain_dir)

  p = subprocess.Popen(cmd, shell=True)
  p.communicate()
  assert p.returncode == 0

  # Clean up: remove the sdk bz2.
  time.sleep(2)  # Wait for windows.
  os.remove(bz2_filename)

  print 'Install complete.'


PLATFORM_COLLAPSE = {
    'win32': 'win',
    'cygwin': 'win',
    'linux': 'linux',
    'linux2': 'linux',
    'darwin': 'mac',
}

def main(argv):
  parser = optparse.OptionParser()
  parser.add_option(
      '-v', '--version', dest='version',
      default='latest',
      help='which version of the toolchain to download')
  parser.add_option(
      '-f', '--flavor', dest='flavor',
      default='auto',
      help='which flavor of the toolchain to download, e.g. naclsdk_linux or ' +
           'pnaclsdk_linux')
  options, args = parser.parse_args(argv)
  if args:
    parser.print_help()
    print 'ERROR: invalid argument'
    sys.exit(1)

  flavor = options.flavor
  if flavor == 'auto':
    flavor = 'naclsdk_' + PLATFORM_COLLAPSE[sys.platform]

  url = DetermineSdkURL(flavor,
                        base_url='gs://nativeclient-mirror/nacl/nacl_sdk/',
                        version=options.version)
  print 'SDK URL is "%s"' % url

  DownloadAndInstallSDK(url)

if __name__ == '__main__':
  main(sys.argv[1:])
