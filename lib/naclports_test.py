# Copyright (c) 2014 The Native Client Authors. All rights reserved.
# Use of this source code is governed by a BSD-style license that can be
# found in the LICENSE file.

import mock
from mock import MagicMock, Mock, patch, call
import os
import shutil
import StringIO
import sys
import tempfile
import textwrap
import unittest

from naclports import paths
from naclports import binary_package
from naclports import error
from naclports import package_index
from naclports import source_package
from naclports import util
from naclports.configuration import Configuration
import naclports
import naclports.__main__

def MockFileObject(contents=''):
  file_mock = Mock(name="file_mock", spec=file)
  file_mock.read.return_value = contents
  file_mock.__enter__ = lambda s: s
  file_mock.__exit__ = Mock(return_value=False)
  return file_mock


def AddPatch(testcase, patcher):
  patcher.start()
  testcase.addCleanup(patcher.stop)


class NaclportsTest(unittest.TestCase):
  """Class that sets up core mocks common to all test cases."""

  def setUp(self):
    AddPatch(self, patch.dict('os.environ', {'NACL_SDK_ROOT': '/sdk/root'}))
    AddPatch(self, patch('naclports.util.GetPlatform',
             Mock(return_value='linux')))
    AddPatch(self, patch('naclports.util.GetInstallRoot',
             Mock(return_value='/package/install/path')))
    AddPatch(self, patch('naclports.util.GetSDKRoot',
             Mock(return_value='/sdk/root')))

    mock_lock = Mock()
    mock_lock.__enter__ = lambda s: s
    mock_lock.__exit__ = Mock(return_value=False)
    AddPatch(self, patch('naclports.util.InstallLock',
             Mock(return_value=mock_lock)))

    mock_lock = Mock()
    mock_lock.__enter__ = lambda s: s
    mock_lock.__exit__ = Mock(return_value=False)
    AddPatch(self, patch('naclports.util.BuildLock',
             Mock(return_value=mock_lock)))


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
    with self.assertRaisesRegexp(error.Error, expected_error):
      Configuration('not_arch')

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

test_info = '''\
NAME=foo
VERSION=bar
BUILD_ARCH=arm
BUILD_CONFIG=debug
BUILD_TOOLCHAIN=newlib
BUILD_SDK_VERSION=123
BUILD_NACLPORTS_REVISION=98765
'''

class TestPackageIndex(NaclportsTest):
  def testParsingInvalid(self):
    contents = 'FOO=bar\nBAR=baz\n'
    expected_error = "Invalid key 'FOO' in info file dummy_file:1"
    with self.assertRaisesRegexp(error.Error, expected_error):
      package_index.PackageIndex('dummy_file', contents)

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
    with patch('naclports.util.GetSDKVersion') as mock_version:
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

  @patch('naclports.util.Log', Mock())
  @patch('naclports.package_index.PREBUILT_ROOT', os.getcwd())
  @patch('naclports.util.VerifyHash', Mock(return_value=True))
  @patch('naclports.util.DownloadFile')
  def testDownload(self, download_file_mock):
    index = package_index.PackageIndex('dummy_file', test_index)
    arm_config = Configuration('arm', 'newlib', False)
    index.Download('agg-demo', arm_config)
    self.assertEqual(download_file_mock.call_count, 1)

  @patch('naclports.util.HashFile', Mock(return_value='sha1'))
  @patch('os.path.getsize', Mock(return_value=100))
  def testWriteIndex(self):
    temp_file = tempfile.mkstemp('naclports_test')[1]
    self.addCleanup(os.remove, temp_file)

    with patch('naclports.package_index.ExtractPkgInfo',
               Mock(return_value=test_info)):
      package_index.WriteIndex(temp_file, (('pkg1', 'url1'), ('pkg2', 'url2')))


class TestInstalledPackage(NaclportsTest):
  def CreateMockInstalledPackage(self):
    file_mock = MockFileObject(test_info)
    with patch('__builtin__.open', Mock(return_value=file_mock), create=True):
      return naclports.package.InstalledPackage('dummy_file')

  @patch('naclports.package.Log', Mock())
  @patch('naclports.package.RemoveFile')
  @patch('os.path.lexists', Mock(return_value=True))
  def testUninstall(self, remove_patch):
    pkg = self.CreateMockInstalledPackage()
    pkg.Files = Mock(return_value=['f1', 'f2'])
    pkg.Uninstall()

    # Assert that exactly 4 files we removed using RemoveFile
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
    binary_package.InstallFile('fname', 'location1', 'location2')
    makedirs_mock.assert_called_once_with('location2')
    rename_mock.assert_has_calls([call('location1/fname', 'location2/fname')])

  def testRelocateFile(self):
    # Only certain files should be relocated. A file called 'testfile'
    # for example, should not be touched.
    with patch('__builtin__.open', Mock(), create=True) as open_mock:
      binary_package.RelocateFile('testfile', 'newroot')
      open_mock.assert_not_called()

  @patch('naclports.binary_package.BinaryPackage.VerifyArchiveFormat', Mock())
  @patch('naclports.binary_package.BinaryPackage.GetPkgInfo')
  @patch('naclports.util.GetInstallStamp',
         Mock(return_value='stamp_dir/stamp_file'))
  def testWriteStamp(self, mock_get_info):
    fake_binary_pkg_info = textwrap.dedent('''\
      NAME=foo
      VERSION=1.0
      BUILD_CONFIG=release
      BUILD_ARCH=arm
      BUILD_TOOLCHAIN=newlib
      BUILD_SDK_VERSION=38
      BUILD_NACLPORTS_REVISION=1414
      ''')
    mock_get_info.return_value = fake_binary_pkg_info
    pkg = binary_package.BinaryPackage('foo')
    mock_stamp_file = MockFileObject()
    with patch('__builtin__.open', Mock(return_value=mock_stamp_file),
               create=True):
      pkg.WriteStamp()
    mock_stamp_file.write.assert_called_once_with(fake_binary_pkg_info)


class TestParsePkgInfo(NaclportsTest):
  def testValidKeys(self):
    expected_error = "Invalid key 'BAR' in info file dummy_file:2"
    with self.assertRaisesRegexp(error.Error, expected_error):
      contents = 'FOO=bar\nBAR=baz\n'
      valid = ['FOO']
      required = []
      naclports.ParsePkgInfo(contents, 'dummy_file', valid, required)

  def testRequiredKeys(self):
    expected_error = "Required key 'BAR' missing from info file: 'dummy_file'"
    with self.assertRaisesRegexp(error.Error, expected_error):
      contents = 'FOO=bar\n'
      valid = ['FOO']
      required = ['BAR']
      naclports.ParsePkgInfo(contents, 'dummy_file', valid, required)


class TestSourcePackage(NaclportsTest):
  def setUp(self):
    super(TestSourcePackage, self).setUp()
    self.tempdir = tempfile.mkdtemp(prefix='naclports_test_')
    self.addCleanup(shutil.rmtree, self.tempdir)
    self.temp_ports = os.path.join(self.tempdir, 'ports')

    patcher = patch('naclports.paths.BUILD_ROOT',
                    os.path.join(self.tempdir, 'build_root'))
    patcher.start()
    self.addCleanup(patcher.stop)
    patcher = patch('naclports.paths.OUT_DIR',
                    os.path.join(self.tempdir, 'out_dir'))
    patcher.start()
    self.addCleanup(patcher.stop)

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

  def testStampContentsMatch(self):
    stamp_file = os.path.join(self.tempdir, 'test_stamp')
    # stamp does not exist
    self.assertFalse(source_package.StampContentsMatch(stamp_file, ''))

    open(stamp_file, 'w').close()
    self.assertTrue(source_package.StampContentsMatch(stamp_file, ''))
    self.assertFalse(source_package.StampContentsMatch(stamp_file, 'foo'))

  def testInvalidSourceDir(self):
    """test that invalid source directory generates an error."""
    path = '/bad/path'
    expected_error = 'Invalid package folder: ' + path
    with self.assertRaisesRegexp(error.Error, expected_error):
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

  def testSourcePackageIterator(self):
    self.CreateTestPackage('foo')
    with patch('naclports.paths.NACLPORTS_ROOT', self.tempdir):
      pkgs = [p for p in source_package.SourcePackageIterator()]
    self.assertEqual(len(pkgs), 1)
    self.assertEqual(pkgs[0].NAME, 'foo')

  def testGetBuildLocation(self):
    root = self.CreateTestPackage('foo')
    pkg = source_package.SourcePackage(root)
    location = pkg.GetBuildLocation()
    self.assertTrue(location.startswith(paths.BUILD_ROOT))
    self.assertEqual(os.path.basename(location),
                     '%s-%s' % (pkg.NAME, pkg.VERSION))

  @patch('naclports.util.Log', Mock())
  def testExtract(self):
    root = self.CreateTestPackage('foo', 'URL=someurl.tar.gz\nSHA1=123')
    pkg = source_package.SourcePackage(root)

    def fake_extract(archive, dest):
      os.mkdir(os.path.join(dest, '%s-%s' % (pkg.NAME, pkg.VERSION)))

    with patch('naclports.source_package.ExtractArchive', fake_extract):
      pkg.Extract()

  def testCreatePackageInvalid(self):
    with self.assertRaisesRegexp(error.Error, 'Package not found: foo'):
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
    with patch('naclports.util.IsInstalled', Mock(return_value=False)):
      pkg.CheckInstallable()

    # with all possible packages installed
    with patch('naclports.util.IsInstalled') as is_installed:
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
      with self.assertRaises(error.DisabledError):
        pkg.CheckInstallable()

  def testCheckBuildable(self):
    root = self.CreateTestPackage('foo', 'BUILD_OS=solaris')
    pkg = source_package.SourcePackage(root)
    with self.assertRaisesRegexp(error.DisabledError,
                                 'can only be built on solaris'):
      pkg.CheckBuildable()

  @patch('naclports.util.GetSDKVersion', Mock(return_value=1234))
  def testInstalledInfoContents(self):
    root = self.CreateTestPackage('foo')
    pkg = source_package.SourcePackage(root)
    expected_contents = textwrap.dedent('''\
      NAME=foo
      VERSION=1.0
      BUILD_CONFIG=release
      BUILD_ARCH=x86_64
      BUILD_TOOLCHAIN=newlib
      BUILD_SDK_VERSION=1234
      ''')
    self.assertRegexpMatches(pkg.InstalledInfoContents(), expected_contents)

  def testRunGitCmd_BadRepo(self):
    os.mkdir(os.path.join(self.tempdir, '.git'))
    with self.assertRaisesRegexp(error.Error, 'git command failed'):
      source_package.InitGitRepo(self.tempdir)

  def testInitGitRepo(self):
    # init a git repo containing a single dummy file
    with open(os.path.join(self.tempdir, 'file'), 'w') as f:
      f.write('bar')
    source_package.InitGitRepo(self.tempdir)
    self.assertTrue(os.path.isdir(os.path.join(self.tempdir, '.git')))

    # InitGitRepo should work on existing git repositories too.
    source_package.InitGitRepo(self.tempdir)


class TestCommands(NaclportsTest):
  def testListCommand(self):
    config = Configuration()
    pkg = Mock(NAME='foo', VERSION='0.1')
    with patch('naclports.package.InstalledPackageIterator',
               Mock(return_value=[pkg])):
      with patch('sys.stdout', new_callable=StringIO.StringIO) as stdout:
        options = Mock(all=False)
        naclports.__main__.CmdList(config, options, [])
        lines = stdout.getvalue().splitlines()
        self.assertRegexpMatches(lines[0], '^foo\\s+0.1$')
        self.assertEqual(len(lines), 1)

  def testListCommandVerbose(self):
    config = Configuration()
    pkg = Mock(NAME='foo', VERSION='0.1')
    with patch('naclports.package.InstalledPackageIterator',
               Mock(return_value=[pkg])):
      with patch('sys.stdout', new_callable=StringIO.StringIO) as stdout:
        options = Mock(verbose=False, all=False)
        naclports.__main__.CmdList(config, options, [])
        lines = stdout.getvalue().splitlines()
        self.assertRegexpMatches(lines[0], "^foo$")
        self.assertEqual(len(lines), 1)

  @patch('naclports.package.CreateInstalledPackage', Mock())
  def testInfoCommand(self):
    config = Configuration()
    options = Mock()
    file_mock = MockFileObject('FOO=bar\n')

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


class TestUtil(unittest.TestCase):
  def setUp(self):
    AddPatch(self, patch('naclports.util.GetSDKRoot',
             Mock(return_value='/sdk/root')))
    AddPatch(self, patch('naclports.util.GetPlatform',
             Mock(return_value='linux')))

  @patch('naclports.util.HashFile', Mock(return_value='sha1'))
  def testVerifyHash(self):
    self.assertTrue(util.VerifyHash('foo', 'sha1'))
    self.assertFalse(util.VerifyHash('foo', 'sha1x'))

  @patch.dict('os.environ', {'PATH': '/x/y/z'})
  def testFindInPath(self):
    with self.assertRaisesRegexp(error.Error, "command not found: foo"):
      util.FindInPath('foo')

    with patch('os.path.exists') as mock_exists:
      executable = os.path.join('/x/y/z', 'somefile')
      self.assertEqual(util.FindInPath('somefile'), executable)
      mock_exists.assert_called_once_with(executable)

  def testCheckStamp_Missing(self):
    with patch('os.path.exists', Mock(return_value=False)):
      self.assertFalse(util.CheckStamp('foo.stamp', ''))

  def testCheckStamp_Contents(self):
    temp_fd, temp_name = tempfile.mkstemp('naclports_test')
    self.addCleanup(os.remove, temp_name)

    stamp_contents = 'stamp file contents'
    with os.fdopen(temp_fd, 'w') as f:
      f.write(stamp_contents)

    self.assertTrue(util.CheckStamp(temp_name, stamp_contents))
    self.assertFalse(util.CheckStamp(temp_name, stamp_contents + 'x'))

  def testGetToolchainRoot(self):
    expected = '/sdk/root/toolchain/linux_x86_newlib/x86_64-nacl'
    self.assertEqual(util.GetToolchainRoot(Configuration()), expected)

  def testGetInstallRoot(self):
    expected = '/sdk/root/toolchain/linux_x86_newlib/x86_64-nacl/usr'
    self.assertEqual(util.GetInstallRoot(Configuration()), expected)

    expected = '/sdk/root/toolchain/linux_pnacl/usr/local'
    self.assertEqual(util.GetInstallRoot(Configuration('pnacl')), expected)

  def testHashFile(self):
    temp_name = tempfile.mkstemp('naclports_test')[1]
    self.addCleanup(os.remove, temp_name)

    with self.assertRaises(IOError):
      util.HashFile('/does/not/exist')

    sha1_empty_string = 'da39a3ee5e6b4b0d3255bfef95601890afd80709'
    self.assertEqual(util.HashFile(temp_name), sha1_empty_string)

  @patch('naclports.paths.NACLPORTS_ROOT', '/foo')
  def testRelPath(self):
    self.assertEqual('bar', util.RelPath('/foo/bar'))
    self.assertEqual('../baz/bar', util.RelPath('/baz/bar'))


class TestMain(NaclportsTest):
  def setUp(self):
    super(TestMain, self).setUp()
    patcher = patch('naclports.util.CheckSDKRoot')
    patcher.start()
    self.addCleanup(patcher.stop)

  @patch('naclports.Log', Mock())
  @patch('shutil.rmtree', Mock())
  def testCleanAll(self):
    config = Configuration()
    naclports.__main__.CleanAll(config)

  @patch('naclports.__main__.run_main',
         Mock(side_effect=error.Error('oops')))
  def testErrorReport(self):
    # Verify that exceptions of the type error.Error are printed
    # to stderr and result in a return code of 1
    with patch('sys.stderr', new_callable=StringIO.StringIO) as stderr:
      self.assertEqual(naclports.__main__.main(None), 1)
    self.assertRegexpMatches(stderr.getvalue(), '^naclports: oops')

  @patch('naclports.__main__.CmdPkgClean')
  def testMainCommandDispatch(self, cmd_pkg_clean):
    mock_pkg = Mock()
    with patch('naclports.source_package.CreatePackage',
               Mock(return_value=mock_pkg)):
      naclports.__main__.run_main(['clean', 'foo'])
    cmd_pkg_clean.assert_called_once_with(mock_pkg, mock.ANY)

  @patch('naclports.__main__.CmdPkgClean',
         Mock(side_effect=error.DisabledError()))
  def testMainHandlePackageDisabled(self):
    mock_pkg = Mock()
    with patch('naclports.source_package.CreatePackage',
               Mock(return_value=mock_pkg)):
      with self.assertRaises(error.DisabledError):
        naclports.__main__.run_main(['clean', 'foo'])

  @patch('naclports.__main__.CleanAll')
  def testMainCleanAll(self, clean_all_mock):
    naclports.__main__.run_main(['clean', '--all'])
    clean_all_mock.assert_called_once_with(Configuration())
