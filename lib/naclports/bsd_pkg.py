# Copyright 2015 The Native Client Authors. All rights reserved.
# Use of this source code is governed by a BSD-style license that can be
# found in the LICENSE file.

"""Basic implemenation of FreeBSD pkg file format.

This is just enough to allow us to create archive files
that pkg will then be able to install.

See https://github.com/freebsd/pkg#pkgfmt for information
on this package format.
"""

import collections
import hashlib
import os
import shutil
import subprocess
import tarfile

from naclports import util


def WriteUCL(outfile, ucl_dict):
  """Write a dictionary to file in UCL format"""

  # See: https://github.com/vstakhov/libucl
  with open(outfile, 'w') as f:
    f.write('{\n')
    for key, value in ucl_dict.iteritems():
      if key == 'files':
        f.write('  "%s": \n  {\n' % key)
        for file_name, file_hash in value.iteritems():
          f.write('    "%s": "%s",\n' % (file_name, file_hash))
        f.write('  }\n')
      else:
        f.write('  "%s": "%s",\n' % (key, value))
    f.write('}\n')


def ParseDir(payload_dir, file_dict, prefix):
  for filename in os.listdir(payload_dir):
    if not filename.startswith('+'):
      fullname = os.path.join(payload_dir, filename)
      if os.path.isdir(fullname):
        ParseDir(fullname, file_dict, prefix + filename + '/')
      else:
        with open(fullname, 'rb') as f:
          file_dict[prefix + filename] = hashlib.sha256(f.read()).hexdigest()


def AddFilesInDir(content_dir, tar, prefix):
  for filename in os.listdir(content_dir):
    fullname = os.path.join(content_dir, filename)
    if os.path.isdir(fullname):
      AddFilesInDir(fullname, tar, prefix)
    else:
      # Rather convoluted way to add files to a tar archive that are
      # abolute (i.e. start with /).  pkg requires this, but python's
      # tar.py calls lstrip('/') on arcname in the tar.add() method.
      with open(fullname, 'r') as f:
        info = tar.gettarinfo(fileobj=f)
        info.name = fullname.replace(prefix, '')
        tar.addfile(info, fileobj=f)


def CreatePkgFile(name, version, arch, payload_dir, outfile):
  """Create an archive file in FreeBSD's pkg file format"""
  util.Log('Creating pkg package: %s' % outfile)
  manifest = collections.OrderedDict()
  manifest['name'] = name
  manifest['version'] =  version
  manifest['arch'] = 'nacl:0:%s' % arch

  # The following fields are required by 'pkg' but we don't have
  # meaningful values for them yet
  manifest['origin'] = name,
  manifest['comment'] = 'comment not available'
  manifest['desc'] = 'desc not available'
  manifest['maintainer'] = 'native-client-discuss@googlegroups.com'
  manifest['www'] = 'https://code.google.com/p/naclports/'
  manifest['prefix'] = '/mnt/html5/usr/local/'
  temp_dir = os.path.splitext(outfile)[0] + '.tmp'
  if os.path.exists(temp_dir):
    shutil.rmtree(temp_dir)
  os.mkdir(temp_dir)

  content_dir = os.path.join(temp_dir, 'mnt/html5/usr/local')
  shutil.copytree(payload_dir, content_dir)
  WriteUCL(os.path.join(temp_dir, '+COMPACT_MANIFEST'), manifest)
  file_dict = collections.OrderedDict()
  ParseDir(temp_dir, file_dict, '/')
  manifest['files'] = file_dict
  WriteUCL(os.path.join(temp_dir, '+MANIFEST'), manifest)

  with tarfile.open(outfile, 'w:bz2') as tar:
    for filename in os.listdir(temp_dir):
      if filename.startswith('+'):
        fullname = os.path.join(temp_dir, filename)
        tar.add(fullname, arcname=filename)

    for filename in os.listdir(temp_dir):
      if not filename.startswith('+'):
        fullname = os.path.join(temp_dir, filename)
        AddFilesInDir(fullname, tar, temp_dir)
  shutil.rmtree(temp_dir)
