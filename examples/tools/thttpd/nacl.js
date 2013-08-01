/*
 * Copyright (c) 2012 The Native Client Authors. All rights reserved.
 * Use of this source code is governed by a BSD-style license that can be
 * found in the LICENSE file.
 */

function moduleDidLoad() {
  $("#status_field").text("SUCCESS")
}

function is_array(input) {
  return typeof(input)=='object'&&(input instanceof Array);
}

function escapeHTML(szHTML) {
  return szHTML.split("&").join("&amp;").split( "<").join("&lt;").split(">")
    .join("&gt;").split("\n").join("<br />").replace(" ", "&nbsp;")
    .replace("\t", "&nbsp;&nbsp;&nbsp;&nbsp;")
}


function handleMessage(message_event) {
  if (message_event.data == null || message_event.data == "null")
  {
    console.log("warning: null message")
    return
  }
  console.log(message_event.data);
  var data = eval('('+message_event.data+')');
  if (data == null) {
    console.log("warning: null data")
    return
  }
  if (is_array(data) && data[0] == "ReadDirectory")
  {
    console.log("calling pepper helper")
    HandlePepperMountMessage(data)
    return
  } else if (data.result && data.type == "network error") {
    $("#status_field").html("Failure")
    $("#log").html("Network initialization error. Please supply the following "
    + "flags to chrome: --enable-nacl --allow-nacl-socket-api=localhost")
  } else {
    // unknown message
  }
}

function uploadFile(file) {
  (function(f) {
    fs.root.getFile(file.name, {create: true, exclusive: true},
    function(fileEntry) {
      fileEntry.createWriter(function(fileWriter) {
      fileWriter.write(f); // Note: write() can take a File or Blob object.
      $("#log").html("File uploaded! Checkout at <a target=\"_blank\" href=\"http://localhost"
          +":8006/upload/"+file.name+"\">http://localhost:8006/upload/"+file.name+"</a>")
      }, errorHandler);
    }, errorHandler);
  })(file);
}

function handleFileSelect(evt) {
  // var url = window.URL.createObjectURL(evt.target.files[0]);
  var files = this.files;
  for (var i = 0, file; file = files[i]; ++i) {
    uploadFile(file)
  }
}

function onInitFs(fs) {
  console.log('opened fs: '+fs.name);
  window.fs = fs
}

function errorHandler(e) {
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
  $("#log").html("Error uploading file.")
  console.log('Error: ' + msg);
}

$(document).ready(function() {
  window.URL = window.URL || window.webkitURL;
  window.requestFileSystem  = window.requestFileSystem
    || window.webkitRequestFileSystem;
  window.webkitStorageInfo.requestQuota(PERSISTENT, 1024*1024,
  function(grantedBytes) {
    window.requestFileSystem(PERSISTENT, grantedBytes, onInitFs, errorHandler);
  }, function(e) {
      console.log('Error', e);
  });

  document.getElementById('upfile').addEventListener(
    'change', handleFileSelect, false);
})
