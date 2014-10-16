#!/usr/bin/env python
# Copyright (c) 2014 The Native Client Authors. All rights reserved.
# Use of this source code is governed by a BSD-style license that can be
# found in the LICENSE file.

import naclports
import naclports.package
import naclports.source_package
import naclports.__main__
from naclports.configuration import Configuration
from naclports.package_index import PackageIndex

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

from mock import Mock, patch


class TestConfiguration(unittest.TestCase):
  def testDefaults(self):
    config = Configuration()
    self.assertEqual(config.toolchain, 'newlib')
    self.assertEqual(config.arch, 'x86_64')
    self.assertEqual(config.debug, False)
    self.assertEqual(config.config_name, 'release')

  def testConfigString(self):
    config = Configuration('arm', 'newlib', True)
    self.assertEqual(str(config), 'arm/newlib/debug')

  def testConfigEquality(self):
    config1 = Configuration('arm', 'newlib', True)
    config2 = Configuration('arm', 'newlib', True)
    config3 = Configuration('arm', 'newlib', False)
    self.assertEqual(config1, config2)
    self.assertNotEqual(config1, config3)

test_index = '''\
NAME=agg-demo
VERSION=0.1
LICENSE=BSD
DEPENDS=(agg)
BUILD_CONFIG=release
BUILD_ARCH=arm
BUILD_TOOLCHAIN=newlib
BUILD_SDK_VERSION=38
BUILD_NACLPORTS_REVISION=1414
BIN_URL=http://storage.googleapis.com/naclports/builds/pepper_38/1414/packages/agg-demo_0.1_arm_newlib.tar.bz2
BIN_SIZE=10240
BIN_SHA1=f300618f52188a291804dd60d6a5e04361c0ffe6

NAME=agg-demo
VERSION=0.1
LICENSE=BSD
DEPENDS=(agg)
BUILD_CONFIG=release
BUILD_ARCH=i686
BUILD_TOOLCHAIN=newlib
BUILD_SDK_VERSION=38
BUILD_NACLPORTS_REVISION=1414
BIN_URL=http://storage.googleapis.com/naclports/builds/pepper_38/1414/packages/agg-demo_0.1_i686_newlib.tar.bz2
BIN_SIZE=10240
BIN_SHA1=0cb0d2d1380831b38c2b8461528836aa7992435f
'''

class TestPackageIndex(unittest.TestCase):
  def testParsingInvalid(self):
    contents = 'FOO=bar\nBAR=baz\n'
    ex = None
    try:
      index = PackageIndex('dummy_file', contents)
    except naclports.Error as e:
      ex = e
    self.assertIsNotNone(ex)
    self.assertEqual(str(ex), "Invalid key 'FOO' in info file dummy_file:1")

  def testParsingValid(self):
    index = PackageIndex('dummy_file', test_index)
    arm_config = Configuration('arm', 'newlib', False)
    i686_config = Configuration('i686', 'newlib', False)
    self.assertEqual(len(index.packages), 2)
    self.assertTrue(index.Contains('agg-demo', arm_config))
    self.assertTrue(index.Contains('agg-demo', i686_config))

  def testContains(self):
    # Create an empty package index and add a single entry to it
    index = PackageIndex('dummy_file', '')
    config_debug = Configuration('arm', 'newlib', True)
    config_release = Configuration('arm', 'newlib', False)
    self.assertFalse(index.Contains('foo', config_release))
    index.packages[('foo', config_release)] = {
      'NAME': 'dummy',
      'BUILD_SDK_VERSION': 123
    }
    with patch('naclports.GetSDKVersion') as mock_version:
      # Setting the mock SDK version to 123 should mean that the
      # index contains the 'foo' package and it is installable'
      mock_version.return_value = 123
      self.assertTrue(index.Contains('foo', config_release))
      self.assertTrue(index.Installable('foo', config_release))

      # Setting the mock SDK version to some other version should
      # mean the index contains that package but it is not installable.
      mock_version.return_value = 124
      self.assertTrue(index.Contains('foo', config_release))
      self.assertFalse(index.Installable('foo', config_release))

      self.assertFalse(index.Contains('foo', config_debug))
      self.assertFalse(index.Contains('bar', config_release))


class TestParsePkgInfo(unittest.TestCase):
  def testValidKeys(self):
    contents = 'FOO=bar\nBAR=baz\n'
    valid = ['FOO']
    required = []
    ex = None
    try:
      naclports.ParsePkgInfo(contents, 'dummy_file', valid, required)
    except naclports.Error as e:
      ex = e
    self.assertIsNotNone(ex)
    self.assertEqual(str(ex), "Invalid key 'BAR' in info file dummy_file:2")

  def testRequiredKeys(self):
    contents = 'FOO=bar\n'
    valid = ['FOO']
    required = ['BAR']
    ex = None
    try:
      naclports.ParsePkgInfo(contents, 'dummy_file', valid, required)
    except naclports.Error as e:
      ex = e
    expected = "Required key 'BAR' missing from info file: 'dummy_file'"
    self.assertIsNotNone(ex)
    self.assertEqual(str(ex), expected)


class TestSourcePackage(unittest.TestCase):
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
      naclports.source_package.SourcePackage(path)
    self.assertEqual(context.exception.message,
                     'Invalid package folder: ' + path)

  def testValidSourceDir(self):
    """test that valid source directory is loaded correctly."""
    root = self.CreateSourcePackage('foo')
    pkg = naclports.source_package.SourcePackage(root)
    self.assertEqual(pkg.NAME, 'foo')
    self.assertEqual(pkg.root, root)

  def testIsBuilt(self):
    """test that IsBuilt() can handle malformed package files."""
    root = self.CreateSourcePackage('foo')
    pkg = naclports.source_package.SourcePackage(root)
    invalid_binary = os.path.join(self.tempdir, 'package.tar.bz2')
    with open(invalid_binary, 'w') as f:
      f.write('this is not valid package file\n')
    pkg.PackageFile = Mock(return_value=invalid_binary)
    self.assertFalse(pkg.IsBuilt())


class TestCommands(unittest.TestCase):
  def tearDown(sefl):
    if os.path.exists('test.list'):
      os.remove('test.list')

  def testContentsCommands(self):
    file_list = ['foo', 'bar']
    install_root = '/testpath'

    # ideally we would use mock.mock_open here to avoid hitting
    # the filesystem at all but the version we are using doesn't
    # seem to support f.readlines().
    test_data = '\n'.join(file_list) + '\n'
    with open('test.list', 'w') as f:
      f.write(test_data)

    options = Mock()
    package = Mock()
    package.GetListFile = Mock(return_value='test.list')
    package.config = Configuration('arm', 'newlib', True)
    package.NAME = 'test'

    options.verbose = False
    options.all = False

    with patch('sys.stdout', new_callable=StringIO.StringIO) as stdout:
      with patch('naclports.GetInstallRoot', Mock(return_value=install_root)):
        naclports.__main__.CmdContents(package, options)
        self.assertEqual(stdout.getvalue(), test_data)

    # when the verbose option is set expect CmdContents to output full paths.
    options.verbose = True
    expected_output = [os.path.join(install_root, f) for f in file_list]
    expected_output = '\n'.join(expected_output) + '\n'
    with patch('sys.stdout', new_callable=StringIO.StringIO) as stdout:
      with patch('naclports.GetInstallRoot', Mock(return_value=install_root)):
        naclports.__main__.CmdContents(package, options)
        self.assertEqual(stdout.getvalue(), expected_output)


if __name__ == '__main__':
  unittest.main()
