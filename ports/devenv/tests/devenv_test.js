/*
 * Copyright (c) 2014 The Native Client Authors. All rights reserved.
 * Use of this source code is governed by a BSD-style license that can be
 * found in the LICENSE file.
 */

'use strict';

function DevEnvTest() {
  chrometest.Test.call(this);
  this.devEnv = null;
}
DevEnvTest.prototype = new chrometest.Test();

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

// Run the command "bash -c 'exit 42'" and check the exit code.
TEST_F(DevEnvTest, 'testExit', function() {
  var EXIT_CODE = 42;

  var self = this;
  var pid = null;

  return Promise.resolve().then(function() {
    self.devEnv.postMessage({
      'name': 'nacl_spawn',
      'nmf': 'bash.nmf',
      'argv': ['bash', '-c', 'exit ' + EXIT_CODE],
      'cwd': '/home/user',
      'envs': {},
    });
    return self.devEnv.wait();
  }).then(function(msg) {
    ASSERT_EQ('nacl_spawn_reply', msg.name);
    pid = msg.pid;
    self.devEnv.postMessage({
      'name': 'nacl_waitpid',
      'pid': -1,
      'options': 0,
    });
    return self.devEnv.wait();
  }).then(function(msg) {
    ASSERT_EQ('nacl_waitpid_reply', msg.name);
    ASSERT_EQ(pid, msg.pid);
    ASSERT_EQ(EXIT_CODE, msg.status);
  });
});
