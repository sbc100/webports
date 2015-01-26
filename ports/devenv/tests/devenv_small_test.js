/*
 * Copyright (c) 2014 The Native Client Authors. All rights reserved.
 * Use of this source code is governed by a BSD-style license that can be
 * found in the LICENSE file.
 */

'use strict';

// Run the command "bash -c 'exit 42'" and check the exit code.
TEST_F(DevEnvTest, 'testExit', function() {
  return this.checkCommand('exit 42', 42, '');
});

// Run the command "bash -c 'echo hello'" and check the exit code.
TEST_F(DevEnvTest, 'testEcho', function() {
  return this.checkCommand('echo hello', 0, 'hello\n');
});

// Confirm that sh works as an alias for bash.
// Run the command "bash -c 'sh -c "foo"'" and check the exit code.
TEST_F(DevEnvTest, 'testSh', function() {
  return this.checkCommand('sh -c "echo foo"', 0, 'foo\n');
});

// Confirm that a shell script with /bin/bash works.
TEST_F(DevEnvTest, 'testSheeBangBash', function() {
  var self = this;
  return Promise.resolve().then(function() {
    return self.writeFile(
        '/home/user/foo.sh',
        '#!/bin/bash\necho "red leather, yellow leather"\n');
  }).then(function() {
    return self.checkCommand(
        '/home/user/foo.sh', 0, 'red leather, yellow leather\n');
  });
});

// Confirm that a shell script with /bin/sh works.
TEST_F(DevEnvTest, 'testSheeBangSh', function() {
  var self = this;
  return Promise.resolve().then(function() {
    return self.writeFile(
        '/home/user/bar.sh',
        '#!/bin/sh\necho "resolute urgency"\n');
  }).then(function() {
    return self.checkCommand(
        '/home/user/bar.sh', 0, 'resolute urgency\n');
  });
});

// Run a NaCl executable to make sure syscalls are working.
TEST_F(DevEnvTest, 'testCTests', function() {
  var self = this;
  return Promise.resolve().then(function() {
    return self.checkCommand('geturl ' +
        chrometest.harnessURL('devenv_small_test.zip') +
                              ' devenv_small_test.zip', 0);
  }).then(function() {
    return self.checkCommand('unzip devenv_small_test.zip', 0);
  }).then(function() {
    return self.checkCommand(
        'LD_LIBRARY_PATH=${PWD}/${PACKAGE_LIB_DIR}:$LD_LIBRARY_PATH ' +
        './devenv_small_test_${NACL_BOOT_ARCH}', 0);
  });
});

// Test the Pipe Server.
TEST_F(DevEnvTest, 'testPipeServer', function() {
  var HOST = '127.0.0.1';
  var STR = 'Hello, WoodlyDoodly!';

  var self = this;
  var pipes, socketRead, socketWrite;
  var buffer = '';

  return this.pipe().then(function(returnedPipes) {
    pipes = returnedPipes;
    return self.tcpConnect(HOST, pipes[0]);
  }).then(function(msg) {
    socketRead = msg.data;
    return self.tcpConnect(HOST, pipes[1]);
  }).then(function(msg) {
    socketWrite = msg.data;
    return self.tcpSend(socketWrite, STR);
  }).then(function() {
    return self.tcpClose(socketWrite);
  }).then(function() {
    return self.tcpRecv(socketRead);
  }).then(function recvLoop(out) {
    if (out === null) {
      return buffer;
    } else {
      buffer += out;
      return self.tcpRecv(socketRead).then(recvLoop);
    }
  }).then(function() {
    ASSERT_EQ(STR, buffer);
  });
});
