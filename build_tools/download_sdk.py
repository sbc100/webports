#!/usr/bin/python
# Copyright (c) 2011 The Native Client Authors. All rights reserved.
# Use of this source code is governed by a BSD-style license that can be
# found in the LICENSE file.
#

"""Download all Native Client toolchains for this platform.

This module downloads multiple tgz's and expands them.
"""

import optparse
import os
import shutil
import stat
import subprocess
import sys
import tempfile
import time
import urllib


def DownloadSDK(platform, base_url, version):
  """Download one Native Client toolchain and extract it.

  Arguments:
    platform: platform of the sdk to download
    base_url: base url to download toolchain tarballs from
    version: version directory to select tarballs from
  """
  if sys.platform in ['win32', 'cygwin']:
    path = 'naclsdk_' + platform + '.exe'
  else:
    path = 'naclsdk_' + platform + '.tgz'
  url = base_url + version + '/' + path

  # Pick target directory.
  script_dir = os.path.abspath(os.path.dirname(__file__))
  parent_dir = os.path.split(script_dir)[0]
  toolchain_dir = os.path.join(parent_dir, 'toolchain')
  target = os.path.join(toolchain_dir, platform)

  tgz_dir = os.path.join(script_dir)
  tgz_filename = os.path.join(tgz_dir, path)

  # Drop old versions on mac/linux.
  if sys.platform not in ['win32', 'cygwin']:
    print 'Cleaning up old SDKs...'
    cmd = 'rm -rf "%s"/native_client_sdk_*' % tgz_dir
    p = subprocess.Popen(cmd, shell=True)
    p.communicate()
    assert p.returncode == 0

  print 'Downloading "%s" to "%s"...' % (url, tgz_filename)
  sys.stdout.flush()

  # Download it.
  urllib.urlretrieve(url, tgz_filename)

  # Extract toolchain.
  old_cwd = os.getcwd()
  os.chdir(tgz_dir)
  if sys.platform in ['win32', 'cygwin']:
    cmd = tgz_filename + (
        ' /S /D=c:\\native_client_sdk&& '
        'cd .. && '
        r'c:\cygwin\bin\ln.exe -fsn '
        'c:/native_client_sdk/toolchain toolchain')
  else:
    cmd = (
        'mkdir native_client_sdk_latest && '
        'tar xfzv "%s" -C native_client_sdk_latest && '
        'cd .. && rm -rf toolchain && '
        'ln -fsn build_tools/native_client_sdk_*/toolchain toolchain'
    ) % path
  p = subprocess.Popen(cmd, shell=True)
  p.communicate()
  assert p.returncode == 0
  os.chdir(old_cwd)

  # Clean up: remove the sdk tgz/exe.
  time.sleep(2)  # Wait for windows.
  os.remove(tgz_filename)

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
      '-b', '--base-url', dest='base_url',
      default='http://build.chromium.org/f/client/nacl_archive/sdk/',
      help='base url to download from')
  parser.add_option(
      '-v', '--version', dest='version',
      default='latest',
      help='which version of the toolchain to download')
  (options, args) = parser.parse_args(argv)
  if args:
    parser.print_help()
    print 'ERROR: invalid argument'
    sys.exit(1)

  flavor = PLATFORM_COLLAPSE[sys.platform]
  DownloadSDK(flavor, base_url=options.base_url, version=options.version)


if __name__ == '__main__':
  main(sys.argv[1:])
