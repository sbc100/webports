/*
 * Copyright (c) 2013 The Native Client Authors. All rights reserved.
 * Use of this source code is governed by a BSD-style license that can be
 * found in the LICENSE file.
 */

function addMount(mountPoint, entry, localPath, mounted) {
  g_mount.mountPoint = mountPoint;
  g_mount.entry = entry;
  g_mount.localPath = localPath;
  g_mount.mounted = mounted;
  g_mount.entryId = '';
}

function handleChooseFolder(mount, callback) {
  chrome.fileSystem.chooseEntry({'type': 'openDirectory'}, function(entry) {
    chrome.fileSystem.getDisplayPath(entry, function(path) {
      mount.entry = entry;
      mount.filesystem = entry.filesystem;
      mount.fullPath = entry.fullPath;
      mount.entryId = chrome.fileSystem.retainEntry(entry);
      mount.localPath = path;
      chrome.storage.local.set({oldMounts: [mount.entryId]}, callback);
    });
  });
}

function restoreMount(mount, callback) {
  chrome.storage.local.get('oldMounts', function(items) {
    var oldMounts = items['oldMounts'];
    if (oldMounts === undefined || oldMounts.length === 0) {
      callback();
      return;
    }
    // TODO(gdeepti): Support multiple mounts.
    chrome.fileSystem.restoreEntry(oldMounts[0], function(entry) {
      chrome.fileSystem.getDisplayPath(entry, function(path) {
        mount.entry = entry;
        mount.filesystem = entry.filesystem;
        mount.fullPath = entry.fullPath;
        mount.entryId = chrome.fileSystem.retainEntry(entry);
        mount.localPath = path;
        callback();
      });
    });
  });
}

function handleMount(mount, callback) {
  mount.operationId = 'mount';
  mount.available = true;
  mount.mounted = false;
  var message = {};
  message.mount = mount;
  window.term_.command.processManager.broadcastMessage(message, callback);
}

function handleUnmount(mount, callback) {
  mount.operationId = 'unmount'
  mount.available = false;
  var message = {};
  message.unmount = mount;
  window.term_.command.processManager.broadcastMessage(message, callback);
  addMount('/mnt/local/', null, '', false);
  chrome.storage.local.remove('oldMounts', function() {});
}

function initMountSystem() {
  var terminal = document.getElementById('terminal');
  var mounterClient = new initMounterclient(g_mount, handleChooseFolder,
      handleMount, handleUnmount, terminal);
  addMount('/mnt/local/', null, '', false);
  restoreMount(g_mount, function() {
    initMounter(false, mounterClient, function(update) {
      // Mount any restore mount.
      if (g_mount.entryId !== '') {
        handleMount(g_mount, update);
      }
    });
  });
}

NaClTerm.nmf = 'bash.nmf';
NaClTerm.argv = ['--init-file', '/mnt/http/bashrc'];
// TODO(bradnelson): Drop this hack once tar extraction first checks relative
// to the nexe.
NaClProcessManager.useNaClAltHttp = true;

function onInit(callback) {
  // Request 1GB storage.
  navigator.webkitPersistentStorage.requestQuota(
      1024 * 1024 * 1024 * 10,
      function() {
        NaClTerm.init();
        callback();
      },
      function() {
        console.log("Failed to allocate space!\n");
        // Start the terminal even if FS failed to init.
        NaClTerm.init();
        callback();
      });
}

window.onload = function() {
  mounterBackground = document.createElement('div');
  mounterBackground.id = 'mounterBackground';
  mounter = document.createElement('div');
  mounter.id = 'mounter';
  mounterHeader = document.createElement('div');
  mounterHeader.id = 'mounterHeader';
  var text = document.createTextNode('Folders Mounted');
  mounterHeader.appendChild(text);
  mounter.appendChild(mounterHeader);
  mounterBackground.appendChild(mounter);
  var mounterSpacer = document.createElement('div');
  mounterSpacer.id = 'mounterSpacer';

  mounterBackground.appendChild(mounterSpacer);
  mounterThumb = document.createElement('div');
  mounterThumb.id = 'mounterThumb';
  var sp = document.createElement("span");
  mounterThumb.appendChild(sp);
  mounterBackground.appendChild(mounterThumb);
  document.body.appendChild(mounterBackground);

  lib.init(function() {
    onInit(function() {
      initMountSystem();
    });
  });
};

// Patch hterm to intercept Ctrl-Shift-N to create new windows.
hterm.Keyboard.KeyMap.prototype.onCtrlN_ = function(e, keyDef) {
  if (e.shiftKey) {
    chrome.runtime.sendMessage({'name': 'new_window'});
  }
  return '\x0e';
};
