/*
  Copyright (c) 2012 The Native Client Authors. All rights reserved.
  Use of this source code is governed by a BSD-style license that can be
  found in the LICENSE file.
*/

function toArray(list) {
  return Array.prototype.slice.call(list || [], 0);
}

function HandlePepperMountMessage(data) {
  var path = data[1];
  var id = data[2];
  errorHandler = function (e) {
    var msg = '';

    switch (e.code) {
      case FileError.QUOTA_EXCEEDED_ERR:
        msg = 'QUOTA_EXCEEDED_ERR';
        break;
      case FileError.NOT_FOUND_ERR:
        msg = 'NOT_FOUND_ERR';
        break;
      case FileError.SECURITY_ERR:
        msg = 'SECURITY_ERR';
        break;
      case FileError.INVALID_MODIFICATION_ERR:
        msg = 'INVALID_MODIFICATION_ERR';
        break;
      case FileError.INVALID_STATE_ERR:
        msg = 'INVALID_STATE_ERR';
        break;
      default:
        msg = 'Unknown Error';
        break;
    };

    console.log('Error: ' + msg);
    if (id)
    {
      var items = []
      items.push("ReadDirectory")
      items.push([id])
      document.getElementById('thttpd').postMessage(JSON.stringify(items));
    }
  };

  listEntries = function (entries) {
    var items = [id]
    entries.forEach(function(entry, i) {
      items.push(entry.name) // TODO other data
    });
    console.log('posting entries');
    var res = []
    res.push("ReadDirectory")
    res.push(JSON.stringify(items)) // jeez
    document.getElementById('thttpd').postMessage(JSON.stringify(res));
  };

  onInitFs = function(fs) {
    console.log("at onInitFs")
    fs.root.getDirectory(path, {}, function (dir) { // readdir
      var dirReader = dir.createReader();
      var entries = [];

      // Call the reader.readEntries() until no more results are returned.
      var readEntries = function() {
         dirReader.readEntries (function(results) {
          if (!results.length) {
            listEntries(entries.sort());
          } else {
            entries = entries.concat(toArray(results));
            readEntries();
          }
        }, errorHandler);
      };

      readEntries(); // Start reading dirs.
    }
    , errorHandler)
  };
  console.log("before webkitRequestFS")
  if (window.webkitRequestFileSystem) {
    window.webkitRequestFileSystem(window.PERSISTENT, 5*1024*1024 /*5MB*/,
        onInitFs, errorHandler);
  }
  else
  {
    window.requestFileSystem(window.PERSISTENT, 1024*1024, onInitFs,
        errorHandler);
  }
}
