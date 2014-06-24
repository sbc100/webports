#!/usr/bin/env python
# Copyright (c) 2014 The Native Client Authors. All rights reserved.
# Use of this source code is governed by a BSD-style license that can be
# found in the LICENSE file.

import naclports

import os
import shutil
import StringIO
import sys
import tempfile
import unittest

SCRIPT_DIR = os.path.dirname(os.path.abspath(__file__))
SRC_DIR = os.path.dirname(SCRIPT_DIR)
MOCK_DIR = os.path.join(SRC_DIR, 'third_party', 'mock')
sys.path.append(MOCK_DIR)

import mock


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


class TestPackage(unittest.TestCase):
  def setUp(self):
    self.tempdir = tempfile.mkdtemp(prefix='naclports_test_')

  def tearDown(self):
    shutil.rmtree(self.tempdir)

  def CreateSourcePackage(self, name, extra_info=''):
    """Creates a source package directory in a temporary directory.
    Args:
        name: The name of the temporary package.
        extra_info: extra information to append to the pkg_info file.

    Returns:
        The new package source directory
    """
    pkg_root = os.path.join(self.tempdir, name)
    os.mkdir(pkg_root)
    with open(os.path.join(pkg_root, 'pkg_info'), 'w') as info:
      info.write("NAME=%s\nVERSION=1.0\n%s" % (name, extra_info))
    return pkg_root

  def testInvalidSourceDir(self):
    """test that invalid source directory generates an error."""
    path = '/bad/path'
    with self.assertRaises(naclports.Error) as context:
      naclports.Package(path)
    self.assertEqual(context.exception.message,
                     'Invalid package folder: ' + path)

  def testValidSourceDir(self):
    """test that valid source directory is loaded correctly."""
    root = self.CreateSourcePackage('foo')
    pkg = naclports.Package(root)
    self.assertEqual(pkg.NAME, 'foo')
    self.assertEqual(pkg.root, root)

  def testIsBuilt(self):
    """test that IsBuilt() can handle malformed package files."""
    root = self.CreateSourcePackage('foo')
    pkg = naclports.Package(root)
    invalid_binary = os.path.join(self.tempdir, 'package.tar.bz2')
    with open(invalid_binary, 'w') as f:
      f.write('this is not valid package file\n')
    pkg.PackageFile = mock.Mock(return_value=invalid_binary)
    self.assertFalse(pkg.IsBuilt())


if __name__ == '__main__':
  unittest.main()
