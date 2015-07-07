# Copyright 2015 The Native Client Authors. All rights reserved.
# Use of this source code is governed by a BSD-style license that can be
# found in the LICENSE file.

"""Basic implemenation of FreeBSD pkg file format.

This is just enough to allow us to create archive files
that pkg will then be able to install.

See https://github.com/freebsd/pkg#pkgfmt for information
on this package format.
"""

import tarfile
import os
import collections

MANIFEST = '+MANIFEST'
COMPACT_MANIFEST = '+COMPACT_MANIFEST'


def WriteUCL(outfile, ucl_dict):
  """Write a dictionary to file in UCL format"""

  # See: https://github.com/vstakhov/libucl
  with open(outfile, 'w') as f:
    f.write('{\n')
    for key, value in ucl_dict.iteritems():
      f.write('  "%s": "%s",\n' % (key, value))
    f.write('}\n')


def CreatePkgFile(name, version, arch, payload_dir, outfile):
  """Create an archive file in FreeBSD's pkg file format"""
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
  manifest['prefix'] = '/'

  WriteUCL(os.path.join(payload_dir, MANIFEST), manifest)
  WriteUCL(os.path.join(payload_dir, COMPACT_MANIFEST), manifest)

  with tarfile.open(outfile, 'w:bz2') as tar:
    for filename in os.listdir(payload_dir):
      if filename.startswith('+'):
        fullname = os.path.join(payload_dir, filename)
        arcname = filename
        tar.add(fullname, arcname=arcname)

    for filename in os.listdir(payload_dir):
      if not filename.startswith('+'):
        fullname = os.path.join(payload_dir, filename)
        arcname = filename
        tar.add(fullname, arcname=arcname)
