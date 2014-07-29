#!/usr/bin/env python
# Copyright (c) 2013 The Native Client Authors. All rights reserved.
# Use of this source code is governed by a BSD-style license that can be
# found in the LICENSE file.
"""Creates simple terminal for a NaCl module.

This script is designed to make the process of porting terminal based
Native Client executables simple by generating boilerplate .html and .js
files for a given Native Client module (.nmf).
"""

import logging
import optparse
import os
import sys

HTML_TEMPLATE = '''\
<!DOCTYPE html>
<html>
  <head>
    <title>%(title)s</title>
    <META HTTP-EQUIV="Pragma" CONTENT="no-cache" />
    <META HTTP-EQUIV="Expires" CONTENT="-1" />
    <script type="text/javascript" src="hterm.concat.js"></script>
    <script type="text/javascript" src="naclprocess.js"></script>
    <script type="text/javascript" src="naclterm.js"></script>
    <script type="text/javascript" src="%(module_name)s.js"></script>
    %(include)s

    <style type="text/css">
      body {
        position: absolute;
        padding: 0;
        margin: 0;
        height: 100%%;
        width: 100%%;
        overflow: hidden;
      }

      #terminal {
        display: block;
        position: static;
        width: 100%%;
        height: 100%%;
      }
    </style>
  </head>
  <body>
    <div id="terminal"></div>
  </body>
</html>
'''

JS_TEMPLATE = '''\
NaClTerm.nmf = '%(nmf)s'
'''

FORMAT = '%(filename)s: %(message)s'
logging.basicConfig(format=FORMAT)


def CreateTerm(filename, name=None, include=None):
  if not name:
    basename = os.path.basename(filename)
    name, _ = os.path.splitext(basename)

  include = include or []

  htmlfile = name + '.html'
  logging.info('creating html: %s', htmlfile)
  with open(htmlfile, 'w') as outfile:
    args = {}
    args['title'] = name
    args['module_name'] = name

    includeHTML = ['<script src="%s"></script>' % js for js in include]
    args['include'] = '\n    '.join(includeHTML)

    outfile.write(HTML_TEMPLATE % args)

  jsfile = name + '.js'
  logging.info('creating js: %s', jsfile)
  with open(jsfile, 'w') as outfile:
    args = {}
    args['module_name'] = name
    args['nmf'] = os.path.basename(filename)
    outfile.write(JS_TEMPLATE % args)


def main():
  parser = optparse.OptionParser(
      usage='usage: %prog [-n] [-v] .nmf',
      description=__doc__)
  parser.add_option('-n', '--name',
                    help='name of the application')
  parser.add_option('-v', '--verbose',
                    action='store_true', dest='verbose', default=False,
                    help='be more verbose')
  parser.add_option('-i', '--include', action='append', default=[],
                    help='include a JavaScript file in the generated HTML')

  options, args = parser.parse_args()

  if not args:
    parser.error('no input file specified')
  if len(args) > 1:
    parser.error('more than one input file specified')

  if not options.verbose:
    logging.disable(logging.INFO)

  CreateTerm(args[0], options.name, options.include)


if __name__ == '__main__':
  main()
