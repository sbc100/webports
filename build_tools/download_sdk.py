#!/usr/bin/env python
# Copyright (c) 2012 The Native Client Authors. All rights reserved.
# Use of this source code is governed by a BSD-style license that can be
# found in the LICENSE file.

"""Download Native Client SDK for the current platform.

This script downloads toolchain bz2's and expands them. It requires
gsutil to be in the bin PATH and assumes if building on windows that
cygwin is installed to /cygwin.

On Windows this script also required access to the cygtar python
module which gets included by the gclient DEPS.
"""

from __future__ import print_function

import argparse
import os
import subprocess
import sys
import tarfile
import time

SCRIPT_DIR = os.path.dirname(os.path.abspath(__file__))
NACLPORTS_ROOT = os.path.dirname(SCRIPT_DIR)
sys.path.append(os.path.join(NACLPORTS_ROOT, 'lib'))

import naclports
import naclports.source_package

HISTORY_SIZE = 500

if sys.version_info < (2, 6, 0):
  sys.stderr.write('python 2.6 or later is required run this script\n')
  sys.exit(1)

if sys.version_info >= (3, 0, 0):
  sys.stderr.write('This script does not support python 3.\n')
  sys.exit(1)

SCRIPT_DIR = os.path.abspath(os.path.dirname(__file__))
SRC_DIR = os.path.dirname(SCRIPT_DIR)
OUT_DIR = os.path.join(SRC_DIR, 'out')
TARGET_DIR = os.path.join(OUT_DIR, 'nacl_sdk')

if sys.platform == 'win32':
  NACL_BUILD_DIR = os.path.join(SRC_DIR, 'native_client', 'build')
  sys.path.append(NACL_BUILD_DIR)
  import cygtar  # pylint: disable=import-error

BOT_GSUTIL = '/b/build/scripts/slave/gsutil'
LOCAL_GSUTIL = 'gsutil'
# For local testing on Windows
#LOCAL_GSUTIL = 'python.exe C:\\bin\\gsutil\\gsutil'

GS_URL_BASE = 'gs://nativeclient-mirror/nacl/nacl_sdk/'
GSTORE = 'http://storage.googleapis.com/nativeclient-mirror/nacl/nacl_sdk/'



def DetermineSDKURL(flavor, base_url, version):
  """Download one Native Client toolchain and extract it.

  Arguments:
    flavor: flavor of the sdk to download
    base_url: base url to download toolchain tarballs from
    version: version directory to select tarballs from

  Returns:
    A tuple of the URL and version number.
  """
  if (os.environ.get('BUILDBOT_BUILDERNAME') and
      not os.environ.get('TEST_BUILDBOT')):
    gsutil = BOT_GSUTIL
    if not os.path.exists(gsutil):
      raise naclports.Error('gsutil not found at: %s' % gsutil)
  else:
    gsutil = LOCAL_GSUTIL

  if sys.platform in ['win32', 'cygwin']:
    gsutil += '.bat'

  path = flavor + '.tar.bz2'

  def GSList(path):
    """Run gsutil 'ls' on a path and return just the basenames of the
    elements within.
    """
    cmd = [gsutil, 'ls', base_url + path]
    p = subprocess.Popen(cmd, stdout=subprocess.PIPE)
    p_stdout = p.communicate()[0]
    if p.returncode:
      raise naclports.Error('gsutil command failed: %s' % str(cmd))

    elements = p_stdout.splitlines()
    return [os.path.basename(os.path.normpath(elem)) for elem in elements]

  if version == 'latest':
    print('Looking for latest SDK upload...')
    # List the top level of the nacl_sdk folder
    versions = GSList('')
    # Find all trunk revision
    versions = [v for v in versions if v.startswith('trunk')]

    # Look backwards through all trunk revisions
    # Only look back HISTORY_SIZE revisions so this script doesn't take
    # forever.
    versions = list(reversed(sorted(versions)))
    for version_dir in versions[:HISTORY_SIZE]:
      contents = GSList(version_dir)
      if path in contents:
        version = version_dir.rsplit('.', 1)[1]
        break
    else:
      raise naclports.Error('No SDK build (%s) found in last %d trunk builds' %
                            (path, HISTORY_SIZE))

  version = int(version)
  return ('%strunk.%d/%s' % (GSTORE, version, path), version)


def Untar(bz2_filename):
  if sys.platform == 'win32':
    tar_file = None
    try:
      print('Unpacking tarball...')
      tar_file = cygtar.CygTar(bz2_filename, 'r:bz2')
      tar_file.Extract()
    except Exception, err:
      raise naclports.Error('Error unpacking %s' % str(err))
    finally:
      if tar_file:
        tar_file.Close()
  else:
    if subprocess.call(['tar', 'jxf', bz2_filename]):
      raise naclports.Error('Error unpacking')


def FindCygwin():
  if os.path.exists(r'\cygwin'):
    return r'\cygwin'
  elif os.path.exists(r'C:\cygwin'):
    return r'C:\cygwin'
  else:
    raise naclports.Error(r'failed to find cygwin in \cygwin or c:\cygwin')


def DownloadAndInstallSDK(url):
  bz2_dir = OUT_DIR
  if not os.path.exists(bz2_dir):
    os.makedirs(bz2_dir)
  bz2_filename = os.path.join(bz2_dir, url.split('/')[-1])

  if sys.platform in ['win32', 'cygwin']:
    cygbin = os.path.join(FindCygwin(), 'bin')

  print('Downloading "%s" to "%s"...' % (url, bz2_filename))
  sys.stdout.flush()

  # Download it.
  naclports.DownloadFile(bz2_filename, url)

  # Extract toolchain.
  old_cwd = os.getcwd()
  os.chdir(bz2_dir)
  Untar(bz2_filename)
  os.chdir(old_cwd)

  # Calculate pepper_dir by taking common prefix of tar
  # file contents
  tar = tarfile.open(bz2_filename)
  names = tar.getnames()
  tar.close()
  pepper_dir = os.path.commonprefix(names)

  actual_dir = os.path.join(bz2_dir, pepper_dir)

  # Drop old versions.
  if os.path.exists(TARGET_DIR):
    print('Cleaning up old SDK...')
    if sys.platform in ['win32', 'cygwin']:
      cmd = [os.path.join(cygbin, 'bin', 'rm.exe'), '-rf']
    else:
      cmd = ['rm', '-rf']
    cmd.append(TARGET_DIR)
    returncode = subprocess.call(cmd)
    assert returncode == 0

  print('Renaming toolchain "%s" -> "%s"' % (actual_dir, TARGET_DIR))
  os.rename(actual_dir, TARGET_DIR)

  if sys.platform in ['win32', 'cygwin']:
    time.sleep(2)  # Wait for windows.

  # Clean up: remove the sdk bz2.
  os.remove(bz2_filename)

  print('Install complete.')


PLATFORM_COLLAPSE = {
    'win32': 'win',
    'cygwin': 'win',
    'linux': 'linux',
    'linux2': 'linux',
    'darwin': 'mac',
}


def main(argv):
  parser = argparse.ArgumentParser(description=__doc__)
  parser.add_argument('-v', '--version', default='latest',
      help='which version of the SDK to download')
  parser.add_argument('--bionic', action='store_true',
      help='download bionic version of the SDK (linux only).')
  options = parser.parse_args(argv)

  if options.bionic:
    flavor = 'naclsdk_bionic'
  else:
    flavor = 'naclsdk_' + PLATFORM_COLLAPSE[sys.platform]

  os.environ['NACL_SDK_ROOT'] = TARGET_DIR
  getos = os.path.join(TARGET_DIR, 'tools', 'getos.py')
  existing_version = 0
  if os.path.exists(getos):
    cmd = [sys.executable, getos, '--sdk-revision']
    existing_version = int(subprocess.check_output(cmd).strip())

  url, version = DetermineSDKURL(flavor,
                                 base_url=GS_URL_BASE,
                                 version=options.version)
  if version == existing_version:
    print('SDK revision %s already downloaded' % version)
    return 0

  DownloadAndInstallSDK(url)
  return 0


if __name__ == '__main__':
  try:
    rtn = main(sys.argv[1:])
  except naclports.Error as e:
    sys.stderr.write("error: %s\n" % str(e))
    rtn = 1
  sys.exit(rtn)
