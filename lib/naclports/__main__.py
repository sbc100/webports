#!/usr/bin/env python
# Copyright (c) 2013 The Native Client Authors. All rights reserved.
# Use of this source code is governed by a BSD-style license that can be
# found in the LICENSE file.
"""Tool for manipulating naclports packages in python.

This tool can be used to for working with naclports packages.
It can also be incorporated into other tools that need to
work with packages (e.g. 'update_mirror.py' uses it to iterate
through all packages and mirror them on Google Cloud Storage).
"""
import optparse
import os
import shutil
import sys

sys.path.append(os.path.dirname(os.path.dirname(__file__)))

import naclports.package
from naclports import Error, DisabledError, Trace, Configuration, NACL_SDK_ROOT

def run_main(args):
  usage = "Usage: %prog [options] <command> [<package_dir>]"
  parser = optparse.OptionParser(prog='naclports', description=__doc__,
                                 usage=usage)
  parser.add_option('-v', '--verbose', action='store_true',
                    help='Output extra information.')
  parser.add_option('-V', '--verbose-build', action='store_true',
                    help='Make the build itself version (e.g. pass V=1 to make')
  parser.add_option('--all', action='store_true',
                    help='Perform action on all known ports.')
  parser.add_option('-f', '--force', action='store_const', const='build',
                    dest='force', help='Force building specified targets, '
                    'even if timestamps would otherwise skip it.')
  parser.add_option('-F', '--force-all', action='store_const', const='all',
                    dest='force', help='Force building target and all '
                    'dependencies, even if timestamps would otherwise skip '
                    'them.')
  parser.add_option('--no-deps', dest='build_deps', action='store_false',
                    default=True,
                    help='Disable automatic building of dependencies.')
  parser.add_option('--ignore-disabled', action='store_true',
                    help='Ignore attempts to build disabled packages.\n'
                    'Normally attempts to build such packages will result\n'
                    'in an error being returned.')
  parser.add_option('--toolchain',
                    help='Set toolchain to use when building (newlib, glibc, or'
                    ' pnacl)"')
  parser.add_option('--debug',
                    help='Build debug configuration (release is the default)')
  parser.add_option('--arch',
                    help='Set architecture to use when building (x86_64,'
                    ' x86_32, arm, pnacl)')
  options, args = parser.parse_args(args)
  if not args:
    parser.error('You must specify a sub-command. See --help.')

  command = args[0]

  verbose = options.verbose or os.environ.get('VERBOSE') == '1'
  Trace.verbose = verbose
  if options.verbose_build:
    os.environ['VERBOSE'] = '1'
  else:
    os.environ['VERBOSE'] = '0'
    os.environ['V'] = '0'

  if not NACL_SDK_ROOT:
    raise Error('$NACL_SDK_ROOT not set')

  if not os.path.isdir(NACL_SDK_ROOT):
    raise Error('$NACL_SDK_ROOT does not exist: %s' % NACL_SDK_ROOT)

  config = Configuration(options.arch, options.toolchain, options.debug)

  if command == 'list':
    stamp_root = naclports.GetInstallStampRoot(config)
    if os.path.exists(stamp_root):
      for filename in os.listdir(stamp_root):
        basename, ext = os.path.splitext(filename)
        if ext != '.info':
          continue
        naclports.Log(basename)
    return 0
  elif command == 'info':
    if len(args) != 2:
      parser.error('info command takes a single package name')
    package_name = args[1]
    info_file = GetInstallStamp(package_name, config)
    print "Install receipt: %s" % info_file
    if not os.path.exists(info_file):
      raise Error('package not installed: %s [%s]' % (package_name, config))
    with open(info_file) as f:
      sys.stdout.write(f.read())
    return 0
  elif command == 'contents':
    if len(args) != 2:
      parser.error('contents command takes a single package name')
    package_name = args[1]
    list_file = naclports.GetFileList(package_name, config)
    if not os.path.exists(list_file):
      raise Error('package not installed: %s [%s]' % (package_name, config))
    with open(list_file) as f:
      sys.stdout.write(f.read())
    return 0

  package_dirs = ['.']
  if len(args) > 1:
    if options.all:
      parser.error('Package name and --all cannot be specified together')
    package_dirs = args[1:]

  def DoCmd(package):
    try:
      if command == 'download':
        package.Download()
      elif command == 'check':
        # Fact that we've got this far means the pkg_info
        # is basically valid.  This final check verifies the
        # dependencies are valid.
        packages = naclports.package.PackageIterator()
        package_names = [os.path.basename(p.root) for p in packages]
        package.CheckDeps(package_names)
      elif command == 'enabled':
        package.CheckEnabled()
      elif command == 'verify':
        package.Verify()
      elif command == 'clean':
        package.Clean()
      elif command == 'build':
        package.Build(verbose, options.build_deps, options.force)
      elif command == 'install':
        package.Install(verbose, options.build_deps, options.force)
      elif command == 'uninstall':
        package.Uninstall(options.all)
      else:
        parser.error("Unknown subcommand: '%s'\n"
                     "See --help for available commands." % command)
    except DisabledError as e:
      if options.ignore_disabled:
        naclports.Log('naclports: %s' % e)
      else:
        raise e

  def rmtree(path):
    naclports.Log('removing %s' % path)
    if os.path.exists(path):
      shutil.rmtree(path)

  if options.all:
    options.ignore_disabled = True
    if command == 'clean':
      rmtree(naclports.STAMP_DIR)
      rmtree(naclports.BUILD_ROOT)
      rmtree(naclports.PUBLISH_ROOT)
      rmtree(naclports.package.PACKAGES_ROOT)
      rmtree(naclports.GetInstallStampRoot(config))
      rmtree(naclports.GetInstallRoot(config))
    else:
      for p in naclports.package.PackageIterator():
        if not p.DISABLED:
          DoCmd(p)
  else:
    for package_dir in package_dirs:
      p = naclports.package.CreatePackage(package_dir, config)
      DoCmd(p)


def main(args):
  try:
    run_main(args)
  except Error as e:
    sys.stderr.write('naclports: %s\n' % e)
    return 1

  return 0

if __name__ == '__main__':
  sys.exit(main(sys.argv[1:]))
