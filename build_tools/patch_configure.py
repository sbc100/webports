#!/usr/bin/env python
# Copyright (c) 2013 The Native Client Authors. All rights reserved.
# Use of this source code is governed by a BSD-style license that can be
# found in the LICENSE file.
"""Script to patch a configure script in-place such that the libtool
dynamic library detection works for NaCl.

Once this patch makes it into upstream libtool it should eventually
be possible to remove this completely.
"""
import optparse
import sys

CONFIGURE_PATCH = '''
nacl)
  if $CC -v 2>&1 | grep -q enable-shared; then
    version_type=linux
    library_names_spec='${libname}${release}${shared_ext}$versuffix ${libname}${release}${shared_ext}${major} ${libname}${shared_ext}'
    soname_spec='${libname}${release}${shared_ext}$major'
  else
    dynamic_linker=no
  fi
  ;;
'''

def main(args):
  usage = "usage: %prog [options] <configure_script>"
  parser = optparse.OptionParser(usage=usage)
  args = parser.parse_args(args)[1]
  if not args:
    parser.error("no configure script specified")
  configure = args[0]

  # Read configure
  with open(configure) as input_file:
    filedata = input_file.read()

  # Check for patch location
  pos = filedata.find('\n*)\n  dynamic_linker=no\n')
  if pos == -1:
    sys.stderr.write("Failed to find patch location in configure "
                     "script: %s\n" % configure)
    return 0

  # Apply patch
  filedata = filedata[:pos] + CONFIGURE_PATCH + filedata[pos:]

  # Overwrite input file with patched file data
  with open(configure, 'w') as output_file:
    output_file.write(filedata)

  return 0

if __name__ == '__main__':
  sys.exit(main(sys.argv[1:]))
