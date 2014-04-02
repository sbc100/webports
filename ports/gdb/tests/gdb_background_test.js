/*
 * Copyright (c) 2014 The Native Client Authors. All rights reserved.
 * Use of this source code is governed by a BSD-style license that can be
 * found in the LICENSE file.
 */

'use strict';


/**
 * Wait until a certain number of NaCl modules start/stop.
 * Waits until the number of extra modules vs a snapshot equals a certain
 * number.
 * @param {integer} count Number of modules in addition to the snapshot to
 *     wait for.
 * @param {Object.<integer, ProcessInfo>} snapshot A snapshot of the the
 *     process set from getAllProcesses.
 * @return {Promise.Array.<ProcesssInfo>} Promise to wait until
 *     the module count matches with a list of extra modules.
 */
function waitForExtraModuleCount(count, snapshot) {
  return chrometest.getAllProcesses().then(function(processes) {
    var extraModules = [];
    for (var i in processes) {
      if (processes[i].type != 'nacl') {
        continue;
      }
      if (!(i in snapshot)) {
        extraModules.push(processes[i]);
      }
    }
    if (extraModules.length == count) {
      return Promise.resolve(extraModules);
    } else {
      // Try again in 100ms.
      return chrometest.wait(100).then(function() {
        return waitForExtraModuleCount(count, snapshot);
      });
    }
  });
}

/**
 * Create a new test module.
 * @return {Promise.[ProcessInfo, Element]} Promise to create element.
 */
function createModule() {
  var object = null;
  return chrometest.getAllProcesses().then(function(oldProcesses) {
    object = document.createElement('embed');
    object.setAttribute('src', 'test_module.nmf');
    object.setAttribute('type', 'application/x-nacl');
    object.setAttribute('width', '0');
    object.setAttribute('height', '0');
    document.body.appendChild(object);
    return waitForExtraModuleCount(1, oldProcesses);
  }).then(function(newModules) {
    return Promise.resolve([newModules[0], object]);
  });
}

/**
 * Create a waiter wrapper around a NaCl module.
 * @param {Element} module The module to wrap.
 * @return {chrometest.PortlikeWaiter} A promise based waiter.
 */
function moduleMessageWaiter(module) {
  var waiter;
  function handleMessage(msg) {
    waiter.enqueue(Promise.resolve(msg));
  }
  waiter = new chrometest.PortlikeWaiter(function() {
    module.removeEventListener(handleMessage);
  }, module);
  module.addEventListener('message', handleMessage, true);
  return waiter;
};


function TestModuleTest() {
  chrometest.Test.call(this);
  this.process = null;
  this.object = null;
}
TestModuleTest.prototype = new chrometest.Test();

TestModuleTest.prototype.setUp = function() {
  var self = this;
  return Promise.resolve().then(function() {
    return chrometest.Test.prototype.setUp.call(self);
  }).then(function() {
    // Snapshot the processes that are running before the test begins for later
    // use.
    return chrometest.getAllProcesses();
  }).then(function(initialProcesses) {
    self.initialProcesses = initialProcesses;
    return createModule();
  }).then(function(args) {
    self.process = args[0];
    self.rawObject = args[1];
    self.object = moduleMessageWaiter(args[1]);
    ASSERT_NE(null, self.process, 'there must be a process');
    // Done with ASSERT_FALSE because otherwise self.rawObject will attempt to
    // jsonify the DOM element.
    ASSERT_FALSE(null === self.rawObject, 'there must be a DOM element');
  });
};

TestModuleTest.prototype.tearDown = function() {
  var self = this;
  // Wait for the test module to exit.
  return waitForExtraModuleCount(0, self.initialProcesses).then(function() {
    // Remove node.
    if (self.object != null) {
      var object = self.object.detach();
      self.object = null;
      self.rawObject = null;
      var p = object.parentNode;
      p.removeChild(object);
    }
    return chrometest.Test.prototype.tearDown.call(self);
  });
};


function GdbExtensionTestModuleTest() {
  TestModuleTest.call(this);
  this.gdbExt = null;
}
GdbExtensionTestModuleTest.prototype = new TestModuleTest();

GdbExtensionTestModuleTest.prototype.setUp = function() {
  var self = this;
  return Promise.resolve().then(function() {
    return TestModuleTest.prototype.setUp.call(self);
  }).then(function() {
    return self.newGdbExtPort(self.process.naclDebugPort);
  }).then(function(gdbExt) {
    self.gdbExt = gdbExt;
  });
};

GdbExtensionTestModuleTest.prototype.tearDown = function() {
  var self = this;
  return Promise.resolve().then(function() {
    self.gdbExt.disconnect();
    return TestModuleTest.prototype.tearDown.call(self);
  });
};

/**
 * Create a new port to the GDB extension.
 * @param {integer} debugTcpPort Tcp port of the module to manage.
 * @return {Promise.Port} Promise a port to the GDB extension.
 */
GdbExtensionTestModuleTest.prototype.newGdbExtPort = function(debugTcpPort) {
  var keepPort = null;
  return Promise.resolve().then(function() {
    return chrometest.proxyExtension('GDB');
  }).then(function(gdbExtPort) {
    keepPort = gdbExtPort;
    keepPort.postMessage({'name': 'setDebugTcpPort',
                          'debugTcpPort': debugTcpPort});
    return keepPort.wait();
  }).then(function(msg) {
    ASSERT_EQ('setDebugTcpPortReply', msg.name,
      'expect debug extension port reply');
    return Promise.resolve(keepPort);
  });
};

GdbExtensionTestModuleTest.prototype.runGdb = function() {
  var self = this;
  var keepPort = null;
  return Promise.resolve().then(function() {
    return chrometest.getAllProcesses();
  }).then(function(oldProcesses) {
    // Start gdb on the target process.
    self.gdbExt.postMessage({'name': 'runGdb'});
    return waitForExtraModuleCount(1, oldProcesses);
  }).then(function(newModules) {
    var gdbProcess = newModules[0];
    return self.newGdbExtPort(gdbProcess.naclDebugPort);
  }).then(function(gdbExtForGdb) {
    keepPort = gdbExtForGdb;
    keepPort.postMessage({'name': 'rspDetach'});
    return keepPort.wait();
  }).then(function(msg) {
    ASSERT_EQ('rspDetachReply', msg.name, 'expect successful detach');
    keepPort.disconnect();
  });
};


TEST_F(GdbExtensionTestModuleTest, 'testRspKill', function() {
  var self = this;
  self.gdbExt.postMessage({'name': 'rspKill'});
  return self.gdbExt.wait().then(function(msg) {
    EXPECT_EQ('rspKillReply', msg.name, 'reply should be right');
  });
});


TEST_F(GdbExtensionTestModuleTest, 'testRspDetach', function() {
  var self = this;
  self.gdbExt.postMessage({'name': 'rspDetach'});
  return self.gdbExt.wait().then(function(msg) {
    EXPECT_EQ('rspDetachReply', msg.name, 'reply should be right');
    // Wait a bit for the module to start.
    return chrometest.wait(500);
  }).then(function() {
    self.object.postMessage('ping');
    return self.object.wait();
  }).then(function(msg) {
    EXPECT_EQ('pong', msg.data);
    self.object.postMessage('exit');
  });
});


TEST_F(GdbExtensionTestModuleTest, 'testRspContinueOk', function() {
  var self = this;
  self.gdbExt.postMessage({'name': 'rspContinue'});
  // Wait a bit for the module to start.
  return chrometest.wait(500).then(function() {
    self.object.postMessage('ping');
    return self.object.wait();
  }).then(function(msg) {
    EXPECT_EQ('pong', msg.data);
    self.object.postMessage('exit');
    return self.gdbExt.wait();
  }).then(function(msg) {
    EXPECT_EQ('rspContinueReply', msg.name);
    EXPECT_EQ('exited', msg.type,
        'expected module exit but got: ' + msg.reply);
    EXPECT_EQ(0, msg.number, 'expected 0 exit code');
  });
});


TEST_F(GdbExtensionTestModuleTest, 'testRspContinueFault', function() {
  var self = this;
  self.gdbExt.postMessage({'name': 'rspContinue'});
  // Wait a bit for the module to start.
  return chrometest.wait(500).then(function() {
    self.object.postMessage('ping');
    return self.object.wait();
  }).then(function(msg) {
    EXPECT_EQ('pong', msg.data);
    self.object.postMessage('fault');
    return self.gdbExt.wait();
  }).then(function(msg) {
    EXPECT_EQ('rspContinueReply', msg.name);
    EXPECT_EQ('signal', msg.type,
        'expected module signal but got: ' + msg.reply);
    self.gdbExt.postMessage({'name': 'rspKill'});
    return self.gdbExt.wait();
  }).then(function(msg) {
    EXPECT_EQ('rspKillReply', msg.name, 'reply should be right');
  });
});


TEST_F(GdbExtensionTestModuleTest, 'testGdbStart', function() {
  var self = this;
  self.lineCount = 0;
  return self.runGdb().then(function() {
    return self.gdbExt.wait();
  }).then(function(msg) {
    EXPECT_EQ('load', msg.name, 'expecting a load');
    return self.gdbExt.wait();
  }).then(function(msg) {
    function checkLine(msg) {
      ASSERT_EQ('message', msg.name, 'expecting a message');
      var prefix = msg.data.slice(0, 3);
      var data = msg.data.slice(3);
      EXPECT_EQ('gdb', prefix, 'expected gdb term message');
      if (data == '(gdb) ') {
        ASSERT_GE(self.lineCount, 16, 'expect gdb to emit some text');
        self.gdbExt.postMessage(
            {'name': 'input', 'msg': {'gdb': 'kill\ny\nquit\n'}});
        // Go on to the next clause.
        return self.gdbExt.wait();
      } else {
        self.lineCount++;
        ASSERT_LE(self.lineCount, 18, 'expect limited test');
        // Recurse.
        return self.gdbExt.wait().then(checkLine);
      }
    }
    return checkLine(msg);
  }).then(function(msg) {
    function checkLine(msg) {
      if (msg.name == 'message') {
        // Recurse (ignoring this line.
        return self.gdbExt.wait().then(checkLine);
      }
      EXPECT_EQ('exited', msg.name, 'expect exit');
      EXPECT_EQ(0, msg.returncode, 'expect 0');
    }
    return checkLine(msg);
  });
});
