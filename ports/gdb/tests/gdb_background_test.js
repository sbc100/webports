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
    self.object = args[1];
    ASSERT_NE(null, self.process, 'there must be a process');
    // Done with ASSERT_FALSE because otherwise self.object will attempt to
    // jsonify the DOM element.
    ASSERT_FALSE(null === self.object, 'there must be a DOM element');
  });
};

TestModuleTest.prototype.tearDown = function() {
  var self = this;
  // Wait for the test module to exit.
  return waitForExtraModuleCount(0, self.initialProcesses).then(function() {
    // Remove node.
    if (self.object != null) {
      var p = self.object.parentNode;
      p.removeChild(self.object);
      self.object = null;
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
  return Promise.resolve().then(function() {
    return chrometest.proxyExtension('GDB');
  }).then(function(gdbExtPort) {
    return new Promise(function(resolve) {
      function handlePortReply(msg) {
        ASSERT_EQ('setDebugTcpPortReply', msg.name,
          'expect debug extension port reply');
        gdbExtPort.onMessage.removeListener(handlePortReply);
        resolve(gdbExtPort);
      }
      gdbExtPort.onMessage.addListener(handlePortReply);
      gdbExtPort.postMessage({'name': 'setDebugTcpPort',
        'debugTcpPort': debugTcpPort});
    });
  });
};

GdbExtensionTestModuleTest.prototype.runGdb = function() {
  var self = this;
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
    return new Promise(function(resolve) {
      gdbExtForGdb.onMessage.addListener(function(msg) {
        ASSERT_EQ('rspDetachReply', msg.name, 'expect successful detach');
        gdbExtForGdb.disconnect();
        resolve();
      });
      gdbExtForGdb.postMessage({'name': 'rspDetach'});
    });
  });
};


TEST_F(GdbExtensionTestModuleTest, 'testRspKill', function() {
  var self = this;
  return new Promise(function(resolve) {
    self.gdbExt.onMessage.addListener(function(msg) {
      EXPECT_EQ('rspKillReply', msg.name, 'reply should be right');
      resolve();
    });
    self.gdbExt.postMessage({'name': 'rspKill'});
  });
});


TEST_F(GdbExtensionTestModuleTest, 'testRspDetach', function() {
  var self = this;
  return new Promise(function(resolve) {
    self.gdbExt.onMessage.addListener(function(msg) {
      EXPECT_EQ('rspDetachReply', msg.name, 'reply should be right');
      setTimeout(function() {
        self.object.addEventListener('message', function(msg) {
          EXPECT_EQ('pong', msg.data);
          self.object.postMessage('exit');
          resolve();
        }, true);
        self.object.postMessage('ping');
      }, 500);
    });
    self.gdbExt.postMessage({'name': 'rspDetach'});
  });
});


TEST_F(GdbExtensionTestModuleTest, 'testRspContinueOk', function() {
  var self = this;
  return new Promise(function(resolve) {
    setTimeout(function() {
      self.object.addEventListener('message', function(msg) {
        EXPECT_EQ('pong', msg.data);
        self.gdbExt.onMessage.addListener(function(msg) {
          EXPECT_EQ('rspContinueReply', msg.name);
          EXPECT_EQ('exited', msg.type,
            'expected module exit but got: ' + msg.reply);
          EXPECT_EQ(0, msg.number, 'expected 0 exit code');
          resolve();
        });
        self.object.postMessage('exit');
      }, true);
      self.object.postMessage('ping');
    }, 500);
    self.gdbExt.postMessage({'name': 'rspContinue'});
  });
});


TEST_F(GdbExtensionTestModuleTest, 'testRspContinueFault', function() {
  var self = this;
  return new Promise(function(resolve) {
    setTimeout(function() {
      self.object.addEventListener('message', function(msg) {
        EXPECT_EQ('pong', msg.data);
        var handler = function(msg) {
          EXPECT_EQ('rspContinueReply', msg.name);
          EXPECT_EQ('signal', msg.type,
            'expected module signal but got: ' + msg.reply);
          self.gdbExt.onMessage.removeListener(handler);
          self.gdbExt.onMessage.addListener(function(msg) {
            EXPECT_EQ('rspKillReply', msg.name, 'reply should be right');
            resolve();
          });
          self.gdbExt.postMessage({'name': 'rspKill'});
        };
        self.gdbExt.onMessage.addListener(handler);
        self.object.postMessage('fault');
      }, true);
      self.object.postMessage('ping');
    }, 500);
    self.gdbExt.postMessage({'name': 'rspContinue'});
  });
});


TEST_F(GdbExtensionTestModuleTest, 'testGdbStart', function() {
  var self = this;
  return new Promise(function(resolve) {
    self.stage = 0;
    self.lineCount = 0;
    self.gdbExt.onMessage.addListener(function(msg) {
      if (self.stage == 0) {
        self.stage++;
        EXPECT_EQ('load', msg.name, 'expecting a load');
      } else if (self.stage == 1) {
        ASSERT_EQ('message', msg.name, 'expecting a message');
        var prefix = msg.data.slice(0, 3);
        var data = msg.data.slice(3);
        EXPECT_EQ('gdb', prefix, 'expected gdb term message');
        if (data == '(gdb) ') {
          ASSERT_GE(self.lineCount, 16, 'expect gdb to emit some text');
          self.stage++;
          self.gdbExt.postMessage(
            {'name': 'input', 'msg': {'gdb': 'kill\ny\nquit\n'}});
        } else {
          self.lineCount++;
          ASSERT_LE(self.lineCount, 18, 'expect limited test');
        }
      } else if (self.stage == 2) {
        EXPECT_TRUE(msg.name == 'exited' || msg.name == 'message',
            'expected exited or message, not ' + msg.name);
        if (msg.name == 'exited') {
          EXPECT_EQ(0, msg.returncode, 'return 0');
          self.stage++;
          resolve();
        } else if (msg.name == 'message') {
          // We will receive more output from gdb, but it's echoed keystrokes
          // and exit messages, so we'll ignore it.
        } else {
          ASSERT_TRUE(false, 'unexpected message: ' + msg.name);
        }
      }
    });
    self.runGdb();
  });
});
