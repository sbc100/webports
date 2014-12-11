# Copyright 2014 The Native Client Authors. All rights reserved.
# Use of this source code is governed by a BSD-style license that can be
# found in the LICENSE file.

from naclports import pkg_info
from naclports import error

import common


class TestParsePkgInfo(common.NaclportsTest):
  def testValidKeys(self):
    expected_error = "Invalid key 'BAR' in info file dummy_file:2"
    with self.assertRaisesRegexp(error.Error, expected_error):
      contents = 'FOO=bar\nBAR=baz\n'
      valid = ['FOO']
      required = []
      pkg_info.ParsePkgInfo(contents, 'dummy_file', valid, required)

  def testRequiredKeys(self):
    expected_error = "Required key 'BAR' missing from info file: 'dummy_file'"
    with self.assertRaisesRegexp(error.Error, expected_error):
      contents = 'FOO=bar\n'
      valid = ['FOO']
      required = ['BAR']
      pkg_info.ParsePkgInfo(contents, 'dummy_file', valid, required)
