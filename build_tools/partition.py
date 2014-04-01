#!/usr/bin/env python
# Copyright (c) 2013 The Native Client Authors. All rights reserved.
# Use of this source code is governed by a BSD-style license that can be
# found in the LICENSE file.

"""Manage partitioning of port builds.

Download historical data from the naclports builders, and use it to
partition all of the projects onto the builder shards so each shard builds in
about the same amount of time.

Example use:

    $ ./partition.py -b linux-newlib-

    builder 0 (total: 2786)
      bzip2
      zlib
      boost
      glibc-compat
      openssl
      libogg
      ...
    builder 1 (total: 2822)
      zlib
      libpng
      Regal
      glibc-compat
      ncurses
      ...
    builder 2 (total: 2790)
      zlib
      libpng
      bzip2
      jpeg
      ImageMagick
      glibc-compat
      ...
    Difference between total time of builders: 36


Pipe the results above (with appropriate use of -n and -p) into partition*.txt
so the partition can be used in the future.

The script is also used by the buildbot to read canned partitions.

Example use:

    $ ./partition.py -t <index> -n <number_of_shards>
"""

import json
import optparse
import os
import subprocess
import sys
import urllib2

SCRIPT_DIR = os.path.dirname(os.path.abspath(__file__))
ROOT_DIR = os.path.dirname(SCRIPT_DIR)
ARCHES = ('arm', 'i686', 'x86_64')

verbose = False

import naclports


class Error(Exception):
  pass


def Trace(msg):
  if verbose:
    sys.stderr.write(msg + '\n')


def GetBuildOrder(projects):
  rtn = []
  packages = [naclports.Package(os.path.join('ports', p)) for p in projects]
  for package in packages:
    for dep in package.DEPENDS:
      rtn += GetBuildOrder([dep])
    rtn.append(package.NAME)
  return rtn

def GetDependencies(projects):
  deps = GetBuildOrder(projects)
  return set(deps) - set(projects)


def DownloadDataFromBuilder(builder, build):
  max_tries = 10

  for _ in xrange(max_tries):
    url = 'http://build.chromium.org/p/client.nacl.ports/json'
    url += '/builders/%s/builds/%d' % (builder, build)
    Trace('Downloading %s' % url)
    f = urllib2.urlopen(url)
    try:
      data = json.loads(f.read())
      text = data['text']
      if text == ['build', 'successful']:
        Trace('  Success!')
        return data
      Trace('  Not successful, trying previous build.')
    finally:
      f.close()
    build -= 1

  raise Error('Unable to find a successful build:\nBuilder: %s\nRange: [%d, %d]'
      % (builder, build - max_tries, build))


class Project(object):
  def __init__(self, name):
    self.name = name
    self.time = 0
    self.arch_times = [0] * len(ARCHES)
    self.dep_names = GetDependencies([name])
    self.dep_times = [0] * len(self.dep_names)

  def UpdateArchTime(self, arch, time):
    index = ARCHES.index(arch)
    self.arch_times[index] = max(self.arch_times[index], time)
    self.time = sum(self.arch_times)

  def UpdateDepTimes(self, project_map):
    for i, dep_name in enumerate(self.dep_names):
      dep = project_map[dep_name]
      self.dep_times[i] = dep.time

  def GetTime(self, used_dep_names):
    time = self.time
    for i, dep_name in enumerate(self.dep_names):
      if dep_name not in used_dep_names:
        time += self.dep_times[i]
    return time


class Projects(object):
  def __init__(self):
    self.projects = []
    self.project_map = {}
    self.dependencies = set()

  def AddProject(self, name):
    if name not in self.project_map:
      project = Project(name)
      self.projects.append(project)
      self.project_map[name] = project
    return self.project_map[name]

  def AddDataFromBuilder(self, builder, build):
    data = DownloadDataFromBuilder(builder, build)
    for step in data['steps']:
      text = step['text'][0]
      text_tuple = text.split()
      if len(text_tuple) != 3 or text_tuple[0] not in ARCHES:
        continue
      arch, _, name = text_tuple
      project = self.AddProject(name)
      time = step['times'][1] - step['times'][0]
      project.UpdateArchTime(arch, time)

  def PostProcessDeps(self):
    for project in self.projects:
      project.UpdateDepTimes(self.project_map)
      for dep_name in project.dep_names:
        self.dependencies.add(dep_name)

  def __getitem__(self, name):
    return self.project_map[name]


class ProjectTimes(object):
  def __init__(self):
    self.project_names = set()
    self.projects = []
    self.total_time = 0

  def GetTotalTimeWithProject(self, project):
    return self.total_time + project.GetTime(self.project_names)

  def AddProject(self, projects, project):
    self.AddDependencies(projects, project)
    self.project_names.add(project.name)
    self.projects.append(project)
    self.total_time = self.GetTotalTimeWithProject(project)

  def AddDependencies(self, projects, project):
    for dep_name in project.dep_names:
      if dep_name not in self.project_names:
        self.AddProject(projects, projects[dep_name])

  def HasProject(self, project):
    return project.name in self.project_names

  def TopologicallySortedProjectNames(self, projects):
    sorted_project_names = []

    def Helper(project):
      for dep_name in project.dep_names:
        if dep_name not in sorted_project_names:
          Helper(projects[dep_name])
      sorted_project_names.append(project.name)

    for project in self.projects:
      Helper(project)

    return sorted_project_names


def Partition(projects, dims):
  # Greedy algorithm: sort the projects by slowest to fastest, then add the
  # projects, in order, to the shard that has the least work on it.
  #
  # Note that this takes into account the additional time necessary to build a
  # projects dependencies, if those dependencies have not already been built.
  parts = [ProjectTimes() for _ in xrange(dims)]
  sorted_projects = sorted(projects.projects, key=lambda p: -p.time)
  for project in sorted_projects:
    if any(part.HasProject(project) for part in parts):
      continue

    key = lambda p: p[1].GetTotalTimeWithProject(project)
    index, _ = min(enumerate(parts), key=key)
    parts[index].AddProject(projects, project)
  return parts


def LoadCanned(parts):
  # Return an empty partition for the no-sharding case.
  if parts == 1:
    return [[]]
  partitions = []
  partition = []
  input_file = os.path.join(SCRIPT_DIR, 'partition%d.txt' % parts)
  Trace("LoadCanned: %s" % input_file)
  with open(input_file) as fh:
    for line in fh:
      if line.strip()[0] == '#':
        continue
      if line.startswith('  '):
        partition.append(line[2:].strip())
      else:
        if partition:
          partitions.append(partition)
          partition = []
  assert not partition
  assert len(partitions) == parts, partitions
  # Return a small set of packages for testing.
  if os.environ.get('TEST_BUILDBOT'):
    partitions[0] = [
        'glibc-compat',
        'ncurses',
        'readline',
        'libtar',
        'zlib',
        'lua5.2',
        'lua-ppapi',
    ]
  return partitions


def FixupCanned(partitions):
  all_projects = [p for p in naclports.PackageIterator()]
  all_names = [p.NAME for p in all_projects if not p.DISABLED]

  # Blank the last partition and fill it with anything not in the first two.
  partitions[-1] = []
  covered = set()
  for partition in partitions[:-1]:
    for item in partition:
      covered.add(item)

  for item in all_names:
    if item not in covered:
      partitions[-1].append(item)

  # Order by dependencies.
  partitions[-1] = GetBuildOrder(partitions[-1])

  # Check that all the items still exist.
  for i, partition in enumerate(partitions):
    for item in partition:
      if item not in all_names:
        raise Error('non-existent package in partion %d: %s' % (i, item))

  # Check that partitions include all of their dependencies.
  for i, partition in enumerate(partitions):
    deps = GetDependencies(partition)
    for dep in deps:
      if not dep in partition:
        raise Error('dependency missing from partition %d: %s' % (i, dep))

  return partitions


def PrintCanned(index, parts):
  assert index >= 0 and index < parts, [index, parts]
  partitions = LoadCanned(parts)
  partitions = FixupCanned(partitions)
  Trace("Found %d packages for shard %d" % (len(partitions[index]), index))
  print ' '.join(partitions[index])


def main(args):
  parser = optparse.OptionParser()
  parser.add_option('-v', '--verbose', action='store_true',
                    help='Output extra information.')
  parser.add_option('-t', '--print-canned', type='int',
                    help='Print a the canned partition list and exit.')
  parser.add_option('-b', '--bot-prefix', help='builder name prefix.',
                    default='linux-newlib-')
  parser.add_option('-n', '--num-bots',
                    help='Number of builders on the waterfall to collect '
                    'data from or to print a canned partition for.',
                    type='int', default=3)
  parser.add_option('-p', '--num-parts',
                    help='Number of parts to partition things into '
                    '(this will differ from --num-bots when changing the '
                    'number of shards).',
                    type='int', default=3)
  parser.add_option('--build-number', help='Builder number to look at for '
                    'historical data on build times.', type='int', default=-1)
  options, _ = parser.parse_args(args)

  global verbose
  verbose = options.verbose

  if options.print_canned is not None:
    PrintCanned(options.print_canned, options.num_bots)
    return

  projects = Projects()
  for bot in range(options.num_bots):
    bot_name = '%s%d' % (options.bot_prefix, bot)
    Trace('Attempting to add data from "%s"' % bot_name)
    projects.AddDataFromBuilder(bot_name, options.build_number)
  projects.PostProcessDeps()

  parts = Partition(projects, options.num_parts)
  for i, project_times in enumerate(parts):
    print 'builder %d (total: %d)' % (i, project_times.total_time)
    project_names = project_times.TopologicallySortedProjectNames(projects)
    print '  %s' % '\n  '.join(project_names)

  times = list(sorted(part.total_time for part in parts))
  difference = 0
  for i in range(1, len(times)):
    difference += times[i] - times[i - 1]
  print 'Difference between total time of builders: %d' % difference


if __name__ == '__main__':
  try:
    sys.exit(main(sys.argv[1:]))
  except Error, e:
    sys.stderr.write("%s\n" % e)
    sys.exit(1)
