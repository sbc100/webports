/*
 * Copyright (c) 2014 The Native Client Authors. All rights reserved.
 * Use of this source code is governed by a BSD-style license that can be
 * found in the LICENSE file.
 */

'use strict';

// A testing extension that grants ordinary pages access to extension specific
// functionality when run in test mode.


/**
 * Kill the browser.
 */
function Die() {
  chrome.processes.getProcessInfo([], false, function(processes) {
    for (var p in processes) {
      if (processes[p].type === 'browser') {
        chrome.processes.terminate(processes[p].id);
      }
    }
  });
  // This seems to be needed in practice sometimes.
  chrome.processes.terminate(0);
}

/**
 * Listen for a number of message types from tests.
 */
chrome.runtime.onConnectExternal.addListener(function(port) {
  function initialListener(msg) {
    // All the test runner to end the session quickly.
    if (msg.name == 'die') {
      Die();

    // Expose chrome.management.getAll.
    } else if (msg.name == 'getAllExtensions') {
      chrome.management.getAll(function(result) {
        port.postMessage({'name': 'getAllExtensionsResult',
                          'result': result});
      });

    // Expose chrome.processes.getProcessInfo.
    } else if (msg.name == 'getAllProcesses') {
      chrome.processes.getProcessInfo([], false, function(processes) {
        port.postMessage({'name': 'getAllProcessesResult',
                          'result': processes});
      });

    // Allow proxied access to all extensions / apps for testing.
    // NOTE: Once you switch to proxy mode, all messages are routed to the
    // proxied extension. A new connection is required for further access to
    // other functionality.
    } else if (msg.name == 'proxy') {
      port.onMessage.removeListener(initialListener);
      var extension = msg.extension;
      var extensionPort = chrome.runtime.connect(extension);
      extensionPort.onMessage.addListener(function(msg) {
        port.postMessage(msg);
      });
      extensionPort.onDisconnect.addListener(function(msg) {
        port.disconnect();
      });
      port.onMessage.addListener(function(msg) {
        extensionPort.postMessage(msg);
      });
      port.onDisconnect.addListener(function() {
        extensionPort.disconnect();
      });

    // Provide a simple echo for testing of this extension.
    } else if (msg.name == 'ping') {
      msg.name = 'pong';
      port.postMessage(msg);
    }
  }
  port.onMessage.addListener(initialListener);
});
