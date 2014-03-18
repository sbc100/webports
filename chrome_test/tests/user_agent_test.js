/*
 * Copyright (c) 2014 The Native Client Authors. All rights reserved.
 * Use of this source code is governed by a BSD-style license that can be
 * found in the LICENSE file.
 */

'use strict';

TEST('UserAgentTest', 'testInTestMode', function(done) {
  EXPECT_EQ('ChromeTestAgent', navigator.userAgent,
            'checking that user agent is a special test value');
  done();
});
