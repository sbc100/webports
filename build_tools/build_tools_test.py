#!/usr/bin/env python
# Copyright 2014 The Native Client Authors. All rights reserved.
# Use of this source code is governed by a BSD-style license that can be
# found in the LICENSE file.

import os
import patch_configure
import scan_packages
import sys
import StringIO
import unittest

SCRIPT_DIR = os.path.dirname(os.path.abspath(__file__))
SRC_DIR = os.path.dirname(SCRIPT_DIR)
MOCK_DIR = os.path.join(SRC_DIR, 'third_party', 'mock')
sys.path.append(MOCK_DIR)

from mock import Mock, patch, call


def MockFileObject(contents):
  file_mock = Mock(name="file_mock", spec=file)
  file_mock.read.return_value = contents
  file_mock.__enter__ = lambda s: s
  file_mock.__exit__ = Mock(return_value=False)
  return file_mock


class TestPatchConfigure(unittest.TestCase):
  @patch('sys.stderr', new_callable=StringIO.StringIO)
  def testMissingFile(self, stderr):
    rtn = patch_configure.main(['foo'])
    self.assertEqual(rtn, 1)
    self.assertRegexpMatches(stderr.getvalue(),
                             '^configure script not found: foo$')


class TestScanPackages(unittest.TestCase):
  def testCheckHash(self):
    file_mock = MockFileObject('1234\n')
    md5 = Mock()
    md5.hexdigest.return_value('4321')
    with patch('__builtin__.open', Mock(return_value=file_mock), create=True):
      scan_packages.CheckHash('foo', '1234')

  @patch('naclports.package_index.PREBUILT_ROOT', 'dummydir')
  @patch('scan_packages.Log', Mock())
  @patch('scan_packages.CheckHash')
  @patch('os.path.exists', Mock(return_value=True))
  def testDownloadFiles(self, check_hash_mock):
    check_hash_mock.return_value = True
    file_info = scan_packages.FileInfo('foo', 10, 'http://host/base', 'hashval')
    scan_packages.DownloadFiles([file_info])
    check_hash_mock.assert_called_once_with('dummydir/base', 'hashval')


if __name__ == '__main__':
  unittest.main()
