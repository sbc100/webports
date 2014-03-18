/*
 * Copyright (c) 2014 The Native Client Authors. All rights reserved.
 * Use of this source code is governed by a BSD-style license that can be
 * found in the LICENSE file.
 */

'use strict';


TEST('ExtensionTest', 'testGetAllExtensions', function(done) {
  chrometest.getAllExtensions(function(extensions) {
    ASSERT_EQ(2, extensions.length, 'there should be two extensions');
    var expected = [
      'Chrome Testing Extension',
      'Ping Test Extension',
    ];
    expected.sort();
    var actual = [];
    for (var i = 0; i < extensions.length; i++) {
      actual.push(extensions[i].name);
    }
    actual.sort();
    EXPECT_EQ(expected, actual, 'extensions should have the right names');
    done();
  });
});

TEST('ExtensionTest', 'testBuiltInPingPong', function(done) {
  var port = chrometest.newTestPort();
  var data = 'hickory dickory dock';
  port.onMessage.addListener(function(msg) {
    EXPECT_EQ('pong', msg.name, 'we should have gotten a pong');
    EXPECT_EQ(data, msg.data, 'we should get back what we sent');
    port.disconnect();
    done();
  });
  port.postMessage({'name': 'ping', 'data': data});
});

TEST('ExtensionTest', 'testExtensionProxy', function(done) {
  var data = 'fee fi fo fum';
  chrometest.proxyExtension('Ping Test Extension', function(port) {
    port.onMessage.addListener(function(msg) {
      EXPECT_EQ('pong', msg.name, 'we should have gotten a pong');
      EXPECT_EQ(data, msg.data, 'we should get back what we sent');
      port.disconnect();
      done();
    });
    port.postMessage({'name': 'ping', 'data': data});
  });
});
