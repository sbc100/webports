#!/usr/bin/env python
# Copyright 2014 The Native Client Authors. All rights reserved.
# Use of this source code is governed by a BSD-style license that can be
# found in the LICENSE file.

import os
import patch_configure
import sys
import StringIO
import unittest

SCRIPT_DIR = os.path.dirname(os.path.abspath(__file__))
SRC_DIR = os.path.dirname(SCRIPT_DIR)
MOCK_DIR = os.path.join(SRC_DIR, 'third_party', 'mock')
sys.path.append(MOCK_DIR)

from mock import Mock, patch

class TestPatchConfigure(unittest.TestCase):
  @patch('sys.stderr', new_callable=StringIO.StringIO)
  def testMissingFile(self, stderr):
    rtn = patch_configure.main(['foo'])
    self.assertEqual(rtn, 1)
    self.assertRegexpMatches(stderr.getvalue(),
                             "^configure script not found: foo$")

if __name__ == '__main__':
  unittest.main()
