/*
 * Copyright (c) 2014 The Native Client Authors. All rights reserved.
 * Use of this source code is governed by a BSD-style license that can be
 * found in the LICENSE file.
 */

'use strict';

// The background page of the debugger extension has a few purposes:
// - Track and react to nacl process create / exit / suspend.
// - Store and update global g_settings choices.

/**
 * Name of the GDB app (used to establish contact for testing).
 * @const
 */
var GDB_EXTENSION_NAME = 'GDB';

/**
 * ID of GDB app (used to establish contact).
 * @const
 */
var GDB_EXTENSION_ID = 'mmgaaffjoeedmfdelihjppfdepcpophe';

/**
 * Keep a run running snapshot of running NaCl modules.
 * Mapping of process id to object detailing process.
 */
var g_naclModules = {};

/**
 * Keep a mapping of listener id to an object for each process with these
 * fields:
 *   {chrome.processes.ProcessInfo} process Process Info for the process.
 *   {string] debugState String describing debug status.
 *   {Port} debugConnection A messaging port to the gdb app for this process.
 */
var g_listeners = {};

/**
 * Keep a counter to dole out unique ids for each listener.
 */
var g_listenerId = 0;

/**
 * Keep a use settings in the background page to retain them across ui stop
 * start.
 * TODO(bradnelson): Keep this between sessions in localStorage?
 */
var g_settings = {
  onStartRun: true,  // Run (as opposed to attach) on module start.
  onFaultAttach: true,  // Attach on fault (as opposed to halting).
  showGdb: false,  // Show GDB modules in the list of NaCl apps.
};


/**
 * Broadcast a message to all open listeners (or a tuned subset).
 * @param msg Message to broadcast.
 * @param opt_tuned Optionally restrict broadcast to listeners tuned to a given
 *                  process id (interacting with the gdb console).
 */
function broadcast(msg, opt_tuned) {
  for (var i in g_listeners) {
    try {
      if (opt_tuned === undefined || opt_tuned === g_listeners[i].tune) {
        g_listeners[i].port.postMessage(msg);
      }
    } catch(e) {
    }
  }
}

/**
 * Send a complete state update to all listeners.
 * @param {string} cause String describing why an update is needed.
 * @param {string} opt_addedProcessId Optional process id that was involved in
 *                                    the cause (ex process started).
 */
function notifyListeners(cause, opt_addedProcessId) {
  broadcast({
    'name': 'change',
    'cause': cause,
    'addedProcessId': opt_addedProcessId,
    'naclModules': g_naclModules,
    'settings': g_settings,
  });
}

/**
 * Create a connection to the GDB app.
 * @param {function(Port)} callback Called with a Port to the GDB app.
 */
function newGdbAppPort(callback) {
  // In testing mode connect via the test extension.
  if (navigator.userAgent.indexOf('ChromeTestAgent/') >= 0) {
    var testExt = navigator.userAgent.split(' ')[0].split('/')[1];
    var port = chrome.runtime.connect(testExt);
    var handleMessage = function(msg) {
      port.onMessage.removeListener(handleMessage);
      callback(port);
    };
    port.onMessage.addListener(handleMessage);
    port.postMessage({'name': 'proxy', 'extension': GDB_EXTENSION_NAME});
    return;
  }
  callback(chrome.runtime.connect(GDB_EXTENSION_ID));
}

/**
 * Create a new connect to the GDB app for a particular debug port.
 * @param {integer} debugTcpPort The port to debug on.
 * @param {function(Port)} callback Called with a setup port to the GDB app.
 */
function newGdbConnection(debugTcpPort, callback) {
  newGdbAppPort(function(port) {
    var handleMessage = function(msg) {
      port.onMessage.removeListener(handleMessage);
      callback(port);
    };
    port.onMessage.addListener(handleMessage);
    port.postMessage({'name': 'setDebugTcpPort', 'debugTcpPort': debugTcpPort});
  });
}

/**
 * Add process to the monitored set if appropriate.
 * @param {chrome.processes.ProcessInfo} process.
 * @return {boolean} Was there a need to add the process
 *     (ie send out an update).
 */
function addProcess(process) {
  // Only monitor NaCl modules.
  if (process.type !== 'nacl') {
    return false;
  }
  // Ignore process ids that are already present.
  var processId = process.id.toString();
  if (processId in g_naclModules) {
    return false;
  }

  // Add the module to the active set.
  var entry = {
    'process': process,
    'debugConnection': null,
    'debugState': 'setup',
  };
  g_naclModules[processId] = entry;

  // Create a new connection to the debug app.
  newGdbConnection(process.naclDebugPort, function(debugConnection) {
    entry.debugConnection = debugConnection;
    debugConnection.onMessage.addListener(function(msg) {
      if (msg.name === 'rspContinueReply') {
        if (msg.type === 'signal') {
          if (g_settings.onFaultAttach) {
            entry.debugConnection.postMessage({'name': 'runGdb'});
            entry.debugState = 'gdb';
            notifyListeners('faulted');
          } else {
            entry.debugConnection.postMessage({'name': 'rspKill'});
            entry.debugState = 'killing';
            notifyListeners('killed');
          }
        }
      } else if (msg.name === 'message') {
        broadcast(msg, processId);
      }
    });
    debugConnection.onDisconnect.addListener(function() {
      entry.debugState = 'disconnecting';
      notifyListeners('disconnect');
    });

    if (process.title.match(/^Native Client module:.*gdb.nmf$/)) {
      // For now, detach from GDB processes.
      // TODO(bradnelson): Add an infinite regress check and switch this to
      // rspContinue so we can catch GDB crashes.
      entry.debugConnection.postMessage({'name': 'rspDetach'});
      entry.debugState = 'detached';
    } else if (g_settings.onStartRun) {
      entry.debugConnection.postMessage({'name': 'rspContinue'});
      entry.debugState = 'running';
    } else {
      entry.debugConnection.postMessage({'name': 'runGdb'});
      entry.debugState = 'gdb';
    }
    notifyListeners('setup');
  });

  return true;
}


/**
 * Make an initial request of the process list to prime g_naclModules.
 */
chrome.processes.getProcessInfo([], false, function(processes) {
  for (var rawProcessId in processes) {
    var process = processes[rawProcessId];
    if (addProcess(process)) {
      notifyListeners('init');
    }
  }
});

/**
 * Listen to process update events.
 * This is done in addition to listening to creation events because in practice
 * not registering an onUpdated handler seems to result in slow / missed
 * process events.
 * NOTE: This is only used to detect modules to add.
 * TODO(bradnelson): Look into if this is really needed.
 */
chrome.processes.onUpdated.addListener(function(processes) {
  for (var rawProcessId in processes) {
    var process = processes[rawProcessId];
    if (addProcess(process)) {
      notifyListeners('updated');
    }
  }
});

/**
 * Listen to process creation events.
 */
chrome.processes.onCreated.addListener(function(process) {
  if (addProcess(process)) {
    notifyListeners('create', process.id.toString());
  }
});

/**
 * Listen to process exit events.
 */
chrome.processes.onExited.addListener(function(processId, exitType, exitCode) {
  var processIdStr = processId.toString();
  if (processIdStr in g_naclModules) {
    if (g_naclModules[processIdStr].debugConnection !== null) {
      g_naclModules[processIdStr].debugConnection.disconnect();
    }
    delete g_naclModules[processIdStr];
    notifyListeners('exit');
  }
});

/**
 * Handle a newly connected port (internal from main.js or external for
 * testing).
 */
function handleConnect(port) {
  var id = g_listenerId++;
  g_listeners[id] = {
    'port': port,
    'tune': null,
  };
  port.onMessage.addListener(function(msg) {
    // Respond to a settings change from the UI.
    if (msg.name === 'settingsChange') {
      g_settings = msg.settings;
      notifyListeners('settingsChange');

    // Respond to an attach request from the UI.
    } else if (msg.name === 'attach') {
      if (msg.processId in g_naclModules) {
        g_naclModules[msg.processId].debugState = 'gdb';
        if (g_naclModules[msg.processId].debugConnection !== null) {
          g_naclModules[msg.processId].debugConnection.postMessage(
              {'name': 'runGdb'});
        }
      }

    // Respond to a kill request from the UI.
    } else if (msg.name === 'kill') {
      g_naclModules[msg.processId].debugState = 'killing';
      chrome.processes.terminate(
          parseInt(msg.processId), function(didTerminate) {
      });

    // Respond to a request to view the GDB console from the UI.
    } else if (msg.name === 'tune') {
      g_listeners[id].tune = msg.processId;

    // Route user input to the proper GDB module.
    } else if (msg.name === 'input') {
      var tune = g_listeners[id].tune;
      if (tune !== null && (tune in g_naclModules)) {
        if (g_naclModules[tune].debugConnection !== null) {
          g_naclModules[tune].debugConnection.postMessage(msg);
        }
      }
    }
  });

  // Drop the listener on disconnect.
  port.onDisconnect.addListener(function() {
    delete g_listeners[id];
  });

  // Announce the new module.
  notifyListeners('join');
};

/**
 * Listen for internal connection events (from main.js).
 */
chrome.runtime.onConnect.addListener(handleConnect);

/**
 * Allow an external connection for testing only.
 */
chrome.runtime.onConnectExternal.addListener(function(port) {
  // Check the sender only when not in testing mode.
  if (navigator.userAgent.indexOf('ChromeTestAgent/') < 0) {
    port.disconnect();
    return;
  }
  handleConnect(port);
});
