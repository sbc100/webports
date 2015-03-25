# Copyright 2015 The Native Client Authors. All rights reserved.
# Use of this source code is governed by a BSD-style license that can be
# found in the LICENSE file.

"""Simple test for json formatting of cq_config.json"""

import json
import os
import sys

SCRIPT_DIR = os.path.dirname(os.path.abspath(__file__))

def main():
  with open(os.path.join(SCRIPT_DIR, 'cq_config.json')) as f:
    try:
      json.load(f)
    except ValueError as e:
      print 'error in cq_config.json:', e
      return 1

  print 'OK'
  return 0

if __name__ == '__main__':
  sys.exit(main())
