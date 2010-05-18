// Copyright (c) 2010 The Native Client Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that be
// found in the LICENSE file.

/**
 * @fileoverview HTTP related functions.
 */

/**
 * @namespace Namespace for http related functions/classes.
 */
var http = {};


/**
 * Download using an HTTP GET request.
 * @param {string} url What to download.
 * @param {function(string|null)} callback What to do with the result.
 */
http.getText = function(url, callback) {
  var request = new XMLHttpRequest();
  request.onreadystatechange = function() {
    if (request.readyState == 4) {
      if (request.status == 200) {
        callback(request.responseText);
      } else {
        callback(null);
      }
    }
  }
  request.open('GET', url);
  request.overrideMimeType('text/plain; charset=x-user-defined');
  request.send(null);
};
 
