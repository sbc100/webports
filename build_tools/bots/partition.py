#!/usr/bin/env python
# Copyright (c) 2013 The Native Client Authors. All rights reserved.
# Use of this source code is governed by a BSD-style license that can be
# found in the LICENSE file.

"""Download historical data from the naclports builders, and use it to
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

The list for each builder can be copied directly to the PKG_LIST_PART_*
definitions in bot_common.sh.
"""

import json
import optparse
import os
import subprocess
import sys
import urllib2

SCRIPT_DIR = os.path.dirname(os.path.abspath(__file__))
BUILD_TOOLS_DIR = os.path.dirname(SCRIPT_DIR)
ROOT_DIR = os.path.dirname(BUILD_TOOLS_DIR)
ARCHES = ('arm', 'i686', 'x86_64')

verbose = False


class Error(Exception):
  pass


def GetDependencies(name):
  # We don't need a valid NACL_SDK_ROOT to get dependencies, but the Makefile
  # checks for it anyway.
  env = {'NACL_SDK_ROOT': 'DUMMY_NACL_SDK_ROOT'}
  cmd = ['make', '-s', 'PRINT_DEPS=1', name]
  cwd = ROOT_DIR
  process = subprocess.Popen(cmd, stdout=subprocess.PIPE, cwd=cwd, env=env)
  stdout, _ = process.communicate()
  names = stdout.split()
  # names will be "libraries/foo" or "examples/bar/baz". We only want the last
  # part.
  return set(name.split('/')[-1] for name in names) - set([name])


def DownloadDataFromBuilder(builder, build):
  max_tries = 10

  for _ in xrange(max_tries):
    url = 'http://build.chromium.org/p/client.nacl.ports/json'
    url += '/builders/%s/builds/%d' % (builder, build)
    if verbose:
      sys.stdout.write('Downloading %s\n' % url)
    f = urllib2.urlopen(url)
    try:
      data = json.loads(f.read())
      text = data['text']
      if text == ['build', 'successful']:
        if verbose:
          sys.stdout.write('  Success!\n')
        return data
      if verbose:
        sys.stdout.write('  Not successful, trying previous build.\n')
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
    self.dep_names = GetDependencies(name)
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


def main(args):
  parser = optparse.OptionParser()
  parser.add_option('-v', '--verbose', action='store_true',
                    help='Output extra information.')
  parser.add_option('-b', '--bot-prefix', help='builder name prefix.',
                    default='linux-newlib-')
  parser.add_option('-n', '--num-bots', help='number of builders.',
                    type='int', default=3)
  parser.add_option('--build-number', help='builder number to look at for '
                    'historical data on build times.', type='int', default=-1)
  options, _ = parser.parse_args(args)

  global verbose
  verbose = options.verbose

  projects = Projects()
  for bot in range(options.num_bots):
    bot_name = '%s%d' % (options.bot_prefix, bot)
    if verbose:
      sys.stdout.write('Attempting to add data from "%s"\n' % bot_name)
    projects.AddDataFromBuilder(bot_name, options.build_number)
  projects.PostProcessDeps()

  parts = Partition(projects, 3)
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
  sys.exit(main(sys.argv[1:]))
