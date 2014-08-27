/*
 * Copyright (c) 2014 The Native Client Authors. All rights reserved.
 * Use of this source code is governed by a BSD-style license that can be
 * found in the LICENSE file.
 */

'use strict';

function DevEnvTest() {
  chrometest.Test.call(this);
  this.devEnv = null;
  this.tcp = null;

  // Buffer incoming TCP messages.
  this.tcpBuffer = {};
  this.tcpDisconnected = {};
};

DevEnvTest.prototype = new chrometest.Test();
DevEnvTest.prototype.constructor = DevEnvTest;

DevEnvTest.prototype.setUp = function() {
  var self = this;
  return Promise.resolve().then(function() {
    return chrometest.Test.prototype.setUp.call(self);
  }).then(function() {
    return chrometest.proxyExtension('NaCl Development Environment');
  }).then(function(ext) {
    self.devEnv = ext;
  }).then(function() {
    return chrometest.proxyExtension('TCP Interface');
  }).then(function(ext) {
    self.tcp = ext;
  });
};

DevEnvTest.prototype.tearDown = function() {
  var self = this;
  return Promise.resolve().then(function() {
    self.devEnv.disconnect();
    self.tcp.disconnect();
    return chrometest.Test.prototype.tearDown.call(self);
  });
};

DevEnvTest.prototype.waitWhile = function(ext, condition, body) {
  function loop(arg) {
    if (!condition(arg)) {
      return arg;
    } else {
      body(arg);
      return ext.wait().then(loop);
    }
  }
  return loop;
};

DevEnvTest.prototype.runCommand = function(cmd) {
  var self = this;
  var output = '';
  var pid = null;

  function updateStdoutUntil(name) {
    return self.waitWhile(self.devEnv,
      function condition(msg) { return msg.name !== name; },
      function body(msg) {
        ASSERT_EQ('nacl_stdout', msg.name);
        output += msg.output;
      }
    );
  }

  return Promise.resolve().then(function() {
    self.devEnv.postMessage({
      'name': 'nacl_spawn',
      'nmf': 'bash.nmf',
      'argv': ['bash', '-c', '. /mnt/http/setup-environment && ' + cmd],
      'cwd': '/home/user',
      'envs': [],
    });
    return self.devEnv.wait();
  }).then(updateStdoutUntil('nacl_spawn_reply')).then(function(msg) {
    ASSERT_EQ('nacl_spawn_reply', msg.name);
    pid = msg.pid;
    self.devEnv.postMessage({
      'name': 'nacl_waitpid',
      'pid': pid,
      'options': 0,
    });
    return self.devEnv.wait();
  }).then(updateStdoutUntil('nacl_waitpid_reply')).then(function(msg) {
    ASSERT_EQ('nacl_waitpid_reply', msg.name);
    ASSERT_EQ(pid, msg.pid);
    return {status: msg.status, output: output};
  });
};

DevEnvTest.prototype.checkCommand = function(
    cmd, expectedStatus, expectedOutput) {
  var self = this;
  return Promise.resolve().then(function() {
    return self.runCommand(cmd);
  }).then(function(result) {
    ASSERT_EQ(expectedStatus, result.status, result.output);
    if (expectedOutput !== undefined) {
      ASSERT_EQ(expectedOutput, result.output);
    }
  });
};

DevEnvTest.prototype.initFileSystem = function() {
  var self = this;
  return Promise.resolve().then(function() {
    self.devEnv.postMessage({name: 'file_init'});
    return self.devEnv.wait();
  }).then(function(msg) {
    ASSERT_EQ('file_init_reply', msg.name);
  });
};

DevEnvTest.prototype.writeFile = function(fileName, data) {
  var self = this;
  return Promise.resolve().then(function() {
    self.devEnv.postMessage({
      'name': 'file_write',
      'file': fileName,
      'data': data
    });
    return self.devEnv.wait();
  }).then(function(msg) {
    ASSERT_EQ('file_write_reply', msg.name);
  });
};

DevEnvTest.prototype.mkdir = function(fileName) {
  var self = this;
  return Promise.resolve().then(function() {
    self.devEnv.postMessage({
      'name': 'file_mkdir',
      'file': fileName
    });
    return self.devEnv.wait();
  }).then(function(msg) {
    ASSERT_EQ('file_mkdir_reply', msg.name);
  });
};

DevEnvTest.prototype.rmRf = function(fileName) {
  var self = this;
  return Promise.resolve().then(function() {
    self.devEnv.postMessage({
      'name': 'file_rm_rf',
      'file': fileName
    });
    return self.devEnv.wait();
  }).then(function(msg) {
    ASSERT_EQ('file_rm_rf_reply', msg.name);
  });
};

DevEnvTest.prototype.pipe = function() {
  var self = this;
  return Promise.resolve().then(function() {
    self.devEnv.postMessage({
      'name': 'nacl_pipe'
    });
    return self.devEnv.wait();
  }).then(function(msg) {
    ASSERT_EQ('nacl_pipe_reply', msg.name);
    return msg.pipes;
  });
};

/**
 * Convert an Array to a string.
 * @param {Array} arr The Array to be converted.
 * @returns {string}
 */
DevEnvTest.array2Str = function(arr) {
  return String.fromCharCode.apply(null, arr);
};

/**
 * Convert a string to an Array.
 * @param {string} str The String to be converted.
 * @returns {Array}
 */
DevEnvTest.str2Array = function(str) {
  var arr = [];
  for (var i = 0; i < str.length; i++) {
    arr.push(str.charCodeAt(i));
  }
  return arr;
};

/**
 * Execute a TCP command, and listen for the reply. Buffer incoming TCP
 * messages, and resolve when we receive the reply to the command.
 * @private
 * @param {object} msg The message to send.
 * @returns {Promise}
 */
DevEnvTest.prototype.tcpExec_ = function(msg) {
  var self = this;
  var reply = msg.name + '_reply';
  var error = msg.name + '_error';
  return Promise.resolve().then(function() {
    self.tcp.postMessage(msg);
    return self.tcp.wait();
  }).then(self.waitWhile(self.tcp,
    function condition(msg) {
      return msg.name !== reply && msg.name !== error;
    },
    function body(msg) {
      if (msg.name === 'tcp_message') {
        if (self.tcpBuffer[msg.socket] === undefined) {
          self.tcpBuffer[msg.socket] = '';
        }
        self.tcpBuffer[msg.socket] += DevEnvTest.array2Str(msg.data);
      } else if (msg.name === 'tcp_disconnect') {
        self.tcpDisconnected[msg.socket] = true;
      } else {
        // Is there a better way to do this?
        chrometest.assert(false, 'unexpected message ' + msg.name +
            ' from tcpapp');
      }
    }
  )).then(function(msg) {
    ASSERT_EQ(reply, msg.name);
    return msg;
  });
};

/**
 * Initiate a TCP connection.
 * @param {string} addr The address of the remote host.
 * @param {number} port The port to connect to.
 * @returns {Promise}
 */
DevEnvTest.prototype.tcpConnect = function(addr, port) {
  return this.tcpExec_({
    name: 'tcp_connect',
    addr: addr,
    port: port
  });
};

/**
 * Send a string over TCP.
 * @param {number} socket The TCP socket.
 * @param {string} msg The string to be sent.
 * @returns {Promise}
 */
DevEnvTest.prototype.tcpSend = function(socket, msg) {
  return this.tcpExec_({
    name: 'tcp_send',
    socket: socket,
    data: DevEnvTest.str2Array(msg)
  });
};

/**
 * Receive a TCP message. Resolves with a String of the received data, or null
 * if the TCP connection has been closed.
 * @param {number} socket The TCP socket.
 * @returns {Promise}
 */
DevEnvTest.prototype.tcpRecv = function(socket) {
  var self = this;
  return new Promise(function(resolve, reject) {
    if (self.tcpBuffer[socket] !== undefined) {
      var buffer = self.tcpBuffer[socket];
      delete self.tcpBuffer[socket];
      resolve(buffer);
    } else if (self.tcpDisconnected[socket]) {
      delete self.tcpDisconnected[socket];
      resolve(null);
    } else {
      self.tcp.wait().then(function(msg) {
        if (msg.name === 'tcp_message') {
          resolve(DevEnvTest.array2Str(msg.data));
        } else if (msg.name === 'tcp_disconnect') {
          resolve(null);
        } else {
          chrometest.assert(false, 'unexpected message ' + msg.name +
              ' from tcpapp');
        }
      });
    }
  });
};

/**
 * Close a TCP connection.
 * @param {number} socket The TCP socket.
 * @returns {Promise}
 */
DevEnvTest.prototype.tcpClose = function(socket) {
  return this.tcpExec_({
    name: 'tcp_close',
    socket: socket
  });
};
