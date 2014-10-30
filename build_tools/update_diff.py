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

import os
import re
import subprocess
import sys


SCRIPT_DIR = os.path.dirname(os.path.abspath(__file__))
ROOT_DIR = os.path.dirname(SCRIPT_DIR)


class Error(Exception):
  pass


def main(args):
  if len(args) != 1:
    raise Error('Usage: update-diff <port-name>')

  port = args[0]
  port_dir = os.path.join(ROOT_DIR, 'ports', port)

  if not os.path.exists(port_dir):
    raise Error('Port %s does not exist' % port)

  port_build_dir = os.path.join(ROOT_DIR, 'out', 'build', port)

  if not os.path.exists(port_build_dir):
    raise Error('Port %s build dir does not exist' % port)

  items = [i for i in os.listdir(port_build_dir)
           if i.lower().startswith(port.lower() + '-')]
  if len(items) == 0:
    raise Error('Port %s build git dir does not exist' % port)

  if len(items) > 1:
    raise Error('Port %s build git dir is ambiguous')

  git_dir = os.path.join(port_build_dir, items[0])

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
  diff_skip = os.path.join(port_dir, 'diff_skip.txt')
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
  patch_path = os.path.join(port_dir, 'nacl.patch')
  with open(patch_path, 'w') as fh:
    fh.write(diff)
  return 0


if __name__ == '__main__':
  try:
    sys.exit(main(sys.argv[1:]))
  except Error as e:
    sys.stderr.write('update-diff: %s\n' % e)
    sys.exit(1)
