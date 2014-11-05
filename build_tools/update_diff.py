#!/usr/bin/env python
# Copyright (c) 2014 The Native Client Authors. All rights reserved.
# Use of this source code is governed by a BSD-style license that can be
# found in the LICENSE file.

"""A script to update the nacl.patch file to match the git checkout.

This encapsulates a step in the naclports workflow.
Changesin out/build/<port> can be worked on incrementally.
Then when ready for pickling as a patch, this script is run.
"""

from __future__ import print_function

import argparse
import os
import re
import subprocess
import sys


SCRIPT_DIR = os.path.dirname(os.path.abspath(__file__))
ROOT_DIR = os.path.dirname(SCRIPT_DIR)

sys.path.append(os.path.join(ROOT_DIR, 'lib'))

from naclports import Error
import naclports.source_package


def UpdatePatch(package_name):
  package = naclports.source_package.CreatePackage(package_name)

  git_dir = package.GetBuildLocation()
  if not os.path.exists(git_dir):
    raise Error('Build directory does not exist: %s' % git_dir)

  diff = subprocess.check_output(['git', 'diff', 'upstream', '--no-ext-diff'],
                                 cwd=git_dir)

  # Drop index lines for a more stable diff.
  diff = re.sub('\nindex [^\n]+\n', '\n', diff)

  # Drop binary files, as they don't work anyhow.
  diff = re.sub(
      'diff [^\n]+\n'
      '(new file [^\n]+\n)?'
      '(deleted file mode [^\n]+\n)?'
      'Binary files [^\n]+ differ\n', '', diff)

  # Filter out things from an optional per port skip list.
  diff_skip = os.path.join(package.root, 'diff_skip.txt')
  if os.path.exists(diff_skip):
    names = open(diff_skip).read().splitlines()
    new_diff = ''
    skipping = False
    for line in diff.splitlines():
      if line.startswith('diff --git '):
        skipping = False
        for name in names:
          if line == 'diff --git a/%s b/%s' % (name, name):
            skipping = True
      if not skipping:
        new_diff += line + '\n'
    diff = new_diff

  # Write back out the diff.
  patch_path = os.path.join(package.root, 'nacl.patch')
  with open(patch_path, 'w') as fh:
    fh.write(diff)
  return 0


def main(args):
  parser = argparse.ArgumentParser(description=__doc__)
  parser.add_argument('port', metavar='PORT_NAME',
                      help='name of port to update patch for')
  options = parser.parse_args(args)
  return UpdatePatch(options.port)


if __name__ == '__main__':
  try:
    sys.exit(main(sys.argv[1:]))
  except Error as e:
    sys.stderr.write('update-diff: %s\n' % e)
    sys.exit(1)
