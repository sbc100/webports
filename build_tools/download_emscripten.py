#!/usr/bin/env python
# Copyright 2015 The Native Client Authors. All rights reserved.
# Use of this source code is governed by a BSD-style license that can be
# found in the LICENSE file.

"""Download the Emscripten SDK for the current platform.

This script downloads the emscripten tarball and expands it.
It requires gsutil to be in the bin PATH and is currently
supported on Linux and Mac OSX and not windows.

Additional prerequisites include cmake, node.js and Java.
"""

import os
import subprocess
import sys
import tarfile

SCRIPT_DIR = os.path.dirname(os.path.abspath(__file__))
NACLPORTS_ROOT = os.path.dirname(SCRIPT_DIR)
sys.path.append(os.path.join(NACLPORTS_ROOT, 'lib'))

import naclports
import naclports.source_package

EMSDK_FILENAME = 'emsdk-portable-20150325.tar.gz'
SHA1 = '18934e2a5b432915465eb5177d1caf265a2082a3'
MIRROR_URL = 'http://storage.googleapis.com/naclports/mirror/emscripten'
URL = MIRROR_URL + '/' + EMSDK_FILENAME

SCRIPT_DIR = os.path.abspath(os.path.dirname(__file__))
SRC_DIR = os.path.dirname(SCRIPT_DIR)
OUT_DIR = os.path.join(SRC_DIR, 'out')
TARGET_DIR = os.path.join(OUT_DIR, 'emscripten_sdk')


def DownloadToCache(url, filename, sha1):
  full_name = os.path.join(naclports.paths.CACHE_ROOT, filename)
  if os.path.exists(full_name):
    try:
      naclports.util.VerifyHash(full_name, sha1)
      naclports.Log("Verified existing SDK: %s" % full_name)
      return full_name
    except naclports.util.HashVerificationError:
      naclports.Log("Hash mistmatch on existing SDK: %s" % full_name)

  naclports.DownloadFile(full_name, url)
  naclports.util.VerifyHash(full_name, sha1)
  return full_name


def DownloadAndInstallEmSDK():
  # Clean up old SDK versions
  if os.path.exists(TARGET_DIR):
    naclports.Log('Cleaning up old SDK...')
    cmd = ['rm', '-rf']
    cmd.append(TARGET_DIR)
    subprocess.check_call(cmd)

  # Download the emscripten SDK tarball
  if not os.path.exists(OUT_DIR):
    os.makedirs(OUT_DIR)

  tar_file = DownloadToCache(URL, EMSDK_FILENAME, SHA1)

  # Extract the toolchain
  os.chdir(OUT_DIR)
  naclports.Log('Exctacting SDK ...')
  if subprocess.call(['tar', 'xf', tar_file]):
    raise naclports.Error('Error unpacking Emscripten SDK')

  # TODO(gdeepti): The update/install scripts clone from external git
  # repositories which is not permitted on the bots. Enable this when
  # we have mirrors for the repositories.
  #
  # Update version of Emscripten, activate the latest emscripten SDK
  # os.chdir(em_sdk_dir)
  # subprocess.check_call(['./emsdk', 'update'])
  # subprocess.check_call(['./emsdk', 'install', 'latest'])
  # subprocess.check_call(['./emsdk', 'activate', 'latest'])

  print('Emscripten SDK Install complete')


def main(argv):
  if sys.platform in ['win32', 'cygwin']:
    print('Emscripten support is currently not available on Windows.')
    return 1

  DownloadAndInstallEmSDK()
  return 0


if __name__ == '__main__':
  try:
    rtn = main(sys.argv[1:])
  except naclports.Error as e:
    sys.stderr.write('error: %s\n' % str(e))
    rtn = 1
