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
import fcntl
import optparse
import os
import shutil
import sys

sys.path.append(os.path.dirname(os.path.dirname(__file__)))

import naclports
import naclports.binary_package
from naclports import Error, DisabledError, Trace, NACL_SDK_ROOT
from naclports.package import PackageIterator
from naclports.configuration import Configuration


def CmdList(config, options, args):
  if len(args):
    raise Error('list command takes no arguments')
  stamp_root = naclports.GetInstallStampRoot(config)
  if os.path.exists(stamp_root):
    for filename in os.listdir(stamp_root):
      basename, ext = os.path.splitext(filename)
      if ext != '.info':
        continue
      if options.verbose:
        fullname = os.path.join(stamp_root, filename)
        valid_keys = naclports.VALID_KEYS + naclports.binary_package.EXTRA_KEYS
        info = naclports.ParsePkgInfoFile(fullname, valid_keys)
        sys.stdout.write('%-15s %s\n' % (info['NAME'], info['VERSION']))
      else:
        sys.stdout.write(basename + '\n')
  return 0


def CmdInfo(config, options, args):
  if len(args) != 1:
    raise Error('info command takes a single package name')
  package_name = args[0]
  info_file = naclports.GetInstallStamp(package_name, config)
  print 'Install receipt: %s' % info_file
  if not os.path.exists(info_file):
    raise Error('package not installed: %s [%s]' % (package_name, config))
  with open(info_file) as f:
    sys.stdout.write(f.read())


def CmdContents(config, options, args):
  if len(args) != 1:
    raise Error('contents command takes a single package name')
  package_name = args[0]
  list_file = naclports.GetFileList(package_name, config)
  if not os.path.exists(list_file):
    raise Error('package not installed: %s [%s]' % (package_name, config))

  install_root = naclports.GetInstallRoot(config)
  with open(list_file) as f:
    if options.verbose:
      for line in f:
        sys.stdout.write(os.path.join(install_root, line))
    else:
      sys.stdout.write(f.read())


def CmdPkgDownload(package, options):
  package.Download()


def CmdPkgCheck(package, options):
  # The fact that we got this far means the pkg_info is basically valid.
  # This final check verifies the dependencies are valid.
  # Cache the list of all packages names since this function could be called
  # a lot in the case of "naclports check --all".
  packages = PackageIterator()
  if not CmdPkgCheck.all_package_names:
    CmdPkgCheck.all_package_names = [os.path.basename(p.root) for p in packages]
  naclports.Log("Checking deps for %s .." % package.NAME)
  package.CheckDeps(CmdPkgCheck.all_package_names)

CmdPkgCheck.all_package_names = None


def CmdPkgBuild(package, options):
  package.Build(options.build_deps, force=options.force)


def CmdPkgInstall(package, options):
  package.Install(options.build_deps, force=options.force,
                  from_source=options.from_source)


def CmdPkgUninstall(package, options):
  package.Uninstall(options.all)


def CmdPkgClean(package, options):
  package.Clean()


def CmdPkgVerify(package, options):
  package.Verify()


def GetLock():
  lock_file_name = os.path.join(naclports.OUT_DIR, 'naclports.lock')
  if not os.path.exists(naclports.OUT_DIR):
    os.makedirs(naclports.OUT_DIR)
  f = open(lock_file_name, 'w')
  try:
    fcntl.flock(f, fcntl.LOCK_EX | fcntl.LOCK_NB)
  except Exception as e:
    raise Error("Unable to lock file (%s): Is naclports already running?" %
        lock_file_name)
  return f


def run_main(args):
  usage = 'Usage: %prog [options] <command> [<package_dir>]'
  parser = optparse.OptionParser(prog='naclports', description=__doc__,
                                 usage=usage)
  parser.add_option('-v', '--verbose', action='store_true',
                    help='Output extra information.')
  parser.add_option('-V', '--verbose-build', action='store_true',
                    help='Make the build itself version (e.g. pass V=1 to make')
  parser.add_option('--all', action='store_true',
                    help='Perform action on all known ports.')
  parser.add_option('-f', '--force', action='store_const', const='build',
                    help='Force building specified targets, '
                    'even if timestamps would otherwise skip it.')
  parser.add_option('--from-source', action='store_true',
                    help='Always build from source rather than downloading '
                    'prebuilt packages.')
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
  args = args[1:]

  lock_file = GetLock()

  naclports.verbose = options.verbose or os.environ.get('VERBOSE') == '1'
  if options.verbose_build:
    os.environ['VERBOSE'] = '1'
  else:
    os.environ['VERBOSE'] = '0'
    os.environ['V'] = '0'

  if not NACL_SDK_ROOT:
    raise Error('$NACL_SDK_ROOT not set')

  if not os.path.isdir(NACL_SDK_ROOT):
    raise Error('$NACL_SDK_ROOT does not exist: %s' % NACL_SDK_ROOT)

  sentinel = os.path.join(NACL_SDK_ROOT, 'tools', 'getos.py')
  if not os.path.exists(sentinel):
    raise Error("$NACL_SDK_ROOT (%s) doesn't look right. "
                "Couldn't find sentinel file (%s)" % (NACL_SDK_ROOT, sentinel))

  config = Configuration(options.arch, options.toolchain, options.debug)

  base_commands = {
    'list': CmdList,
    'info': CmdInfo,
    'contents': CmdContents
  }

  pkg_commands = {
    'download': CmdPkgDownload,
    'check': CmdPkgCheck,
    'build': CmdPkgBuild,
    'uninstall': CmdPkgUninstall,
    'install': CmdPkgInstall,
    'verify': CmdPkgVerify,
    'clean': CmdPkgClean,
  }

  if command in base_commands:
    base_commands[command](config, options, args)
    return 0

  if command not in pkg_commands:
    parser.error("Unknown subcommand: '%s'\n"
                 'See --help for available commands.' % command)

  if len(args) and options.all:
    parser.error('Package name(s) and --all cannot be specified together')

  if args:
    package_dirs = args
  else:
    package_dirs = [os.getcwd()]

  def DoCmd(package):
    try:
      pkg_commands[command](package, options)
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
      for p in PackageIterator():
        if not p.DISABLED:
          DoCmd(p)
  else:
    for package_dir in package_dirs:
      p = naclports.package.CreatePackage(package_dir, config)
      DoCmd(p)


def main(args):
  try:
    run_main(args)
  except KeyboardInterrupt:
    sys.stderr.write('naclports: interrupted\n')
    return 1
  except Error as e:
    sys.stderr.write('naclports: %s\n' % e)
    return 1

  return 0

if __name__ == '__main__':
  sys.exit(main(sys.argv[1:]))
