// Copyright (c) 2010 The Native Client Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that be
// found in the LICENSE file.

// File access constants.
var O_RDONLY = 00;
var O_WRONLY = 01;
var O_RDWR = 02;
var O_ACCMODE = 0003;
var O_CREAT = 0100;
var O_TRUNC = 01000;
var O_APPEND = 02000;

function escape_string(str) {
  var ret = '';
  for (var x = 0; x < str.length; x++) {
    var cd = str.charCodeAt(x) & 0xff;
    var ch = cd.toString(16);
    if (ch.length < 2) ch = '0' + ch;
    ret += ch;
  }
  return ret;
}

function unescape_string(str) {
  var ret = '';
  for (var x = 0; x < str.length; x+=2) {
    var cd = parseInt(str.substr(x, 2), 16);
    ret += String.fromCharCode(cd);
  }
  return ret;
}

function read(obj, handle, count) {
  var pair = obj.readEscaped(handle, count);
  pair[1] = unescape_string(pair[1]);
  return pair;
}

function write(obj, handle, str) {
  return obj.writeEscaped(handle, escape_string(str));
}

