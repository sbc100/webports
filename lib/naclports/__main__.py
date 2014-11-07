# Copyright (c) 2013 The Native Client Authors. All rights reserved.
# Use of this source code is governed by a BSD-style license that can be
# found in the LICENSE file.
"""Tool for manipulating naclports packages in python.

This tool can be used to for working with naclports packages.
It can also be incorporated into other tools that need to
work with packages (e.g. 'update_mirror.py' uses it to iterate
through all packages and mirror them on Google Cloud Storage).
"""
from __future__ import print_function
import os
import shutil
import sys

if sys.version_info < (2, 7, 0):
  sys.stderr.write("python 2.7 or later is required run this script\n")
  sys.exit(1)

import argparse

sys.path.append(os.path.dirname(os.path.dirname(__file__)))

import naclports
import naclports.binary_package
import naclports.package
import naclports.source_package
from naclports import Error, DisabledError, Trace, NACL_SDK_ROOT
from naclports.configuration import Configuration


def CmdList(config, options, args):
  """List installed packages"""
  if len(args):
    raise Error('list command takes no arguments')
  for package in naclports.package.InstalledPackageIterator(config):
    if options.verbose:
      sys.stdout.write('%-15s %s\n' % (package.NAME, package.VERSION))
    else:
      sys.stdout.write(package.NAME + '\n')
  return 0


def CmdInfo(config, options, args):
  """Print infomation on installed package(s)"""
  if len(args) != 1:
    raise Error('info command takes a single package name')
  package_name = args[0]
  pkg = naclports.package.CreateInstalledPackage(package_name, config)
  info_file = pkg.GetInstallStamp()
  print('Install receipt: %s' % info_file)
  with open(info_file) as f:
    sys.stdout.write(f.read())


def CmdPkgContents(package, options):
  """List contents of an installed package"""
  install_root = naclports.GetInstallRoot(package.config)
  for filename in package.Files():
    if options.verbose:
      filename = os.path.join(install_root, filename)
    if options.all:
      filename = package.NAME + ': ' + filename
    sys.stdout.write(filename + '\n')


def CmdPkgDownload(package, options):
  """Download sources for given package(s)"""
  package.Download()


def CmdPkgCheck(package, options):
  """Verify dependency information for given package(s)"""
  # The fact that we got this far means the pkg_info is basically valid.
  # This final check verifies the dependencies are valid.
  # Cache the list of all packages names since this function could be called
  # a lot in the case of "naclports check --all".
  packages = naclports.source_package.SourcePackageIterator()
  if not CmdPkgCheck.all_package_names:
    CmdPkgCheck.all_package_names = [os.path.basename(p.root) for p in packages]
  naclports.Log("Checking deps for %s .." % package.NAME)
  package.CheckDeps(CmdPkgCheck.all_package_names)

CmdPkgCheck.all_package_names = None


def CmdPkgBuild(package, options):
  """Build package(s)"""
  package.Build(options.build_deps, force=options.force)


def CmdPkgInstall(package, options):
  """Install package(s)"""
  if options.all:
    for conflict in package.TransitiveConflicts():
      if conflict.IsInstalled():
        conflict.GetInstalledPackage().Uninstall()

  package.Install(options.build_deps, force=options.force,
                  from_source=options.from_source)


def CmdPkgUninstall(package, options):
  """Uninstall package(s)"""
  package.Uninstall()


def CmdPkgClean(package, options):
  """Clean package build artifacts."""
  package.Clean()


def CmdPkgVerify(package, options):
  """Verify package(s)"""
  package.Verify()


def CleanAll(config):
  """Remove all build directories and all pre-built packages as well
  as all installed packages for the given configuration."""
  def rmtree(path):
    naclports.Log('removing %s' % path)
    if os.path.exists(path):
      shutil.rmtree(path)

  rmtree(naclports.STAMP_DIR)
  rmtree(naclports.BUILD_ROOT)
  rmtree(naclports.PUBLISH_ROOT)
  rmtree(naclports.PACKAGES_ROOT)
  rmtree(naclports.GetInstallStampRoot(config))
  rmtree(naclports.GetInstallRoot(config))


def run_main(args):
  base_commands = {
    'list': CmdList,
    'info': CmdInfo,
  }

  pkg_commands = {
    'download': CmdPkgDownload,
    'check': CmdPkgCheck,
    'build': CmdPkgBuild,
    'install': CmdPkgInstall,
    'verify': CmdPkgVerify,
    'clean': CmdPkgClean,
    'uninstall': CmdPkgUninstall,
    'contents': CmdPkgContents
  }

  installed_pkg_commands = ['contents', 'uninstall']

  all_commands = dict(base_commands.items() + pkg_commands.items())

  epilog = "The following commands are available:\n"
  for name, function in all_commands.iteritems():
    epilog += '  %-10s - %s\n' % (name, function.__doc__)

  parser = argparse.ArgumentParser(prog='naclports', description=__doc__,
      formatter_class=argparse.RawDescriptionHelpFormatter, epilog=epilog)
  parser.add_argument('-v', '--verbose', action='store_true',
                      help='Output extra information.')
  parser.add_argument('-V', '--verbose-build', action='store_true',
                      help='Make builds verbose (e.g. pass V=1 to make')
  parser.add_argument('--all', action='store_true',
                      help='Perform action on all known ports.')
  parser.add_argument('-f', '--force', action='store_const', const='build',
                      help='Force building specified targets, '
                      'even if timestamps would otherwise skip it.')
  parser.add_argument('--from-source', action='store_true',
                      help='Always build from source rather than downloading '
                      'prebuilt packages.')
  parser.add_argument('-F', '--force-all', action='store_const', const='all',
                      dest='force', help='Force building target and all '
                      'dependencies, even if timestamps would otherwise skip '
                      'them.')
  parser.add_argument('--no-deps', dest='build_deps', action='store_false',
                      default=True,
                      help='Disable automatic building of dependencies.')
  parser.add_argument('--ignore-disabled', action='store_true',
                      help='Ignore attempts to build disabled packages.\n'
                      'Normally attempts to build such packages will result\n'
                      'in an error being returned.')
  parser.add_argument('--toolchain',
                      help='Set toolchain to use when building (newlib, glibc, '
                      'or pnacl)')
  parser.add_argument('--debug',
                      help='Build debug configuration (release is the default)')
  parser.add_argument('--arch',
                      help='Set architecture to use when building (x86_64,'
                      ' x86_32, arm, pnacl)')
  parser.add_argument('command', help="sub-command to run")
  parser.add_argument('pkg', nargs='*', help="package name or directory")
  args = parser.parse_args(args)

  naclports.verbose = args.verbose or os.environ.get('VERBOSE') == '1'
  if args.verbose_build:
    os.environ['VERBOSE'] = '1'
  else:
    if 'VERBOSE' in os.environ:
      del os.environ['VERBOSE']
    if 'V' in os.environ:
      del os.environ['V']

  if not NACL_SDK_ROOT:
    raise Error('$NACL_SDK_ROOT not set')

  if not os.path.isdir(NACL_SDK_ROOT):
    raise Error('$NACL_SDK_ROOT does not exist: %s' % NACL_SDK_ROOT)

  sentinel = os.path.join(NACL_SDK_ROOT, 'tools', 'getos.py')
  if not os.path.exists(sentinel):
    raise Error("$NACL_SDK_ROOT (%s) doesn't look right. "
                "Couldn't find sentinel file (%s)" % (NACL_SDK_ROOT, sentinel))

  config = Configuration(args.arch, args.toolchain, args.debug)

  if args.command in base_commands:
    base_commands[args.command](config, args, args.pkg)
    return 0

  if args.command not in pkg_commands:
    parser.error("Unknown subcommand: '%s'\n"
                 'See --help for available commands.' % args.command)

  if len(args.pkg) and args.all:
    parser.error('Package name(s) and --all cannot be specified together')

  if args.pkg:
    package_names = args.pkg
  else:
    package_names = [os.getcwd()]

  def DoCmd(package):
    try:
      pkg_commands[args.command](package, args)
    except DisabledError as e:
      if args.ignore_disabled:
        naclports.Log('naclports: %s' % e)
      else:
        raise e

  if args.all:
    args.ignore_disabled = True
    if args.command == 'clean':
      CleanAll(config)
    else:
      if args.command in installed_pkg_commands:
        package_iterator = naclports.package.InstalledPackageIterator(config)
      else:
        package_iterator = naclports.source_package.SourcePackageIterator()
      for p in package_iterator:
        if not p.DISABLED:
          DoCmd(p)
  else:
    for package_name in package_names:
      if args.command in installed_pkg_commands:
        p = naclports.package.CreateInstalledPackage(package_name, config)
      else:
        p = naclports.source_package.CreatePackage(package_name, config)
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
