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

GS_EM_URL = 'gs://naclports/mirror/emscripten/emsdk-portable.tar'
GSTORE = 'http://storage.googleapis.com/naclports/mirror'
GSTORE += '/emscripten/emsdk-portable.tar'

SCRIPT_DIR = os.path.abspath(os.path.dirname(__file__))
SRC_DIR = os.path.dirname(SCRIPT_DIR)
OUT_DIR = os.path.join(SRC_DIR, 'out')
TARGET_DIR = os.path.join(OUT_DIR, 'emscripten_sdk')


def DownloadAndInstallEmSDK():
  # Clean up old SDK versions
  if os.path.exists(TARGET_DIR):
    print('Cleaning up old SDK...')
    cmd = ['rm', '-rf']
    cmd.append(TARGET_DIR)
    subprocess.check_call(cmd)

  # Download the emscripten SDK tarball
  if not os.path.exists(OUT_DIR):
    os.makedirs(OUT_DIR)
  tar_file = os.path.join(OUT_DIR, GSTORE.split('/')[-1])

  print('Downloading "%s" to "%s"...' % (GSTORE, tar_file))
  sys.stdout.flush()

  naclports.DownloadFile(tar_file, GSTORE)

  # Extract the toolchain
  cwd = os.getcwd()
  os.chdir(OUT_DIR)
  if subprocess.call(['tar', 'xf', tar_file]):
    raise naclports.Error('Error unpacking Emscripten SDK')

  em_sdk_dir = os.path.join(OUT_DIR, 'emsdk_portable')

  # TODO(gdeepti): The update/install scripts clone from external git
  # repositories which is not permitted on the bots. Enable this when
  # we have mirrors for the repositories.
  #
  # Update version of Emscripten, activate the latest emscripten SDK
  # os.chdir(em_sdk_dir)
  # subprocess.check_call(['./emsdk', 'update'])
  # subprocess.check_call(['./emsdk', 'install', 'latest'])
  # subprocess.check_call(['./emsdk', 'activate', 'latest'])

  os.chdir(cwd)

  print('Renaming toolchain "%s" -> "%s"' % (em_sdk_dir, TARGET_DIR))
  os.rename(em_sdk_dir, TARGET_DIR)

  # Clean up: Remove the sdk tar file
  os.remove(tar_file)

  print('Emscripten SDK Install complete.')


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
