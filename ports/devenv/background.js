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

chrome.runtime.onMessageExternal.addListener(
  function(request, sender, sendResponse) {
    if (request.name === 'ping') {
      sendResponse({name: 'pong'});
    }
  }
);

chrome.runtime.onConnectExternal.addListener(function(port) {
  var files = new FileManager();
  var manager = new NaClProcessManager();
  manager.setStdoutListener(function(output) {
    port.postMessage({name: 'nacl_stdout', output: output});
  });

  function fileReply(name) {
    return function() {
      port.postMessage({name: name});
    };
  }
  function fileError(name) {
    return function(error) {
      port.postMessage({name: name, error: error.message});
    };
  }

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

      case 'file_init':
        var type = (msg.type === 'temporary') ?
            window.TEMPORARY : window.PERSISTENT;
        files.init(type).then(
            fileReply('file_init_reply'), fileError('file_init_error'));
        break;
      case 'file_read':
        files.readText(msg.file).then(function(data) {
          port.postMessage({
            name: 'file_read_reply',
            data: data
          });
        }, fileError('file_read_error'));
        break;
      case 'file_write':
        files.writeText(msg.file, msg.data).then(
            fileReply('file_write_reply'), fileError('file_write_error'));
        break;
      case 'file_remove':
        files.remove(msg.file).then(
            fileReply('file_remove_reply'), fileError('file_remove_error'));
        break;
      case 'file_mkdir':
        files.makeDirectory(msg.file).then(
            fileReply('file_mkdir_reply'), fileError('file_mkdir_error'));
        break;
      case 'file_rm_rf':
        files.removeDirectory(msg.file).then(
            fileReply('file_rm_rf_reply'), fileError('file_rm_rf_error'));
        break;

      default:
        port.postMessage({name: 'unknown_error', error: 'unknown message'});
    }
  });
});

/**
 * Access the HTML5 Filesystem.
 */
function FileManager() {
  this.fs = null;
  this.type = null;
}

/**
 * Translate a path from the point of view of NaCl to the point of view of the
 * HTML5 file system.
 * @param {string} path The path to be translated.
 * @returns {string} The translated path.
 */
FileManager.prototype.translatePath = function(path) {
  var html5MountPoint = '/mnt/html5';
  var homeMountPoint = '/home/user';
  var tmpMountPoint = '/tmp';
  var isHTML5 = path.indexOf(html5MountPoint) === 0;
  var isHome = path.indexOf(homeMountPoint) === 0;
  var isTmp = path.indexOf(tmpMountPoint) === 0;
  if (isHTML5 || isHome) {
    if (this.type !== window.PERSISTENT) {
      throw new Error('attempting to access persistent data from temporary' +
          ' filesystem');
    }
    if (isHTML5) {
      return path.replace(html5MountPoint, '');
    } else {
      return path.replace(homeMountPoint, '/home');
    }
  } else if (isTmp) {
    if (this.type !== window.TEMPORARY) {
      throw new Error('attempting to access temporary data from persistent' +
          ' filesystem');
    }
    return path.replace(tmpMountPoint, '');
  } else {
    throw new Error('path is outside of HTML5 filesystem');
  }
};

/**
 * Initialize the file system. This must be called before any file operations
 * can be performed.
 */
FileManager.prototype.init = function(type) {
  var self = this;

  // TODO(channingh): Initialize both types of filesystem, so the user doesn't
  // have to decide.

  if (type === undefined)
    type = window.PERSISTENT;

  return new Promise(function(resolve, reject) {
    window.webkitRequestFileSystem(type, 1024*1024, function(fs) {
      self.fs = fs;
      self.type = type;
      resolve();
    }, function(e) {
      reject(e);
    });
  });
};

/**
 * The error thrown when the user tries to perform file operations before the
 * file system has been initialized.
 * @const
 */
FileManager.FS_NOT_INITIALIZED = 'File system not initialized.';

/**
 * Read the contents of a text file.
 * @param {string} fileName The name of the file to be read.
 */
FileManager.prototype.readText = function(fileName) {
  var self = this;
  return new Promise(function(resolve, reject) {
    if (!self.fs)
      reject(new Error(FileManager.FS_NOT_INITIALIZED));
    fileName = self.translatePath(fileName);

    self.fs.root.getFile(fileName, {}, function(fe) {
      fe.file(function(file) {
        var reader = new FileReader();
        reader.onload = function(e) {
          resolve(this.result);
        };
        reader.onerror = function(e) {
          reject(new Error(e.message));
        };
        reader.readAsText(file);
      }, reject);
    }, reject);
  });
};

/**
 * Write a string to a text file.
 * @param {string} fileName The name of the destination file.
 * @param {string} fileName The text to be written.
 */
FileManager.prototype.writeText = function(fileName, content) {
  var self = this;
  return new Promise(function(resolve, reject) {
    if (!self.fs)
      reject(new Error(FileManager.FS_NOT_INITIALIZED));
    fileName = self.translatePath(fileName);

    self.fs.root.getFile(fileName, {create: true}, function(fe) {
      fe.createWriter(onCreateWriter, reject);
    }, reject);

    function onCreateWriter(writer) {
      var blob = new Blob([content], {type:'text/plain'})
      // Discard arguments.
      writer.onwriteend = function() {
        resolve();
      }
      writer.onerror = reject;
      writer.write(blob);
    }
  });
};

/**
 * Remove a file from the filesystem. This does not work on directories.
 * @param {string} fileName The name of the file.
 */
FileManager.prototype.remove = function(fileName) {
  var self = this;
  return new Promise(function(resolve, reject) {
    if (!self.fs)
      reject(new Error(FileManager.FS_NOT_INITIALIZED));
    fileName = self.translatePath(fileName);

    self.fs.root.getFile(fileName, {}, function(fe) {
      fe.remove(resolve, reject);
    }, reject);
  });
};

/**
 * Create a directory.
 * @param {string} fileName The name of the directory.
 */
FileManager.prototype.makeDirectory = function(fileName) {
  var self = this;
  return new Promise(function(resolve, reject) {
    if (!self.fs)
      reject(new Error(FileManager.FS_NOT_INITIALIZED));
    fileName = self.translatePath(fileName);

    self.fs.root.getDirectory(fileName, {create: true}, function() {
      resolve();
    }, reject);
  });
};

/**
 * Remove a directory and its contents.
 * @param {string} fileName The name of the directory.
 */
FileManager.prototype.removeDirectory = function(fileName) {
  var self = this;
  return new Promise(function(resolve, reject) {
    if (!self.fs)
      reject(new Error(FileManager.FS_NOT_INITIALIZED));
    fileName = self.translatePath(fileName);

    self.fs.root.getDirectory(fileName, {}, function(dir) {
      dir.removeRecursively(function() {
        resolve();
      }, reject);
    }, reject);
  });
};
