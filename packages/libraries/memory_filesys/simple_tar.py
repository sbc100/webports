#!/usr/bin/python
# Copyright (c) 2010 The Native Client Authors. All rights reserved.
# Use of this source code is governed by a BSD-style license that be
# found in the LICENSE file.

import os
import posixpath
import sys

  
def SimpleTar(src, dst):
  """Tar a directory in a simple format.

  Arguments:
    src: source directory path.
    dst: destination filename.
  """
  dstf = open(dst, 'wb')
  dstf.write('%d %d\n' % (len(src), -1))
  dstf.write(src)
  for root, dirs, files in os.walk(src):
    for name in dirs:
      path = posixpath.join(root, name)
      dstf.write('%d %d\n' % (len(path), -1))
      dstf.write(path)
    for name in files:
      path = posixpath.join(root, name)
      data = open(path, 'rb').read()
      dstf.write('%d %d\n' % (len(path), len(data)))
      dstf.write(path)
      dstf.write(data) 
  dstf.close()


def main(argv):
  if len(argv) != 3:
    sys.stderr.write('Usage: simple_tar.py <src_path> <tarfile>\n');
    return 1
  SimpleTar(argv[1], argv[2])
  return 0
 

if __name__ == '__main__':
  sys.exit(main(sys.argv))
