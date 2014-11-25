/*
 * Copyright (c) 2014 The Native Client Authors. All rights reserved.
 * Use of this source code is governed by a BSD-style license that can be
 * found in the LICENSE file.
 */

NaClTerm.nmf = 'emacs.nmf';
NaClTerm.cwd = '/home/user';
NaClTerm.argv = ['-nw'];
NaClTerm.env = [
  'EMACSLOADPATH=' +
  '/naclports-dummydir/share/emacs/24.3/lisp' +
  ':/naclports-dummydir/share/emacs/24.3/lisp/emacs-lisp',

  'DISPLAY=:42',
];
