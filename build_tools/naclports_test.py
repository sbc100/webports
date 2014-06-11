#!/usr/bin/env python
# Copyright (c) 2014 The Native Client Authors. All rights reserved.
# Use of this source code is governed by a BSD-style license that can be
# found in the LICENSE file.

import unittest

import naclports


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


if __name__ == '__main__':
  unittest.main()
