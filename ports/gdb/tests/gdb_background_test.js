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
 * @param {function(Array.<ProcesssInfo>)} callback Called when the count
 *     matches with a list of extra modules.
 */
function waitForExtraModuleCount(count, snapshot, callback) {
  chrometest.getAllProcesses(function(processes) {
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
      callback(extraModules);
    } else {
      // Try again in 100ms.
      setTimeout(function() {
        waitForExtraModuleCount(count, snapshot, callback);
      }, 100);
    }
  });
}

/**
 * Create a new test module.
 * @param {function(ProcessInfo, Element)} callback Called with result.
 */
function createModule(loaded) {
  chrometest.getAllProcesses(function(oldProcesses) {
    var object = document.createElement('embed');
    object.setAttribute('src', 'test_module.nmf');
    object.setAttribute('type', 'application/x-nacl');
    object.setAttribute('width', '0');
    object.setAttribute('height', '0');
    document.body.appendChild(object);
    waitForExtraModuleCount(1, oldProcesses, function(newModules) {
      loaded(newModules[0], object);
    });
  });
}


function TestModuleTest() {
  chrometest.Test.call(this);
  this.process = null;
  this.object = null;
}
TestModuleTest.prototype = new chrometest.Test();

TestModuleTest.prototype.setUp = function(done) {
  var self = this;
  // Snapshot the processes that are running before the test begins for later
  // use.
  chrometest.getAllProcesses(function(initialProcesses) {
    self.initialProcesses = initialProcesses;
    createModule(function(process, object) {
      self.process = process;
      self.object = object;
      done();
    });
  });
};

TestModuleTest.prototype.tearDown = function(done) {
  var self = this;
  // Wait for the test module to exit.
  waitForExtraModuleCount(0, self.initialProcesses, function() {
    // Remove node.
    if (self.object != null) {
      var p = self.object.parentNode;
      p.removeChild(self.object);
      self.object = null;
    }
    done();
  });
};


function GdbExtensionTestModuleTest() {
  TestModuleTest.call(this);
  this.gdbExt = null;
}
GdbExtensionTestModuleTest.prototype = new TestModuleTest();

GdbExtensionTestModuleTest.prototype.setUp = function(done) {
  var self = this;
  TestModuleTest.prototype.setUp.call(self, function() {
    chrometest.proxyExtension('GDB', function(gdbExt) {
      self.gdbExt = gdbExt;
      self.gdbExt.postMessage(
          {'name': 'setDebugPort', 'port': self.process.naclDebugPort});
      done();
    });
  });
};

GdbExtensionTestModuleTest.prototype.tearDown = function(done) {
  this.gdbExt.disconnect();
  TestModuleTest.prototype.tearDown(done);
};

GdbExtensionTestModuleTest.prototype.runGdb = function(done) {
  var self = this;
  chrometest.getAllProcesses(function(oldProcesses) {
    waitForExtraModuleCount(1, oldProcesses, function(newModules) {
      var gdbProcess = newModules[0];
      chrometest.proxyExtension('GDB', function(gdbExtForGdb) {
        // Once the GDB process starts.
        gdbExtForGdb.onMessage.addListener(function(msg) {
          ASSERT_EQ('rspDetachReply', msg.name, 'expect successful detach');
          gdbExtForGdb.disconnect();
          done();
        });
        gdbExtForGdb.postMessage(
          {'name': 'setDebugPort', 'port': gdbProcess.naclDebugPort});
        gdbExtForGdb.postMessage({'name': 'rspDetach'});
      });
    });
  });
  // Start gdb on the target process.
  self.gdbExt.postMessage({'name': 'runGdb'});
};



TEST_F(GdbExtensionTestModuleTest, 'testRspKill', function(done) {
  var self = this;
  self.gdbExt.onMessage.addListener(function(msg) {
    EXPECT_EQ('rspKillReply', msg.name, 'reply should be right');
    done();
  });
  self.gdbExt.postMessage({'name': 'rspKill'});
});


TEST_F(GdbExtensionTestModuleTest, 'testRspDetach', function(done) {
  var self = this;
  self.gdbExt.onMessage.addListener(function(msg) {
    EXPECT_EQ('rspDetachReply', msg.name, 'reply should be right');
    self.gdbExt.disconnect();
    setTimeout(function() {
      self.object.addEventListener('message', function(msg) {
        EXPECT_EQ('pong', msg.data);
        self.object.postMessage('exit');
        done();
      }, true);
      self.object.postMessage('ping');
    }, 500);
  });
  self.gdbExt.postMessage({'name': 'rspDetach'});
});


TEST_F(GdbExtensionTestModuleTest, 'testRspContinueOk', function(done) {
  var self = this;
  setTimeout(function() {
    self.object.addEventListener('message', function(msg) {
      EXPECT_EQ('pong', msg.data);
      self.gdbExt.onMessage.addListener(function(msg) {
        EXPECT_EQ('rspContinueReply', msg.name);
        EXPECT_EQ('exited', msg.type,
                  'expected module exit but got: ' + msg.reply);
        EXPECT_EQ(0, msg.number, 'expected 0 exit code');
        done();
      });
      self.object.postMessage('exit');
    }, true);
    self.object.postMessage('ping');
  }, 500);
  self.gdbExt.postMessage({'name': 'rspContinue'});
});


TEST_F(GdbExtensionTestModuleTest, 'testRspContinueFault', function(done) {
  var self = this;
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
          done();
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


TEST_F(GdbExtensionTestModuleTest, 'testGdbStart', function(done) {
  var self = this;
  self.stage = 0;
  self.lineCount = 0;
  self.runGdb(function() {
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
        EXPECT_TRUE(msg.name == 'crash' || msg.name == 'message',
            'expected crash or message, not ' + msg.name);
        if (msg.name == 'crash') {
          self.stage++;
          done();
        } else if (msg.name == 'message') {
          // We will receive more output from gdb, but it's echoed keystrokes
          // and exit messages, so we'll ignore it.
        } else {
          ASSERT_TRUE(false, 'unexpected message: ' + msg.name);
        }
      }
    });
  });
});
