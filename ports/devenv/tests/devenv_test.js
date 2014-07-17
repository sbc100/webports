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
