#!/usr/bin/env python
# Copyright (c) 2014 The Native Client Authors. All rights reserved.
# Use of this source code is governed by a BSD-style license that can be
# found in the LICENSE file.

import naclports

import StringIO
import unittest


class TestConfig(unittest.TestCase):
  def testDefaults(self):
    config = naclports.Configuration()
    self.assertEqual(config.toolchain, 'newlib')
    self.assertEqual(config.arch, 'x86_64')
    self.assertEqual(config.debug, False)
    self.assertEqual(config.config_name, 'release')

  def testConfigString(self):
    config = naclports.Configuration('arm', 'newlib', True)
    self.assertEqual(str(config), 'arm/newlib/debug')


class TestParsePkgInfo(unittest.TestCase):
  def testValidKeys(self):
    file_object = StringIO.StringIO('FOO=bar\nBAR=baz\n')
    valid = ['FOO']
    required = []
    ex = None
    try:
      naclports.ParsePkgInfo(file_object, 'dummy_file', valid, required)
    except naclports.Error as e:
      ex = e
    self.assertIsNotNone(ex)
    self.assertEqual(str(ex), "Invalid key 'BAR' in info file dummy_file:2")

  def testRequiredKeys(self):
    file_object = StringIO.StringIO('FOO=bar\n')
    valid = ['FOO']
    required = ['BAR']
    ex = None
    try:
      naclports.ParsePkgInfo(file_object, 'dummy_file', valid, required)
    except naclports.Error as e:
      ex = e
    expected = "Required key 'BAR' missing from info file: 'dummy_file'"
    self.assertIsNotNone(ex)
    self.assertEqual(str(ex), expected)


if __name__ == '__main__':
  unittest.main()
