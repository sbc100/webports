#!/usr/bin/env python
# Copyright (c) 2014 The Native Client Authors. All rights reserved.
# Use of this source code is governed by a BSD-style license that can be
# found in the LICENSE file.

import naclports
import naclports.package
import naclports.binary_package
import naclports.__main__
from naclports import source_package, package_index
from naclports.configuration import Configuration

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

from mock import MagicMock, Mock, patch, call


def MockFileObject(contents=''):
  file_mock = Mock(name="file_mock", spec=file)
  file_mock.read.return_value = contents
  file_mock.__enter__ = lambda s: s
  file_mock.__exit__ = Mock(return_value=False)
  return file_mock


class NaclportsTest(unittest.TestCase):
  """Class that sets up core mocks common to all test cases."""

  def setUp(self):
    patcher = patch('naclports.GetInstallRoot',
                    Mock(return_value='/package/install/path'))
    patcher.start()
    self.addCleanup(patcher.stop)

    mock_lock = Mock()
    mock_lock.__enter__ = lambda s: s
    mock_lock.__exit__ = Mock(return_value=False)
    patcher = patch('naclports.InstallLock', Mock(return_value=mock_lock))
    patcher.start()
    self.addCleanup(patcher.stop)

    mock_lock = Mock()
    mock_lock.__enter__ = lambda s: s
    mock_lock.__exit__ = Mock(return_value=False)
    patcher = patch('naclports.BuildLock', Mock(return_value=mock_lock))
    patcher.start()
    self.addCleanup(patcher.stop)


class TestConfiguration(NaclportsTest):
  def testDefaults(self):
    config = Configuration()
    self.assertEqual(config.toolchain, 'newlib')
    self.assertEqual(config.arch, 'x86_64')
    self.assertEqual(config.debug, False)
    self.assertEqual(config.config_name, 'release')
    self.assertEqual(config.libc, 'newlib')

  def testDefaultArch(self):
    # We default to x86_64 except in the special case where the build
    # machine is i686 hardware, in which case we default to i686.
    with patch('platform.machine', Mock(return_value='i686')):
      self.assertEqual(Configuration().arch, 'i686')
    with patch('platform.machine', Mock(return_value='dummy')):
      self.assertEqual(Configuration().arch, 'x86_64')

  def testEnvironmentVariables(self):
    with patch.dict('os.environ', {'NACL_ARCH': 'arm'}):
      self.assertEqual(Configuration().arch, 'arm')

    with patch.dict('os.environ', {'NACL_DEBUG': '1'}):
      self.assertEqual(Configuration().debug, True)

  def testDefaultToolchain(self):
    self.assertEqual(Configuration(arch='pnacl').toolchain, 'pnacl')
    self.assertEqual(Configuration(arch='arm').libc, 'newlib')

  def testDefaultLibc(self):
    self.assertEqual(Configuration(toolchain='pnacl').libc, 'newlib')
    self.assertEqual(Configuration(toolchain='newlib').libc, 'newlib')
    self.assertEqual(Configuration(toolchain='glibc').libc, 'glibc')
    self.assertEqual(Configuration(toolchain='bionic').libc, 'bionic')

  def testConfigStringForm(self):
    config = Configuration('arm', 'newlib', True)
    self.assertEqual(str(config), 'arm/newlib/debug')
    self.assertRegexpMatches(repr(config), '<Configuration .*>')

  def testConfigEquality(self):
    config1 = Configuration('arm', 'newlib', True)
    config2 = Configuration('arm', 'newlib', True)
    config3 = Configuration('arm', 'newlib', False)
    self.assertEqual(config1, config2)
    self.assertNotEqual(config1, config3)

  def testInvalidArch(self):
    expected_error = 'Invalid arch: not_arch'
    with self.assertRaisesRegexp(naclports.Error, expected_error):
      config = Configuration('not_arch')

test_index = '''\
NAME=agg-demo
VERSION=0.1
LICENSE=BSD
DEPENDS=(agg)
BUILD_CONFIG=release
BUILD_ARCH=arm
BUILD_TOOLCHAIN=newlib
BUILD_SDK_VERSION=38
BUILD_NACLPORTS_REVISION=98765
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
BUILD_NACLPORTS_REVISION=98765
BIN_URL=http://storage.googleapis.com/naclports/builds/pepper_38/1414/packages/agg-demo_0.1_i686_newlib.tar.bz2
BIN_SIZE=10240
BIN_SHA1=0cb0d2d1380831b38c2b8461528836aa7992435f
'''

class TestPackageIndex(NaclportsTest):
  def testParsingInvalid(self):
    contents = 'FOO=bar\nBAR=baz\n'
    expected_error = "Invalid key 'FOO' in info file dummy_file:1"
    with self.assertRaisesRegexp(naclports.Error, expected_error):
      index = package_index.PackageIndex('dummy_file', contents)

  def testParsingValid(self):
    index = package_index.PackageIndex('dummy_file', test_index)
    arm_config = Configuration('arm', 'newlib', False)
    i686_config = Configuration('i686', 'newlib', False)
    self.assertEqual(len(index.packages), 2)
    self.assertTrue(index.Contains('agg-demo', arm_config))
    self.assertTrue(index.Contains('agg-demo', i686_config))

  def testContains(self):
    # Create an empty package index and add a single entry to it
    index = package_index.PackageIndex('dummy_file', '')
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

  @patch('naclports.Log', Mock())
  @patch('naclports.package_index.PREBUILT_ROOT', os.getcwd())
  @patch('naclports.package_index.VerifyHash', Mock(return_value=True))
  @patch('naclports.DownloadFile')
  def testDownload(self, download_file_mock):
    index = package_index.PackageIndex('dummy_file', test_index)
    arm_config = Configuration('arm', 'newlib', False)
    index.Download('agg-demo', arm_config)
    self.assertEqual(download_file_mock.call_count, 1)

test_info = '''\
NAME=foo
VERSION=bar
BUILD_ARCH=arm
BUILD_CONFIG=debbug
BUILD_TOOLCHAIN=newlib
BUILD_SDK_VERSION=123
BUILD_NACLPORTS_REVISION=98765
'''

class TestInstalledPackage(NaclportsTest):
  def CreateMockInstalledPackage(self):
    file_mock = MockFileObject(test_info)
    with patch('__builtin__.open', Mock(return_value=file_mock), create=True):
      return naclports.package.InstalledPackage('dummy_file')

  @patch('naclports.package.Log', Mock())
  @patch('naclports.package.InstalledPackage.RemoveFile')
  @patch('os.path.lexists', Mock(return_value=True))
  def testUninstall(self, remove_patch):
    pkg = self.CreateMockInstalledPackage()
    pkg.Files = Mock(return_value=['f1', 'f2'])
    pkg.Uninstall()

    # Assert that exactly 4 files we removed using InstalledPackage.RemoveFile
    calls = [call('/package/install/path/var/lib/npkg/foo.info'),
             call('/package/install/path/f1'),
             call('/package/install/path/f2'),
             call('/package/install/path/var/lib/npkg/foo.list')]
    remove_patch.assert_has_calls(calls)


class TestBinaryPackage(NaclportsTest):
  @patch('os.rename')
  @patch('os.makedirs')
  @patch('os.path.isdir', Mock(return_value=False))
  def testInstallFile(self, makedirs_mock, rename_mock):
    naclports.binary_package.InstallFile('fname', 'location1', 'location2')
    makedirs_mock.assert_called_once_with('location2')
    rename_mock.assert_has_calls([call('location1/fname', 'location2/fname')])

  def testRelocateFile(self):
    # Only certain files should be relocated. A file called 'testfile'
    # for example, should not be touched.
    with patch('__builtin__.open', Mock(), create=True) as open_mock:
      naclports.binary_package.RelocateFile('testfile', 'newroot')
      open_mock.assert_not_called()

  @patch('naclports.binary_package.BinaryPackage.VerifyArchiveFormat', Mock())
  @patch('naclports.binary_package.BinaryPackage.GetPkgInfo')
  @patch('naclports.GetInstallStamp', Mock(return_value='stamp_dir/stamp_file'))
  def testWriteStamp(self, mock_get_info):
    fake_binary_pkg_info = '''\
NAME=foo
VERSION=1.0
BUILD_CONFIG=release
BUILD_ARCH=arm
BUILD_TOOLCHAIN=newlib
BUILD_SDK_VERSION=38
BUILD_NACLPORTS_REVISION=1414
'''
    mock_get_info.return_value = fake_binary_pkg_info
    pkg = naclports.binary_package.BinaryPackage('foo')
    mock_stamp_file = MockFileObject()
    with patch('__builtin__.open', Mock(return_value=mock_stamp_file),
               create=True):
      pkg.WriteStamp()
    mock_stamp_file.write.assert_called_once_with(fake_binary_pkg_info)


class TestParsePkgInfo(NaclportsTest):
  def testValidKeys(self):
    expected_error = "Invalid key 'BAR' in info file dummy_file:2"
    with self.assertRaisesRegexp(naclports.Error, expected_error):
      contents = 'FOO=bar\nBAR=baz\n'
      valid = ['FOO']
      required = []
      naclports.ParsePkgInfo(contents, 'dummy_file', valid, required)

  def testRequiredKeys(self):
    expected_error = "Required key 'BAR' missing from info file: 'dummy_file'"
    with self.assertRaisesRegexp(naclports.Error, expected_error):
      contents = 'FOO=bar\n'
      valid = ['FOO']
      required = ['BAR']
      naclports.ParsePkgInfo(contents, 'dummy_file', valid, required)


class TestSourcePackage(NaclportsTest):
  def setUp(self):
    self.tempdir = tempfile.mkdtemp(prefix='naclports_test_')
    self.addCleanup(shutil.rmtree, self.tempdir)
    self.temp_ports = os.path.join(self.tempdir, 'ports')

  def CreateTestPackage(self, name, extra_info=''):
    """Creates a source package directory in a temporary directory.
    Args:
      name: The name of the temporary package.
      extra_info: extra information to append to the pkg_info file.

    Returns:
      The new package source directory
    """
    pkg_root = os.path.join(self.temp_ports, name)
    os.makedirs(pkg_root)
    with open(os.path.join(pkg_root, 'pkg_info'), 'w') as info:
      info.write("NAME=%s\nVERSION=1.0\n%s" % (name, extra_info))
    return pkg_root

  def testInvalidSourceDir(self):
    """test that invalid source directory generates an error."""
    path = '/bad/path'
    expected_error = 'Invalid package folder: ' + path
    with self.assertRaisesRegexp(naclports.Error, expected_error):
      source_package.SourcePackage(path)

  def testValidSourceDir(self):
    """test that valid source directory is loaded correctly."""
    root = self.CreateTestPackage('foo')
    pkg = source_package.SourcePackage(root)
    self.assertEqual(pkg.NAME, 'foo')
    self.assertEqual(pkg.root, root)

  def testIsBuiltMalformedBinary(self):
    """test that IsBuilt() can handle malformed package files."""
    root = self.CreateTestPackage('foo')
    pkg = source_package.SourcePackage(root)
    invalid_binary = os.path.join(self.tempdir, 'package.tar.bz2')
    with open(invalid_binary, 'w') as f:
      f.write('this is not valid package file\n')
    pkg.PackageFile = Mock(return_value=invalid_binary)
    self.assertFalse(pkg.IsBuilt())

  @patch('naclports.source_package.SourcePackage.RunBuildSh',
      Mock(return_value=True))
  @patch('naclports.source_package.Log', Mock())
  def testBuildPackage(self):
    root = self.CreateTestPackage('foo')
    pkg = source_package.SourcePackage(root)
    pkg.Build(True)

  @patch('sha1check.VerifyHash')
  @patch('naclports.source_package.SourcePackage.Download', Mock())
  @patch('naclports.source_package.Log', Mock())
  def testVerify(self, verify_hash_mock):
    root = self.CreateTestPackage('foo', 'URL=someurl\nSHA1=123')
    pkg = source_package.SourcePackage(root)
    pkg.Verify()
    filename = os.path.join(source_package.CACHE_ROOT, 'someurl')
    verify_hash_mock.assert_called_once_with(filename, '123')

  def testSourcePackageIterator(self):
    self.CreateTestPackage('foo')
    with patch('naclports.NACLPORTS_ROOT', self.tempdir):
      pkgs = [p for p in source_package.SourcePackageIterator()]
    self.assertEqual(len(pkgs), 1)
    self.assertEqual(pkgs[0].NAME, 'foo')

  def testGetBuildLocation(self):
    root = self.CreateTestPackage('foo')
    pkg = source_package.SourcePackage(root)
    location = pkg.GetBuildLocation()
    self.assertTrue(location.startswith(naclports.BUILD_ROOT))
    self.assertEqual(os.path.basename(location),
                     '%s-%s' % (pkg.NAME, pkg.VERSION))

  @patch('naclports.Log', Mock())
  def testExtract(self):
    root = self.CreateTestPackage('foo', 'URL=someurl.tar.gz\nSHA1=123')
    pkg = source_package.SourcePackage(root)

    def fake_extract(archive, dest):
      os.mkdir(os.path.join(dest, '%s-%s' % (pkg.NAME, pkg.VERSION)))

    with patch('naclports.source_package.ExtractArchive', fake_extract):
      pkg.Extract()

  def testCreatePackageInvalid(self):
    with self.assertRaisesRegexp(naclports.Error, 'Package not found: foo'):
      source_package.CreatePackage('foo')

  def testFormatTimeDelta(self):
    expectations = (
       ( 1, '1s' ),
       ( 60, '1m' ),
       ( 70, '1m10s' ),
    )

    for secs, expected_result in expectations:
      self.assertEqual(expected_result,
                       naclports.source_package.FormatTimeDelta(secs))

  def testConflicts(self):
    root = self.CreateTestPackage('foo', 'CONFLICTS=(bar)')
    pkg = source_package.SourcePackage(root)

    # with no other packages installed
    with patch('naclports.IsInstalled', Mock(return_value=False)):
      pkg.CheckInstallable()

    # with all possible packages installed
    with patch('naclports.IsInstalled') as is_installed:
      is_installed.return_value = True
      with self.assertRaises(naclports.source_package.PkgConflictError):
        pkg.CheckInstallable()
      is_installed.assert_called_once_with('bar', pkg.config)

  def testCheckInstallable(self):
    root = self.CreateTestPackage('foo', 'DEPENDS=(bar)')
    pkg = source_package.SourcePackage(root)

    # Verify that CheckInstallable raises an error when the package
    # depened on something that is disabled.
    def CreatePackageMock(name, config):
      root = self.CreateTestPackage(name, 'DISABLED_ARCH=(x86_64)')
      return source_package.SourcePackage(root)

    with patch('naclports.source_package.CreatePackage', CreatePackageMock):
      with self.assertRaises(naclports.DisabledError):
        pkg.CheckInstallable()


class TestCommands(NaclportsTest):
  def testListCommand(self):
    config = Configuration()
    options = Mock()
    pkg = Mock(NAME='foo', VERSION='bar')
    with patch('naclports.package.InstalledPackageIterator',
               Mock(return_value=[pkg])):
      with patch('sys.stdout', new_callable=StringIO.StringIO) as stdout:
        naclports.__main__.CmdList(config, options, [])
        lines = stdout.getvalue().splitlines()
        self.assertEqual(len(lines), 1)
        self.assertRegexpMatches(lines[0], "^foo\\s+bar$")

  @patch('naclports.package.CreateInstalledPackage', Mock())
  def testInfoCommand(self):
    config = Configuration()
    options = Mock()
    file_mock = MockFileObject('FOO=bar\n')
    pkg = Mock(NAME='foo', VERSION='bar')

    with patch('sys.stdout', new_callable=StringIO.StringIO) as stdout:
      with patch('__builtin__.open', Mock(return_value=file_mock), create=True):
        naclports.__main__.CmdInfo(config, options, ['foo'])
        self.assertRegexpMatches(stdout.getvalue(), "FOO=bar")

  def testContentsCommand(self):
    file_list = ['foo', 'bar']

    options = Mock(verbose=False, all=False)
    package = Mock(NAME='test', Files=Mock(return_value=file_list))

    expected_output = '\n'.join(file_list) + '\n'
    with patch('sys.stdout', new_callable=StringIO.StringIO) as stdout:
      naclports.__main__.CmdPkgContents(package, options)
      self.assertEqual(stdout.getvalue(), expected_output)

    # when the verbose option is set expect CmdContents to output full paths.
    options.verbose = True
    expected_output = [os.path.join('/package/install/path', f)
                       for f in file_list]
    expected_output = '\n'.join(expected_output) + '\n'
    with patch('sys.stdout', new_callable=StringIO.StringIO) as stdout:
      naclports.__main__.CmdPkgContents(package, options)
      self.assertEqual(stdout.getvalue(), expected_output)


class TestMain(NaclportsTest):
  @patch('naclports.Log', Mock())
  @patch('shutil.rmtree', Mock())
  def testCleanAll(self):
    config = Configuration()
    naclports.__main__.CleanAll(config)

  @patch('naclports.__main__.run_main',
         Mock(side_effect=naclports.Error('oops')))
  def testErrorReport(self):
    # Verify that exceptions of the type naclports.Error are printed
    # to stderr and result in a return code of 1
    with patch('sys.stderr', new_callable=StringIO.StringIO) as stderr:
      self.assertEqual(naclports.__main__.main(None), 1)
    self.assertRegexpMatches(stderr.getvalue(), '^naclports: oops')

  @patch('naclports.__main__.CleanAll')
  def testMainCleanAll(self, clean_all_mock):
    naclports.__main__.main(['clean', '--all'])
    clean_all_mock.assert_called_once_with(Configuration())


if __name__ == '__main__':
  unittest.main()
