/*
 * Copyright (c) 2014 The Native Client Authors. All rights reserved.
 * Use of this source code is governed by a BSD-style license that can be
 * found in the LICENSE file.
 */

'use strict';

function DevEnvTest() {
  chrometest.Test.call(this);
  this.devEnv = null;
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
  });
};

DevEnvTest.prototype.tearDown = function() {
  var self = this;
  return Promise.resolve().then(function() {
    self.devEnv.disconnect();
    return chrometest.Test.prototype.tearDown.call(self);
  });
};

DevEnvTest.prototype.waitWhile = function(condition, body) {
  var self = this;
  function loop(arg) {
    if (!condition(arg)) {
      return arg;
    } else {
      body(arg);
      return self.devEnv.wait().then(loop);
    }
  }
  return loop;
};

DevEnvTest.prototype.runCommand = function(cmd) {
  var self = this;
  var output = '';
  var pid = null;

  function updateStdoutUntil(name) {
    return self.waitWhile(
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
      'envs': {},
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
    ASSERT_EQ(expectedStatus, result.status);
    if (expectedOutput !== undefined) {
      ASSERT_EQ(expectedOutput, result.output);
    }
  });
};
