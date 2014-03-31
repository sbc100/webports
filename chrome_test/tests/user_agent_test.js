/*
 * Copyright (c) 2014 The Native Client Authors. All rights reserved.
 * Use of this source code is governed by a BSD-style license that can be
 * found in the LICENSE file.
 */

'use strict';

TEST('UserAgentTest', 'testInTestMode', function() {
  var parts = navigator.userAgent.split('/');
  ASSERT_EQ(2, parts.length, 'agent should have 2 parts');
  EXPECT_EQ('ChromeTestAgent', parts[0],
            'first part should be an special string');
  EXPECT_EQ(32, parts[1].length,
            'second part should be a 32 digit extension id');
});
