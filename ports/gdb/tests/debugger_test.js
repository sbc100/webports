/*
 * Copyright (c) 2014 The Native Client Authors. All rights reserved.
 * Use of this source code is governed by a BSD-style license that can be
 * found in the LICENSE file.
 */

'use strict';

function DebugExtensionTest() {
  this.debugExt = null;
  this.moduleId = null;
  this.change = null;
}
DebugExtensionTest.prototype = new TestModuleTest();

DebugExtensionTest.prototype.setUp = function() {
  var self = this;
  return Promise.resolve().then(function() {
    return TestModuleTest.prototype.setUp.call(self);
  }).then(function() {
    // Wait for test module to be run by extensions.
    return chrometest.sleep(500);
  }).then(function() {
    return chrometest.proxyExtension('NaCl Debugger');
  }).then(function(debugExt) {
    self.debugExt = debugExt;
  }).then(function() {
    return self.debugExt.wait();
  }).then(function(msg) {
    ASSERT_EQ('change', msg.name);
    ASSERT_EQ('join', msg.cause);
    var ids = Object.keys(msg.naclModules);
    ASSERT_EQ(1, ids.length);
    self.moduleId = ids[0];
    self.change = msg;
    ASSERT_TRUE(msg.naclModules[self.moduleId].process.title.indexOf(
        'test_module.nmf') >= 0);
  });
};

DebugExtensionTest.prototype.tearDown = function() {
  var self = this;
  return Promise.resolve().then(function() {
    self.debugExt.disconnect();
    return TestModuleTest.prototype.tearDown.call(self);
  });
};


TEST_F(DebugExtensionTest, 'testExit', function() {
  var self = this;
  return Promise.resolve().then(function() {
    self.object.postMessage('exit');
    return self.debugExt.wait();
  }).then(function(msg) {
    ASSERT_EQ('change', msg.name);
    ASSERT_EQ('exit', msg.cause);
    var ids = Object.keys(msg.naclModules);
    ASSERT_EQ(0, ids.length);
  });
});


TEST_F(DebugExtensionTest, 'testFaultKilled', function() {
  var self = this;
  return Promise.resolve().then(function() {
    self.change.settings.onFaultAttach = false;
    self.debugExt.postMessage(
        {'name': 'settingsChange', 'settings': self.change.settings});
    return self.debugExt.wait();
  }).then(function(msg) {
    ASSERT_EQ('change', msg.name);
    ASSERT_EQ('settingsChange', msg.cause);
    ASSERT_FALSE(msg.settings.onFaultAttach);
    self.object.postMessage('fault');
    return self.debugExt.wait();
  }).then(function(msg) {
    ASSERT_EQ('change', msg.name);
    ASSERT_EQ('killed', msg.cause);
    return self.debugExt.wait();
  }).then(function(msg) {
    ASSERT_EQ('change', msg.name);
    ASSERT_EQ('exit', msg.cause);
    var ids = Object.keys(msg.naclModules);
    ASSERT_EQ(0, ids.length);
  });
});


TEST_F(DebugExtensionTest, 'testFaultAttach', function() {
  var self = this;
  return Promise.resolve().then(function() {
    self.change.settings.onFaultAttach = true;
    self.debugExt.postMessage(
        {'name': 'settingsChange', 'settings': self.change.settings});
    return self.debugExt.wait();
  }).then(function(msg) {
    ASSERT_EQ('change', msg.name);
    ASSERT_EQ('settingsChange', msg.cause);
    ASSERT_TRUE(msg.settings.onFaultAttach);
    self.object.postMessage('fault');
    return self.debugExt.wait();
  }).then(function(msg) {
    ASSERT_EQ('change', msg.name);
    ASSERT_EQ('faulted', msg.cause);
    return self.debugExt.wait();
  }).then(function(msg) {
    ASSERT_EQ('change', msg.name);
    ASSERT_EQ('create', msg.cause);
    return self.debugExt.wait();
  }).then(function(msg) {
    ASSERT_EQ('change', msg.name);
    ASSERT_EQ('setup', msg.cause);
    self.debugExt.postMessage({name: 'tune', 'processId': self.moduleId});
    return self.debugExt.wait();
  }).then(function(msg) {
    var count = 0;
    function handleMessage(msg) {
      if (msg.name == 'message') {
        if (count == 0) {
          self.debugExt.postMessage(
            {'name': 'input', 'msg': {'gdb': 'kill\ny\nquit\n'}});
        }
        count++;
        return self.debugExt.wait();
      }
      ASSERT_EQ('change', msg.name);
      ASSERT_EQ('exit', msg.cause);
      var ids = Object.keys(msg.naclModules);
      ASSERT_EQ(0, ids.length);
    };
    return handleMessage(msg);
  });
});
