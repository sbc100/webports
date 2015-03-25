# Copyright (c) 2011 The Native Client Authors. All rights reserved.
# Use of this source code is governed by a BSD-style license that can be
# found in the LICENSE file.

# Documentation on PRESUBMIT.py can be found at:
# http://www.chromium.org/developers/how-tos/depottools/presubmit-scripts

import os
import subprocess

PYTHON = 'build_tools/python_wrapper'

_EXCLUDED_PATHS = (
    # patch_configure.py contains long lines embedded in multi-line
    # strings.
    r"^build_tools[\\\/]patch_configure.py",
)

def RunPylint(input_api, output_api):
  output = []
  canned = input_api.canned_checks
  disabled_warnings = [
    'W0613',  # Unused argument
  ]
  black_list = list(input_api.DEFAULT_BLACK_LIST) + [
    r'ports[\/\\]ipython-ppapi[\/\\]kernel\.py',
  ]
  output.extend(canned.RunPylint(input_api, output_api, black_list=black_list,
                disabled_warnings=disabled_warnings, extra_paths_list=['lib']))
  return output



def RunCommand(name, cmd, input_api, output_api):
  try:
    subprocess.check_call(cmd)
  except subprocess.CalledProcessError:
    message = '%s failed.' % name
    return [output_api.PresubmitError(message)]
  return []


def RunPythonCommand(cmd, input_api, output_api):
  return RunCommand(cmd[0], [PYTHON] + cmd, input_api, output_api)


def CheckCQConfig(input_api, output_api):
  def f(x):
    return input_api.FilterSourceFile(x,
        white_list=['build_tools/commit_queue/cq_config.json'])

  if not input_api.AffectedFiles(file_filter=f):
    return []

  return RunPythonCommand(['build_tools/commit_queue/test_cq_config.py'],
                          input_api,
                          output_api)


def CheckPartioning(input_api, output_api):
  return RunPythonCommand(['build_tools/partition.py', '--check'],
                          input_api,
                          output_api)


def CheckDeps(input_api, output_api):
  return RunPythonCommand(['build_tools/check_deps.py'],
                          input_api,
                          output_api)

def CheckMirror(input_api, output_api):
  return RunPythonCommand(['build_tools/update_mirror.py', '--check'],
                          input_api,
                          output_api)


def RunUnittests(input_api, output_api):
  return RunCommand('unittests', ['make', 'test'], input_api, output_api)


def CheckChangeOnUpload(input_api, output_api):
  report = []
  report.extend(CheckCQConfig(input_api, output_api))
  report.extend(RunPylint(input_api, output_api))
  report.extend(RunUnittests(input_api, output_api))
  report.extend(CheckDeps(input_api, output_api))
  report.extend(input_api.canned_checks.PanProjectChecks(
      input_api, output_api, project_name='Native Client',
      excluded_paths=_EXCLUDED_PATHS))
  return report


def CheckChangeOnCommit(input_api, output_api):
  report = []
  report.extend(CheckChangeOnUpload(input_api, output_api))
  report.extend(CheckMirror(input_api, output_api))
  report.extend(CheckPartioning(input_api, output_api))
  report.extend(input_api.canned_checks.CheckTreeIsOpen(
      input_api, output_api,
      json_url='http://naclports-status.appspot.com/current?format=json'))
  return report


TRYBOTS = [
    'naclports-linux-glibc-0',
    'naclports-linux-glibc-1',
    'naclports-linux-glibc-2',
    'naclports-linux-glibc-3',
    'naclports-linux-glibc-4',
    'naclports-linux-newlib-0',
    'naclports-linux-newlib-1',
    'naclports-linux-newlib-2',
    'naclports-linux-newlib-3',
    'naclports-linux-newlib-4',
    'naclports-linux-pnacl-0',
    'naclports-linux-pnacl-1',
    'naclports-linux-pnacl-2',
    'naclports-linux-pnacl-3',
    'naclports-linux-pnacl-4',
    'naclports-linux-clang-0',
    'naclports-linux-clang-1',
    'naclports-linux-clang-2',
    'naclports-linux-clang-3',
    'naclports-linux-clang-4',
]


def GetPreferredTryMasters(_, change):
  return {
    'tryserver.nacl': { t: set(['defaulttests']) for t in TRYBOTS },
  }
