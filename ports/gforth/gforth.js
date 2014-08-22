/*
 * Copyright (c) 2014 The Native Client Authors. All rights reserved.
 * Use of this source code is governed by a BSD-style license that can be
 * found in the LICENSE file.
 */

'use strict';

NaClTerm.nmf = 'gforth.nmf'

function onInit() {
  navigator.webkitPersistentStorage.requestQuota(1024 * 1024,
    function(bytes) {
      window.webkitRequestFileSystem(window.TEMPORARAY, bytes, NaClTerm.init)
    },
    function() {
      console.log('Failed to allocate space!\n');
      // Start the terminal even if FS failed to init.
      NaClTerm.init();
    }
  );
}

window.onload = function() {
  lib.init(function() {
    onInit();
  });
};
