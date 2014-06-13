/*
 * Copyright (c) 2013 The Native Client Authors. All rights reserved.
 * Use of this source code is governed by a BSD-style license that can be
 * found in the LICENSE file.
 */

NaClTerm.prefix = 'bash';
NaClTerm.nmf = 'bash.nmf';
NaClTerm.argv = ['--init-file', '/mnt/http/bashrc'];
NaClTerm.nmfWhitelist = [
    'bash',
    'curl',
    'funzip',
    'unzip',
    'unzipsfx',
];

// We cannot start bash until the storage request is approved.
NaClTerm.real_init = NaClTerm.init;
NaClTerm.init = function() {
  // Request 1GB storage for mingn.
  navigator.webkitPersistentStorage.requestQuota(
      1000 * 1000 * 1000,
      NaClTerm.real_init,
      function() {});
}
