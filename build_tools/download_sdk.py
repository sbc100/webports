#!/usr/bin/python
# Copyright (c) 2012 The Native Client Authors. All rights reserved.
# Use of this source code is governed by a BSD-style license that can be
# found in the LICENSE file.
#

"""Download all Native Client toolchains for this platform.

This module downloads toolchain bz2's and expands them. It requires
gsutil to be in the bin PATH and assumes if building on windows that
cygwin is installed to \cygwin

On windows this script also required access to the cygtar python
module which gets included by the gclient DEPS.
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

if sys.version_info < (2, 6, 0):
  sys.stderr.write("python 2.6 or later is required run this script\n")
  sys.exit(1)

if sys.version_info >= (3, 0, 0):
  sys.stderr.write("This script does not support python 3.\n")
  sys.exit(1)

SCRIPT_DIR = os.path.abspath(os.path.dirname(__file__))
SRC_DIR = os.path.dirname(SCRIPT_DIR)

if sys.platform == 'win32':
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
      print 'gsutil command failed: %s' % str(cmd)
      sys.exit(1)

    elements = p_stdout.splitlines()
    return [os.path.basename(os.path.normpath(e)) for e in elements]

  if version == 'latest':
    print 'Looking for latest SDK upload...'
    # List the top level of the nacl_sdk folder
    versions = GSList('')
    # Find all trunk revision
    versions = [v for v in versions if v.startswith('trunk')]

    # Look backwards through all trunk revisions
    for version_dir in reversed(sorted(versions)):
      contents = GSList(version_dir)
      if path in contents:
        version = version_dir.rsplit('.', 1)[1]
        break
    else:
      print "No SDK build found looking for: %s" % path
      sys.exit(1)

  return GSTORE + 'trunk.' + str(version) + '/' + path


def Untar(bz2_filename):
  if sys.platform == 'win32':
    tar_file = None
    try:
      print 'Unpacking tarball...'
      tar_file = cygtar.CygTar(bz2_filename, 'r:bz2')
      tar_file.Extract()
    except Exception, err:
      print 'Error unpacking %s' % str(err)
      sys.exit(1)
    finally:
      if tar_file:
        tar_file.Close()
  else:
    if subprocess.call(['tar', 'jxf', bz2_filename]):
      print 'Error unpacking'
      sys.exit(1)


def DownloadAndInstallSDK(url):
  # Pick target directory.
  target_dir = os.path.join(SRC_DIR, 'pepper_XX')

  bz2_dir = SCRIPT_DIR
  bz2_filename = os.path.join(bz2_dir, url.split('/')[-1])

  # Drop old versions.
  old_sdks = glob.glob(os.path.join(bz2_dir, 'pepper_*'))
  if old_sdks:
    print 'Cleaning up old SDKs...'
    if sys.platform in ['win32', 'cygwin']:
      cmd = [r'\cygwin\bin\rm.exe', '-rf']
    else:
      cmd = ['rm', '-rf']
    cmd += old_sdks
    returncode = subprocess.call(cmd)
    assert returncode == 0

  print 'Downloading "%s" to "%s"...' % (url, bz2_filename)
  sys.stdout.flush()

  # Download it.
  urlret = urllib.urlretrieve(url, bz2_filename)
  assert urlret[0] == bz2_filename

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
  print 'Create toolchain symlink "%s" -> "%s"' % (actual_dir, target_dir)
  if sys.platform in ['win32', 'cygwin']:
    cmd = (r'\cygwin\bin\rm.exe -rf ' + target_dir + ' && ' +
           r'\cygwin\bin\ln.exe -fsn ' + actual_dir + ' ' +  target_dir)
  else:
    cmd = ('rm -rf ' + target_dir + ' && ' +
           'ln -fsn ' + actual_dir + ' ' + target_dir)

  returncode = subprocess.call(cmd, shell=True)
  assert returncode == 0

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
      '-v', '--version', default='latest',
      help='which version of the toolchain to download')
  parser.add_option(
      '-f', '--flavor', default='auto',
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
  return 0

if __name__ == '__main__':
  sys.exit(main(sys.argv[1:]))
