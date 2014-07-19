/*
 * Copyright (c) 2014 The Native Client Authors. All rights reserved.
 * Use of this source code is governed by a BSD-style license that can be
 * found in the LICENSE file.
 */

'use strict';


chrome.app.runtime.onLaunched.addListener(function() {
  chrome.app.window.create('bash.html', {
    'bounds': {
      'width': 800,
      'height': 600,
    },
  });
});

chrome.runtime.onConnectExternal.addListener(function(port) {
  var manager = new NaClProcessManager();
  manager.setStdoutListener(function(output) {
    port.postMessage({name: 'nacl_stdout', output: output});
  });
  port.onMessage.addListener(function(msg) {
    switch (msg.name) {
      case 'nacl_spawn':
        var handleSuccess = function(naclType) {
          var pid = manager.spawn(
            msg.nmf, msg.argv, msg.envs, msg.cwd, naclType);
          port.postMessage({name: 'nacl_spawn_reply', pid: pid});
        };
        var handleFailure = function(message) {
          port.postMessage({name: 'nacl_spawn_reply', pid: -1,
                            message: message});
        };
        if ('naclType' in msg) {
          handleSuccess(msg.naclType);
        } else {
          manager.checkNaClManifestType(msg.nmf, handleSuccess, handleFailure);
        }
        break;
      case 'nacl_waitpid':
        manager.waitpid(msg.pid, msg.options, function(pid, status) {
          port.postMessage({
            name: 'nacl_waitpid_reply',
            pid: pid,
            status: status
          });
        });
        break;
      default:
        console.log('Unknown message: ', msg);
    }
  });
});
